#!/usr/bin/env bash
set -e
cd "$(dirname -- "${BASH_SOURCE[0]}")"

alias flutter="flutter --suppress-analytics"

flutter clean
flutter pub get

flutter build apk \
    --release \
    --dart-define=APP_BUILD_TIMESTAMP="$(date +%s)" \
    --dart-define=APP_GIT_HASH="$(git rev-parse HEAD)" \
    --split-debug-info=build/debug_info

echo "APK dir: $(pwd)/build/app/outputs/flutter-apk"
