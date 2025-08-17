#!/bin/bash
set -euo pipefail

echo "[ci_post_clone] Starting post-clone setup"

# Ensure Flutter is available
if ! command -v flutter >/dev/null 2>&1; then
  echo "[ci_post_clone] Flutter not found; installing stable via FVM-like script"
  git clone https://github.com/flutter/flutter.git -b stable "$HOME/flutter"
  export PATH="$HOME/flutter/bin:$PATH"
  flutter --version
else
  echo "[ci_post_clone] Flutter found: $(flutter --version 2>/dev/null | head -n1)"
fi

# Fetch dependencies
echo "[ci_post_clone] Running flutter pub get"
flutter pub get

# iOS pods
echo "[ci_post_clone] Installing CocoaPods"
cd ios
# Disable input/output paths to avoid xcfilelist references
export COCOAPODS_DISABLE_INPUT_OUTPUT_PATHS=YES
pod repo update
pod install --repo-update

echo "[ci_post_clone] Done"
