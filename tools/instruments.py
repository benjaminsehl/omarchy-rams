#!/usr/bin/env python3
"""Build "Rams Instruments": the bar's status icons, redrawn as Braun
instruments.

It covers the Material Design Nerd Font code points Omarchy's bar uses
(battery, volume, microphone, wifi, Bluetooth, monitor, indicators, power
profiles), with the same metrics, so they drop in as a fontconfig fallback
right after ABC Areal Mono. Anything not drawn here falls through to
JetBrainsMono Nerd Font as before.

Drawing rules: one stroke weight; active parts solid, inactive parts as
hairlines (a font can't dim); a level is a count of segments, like a
Braun meter; colour is left to the bar.

Usage: uv run --with fonttools tools/instruments.py
Writes extras/instruments/RamsInstruments.otf
"""
import math
import pathlib

from fontTools.fontBuilder import FontBuilder
from fontTools.pens.t2CharStringPen import T2CharStringPen

ROOT = pathlib.Path(__file__).resolve().parent.parent
OUT = ROOT / "extras/instruments/RamsInstruments.otf"

ADV = 600          # Nerd Font glyphs advance one cell and overflow right
CY = 360           # optical centre of the Nerd Font icon box (-56..776)
W = 64             # stroke
HAIR = 26          # inactive stroke
K = 0.5523         # cubic circle constant


class G:
    """Collects contours for one glyph. Outer shapes clockwise, holes
    counter-clockwise (CFF, non-zero winding)."""

    def __init__(self):
        self.ops = []

    # -- primitives ------------------------------------------------------
    def poly(self, pts, cw=True):
        # Shoelace: positive area = counter-clockwise in y-up space.
        area = sum(x0 * y1 - x1 * y0 for (x0, y0), (x1, y1) in zip(pts, pts[1:] + pts[:1]))
        if (area > 0) == cw:
            pts = list(reversed(pts))
        self.ops.append(("poly", pts))

    def circle(self, cx, cy, r, cw=True):
        self.ops.append(("circle", (cx, cy, r, cw)))

    def rrect(self, x0, y0, x1, y1, r, cw=True):
        r = min(r, (x1 - x0) / 2, (y1 - y0) / 2)
        self.ops.append(("rrect", (x0, y0, x1, y1, r, cw)))

    def frame(self, x0, y0, x1, y1, r, t):
        self.rrect(x0, y0, x1, y1, r, True)
        self.rrect(x0 + t, y0 + t, x1 - t, y1 - t, max(0, r - t), False)

    def ring(self, cx, cy, r, t):
        self.circle(cx, cy, r, True)
        self.circle(cx, cy, r - t, False)

    def line(self, x0, y0, x1, y1, t):
        """A stroke with round caps."""
        dx, dy = x1 - x0, y1 - y0
        L = math.hypot(dx, dy) or 1
        nx, ny = -dy / L * t / 2, dx / L * t / 2
        self.poly([(x0 + nx, y0 + ny), (x1 + nx, y1 + ny), (x1 - nx, y1 - ny), (x0 - nx, y0 - ny)])
        self.circle(x0, y0, t / 2)
        self.circle(x1, y1, t / 2)

    def arc(self, cx, cy, r, a0, a1, t, caps=True, steps=48):
        """A stroked arc from a0 to a1 degrees (0 = right, counter-clockwise)."""
        ro, ri = r + t / 2, r - t / 2
        n = max(4, int(abs(a1 - a0) / 360 * steps) + 2)
        angs = [math.radians(a0 + (a1 - a0) * i / (n - 1)) for i in range(n)]
        outer = [(cx + ro * math.cos(a), cy + ro * math.sin(a)) for a in angs]
        inner = [(cx + ri * math.cos(a), cy + ri * math.sin(a)) for a in reversed(angs)]
        self.poly(outer + inner)
        if caps:
            for a in (angs[0], angs[-1]):
                self.circle(cx + r * math.cos(a), cy + r * math.sin(a), t / 2)

    # -- output ----------------------------------------------------------
    def draw(self, pen):
        for kind, a in self.ops:
            if kind == "poly":
                pts = a
                pen.moveTo(pts[0])
                for p in pts[1:]:
                    pen.lineTo(p)
                pen.closePath()
            elif kind == "circle":
                cx, cy, r, cw = a
                k = K * r
                if cw:
                    pen.moveTo((cx, cy + r))
                    pen.curveTo((cx + k, cy + r), (cx + r, cy + k), (cx + r, cy))
                    pen.curveTo((cx + r, cy - k), (cx + k, cy - r), (cx, cy - r))
                    pen.curveTo((cx - k, cy - r), (cx - r, cy - k), (cx - r, cy))
                    pen.curveTo((cx - r, cy + k), (cx - k, cy + r), (cx, cy + r))
                else:
                    pen.moveTo((cx, cy + r))
                    pen.curveTo((cx - k, cy + r), (cx - r, cy + k), (cx - r, cy))
                    pen.curveTo((cx - r, cy - k), (cx - k, cy - r), (cx, cy - r))
                    pen.curveTo((cx + k, cy - r), (cx + r, cy - k), (cx + r, cy))
                    pen.curveTo((cx + r, cy + k), (cx + k, cy + r), (cx, cy + r))
                pen.closePath()
            elif kind == "rrect":
                x0, y0, x1, y1, r, cw = a
                k = (1 - K) * r
                if cw:
                    pen.moveTo((x0 + r, y1))
                    pen.lineTo((x1 - r, y1))
                    pen.curveTo((x1 - k, y1), (x1, y1 - k), (x1, y1 - r)) if r else None
                    pen.lineTo((x1, y0 + r))
                    pen.curveTo((x1, y0 + k), (x1 - k, y0), (x1 - r, y0)) if r else None
                    pen.lineTo((x0 + r, y0))
                    pen.curveTo((x0 + k, y0), (x0, y0 + k), (x0, y0 + r)) if r else None
                    pen.lineTo((x0, y1 - r))
                    pen.curveTo((x0, y1 - k), (x0 + k, y1), (x0 + r, y1)) if r else None
                else:
                    pen.moveTo((x0 + r, y1))
                    pen.curveTo((x0 + k, y1), (x0, y1 - k), (x0, y1 - r)) if r else None
                    pen.lineTo((x0, y0 + r))
                    pen.curveTo((x0, y0 + k), (x0 + k, y0), (x0 + r, y0)) if r else None
                    pen.lineTo((x1 - r, y0))
                    pen.curveTo((x1 - k, y0), (x1, y0 + k), (x1, y0 + r)) if r else None
                    pen.lineTo((x1, y1 - r))
                    pen.curveTo((x1, y1 - k), (x1 - k, y1), (x1 - r, y1)) if r else None
                pen.closePath()


# --------------------------------------------------------------- glyphs

def battery(level, charging=False):
    """Horizontal cell with five segments. Charging adds an indicator dot."""
    g = G()
    x1 = 640 if charging else 736
    g.frame(0, CY - 200, x1, CY + 200, 92, 52)
    g.rrect(x1 + 20, CY - 88, x1 + 84, CY + 88, 28)
    ix0, ix1 = 52 + 34, x1 - 52 - 34
    gap = 26
    seg = (ix1 - ix0 - 4 * gap) / 5
    for i in range(5):
        sx = ix0 + i * (seg + gap)
        if i < level:
            g.rrect(sx, CY - 114, sx + seg, CY + 114, 14)
    if charging:
        g.circle(812, CY, 58)
    return g


def speaker(g):
    g.poly([(0, CY + 120), (120, CY + 120), (290, CY + 270), (290, CY - 270), (120, CY - 120), (0, CY - 120)])


def volume(active):
    """Speaker and a three-bar level meter; muted shows the empty meter."""
    g = G()
    speaker(g)
    base = CY - 230
    for i, h in enumerate((200, 330, 460)):
        x = 410 + i * 150
        if i < active:
            g.rrect(x, base, x + W, base + h, W / 2)
        else:
            g.frame(x, base, x + W, base + h, W / 2, HAIR)
    return g


def microphone(off=False):
    g = G()
    if off:
        g.frame(300, CY - 40, 532, CY + 380, 116, W * 0.8)
    else:
        g.rrect(300, CY - 40, 532, CY + 380, 116)
    g.arc(416, CY + 80, 230, 180, 360, W * 0.8)
    g.rrect(388, CY - 330, 444, CY - 150, 20)
    g.rrect(260, CY - 380, 572, CY - 326, 27)
    if off:
        g.line(120, CY - 380, 712, CY + 380, W * 0.8)
    return g


def headphones():
    g = G()
    g.arc(416, CY - 20, 360, 0, 180, W)
    g.rrect(10, CY - 360, 200, CY + 20, 70)
    g.rrect(632, CY - 360, 822, CY + 20, 70)
    return g


def wifi(strength, off=False):
    """Dot and three arcs. Live parts solid, the rest as hairlines."""
    g = G()
    ox, oy = 416, CY - 330
    if strength >= 1:
        g.circle(ox, oy, 62)
    else:
        g.ring(ox, oy, 62, HAIR)
    for i, r in enumerate((250, 450, 650)):
        live = strength >= i + 2
        g.arc(ox, oy, r, 48, 132, W if live else HAIR)
    if off:
        g.line(130, CY - 380, 702, CY + 380, W * 0.8)
    return g


def ethernet():
    g = G()
    g.frame(96, CY - 300, 736, CY + 300, 90, W)
    g.rrect(276, CY - 110, 556, CY + 110, 30)
    return g


def bluetooth(mode=""):
    g = G()
    t = W * 0.85
    pts = [(250, CY + 190), (590, CY - 150), (416, CY - 324), (416, CY + 324), (590, CY + 150), (250, CY - 190)]
    for a, b in zip(pts, pts[1:]):
        g.line(*a, *b, t)
    if mode == "connect":
        g.circle(110, CY, 52)
        g.circle(722, CY, 52)
    if mode == "off":
        g.line(140, CY - 380, 692, CY + 380, t)
    return g


def monitor(multiple=False):
    g = G()
    if multiple:
        g.frame(150, CY - 110, 832, CY + 400, 56, HAIR * 1.6)
        g.frame(0, CY - 220, 682, CY + 290, 56, W * 0.85)
        g.rrect(300, CY - 330, 382, CY - 220, 16)
        g.rrect(190, CY - 380, 492, CY - 328, 26)
    else:
        g.frame(0, CY - 200, 832, CY + 340, 60, W * 0.85)
        g.rrect(376, CY - 320, 456, CY - 200, 16)
        g.rrect(236, CY - 380, 596, CY - 320, 30)
    return g


def gauge(needle_deg):
    """Power profiles on one Braun dial: saver left, balanced up,
    performance right."""
    g = G()
    cx, cy = 416, CY - 120
    g.arc(cx, cy, 380, -15, 195, W * 0.8)
    a = math.radians(needle_deg)
    g.line(cx, cy, cx + 300 * math.cos(a), cy + 300 * math.sin(a), W)
    g.circle(cx, cy, 70)
    return g


def record():
    g = G()
    g.circle(416, CY, 250)
    return g


def no_entry():
    g = G()
    g.ring(416, CY, 360, W)
    g.rrect(206, CY - 34, 626, CY + 34, 34)
    return g


def half_moon():
    g = G()
    g.ring(416, CY, 360, W)
    # left half filled
    pts = []
    for i in range(25):
        a = math.radians(90 + 180 * i / 24)
        pts.append((416 + 300 * math.cos(a), CY + 300 * math.sin(a)))
    g.poly(pts)
    return g


def clockface():
    g = G()
    g.ring(416, CY, 360, W)
    g.line(416, CY, 416, CY + 230, W)
    g.line(416, CY, 576, CY, W)
    return g


def hourglass():
    g = G()
    g.rrect(116, CY + 330, 716, CY + 390, 30)
    g.rrect(116, CY - 390, 716, CY - 330, 30)
    g.poly([(176, CY + 330), (656, CY + 330), (430, CY + 20), (402, CY + 20)])
    g.poly([(402, CY - 20), (430, CY - 20), (656, CY - 330), (176, CY - 330)])
    return g


def cup():
    g = G()
    g.rrect(60, CY - 300, 560, CY + 200, 70)
    g.ring(600, CY - 40, 170, W)
    g.rrect(60, CY - 380, 560, CY - 330, 25)
    return g


# ------------------------------------------------------ panels and menus

def calendar():
    g = G()
    g.frame(60, CY - 330, 772, CY + 290, 70, W * 0.85)
    g.rrect(60, CY + 150, 772, CY + 290, 40)
    g.rrect(220, CY + 250, 284, CY + 400, 32)
    g.rrect(548, CY + 250, 612, CY + 400, 32)
    g.rrect(470, CY - 200, 610, CY - 60, 22)
    return g


def chevron(direction):
    g = G()
    t = W
    if direction == "left":
        g.line(520, CY + 260, 300, CY, t); g.line(300, CY, 520, CY - 260, t)
    elif direction == "right":
        g.line(312, CY + 260, 532, CY, t); g.line(532, CY, 312, CY - 260, t)
    else:  # down
        g.line(156, CY + 110, 416, CY - 150, t); g.line(416, CY - 150, 676, CY + 110, t)
    return g


def check():
    g = G()
    g.line(140, CY, 330, CY - 190, W); g.line(330, CY - 190, 700, CY + 220, W)
    return g


def close_circle():
    g = G()
    g.ring(416, CY, 360, W)
    g.line(286, CY - 130, 546, CY + 130, W); g.line(286, CY + 130, 546, CY - 130, W)
    return g


def lock():
    g = G()
    g.rrect(130, CY - 360, 702, CY + 60, 70)
    g.arc(416, CY + 70, 200, 0, 180, W, caps=False)
    g.rrect(216 - W / 2, CY + 20, 216 + W / 2, CY + 80, 0)
    g.rrect(616 - W / 2, CY + 20, 616 + W / 2, CY + 80, 0)
    return g


def refresh():
    g = G()
    g.arc(416, CY, 300, 60, 340, W)
    a = math.radians(60)
    tip = (416 + 300 * math.cos(a), CY + 300 * math.sin(a))
    g.poly([(tip[0] + 110, tip[1] + 40), (tip[0] - 120, tip[1] + 60), (tip[0] - 10, tip[1] - 150)])
    return g


def camera():
    g = G()
    g.frame(20, CY - 270, 812, CY + 250, 70, W * 0.85)
    g.rrect(250, CY + 250, 470, CY + 330, 30)
    g.ring(416, CY - 10, 170, W * 0.85)
    g.circle(416, CY - 10, 60)
    return g


def loudspeaker():
    """A Braun loudspeaker: a cabinet with one large and one small driver."""
    g = G()
    g.frame(150, CY - 380, 682, CY + 380, 70, W * 0.8)
    g.ring(416, CY - 110, 170, W * 0.8)
    g.circle(416, CY - 110, 46)
    g.circle(416, CY + 220, 62)
    return g


def marker():
    g = G()
    g.ring(416, CY + 130, 230, W)
    g.poly([(250, CY - 30), (582, CY - 30), (416, CY - 380)])
    g.circle(416, CY + 130, 70)
    return g


# Weather: a filled cloud, a sun with short rays, a crescent moon.
def cloud_shape(g, ox=0, oy=0, k=1.0):
    def X(x): return ox + x * k
    def Y(y): return oy + y * k
    g.circle(X(280), Y(CY - 40), 150 * k)
    g.circle(X(470), Y(CY + 60), 210 * k)
    g.circle(X(640), Y(CY - 50), 140 * k)
    g.rrect(X(130), Y(CY - 190), X(780), Y(CY - 40), 75 * k)


def sun_shape(g, cx=416, cy=CY, r=170, rays=True):
    g.circle(cx, cy, r)
    if rays:
        for i in range(8):
            a = math.radians(i * 45)
            g.line(cx + (r + 70) * math.cos(a), cy + (r + 70) * math.sin(a),
                   cx + (r + 150) * math.cos(a), cy + (r + 150) * math.sin(a), W * 0.8)


def moon_shape(g, cx=416, cy=CY, r=300):
    # Crescent: outer circle minus an offset circle, as one polygon.
    pts = []
    ox, oy, orr = cx + r * 0.42, cy + r * 0.30, r * 0.82
    for i in range(64):
        a = 2 * math.pi * i / 64
        x, y = cx + r * math.cos(a), cy + r * math.sin(a)
        if math.hypot(x - ox, y - oy) > orr:
            pts.append((x, y))
    # Walk back along the inner circle between the two intersections.
    inner = []
    for i in range(64):
        a = 2 * math.pi * i / 64
        x, y = ox + orr * math.cos(a), oy + orr * math.sin(a)
        if math.hypot(x - cx, y - cy) < r:
            inner.append((x, y, math.atan2(y - cy, x - cx)))
    # Order outer points by angle (start after the gap), inner reversed.
    import cmath
    def ang(p): return math.atan2(p[1] - cy, p[0] - cx)
    gap = math.atan2(oy - cy, ox - cx)
    def rel(a): return (a - gap) % (2 * math.pi)
    outer = sorted(pts, key=lambda p: rel(ang(p)))
    inner = sorted(inner, key=lambda p: -rel(p[2]))
    g.poly(outer + [(x, y) for x, y, _ in inner])


def weather(kind, night=False):
    g = G()
    if kind == "clear":
        (moon_shape if night else sun_shape)(g)
        return g
    if kind == "partly":
        if night:
            moon_shape(g, 560, CY + 200, 170)
        else:
            sun_shape(g, 560, CY + 210, 120, rays=False)
            for i in range(5):
                a = math.radians(-20 + i * 45)
                g.line(560 + 175 * math.cos(a), CY + 210 + 175 * math.sin(a),
                       560 + 235 * math.cos(a), CY + 210 + 235 * math.sin(a), W * 0.7)
        cloud_shape(g, -40, -80, 0.9)
        return g
    if kind == "fog":
        for i, (x0, x1) in enumerate(((120, 712), (60, 772), (160, 672))):
            g.line(x0, CY + 230 - i * 230, x1, CY + 230 - i * 230, W)
        return g
    cloud_shape(g, 0, 130, 0.92)
    base = CY - 140
    if kind == "cloud":
        return weather("cloud_only")
    if kind == "rain":
        for x in (250, 416, 582):
            g.line(x + 40, base, x - 30, base - 210, W * 0.8)
    elif kind == "snow":
        for x, dy in ((250, 0), (416, -110), (582, 0)):
            g.circle(x, base - 90 + dy, 48)
    elif kind == "sleet":
        g.line(290, base, 230, base - 200, W * 0.8)
        g.circle(450, base - 130, 48)
        g.line(620, base, 560, base - 200, W * 0.8)
    elif kind == "thunder":
        g.poly([(470, base + 20), (320, base - 200), (420, base - 200), (360, base - 400), (540, base - 150), (440, base - 150)])
    return g


def cloud_only():
    g = G()
    cloud_shape(g, 0, 60)
    return g


GLYPHS = {
    # battery
    0xF0079: battery(5), 0xF007A: battery(1), 0xF007B: battery(1), 0xF007C: battery(2),
    0xF007D: battery(2), 0xF007E: battery(3), 0xF007F: battery(3), 0xF0080: battery(4),
    0xF0081: battery(4), 0xF0082: battery(5),
    0xF0084: battery(5, True), 0xF0085: battery(5, True), 0xF0086: battery(1, True),
    0xF0087: battery(2, True), 0xF0088: battery(2, True), 0xF0089: battery(3, True),
    0xF008A: battery(4, True), 0xF008B: battery(5, True), 0xF089C: battery(1, True),
    0xF089D: battery(3, True), 0xF089E: battery(4, True),
    # audio
    0xEEE8: volume(0), 0xF026: volume(0), 0xF027: volume(1), 0xF028: volume(3),
    0xF057E: volume(3), 0xF075F: volume(0),
    0xF02CB: headphones(),
    0xF036C: microphone(), 0xF036D: microphone(off=True),
    # network
    0xF091F: wifi(1), 0xF0922: wifi(2), 0xF0925: wifi(3), 0xF0928: wifi(4),
    0xF092F: wifi(0), 0xF092E: wifi(0, off=True),
    0xF0200: ethernet(),
    # bluetooth, monitor
    0xF00AF: bluetooth(), 0xF00B1: bluetooth("connect"), 0xF00B2: bluetooth("off"),
    0xF0379: monitor(), 0xF037A: monitor(True),
    # indicators
    0xF0EC2: record(), 0xF009B: no_entry(), 0xF050E: half_moon(),
    0xF088C: clockface(), 0xF051F: hourglass(), 0xF0176: cup(),
    # power profiles
    0xF032A: gauge(150), 0xF029A: gauge(90), 0xF04C5: gauge(30),
    # panels and menus
    0xF00ED: calendar(), 0xF0141: chevron("left"), 0xF0142: chevron("right"),
    0xF0140: chevron("down"), 0xF012C: check(), 0xF0159: close_circle(),
    0xF033E: lock(), 0xF0450: refresh(), 0xF0100: camera(), 0xF04C3: loudspeaker(),
    0xF0996: clockface(), 0xF041: marker(),
    # weather (Weather Icons code points used by omarchy.weather)
    0xE30D: weather("clear"), 0xE32B: weather("clear", night=True),
    0xE302: weather("partly"), 0xE32E: weather("partly", night=True),
    0xE33D: cloud_only(), 0xE313: weather("fog"), 0xE346: weather("fog"),
    0xE318: weather("rain"), 0xE308: weather("rain"), 0xE333: weather("rain"),
    0xE31A: weather("snow"), 0xE30A: weather("snow"), 0xE327: weather("snow"),
    0xE3AD: weather("sleet"), 0xE31D: weather("thunder"),
}


def main():
    names = [".notdef", "space"] + [f"u{cp:04X}" if cp > 0xFFFF else f"uni{cp:04X}" for cp in GLYPHS]
    fb = FontBuilder(1000, isTTF=False)
    fb.setupGlyphOrder(names)
    cmap = {0x20: "space"}
    charstrings = {}
    for name in (".notdef", "space"):
        pen = T2CharStringPen(ADV, None)
        charstrings[name] = pen.getCharString()
    for cp, name in zip(GLYPHS, names[2:]):
        cmap[cp] = name
        pen = T2CharStringPen(ADV, None)
        GLYPHS[cp].draw(pen)
        charstrings[name] = pen.getCharString()
    fb.setupCharacterMap(cmap)
    fb.setupCFF("RamsInstruments-Regular", {"FullName": "Rams Instruments"}, charstrings, {})
    fb.setupHorizontalMetrics({n: (ADV, 0) for n in names})
    fb.setupHorizontalHeader(ascent=1020, descent=-300)
    fb.setupNameTable({
        "familyName": "Rams Instruments", "styleName": "Regular",
        "copyright": "Copyright (c) 2026 Ben Sehl. MIT License.",
        "uniqueFontIdentifier": "RamsInstruments-Regular-1.0",
        "version": "Version 1.000",
    })
    fb.setupOS2(sTypoAscender=1020, sTypoDescender=-300, usWinAscent=1020, usWinDescent=300,
                achVendID="RAMS", fsType=0)
    fb.setupPost(isFixedPitch=1)
    OUT.parent.mkdir(parents=True, exist_ok=True)
    fb.save(str(OUT))
    print(OUT.relative_to(ROOT), len(GLYPHS), "glyphs")


if __name__ == "__main__":
    main()
