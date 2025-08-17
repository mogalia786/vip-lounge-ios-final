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

# Move to repo root (Cloud runs from ci_scripts by default)
REPO_DIR="${CI_WORKSPACE:-$(pwd)}"
echo "[ci_pre_xcodebuild] Using repo dir: $REPO_DIR"
cd "$REPO_DIR"

# Derive and export FLUTTER_ROOT for Xcode build phases
FLUTTER_BIN_PATH="$(command -v flutter)"
FLUTTER_ROOT_DIR="${FLUTTER_BIN_PATH%/bin/flutter}"
export FLUTTER_ROOT="$FLUTTER_ROOT_DIR"
echo "[ci_pre_xcodebuild] FLUTTER_ROOT=$FLUTTER_ROOT"

# Fetch Dart/Flutter deps
flutter pub get

# Prepare iOS pods
pushd ios >/dev/null
export COCOAPODS_DISABLE_INPUT_OUTPUT_PATHS=YES
pod install --repo-update
popd >/dev/null

# Ensure ios/Flutter/Generated.xcconfig exists for Flutter scripts
if [ ! -f ios/Flutter/Generated.xcconfig ]; then
  echo "[ci_pre_xcodebuild] Creating minimal ios/Flutter/Generated.xcconfig"
  cat > ios/Flutter/Generated.xcconfig <<EOF
// Minimal auto-generated for CI
FLUTTER_ROOT=$FLUTTER_ROOT
FLUTTER_APPLICATION_PATH=$REPO_DIR
FLUTTER_TARGET=lib/main.dart
FLUTTER_BUILD_DIR=build
EOF
fi

echo "[ci_pre_xcodebuild] Ready"
