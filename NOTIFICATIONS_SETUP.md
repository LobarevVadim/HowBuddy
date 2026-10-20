# HowBuddy push notifications

## Delivery design

The authenticated Flutter app registers its Firebase Cloud Messaging token, language, and IANA time zone with the API. Notification preferences, devices, and delivery claims are stored in PostgreSQL, so the schedule survives app and server restarts. Logging out unregisters only that device; other signed-in devices remain registered. A device logging back in registers its token again. Turning notifications off is account-wide.

The API scheduler checks local time at 9:00 a.m., noon, and 6:00 p.m. It uses the current IANA time-zone rules, so daylight-saving changes are applied by the time-zone database rather than by fixed UTC offsets. It allows a 20-minute delivery window, chooses one eligible message per slot, honors quiet hours and the three-message local-day cap, and records a unique `(account, local date, notification type)` claim before sending. The most recently active device updates the account time zone; all devices on that account therefore receive notifications according to that one time zone.

Daily/missed-yesterday reminders and inactivity/streak rules are evaluated from completed lessons in `lesson_progress`. Curiosity messages choose a reachable topic from the selected language's lesson JSON and carry its topic ID for navigation. Inactivity copy is provided for days 2–41. Returning users receive only the current day's eligible message; the scheduler does not replay old reminders.

The `dev-server.js` in-memory prototype does not send scheduled pushes. Use the PostgreSQL API in `server/src/server.js` for persistent notification delivery.

## Email copies during the owner-only test

Every eligible scheduled notification independently attempts a push and an email with the same localized title and message. A failure or missing device token for one channel does not block the other. For the test phase, `server/src/notification_email.js` only permits delivery to `vlobarev823@gmail.com`; other account addresses are filtered out. Remove that allowlist check only when you are ready to email all users.

Email delivery uses the Resend HTTP API. Create a Resend API key and configure a sender address that Resend permits (verify your sending domain if required). Add these values to the Render **API** service only:

- `RESEND_API_KEY` — keep this secret; never commit it or put it in the web service.
- `NOTIFICATION_EMAIL_FROM` — a permitted sender, for example `HowBuddy <notifications@your-verified-domain.example>`.

The Profile notification test reports separately whether the push and email were sent. If the email provider is not configured or rejects a message, push delivery continues and the API logs the email failure. Scheduled email is also attempted independently when the notification policy chooses an eligible message. See [Resend's Express guide](https://resend.com/express) and [domain setup](https://resend.com/docs/dashboard/domains/introduction).

## Firebase and hosting setup

1. In Firebase Console, create or select a project and enable **Cloud Messaging**.
2. Register the Android application using the Android application ID from `android/app/build.gradle.kts` and the iOS application using the Xcode bundle ID. Both currently use `com.example.hello`; change those IDs before registering if you intend to publish under a different app identity. Register a Web app too. Copy the project ID, sender ID, API key, and each platform's app ID from Project settings.
3. For iOS, add an APNs authentication key in Firebase Console under Project settings → Cloud Messaging. In Xcode enable Push Notifications and Background Modes → Remote notifications for the iOS app. iOS push requires signing and a real Apple device; the iOS simulator cannot receive APNs pushes.
4. In Firebase Console → Project settings → Cloud Messaging, create or copy the Web Push certificate key pair (VAPID key). Browser push needs HTTPS and the user must grant browser notification permission. It is not available in every browser/private-browsing mode.
5. Create a Firebase service account with Firebase Cloud Messaging send access. In Render, set `FIREBASE_SERVICE_ACCOUNT_JSON` on the API service to the complete service-account JSON. Keep this credential private; do not commit it or put it in the web service.
6. Set the `FIREBASE_*` values listed on the Render static web service in its Environment settings. The web build embeds the public Firebase app configuration and VAPID key and writes the web messaging service worker. These values are expected to be public client configuration; the service-account JSON is not.
7. Set `FIREBASE_ANDROID_APP_ID`, `FIREBASE_IOS_APP_ID`, and `FIREBASE_IOS_BUNDLE_ID` for local Android/iOS builds as well. Pass the same `FIREBASE_*` values to Flutter using `--dart-define=NAME=value`. Build iOS on macOS with Xcode. The Dart Firebase options are used directly, so separate `google-services.json`/`GoogleService-Info.plist` files are not required by this configuration.
8. Deploy the API so it applies the notification tables in `server/schema.sql`. Render generates `NOTIFICATION_CRON_SECRET` from the blueprint. Copy its value from the API service's Environment page into a trusted external scheduler.
9. Configure that scheduler to send an HTTP `POST` every five minutes to `https://howbuddy-demo-api.onrender.com/notifications/tick` with header `X-Notification-Cron-Secret: <the Render secret>`. The API also checks once a minute while running. The external tick helps wake a free Render instance, but cold starts or a sleeping host can still delay delivery; use a continuously running scheduler/API for dependable timing.

## Test now

- Open Profile → Notifications, enable push, and allow the device/browser permission prompt.
- Use **Send test notification now** to send an immediate test to the registered device(s). This exercises Firebase delivery without waiting for a scheduled reminder.
- Run the scheduling rules without waiting for calendar days with `cd server` then `npm test`. These tests use fixed dates and cover inactivity days 2–41, streaks, local time/DST, suppression, caps, deduplication, and target topic data.
- For an end-to-end scheduled send, set up Firebase and the cron tick, then temporarily set a test account's `time_zone` so its local clock enters a delivery window. Restore its time zone afterwards. Do this only on a test account.

Notifications are opt-in by default. Android 13+ also asks for notification permission. If Firebase client values, APNs/Web Push credentials, or the server service account are missing, the app reports that setup is needed and the scheduler does not send remote notifications.
