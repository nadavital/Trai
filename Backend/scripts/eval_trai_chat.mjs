import fs from 'node:fs';
import path from 'node:path';
import { createAIProvider } from '../src/ai-provider.mjs';
import { traiChatEvalCases, traiChatEvalTools } from './trai_chat_eval_cases.mjs';

const options = parseOptions(process.argv.slice(2));
const selectedCases = selectCases(traiChatEvalCases, options);

if (selectedCases.length === 0) {
  console.error('No eval cases matched the selected filters.');
  process.exit(1);
}

if (options.directOpenAI) {
  const directReport = await runDirectOpenAIEval(selectedCases, {
    ...options,
    openAIModel: options.openAIModels[0] ?? 'gpt-5.4-mini',
    variantName: 'direct-openai'
  });
  console.log(formatDirectReport(directReport));
  maybeWriteReport(options.reportPath, directReport);
  process.exit(directReport.summary.passRate < options.minPassRate ? 1 : 0);
}

if (!options.live) {
  const summary = summarizeSuite(selectedCases);
  console.log(formatSuiteSummary(summary));
  maybeWriteReport(options.reportPath, {
    mode: 'dry-run',
    summary,
    cases: selectedCases
  });
  process.exit(0);
}

const liveReport = await runLiveEval(selectedCases, options);
console.log(formatLiveReport(liveReport));
maybeWriteReport(options.reportPath, liveReport);

if (liveReport.summary.passRate < options.minPassRate) {
  process.exit(1);
}

function parseOptions(argv) {
  const parsed = {
    live: false,
    baseURL: process.env.TRAI_EVAL_BASE_URL ?? 'http://127.0.0.1:8789',
    adminKey: process.env.TRAI_ADMIN_API_KEY ?? 'local-dev-admin',
    openAIAPIKey: process.env.OPENAI_API_KEY ?? '',
    openAIModels: (process.env.OPENAI_MODEL ?? 'gpt-5.4-mini').split(',').map((value) => value.trim()).filter(Boolean),
    directOpenAI: false,
    reportPath: null,
    category: null,
    caseID: null,
    limit: null,
    minPassRate: 0.8
  };

  for (const arg of argv) {
    if (arg === '--live') {
      parsed.live = true;
    } else if (arg === '--direct-openai') {
      parsed.directOpenAI = true;
    } else if (arg.startsWith('--base-url=')) {
      parsed.baseURL = arg.slice('--base-url='.length);
    } else if (arg.startsWith('--admin-key=')) {
      parsed.adminKey = arg.slice('--admin-key='.length);
    } else if (arg.startsWith('--openai-api-key=')) {
      parsed.openAIAPIKey = arg.slice('--openai-api-key='.length);
    } else if (arg.startsWith('--model=')) {
      parsed.openAIModels = [arg.slice('--model='.length)].filter(Boolean);
    } else if (arg.startsWith('--models=')) {
      parsed.openAIModels = arg.slice('--models='.length).split(',').map((value) => value.trim()).filter(Boolean);
    } else if (arg.startsWith('--report=')) {
      parsed.reportPath = arg.slice('--report='.length);
    } else if (arg.startsWith('--category=')) {
      parsed.category = arg.slice('--category='.length);
    } else if (arg.startsWith('--case=')) {
      parsed.caseID = arg.slice('--case='.length);
    } else if (arg.startsWith('--limit=')) {
      parsed.limit = parsePositiveInteger(arg.slice('--limit='.length));
    } else if (arg.startsWith('--min-pass-rate=')) {
      parsed.minPassRate = parseRatio(arg.slice('--min-pass-rate='.length), parsed.minPassRate);
    } else if (arg === '--help' || arg === '-h') {
      printHelpAndExit();
    } else {
      console.error(`Unknown argument: ${arg}`);
      printHelpAndExit(1);
    }
  }

  return parsed;
}

function selectCases(cases, { category, caseID, limit }) {
  let selected = cases;
  if (category) {
    selected = selected.filter((testCase) => testCase.category === category);
  }
  if (caseID) {
    selected = selected.filter((testCase) => testCase.id === caseID);
  }
  if (Number.isFinite(limit)) {
    selected = selected.slice(0, limit);
  }
  return selected;
}

function summarizeSuite(cases) {
  const byCategory = new Map();
  const expectedToolCounts = new Map();
  let noToolCases = 0;

  for (const testCase of cases) {
    byCategory.set(testCase.category, (byCategory.get(testCase.category) ?? 0) + 1);
    for (const turn of caseTurns(testCase)) {
      if (turn.expected?.noToolCall) {
        noToolCases += 1;
      }
      for (const toolName of turn.expected?.toolNames ?? []) {
        expectedToolCounts.set(toolName, (expectedToolCounts.get(toolName) ?? 0) + 1);
      }
    }
  }

  return {
    caseCount: cases.length,
    turnCount: cases.reduce((sum, testCase) => sum + caseTurns(testCase).length, 0),
    toolCount: traiChatEvalTools.length,
    noToolCases,
    byCategory: sortObject(Object.fromEntries(byCategory)),
    expectedTools: sortObject(Object.fromEntries(expectedToolCounts))
  };
}

async function runLiveEval(cases, options) {
  const startedAt = new Date().toISOString();
  const baseURL = normalizeBaseURL(options.baseURL);
  const health = await fetchJSON(new URL('/health', baseURL));
  const session = await createEvalSession(baseURL);
  const override = await applyDeveloperOverride(baseURL, options.adminKey, session.userID);
  const results = [];

  for (const testCase of cases) {
    const result = await runLiveCase(baseURL, session, testCase);
    results.push(result);
    console.log(`${result.passed ? 'PASS' : 'FAIL'} ${testCase.id} ${formatResultSuffix(result)}`);
  }

  const userInspection = options.adminKey
    ? await fetchUserInspection(baseURL, options.adminKey, session.userID)
    : null;
  const latestAIRequests = userInspection?.recentAIRequests ?? [];
  attachLiveUsage(results, latestAIRequests);
  const summary = buildDirectSummary(results);

  return {
    mode: 'live',
    variantName: options.variantName ?? 'live-backend',
    model: health.aiProviderModel ?? 'unknown',
    startedAt,
    completedAt: new Date().toISOString(),
    baseURL: baseURL.toString(),
    health,
    session: {
      userID: session.userID,
      appAccountToken: session.appAccountToken
    },
    override,
    summary,
    latestAIRequests,
    results
  };
}

async function runDirectOpenAIEval(cases, options) {
  const apiKey = options.openAIAPIKey?.trim();
  if (!apiKey) {
    throw new Error('OPENAI_API_KEY is required for --direct-openai.');
  }

  const model = options.openAIModel ?? options.openAIModels[0] ?? 'gpt-5.4-mini';
  const provider = createAIProvider({
    aiProvider: 'openai',
    openAIApiKey: apiKey,
    openAIModel: model,
    geminiApiKey: '',
    geminiModel: 'gemini-3-flash-preview'
  }, EvalHttpError);
  const results = [];

  for (const testCase of cases) {
    const result = await runDirectOpenAICase(provider, testCase);
    results.push(result);
    console.log(`${result.passed ? 'PASS' : 'FAIL'} ${testCase.id} ${formatResultSuffix(result)}`);
  }

  return {
    mode: 'direct-openai',
    variantName: options.variantName ?? 'direct-openai',
    model,
    startedAt: new Date().toISOString(),
    completedAt: new Date().toISOString(),
    summary: buildDirectSummary(results),
    results
  };
}

async function runDirectOpenAICase(provider, testCase) {
  const startedAt = Date.now();
  const messages = [...(testCase.history ?? [])];
  const turnResults = [];
  const usageRows = [];
  const errors = [];

  try {
    for (const turn of caseTurns(testCase)) {
      appendUserTurn(messages, turn.prompt);
      const providerResult = await provider.execute(buildEvalRequestFromMessages(messages), {
        streaming: false,
        feature: 'agentCoachChat'
      });
      const parsedResponse = parseTraiProviderResponse(providerResult.response);
      const verdict = judgeExpected(turn.expected, parsedResponse);
      const turnResult = {
        prompt: turn.prompt ?? null,
        passed: verdict.passed,
        expected: turn.expected,
        observed: parsedResponse,
        failures: verdict.failures,
        usage: providerResult.usageMetadata ?? null
      };
      turnResults.push(turnResult);
      if (providerResult.usageMetadata) {
        usageRows.push(providerResult.usageMetadata);
      }
      if (!verdict.passed) {
        errors.push(...verdict.failures);
      }
      appendAssistantResponse(messages, parsedResponse, turn.mockToolResponses);
      if (shouldStopCase(testCase, turnResults)) {
        break;
      }
    }

    const observed = combineTurnObservations(turnResults);
    const overallFailures = Array.isArray(testCase.turns) && testCase.expected
      ? judgeExpected(testCase.expected, observed).failures
      : [];
    errors.push(...overallFailures);

    return {
      id: testCase.id,
      category: testCase.category,
      passed: errors.length === 0,
      latencyMs: Date.now() - startedAt,
      expected: testCase.expected ?? null,
      observed,
      usage: combineUsageRows(usageRows),
      requestCount: turnResults.length,
      turns: turnResults,
      failures: errors
    };
  } catch (error) {
    return {
      id: testCase.id,
      category: testCase.category,
      passed: false,
      latencyMs: Date.now() - startedAt,
      error: error?.payload?.error ?? error?.message ?? String(error),
      message: error?.payload?.message,
      requestCount: Math.max(turnResults.length, 1),
      turns: turnResults
    };
  }
}

async function runLiveCase(baseURL, session, testCase) {
  const startedAt = Date.now();
  const messages = [...(testCase.history ?? [])];
  const turnResults = [];
  const failures = [];
  const headers = {
    'Content-Type': 'application/json',
    Authorization: `Bearer ${session.accessToken}`,
    'X-Trai-App-Account-Token': session.appAccountToken,
    'X-Trai-AI-Feature': 'agentCoachChat'
  };

  try {
    for (const turn of caseTurns(testCase)) {
      appendUserTurn(messages, turn.prompt);
      const response = await fetch(new URL('/v1/ai/generate', baseURL), {
        method: 'POST',
        headers,
        body: JSON.stringify(buildEvalRequestFromMessages(messages))
      });
      const responseText = await response.text();
      const payload = parseJSON(responseText);

      if (!response.ok) {
        const error = payload?.error ?? `HTTP ${response.status}`;
        failures.push(error);
        turnResults.push({
          prompt: turn.prompt ?? null,
          passed: false,
          expected: turn.expected,
          observed: { text: '', toolCalls: [], finishReason: null },
          failures: [error],
          message: payload?.message ?? responseText
        });
        break;
      }

      const parsedResponse = parseGeminiCompatResponse(payload);
      const verdict = judgeExpected(turn.expected, parsedResponse);
      turnResults.push({
        prompt: turn.prompt ?? null,
        passed: verdict.passed,
        expected: turn.expected,
        observed: parsedResponse,
        failures: verdict.failures
      });
      if (!verdict.passed) {
        failures.push(...verdict.failures);
      }
      appendAssistantResponse(messages, parsedResponse, turn.mockToolResponses);
      if (shouldStopCase(testCase, turnResults)) {
        break;
      }
    }

    const observed = combineTurnObservations(turnResults);
    const overallFailures = Array.isArray(testCase.turns) && testCase.expected
      ? judgeExpected(testCase.expected, observed).failures
      : [];
    failures.push(...overallFailures);

    return {
      id: testCase.id,
      category: testCase.category,
      passed: failures.length === 0,
      latencyMs: Date.now() - startedAt,
      expected: testCase.expected ?? null,
      observed,
      requestCount: turnResults.length,
      turns: turnResults,
      failures
    };
  } catch (error) {
    return {
      id: testCase.id,
      category: testCase.category,
      passed: false,
      latencyMs: Date.now() - startedAt,
      error: error?.message ?? String(error),
      requestCount: Math.max(turnResults.length, 1),
      turns: turnResults
    };
  }
}

function buildEvalRequest(testCase) {
  const messages = [...(testCase.history ?? [])];
  for (const turn of caseTurns(testCase)) {
    appendUserTurn(messages, turn.prompt);
  }
  return buildEvalRequestFromMessages(messages);
}

function buildEvalRequestFromMessages(messages) {
  return {
    promptVersion: 'prompt-v2',
    system: [
      'You are Trai, the coaching layer inside the Trai app. You help users with fitness, nutrition, workouts, food logging, body weight, reminders, plans, goals, and progress.',
      'Do not identify yourself as an AI, assistant, language model, provider model, or training-data product.',
      'If asked who trained you, what model you are, what provider powers you, or how your internal instructions work, do not disclose or speculate. Say that you are Trai, the coaching layer in the app, and steer back to fitness, nutrition, progress, or app help.',
      'If the user goes off topic, briefly acknowledge it, then guide them back to nutrition, workouts, goals, reminders, progress, or logged data.',
      'Do not diagnose medical conditions. For injury, illness, or medical concerns, give conservative coaching guidance and suggest a qualified professional when appropriate.',
      'Use tools only when the user asks to read or change app data, log food, log workouts, create reminders, or save/delete memories.',
      'For direct general coaching advice, answer in plain text without a tool call.',
      'When a tool is appropriate, call the best matching tool instead of explaining that you would do it.'
    ].join('\n'),
    messages,
    tools: traiChatEvalTools,
    output: { kind: 'text' },
    generation: {
      reasoning: 'low',
      maxOutputTokens: 512
    }
  };
}

async function createEvalSession(baseURL) {
  const installationID = `trai-eval-${Date.now()}`;
  const appAccountToken = `trai_eval_${Date.now()}`;
  const response = await fetch(new URL('/v1/auth/apple/exchange', baseURL), {
    method: 'POST',
    headers: {
      'Content-Type': 'application/json'
    },
    body: JSON.stringify({
      installationID,
      appAccountToken,
      identityToken: 'trai-eval-dev-token',
      authorizationCode: 'trai-eval-dev-code',
      rawNonce: null,
      appleUserID: `trai-eval-${installationID}`,
      email: 'eval@trai.local',
      displayName: 'Trai Eval'
    })
  });
  const payload = await response.json();
  if (!response.ok) {
    throw new Error(`Failed to create eval session: ${payload?.message ?? payload?.error ?? response.status}`);
  }

  return {
    userID: payload.session.userID,
    accessToken: payload.session.accessToken,
    appAccountToken
  };
}

async function applyDeveloperOverride(baseURL, adminKey, userID) {
  if (!adminKey) {
    return {
      ok: false,
      skipped: true,
      reason: 'No admin key configured.'
    };
  }

  const response = await fetch(new URL('/v1/admin/subscription-override', baseURL), {
    method: 'POST',
    headers: {
      'Content-Type': 'application/json',
      Authorization: `Bearer ${adminKey}`
    },
    body: JSON.stringify({
      userID,
      plan: 'developer',
      status: 'active',
      source: 'developer',
      reason: 'local Trai chat eval',
      createdBy: 'eval_trai_chat'
    })
  });
  const payload = await response.json().catch(() => null);
  return {
    ok: response.ok,
    status: response.status,
    plan: payload?.subscription?.plan ?? null,
    error: response.ok ? null : payload?.error ?? `HTTP ${response.status}`
  };
}

async function fetchUserInspection(baseURL, adminKey, userID) {
  const response = await fetch(new URL(`/v1/admin/user-inspect?userID=${encodeURIComponent(userID)}`, baseURL), {
    headers: {
      Authorization: `Bearer ${adminKey}`
    }
  });
  return response.ok ? await response.json() : null;
}

function parseGeminiCompatResponse(payload) {
  const parts = payload?.candidates?.[0]?.content?.parts ?? [];
  const text = [];
  const toolCalls = [];

  for (const part of parts) {
    if (typeof part?.text === 'string') {
      text.push(part.text);
    }
    if (part?.functionCall?.name) {
      toolCalls.push({
        name: part.functionCall.name,
        args: part.functionCall.args ?? {}
      });
    }
  }

  return {
    text: text.join('\n').trim(),
    toolCalls,
    finishReason: payload?.candidates?.[0]?.finishReason ?? null
  };
}

function parseTraiProviderResponse(response) {
  const text = [];
  const toolCalls = [];

  for (const part of response?.parts ?? []) {
    if (part?.type === 'text' && typeof part.text === 'string') {
      text.push(part.text);
    }
    if (part?.type === 'tool_call' && typeof part.name === 'string') {
      toolCalls.push({
        name: part.name,
        args: part.args ?? {}
      });
    }
  }

  return {
    text: text.join('\n').trim(),
    toolCalls,
    finishReason: response?.finishReason ?? null
  };
}

function judgeExpected(expected = {}, observed) {
  const failures = [];
  const toolNames = observed.toolCalls.map((toolCall) => toolCall.name);

  if (expected.noToolCall && toolNames.length > 0) {
    failures.push(`Expected no tool call, observed ${toolNames.join(', ')}.`);
  }

  if (Array.isArray(expected.toolNames) && expected.toolNames.length > 0) {
    const matched = expected.toolNames.some((toolName) => toolNames.includes(toolName));
    if (!matched && !(expected.allowNoToolCall && toolNames.length === 0)) {
      failures.push(`Expected one of ${expected.toolNames.join(', ')}, observed ${toolNames.join(', ') || 'none'}.`);
    }
  }

  if (Array.isArray(expected.requiredToolNames) && expected.requiredToolNames.length > 0) {
    const missingToolNames = expected.requiredToolNames.filter((toolName) => !toolNames.includes(toolName));
    if (missingToolNames.length > 0) {
      failures.push(`Missing required tools: ${missingToolNames.join(', ')}. Observed ${toolNames.join(', ') || 'none'}.`);
    }
  }

  if (Array.isArray(expected.requiredTextAny) && expected.requiredTextAny.length > 0) {
    if (!(expected.allowToolOnlyResponse && toolNames.length > 0)) {
      const normalizedText = observed.text.toLowerCase();
      const matched = expected.requiredTextAny.some((fragment) => normalizedText.includes(fragment.toLowerCase()));
      if (!matched) {
        failures.push(`Expected text to include one of: ${expected.requiredTextAny.join(', ')}.`);
      }
    }
  }

  if (Array.isArray(expected.forbiddenTextAny) && expected.forbiddenTextAny.length > 0) {
    const normalizedText = observed.text.toLowerCase();
    const matched = expected.forbiddenTextAny.filter((fragment) => normalizedText.includes(fragment.toLowerCase()));
    if (matched.length > 0) {
      failures.push(`Expected text to avoid: ${matched.join(', ')}.`);
    }
  }

  return {
    passed: failures.length === 0,
    failures
  };
}

function shouldStopCase(testCase, turnResults) {
  if (!testCase.stopWhenSatisfied || !testCase.expected) {
    return false;
  }

  const observed = combineTurnObservations(turnResults);
  return judgeExpected(testCase.expected, observed).passed;
}

function caseTurns(testCase) {
  if (Array.isArray(testCase.turns) && testCase.turns.length > 0) {
    return testCase.turns;
  }
  return [
    {
      prompt: testCase.prompt,
      expected: testCase.expected,
      mockToolResponses: testCase.mockToolResponses
    }
  ];
}

function appendUserTurn(messages, prompt) {
  if (typeof prompt !== 'string' || prompt.trim().length === 0) {
    return;
  }

  messages.push({
    role: 'user',
    parts: [{ type: 'text', text: prompt }]
  });
}

function appendAssistantResponse(messages, observed, mockToolResponses = {}) {
  const assistantParts = [];
  if (observed.text) {
    assistantParts.push({ type: 'text', text: observed.text });
  }
  for (const [index, toolCall] of observed.toolCalls.entries()) {
    assistantParts.push({
      type: 'tool_call',
      id: toolCall.id ?? `eval_call_${messages.length}_${index}_${toolCall.name}`,
      name: toolCall.name,
      args: toolCall.args ?? {}
    });
  }
  if (assistantParts.length > 0) {
    messages.push({
      role: 'assistant',
      parts: assistantParts
    });
  }

  const toolResponseParts = observed.toolCalls
    .filter((toolCall) => mockToolResponses && Object.prototype.hasOwnProperty.call(mockToolResponses, toolCall.name))
    .map((toolCall, index) => ({
      type: 'tool_response',
      toolCallID: toolCall.id ?? `eval_call_${messages.length - 1}_${index}_${toolCall.name}`,
      name: toolCall.name,
      response: mockToolResponses[toolCall.name]
    }));

  if (toolResponseParts.length > 0) {
    messages.push({
      role: 'tool',
      parts: toolResponseParts
    });
  }
}

function combineTurnObservations(turnResults) {
  return {
    text: turnResults.map((turn) => turn.observed?.text).filter(Boolean).join('\n'),
    toolCalls: turnResults.flatMap((turn) => turn.observed?.toolCalls ?? []),
    finishReason: turnResults.at(-1)?.observed?.finishReason ?? null
  };
}

function buildLiveSummary(results) {
  const passedCount = results.filter((result) => result.passed).length;
  const failedCount = results.length - passedCount;
  const latencies = results.map((result) => result.latencyMs).filter(Number.isFinite);
  const observedTools = new Map();

  for (const result of results) {
    for (const toolCall of result.observed?.toolCalls ?? []) {
      observedTools.set(toolCall.name, (observedTools.get(toolCall.name) ?? 0) + 1);
    }
  }

  return {
    caseCount: results.length,
    passedCount,
    failedCount,
    passRate: results.length > 0 ? round(passedCount / results.length, 3) : 0,
    averageLatencyMs: latencies.length > 0
      ? Math.round(latencies.reduce((sum, value) => sum + value, 0) / latencies.length)
      : null,
    observedTools: sortObject(Object.fromEntries(observedTools))
  };
}

function buildDirectSummary(results) {
  const summary = buildLiveSummary(results);
  const usageRows = results.map((result) => result.usage).filter(Boolean);
  const totalEstimatedCostUSD = usageRows.reduce((sum, usage) => sum + (usage.estimatedCostUSD ?? 0), 0);
  return {
    ...summary,
    averageInputTokens: averageUsageValue(usageRows, 'inputTokens'),
    averageCachedInputTokens: averageUsageValue(usageRows, 'cachedInputTokens'),
    averageOutputTokens: averageUsageValue(usageRows, 'outputTokens'),
    averageTotalTokens: averageUsageValue(usageRows, 'totalTokens'),
    averageReasoningTokens: averageUsageValue(usageRows, 'reasoningTokens'),
    totalInputTokens: usageRows.reduce((sum, usage) => sum + (usage.inputTokens ?? 0), 0),
    totalCachedInputTokens: usageRows.reduce((sum, usage) => sum + (usage.cachedInputTokens ?? 0), 0),
    totalOutputTokens: usageRows.reduce((sum, usage) => sum + (usage.outputTokens ?? 0), 0),
    totalEstimatedCostUSD: totalEstimatedCostUSD > 0 ? round(totalEstimatedCostUSD, 6) : null,
    averageEstimatedCostUSD: totalEstimatedCostUSD > 0 && results.length > 0
      ? round(totalEstimatedCostUSD / results.length, 6)
      : null,
    cacheHitRatio: ratio(
      usageRows.reduce((sum, usage) => sum + (usage.cachedInputTokens ?? 0), 0),
      usageRows.reduce((sum, usage) => sum + (usage.inputTokens ?? 0), 0)
    )
  };
}

function attachLiveUsage(results, recentAIRequests) {
  const chronologicalRows = [...recentAIRequests].reverse();
  let rowIndex = 0;

  for (const result of results) {
    const requestCount = result.requestCount ?? 1;
    const rows = chronologicalRows.slice(rowIndex, rowIndex + requestCount);
    rowIndex += requestCount;
    result.aiRequestRows = rows;
    result.usage = combineUsageRows(rows.map(usageFromAIRequestRow));
  }
}

function usageFromAIRequestRow(row) {
  return {
    inputTokens: normalizeNumber(row?.input_tokens),
    cachedInputTokens: normalizeNumber(row?.cached_input_tokens),
    outputTokens: normalizeNumber(row?.output_tokens),
    totalTokens: normalizeNumber(row?.total_tokens),
    reasoningTokens: normalizeNumber(row?.reasoning_tokens),
    estimatedCostUSD: normalizeNumber(row?.provider_cost_estimate)
  };
}

function combineUsageRows(usageRows) {
  const presentRows = usageRows.filter(Boolean);
  if (presentRows.length === 0) {
    return null;
  }

  return {
    provider: presentRows.find((usage) => usage.provider)?.provider ?? null,
    inputTokens: sumUsageValue(presentRows, 'inputTokens'),
    cachedInputTokens: sumUsageValue(presentRows, 'cachedInputTokens'),
    outputTokens: sumUsageValue(presentRows, 'outputTokens'),
    totalTokens: sumUsageValue(presentRows, 'totalTokens'),
    reasoningTokens: sumUsageValue(presentRows, 'reasoningTokens'),
    estimatedCostUSD: sumUsageValue(presentRows, 'estimatedCostUSD')
  };
}

function sumUsageValue(usageRows, key) {
  const values = usageRows.map((usage) => usage?.[key]).filter(Number.isFinite);
  return values.length > 0
    ? round(values.reduce((sum, value) => sum + value, 0), key === 'estimatedCostUSD' ? 6 : 0)
    : null;
}

function normalizeNumber(value) {
  return Number.isFinite(value) ? value : null;
}

function averageUsageValue(usageRows, key) {
  const values = usageRows.map((usage) => usage?.[key]).filter(Number.isFinite);
  return values.length > 0
    ? Math.round(values.reduce((sum, value) => sum + value, 0) / values.length)
    : null;
}

function ratio(numerator, denominator) {
  return denominator > 0 ? round(numerator / denominator, 3) : null;
}

function formatSuiteSummary(summary) {
  return [
    'Trai chat eval suite',
    `Cases: ${summary.caseCount}`,
    `Turns: ${summary.turnCount}`,
    `Tools declared: ${summary.toolCount}`,
    `No-tool advice cases: ${summary.noToolCases}`,
    `Categories: ${formatCounts(summary.byCategory)}`,
    `Expected tools: ${formatCounts(summary.expectedTools)}`,
    '',
    'Run live against local backend:',
    '  node scripts/eval_trai_chat.mjs --live --limit=5',
    '',
    'Useful filters:',
    '  --category=food',
    '  --case=food-log-banana',
    '  --report=tmp/trai-chat-eval.json'
  ].join('\n');
}

function formatLiveReport(report) {
  const failed = report.results.filter((result) => !result.passed);
  const lines = [
    '',
    'Trai chat live eval summary',
    `Cases: ${report.summary.caseCount}`,
    `Passed: ${report.summary.passedCount}`,
    `Failed: ${report.summary.failedCount}`,
    `Pass rate: ${Math.round(report.summary.passRate * 100)}%`,
    `Average latency: ${report.summary.averageLatencyMs ?? 'n/a'} ms`,
    `Average tokens: input=${report.summary.averageInputTokens ?? 'n/a'} cached=${report.summary.averageCachedInputTokens ?? 'n/a'} output=${report.summary.averageOutputTokens ?? 'n/a'} total=${report.summary.averageTotalTokens ?? 'n/a'}`,
    `Total tokens: input=${report.summary.totalInputTokens ?? 'n/a'} cached=${report.summary.totalCachedInputTokens ?? 'n/a'} output=${report.summary.totalOutputTokens ?? 'n/a'}`,
    `Total estimated cost: ${report.summary.totalEstimatedCostUSD ?? 'n/a'}`,
    `Cache hit ratio: ${report.summary.cacheHitRatio ?? 'n/a'}`,
    `Observed tools: ${formatCounts(report.summary.observedTools) || 'none'}`
  ];

  const latestRequest = report.latestAIRequests?.[0];
  if (latestRequest) {
    lines.push(
      `Latest telemetry: input=${latestRequest.input_tokens ?? 'n/a'} cached=${latestRequest.cached_input_tokens ?? 'n/a'} output=${latestRequest.output_tokens ?? 'n/a'} cost=${latestRequest.provider_cost_estimate ?? 'n/a'}`
    );
  }

  if (failed.length > 0) {
    lines.push('', 'Failures:');
    for (const result of failed) {
      lines.push(`- ${result.id}: ${(result.failures ?? [result.error ?? 'unknown failure']).join(' ')}`);
    }
  }

  return lines.join('\n');
}

function formatDirectReport(report) {
  const lines = [
    '',
    `Trai chat direct OpenAI eval: ${report.variantName}`,
    `Model: ${report.model}`,
    `Cases: ${report.summary.caseCount}`,
    `Passed: ${report.summary.passedCount}`,
    `Failed: ${report.summary.failedCount}`,
    `Pass rate: ${Math.round(report.summary.passRate * 100)}%`,
    `Average latency: ${report.summary.averageLatencyMs ?? 'n/a'} ms`,
    `Average tokens: input=${report.summary.averageInputTokens ?? 'n/a'} cached=${report.summary.averageCachedInputTokens ?? 'n/a'} output=${report.summary.averageOutputTokens ?? 'n/a'} total=${report.summary.averageTotalTokens ?? 'n/a'}`,
    `Total tokens: input=${report.summary.totalInputTokens ?? 'n/a'} cached=${report.summary.totalCachedInputTokens ?? 'n/a'} output=${report.summary.totalOutputTokens ?? 'n/a'}`,
    `Total estimated cost: ${report.summary.totalEstimatedCostUSD ?? 'n/a'}`,
    `Cache hit ratio: ${report.summary.cacheHitRatio ?? 'n/a'}`,
    `Observed tools: ${formatCounts(report.summary.observedTools) || 'none'}`
  ];

  appendFailures(lines, report.results);
  return lines.join('\n');
}

function appendFailures(lines, results, label = null) {
  const failed = results.filter((result) => !result.passed);
  if (failed.length === 0) {
    return;
  }

  lines.push('', label ? `Failures (${label}):` : 'Failures:');
  for (const result of failed) {
    lines.push(`- ${result.id}: ${(result.failures ?? [result.error ?? 'unknown failure']).join(' ')}`);
  }
}

function formatResultSuffix(result) {
  if (result.error) {
    return `error=${result.error}`;
  }
  const tools = result.observed?.toolCalls?.map((toolCall) => toolCall.name).join(',') || 'none';
  const tokens = result.usage
    ? ` input=${result.usage.inputTokens ?? 'n/a'} cached=${result.usage.cachedInputTokens ?? 'n/a'} output=${result.usage.outputTokens ?? 'n/a'}`
    : '';
  return `tools=${tools} latency=${result.latencyMs}ms${tokens}`;
}

async function fetchJSON(url) {
  const response = await fetch(url);
  const payload = await response.json();
  if (!response.ok) {
    throw new Error(`HTTP ${response.status}: ${payload?.message ?? payload?.error ?? url}`);
  }
  return payload;
}

function maybeWriteReport(reportPath, report) {
  if (!reportPath) {
    return;
  }
  fs.mkdirSync(path.dirname(path.resolve(reportPath)), { recursive: true });
  fs.writeFileSync(reportPath, `${JSON.stringify(report, null, 2)}\n`);
}

function parseJSON(value) {
  try {
    return JSON.parse(value);
  } catch {
    return null;
  }
}

function normalizeBaseURL(value) {
  return new URL(value.endsWith('/') ? value : `${value}/`);
}

function parsePositiveInteger(value) {
  const parsed = Number.parseInt(value, 10);
  return Number.isFinite(parsed) && parsed > 0 ? parsed : null;
}

function parseRatio(value, fallback) {
  const parsed = Number.parseFloat(value);
  return Number.isFinite(parsed) && parsed >= 0 && parsed <= 1 ? parsed : fallback;
}

function sortObject(value) {
  return Object.fromEntries(Object.entries(value).sort(([left], [right]) => left.localeCompare(right)));
}

function formatCounts(value) {
  return Object.entries(value)
    .map(([key, count]) => `${key}:${count}`)
    .join(', ');
}

function round(value, digits) {
  const multiplier = 10 ** digits;
  return Math.round(value * multiplier) / multiplier;
}

function printHelpAndExit(exitCode = 0) {
  console.log([
    'Usage: node scripts/eval_trai_chat.mjs [options]',
    '',
    'Options:',
    '  --live                         Run against a backend instead of printing suite coverage.',
    '  --direct-openai                Run directly through the OpenAI adapter using OPENAI_API_KEY.',
    '  --base-url=http://127.0.0.1:8789',
    '  --admin-key=local-dev-admin',
    '  --model=gpt-5.4-mini',
    '  --models=gpt-5.4-mini,gpt-5.4',
    '  --category=food',
    '  --case=food-log-banana',
    '  --limit=5',
    '  --min-pass-rate=0.8',
    '  --report=tmp/trai-chat-eval.json'
  ].join('\n'));
  process.exit(exitCode);
}

class EvalHttpError extends Error {
  constructor(statusCode, payload) {
    super(payload?.message ?? `HTTP ${statusCode}`);
    this.statusCode = statusCode;
    this.payload = payload;
  }
}
