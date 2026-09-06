#version 440

// skwd transition: ports PLASMA_FLOW_FRAG from skwd-daemon
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

float hash(vec2 p) {
    return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}
float noise(vec2 p) {
    vec2 i = floor(p);
    vec2 f = fract(p);
    f = f * f * (3.0 - 2.0 * f);
    return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), f.x),
               mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), f.x), f.y);
}
void main() {
    vec2 v_uv = qt_TexCoord0;
    float p = progress;
    vec2 flow = vec2(
        noise(v_uv * 5.0 + vec2(p * 2.0, 0.0)),
        noise(v_uv * 5.0 + vec2(0.0, p * 2.0))
    ) - 0.5;
    float intensity = sin(p * 3.14159) * 0.18;
    vec2 distorted = v_uv + flow * intensity;
    vec4 a = texture(oldTex, distorted);
    vec4 b = texture(newTex, distorted);
    fragColor = (mix(a, b, smoothstep(0.2, 0.8, p))) * qt_Opacity;
}
