const adminKey = process.env.OPENAI_ADMIN_KEY;

if (!adminKey) {
  console.error('Missing OPENAI_ADMIN_KEY. Use an OpenAI admin API key with Usage read access.');
  process.exit(1);
}

const nowSeconds = Math.floor(Date.now() / 1000);
const days = parsePositiveInteger(process.env.OPENAI_USAGE_DAYS, 7);
const startTime = parseInteger(process.env.OPENAI_USAGE_START_TIME, nowSeconds - (days * 24 * 60 * 60));
const endTime = parseInteger(process.env.OPENAI_USAGE_END_TIME, nowSeconds);
const projectIDs = parseCSV(process.env.OPENAI_PROJECT_IDS);
const apiKeyIDs = parseCSV(process.env.OPENAI_API_KEY_IDS);

const commonFilters = {
  start_time: startTime,
  end_time: endTime,
  limit: process.env.OPENAI_USAGE_LIMIT ?? '31'
};
if (projectIDs.length > 0) {
  commonFilters.project_ids = projectIDs;
}
if (apiKeyIDs.length > 0) {
  commonFilters.api_key_ids = apiKeyIDs;
}

const [costs, usage] = await Promise.all([
  fetchOpenAI('/organization/costs', {
    ...commonFilters,
    bucket_width: '1d',
    group_by: ['project_id', 'api_key_id', 'line_item']
  }),
  fetchOpenAI('/organization/usage/completions', {
    ...commonFilters,
    bucket_width: process.env.OPENAI_USAGE_BUCKET_WIDTH ?? '1h',
    group_by: ['project_id', 'api_key_id', 'model', 'service_tier']
  })
]);

const costRows = flattenBuckets(costs);
const usageRows = flattenBuckets(usage);
const totalCost = costRows.reduce((sum, row) => sum + Number(row.amount?.value ?? 0), 0);
const totalRequests = usageRows.reduce((sum, row) => sum + Number(row.num_model_requests ?? 0), 0);
const totalInputTokens = usageRows.reduce((sum, row) => sum + Number(row.input_tokens ?? 0), 0);
const totalOutputTokens = usageRows.reduce((sum, row) => sum + Number(row.output_tokens ?? 0), 0);
const totalCachedInputTokens = usageRows.reduce((sum, row) => sum + Number(row.input_cached_tokens ?? 0), 0);

console.log(JSON.stringify({
  range: {
    startTime,
    endTime,
    days,
    bucketWidth: process.env.OPENAI_USAGE_BUCKET_WIDTH ?? '1h'
  },
  filters: {
    projectIDs,
    apiKeyIDs
  },
  totals: {
    costUSD: roundCurrency(totalCost),
    modelRequests: totalRequests,
    inputTokens: totalInputTokens,
    outputTokens: totalOutputTokens,
    cachedInputTokens: totalCachedInputTokens
  },
  costByProject: summarizeCosts(costRows, 'project_id'),
  costByAPIKey: summarizeCosts(costRows, 'api_key_id'),
  costByLineItem: summarizeCosts(costRows, 'line_item'),
  usageByModel: summarizeUsage(usageRows, 'model'),
  usageByAPIKey: summarizeUsage(usageRows, 'api_key_id')
}, null, 2));

async function fetchOpenAI(path, params) {
  const url = new URL(`https://api.openai.com/v1${path}`);
  for (const [key, value] of Object.entries(params)) {
    if (Array.isArray(value)) {
      for (const item of value) {
        url.searchParams.append(key, item);
      }
    } else if (value != null && value !== '') {
      url.searchParams.set(key, String(value));
    }
  }

  const response = await fetch(url, {
    headers: {
      Authorization: `Bearer ${adminKey}`,
      'Content-Type': 'application/json'
    }
  });

  if (!response.ok) {
    const body = await response.text();
    throw new Error(`${path} failed with ${response.status}: ${body}`);
  }

  return await response.json();
}

function flattenBuckets(page) {
  return (page?.data ?? []).flatMap((bucket) =>
    (bucket.results ?? []).map((result) => ({
      ...result,
      bucket_start_time: bucket.start_time,
      bucket_end_time: bucket.end_time
    }))
  );
}

function summarizeCosts(rows, key) {
  return summarize(rows, key, (row) => Number(row.amount?.value ?? 0), 'costUSD');
}

function summarizeUsage(rows, key) {
  const groups = new Map();
  for (const row of rows) {
    const groupKey = row[key] ?? 'unattributed';
    const existing = groups.get(groupKey) ?? {
      [key]: groupKey,
      modelRequests: 0,
      inputTokens: 0,
      outputTokens: 0,
      cachedInputTokens: 0
    };
    existing.modelRequests += Number(row.num_model_requests ?? 0);
    existing.inputTokens += Number(row.input_tokens ?? 0);
    existing.outputTokens += Number(row.output_tokens ?? 0);
    existing.cachedInputTokens += Number(row.input_cached_tokens ?? 0);
    groups.set(groupKey, existing);
  }
  return [...groups.values()].sort((a, b) => b.modelRequests - a.modelRequests);
}

function summarize(rows, key, valueForRow, valueName) {
  const groups = new Map();
  for (const row of rows) {
    const groupKey = row[key] ?? 'unattributed';
    groups.set(groupKey, (groups.get(groupKey) ?? 0) + valueForRow(row));
  }
  return [...groups.entries()]
    .map(([groupKey, value]) => ({ [key]: groupKey, [valueName]: roundCurrency(value) }))
    .sort((a, b) => b[valueName] - a[valueName]);
}

function parseCSV(value) {
  return String(value ?? '')
    .split(',')
    .map((item) => item.trim())
    .filter(Boolean);
}

function parseInteger(value, fallback) {
  const parsed = Number.parseInt(String(value ?? ''), 10);
  return Number.isFinite(parsed) ? parsed : fallback;
}

function parsePositiveInteger(value, fallback) {
  const parsed = parseInteger(value, fallback);
  return parsed > 0 ? parsed : fallback;
}

function roundCurrency(value) {
  return Math.round(value * 1000000) / 1000000;
}
