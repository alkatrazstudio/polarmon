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

cd build/app/outputs/flutter-apk
CUR_VER="$(git describe --tags --abbrev=0)"
mv app-release.apk "polarmon-$CUR_VER.apk"

echo
echo "APK dir: $(pwd)"
