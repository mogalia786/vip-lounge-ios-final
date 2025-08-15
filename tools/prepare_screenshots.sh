#!/usr/bin/env bash
set -euo pipefail

# Prepare App Store screenshots from raw captures WITHOUT stretching.
# Steps per image:
# 1) Convert to PNG and honor EXIF orientation
# 2) If landscape, rotate to portrait
# 3) For each target size: scale by height, then center-crop width to fit exactly

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
RAW_DIR="$ROOT_DIR/store_screenshots/ios/raw"
OUT_67="$ROOT_DIR/store_screenshots/ios/output/6.7"
OUT_65="$ROOT_DIR/store_screenshots/ios/output/6.5"
TMP_DIR="$ROOT_DIR/store_screenshots/ios/.tmp"

mkdir -p "$OUT_67" "$OUT_65" "$TMP_DIR"

# Target sizes (pixels)
TW_67=1290; TH_67=2796   # 6.7"
TW_65=1242; TH_65=2688   # 6.5"

read_dim() {
  # $1: path
  local W H
  W=$(sips -g pixelWidth  "$1" 2>/dev/null | awk 'NR==2{print $2}')
  H=$(sips -g pixelHeight "$1" 2>/dev/null | awk 'NR==2{print $2}')
  echo "$W $H"
}

process_target() {
  # $1: src png (portrait)
  # $2: target width
  # $3: target height
  # $4: out path
  local SRC="$1" TW="$2" TH="$3" OUT="$4"

  # 1) scale by height to TH, keep aspect
  # compute new width: W' = round(W * TH / H)
  read W H < <(read_dim "$SRC")
  if [[ -z "$W" || -z "$H" ]]; then
    echo "Skipping (cannot read dims): $SRC" >&2
    return
  fi
  local NEWW
  NEWW=$(awk -v W="$W" -v H="$H" -v TH="$TH" 'BEGIN{ printf("%d", (W*TH)/H) }')
  local RSIZED="$TMP_DIR/_resized_$$.png"
  sips -z "$TH" "$NEWW" "$SRC" --out "$RSIZED" >/dev/null

  # 2) center-crop to TW x TH
  local CROPPED="$OUT"
  sips -c "$TH" "$TW" "$RSIZED" --out "$CROPPED" >/dev/null
  rm -f "$RSIZED"
}

shopt -s nullglob
for IMG in "$RAW_DIR"/*.png "$RAW_DIR"/*.jpg "$RAW_DIR"/*.jpeg; do
  FBASE=$(basename "$IMG")
  echo "Processing $FBASE"
  # Convert to PNG (applies EXIF orientation)
  INP="$TMP_DIR/_in_$$.png"
  sips -s format png "$IMG" --out "$INP" >/dev/null

  # Ensure portrait (rotate if width>height)
  read W H < <(read_dim "$INP")
  if [[ "${W:-0}" -gt "${H:-0}" ]]; then
    sips -r 90 "$INP" >/dev/null
  fi

  # 6.7"
  process_target "$INP" "$TW_67" "$TH_67" "$OUT_67/$FBASE"
  # 6.5"
  process_target "$INP" "$TW_65" "$TH_65" "$OUT_65/$FBASE"

  rm -f "$INP"
done

echo "Done. Outputs:"
echo " - $OUT_67 (${TW_67}x${TH_67})"
echo " - $OUT_65 (${TW_65}x${TH_65})"
