#!/usr/bin/env python3
"""Generate a placeholder AppIcon set for Jarvis.

Produces a full-bleed gradient icon with a bold "J" and writes every size
required by Assets.xcassets/AppIcon.appiconset, then rewrites Contents.json
with the matching filenames. Replace base art later by editing the gradient
colors here or dropping in your own 1024 master and re-running.

Usage: python3 Scripts/generate_app_icons.py
"""
import json
import os
from PIL import Image, ImageDraw, ImageFont

ICONSET = os.path.join(
    os.path.dirname(os.path.dirname(os.path.abspath(__file__))),
    "Jarvis", "Assets.xcassets", "AppIcon.appiconset",
)

FONT_CANDIDATES = [
    "/System/Library/Fonts/SFNSRounded.ttf",
    "/System/Library/Fonts/Helvetica.ttc",
    "/Library/Fonts/Arial.ttf",
    "/System/Library/Fonts/Supplemental/Arial.ttf",
]


def load_font(px):
    for path in FONT_CANDIDATES:
        if os.path.exists(path):
            try:
                return ImageFont.truetype(path, px)
            except Exception:
                continue
    return ImageFont.load_default()


def make_master(size, variant):
    """variant in {'light','dark','tinted'}."""
    img = Image.new("RGB", (size, size))
    draw = ImageDraw.Draw(img)

    if variant == "light":
        top, bottom = (74, 108, 247), (139, 92, 246)      # blue → purple
        glyph = (255, 255, 255)
    elif variant == "dark":
        top, bottom = (24, 28, 42), (44, 38, 72)          # deep navy → plum
        glyph = (150, 170, 255)
    else:  # tinted (grayscale, system applies tint)
        top, bottom = (40, 40, 40), (110, 110, 110)
        glyph = (235, 235, 235)

    for y in range(size):
        t = y / max(1, size - 1)
        r = int(top[0] + (bottom[0] - top[0]) * t)
        g = int(top[1] + (bottom[1] - top[1]) * t)
        b = int(top[2] + (bottom[2] - top[2]) * t)
        draw.line([(0, y), (size, y)], fill=(r, g, b))

    font = load_font(int(size * 0.62))
    text = "J"
    try:
        box = draw.textbbox((0, 0), text, font=font)
        tw, th = box[2] - box[0], box[3] - box[1]
        pos = ((size - tw) / 2 - box[0], (size - th) / 2 - box[1])
    except Exception:
        pos = (size * 0.32, size * 0.12)
    draw.text(pos, text, font=font, fill=glyph)
    return img


# (filename, pixel_size, variant)
TARGETS = [
    ("icon-ios-1024.png", 1024, "light"),
    ("icon-ios-1024-dark.png", 1024, "dark"),
    ("icon-ios-1024-tinted.png", 1024, "tinted"),
    ("icon-mac-16.png", 16, "light"),
    ("icon-mac-32.png", 32, "light"),
    ("icon-mac-64.png", 64, "light"),
    ("icon-mac-128.png", 128, "light"),
    ("icon-mac-256.png", 256, "light"),
    ("icon-mac-512.png", 512, "light"),
    ("icon-mac-1024.png", 1024, "light"),
]

masters = {}
for name, px, variant in TARGETS:
    img = make_master(px, variant)
    img.save(os.path.join(ICONSET, name), "PNG")
    masters[(px, variant)] = name

contents = {
    "images": [
        {"idiom": "universal", "platform": "ios", "size": "1024x1024",
         "filename": "icon-ios-1024.png"},
        {"appearances": [{"appearance": "luminosity", "value": "dark"}],
         "idiom": "universal", "platform": "ios", "size": "1024x1024",
         "filename": "icon-ios-1024-dark.png"},
        {"appearances": [{"appearance": "luminosity", "value": "tinted"}],
         "idiom": "universal", "platform": "ios", "size": "1024x1024",
         "filename": "icon-ios-1024-tinted.png"},
        {"idiom": "mac", "scale": "1x", "size": "16x16", "filename": "icon-mac-16.png"},
        {"idiom": "mac", "scale": "2x", "size": "16x16", "filename": "icon-mac-32.png"},
        {"idiom": "mac", "scale": "1x", "size": "32x32", "filename": "icon-mac-32.png"},
        {"idiom": "mac", "scale": "2x", "size": "32x32", "filename": "icon-mac-64.png"},
        {"idiom": "mac", "scale": "1x", "size": "128x128", "filename": "icon-mac-128.png"},
        {"idiom": "mac", "scale": "2x", "size": "128x128", "filename": "icon-mac-256.png"},
        {"idiom": "mac", "scale": "1x", "size": "256x256", "filename": "icon-mac-256.png"},
        {"idiom": "mac", "scale": "2x", "size": "256x256", "filename": "icon-mac-512.png"},
        {"idiom": "mac", "scale": "1x", "size": "512x512", "filename": "icon-mac-512.png"},
        {"idiom": "mac", "scale": "2x", "size": "512x512", "filename": "icon-mac-1024.png"},
    ],
    "info": {"author": "xcode", "version": 1},
}

with open(os.path.join(ICONSET, "Contents.json"), "w") as f:
    json.dump(contents, f, indent=2)

print(f"Generated {len(TARGETS)} PNGs + Contents.json in {ICONSET}")
