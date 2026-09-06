#version 440

// skwd transition: ports INKWELL_DROP_FRAG from skwd-daemon
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

void main() {
    vec2 v_uv = qt_TexCoord0;
    float p = progress;
    vec2 impact = vec2(0.35, 0.4);
    vec2 c = v_uv - impact;
    c.x *= 1.7777;
    float d = length(c);
    float front = p * 1.5;
    float ring1 = sin((d - front) * 80.0) * exp(-abs(d - front) * 6.0);
    float ring2 = sin((d - front + 0.08) * 80.0) * exp(-abs(d - front + 0.08) * 8.0) * 0.6;
    float ring3 = sin((d - front + 0.16) * 80.0) * exp(-abs(d - front + 0.16) * 10.0) * 0.4;
    float ripple = (ring1 + ring2 + ring3) * 0.05 * (1.0 - p);
    vec2 dir = (d > 0.001) ? normalize(c) : vec2(0.0);
    vec2 distorted = v_uv + dir * ripple;
    vec4 a = texture(oldTex, distorted);
    vec4 b = texture(newTex, distorted);
    float reveal = smoothstep(0.05, -0.02, d - front);
    vec4 mixed = mix(a, b, reveal);
    float crest = exp(-abs(d - front) * 25.0) * (1.0 - p);
    mixed.rgb += vec3(0.6, 0.75, 0.95) * crest * 0.5;
    fragColor = (mixed) * qt_Opacity;
}
