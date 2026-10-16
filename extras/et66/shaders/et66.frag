#version 440
// The ET 66, rendered as an object under the same light as the Rams dial
// (top left). Measured in device pixels. Body: matte, finely textured
// plastic with a softened edge. Display: a window recessed into the body,
// glass over a grey-green LCD. Keys: round caps standing off the body, with
// a chamfered edge and a shallow dish on top; a pressed key sinks and its
// shadow shortens. Labels and digits come from printTex: red = key labels,
// green = display digits.

layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;

layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;
    vec2 res;          // item size, device px
    vec4 body;         // x, y, w, h (device px)
    float bodyRadius;
    vec4 display;      // x, y, w, h
    vec2 gridOrigin;   // centre of key (0,0)
    float keyPitch;    // centre to centre
    float keyRadius;
    float pressed;     // key index 0..19, or -1
};
layout(binding = 1) uniform sampler2D printTex;

vec3 Lv;

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
float grain(vec2 px) { return vnoise(px / 1.6) * 0.6 + vnoise(px / 4.0) * 0.4; }

float sdRoundBox(vec2 p, vec2 b, float r) {
    vec2 q = abs(p) - b + r;
    return length(max(q, 0.0)) + min(max(q.x, q.y), 0.0) - r;
}
vec2 gradRoundBox(vec2 p, vec2 b, float r) {
    float e = 0.75;
    return normalize(vec2(sdRoundBox(p + vec2(e, 0), b, r) - sdRoundBox(p - vec2(e, 0), b, r),
                          sdRoundBox(p + vec2(0, e), b, r) - sdRoundBox(p - vec2(0, e), b, r)) + 1e-6);
}

float lambert(vec3 n, float amb) { return amb + (1.0 - amb) * max(dot(n, Lv), 0.0); }
float flatL(float amb) { return amb + (1.0 - amb) * Lv.z; }
float spec(vec3 n, float p) {
    vec3 r = reflect(vec3(0.0, 0.0, -1.0), n);
    return pow(max(dot(r, Lv), 0.0), p);
}
float cover(float d) { return clamp(0.5 - d, 0.0, 1.0); }

// The ET 66 key colours: clear orange, equals yellow, operators brown,
// functions grey-brown, digits dark.
vec3 keyColor(int col, int row) {
    if (col == 0 && row == 0) return vec3(0.886, 0.333, 0.165);
    if (col == 3 && row == 4) return vec3(0.949, 0.718, 0.020);
    if (col == 3) return vec3(0.357, 0.302, 0.251);
    if (row == 0 || (row == 4 && col == 2)) return vec3(0.290, 0.267, 0.239);
    return vec3(0.215, 0.200, 0.184);
}

void main() {
    Lv = normalize(vec3(-0.42, -0.80, 0.95));
    vec2 toL = normalize(Lv.xy);
    vec2 px = qt_TexCoord0 * res;
    float u = res.x / 340.0;                     // device px per design unit
    vec4 pr = texture(printTex, qt_TexCoord0);

    // ------------------------------------------------------------ body
    vec2 bc = body.xy + body.zw * 0.5;
    vec2 bh = body.zw * 0.5;
    float dB = sdRoundBox(px - bc, bh, bodyRadius);

    // Drop shadow of the body on whatever is behind the window.
    float bodyH = 14.0 * u;
    float dS = sdRoundBox(px - bc + toL * bodyH * 0.9, bh, bodyRadius);
    float shadowA = (1.0 - smoothstep(-bodyH * 0.8, bodyH * 1.4, dS)) * 0.42;

    if (dB > 1.0) { fragColor = vec4(0.0, 0.0, 0.0, shadowA) * qt_Opacity; return; }

    // Body: matte plastic, softened edge.
    float edgeW = 7.0 * u;
    float s = -dB;
    vec2 gB = gradRoundBox(px - bc, bh, bodyRadius);
    float tilt = (1.0 - smoothstep(0.0, edgeW, s)) * 1.1;
    float g0 = grain(px), gx = grain(px + vec2(1, 0)), gy = grain(px + vec2(0, 1));
    vec3 n = normalize(vec3(gB * tilt + vec2(g0 - gx, g0 - gy) * 0.25, 1.0));
    vec3 bodyCol = vec3(0.176, 0.161, 0.145);
    vec3 col = bodyCol * lambert(n, 0.55) / flatL(0.55) + spec(n, 18.0) * 0.05;

    // --------------------------------------------------------- display
    vec2 dc = display.xy + display.zw * 0.5;
    vec2 dh = display.zw * 0.5;
    float dD = sdRoundBox(px - dc, dh, 9.0 * u);
    if (dD < 1.0) {
        // The well: a dark bezel stepping down to the glass.
        float bez = 5.0 * u;
        vec3 well = vec3(0.075, 0.07, 0.065);
        float dG = sdRoundBox(px - dc, dh - bez, 6.0 * u);
        // LCD: grey-green, lit from the top through the glass.
        float t = (px.y - (dc.y - dh.y)) / display.w;
        vec3 lcd = mix(vec3(0.66, 0.675, 0.60), vec3(0.75, 0.765, 0.685), t);
        // The body casts a shadow into the window from the light's side.
        float inner = smoothstep(0.0, 14.0 * u, sdRoundBox(px - dc + toL * 9.0 * u, dh - bez, 6.0 * u) * -1.0);
        lcd *= mix(0.72, 1.0, inner);
        // Digits: dark segments with a faint shadow on the backplane.
        float dig = pr.g;
        float digSh = texture(printTex, qt_TexCoord0 - toL * vec2(1.6 * u / res.x, 1.6 * u / res.y)).g;
        lcd *= 1.0 - 0.10 * digSh;
        lcd = mix(lcd, vec3(0.13, 0.14, 0.11), dig * 0.92);
        // Glass: a broad, faint reflection across the top.
        lcd += vec3(1.0) * 0.06 * (1.0 - smoothstep(0.0, 0.55, t));
        vec3 w = mix(well, lcd, cover(dG));
        col = mix(col, w, cover(dD));
    }

    // ------------------------------------------------------------ keys
    vec2 g = (px - gridOrigin) / keyPitch;
    ivec2 cell = ivec2(floor(g + 0.5));
    // Shadows of nearby keys (this cell and the one toward the light).
    float lit = 1.0;
    for (int oy = -1; oy <= 0; oy++) {
        for (int ox = -1; ox <= 0; ox++) {
            ivec2 c2 = ivec2(floor(g + 0.5)) + ivec2(ox, oy) * ivec2(sign(-toL));
            if (c2.x < 0 || c2.x > 3 || c2.y < 0 || c2.y > 4) continue;
            int idx = c2.y * 4 + c2.x;
            float hk = (abs(float(idx) - pressed) < 0.5 ? 3.0 : 7.0) * u;
            vec2 kc = gridOrigin + vec2(c2) * keyPitch;
            float dk = length(px + toL * hk * 0.9 - kc) - keyRadius;
            lit *= mix(0.45, 1.0, smoothstep(-hk * 0.6, hk * 1.1, dk));
        }
    }
    col *= lit;

    if (cell.x >= 0 && cell.x < 4 && cell.y >= 0 && cell.y < 5) {
        int idx = cell.y * 4 + cell.x;
        bool down = abs(float(idx) - pressed) < 0.5;
        vec2 kc = gridOrigin + vec2(cell) * keyPitch;
        vec2 kp = px - kc;
        float rr = length(kp);
        float dk = rr - keyRadius;
        if (dk < 1.0) {
            vec2 radial = kp / max(rr, 1e-3);
            float chamfer = 3.2 * u;
            float s2 = -dk;
            vec3 nk;
            if (s2 < chamfer) {
                // Chamfered rim, sloping down and out.
                nk = normalize(vec3(radial * 0.9, 1.0));
            } else {
                // Dished top: slopes gently toward the centre.
                float rt = rr / (keyRadius - chamfer);
                nk = normalize(vec3(-radial * rt * 0.22, 1.0));
            }
            vec3 kcCol = keyColor(cell.x, cell.y);
            float amb = down ? 0.62 : 0.55;
            vec3 key = kcCol * lambert(nk, amb) / flatL(amb) + spec(nk, 30.0) * 0.10;
            // A pressed key sits lower and takes a little less light.
            key *= down ? 0.9 : 1.0;
            // Label, printed on the dish.
            bool equals = cell.x == 3 && cell.y == 4;
            vec3 ink = equals ? vec3(0.17, 0.14, 0.11) : vec3(0.93, 0.91, 0.87);
            key = mix(key, ink * lambert(nk, 0.7) / flatL(0.7), pr.r);
            col = mix(col, key, cover(dk));
        }
    }

    fragColor = vec4(col, 1.0) * cover(dB) * qt_Opacity + vec4(0.0, 0.0, 0.0, shadowA) * (1.0 - cover(dB)) * qt_Opacity;
}
