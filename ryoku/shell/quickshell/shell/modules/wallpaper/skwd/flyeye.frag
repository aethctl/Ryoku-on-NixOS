#version 440

// skwd transition: ports FLYEYE_FRAG from skwd-daemon
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

const float size_v = 0.04;
const float zoom_v = 50.0;
const float colorSeparation = 0.3;
void main() {
    vec2 v_uv = qt_TexCoord0;
    float inv = 1.0 - progress;
    vec2 disp = size_v * vec2(cos(zoom_v * v_uv.x), sin(zoom_v * v_uv.y));
    vec4 texTo = texture(newTex, v_uv + inv * disp);
    vec4 texFrom = vec4(
        texture(oldTex, v_uv + progress * disp * (1.0 - colorSeparation)).r,
        texture(oldTex, v_uv + progress * disp).g,
        texture(oldTex, v_uv + progress * disp * (1.0 + colorSeparation)).b,
        1.0
    );
    fragColor = (texTo * progress + texFrom * inv) * qt_Opacity;
}
