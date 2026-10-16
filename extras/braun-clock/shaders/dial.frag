#version 440
// The Rams dial, rendered as an object under one fixed light.
//
// Everything is measured in dial units (R = 1, y down, 12 o'clock at
// (0, -1)). Shapes are signed distance fields, so edges stay crisp at any
// size. Parts stand at real heights and cast shadows by those heights;
// polished parts reflect a simple studio (bright above, dark below), so a
// facet facing the light shines and the facet facing away goes dark, and
// that changes as a hand turns. Printing comes from printTex: red = ink
// (track, figures), green = hour numerals (ink by day, lume by night).

layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;

layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;
    vec2 res;          // item size, device px
    vec2 center;       // dial centre, device px
    float radius;      // R, device px
    float hourA;       // hand angles, radians clockwise from 12
    float minA;
    float secA;
    float night;       // 0 day, 1 night
    float showSec;
    float printScale;  // printTex spans [-printScale, printScale]
    vec4 dialColor;
    vec4 inkColor;
    vec4 lumeDay;
    vec4 lumeNight;
    vec4 handTint;     // lacquered metal of hands, hub and index frames
    vec4 paintColor;   // second hand
};
layout(binding = 1) uniform sampler2D printTex;

const float PI = 3.14159265;

// ------------------------------------------------------------ geometry
// Index: applied capsule along the radius.
const float IDX_IN = 0.795, IDX_LEN = 0.135, IDX_R = 0.021, IDX_FRAME = 0.0085, IDX_H = 0.010;
// Hands: tail, tip, radius at tail, radius at tip, height.
const vec4 HOUR = vec4(-0.10, 0.52, 0.030, 0.017);
const vec4 MINUTE = vec4(-0.10, 0.84, 0.023, 0.011);
const float HOUR_H = 0.022, MIN_H = 0.036, SEC_H = 0.050;
const float SEC_TAIL = -0.24, SEC_TIP = 0.90, SEC_R = 0.0048;

// ---------------------------------------------------------------- noise
float hash(vec2 p) {
    p = fract(p * vec2(123.34, 456.21));
    p += dot(p, p + 45.32);
    return fract(p.x * p.y);
}
float vnoise(vec2 p) {
    vec2 i = floor(p), f = fract(p);
    vec2 u = f * f * (3.0 - 2.0 * f);
    return mix(mix(hash(i), hash(i + vec2(1, 0)), u.x),
               mix(hash(i + vec2(0, 1)), hash(i + vec2(1, 1)), u.x), u.y);
}
// A fine pebbled finish, measured in device pixels so it reads as a
// surface at any dial size.
float pebble(vec2 px) {
    return vnoise(px / 2.6) * 0.55 + vnoise(px / 6.0) * 0.25 + vnoise(px / 1.3) * 0.20;
}

// ----------------------------------------------------------------- SDFs
// Capsule whose radius tapers from r1 at the base to r2 at height h,
// along +y. (After Inigo Quilez.)
float sdUneven(vec2 p, float r1, float r2, float h) {
    p.x = abs(p.x);
    float b = (r1 - r2) / h;
    float a = sqrt(1.0 - b * b);
    float k = dot(p, vec2(-b, a));
    if (k < 0.0) return length(p) - r1;
    if (k > a * h) return length(p - vec2(0.0, h)) - r2;
    return dot(p, vec2(a, b)) - r1;
}

vec2 handDir(float a) { return vec2(sin(a), -cos(a)); }
vec2 handPerp(float a) { return vec2(cos(a), sin(a)); }

float sdHand(vec2 q, float a, vec4 g) {
    vec2 l = vec2(dot(q, handPerp(a)), dot(q, handDir(a)) - g.x);
    return sdUneven(l, g.z, g.w, g.y - g.x);
}
// The lume channel: the hand inset by its frame, shortened at both ends.
float sdHandLume(vec2 q, float a, vec4 g, float frame) {
    float u0 = 0.11, u1 = g.y - 0.045;
    float t0 = (u0 - g.x) / (g.y - g.x), t1 = (u1 - g.x) / (g.y - g.x);
    float r0 = mix(g.z, g.w, t0) - frame, r1 = mix(g.z, g.w, t1) - frame;
    vec2 l = vec2(dot(q, handPerp(a)), dot(q, handDir(a)) - u0);
    return sdUneven(l, r0, r1, u1 - u0);
}

// Nearest hour index: returns its angle.
float indexAngle(vec2 q) {
    float ang = atan(q.x, -q.y);
    return floor(ang / (PI / 6.0) + 0.5) * (PI / 6.0);
}
float sdIndex(vec2 q, float a) {
    vec2 l = vec2(dot(q, handPerp(a)), dot(q, handDir(a)) - IDX_IN);
    return sdUneven(l, IDX_R, IDX_R, IDX_LEN);
}
float sdIndexLume(vec2 q, float a) {
    vec2 l = vec2(dot(q, handPerp(a)), dot(q, handDir(a)) - IDX_IN - IDX_FRAME * 0.9);
    return sdUneven(l, IDX_R - IDX_FRAME, IDX_R - IDX_FRAME, IDX_LEN - IDX_FRAME * 1.8);
}
float sdIndexAny(vec2 q) { return sdIndex(q, indexAngle(q)); }

float sdSecond(vec2 q) {
    vec2 l = vec2(dot(q, handPerp(secA)), dot(q, handDir(secA)) - SEC_TAIL);
    return sdUneven(l, SEC_R, SEC_R * 0.75, SEC_TIP - SEC_TAIL);
}

// --------------------------------------------------------------- light
vec3 Lv;
float amb, dif;

float lambert(vec3 n) { return amb + dif * max(dot(n, Lv), 0.0); }
float flatLight() { return amb + dif * Lv.z; }

// Lacquered metal: a dark tinted body that mirrors a soft studio, with a
// hard highlight from the key light.
vec3 lacquer(vec3 n, vec3 tint) {
    vec3 r = reflect(vec3(0.0, 0.0, -1.0), n);
    float up = -r.y;
    vec3 studio = mix(vec3(0.10), vec3(1.0), smoothstep(-0.45, 0.65, up + r.x * -0.25));
    float spec = pow(max(dot(r, Lv), 0.0), 48.0);
    vec3 c = tint * (0.60 + 0.40 * lambert(n)) + studio * 0.085 + spec * 0.55;
    return c * mix(1.0, 0.035, night);
}

// Matte paint (second hand, lume by day): diffuse plus a little sheen.
vec3 paint(vec3 n, vec3 col) {
    vec3 r = reflect(vec3(0.0, 0.0, -1.0), n);
    float spec = pow(max(dot(r, Lv), 0.0), 24.0) * 0.25;
    return (col * lambert(n) / flatLight() + spec) * mix(1.0, 0.06, night);
}

float coverage(float d, float aa) { return clamp(0.5 - d / aa, 0.0, 1.0); }
// 1 = lit, 0 = fully shadowed; d is the occluder's SDF at the shifted point.
float occlusion(float d, float soft) { return smoothstep(-soft, soft, d); }

vec2 gradOf(int which, vec2 q, float e) {
    vec2 ex = vec2(e, 0.0), ey = vec2(0.0, e);
    if (which == 0) return normalize(vec2(sdHand(q + ex, hourA, HOUR) - sdHand(q - ex, hourA, HOUR),
                                          sdHand(q + ey, hourA, HOUR) - sdHand(q - ey, hourA, HOUR)) + 1e-6);
    return normalize(vec2(sdHand(q + ex, minA, MINUTE) - sdHand(q - ex, minA, MINUTE),
                          sdHand(q + ey, minA, MINUTE) - sdHand(q - ey, minA, MINUTE)) + 1e-6);
}

// A hand's colour at q: two polished facets meeting at a ridge down the
// middle, rounded edges, and a lume channel set into the ridge.
vec3 handColor(vec2 q, float a, vec4 g, int which, float aa, out float lumeD) {
    vec2 perp = handPerp(a);
    float v = dot(q, perp);
    float d = sdHand(q, a, g);
    vec2 grad = gradOf(which, q, aa);
    float edge = smoothstep(0.0085, 0.0, -d);
    vec3 n = normalize(vec3(perp * sign(v) * 0.30 + grad * edge * 1.1, 1.0));
    vec3 c = lacquer(n, handTint.rgb);

    float frame = (which == 0) ? 0.0085 : 0.0068;
    lumeD = sdHandLume(q, a, g, frame);
    float lc = coverage(lumeD, aa);
    // Lume sits a little below the frame: soft inner shadow at its edge.
    float inner = 1.0 - 0.28 * smoothstep(0.006, 0.0, -lumeD) * (1.0 - night);
    vec3 lume = mix(paint(vec3(0, 0, 1), lumeDay.rgb) * inner, lumeNight.rgb * 1.05, night);
    return mix(c, lume, lc);
}

void main() {
    Lv = normalize(vec3(-0.42, -0.80, 0.95));
    vec2 toL = normalize(Lv.xy);
    amb = mix(0.62, 0.95, night);
    dif = 1.0 - amb;

    vec2 px = qt_TexCoord0 * res;
    vec2 q = (px - center) / radius;
    float aa = 1.0 / radius;
    const float SH_LEN = 1.05;            // shadow length per unit height
    float shadowAmt = mix(0.42, 0.75, night);

    // ---------------------------------------------------------- dial
    float h0 = pebble(px), hx = pebble(px + vec2(1, 0)), hy = pebble(px + vec2(0, 1));
    vec3 nDial = normalize(vec3((h0 - hx) * 0.42, (h0 - hy) * 0.42, 1.0));

    vec2 puv = q / (2.0 * printScale) + 0.5;
    vec4 pr = vec4(0.0);
    if (puv.x >= 0.0 && puv.y >= 0.0 && puv.x <= 1.0 && puv.y <= 1.0) pr = texture(printTex, puv);
    float inkM = clamp(pr.r + pr.g * (1.0 - night), 0.0, 1.0);
    vec3 surface = mix(dialColor.rgb, inkColor.rgb, inkM * mix(1.0, 0.55, night));
    vec3 col = surface * lambert(nDial) / flatLight();

    // Shadows on the dial, each by its part's height.
    float lit = 1.0;
    lit *= mix(1.0 - shadowAmt * 0.8, 1.0, occlusion(sdIndexAny(q + toL * IDX_H * SH_LEN), aa + IDX_H * 0.5));
    lit *= mix(1.0 - shadowAmt, 1.0, occlusion(sdHand(q + toL * HOUR_H * SH_LEN, hourA, HOUR), aa + HOUR_H * 0.55));
    lit *= mix(1.0 - shadowAmt, 1.0, occlusion(sdHand(q + toL * MIN_H * SH_LEN, minA, MINUTE), aa + MIN_H * 0.55));
    if (showSec > 0.5)
        lit *= mix(1.0 - shadowAmt * 0.9, 1.0, occlusion(sdSecond(q + toL * SEC_H * SH_LEN), aa + SEC_H * 0.5));
    col *= lit;

    // Lume glow, at night: indices, hands and the printed numerals.
    vec3 glow = vec3(0.0);

    // ------------------------------------------------------- indices
    {
        float a = indexAngle(q);
        float d = sdIndex(q, a);
        float c = coverage(d, aa);
        if (c > 0.0 || night > 0.0) {
            vec2 dir = handDir(a), perp = handPerp(a);
            vec2 l = vec2(dot(q, perp), dot(q, dir) - IDX_IN);
            vec2 nearest = vec2(0.0, clamp(l.y, 0.0, IDX_LEN));
            vec2 gl = normalize(l - nearest + 1e-6);
            vec2 g = perp * gl.x + dir * gl.y;
            float s = -d;
            // Rounded frame: tilts outward at the outer edge, inward at the lume.
            float x = clamp(1.0 - 2.0 * s / IDX_FRAME, -1.0, 1.0);
            vec3 n = normalize(vec3(g * x * 1.25, 1.0));
            vec3 frameC = lacquer(n, handTint.rgb);
            float dl = sdIndexLume(q, a);
            float lc = coverage(dl, aa);
            float inner = 1.0 - 0.30 * smoothstep(0.006, 0.0, -dl) * (1.0 - night);
            vec3 lume = mix(paint(vec3(0, 0, 1), lumeDay.rgb) * inner, lumeNight.rgb, night);
            // Hands above shade the index too.
            float l2 = 1.0;
            l2 *= mix(1.0 - shadowAmt, 1.0, occlusion(sdHand(q + toL * (HOUR_H - IDX_H) * SH_LEN, hourA, HOUR), aa + HOUR_H * 0.5));
            l2 *= mix(1.0 - shadowAmt, 1.0, occlusion(sdHand(q + toL * (MIN_H - IDX_H) * SH_LEN, minA, MINUTE), aa + MIN_H * 0.5));
            vec3 part = mix(frameC, lume, lc) * mix(1.0, l2, 1.0 - night * lc);
            col = mix(col, part, c);
            glow += lumeNight.rgb * exp(-max(dl, 0.0) / 0.016) * 0.30 * night;
        }
    }

    // Printed numerals glow faintly at night.
    glow += lumeNight.rgb * pr.g * night * 0.95;

    // --------------------------------------------------------- hands
    {
        float d = sdHand(q, hourA, HOUR);
        float c = coverage(d, aa);
        float ld = 1.0;
        if (c > 0.0) {
            vec3 hc = handColor(q, hourA, HOUR, 0, aa, ld);
            float l2 = mix(1.0 - shadowAmt, 1.0, occlusion(sdHand(q + toL * (MIN_H - HOUR_H) * SH_LEN, minA, MINUTE), aa + (MIN_H - HOUR_H) * 0.6));
            if (showSec > 0.5) l2 *= mix(1.0 - shadowAmt * 0.9, 1.0, occlusion(sdSecond(q + toL * (SEC_H - HOUR_H) * SH_LEN), aa + 0.01));
            col = mix(col, hc * mix(l2, 1.0, night), c);
        } else {
            ld = sdHandLume(q, hourA, HOUR, 0.0085);
        }
        glow += lumeNight.rgb * exp(-max(ld, 0.0) / 0.020) * 0.32 * night;
    }
    {
        float d = sdHand(q, minA, MINUTE);
        float c = coverage(d, aa);
        float ld = 1.0;
        if (c > 0.0) {
            vec3 hc = handColor(q, minA, MINUTE, 1, aa, ld);
            float l2 = 1.0;
            if (showSec > 0.5) l2 = mix(1.0 - shadowAmt * 0.9, 1.0, occlusion(sdSecond(q + toL * (SEC_H - MIN_H) * SH_LEN), aa + 0.008));
            col = mix(col, hc * mix(l2, 1.0, night), c);
        } else {
            ld = sdHandLume(q, minA, MINUTE, 0.0068);
        }
        glow += lumeNight.rgb * exp(-max(ld, 0.0) / 0.020) * 0.32 * night;
    }

    // Hub: a lacquered boss under the hands.
    {
        float d = length(q) - 0.052;
        float c = coverage(d, aa);
        vec3 n = normalize(vec3(q / 0.052 * 0.65, 1.0));
        col = mix(col, lacquer(n, handTint.rgb), c);
    }

    // ----------------------------------------------------- second hand
    if (showSec > 0.5) {
        float d = sdSecond(q);
        float c = coverage(d, aa * 0.9);
        float v = dot(q, handPerp(secA));
        vec3 n = normalize(vec3(handPerp(secA) * clamp(v / SEC_R, -1.0, 1.0) * 0.7, 1.0));
        col = mix(col, paint(n, paintColor.rgb), c);
        // Its cap, a small painted dome, and the arbor through it.
        float dc = length(q) - 0.030;
        vec3 nc = normalize(vec3(q / 0.030 * 0.7, 1.0));
        col = mix(col, paint(nc, paintColor.rgb), coverage(dc, aa));
        col = mix(col, lacquer(vec3(0, 0, 1), handTint.rgb) * 0.6, coverage(length(q) - 0.008, aa));
    }

    col += glow;
    fragColor = vec4(col, 1.0) * qt_Opacity;
}
