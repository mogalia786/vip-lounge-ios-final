#!/bin/bash
set -euo pipefail

echo "[ci_pre_xcodebuild] Ensuring Flutter & CocoaPods are ready"

# Ensure Flutter is on PATH
if ! command -v flutter >/dev/null 2>&1; then
  if [ -d "$HOME/flutter" ]; then
    export PATH="$HOME/flutter/bin:$PATH"
  else
    echo "[ci_pre_xcodebuild] Flutter not found; installing stable"
    git clone https://github.com/flutter/flutter.git -b stable "$HOME/flutter"
    export PATH="$HOME/flutter/bin:$PATH"
  fi
fi
flutter --version

# Fetch Dart/Flutter deps
flutter pub get

# Prepare iOS pods
pushd ios >/dev/null
export COCOAPODS_DISABLE_INPUT_OUTPUT_PATHS=YES
pod install --repo-update
popd >/dev/null

echo "[ci_pre_xcodebuild] Ready"
