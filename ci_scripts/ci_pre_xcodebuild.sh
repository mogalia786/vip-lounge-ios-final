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

# Increase script and Flutter verbosity within Xcode build logs
export VERBOSE_SCRIPT_LOGGING=YES
export FLUTTER_VERBOSE=true

# Move to repo root (Cloud runs scripts from ci_scripts by default)
REPO_DIR="${CI_WORKSPACE:-$(pwd)/..}"
echo "[ci_pre_xcodebuild] Using repo dir: $REPO_DIR"
cd "$REPO_DIR"

# Derive and export FLUTTER_ROOT explicitly for Xcode build phase
FLUTTER_BIN_PATH="$(command -v flutter)"
FLUTTER_ROOT_DIR="${FLUTTER_BIN_PATH%/bin/flutter}"
export FLUTTER_ROOT="$FLUTTER_ROOT_DIR"
echo "[ci_pre_xcodebuild] FLUTTER_ROOT=$FLUTTER_ROOT"

# Fetch Dart/Flutter deps
flutter pub get

# Install CocoaPods dependencies (generates Target Support Files + xcfilelist)
pushd ios
export COCOAPODS_DISABLE_INPUT_OUTPUT_PATHS=YES
pod repo update
pod install --repo-update
popd

# Ensure ios/Flutter/Generated.xcconfig exists with at least FLUTTER_ROOT set
if [ ! -f ios/Flutter/Generated.xcconfig ]; then
  echo "[ci_pre_xcodebuild] Generated.xcconfig missing; creating minimal version"
  cat > ios/Flutter/Generated.xcconfig <<EOF
// Auto-generated minimal config for CI to locate Flutter tools
FLUTTER_ROOT=$FLUTTER_ROOT
FLUTTER_APPLICATION_PATH=$REPO_DIR
FLUTTER_TARGET=lib/main.dart
FLUTTER_BUILD_DIR=build
EOF
fi

# Defensive: Create empty xcfilelist files so Xcode doesn't fail if CocoaPods omitted them
PODS_TSF_DIR="ios/Pods/Target Support Files/Pods-Runner"
mkdir -p "$PODS_TSF_DIR"
for cfg in Debug Release Profile; do
  for kind in input-files output-files; do
    f="$PODS_TSF_DIR/Pods-Runner-resources-${cfg}-${kind}.xcfilelist"
    if [ ! -f "$f" ]; then
      echo "[ci_pre_xcodebuild] Creating empty $f"
      : > "$f"
    fi
  done
done

echo "[ci_pre_xcodebuild] Done. Pods installed and Flutter deps fetched."

