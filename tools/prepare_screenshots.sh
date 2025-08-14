#!/usr/bin/env bash
set -euo pipefail

# Prepare App Store screenshots from raw captures.
# Place your raw PNGs into store_screenshots/ios/raw/ then run:
#   bash tools/prepare_screenshots.sh
# Outputs will be in store_screenshots/ios/output/{6.7,6.5}

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
RAW_DIR="$ROOT_DIR/store_screenshots/ios/raw"
OUT_67="$ROOT_DIR/store_screenshots/ios/output/6.7"
OUT_65="$ROOT_DIR/store_screenshots/ios/output/6.5"

mkdir -p "$OUT_67" "$OUT_65"

# Target sizes (pixels)
# iPhone 15 Pro Max (6.7"): 1290x2796
# iPhone 14/13/12 Pro Max (6.7"): same resolution acceptable
# iPhone 11 Pro Max / XS Max (6.5"): 1242x2688
SIZE_67="1290x2796"
SIZE_65="1242x2688"

shopt -s nullglob
for IMG in "$RAW_DIR"/*.png "$RAW_DIR"/*.jpg "$RAW_DIR"/*.jpeg; do
  FNAME=$(basename "$IMG")
  echo "Processing $FNAME"
  # 6.7"
  sips -Z 5000 "$IMG" >/dev/null # normalize metadata/rotation subtly
  sips -s format png "$IMG" --out "$OUT_67/$FNAME" >/dev/null
  sips -z ${SIZE_67%x*} ${SIZE_67#*x} "$OUT_67/$FNAME" >/dev/null
  # 6.5"
  sips -s format png "$IMG" --out "$OUT_65/$FNAME" >/dev/null
  sips -z ${SIZE_65%x*} ${SIZE_65#*x} "$OUT_65/$FNAME" >/dev/null
 done

echo "Done. Outputs:"
echo " - $OUT_67 (1290x2796)"
echo " - $OUT_65 (1242x2688)"
