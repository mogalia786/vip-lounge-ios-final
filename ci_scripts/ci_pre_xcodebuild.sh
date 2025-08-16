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

# Fetch Dart/Flutter deps
flutter pub get

# Install CocoaPods dependencies (generates Target Support Files + xcfilelist)
pushd ios
pod install --repo-update
popd

echo "[ci_pre_xcodebuild] Done. Pods installed and Flutter deps fetched."
