#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "${BASH_SOURCE[0]}")/.."

flutter devices
flutter build ios --simulator --debug "$@" --dart-define=MOSAIC_USE_MANUAL_NFC=true
xcrun simctl install booted build/ios/iphonesimulator/Runner.app
xcrun simctl launch booted com.mosaicmahjong.mosaic

if [[ -n "${MOSAIC_SIMULATOR_SCREENSHOT_PATH:-}" ]]; then
  mkdir -p "$(dirname "${MOSAIC_SIMULATOR_SCREENSHOT_PATH}")"
  xcrun simctl io booted screenshot "${MOSAIC_SIMULATOR_SCREENSHOT_PATH}"
fi
