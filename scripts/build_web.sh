#!/usr/bin/env bash
set -euo pipefail

FLUTTER_VERSION="3.41.9"
FLUTTER_ROOT="${HOME}/.cache/flutter-${FLUTTER_VERSION}"
FLUTTER_ARCHIVE="https://storage.googleapis.com/flutter_infra_release/releases/stable/linux/flutter_linux_${FLUTTER_VERSION}-stable.tar.xz"

if [[ ! -x "${FLUTTER_ROOT}/bin/flutter" ]]; then
  mkdir -p "${FLUTTER_ROOT}"
  curl --fail --location --silent --show-error "${FLUTTER_ARCHIVE}" \
    | tar -xJf - --strip-components=1 -C "${FLUTTER_ROOT}"
fi

export PATH="${FLUTTER_ROOT}/bin:${PATH}"
flutter config --no-analytics
flutter pub get
firebase_args=()
for key in FIREBASE_API_KEY FIREBASE_PROJECT_ID FIREBASE_MESSAGING_SENDER_ID \
  FIREBASE_WEB_APP_ID FIREBASE_ANDROID_APP_ID FIREBASE_IOS_APP_ID \
  FIREBASE_AUTH_DOMAIN FIREBASE_STORAGE_BUCKET FIREBASE_IOS_BUNDLE_ID \
  FIREBASE_MEASUREMENT_ID FIREBASE_WEB_VAPID_KEY; do
  value="${!key:-}"
  if [[ -n "${value}" ]]; then
    firebase_args+=("--dart-define=${key}=${value}")
  fi
done
flutter build web --release --base-href / \
  --dart-define=API_URL=https://api.howbuddy.app \
  "${firebase_args[@]}"
node scripts/configure_firebase_web.js build/web/firebase-messaging-sw.js
