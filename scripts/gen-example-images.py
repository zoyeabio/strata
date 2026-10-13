#!/usr/bin/env python3
"""Generate the exampleSite's photographic placeholders.

Pure standard library: the PNG is written by hand (signature + IHDR + one
zlib IDAT + IEND), so regenerating the demo assets never needs ImageMagick or
Pillow.

Composition notes, all of them driven by file size:
  - No per-pixel noise. Grain is what makes a smooth gradient incompressible
    (a 1920x620 gradient is 31KB clean, 131KB with 12x12 block noise). Soft
    disc edges carry the visual interest instead.
  - No exp() radial glow for the same reason: it varies at every pixel.
  - Sources sit at 1920px wide because caps.hero is 1920; anything wider just
    costs bytes, since the widest variant is capped there.

Usage:
  python3 scripts/gen-example-images.py [--out exampleSite/assets/images]
"""
import argparse
import math
import struct
import zlib
from pathlib import Path

DEEP = (11, 24, 41)
ACCENT = (37, 95, 143)
ACCENT_LT = (92, 146, 196)
SLATE = (148, 163, 180)
WARM = (198, 122, 78)
WARM_LT = (226, 176, 128)
PALE = (236, 240, 245)
WHITE = (255, 255, 255)


def _chunk(tag, data):
    body = tag + data
    return struct.pack('>I', len(data)) + body + struct.pack('>I', zlib.crc32(body))


def _png(path, w, h, pixel):
    raw = bytearray()
    for y in range(h):
        raw.append(0)
        for x in range(w):
            raw.extend(pixel(x, y))
    out = Path(path)
    out.parent.mkdir(parents=True, exist_ok=True)
    with out.open('wb') as f:
        f.write(b'\x89PNG\r\n\x1a\n')
        f.write(_chunk(b'IHDR', struct.pack('>IIBBBBB', w, h, 8, 2, 0, 0, 0)))
        f.write(_chunk(b'IDAT', zlib.compress(bytes(raw), 9)))
        f.write(_chunk(b'IEND', b''))


def c01(v):
    return 0.0 if v < 0 else (1.0 if v > 1 else v)


def lerp(a, b, t):
    return tuple(int(round(a[i] + (b[i] - a[i]) * t)) for i in range(3))


def gradient(w, h, stops, angle=45.0):
    """Two or three colour stops along a diagonal."""
    a = math.radians(angle)
    dx, dy = math.cos(a), math.sin(a)
    amp = abs(dx * w) + abs(dy * h)

    def p(x, y):
        t = c01(((x * dx) + (y * dy) + amp / 2.0) / amp)
        if len(stops) == 2:
            return lerp(stops[0], stops[1], t)
        return lerp(stops[0], stops[1], t * 2) if t < 0.5 else lerp(stops[1], stops[2], (t - 0.5) * 2)

    return p


def disc(cx, cy, r):
    """Soft-edged circle; returns a mask function."""
    def f(x, y):
        d = math.hypot(x - cx, y - cy)
        return 0.0 if d > r + 10 else c01((r + 10 - d) / 20.0)
    return f


def dots(w, h, step, r):
    def f(x, y):
        d = math.hypot((x % step) - step / 2.0, (y % step) - step / 2.0)
        return 0.0 if d > r + 6 else c01((r + 6 - d) / 12.0)
    return f


def rings(cx, cy, step, thickness):
    def f(x, y):
        band = abs((math.hypot(x - cx, y - cy) % step) - step / 2.0)
        return 0.0 if band > thickness + 4 else c01((thickness + 4 - band) / 8.0) * 0.8
    return f


def overlay(base, layers):
    """`layers` is [(mask_fn, colour, mode)]; 'alpha' blends, 'add' lightens."""
    def p(x, y):
        col = base(x, y)
        for mask, colour, mode in layers:
            m = mask(x, y)
            if m <= 0:
                continue
            if mode == 'add':
                col = tuple(max(255, min(255, c + int(colour[i] * m))) for i, c in enumerate(col))
            else:
                col = lerp(col, colour, m)
        return col
    return p


def blend(top, base, alpha=1.0):
    def p(x, y):
        return lerp(base(x, y), top(x, y), alpha)
    return p


def bars(w, h, values, bg, fg, pad=0.16):
    """A bar chart. The axes and labels stay inside the safe area, which is the
    point of fit="contain": cover would crop them off at narrow frames."""
    n = len(values)
    slot = w / n
    bw = slot * (1 - pad)
    gap = slot * pad
    top, bot = h * 0.14, h * 0.88

    def p(x, y):
        col = bg
        i = int(x / slot)
        if 0 <= i < n:
            x0 = i * slot + gap
            x1 = x0 + bw
            bt = bot - (bot - top) * values[i]
            if x0 - 4 <= x <= x1 + 4 and bt - 4 <= y <= bot:
                t = 1.0
                for lim, side in ((x0, x), (x1, x), (bt, y), (bot, y)):
                    d = (lim - side) if side < lim else (side - lim)
                    t *= c01(d / 8.0)
                col = lerp(col, fg, 1.0 - t)
        return col
    return p


def line_path(w, h, series, top=0.16, bot=0.84):
    def at(x):
        n = len(series)
        f = (x / max(1, w - 1)) * (n - 1)
        i = min(n - 2, int(f))
        return top * h + (bot * h - top * h) * (1 - (series[i] + (series[i + 1] - series[i]) * (f - i)))
    return at


def lines(w, h, series, bg, fg, width=9.0, fill=0.10):
    at = line_path(w, h, series)
    bot = h * 0.84

    def p(x, y):
        col = bg
        d = abs(at(x) - y)
        if d < width:
            col = lerp(col, fg, c01((width - d) / width))
        elif at(x) <= y <= bot and d > 2:
            col = lerp(col, fg, fill)
        return col
    return p


def emit(root, name, w, h, pixel):
    _png(root / name, w, h, pixel)
    print(f'  {w:>5}x{h:<5} {(root / name).stat().st_size // 1024:>4}KB  {name}')


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument('--out', default='exampleSite/assets/images')
    args = ap.parse_args()
    root = Path(args.out)
    total = 0
    print(f'writing to {root}/')

    # Heroes. The theme's hero is a fixed-height band, about 3:1 on desktop,
    # not 16:9. These sit near 3:1 with the brightest mark in the middle band,
    # which is the area that survives every crop.
    emit(root, 'hero-home.png', 1920, 620,
         overlay(gradient(1920, 620, (DEEP, ACCENT, ACCENT_LT), 25),
                 [(disc(1460, 190, 150), WARM_LT, 'alpha'), (disc(1150, 470, 80), WARM, 'alpha')]))
    emit(root, 'hero-about.png', 1920, 620,
         overlay(gradient(1920, 620, ((16, 32, 52), ACCENT, DEEP), 115),
                 [(disc(430, 200, 190), SLATE, 'alpha')]))
    emit(root, 'hero-features.png', 1920, 620,
         overlay(gradient(1920, 620, (DEEP, (24, 56, 88), ACCENT), 60),
                 [(disc(1450, 200, 150), ACCENT_LT, 'alpha'), (disc(1180, 470, 90), WARM_LT, 'alpha')]))
    emit(root, 'hero-shortcodes.png', 1920, 620,
         overlay(gradient(1920, 620, ((9, 20, 34), (20, 42, 66), ACCENT), 35),
                 [(dots(1920, 620, 56, 4), ACCENT_LT, 'add')]))
    emit(root, 'hero-gallery.png', 1920, 620,
         overlay(gradient(1920, 620, ((34, 24, 22), WARM, WARM_LT), 150),
                 [(disc(1350, 300, 210), (255, 240, 220), 'alpha')]))
    emit(root, 'hero-docs.png', 1920, 620,
         overlay(gradient(1920, 620, ((206, 216, 228), (168, 190, 212), DEEP), 90),
                 [(disc(560, 300, 180), ACCENT_LT, 'alpha')]))
    emit(root, 'hero-contact.png', 1920, 620,
         overlay(gradient(1920, 620, (ACCENT_LT, ACCENT, DEEP), 70),
                 [(disc(1420, 400, 170), (226, 236, 246), 'alpha')]))

    # Feature cards at 16:9, the ratio the card frame locks to.
    for i, (name, stops, angle) in enumerate([
        ('features-responsive.png', (DEEP, ACCENT, ACCENT_LT), 30),
        ('features-darkmode.png', ((8, 14, 24), (26, 38, 58), ACCENT), 135),
        ('features-seo.png', (DEEP, (30, 74, 116), ACCENT_LT), 75),
        ('features-images.png', ((26, 20, 26), WARM, WARM_LT), 120),
        ('features-gates.png', ((14, 26, 30), (28, 62, 68), (96, 158, 168)), 45),
        ('features-scaffold.png', (DEEP, ACCENT, SLATE), 160),
    ]):
        layers = []
        if i % 2:
            layers = [(disc(960 + 200 * math.cos(i), 450 + 120 * math.sin(i), 140),
                       WARM_LT if i % 4 else ACCENT_LT, 'alpha')]
        emit(root, name, 1600, 900, overlay(gradient(1600, 900, stops, angle), layers))

    # Illustrations in mixed ratios. The charts exist to show fit="contain".
    emit(root, 'chart-bars.png', 1280, 720,
         bars(1280, 720, [0.34, 0.52, 0.41, 0.68, 0.57, 0.83, 0.74, 0.96], PALE, ACCENT))
    emit(root, 'chart-lines.png', 1280, 800,
         blend(lines(1280, 800, [0.42, 0.38, 0.50, 0.47, 0.61, 0.58, 0.74, 0.80, 0.90], PALE, WARM),
               lines(1280, 800, [0.20, 0.31, 0.28, 0.46, 0.44, 0.63, 0.71, 0.69, 0.88], PALE, ACCENT),
               0.55))
    emit(root, 'diagram-nodes.png', 1280, 900,
         overlay(gradient(1280, 900, (DEEP, ACCENT, ACCENT_LT), 40),
                 [(disc(340, 280, 96), ACCENT_LT, 'alpha'), (disc(940, 280, 96), ACCENT_LT, 'alpha'),
                  (disc(640, 640, 120), WARM_LT, 'alpha'), (disc(200, 700, 60), WARM, 'alpha'),
                  (disc(1080, 700, 60), WARM, 'alpha')]))
    emit(root, 'texture-weave.png', 1280, 854,
         overlay(gradient(1280, 854, ((22, 40, 62), ACCENT, (200, 210, 222)), 20),
                 [(dots(1280, 854, 64, 7), PALE, 'add')]))

    # Carousel slides at 16:9.
    for i, (name, angle) in enumerate([('carousel-one.png', 30),
                                       ('carousel-two.png', 150),
                                       ('carousel-three.png', 90)]):
        emit(root, name, 1600, 900,
             overlay(gradient(1600, 900, (DEEP, ACCENT, ACCENT_LT), angle),
                     [(disc(800 + 320 * math.cos(i * 2), 450 + 200 * math.sin(i * 2), 170),
                       WARM_LT if i else (238, 244, 250), 'alpha')]))

    # A square and a tall source: proof the pipeline handles non-wide inputs.
    emit(root, 'square-portrait.png', 1000, 1000,
         overlay(gradient(1000, 1000, (DEEP, ACCENT, ACCENT_LT), 45),
                 [(rings(500, 500, 78, 10), PALE, 'add')]))
    emit(root, 'tall-crop.png', 900, 1600,
         overlay(gradient(900, 1600, (WARM, (140, 84, 52), DEEP), 60),
                 [(disc(450, 800, 190), WARM_LT, 'alpha')]))

    files = sorted(root.glob('*.png'))
    print(f'  {len(files)} images, {sum(f.stat().st_size for f in files) // 1024}KB total')


if __name__ == '__main__':
    main()
