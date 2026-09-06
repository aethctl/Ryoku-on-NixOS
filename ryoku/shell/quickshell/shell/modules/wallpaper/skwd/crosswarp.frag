#version 440

// skwd transition: crosswarp. Ports skwd-daemon's CROSSWARP_FRAG
// (crates/paper/src/transition_paper.rs); math verbatim, only Qt plumbing changed.

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
    float x = progress;
    x = smoothstep(0.0, 1.0, (x * 2.0 + v_uv.x - 1.0));
    fragColor = mix(
        texture(oldTex, (v_uv - 0.5) * (1.0 - x) + 0.5),
        texture(newTex, (v_uv - 0.5) * x + 0.5),
        x
    ) * qt_Opacity;
}
