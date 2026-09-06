#version 440

// skwd transition: crazy-parametric. Ports skwd-daemon's CRAZY_PARAMETRIC_FRAG
// (crates/paper/src/transition_paper.rs); math verbatim. Qt plumbing plus int const
// literals (a/b/amplitude) given .0 to satisfy 440's no-implicit-int-to-float rule.

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

const float a = 4.0;
const float b = 1.0;
const float amplitude = 120.0;
const float smoothness = 0.1;

vec4 transition(vec2 uv) {
  vec2 p = uv.xy / vec2(1.0).xy;
  vec2 dir = p - vec2(.5);
  float dist = length(dir);
  float x = (a - b) * cos(progress) + b * cos(progress * ((a / b) - 1.) );
  float y = (a - b) * sin(progress) - b * sin(progress * ((a / b) - 1.));
  vec2 offset = dir * vec2(sin(progress  * dist * amplitude * x), sin(progress * dist * amplitude * y)) / smoothness;
  return mix(texture(oldTex, p + offset), texture(newTex, p), smoothstep(0.2, 1.0, progress));
}
void main() {
    vec2 v_uv = qt_TexCoord0;
    fragColor = transition(v_uv) * qt_Opacity;
}
