# iOS + Firebase (FCM/Firestore) A–Z Setup Guide

Use this repeatable checklist for any new iOS Flutter app you build. Replace placeholders in ALL CAPS with your actual values.

## 0) Prerequisites
- **Apple Developer**: Active membership on developer.apple.com.
- **Apple ID**: Added to Xcode (Xcode → Settings → Accounts).
- **Firebase Project**: You can reuse an existing project or create a new one.
- **Flutter**: Stable channel; Xcode and CocoaPods installed.

## 1) Name and Bundle ID
- Choose: APP NAME (e.g., "VIP Lounge"), BUNDLE ID (e.g., `com.yourcompany.yourapp`).
- In Xcode: open `ios/Runner.xcworkspace` → Runner target → General → Identity → set Bundle Identifier.

## 2) App ID + Capabilities in Apple Developer
- Go to Apple Developer → Certificates, Identifiers & Profiles → Identifiers.
- Create a new App ID (type App) with your **Bundle ID**.
- Enable required capabilities now (you can add more later):
  - **Push Notifications**
  - **Background Modes** (Remote notifications if you will receive push in background)
  - Any others you need (e.g., Sign In with Apple, Maps, etc.)

## 3) Certificates and Provisioning Profiles
Preferred (Automatic):
- In Xcode → Runner target → Signing & Capabilities:
  - Check **Automatically manage signing**.
  - Select your **Team**.
  - Xcode will create provisioning profiles for Debug/Release.

Optional (Manual):
- Apple Developer → Certificates: create an iOS Development certificate and an iOS Distribution certificate.
- Apple Developer → Profiles: create Development and Distribution profiles for your App ID.
- Download and install in Keychain and Xcode, then set Runner to Manual signing.

## 4) APNs for Push Notifications (recommended: Auth Key)
- Apple Developer → Keys → Add (+) → Select **Apple Push Notifications service (APNs)**.
- Download the **Auth Key (.p8)** and note **Key ID**.
- You’ll also need your **Team ID** (shown in the top-right of the Apple Developer page or in Membership).

Upload to Firebase:
- Firebase Console → Project Settings → Cloud Messaging → iOS app → **APNs Authentication Key**.
- Upload the `.p8`, enter **Key ID** and **Team ID**.
- This works for both development and production; simpler than certificates.

Alternative (Certificates):
- Create APNs Development and Production certificates, upload both to Firebase. Auth Key is preferred.

## 5) Add iOS app in Firebase
- Firebase Console → Project Settings → Your apps → Add app → iOS.
- Enter the **iOS bundle ID** (must match Xcode exactly).
- Download `GoogleService-Info.plist` and add it to `ios/Runner/` in Xcode (ensure it’s in the Runner target).

## 6) Flutter iOS project configuration
- Ensure Firebase packages are added in `pubspec.yaml` (e.g., `firebase_core`, `firebase_messaging`, `cloud_firestore`).
- Run `flutter pub get`.
- iOS platform min version in `ios/Podfile` (e.g., `platform :ios, '14.0'`).

AppDelegate basics (Swift):
- Configure Firebase early and register for APNs.
- Set `UNUserNotificationCenter.current().delegate = self`.
- Bridge APNs token to FCM: `Messaging.messaging().apnsToken = deviceToken` in `didRegisterForRemoteNotificationsWithDeviceToken`.

## 7) Entitlements per build config
- Create two entitlements files or one with dynamic setting:
  - Debug: `aps-environment = development`
  - Release: `aps-environment = production`
- Xcode → Runner target → Build Settings → Code Sign Entitlements:
  - Debug → `Runner/Runner.entitlements`
  - Release → `Runner/Runner-Release.entitlements`

## 8) Info.plist permissions
Add only what you use (examples):
- `NSCalendarsUsageDescription` → “We use your calendar to add bookings.”
- `NSUserNotificationUsageDescription` (iOS 12 and lower) if needed by legacy.
- `NSCameraUsageDescription`, `NSPhotoLibraryUsageDescription`, `NSLocationWhenInUseUsageDescription`, etc., as applicable.

## 9) Enable Capabilities in Xcode
- Xcode → Runner target → Signing & Capabilities → Add:
  - **Push Notifications**
  - **Background Modes** → check **Remote notifications** (and others as needed)
  - Any other required capabilities (e.g., Keychain Sharing for certain auth flows).

## 10) Firestore and Security
- Firebase Console → Firestore Database → Create database.
- Start in **Test Mode** for development; switch to production rules before release.
- Define proper Firestore Security Rules for your data model (least privilege, user-based constraints).

## 11) Local and Remote Notifications
- Request notification permission at app start or at a relevant moment.
- For FCM on iOS, always send via server/APNs (client `sendMessage` is not supported on iOS).
- Foreground presentation: implement `userNotificationCenter(_:willPresent:)`.

## 12) Building and Testing
- `flutter clean` → `flutter pub get`.
- iOS: open Xcode, select a real device → Product → Run (Debug).
- Look for APNs token log and Firebase config log in the Xcode console.

## 13) TestFlight
- Product → Archive (Any iOS Device, Release).
- Organizer → Distribute App → App Store Connect → Upload.
- TestFlight:
  - Internal testers: available within minutes.
  - External testers: requires Beta App Review (24–48h typical).

## 14) App Store submission
- App Store Connect → Create App (if first time), fill metadata.
- Screenshots (6.7", 6.1" at minimum), description, keywords, support URL, privacy policy.
- App Privacy (data collection & tracking) and export compliance.
- Submit for Review. New apps: 1–3 business days typical.

## 15) Release controls
- Choose Automatic, Manual, or Phased Release.
- Select countries/regions.

## 16) Post‑release
- Monitor crashes (Organizer, Crashlytics).
- Monitor push delivery and Firestore metrics.
- Prepare hotfix updates (increment build number).

---

### Quick Push Checklist (recap)
1) Bundle ID consistent in Xcode and Firebase.
2) APNs key (.p8) uploaded to Firebase (Key ID + Team ID).
3) Capabilities: Push + Background Modes (Remote notifications).
4) Entitlements: Debug = development, Release = production.
5) App initializes Firebase, registers for APNs, sets `Messaging.messaging().apnsToken`.

### Notes for Multi‑app reuse
- Create one Firebase project per app or segregate via multiple iOS apps in a single project (ensure correct bundle per app).
- Bookmark the Cloud Messaging page with the correct iOS app dropdown selection for each app.
- Consider using separate APNs keys per account; one key can be used across multiple apps within the same Apple Team.
