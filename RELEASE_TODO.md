# VIP Lounge iOS Release / Production TODO

Use this checklist when preparing the iOS app for TestFlight and App Store release.

## 1) Preflight sanity
- **Bundle ID**: Target `Runner` → General → Bundle Identifier matches the intended App Store app.
- **Version/Build**: Update in `pubspec.yaml`; ensure Xcode Release build picks them up. Increment build for each upload.
- **Icons & Splash**: App icon complete; native splash shows `assets/shop_front.jpg` correctly.
- **Permissions strings (Info.plist)**: Ensure every used permission has a usage string.
  - `NSCalendarsUsageDescription` (added)
  - Add others only if used: Camera, Photos, Microphone, Location, etc.
- **Cold start stability**: Confirm no crash on device from a killed state.

## 2) Push notifications (move to production)
- **Release entitlements**:
  - Create `Runner-Release.entitlements`.
  - Add key `aps-environment` with value `production`.
  - Xcode → Runner target → Build Settings → Code Sign Entitlements:
    - Debug: `Runner/Runner.entitlements` (development)
    - Release: `Runner/Runner-Release.entitlements` (production)
- **Capabilities**: Ensure `Push Notifications` and `Background Modes → Remote notifications` are present (apply to Release, too).
- **Automatic signing**: Keep ON, correct Apple Team selected. Xcode should pick a Release provisioning profile with push entitlement.
- **Firebase Cloud Messaging**:
  - APNs key/cert uploaded for the same Bundle ID.
  - In Cloud Messaging page, select the correct iOS app from the dropdown to view metrics.

## 3) Build, Archive, Upload
- **Mode**: Use Xcode Release build.
- **Archive**: Product → Archive (Any iOS Device).
- **Upload**: Organizer → Distribute App → App Store Connect → Upload.
- **Symbols**: Keep dSYMs included (default) for crash analytics.

## 4) App Store Connect metadata
- **App Privacy**: Complete data collection & tracking disclosures.
- **Export compliance**: If only standard HTTPS, you can usually answer “No” for encryption export.
- **ATT/Tracking**: If tracking/IDFA is used, implement ATT prompt and disclose in privacy.
- **Screenshots**: iPhone 6.7" and 6.1" (and iPad if universal) at minimum.
- **Description, keywords, support URL, marketing URL**: Fill accurately.
- **Age rating**: Complete questionnaire.
- **Sign in with Apple**: If you offer third‑party sign‑in for account creation, include SIWA.

## 5) TestFlight (optional but recommended)
- **Internal testers**: Available minutes after processing.
- **External testers**: First time requires Beta App Review (typically 24–48h).

## 6) Release controls
- **Release type**: Automatic, Manual, or Phased Release.
- **Regional availability**: Select target countries/regions.

## 7) Environment/config for production
- **FCM send/receive**:
  - Android: client SDK send + receive OK.
  - iOS: client SDK send disabled; sending via server/Cloud Function; receiving via APNs/FCM.
- **Endpoints**: Ensure any environment URLs (functions/API) point to production for Release builds.
- **Logging**: Reduce verbose logs for Release.

## 8) Notifications & Calendar checks (final QA)
- **iOS notifications**: Foreground and background receipt verified on real device.
- **Calendar**: Booking creates an EventKit event on iOS via `device_calendar`.
- **Permissions**: Calendar/Notifications prompts show correct copy.

## 9) Post‑release monitoring
- **Crash reports**: Xcode/Organizer + Firebase Crashlytics (if enabled).
- **Push metrics**: Firebase Cloud Messaging (pick correct iOS app in dropdown).
- **User feedback**: App Store Connect reviews and support inbox.

## 10) Common blockers
- **Wrong Bundle ID**: Ensure Xcode and Firebase iOS app entries match.
- **Missing entitlements**: Release must use `aps-environment = production`.
- **Expired APNs certificate / wrong key**: Re-upload in Firebase.
- **Incomplete App Privacy**: Will delay review.
- **Missing screenshots**: Will block submission.

---

### Quick Xcode Release steps
1. Set Scheme to `Runner` (Release), Any iOS Device.
2. Product → Clean Build Folder.
3. Product → Archive.
4. Organizer → Distribute App → App Store Connect → Upload.
5. In App Store Connect, add metadata/screenshots if first submission, then Submit for Review.

### Rollback plan
- If approval delayed: release to TestFlight external testers while addressing review feedback.
- If a critical bug is found: submit a new build; request Expedited Review only if justified.
