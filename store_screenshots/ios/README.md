# iOS App Store Screenshots

This folder contains a simple pipeline to capture raw screenshots and export the exact Apple-required sizes.

## Sizes we generate
- 6.7" iPhone (1290×2796)
- 6.5" iPhone (1242×2688)

## How to use
1) Capture raw screenshots (PNG) on Simulator or device and save them to:
   `store_screenshots/ios/raw/`
   
   Recommended Simulator: iPhone 15 Pro Max for best coverage.

2) Run the resize/export script:
```bash
bash tools/prepare_screenshots.sh
```
Outputs are written to:
- `store_screenshots/ios/output/6.7/`
- `store_screenshots/ios/output/6.5/`

3) Upload to App Store Connect → App Store → Version → Screenshots.

## Target screens (requested)
- Floor Manager Home
- Staff Home
- Consultant Home
- Concierge Home
- Minister Home
- Booking flow
  - Time Slot Selection
  - Booking Confirmation

## Capture tips
- Prefer light mode (unless you want dark mode variants)
- Ensure stable data: mock/seed the account so the Home pages show useful content
- Hide any debug banners
- Avoid personal info in screenshots

## Notes
- If you capture at a different resolution, the script will resize and pad/crop to fit exact targets using macOS `sips`.
- Add your own captions/overlays in a design tool if desired; we’re uploading clean app UI for speed.
