#version 440

// skwd transition: ports LIQUID_RIPPLE_FRAG from skwd-daemon
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

const float amplitude = 100.0;
const float speed = 50.0;
void main() {
    vec2 v_uv = qt_TexCoord0;
    vec2 dir = v_uv - vec2(0.5);
    float dist = length(dir);
    vec2 offset = dir * (sin(progress * dist * amplitude - progress * speed) + 0.5) / 30.0 * progress;
    fragColor = (mix(
        texture(oldTex, v_uv + offset),
        texture(newTex, v_uv),
        smoothstep(0.2, 1.0, progress)
    )) * qt_Opacity;
}
