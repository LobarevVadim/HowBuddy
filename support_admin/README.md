# HowBuddy Support Admin

This is a separate Flutter Web project and Render static service. It is not imported by the main Flutter app and its HTML-rendering dependency is not part of the Android or iOS app's dependency graph.

## Deploy

The Render blueprint creates a separate static service named `howbuddy-support-admin`, which receives its own `onrender.com` URL. It calls the existing HowBuddy API and uses its existing database and Resend integration. No custom domain is assigned, so the service can remain separate without adding another custom domain to Render.

After the first deploy, add the generated admin service origin as an authorized JavaScript origin for the existing Google OAuth web client if administrators use Google sign-in. Email and password sign-in works through existing HowBuddy accounts. The API checks the account email against `ADMIN_EMAILS` on every admin request.

## Local run

From the repository root:

```powershell
cd support_admin
flutter pub get
flutter run -d web-server --web-port 8082 --dart-define=API_URL=http://localhost:3000
```

The API must be running locally and `ADMIN_EMAILS` must include the signed-in account email.
