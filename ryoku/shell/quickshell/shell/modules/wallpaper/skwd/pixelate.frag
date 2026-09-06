#version 440

// skwd transition: blocks grid swells to the coarsest mosaic at mid-switch and
// resolves into the new image. Ported verbatim from skwd-daemon's PIXELATE_FRAG
// (crates/paper/src/transition_paper.rs); only the uniform plumbing is Qt's.

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
    float bump = 1.0 - abs(progress - 0.5) * 2.0;
    float blocks = mix(800.0, 12.0, bump);
    vec2 q = floor(v_uv * blocks) / blocks + 0.5 / blocks;
    vec4 a = texture(oldTex, q);
    vec4 b = texture(newTex, q);
    fragColor = mix(a, b, smoothstep(0.0, 1.0, progress)) * qt_Opacity;
}
