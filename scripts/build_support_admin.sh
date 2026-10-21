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
cd support_admin
flutter pub get
flutter build web --release --base-href / \
  --dart-define=API_URL=https://howbuddy-demo-api.onrender.com
