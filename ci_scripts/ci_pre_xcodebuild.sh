#!/usr/bin/env bash
set -euxo pipefail

# Ensure Flutter is available (install stable if missing)
if ! command -v flutter >/dev/null 2>&1; then
  echo "[ci_pre_xcodebuild] Installing Flutter stable..."
  git clone https://github.com/flutter/flutter.git -b stable "$HOME/flutter"
  export PATH="$HOME/flutter/bin:$PATH"
  flutter --version
else
  echo "[ci_pre_xcodebuild] Flutter found: $(flutter --version | head -n1)"
fi

# Make sure PATH includes flutter for subsequent steps
export PATH="$HOME/flutter/bin:$PATH"

# Move to repo root (Cloud runs scripts from ci_scripts by default)
REPO_DIR="${CI_WORKSPACE:-$(pwd)/..}"
echo "[ci_pre_xcodebuild] Using repo dir: $REPO_DIR"
cd "$REPO_DIR"

# Fetch Dart/Flutter deps
flutter pub get

# Install CocoaPods dependencies (generates Target Support Files + xcfilelist)
pushd ios
export COCOAPODS_DISABLE_INPUT_OUTPUT_PATHS=YES
pod repo update
pod install --repo-update
popd

echo "[ci_pre_xcodebuild] Done. Pods installed and Flutter deps fetched."
