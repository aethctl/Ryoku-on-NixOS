#version 440

// skwd transition: morph. Ports skwd-daemon's MORPH_FRAG
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

const float strength_v = 0.15;
void main() {
    vec2 v_uv = qt_TexCoord0;
    vec4 ca = texture(oldTex, v_uv);
    vec4 cb = texture(newTex, v_uv);
    vec2 oa = (((ca.rg + ca.b) * 0.5) * 2.0 - 1.0);
    vec2 ob = (((cb.rg + cb.b) * 0.5) * 2.0 - 1.0);
    vec2 oc = mix(oa, ob, 0.5) * strength_v;
    float w0 = progress;
    float w1 = 1.0 - w0;
    fragColor = mix(texture(oldTex, v_uv + oc * w0), texture(newTex, v_uv - oc * w1), progress) * qt_Opacity;
}
