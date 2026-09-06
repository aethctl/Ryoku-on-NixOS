#version 440

// skwd transition: ports INK_SPLASH_FRAG from skwd-daemon
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
    for (int i = 0; i < 5; i++) {
        v += amp * noise(p);
        p *= 2.1;
        amp *= 0.5;
    }
    return v;
}
void main() {
    vec2 v_uv = qt_TexCoord0;
    float p = progress;
    float blob = fbm(v_uv * 3.5);
    float fingers = fbm(v_uv * 14.0);
    float distortion = (blob - 0.5) * 0.5 + (fingers - 0.5) * 0.18;
    vec2 c = v_uv - vec2(0.5);
    c.x *= 1.7777;
    float d = length(c);
    float splash_d = d + distortion;
    float boundary = p * 1.7 - 0.15;
    float diff = splash_d - boundary;
    float reveal = smoothstep(0.04, -0.04, diff);
    float edge_outer = smoothstep(0.16, 0.02, diff);
    float edge_inner = smoothstep(0.02, -0.04, diff);
    float edge = edge_outer * (1.0 - edge_inner);
    vec4 a = texture(oldTex, v_uv);
    vec4 b = texture(newTex, v_uv);
    vec4 mixed = mix(a, b, reveal);
    vec3 ink = vec3(0.03, 0.01, 0.06);
    mixed.rgb = mix(mixed.rgb, ink, edge * 0.95);
    float fingers_pre = smoothstep(0.25, 0.05, diff) * (1.0 - reveal);
    mixed.rgb = mix(mixed.rgb, ink, fingers_pre * fingers * 0.4);
    fragColor = (mixed) * qt_Opacity;
}
