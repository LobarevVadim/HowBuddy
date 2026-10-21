# HowBuddy Support Desk

The web-only support desk is deployed as its own `howbuddy-support-admin` Render static service. Use its generated `onrender.com` URL from the Render dashboard. It uses existing HowBuddy accounts, PostgreSQL, the API service, and the existing `RESEND_API_KEY`. It grants access only to account emails listed in the API's `ADMIN_EMAILS` variable. An empty allowlist denies all admins.

## Render API environment

Set these on the `howbuddy-demo-api` service:

- `ADMIN_EMAILS`: comma-separated authorized HowBuddy account emails, for example `vlobarev823@gmail.com`.
- `RESEND_INBOUND_WEBHOOK_SECRET`: the signing secret shown after creating the Resend webhook.
- Existing `RESEND_API_KEY`: used to fetch received email and send replies.

The database schema is applied automatically when the API starts. After pushing, deploy the API, main web service, and the separate support-admin static service from Render.

## Resend inbound email

1. In Resend, add and verify `howbuddy.app` as a sending domain if it is not already verified.
2. In Resend, open **Receiving** and add the domain `howbuddy.app`.
3. Resend will show an MX record. Add the record it provides in Cloudflare DNS, exactly as shown.
4. Before adding the MX record, check whether the domain already receives mail through another provider. An MX change can redirect mail for the whole domain; preserve existing MX records/flows or use a separate subdomain if you already have mailboxes.
5. Create a Resend webhook pointed at `https://howbuddy-demo-api.onrender.com/webhooks/resend` and subscribe to `email.received`.
6. Copy the webhook signing secret into Render as `RESEND_INBOUND_WEBHOOK_SECRET` and redeploy the API.
7. Send a message to each of `hello@howbuddy.app`, `support@howbuddy.app`, and `contact@howbuddy.app` to confirm delivery. Resend Receiving should show the received event; the admin inbox should then show the conversation.

The API verifies Resend's signed webhook before fetching the complete message. Provider email IDs are unique in PostgreSQL to prevent duplicate deliveries from creating duplicate messages. Messages to other addresses are ignored.

## Local run

1. Start PostgreSQL from the repository root: `docker compose up -d postgres`.
2. Copy `server/.env.example` to `server/.env`. Keep `DATABASE_URL=postgres://postgres:postgres@localhost:5432/howbuddy`; set a random `SESSION_SECRET` with at least 32 characters, your Google web client ID, and `ADMIN_EMAILS` to your administrator account email. Resend settings are optional for local browsing, but replies require `RESEND_API_KEY`.
3. In `server`, run `npm install`, then `npm start`.
4. In another terminal, from the repository root run `flutter pub get`, then `flutter run -d web-server --web-port 8081 --dart-define=API_URL=http://localhost:3000` for the main app.
5. Open `http://localhost:8081/` and create a local account using the normal sign-up flow. Add that account's email to `ADMIN_EMAILS` in `server/.env`, restart the API, then in another terminal run `cd support_admin; flutter pub get; flutter run -d web-server --web-port 8082 --dart-define=API_URL=http://localhost:3000`. Open `http://localhost:8082/` and sign in.

The local PostgreSQL database is separate from production. To create a local account, use the normal HowBuddy sign-up screen against the local API, then add that exact email to `ADMIN_EMAILS` in `server/.env` and restart the API. No production account data is copied locally.

## Content and attachment handling

Incoming email HTML is sanitized on the API using an allowlist before it is stored. The Flutter screen renders this sanitized markup as UI rather than executing it in a browser WebView. Attachments are metadata-only in PostgreSQL; the actual file remains with Resend. An administrator must explicitly click an attachment to request a short-lived HTTPS download link. Downloads are not opened automatically or embedded into message HTML.
