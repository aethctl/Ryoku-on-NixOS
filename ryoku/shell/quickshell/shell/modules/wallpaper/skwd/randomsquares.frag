#version 440

// skwd transition: randomsquares. Ports skwd-daemon's RANDOMSQUARES_FRAG
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

const ivec2 size = ivec2(10, 10);
const float smoothness = 0.5;
 
float rand (vec2 co) {
  return fract(sin(dot(co.xy ,vec2(12.9898,78.233))) * 43758.5453);
}

vec4 transition(vec2 p) {
  float r = rand(floor(vec2(size) * p));
  float m = smoothstep(0.0, -smoothness, r - (progress * (1.0 + smoothness)));
  return mix(texture(oldTex, p), texture(newTex, p), m);
}
void main() {
    vec2 v_uv = qt_TexCoord0;
    fragColor = transition(v_uv) * qt_Opacity;
}
