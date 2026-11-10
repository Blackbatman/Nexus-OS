#!/usr/bin/env python3
"""generate-frames.py — renders the NEXUS "IGNITION" boot animation.

The signature NEXUS-OS boot sequence: a dead APU wakes up. Seven micro-dies
ignite in sequence (a nod to the FW 7.00 -> 13.60 support lineage), a
mass-relay style double ring spins up around them (the Mass Effect side of
the identity), the wordmark lands with a Cyberpunk-style RGB-split glitch
snap, and three OS nodes take orbit (macOS / Windows / Linux — one console,
every OS).

Outputs (deterministic, no network, no random seed):
  frames/f00..f47.png    384x384 — Plymouth script cycles these on the PS5
  --preview-dir DIR      960x960 masters for GIF/MP4 previews
  --wallpaper-dir DIR    NEXUS Metro wallpapers (1920x1080, 2560x1440)
  --logo PATH            transparent NEXUS logo (512) for splash/SDDM

Everything is drawn procedurally; the only inputs are the NEXUS palette
(docs/14-nexus-metro-identity.md). Legal note: the theme is inspired by the
Mass Effect and Cyberpunk 2077 aesthetics; no copyrighted asset, logo, or
game font is reproduced.
"""
from __future__ import annotations

import argparse
import math
import os
import shutil

import numpy as np
from PIL import Image, ImageDraw, ImageFilter, ImageFont

# ------------------------------------------------------------------ palette
BG_TOP = (7, 11, 24)
BG_BOT = (0, 3, 8)
CYAN = (53, 224, 255)
CYAN_DIM = (26, 96, 120)
YELLOW = (252, 238, 10)
RED = (255, 42, 95)
MINT = (61, 255, 162)
SILVER = (216, 220, 228)
BLUE = (76, 194, 255)
TXT = (215, 230, 242)
WIDE = 48  # frame count

FONT_CANDIDATES = [
    "/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf",
    "/usr/share/fonts/truetype/liberation/LiberationSans-Bold.ttf",
]


def font(size: int) -> ImageFont.FreeTypeFont:
    for path in FONT_CANDIDATES:
        if os.path.exists(path):
            return ImageFont.truetype(path, size)
    return ImageFont.load_default()


def ease(t: float) -> float:
    return 0.0 if t <= 0 else 1.0 if t >= 1 else t * t * (3 - 2 * t)


def lerp(a, b, t):
    return a + (b - a) * t


def base_bg(s: int) -> np.ndarray:
    """Vertical gradient + corner vignette, computed once per size."""
    y = np.linspace(0, 1, s, dtype=np.float32)[:, None]           # (s,1)
    top = np.array(BG_TOP, np.float32)[None, None, :]
    bot = np.array(BG_BOT, np.float32)[None, None, :]
    bg = np.broadcast_to(top * (1 - y)[:, :, None] + bot * y[:, :, None], (s, s, 3))
    yy, xx = np.mgrid[0:s, 0:s].astype(np.float32)
    d = np.sqrt((xx - s / 2) ** 2 + (yy - s / 2) ** 2) / (s * 0.72)
    vig = 1.0 - 0.42 * np.clip(d - 0.55, 0, 1) ** 1.6
    return np.clip(bg * vig[:, :, None], 0, 255).astype(np.uint8)


def hex_layer(s: int, alpha: int) -> Image.Image:
    """Faint hexagonal lattice overlay."""
    lay = Image.new("RGBA", (s, s), (0, 0, 0, 0))
    d = ImageDraw.Draw(lay)
    r = max(14, s // 26)
    dx, dy = 3 * r, math.sqrt(3) * r
    row = 0
    y = -r
    while y < s + dy:
        x = -2 * r if row % 2 else -r * 0.5
        while x < s + dx:
            d.polygon(
                [(x + r * math.cos(math.radians(a)), y + r * math.sin(math.radians(a)))
                 for a in range(30, 391, 60)],
                outline=(53, 224, 255, alpha), width=1)
            x += dx
        y += dy / 2
        row += 1
    return lay


def glow(layer: Image.Image, radius: int) -> Image.Image:
    return layer.filter(ImageFilter.GaussianBlur(radius))


def draw_wordmark(s: int, tint, y0: float = 0.585) -> Image.Image:
    """Letterspaced NEXUS wordmark on transparent layer."""
    lay = Image.new("RGBA", (s, s), (0, 0, 0, 0))
    d = ImageDraw.Draw(lay)
    f = font(int(s * 0.16))
    word = "NEXUS"
    widths = [d.textlength(c, font=f) for c in word]
    tracking = s * 0.045
    total = sum(widths) + (len(word) - 1) * tracking
    x = (s - total) / 2
    y = s * y0
    for c, w in zip(word, widths):
        d.text((x, y), c, font=f, fill=tint)
        x += w + tracking
    return lay


def tagline_layer(s: int, alpha: int, y0: float = 0.775) -> Image.Image:
    lay = Image.new("RGBA", (s, s), (0, 0, 0, 0))
    d = ImageDraw.Draw(lay)
    f = font(int(s * 0.045))
    txt = "ONE CONSOLE. EVERY OS."
    w = d.textlength(txt, font=f)
    d.text(((s - w) / 2, s * y0), txt, font=f, fill=CYAN + (alpha,))
    return lay


def ring_layer(s: int, spin: float, spin2: float, alpha: float,
               cy: float = 0.46) -> Image.Image:
    """Mass-relay double ring: two counter-rotating arcs + inner ring."""
    lay = Image.new("RGBA", (s, s), (0, 0, 0, 0))
    d = ImageDraw.Draw(lay)
    cx = s / 2
    cy = s * cy
    R = s * 0.28
    w = max(3, int(s * 0.012))
    col = CYAN + (int(255 * alpha),)
    dim = CYAN_DIM + (int(255 * alpha * 0.55),)
    # outer arc pair (counter-rotating gaps)
    d.arc([cx - R, cy - R, cx + R, cy + R], start=spin % 360, end=(spin + 140) % 360, fill=col, width=w)
    d.arc([cx - R, cy - R, cx + R, cy + R], start=(spin + 180) % 360, end=(spin + 320) % 360, fill=col, width=w)
    # mid ring with relay spokes
    R2 = s * 0.235
    d.arc([cx - R2, cy - R2, cx + R2, cy + R2], start=0, end=360, fill=dim, width=max(2, w - 1))
    for k in range(6):
        a = math.radians(spin2 * (-1) + k * 60)
        x1, y1 = cx + R2 * 0.35 * math.cos(a), cy + R2 * 0.35 * math.sin(a)
        x2, y2 = cx + R2 * math.cos(a), cy + R2 * math.sin(a)
        d.line([x1, y1, x2, y2], fill=dim, width=max(2, w - 1))
    # inner core ring
    R3 = s * 0.10
    d.arc([cx - R3, cy - R3, cx + R3, cy + R3], start=0, end=360, fill=col, width=w)
    return lay


DIES = [(-0.115, -0.10), (0.0, -0.135), (0.115, -0.10), (-0.06, 0.0), (0.06, 0.0),
        (-0.115, 0.10), (0.115, 0.10)]  # seven micro-dies, APU-like cluster


def die_layer(s: int, lit_count: int, flash: int) -> Image.Image:
    lay = Image.new("RGBA", (s, s), (0, 0, 0, 0))
    d = ImageDraw.Draw(lay)
    cx = s / 2
    w = s * 0.085
    for i, (fx, fy) in enumerate(DIES):
        x, y = cx + fx * s, s * 0.42 + fy * s * 0.9
        box = [x - w / 2, y - w * 0.62, x + w / 2, y + w * 0.62]
        if i < lit_count:
            fill = CYAN + (200,)
            outline = CYAN + (255,)
        else:
            fill = (16, 26, 40, 160)
            outline = (40, 70, 92, 220)
        d.rounded_rectangle(box, radius=int(w * 0.22), fill=fill, outline=outline,
                            width=max(2, s // 160))
        if i == flash:  # ignition tick — the Cyberpunk accent
            d.rounded_rectangle([box[0] - 3, box[1] - 3, box[2] + 3, box[3] + 3],
                                radius=int(w * 0.24), outline=YELLOW + (255,),
                                width=max(2, s // 220))
    return lay


ORBIT = [(SILVER, 0.0), (BLUE, 2.094), (MINT, 4.189)]  # macOS / Windows / Linux


def orbit_layer(s: int, frame: int) -> Image.Image:
    lay = Image.new("RGBA", (s, s), (0, 0, 0, 0))
    d = ImageDraw.Draw(lay)
    cx = s / 2
    cy = s * 0.46
    R = s * 0.28
    for i, (col, ph) in enumerate(ORBIT):
        a = math.radians(frame * (9 + i * 2.4) + ph)
        x, y = cx + R * math.cos(a), cy + R * math.sin(a)
        r = s * 0.018
        d.ellipse([x - r, y - r, x + r, y + r], fill=col + (255,))
        glowr = s * 0.03
        d.ellipse([x - glowr, y - glowr, x + glowr, y + glowr], fill=col + (60,))
    return lay


def scan_layer(s: int, y: float) -> Image.Image:
    lay = Image.new("RGBA", (s, s), (0, 0, 0, 0))
    d = ImageDraw.Draw(lay)
    d.rectangle([0, y - s * 0.004, s, y + s * 0.004], fill=CYAN + (150,))
    d.rectangle([0, y - s * 0.02, s, y + s * 0.02], fill=CYAN + (28,))
    return lay


def frame(n: int, s: int, bg: Image.Image, hexa: Image.Image) -> Image.Image:
    img = bg.copy()
    img.alpha_composite(hexa)
    # P0 f00-07: lattice wakes, scanline sweeps, core spark grows
    if n <= 7:
        img.alpha_composite(scan_layer(s, s * (n + 1) / 9))
        r = s * 0.006 + s * 0.010 * ease(n / 7)
        d = ImageDraw.Draw(img, "RGBA")
        cx = s / 2
        cy = s * 0.46
        d.ellipse([cx - r, cy - r, cx + r, cy + r], fill=CYAN + (230,))
    # P1 f08-17: seven dies ignite
    if 8 <= n <= 17:
        lit = min(7, n - 7)
        flash = (n - 8) if n <= 14 else -1
        lay = die_layer(s, lit, flash)
        img.alpha_composite(glow(lay, max(2, s // 90)))
        img.alpha_composite(lay)
    # P2 f18-29: relay ring spins up
    if 18 <= n <= 29:
        t = ease((n - 18) / 8)
        lay = ring_layer(s, n * 14, n * 5, t)
        img.alpha_composite(glow(lay, max(3, s // 70)))
        img.alpha_composite(lay)
        if n >= 20:
            img.alpha_composite(die_layer(s, 7, -1))
    # P3 f30-33: RGB-split glitch snap, then the wordmark lands
    if 30 <= n <= 33:
        img.alpha_composite(die_layer(s, 7, -1))
        lay = ring_layer(s, 29 * 14, 29 * 5, 1.0)
        img.alpha_composite(glow(lay, max(3, s // 70)))
        img.alpha_composite(lay)
        wm = draw_wordmark(s, TXT + (255,))
        if n < 33:
            off = s * (0.016 if n % 2 == 0 else -0.012)
            img.alpha_composite(draw_wordmark(s, RED + (235,)), (int(-off), int(off * 0.4)))
            img.alpha_composite(draw_wordmark(s, BLUE + (235,)), (int(off), int(-off * 0.4)))
            img.alpha_composite(draw_wordmark(s, CYAN + (235,)), (0, 0))
        else:
            img.alpha_composite(wm)
    # P4 f34-47: identity settles — wordmark, tagline, three OS nodes orbit
    if n >= 34:
        img.alpha_composite(die_layer(s, 7, -1))
        lay = ring_layer(s, 29 * 14 + (n - 29) * 14, 29 * 5 + (n - 29) * 5, 1.0)
        img.alpha_composite(glow(lay, max(3, s // 70)))
        img.alpha_composite(lay)
        img.alpha_composite(orbit_layer(s, n))
        fade = ease((n - 33) / 5)
        wm = draw_wordmark(s, TXT + (int(255 * fade),))
        img.alpha_composite(wm)
        img.alpha_composite(tagline_layer(s, int(235 * fade)))
        if n >= 42:  # slow breathing glow on the core
            pul = 0.5 + 0.5 * math.sin(n * 0.9)
            core = Image.new("RGBA", (s, s), (0, 0, 0, 0))
            d = ImageDraw.Draw(core)
            r = s * 0.09
            cy = s * 0.46
            d.ellipse([s / 2 - r, cy - r, s / 2 + r, cy + r],
                      fill=CYAN + (int(70 * pul),))
            img.alpha_composite(glow(core, s // 40))
    return img.convert("RGB")


# ------------------------------------------------------------------ wallpapers

def wallpaper(width: int, height: int, mode: str) -> Image.Image:
    arr = base_bg(max(width, height))[:height, :width]
    img = Image.fromarray(arr, "RGB").convert("RGBA")
    s = min(width, height)
    d = ImageDraw.Draw(img, "RGBA")
    img.alpha_composite(hex_layer(s, 34))
    # relay ring assembly, right-of-center (desktop) / centered (lock)
    cx = width * (0.72 if mode == "core" else 0.5)
    cy = height * (0.46 if mode == "core" else 0.62)
    lay = Image.new("RGBA", (width, height), (0, 0, 0, 0))
    dd = ImageDraw.Draw(lay)
    R = s * 0.34
    for rr, wdt, col in [(R, max(3, s // 300), CYAN + (210,)),
                         (R * 0.78, max(2, s // 420), CYAN_DIM + (150,)),
                         (R * 0.30, max(2, s // 380), CYAN + (160,))]:
        dd.arc([cx - rr, cy - rr, cx + rr, cy + rr], 20, 165, fill=col, width=wdt)
        dd.arc([cx - rr, cy - rr, cx + rr, cy + rr], 200, 345, fill=col, width=wdt)
    img.alpha_composite(glow(lay, s // 60))
    img.alpha_composite(lay)
    if mode == "core":
        # N7-style twin stripe, lower left — diagonal accent pair
        for k, col in [(0, RED + (230,)), (18, SILVER + (90,))]:
            d.polygon([(0, height * 0.86 + k), (width * 0.34, height * 0.60 + k),
                       (width * 0.34, height * 0.615 + k), (0, height * 0.875 + k)],
                      fill=col)
        # cyber-yellow glitch ticks
        for gy, gw, gx in [(0.24, 0.030, 0.10), (0.28, 0.014, 0.16), (0.22, 0.008, 0.13)]:
            d.rectangle([width * gx, height * gy, width * (gx + 0.05), height * (gy + gw)],
                        fill=YELLOW + (180,))
        f = font(int(height * 0.052))
        d.text((width * 0.085, height * 0.70), "NEXUS", font=f, fill=TXT + (235,))
        f2 = font(int(height * 0.020))
        d.text((width * 0.087, height * 0.775), "ONE CONSOLE. EVERY OS.",
               font=f2, fill=CYAN + (220,))
    if mode == "lock":
        for y in range(0, height, 4):
            d.line([0, y, width, y], fill=(0, 0, 0, 26))
    return img.convert("RGB")


def logo_png(size: int = 512) -> Image.Image:
    img = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    lay = ring_layer(size, 40, 20, 1.0, cy=0.36)
    img.alpha_composite(glow(lay, size // 50))
    img.alpha_composite(lay)
    img.alpha_composite(draw_wordmark(size, TXT + (255,), y0=0.62))
    img.alpha_composite(tagline_layer(size, 235, y0=0.815))
    return img


# ------------------------------------------------------------------ main

def main() -> int:
    ap = argparse.ArgumentParser(description="Render the NEXUS IGNITION boot animation")
    ap.add_argument("--frames-dir", default=os.path.join(os.path.dirname(__file__), "frames"))
    ap.add_argument("--preview-dir", default="")
    ap.add_argument("--wallpaper-dir", default="")
    ap.add_argument("--logo", default="")
    ap.add_argument("--size", type=int, default=384)
    args = ap.parse_args()

    os.makedirs(args.frames_dir, exist_ok=True)
    bg = Image.fromarray(base_bg(args.size), "RGB").convert("RGBA")
    hexa = hex_layer(args.size, 90)
    for n in range(WIDE):
        frame(n, args.size, bg, hexa).save(
            os.path.join(args.frames_dir, f"f{n:02d}.png"), optimize=True)
    print(f"frames: {WIDE} x {args.size}px -> {args.frames_dir}")

    if args.preview_dir:
        os.makedirs(args.preview_dir, exist_ok=True)
        s = 960
        bg = Image.fromarray(base_bg(s), "RGB").convert("RGBA")
        hexa = hex_layer(s, 90)
        for n in range(WIDE):
            frame(n, s, bg, hexa).save(os.path.join(args.preview_dir, f"f{n:02d}.png"))
        print(f"preview masters: {WIDE} x {s}px -> {args.preview_dir}")

    if args.wallpaper_dir:
        imgs = os.path.join(args.wallpaper_dir, "contents", "images")
        os.makedirs(imgs, exist_ok=True)
        wallpaper(1920, 1080, "core").save(os.path.join(imgs, "1920x1080.png"), optimize=True)
        wallpaper(2560, 1440, "core").save(os.path.join(imgs, "2560x1440.png"), optimize=True)
        wallpaper(1920, 1080, "lock").save(os.path.join(imgs, "1920x1080-lock.png"), optimize=True)
        print(f"wallpapers -> {imgs}")

    if args.logo:
        os.makedirs(os.path.dirname(args.logo) or ".", exist_ok=True)
        logo_png(512).save(args.logo)
        print(f"logo -> {args.logo}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
