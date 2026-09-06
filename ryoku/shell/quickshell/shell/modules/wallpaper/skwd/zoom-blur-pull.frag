#version 440

// skwd transition: ports ZOOM_BLUR_PULL_FRAG from skwd-daemon
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

const float PI = 3.14159265358979;
const float strength_v = 0.4;
float Linear_ease(float begin, float change, float duration, float time) {
    return change * time / duration + begin;
}
float Exponential_easeInOut(float begin, float change, float duration, float time) {
    if (time == 0.0) return begin;
    if (time == duration) return begin + change;
    time = time / (duration / 2.0);
    if (time < 1.0) return change / 2.0 * pow(2.0, 10.0 * (time - 1.0)) + begin;
    return change / 2.0 * (-pow(2.0, -10.0 * (time - 1.0)) + 2.0) + begin;
}
float Sinusoidal_easeInOut(float begin, float change, float duration, float time) {
    return -change / 2.0 * (cos(PI * time / duration) - 1.0) + begin;
}
float rand(vec2 co) {
    return fract(sin(dot(co.xy, vec2(12.9898, 78.233))) * 43758.5453);
}
vec4 crossFade(vec2 uv, float dissolve) {
    return mix(texture(oldTex, uv), texture(newTex, uv), dissolve);
}
void main() {
    vec2 v_uv = qt_TexCoord0;
    vec2 texCoord = v_uv;
    vec2 center = vec2(Linear_ease(0.25, 0.5, 1.0, progress), 0.5);
    float dissolve = Exponential_easeInOut(0.0, 1.0, 1.0, progress);
    float strength = Sinusoidal_easeInOut(0.0, strength_v, 0.5, progress);
    vec4 color = vec4(0.0);
    float total = 0.0;
    vec2 toCenter = center - texCoord;
    float offset = rand(v_uv);
    for (float t = 0.0; t <= 40.0; t++) {
        float percent = (t + offset) / 40.0;
        float weight = 4.0 * (percent - percent * percent);
        color += crossFade(texCoord + toCenter * percent * strength, dissolve) * weight;
        total += weight;
    }
    fragColor = (color / total) * qt_Opacity;
}
