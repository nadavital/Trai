# Trai Backend

Backend service for Trai account bootstrap, entitlement state, quota tracking, StoreKit reconciliation, and AI provider proxying.

## Local Development

```bash
cd Backend
npm install
ALLOW_DEV_APPLE_BYPASS=true \
TRAI_ENVIRONMENT=staging \
TRAI_AI_PROVIDER=openai \
OPENAI_API_KEY=your_key_here \
npm run dev
```

Use `Backend/.env.example` as the starting point for local environment configuration. Keep real API keys and admin credentials out of git.

For on-device local testing, set `HOST=0.0.0.0` and point the app's local backend URL at your Mac's LAN IP.

## Required Configuration

- `PORT`: local HTTP port, default `8789`
- `HOST`: bind host, default `127.0.0.1`
- `TRAI_ENVIRONMENT`: `staging` or `production`
- `TRAI_AI_PROVIDER`: `openai` or `gemini`, default `openai`
- `TRAI_DATABASE_DRIVER`: `sqlite` or `firestore`, default `sqlite`
- `OPENAI_API_KEY`: required when `TRAI_AI_PROVIDER=openai`
- `OPENAI_API_KEY_COACH`, `OPENAI_API_KEY_FOOD`, `OPENAI_API_KEY_WORKOUT`, `OPENAI_API_KEY_PLAN`, `OPENAI_API_KEY_EXERCISE`, `OPENAI_API_KEY_MEMORY`: optional OpenAI keys for platform-side spend attribution by feature family; each falls back to `OPENAI_API_KEY`
- `GEMINI_API_KEY`: required when `TRAI_AI_PROVIDER=gemini`
- `TRAI_ADMIN_API_KEY`: required for admin-only routes
- `ALLOW_DEV_APPLE_BYPASS`: local development only; never enable in production

## AI Provider Operations

Production should use provider-scoped secrets instead of personal API keys:

- Keep `OPENAI_API_KEY` as a project service-account key dedicated to the Trai production backend.
- Add optional feature-family OpenAI keys (`COACH`, `FOOD`, `WORKOUT`, `PLAN`, `EXERCISE`, `MEMORY`) when platform-side cost attribution by API key is needed.
- Keep `GEMINI_API_KEY` configured and tested as the standby provider.
- Do not put OpenAI admin keys in the serving Cloud Run service. Use `OPENAI_ADMIN_KEY` only from an operator shell or scheduled private job that reads usage/cost data.
- Create OpenAI project or organization spend alerts for low thresholds before the monthly/prepaid budget is exhausted.
- Use OpenAI usage and cost grouping by `project_id`, `api_key_id`, and `model` to identify spend spikes. Trai's own `ai_requests` table remains the per-feature/user-safe product ledger.

Generate an OpenAI cost/usage report without exporting user-level OpenAI data:

```bash
cd Backend
OPENAI_ADMIN_KEY=... \
OPENAI_USAGE_DAYS=7 \
npm run openai:usage
```

Optional filters:

- `OPENAI_PROJECT_IDS=proj_...`
- `OPENAI_API_KEY_IDS=key_...`
- `OPENAI_USAGE_BUCKET_WIDTH=1h` (`1m`, `1h`, or `1d`)

Provider switch checklist:

1. Confirm `/health` shows both `hasOpenAIKey` and `hasGeminiKey`.
2. Run `npm run verify:ai-adapter` locally before deploying provider-contract changes.
3. Deploy with `TRAI_AI_PROVIDER=openai` or `TRAI_AI_PROVIDER=gemini`.
4. Re-check `/health` and send one signed-in app request before treating the switch as healthy.

## Checks

```bash
npm test
npm run verify:ai-adapter
npm run verify:apple
```

Run `../scripts/check_no_source_tree_secrets.sh` before publishing repository changes that touch backend configuration or deployment scripts.
