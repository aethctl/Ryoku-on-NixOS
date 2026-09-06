#version 440

// skwd transition: fadecolor. Ports skwd-daemon's FADECOLOR_FRAG
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

const vec3 color = vec3(0.0);
const float colorPhase = 0.4; // if 0.0, there is no black phase, if 0.9, the black phase is very important
vec4 transition (vec2 uv) {
  return mix(
    mix(vec4(color, 1.0), texture(oldTex, uv), smoothstep(1.0-colorPhase, 0.0, progress)),
    mix(vec4(color, 1.0), texture(newTex, uv), smoothstep(    colorPhase, 1.0, progress)),
    progress);
}
void main() {
    vec2 v_uv = qt_TexCoord0;
    fragColor = transition(v_uv) * qt_Opacity;
}
