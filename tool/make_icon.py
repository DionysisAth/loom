"""Draws the placeholder app icon and writes every Android and iOS size.

    python3 tool/make_icon.py
"""
import math
import re
from pathlib import Path

from PIL import Image, ImageDraw, ImageFilter

S = 2048  # draw large, then scale down
ROOT = Path(__file__).resolve().parent.parent


def lerp(a, b, t):
    return tuple(round(x + (y - x) * t) for x, y in zip(a, b))


def yarn(draw, pts, colour, dark, width):
    """A thick yarn stroke with a darker edge and twist marks."""
    draw.line(pts, fill=dark, width=width, joint="curve")
    for p in (pts[0], pts[-1]):
        r = width // 2
        draw.ellipse([p[0] - r, p[1] - r, p[0] + r, p[1] + r], fill=dark)
    inner = int(width * 0.8)
    draw.line(pts, fill=colour, width=inner, joint="curve")
    for p in (pts[0], pts[-1]):
        r = inner // 2
        draw.ellipse([p[0] - r, p[1] - r, p[0] + r, p[1] + r], fill=colour)
    # Twist marks along each segment.
    step = width * 0.45
    for (x0, y0), (x1, y1) in zip(pts, pts[1:]):
        length = math.hypot(x1 - x0, y1 - y0)
        ang = math.atan2(y1 - y0, x1 - x0)
        n = int(length / step)
        for i in range(1, n):
            cx = x0 + (x1 - x0) * i / n
            cy = y0 + (y1 - y0) * i / n
            a = ang + 0.95
            dx, dy = math.cos(a) * width * 0.36, math.sin(a) * width * 0.36
            draw.line([(cx - dx, cy - dy), (cx + dx, cy + dy)], fill=dark, width=max(2, width // 11))


def knot(draw, p, colour, dark, r):
    draw.ellipse([p[0] - r, p[1] - r, p[0] + r, p[1] + r], fill=dark)
    r2 = r * 0.84
    draw.ellipse([p[0] - r2, p[1] - r2, p[0] + r2, p[1] + r2], fill=colour)
    hl = lerp(colour, (255, 255, 255), 0.45)
    r3 = r * 0.3
    draw.ellipse([p[0] - r * 0.45 - r3, p[1] - r * 0.45 - r3, p[0] - r * 0.45 + r3, p[1] - r * 0.45 + r3], fill=hl)


def icon():
    img = Image.new("RGB", (S, S), (233, 223, 207))
    d = ImageDraw.Draw(img)
    # Linen texture.
    for x in range(0, S, 16):
        d.line([(x, 0), (x, S)], fill=(225, 213, 194), width=3)
    for y in range(0, S, 16):
        d.line([(0, y), (S, y)], fill=(225, 213, 194), width=3)
    c = S / 2
    # Hoop shadow.
    shadow = Image.new("L", (S, S), 0)
    ImageDraw.Draw(shadow).ellipse([c - 860, c - 820, c + 860, c + 900], fill=120)
    shadow = shadow.filter(ImageFilter.GaussianBlur(40))
    img.paste((150, 120, 90), mask=shadow)
    # Wooden ring with a simple vertical gradient.
    for i in range(0, 200):
        t = i / 200
        r = 860 - i * 0.6
        col = lerp((214, 169, 112), (143, 97, 54), t)
        d.ellipse([c - r, c - r + i * 0.4, c + r, c + r + i * 0.4], outline=col, width=4)
    d.ellipse([c - 860, c - 860, c + 860, c + 860], fill=(196, 146, 88))
    d.ellipse([c - 810, c - 810, c + 810, c + 810], outline=(226, 186, 128), width=14)
    d.ellipse([c - 720, c - 720, c + 720, c + 720], fill=(248, 242, 231))
    d.ellipse([c - 720, c - 720, c + 720, c + 720], outline=(143, 97, 54), width=18)
    # Fabric weave.
    fabric = Image.new("L", (S, S), 0)
    ImageDraw.Draw(fabric).ellipse([c - 700, c - 700, c + 700, c + 700], fill=255)
    weave = Image.new("RGB", (S, S), (237, 228, 211))
    wd = ImageDraw.Draw(weave)
    for x in range(0, S, 22):
        wd.line([(x, 0), (x, S)], fill=(248, 242, 231), width=12)
    img.paste(weave, mask=Image.eval(fabric, lambda v: v // 3))
    # Threads: blue goes under at the crossing, red over it.
    w = 190
    red, red_d = (200, 66, 59), (138, 40, 35)
    blue, blue_d = (63, 111, 209), (36, 66, 130)
    blue_pts = [(c + 160, c - 520), (c + 160, c + 520)]
    red_pts = [(c - 500, c - 230), (c - 40, c - 230), (c - 40, c + 230), (c + 480, c + 230)]
    yarn(d, blue_pts, blue, blue_d, w)
    yarn(d, red_pts, red, red_d, w)
    knot(d, blue_pts[0], blue, blue_d, 150)
    knot(d, blue_pts[1], blue, blue_d, 150)
    knot(d, red_pts[0], red, red_d, 150)
    knot(d, red_pts[-1], red, red_d, 150)
    return img


def main():
    big = icon()
    big.resize((1024, 1024), Image.LANCZOS).save(ROOT / "assets/art/icon.png")
    ios = ROOT / "ios/Runner/Assets.xcassets/AppIcon.appiconset"
    for f in ios.glob("Icon-App-*.png"):
        m = re.match(r"Icon-App-([\d.]+)x[\d.]+@(\d)x\.png", f.name)
        px = round(float(m.group(1)) * int(m.group(2)))
        big.resize((px, px), Image.LANCZOS).save(f)
    sizes = {"mdpi": 48, "hdpi": 72, "xhdpi": 96, "xxhdpi": 144, "xxxhdpi": 192}
    for k, px in sizes.items():
        big.resize((px, px), Image.LANCZOS).save(ROOT / f"android/app/src/main/res/mipmap-{k}/ic_launcher.png")


if __name__ == "__main__":
    main()
