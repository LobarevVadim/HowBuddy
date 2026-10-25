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

If Bobo is disabled or the key is missing, the API returns a friendly setup error without making a provider request. Conversation threads are stored by account and lesson; reopening Bobo restores the last 50 messages. The model receives only the latest 10 stored turns plus refreshed server-side lesson and progress context. Clearing the conversation deletes its stored messages.

## Render check

After deploying the code, open the `howbuddy-demo-api` service in Render and add `OPENAI_API_KEY` under **Environment**. Set `BOBO_ENABLED` to `true` only when ready to test, then save and redeploy. `OPENAI_MODEL` and the daily limits can be changed there if needed.

Conversations are isolated by the authenticated account and stored with the current exercise index. The API refreshes the account language and lesson progress for each request, loads history from the server (never from a client-submitted transcript), and grades submitted answers against trusted lesson content. It displays the most recent 50 messages, sends only the newest 10 turns to the model, and keeps at most 200 messages per conversation. The API records per-account request counts and token usage in PostgreSQL. It caps each user at 20 requests and 30,000 estimated tokens per UTC day by default, sends at most 280 output tokens per response, and makes no automatic retries. Provider failures do not expose provider response bodies or credentials to the app.

This phase adds persistent lesson-scoped conversations and learner-controlled deletion. HowBuddy currently has one learner per account, so conversation isolation follows that existing account model. It still does not provide administrator usage dashboards or complete child/guardian consent review; review the age and consent requirements before making Bobo available broadly.
