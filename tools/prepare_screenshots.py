#!/usr/bin/env python3
import os
from pathlib import Path
from PIL import Image, ImageOps

# Enforce portrait orientation and exact canvas sizes using cover crop (no bars).
# Inputs: store_screenshots/ios/raw/*
# Outputs: store_screenshots/ios/output/{6.5,6.7} with exact sizes

ROOT = Path(__file__).resolve().parent.parent
RAW = ROOT / 'store_screenshots' / 'ios' / 'raw'
OUT_67 = ROOT / 'store_screenshots' / 'ios' / 'output' / '6.7'
OUT_65 = ROOT / 'store_screenshots' / 'ios' / 'output' / '6.5'

SIZE_67 = (1290, 2796)  # width, height
SIZE_65 = (1242, 2688)

OUT_67.mkdir(parents=True, exist_ok=True)
OUT_65.mkdir(parents=True, exist_ok=True)

SUPPORTED_EXTS = {'.png', '.jpg', '.jpeg'}

# Background color for padding (RGB)
BG = (0, 0, 0)  # unused with cover crop, kept for reference

def process(img_path: Path):
    if img_path.suffix.lower() not in SUPPORTED_EXTS:
        return
    try:
        with Image.open(img_path) as im:
            im = ImageOps.exif_transpose(im)  # honor EXIF orientation
            w, h = im.size
            # Force portrait if needed
            if w > h:
                im = im.rotate(90, expand=True)
                w, h = im.size

            for target_size, outdir in ((SIZE_67, OUT_67), (SIZE_65, OUT_65)):
                tw, th = target_size
                # Cover crop to exact size (centered), preserving portrait, no padding bars
                fitted = ImageOps.fit(im, (tw, th), Image.LANCZOS, centering=(0.5, 0.5))
                outpath = outdir / img_path.name
                fitted.save(outpath, format='PNG')
                print(f"Wrote {outpath} ({tw}x{th})")
    except Exception as e:
        print(f"Failed {img_path}: {e}")


def main():
    for p in sorted(RAW.iterdir()):
        process(p)
    print("Done.")

if __name__ == '__main__':
    main()
