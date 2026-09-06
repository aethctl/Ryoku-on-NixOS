#version 440

// skwd transition: circle-crop. Ports skwd-daemon's CIRCLE_CROP_FRAG
// (crates/paper/src/transition_paper.rs); math verbatim. Qt plumbing plus moving the
// progress-dependent `s` out of global scope (non-const global init is illegal in 440).

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

const float ratio = 1.7777;
const vec4 bgcolor = vec4(0.0, 0.0, 0.0, 1.0);

vec2 ratio2 = vec2(1.0, 1.0 / ratio);

vec4 transition(vec2 p) {
  float s = pow(2.0 * abs(progress - 0.5), 3.0);
  float dist = length((vec2(p) - 0.5) * ratio2);
  return mix(
    progress < 0.5 ? texture(oldTex, p) : texture(newTex, p), // branching is ok here as we statically depend on u_progress uniform (branching won't change over pixels)
    bgcolor,
    step(s, dist)
  );
}
void main() {
    vec2 v_uv = qt_TexCoord0;
    fragColor = transition(v_uv) * qt_Opacity;
}
