#version 440

// skwd transition: ports WAVE_WARP_FRAG from skwd-daemon
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

const float smoothness = 0.5;
const vec2 direction = vec2(1.0, 0.0);
const vec2 center = vec2(0.5, 0.5);
void main() {
    vec2 v_uv = qt_TexCoord0;
    vec2 v = normalize(direction);
    v /= abs(v.x) + abs(v.y);
    float d = v.x * center.x + v.y * center.y;
    float m = 1.0 - smoothstep(-smoothness, 0.0, v.x * v_uv.x + v.y * v_uv.y - (d - 0.5 + progress * (1.0 + smoothness)));
    fragColor = (mix(
        texture(oldTex, (v_uv - 0.5) * (1.0 - m) + 0.5),
        texture(newTex, (v_uv - 0.5) * m + 0.5),
        m
    )) * qt_Opacity;
}
