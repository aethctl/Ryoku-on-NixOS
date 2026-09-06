#version 440

// skwd transition: ports SMOKE_FRAG from skwd-daemon
// (crates/paper/src/transition_paper.rs); math verbatim, only uniform plumbing
// is Qt's.

layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;

layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;
    float progress;
    float seed;
    vec2 res;
};

layout(binding = 1) uniform sampler2D oldTex;
layout(binding = 2) uniform sampler2D newTex;

float hash(vec2 p) {
    return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}
float noise(vec2 p) {
    vec2 i = floor(p);
    vec2 f = fract(p);
    f = f * f * (3.0 - 2.0 * f);
    return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), f.x),
               mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), f.x), f.y);
}
float fbm(vec2 p) {
    float v = 0.0;
    float amp = 0.5;
    for (int i = 0; i < 6; i++) {
        v += amp * noise(p);
        p *= 2.0;
        amp *= 0.5;
    }
    return v;
}
float warpedFbm(vec2 p, float t) {
    vec2 q = vec2(fbm(p), fbm(p + vec2(5.2, 1.3)));
    vec2 r = vec2(fbm(p + 6.0 * q + vec2(1.7, 9.2) + 0.25 * t),
                  fbm(p + 6.0 * q + vec2(8.3, 2.8) + 0.22 * t));
    vec2 s = vec2(fbm(p + 5.0 * r + vec2(3.1, 7.4) + 0.18 * t),
                  fbm(p + 5.0 * r + vec2(6.7, 0.9) + 0.20 * t));
    return fbm(p + 6.0 * s);
}
void main() {
    vec2 v_uv = qt_TexCoord0;
    float p = progress;
    vec2 uv = v_uv;
    float t = p * 12.0;
    float fluid = warpedFbm(uv * 2.0, t);
    vec2 center = uv - 0.5;
    float dist = length(center * vec2(1.0, 0.7));
    float visibility = (1.0 - dist) * 1.2 + fluid * 0.7;
    float reveal_progress = p * 2.5 - 0.4;
    float reveal_mask = smoothstep(visibility - 0.4, visibility + 0.4, reveal_progress);
    float distort_strength = sin(p * 3.14159) * 0.35;
    vec2 wq = vec2(fbm(uv * 2.0 + vec2(0.0, t * 0.2)),
                   fbm(uv * 2.0 + vec2(5.2, t * 0.2)));
    vec2 wr = vec2(fbm(uv * 2.0 + 4.0 * wq + vec2(1.7, 9.2)),
                   fbm(uv * 2.0 + 4.0 * wq + vec2(8.3, 2.8)));
    vec2 warped_uv = uv + (wr - 0.5) * distort_strength;
    vec4 a = texture(oldTex, warped_uv);
    vec4 b = texture(newTex, warped_uv);
    fragColor = (mix(a, b, reveal_mask)) * qt_Opacity;
}
