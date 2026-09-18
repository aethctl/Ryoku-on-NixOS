#version 440

// skwd transition: overexposure. Ports skwd-daemon's OVEREXPOSURE_FRAG
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

const float strength = 0.6;
const float PI = 3.141592653589793;

vec4 transition (vec2 uv) {
  vec4 from = texture(oldTex, uv);
  vec4 to = texture(newTex, uv);

  // Multipliers
  float from_m = 1.0 - progress + sin(PI * progress) * strength;
  float to_m = progress + sin(PI * progress) * strength;
  
  return vec4(
    from.r * from.a * from_m + to.r * to.a * to_m,
    from.g * from.a * from_m + to.g * to.a * to_m,
    from.b * from.a * from_m + to.b * to.a * to_m,
    mix(from.a, to.a, progress)
  );
}
void main() {
    vec2 v_uv = qt_TexCoord0;
    fragColor = transition(v_uv) * qt_Opacity;
}
