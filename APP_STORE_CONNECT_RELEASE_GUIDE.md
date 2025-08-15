# iOS App Release Guide — VIP Lounge

Last updated: 14 August 2025

This guide documents the end‑to‑end process to upload, validate, and release the iOS app to the Apple App Store, including TestFlight and App Store Connect links.

---

## 1) Prerequisites

- Apple Developer Program account with access to Team ID: `ZKLHL9YWUS` (Mogalia Mobile Engines)
- App Store Connect app created with your bundle ID (unchanged)
- Xcode 15/16 installed on macOS
- Flutter SDK and CocoaPods working (for Flutter projects)
- GitHub account `mogalia786` with repo: https://github.com/mogalia786/vip-lounge-ios-final

Useful links:
- App Store Connect: https://appstoreconnect.apple.com
- Apple Developer: https://developer.apple.com
- Transporter (alternative upload): https://apps.apple.com/us/app/transporter/id1450874784

---

## 2) Privacy Policy URL (GitHub Pages)

We host the privacy policy via GitHub Pages.

1. File location in repo: `docs/privacy-policy.html` (already added)
2. Enable GitHub Pages:
   - GitHub → Repo → Settings → Pages
   - Source: "Deploy from a branch"
   - Branch: `main`, Folder: `/docs`
   - Save and wait ~1–3 minutes
3. Your URL: `https://mogalia786.github.io/vip-lounge-ios-final/privacy-policy.html`
4. Use this URL in App Store Connect → App Privacy (and optionally Support URL).

---

## 3) App configuration (Info.plist)

Key iPhone‑only and background settings in `ios/Runner/Info.plist`:
- `UIDeviceFamily = [1]` (iPhone only)
- `UIRequiresFullScreen = true` (avoids iPad multitasking requirements)
- `UIBackgroundModes` should include only the modes you truly need. Current set:
  - `remote-notification`
  - `location`
  - `fetch`
  - (Removed `processing` to avoid BGTaskScheduler identifier requirement)
- Permissions strings:
  - `NSCalendarsUsageDescription`
  - `NSRemindersUsageDescription`
  - `NSLocationWhenInUseUsageDescription`

Notes:
- If you ever add `processing` back, you must also add `BGTaskSchedulerPermittedIdentifiers` and schedule tasks correctly in code.

---

## 4) Signing and Certificates

Xcode needs to be signed into your Apple ID to fetch/create provisioning profiles.

- Xcode → Settings (Preferences) → Accounts → add Apple ID → complete 2FA
- Ensure Team: `ZKLHL9YWUS` appears
- Open `ios/Runner.xcworkspace` in Xcode → Target `Runner` → Signing & Capabilities:
  - Team: `ZKLHL9YWUS`
  - Automatically manage signing: ON
  - Bundle Identifier: unchanged
  - Push Notifications capability should be present

---

## 5) Build number and version

- Flutter project uses values from `pubspec.yaml` synchronized to iOS
- Update version/build as needed (e.g., `1.0.0+1`)
- In Xcode, ensure the Marketing Version and Build match your intended release

---

## 6) Archiving in Xcode

1. Open `ios/Runner.xcworkspace`
2. Scheme: `Runner`; Destination: `Any iOS Device (arm64)`
3. Product → Clean Build Folder
4. Product → Archive
5. When the archive completes, Organizer opens automatically

Troubleshooting:
- If you see code sign issues, recheck Accounts login and Team selection
- If you see build failures, run `flutter clean && flutter pub get && pod install` and retry

---

## 7) Validate & Upload to App Store Connect

In Xcode Organizer → Archives:
- Select the latest archive
- (Optional) Validate App — catches common metadata/code sign issues early
- Distribute App → App Store Connect → Upload
- Proceed through dialogs; allow keychain prompts
- On success, Xcode shows “Upload Successful”

Alternative: Transporter App
- Export `.ipa` then drag into Transporter and Deliver

---

## 8) After Upload — Processing and TestFlight

- App Store Connect: https://appstoreconnect.apple.com
- My Apps → Your App → TestFlight tab
  - Status will be “Processing” (typically 5–30 minutes, sometimes longer)
  - Once done, build is available for **Internal Testing** immediately (no review)
  - For **External Testing**, submit the build in TestFlight for review

---

## 9) App Store Listing (Prepare for Submission)

In App Store Connect → My Apps → App Store tab (select the version):
- **App Name**: Cellular citi VIP Premium Lounge bookings (per your choice)
- **Privacy Policy URL**: `https://mogalia786.github.io/vip-lounge-ios-final/privacy-policy.html`
- **Support URL**: use same domain or another support page
- **App Privacy questionnaire**: declare data collection (Auth identifiers, push tokens, analytics)
- **Category, Age Rating**
- **Screenshots** (iPhone only):
  - iPhone 6.7" (1290×2796)
  - iPhone 6.5" (1242×2688) or 5.5" (1242×2208) if you prefer the older set
  - Minimum 1 per size (Apple recommends 3–5)
- **Description, Keywords, What’s New** (for updates)

---

## 10) Submit for Review and Release

- Once the build has finished processing, select it on the Version page
- Click **Submit for Review**
- Status flow:
  - `Waiting For Review` → `In Review` → `Ready for Sale` (approved)
- Release options:
  - Manual release
  - Automatic release upon approval
  - Scheduled release

---

## 11) Common Validation Errors & Fixes

- Orientation/iPad multitasking error:
  - Symptom: "must include all orientations for iPad multitasking"
  - Fix: Set `UIRequiresFullScreen=true` and ensure `UIDeviceFamily=[1]` for iPhone‑only app
- BGTaskScheduler error:
  - Symptom: `BGTaskSchedulerPermittedIdentifiers` required when using `processing`
  - Fix: Remove `processing` from `UIBackgroundModes`, or add permitted identifiers and code to schedule tasks
- Credentials expired during Validate/Upload:
  - Fix: Xcode → Accounts → Sign out/in; complete 2FA; retry

---

## 12) Monitoring Progress

- App Store Connect → My Apps → Your App:
  - **TestFlight** tab: confirms build Processing → Testing availability
  - **App Store** tab: version status (Prepare for Submission, Waiting for Review, In Review, Ready for Sale)
  - **Activity** tab: build history and processing logs

---

## 13) Post‑Release

- Track crashes and analytics (Crashlytics, App Analytics)
- Respond to reviews, plan updates, and increment version/build

---

## 14) Quick Checklist

- [ ] Privacy Policy URL live via GitHub Pages
- [ ] iPhone‑only: `UIDeviceFamily=[1]`, `UIRequiresFullScreen=true`
- [ ] Background modes limited to what’s needed (no `processing` unless configured)
- [ ] Signed into Xcode with Apple ID (Team: ZKLHL9YWUS)
- [ ] Archive created in Xcode
- [ ] Validate/Upload succeeded
- [ ] Build processed in TestFlight
- [ ] App Store listing completed (metadata, privacy, screenshots)
- [ ] Submit for Review
- [ ] Release strategy chosen (manual/auto/scheduled)

---

## 15) Support

- Email: `mogalia.apps@gmail.com`
- Company: `Mogalia Mobile Engines`

---

## 16) Screenshot Generation Commands (Reproducible)

This project includes a shell script to convert raw phone/simulator screenshots into Apple‑compliant portrait PNGs for iPhone 6.7" and 6.5". It enforces portrait orientation and center‑crops to fit exactly (no black bars, no stretching).

Location:
- Script: `tools/prepare_screenshots.sh`
- Raw input folder: `store_screenshots/ios/raw/`
- Outputs:
  - `store_screenshots/ios/output/6.7/` (1290×2796)
  - `store_screenshots/ios/output/6.5/` (1242×2688)

### A) Process local images into App Store sizes
```bash
# 1) Place images in raw folder (PNG/JPG ok)
ls -lah store_screenshots/ios/raw

# 2) Generate 6.7" and 6.5" portrait screenshots
bash tools/prepare_screenshots.sh

# 3) Verify sample dimensions (should be 1290×2796 and 1242×2688)
fn=$(ls -1 store_screenshots/ios/output/6.5 | head -n 1)
sips -g pixelWidth -g pixelHeight "store_screenshots/ios/output/6.5/$fn"
sips -g pixelWidth -g pixelHeight "store_screenshots/ios/output/6.7/$fn"

# 4) Commit and push outputs
git add store_screenshots/ios/output/6.5 store_screenshots/ios/output/6.7
git commit -m "feat(store): add processed iOS screenshots 6.5 and 6.7 portrait"
git push origin main
```

### B) Optional — capture via Simulator (then process)
```bash
# List devices (ensure a simulator is installed/booted)
xcrun simctl list devices

# Boot a simulator (example; adjust device name as installed)
open -a Simulator
xcrun simctl boot "iPhone 11 Pro Max"

# Launch app from Flutter on that device
flutter run -d "iPhone 11 Pro Max"

# Capture a screenshot to the raw folder
xcrun simctl io booted screenshot store_screenshots/ios/raw/minister_home.png

# Then run the processing script (see section A)
bash tools/prepare_screenshots.sh
```

Notes:
- The script uses macOS `sips` to normalize EXIF orientation, rotate to portrait if needed, scale by height, and center‑crop width to exact target sizes.
- If you prefer “fit with padding” instead of cover‑crop, we can switch the script accordingly.
