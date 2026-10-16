#!/usr/bin/env python3
"""Generate the Rams wallpapers as SVG, then render PNGs with rsvg-convert.

Quiet compositions after Braun objects, each with one point of colour:
  0-clock        Braun wall clock (Rams / Lubs). Static at 10:08; the
                 sehl.braun-clock plugin draws the live hands over it.
  1-grille       SK 4 lid: long horizontal slots, an orange power indicator
  2-perforation  T 3 / T 1000: a circular field of speaker holes, one orange
  3-keys         ET 66: a grid of round keys, orange and yellow function keys
  4-weniger      "Weniger, aber besser." set small in ABC Areal

Usage: tools/wallpapers.py   (writes backgrounds/ and variants/dark/backgrounds/)
"""
import math
import pathlib
import shutil
import subprocess

W, H = 3840, 2400  # 16:10; covers 16:9 with only a little crop top/bottom
ROOT = pathlib.Path(__file__).resolve().parent.parent

PALETTES = {
    "light": dict(
        out=ROOT / "backgrounds",
        bg="#eeebe5", shade="#dfdad1", ink="#2b2a27", soft="#c9c3b8",
        key="#e6e2da", orange="#d4521c", yellow="#f2b705", text="#7a766e",
        face="#f7f5f0", rim="#d3cec4", hand2="#e9a800",
    ),
    "dark": dict(
        out=ROOT / "variants/dark/backgrounds",
        bg="#1d1c1a", shade="#141312", ink="#dedad2", soft="#34322e",
        key="#2a2926", orange="#f0692b", yellow="#f2b705", text="#8f8a82",
        face="#121110", rim="#34322e", hand2="#f2b705",
    ),
}


def svg(p, body):
    return (
        f'<svg xmlns="http://www.w3.org/2000/svg" width="{W}" height="{H}" '
        f'viewBox="0 0 {W} {H}"><rect width="{W}" height="{H}" fill="{p["bg"]}"/>'
        f"{body}</svg>"
    )


# Clock geometry, in units of the face radius R. Mirrored in
# extras/braun-clock/Clock.qml; keep the two in step.
CLOCK = dict(
    diameter=0.56,            # of canvas height; centred on the canvas
    rim=0.012,
    minute_tick=(0.915, 0.965, 0.010),   # inner, outer, width
    hour_tick=(0.855, 0.965, 0.026),
    numeral_radius=0.725, numeral_size=0.135,
    hour_hand=(0.50, 0.10, 0.052),       # length, tail, width
    minute_hand=(0.80, 0.10, 0.036),
    second_hand=(0.86, 0.24, 0.014),
    cap=0.050,
)


def clock(p, h=10, m=8, s=37):
    c = CLOCK
    R = H * c["diameter"] / 2
    cx, cy = W / 2, H / 2
    out = [f'<circle cx="{cx}" cy="{cy}" r="{R}" fill="{p["face"]}" '
           f'stroke="{p["rim"]}" stroke-width="{R * c["rim"]}"/>']
    for i in range(60):
        a, b, w = c["hour_tick"] if i % 5 == 0 else c["minute_tick"]
        out.append(f'<rect x="{cx - R * w / 2}" y="{cy - R * b}" width="{R * w}" '
                   f'height="{R * (b - a)}" fill="{p["ink"]}" '
                   f'transform="rotate({i * 6} {cx} {cy})"/>')
    for n in range(1, 13):
        ang = math.radians(n * 30)
        x = cx + R * c["numeral_radius"] * math.sin(ang)
        y = cy - R * c["numeral_radius"] * math.cos(ang)
        out.append(f'<text x="{x}" y="{y}" text-anchor="middle" dominant-baseline="central" '
                   f'font-family="ABC Areal" font-weight="500" font-size="{R * c["numeral_size"]}" '
                   f'fill="{p["ink"]}">{n}</text>')

    def hand(angle, spec, color):
        length, tail, w = spec
        return (f'<rect x="{cx - R * w / 2}" y="{cy - R * length}" width="{R * w}" '
                f'height="{R * (length + tail)}" fill="{color}" '
                f'transform="rotate({angle} {cx} {cy})"/>')

    out.append(hand((h % 12 + m / 60) * 30, c["hour_hand"], p["ink"]))
    out.append(hand((m + s / 60) * 6, c["minute_hand"], p["ink"]))
    out.append(hand(s * 6, c["second_hand"], p["hand2"]))
    out.append(f'<circle cx="{cx}" cy="{cy}" r="{R * c["cap"]}" fill="{p["hand2"]}"/>')
    return svg(p, "".join(out))


def grille(p):
    # Slots on a strict grid, set right of centre; one indicator below-left.
    n, slot_h, gap, slot_w = 17, 22, 40, 1500
    x0 = W * 0.5
    y0 = (H - (n * slot_h + (n - 1) * gap)) / 2
    s = "".join(
        f'<rect x="{x0}" y="{y0 + i * (slot_h + gap)}" width="{slot_w}" '
        f'height="{slot_h}" rx="{slot_h / 2}" fill="{p["shade"]}"/>'
        for i in range(n)
    )
    s += f'<circle cx="{x0 - 220}" cy="{y0 + (n - 1) * (slot_h + gap) + slot_h / 2}" r="22" fill="{p["orange"]}"/>'
    return svg(p, s)


def perforation(p):
    # Square grid of holes clipped to a circle; one hole is the signal.
    cx, cy, radius, pitch, r = W * 0.36, H * 0.5, 720, 56, 11
    holes = []
    steps = int(radius // pitch)
    for j in range(-steps, steps + 1):
        for i in range(-steps, steps + 1):
            x, y = i * pitch, j * pitch
            if math.hypot(x, y) <= radius - r:
                holes.append((i, j, cx + x, cy + y))
    s = ""
    for i, j, x, y in holes:
        fill = p["orange"] if (i, j) == (5, -3) else p["shade"]
        s += f'<circle cx="{x}" cy="{y}" r="{r}" fill="{fill}"/>'
    # A single thin dial line to the right, like the T 3 tuning wheel edge.
    s += (f'<line x1="{W * 0.66}" y1="{cy - 420}" x2="{W * 0.66}" y2="{cy + 420}" '
          f'stroke="{p["soft"]}" stroke-width="4" stroke-linecap="round"/>')
    return svg(p, s)


def keys(p):
    # 4 x 5 key grid; the bottom-right key is the yellow "=", top-left orange.
    cols, rows, d, gap = 4, 5, 190, 70
    gw, gh = cols * d + (cols - 1) * gap, rows * d + (rows - 1) * gap
    x0, y0 = W * 0.62 - gw / 2, (H - gh) / 2
    s = ""
    for r in range(rows):
        for c in range(cols):
            fill = p["key"]
            if (r, c) == (0, 0):
                fill = p["orange"]
            elif (r, c) == (rows - 1, cols - 1):
                fill = p["yellow"]
            x, y = x0 + c * (d + gap) + d / 2, y0 + r * (d + gap) + d / 2
            s += (f'<circle cx="{x}" cy="{y}" r="{d / 2}" fill="{fill}" '
                  f'stroke="{p["soft"]}" stroke-width="3"/>')
    return svg(p, s)


def weniger(p):
    x, y = W * 0.12, H * 0.78
    s = (f'<line x1="{x}" y1="{y - 90}" x2="{x + 120}" y2="{y - 90}" stroke="{p["orange"]}" '
         f'stroke-width="6"/>'
         f'<text x="{x}" y="{y}" font-family="ABC Areal" font-weight="500" font-size="64" '
         f'fill="{p["ink"]}">Weniger, aber besser.</text>'
         f'<text x="{x}" y="{y + 70}" font-family="ABC Areal" font-size="34" '
         f'fill="{p["text"]}">Less, but better. — Dieter Rams</text>')
    return svg(p, s)


def main():
    if not shutil.which("rsvg-convert"):
        raise SystemExit("rsvg-convert not found (pacman: librsvg)")
    for p in PALETTES.values():
        p["out"].mkdir(parents=True, exist_ok=True)
        for name, fn in [("0-clock", clock), ("1-grille", grille), ("2-perforation", perforation),
                         ("3-keys", keys), ("4-weniger", weniger)]:
            png = p["out"] / f"{name}.png"
            subprocess.run(["rsvg-convert", "-o", str(png), "-"],
                           input=fn(p).encode(), check=True)
            print(png.relative_to(ROOT))


if __name__ == "__main__":
    main()
