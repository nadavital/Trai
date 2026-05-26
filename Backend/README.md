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
- `GEMINI_API_KEY`: required when `TRAI_AI_PROVIDER=gemini`
- `TRAI_ADMIN_API_KEY`: required for admin-only routes
- `ALLOW_DEV_APPLE_BYPASS`: local development only; never enable in production

## Checks

```bash
npm test
npm run verify:apple
```

Run `../scripts/check_no_source_tree_secrets.sh` before publishing repository changes that touch backend configuration or deployment scripts.
