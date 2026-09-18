#version 440

// skwd transition: crosshatch. Ports skwd-daemon's CROSSHATCH_FRAG
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

const vec2 center = vec2(0.5);
const float threshold = 3.0;
const float fadeEdge = 0.1;

float rand(vec2 co) {
  return fract(sin(dot(co.xy ,vec2(12.9898,78.233))) * 43758.5453);
}
vec4 transition(vec2 p) {
  float dist = distance(center, p) / threshold;
  float r = progress - min(rand(vec2(p.y, 0.0)), rand(vec2(0.0, p.x)));
  return mix(texture(oldTex, p), texture(newTex, p), mix(0.0, mix(step(dist, r), 1.0, smoothstep(1.0-fadeEdge, 1.0, progress)), smoothstep(0.0, fadeEdge, progress)));    
}
void main() {
    vec2 v_uv = qt_TexCoord0;
    fragColor = transition(v_uv) * qt_Opacity;
}
