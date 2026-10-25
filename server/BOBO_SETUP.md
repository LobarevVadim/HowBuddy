# Bobo AI test setup

Bobo uses the OpenAI Responses API from the existing HowBuddy API service. The key stays on the server; it is never sent to Flutter.

## Environment variables

| Variable | Purpose | Default |
| --- | --- | --- |
| `OPENAI_API_KEY` | Secret key for the OpenAI API project | unset |
| `OPENAI_MODEL` | Responses API model identifier | `gpt-5.6-luna` |
| `BOBO_ENABLED` | Feature switch; set to `true` to enable chat | `false` |
| `BOBO_DAILY_REQUEST_LIMIT` | Per-account daily request limit | `20` |
| `BOBO_DAILY_TOKEN_BUDGET` | Per-account daily estimated token reservation | `30000` |

Never add the API key to Flutter build arguments, the web service, source control, or chat messages. For local development, add it to the ignored `server/.env` file. For Render, add it to the API web service's environment variables. Avoid enabling Bobo for all users until HowBuddy's age and consent requirements are reviewed.

## Local check

1. Copy `server/.env.example` to `server/.env`, preserve the existing database and session settings, then set `OPENAI_API_KEY` and `BOBO_ENABLED=true`.
2. Start the API with the existing local PostgreSQL database.
3. Run the Flutter app with the local API URL, sign in, open a lesson, and tap Bobo.
4. Ask a question about the current exercise. Bobo should use the selected account language, lesson, exercise, answer state, and compact account progress summary.

If Bobo is disabled or the key is missing, the API returns a friendly setup error without making a provider request. Conversation messages currently live only in the open chat panel; persistent conversations and deletion controls are a later stage.

## Render check

After deploying the code, open the `howbuddy-demo-api` service in Render and add `OPENAI_API_KEY` under **Environment**. Set `BOBO_ENABLED` to `true` only when ready to test, then save and redeploy. `OPENAI_MODEL` and the daily limits can be changed there if needed.

The API records per-account request counts and token usage in PostgreSQL. It caps each user at 20 requests and 30,000 estimated tokens per UTC day by default, sends at most 280 output tokens per response, limits chat history to 10 turns, and makes no automatic retries. Provider failures do not expose provider response bodies or credentials to the app.

This phase is a testable integration, not a production-ready public release. It does not persist conversations, provide administrator usage dashboards, or complete child/guardian consent review.
