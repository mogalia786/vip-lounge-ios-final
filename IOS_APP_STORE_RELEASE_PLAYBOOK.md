# VIP Lounge — Apple App Store Release Playbook (Two-Day Push)

This document gives you a fast, low-friction path to submit the iOS app to the Apple App Store with minimal testing. It includes:
- What you must do vs what I will do
- Exact Xcode/CLI steps to archive and upload
- Screenshot requirements and how to capture them quickly
- Links to all relevant Apple portals and docs

If we act immediately, we can submit today. Apple’s review time is not guaranteed; same-day/next‑day approval is possible but not guaranteed. Internal TestFlight will be available within ~15–60 minutes after upload.

---

## 0) Quick Overview and Timeline

- T0: Prepare metadata, set final bundle ID, set signing → 1–2 hours
- T0+1h: Archive & upload build to App Store Connect → 30–60 minutes including processing
- T0+2h: Fill Store listing (descriptions, privacy, screenshots) → 1–2 hours (parallelizable)
- T0+3–4h: Submit for Review
- Review: Anywhere from hours to a few days.

Two‑day public release is possible but depends on Apple’s review speed. We will submit within the same day to maximize chances.

---

## 1) Prerequisites and Links

- Apple Developer account (paid) and App Store Connect access (Admin/App Manager)
- Final bundle identifier (example: `com.yourcompany.viplounge`)
- App display name (e.g., "VIP Lounge")
- App Privacy Policy URL (public page)
- Support URL and Marketing URL (optional but recommended)
- Contact details for review (email, phone)
- Test account credentials if the app requires login (Apple often asks)

Important links:
- App Store Connect: https://appstoreconnect.apple.com/
- Apple Developer: https://developer.apple.com/
- Transporter (Mac App Store): https://apps.apple.com/app/transporter/id1450874784
- App privacy details: https://developer.apple.com/app-store/app-privacy-details/
- Screenshot guidance: https://developer.apple.com/app-store/product-page/

---

## 2) Responsibilities — You vs Me

- You (Owner)
  - Confirm final bundle ID and app display name
  - Provide Privacy Policy URL, Support URL
  - Provide App descriptions (short and long) — I can draft if you prefer
  - Provide/confirm app icon source (already in project for build; store marketing icon is derived)
  - Provide (or approve) screenshots I capture
  - Create App record in App Store Connect (or grant me access)

- Me (Cascade)
  - Update bundle ID, display name, and signing settings in Xcode
  - Increment version/build and ensure `Info.plist`/`pubspec.yaml` are synced
  - Archive the app and upload the build to App Store Connect
  - Prepare a metadata checklist and a draft description
  - Capture iPhone screenshots per the list below (or guide you to capture)

---

## 3) Project Configuration (once)

- Bundle ID (Xcode): `Runner` target → Signing & Capabilities → Bundle Identifier → set to your final ID
- Team: Set your Apple Team for Debug/Release (Automatic signing is fine for App Store)
- Display name: `ios/Runner/Info.plist` → `CFBundleDisplayName`
- Versioning:
  - `pubspec.yaml` → `version: 1.0.0+1` (I’ll sync to iOS build)
- Capabilities (already configured): Push Notifications and Background Modes (remote-notification)

---

## 4) Build, Archive, and Upload (fast path)

Option A: Xcode GUI (most reliable)
1) Open `ios/Runner.xcworkspace` in Xcode
2) Select target device: Any iOS Device (arm64)
3) Product → Archive (Release). Wait until Organizer opens.
4) In Organizer, select the archive → Distribute App → App Store Connect → Upload.
   - Signing: Automatic
   - Method: App Store Connect upload
   - Manage app signing with Apple (recommended)
5) Finish. Processing takes ~10–30 minutes. Build then appears under TestFlight and for submission.

Option B: CLI (scriptable)
```bash
# From project root
xcodebuild -workspace ios/Runner.xcworkspace \
  -scheme Runner -configuration Release \
  -archivePath build/ios/Runner.xcarchive archive \
  CODE_SIGN_STYLE=Automatic \
  DEVELOPMENT_TEAM=YOUR_TEAM_ID \
  ONLY_ACTIVE_ARCH=YES

xcodebuild -exportArchive \
  -archivePath build/ios/Runner.xcarchive \
  -exportOptionsPlist ios/ExportOptions.plist \
  -exportPath build/ios/export

# Upload with Transporter (GUI) or altool-not-supported-anymore
# Preferred: open Transporter and drag build/ios/export/*.ipa
```
ExportOptions.plist (example, place at `ios/ExportOptions.plist`):
```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>method</key><string>app-store</string>
  <key>signingStyle</key><string>automatic</string>
  <key>uploadSymbols</key><true/>
  <key>compileBitcode</key><false/>
</dict>
</plist>
```

I’ll use Option A unless you prefer CLI.

---

## 5) App Store Connect — App Setup

In App Store Connect → My Apps → New App
- Name, Primary language
- Bundle ID (must match Xcode)
- SKU (internal string)

App Information:
- Categories
- Age rating
- App Privacy: Complete data collection details. If you use Firebase (Messaging/Analytics/Crashlytics), declare accordingly. Ref: https://developer.apple.com/app-store/app-privacy-details/

Pricing and Availability:
- Select territories, pricing (Free)

Prepare for Submission (App version page):
- Promotional text (optional)
- Description (I can draft)
- Keywords
- Support URL, Marketing URL, Privacy Policy URL
- Screenshots and app previews

---

## 6) Screenshots — Minimal, Fast, Correct

Apple requires at least 2 screenshots per device size. For iPhone‑only app, provide:
- 6.7" (iPhone 15 Pro Max simulator) — required
- 5.5" (iPhone 8 Plus simulator) — recommended legacy size Apple still accepts

Recommended set (portrait):
1) Native splash (shop-front) landing → GIF splash
2) Login screen
3) Home/dashboard
4) Booking flow (pre-confirm)
5) Booking success / calendar confirmation
6) Notifications UI/state (if visible)

How to capture quickly (Simulator):
- Open Xcode → Xcode > Settings > Platforms → install iOS simulators for iPhone 15 Pro Max and iPhone 8 Plus
- Run app on each simulator, navigate to target screens
- File → Save Screen Shot (Cmd+S)
- Files will be saved to your Desktop (or set a custom location)
- Store them in `store_assets/ios/screenshots/{6.7-inch,5.5-inch}/`

Image specs:
- PNG or JPG, no transparency, no device frames
- 6.7": 1290×2796 px (captured by simulator automatically)
- 5.5": 1242×2208 px

I can also set up a tiny integration test to auto-navigate and take screenshots if you want to save time.

---

## 7) Minimal Testing Plan (same day)

- Internal TestFlight (you + a couple of testers): install and sanity check
  - Cold boot, login, booking flow, notification receipt
- If all good (30–60 minutes), submit to Review immediately.

---

## 8) Submission & Review

On the App version page:
- Export Compliance: usually Yes (uses standard encryption), no CCATS required for standard networking
- Content Rights: confirm you have rights to content
- Sign-in demo account: provide one if needed
- Build: select the processed build
- Submit for Review

Review time varies (hours to days). Two days is achievable but not guaranteed.

---

## 9) What I Will Do Now (when you confirm bundle ID, app name, team)

1) Update bundle identifier and display name (`ios/Runner` project & `Info.plist`)
2) Set Signing to Automatic (Release) with your Team
3) Bump version/build from `pubspec.yaml` and sync to iOS
4) Archive via Xcode and upload via Organizer
5) Draft store listing text (description, keywords) and handoff for your approval
6) Capture the core iPhone screenshots on 6.7" and 5.5" simulators and place them in `store_assets/ios/screenshots/`

---

## 10) Provide These to Me

- Final bundle ID (e.g., `com.yourcompany.viplounge`)
- App Store display name
- Apple Team ID and confirm Automatic signing for Release is OK
- Privacy Policy URL, Support URL
- Short and long description OR approve my drafts
- Test account credentials for review (if login required)

Once I have these, I’ll proceed immediately to archive and upload.

---

## 11) FAQ

- Q: Can we release in 2 days?
  - A: We will submit today. Approval within 2 days is possible but not guaranteed by Apple. Internal TestFlight is usually available the same day.
- Q: Do we need iPad screenshots?
  - A: Only if we support iPad. If you prefer iPhone‑only initially, we’ll restrict device families to iPhone.
- Q: Do we need a website?
  - A: You need a Privacy Policy URL (can be a simple hosted page). Support URL is recommended.

---

## 12) References
- App Store product page: https://developer.apple.com/app-store/product-page/
- App privacy details: https://developer.apple.com/app-store/app-privacy-details/
- App Store Connect: https://appstoreconnect.apple.com/
- Transporter app: https://apps.apple.com/app/transporter/id1450874784
