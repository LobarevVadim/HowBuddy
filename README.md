# HowBuddy demo

This repo contains a Flutter Android/iOS app and an Express API. The API stores accounts and learning progress in PostgreSQL. The API service can restart without losing progress because it does not use the local filesystem or in-memory progress for the production data path.

## What is persisted

- Email/password accounts (passwords are hashed with bcrypt)
- Completed lessons and per-account tree unlocks
- XP totals and weekly XP history
- Hearts, emeralds, XP boosts, study dates, and streak history

The database schema is applied when `server/src/server.js` starts. `server/dev-server.js` is an in-memory local mock and must not be used for a shared demo.

## Run locally

1. Start PostgreSQL with `docker compose up -d postgres` from the repository root.
2. In `HowBuddy/server`, copy `.env.example` to `.env`, set a random `SESSION_SECRET` (at least 32 characters), then run `npm install` and `npm start`.
3. In the app, set `API_URL` for the device you're running: `http://10.0.2.2:3000` for the Android emulator, `http://localhost:3000` for the iOS simulator, or your computer's LAN IP address for a physical phone.

## Free shared demo deployment

Render can host the Flutter web app, Node API, and PostgreSQL database. This repo includes a `render.yaml` Blueprint for a free static site, free API service, and free database. It connects the database to the API and generates the session signing secret. The web build installs Flutter and points the app at the hosted API. In Render, create a Blueprint from the GitHub repo and apply it, or sync the existing Blueprint to add the `howbuddy-demo-web` static site.

After the static site deploys, share `https://howbuddy.app`. Friends can open it in iPhone Safari and optionally choose **Share > Add to Home Screen**.

The API creates or updates its PostgreSQL tables when it starts. After the API Web Service deploys, open `https://howbuddy-demo-api.onrender.com/health`. It should return `{"ok":true,"database":"connected"}`. Then build the phone app with that HTTPS URL:

```sh
flutter build apk --dart-define=API_URL=https://howbuddy-demo-api.onrender.com
flutter build ios --dart-define=API_URL=https://howbuddy-demo-api.onrender.com
```

Use the generated Android APK for sideloading. iOS requires a Mac with Xcode to build and sign. Apple's free developer account supports testing on your own device from Xcode; sharing installs with friends through TestFlight requires Apple Developer Program membership, currently USD $99/year. [Apple membership details](https://developer.apple.com/programs/)

Render static sites are free with no trial period, subject to Render's included bandwidth and build-pipeline limits. The free API service sleeps after 15 minutes idle and may take about a minute to wake. The free PostgreSQL database has 1 GB storage, no backups, and expires after 30 days; export the database before that date if the demo data must be retained. [Render free plan limits](https://render.com/docs/free)

## What is needed to invite your friends

- A Render account connected to the GitHub repository, then create the database and API using the settings above.
- The deployed API HTTPS URL to build into Android/iOS installs.
- Android: share the APK directly for sideloading.
- iOS: either install from Xcode on each device or use a paid Apple Developer account to distribute through TestFlight.

Google sign-in on the web uses Google Identity Services, and the API verifies each Google ID token before creating or opening an account. Add the deployed web origin to the web OAuth client's authorized JavaScript origins, and add invited Google accounts as test users while the consent screen is in testing mode. Native Android Google sign-in also needs an Android OAuth client registered with the app package name and signing certificate SHA-1; native iOS needs an iOS OAuth client and URL scheme. Apple sign-in is not configured. Never share or commit OAuth client secrets.
