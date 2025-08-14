# VIP Lounge iOS: Clean Build + Install Playbook (All Plugins Enabled)

This document captures the exact build and installation steps we used successfully, plus the key project toggles that affected stability. It is intended as a reusable reference for other Flutter iOS apps.

## Prerequisites
- Xcode 16+ with command line tools
- CocoaPods up-to-date:
  - `pod --version`
  - `pod repo update`
- Device connected and trusted (Developer Mode enabled)
- Flutter SDK installed and on PATH

## One-time project notes
- Splash: native splash is generated via `flutter_native_splash` from `flutter_native_splash.yaml`.
- App entry: `lib/main.dart` removes splash after first frame.
- Login routing: handled in `lib/app.dart`; login defers routing to provider state to avoid bounce after logout.
- iOS Calendar: native `CalendarBridge` (EventKit) is instantiated in `ios/Runner/AppDelegate.swift` and bridged over `MethodChannel` `com.vip/calendar`.
- Plugins: all enabled in `ios/Runner/GeneratedPluginRegistrant.m` except `connectivity_plus` which may be toggled off for iOS 18 cold-boot stability.

## Clean build steps (repeatable)

1) Fetch dependencies
```bash
flutter pub get
```

2) Clean Flutter and Xcode intermediates
```bash
flutter clean
```

3) Reset CocoaPods state (optional but recommended when changing plugins)
```bash
rm -rf ios/Pods ios/Podfile.lock ios/Runner.xcworkspace
```

4) Update CocoaPods repos
```bash
(cd ios && pod repo update)
```

5) Reinstall pods
```bash
(cd ios && pod install)
```

6) Build for device (Profile configuration)
- Replace DEVICE_ID with your actual device id (example used below):
```bash
/usr/bin/arch -arm64e xcrun xcodebuild \
  -workspace ios/Runner.xcworkspace \
  -scheme Runner \
  -configuration Profile \
  -destination id=00008030-000A29EC1A87802E \
  ONLY_ACTIVE_ARCH=YES ARCHS=arm64 build
```

7) Install the built app to device
- Path example uses the DerivedData folder created by the previous step. Adjust if your DerivedData path differs.
```bash
/usr/bin/arch -arm64e xcrun devicectl device install app \
  --device 00008030-000A29EC1A87802E \
  "/Users/faizelmogalia/Library/Developer/Xcode/DerivedData/Runner-gasywfeapfdkwdfsqktwyodlmusf/Build/Products/Profile-iphoneos/Runner.app"
```

## Useful variations

- Build (Release) for App Store/TestFlight validation (not installing):
```bash
/usr/bin/arch -arm64e xcrun xcodebuild \
  -workspace ios/Runner.xcworkspace \
  -scheme Runner \
  -configuration Release \
  -destination 'generic/platform=iOS' \
  ONLY_ACTIVE_ARCH=YES ARCHS=arm64 clean build
```

- Determine build output path quickly:
```bash
/usr/bin/arch -arm64e xcrun xcodebuild \
  -workspace ios/Runner.xcworkspace \
  -scheme Runner \
  -configuration Profile \
  -destination id=00000000-000000000 \
  -showBuildSettings | grep -E "TARGET_BUILD_DIR =|WRAPPER_NAME ="
```

## Live device logs (for diagnosing white screen / hangs)
- Start console streaming and then launch the app on device:
```bash
xcrun devicectl device console --device 00008030-000A29EC1A87802E
```

## Plugin toggles (if first cold boot hangs)
- File: `ios/Runner/GeneratedPluginRegistrant.m`
- We observed iOS 18 cold-boot white screen with `connectivity_plus`. To disable just this plugin:
  - Comment out the import and registration lines for `ConnectivityPlusPlugin`.
  - Leave all other plugins enabled.

Example snippet (disabled):
```objc
// #if __has_include(<connectivity_plus/ConnectivityPlusPlugin.h>)
// #import <connectivity_plus/ConnectivityPlusPlugin.h>
// #else
// @import connectivity_plus;
// #endif
// [ConnectivityPlusPlugin registerWithRegistrar:[registry registrarForPlugin:@"ConnectivityPlusPlugin"]];
```

## iOS Calendar bridge usage
- Native bridge initialized in `ios/Runner/AppDelegate.swift`:
  - Holds a strong reference: `var calendarBridge: CalendarBridge?`
  - Initializes after plugin registration using the `FlutterViewController` `binaryMessenger`.
- Dart call site via `lib/core/services/ios_calendar_channel.dart`:
```dart
final ok = await IOSCalendarChannel.addEvent(
  title: '...',
  start: DateTime.now(),
  end: DateTime.now().add(const Duration(hours: 1)),
  description: '...',
  location: '...',
  reminderMinutes: 15,
);
```

## Splash and login notes
- Splash is native until first frame; Flutter removes it in a post-frame callback in `lib/main.dart`.
- Any additional GIF splash is controlled by `lib/app.dart` and times out quickly to avoid stalls.
- Login navigates to `'/'` after `AppAuthProvider` updates to prevent a first-attempt bounce.

## Troubleshooting tips
- If `pod install` errors about missing `Generated.xcconfig`, run `flutter pub get` again before `pod install`.
- If codesign issues occur, ensure Xcode signing settings are valid for the selected configuration (Debug/Profile/Release) and that push entitlements remain intact.
- If the app hangs on a white screen on first cold boot, try disabling `connectivity_plus` registration only. Re-enable once stable.
- Always use `Runner.xcworkspace` (not `Runner.xcodeproj`) when building with Xcode directly.

---
Last updated: 2025-08-14
