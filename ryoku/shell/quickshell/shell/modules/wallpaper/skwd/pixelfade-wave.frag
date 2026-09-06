#version 440

// skwd transition: ports PIXELFADE_WAVE_FRAG from skwd-daemon
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

void main() {
    vec2 v_uv = qt_TexCoord0;
    float p = progress;
    float wave_x = (v_uv.x + v_uv.y) * 0.5;
    float wave_p = smoothstep(0.0, 1.0, p * 1.6 - wave_x * 0.6);
    float bump = sin(wave_p * 3.14159);
    float blocks = mix(800.0, 8.0, bump);
    vec2 q = floor(v_uv * blocks) / blocks + 0.5 / blocks;
    vec4 a = texture(oldTex, q);
    vec4 b = texture(newTex, q);
    fragColor = (mix(a, b, smoothstep(0.0, 1.0, wave_p))) * qt_Opacity;
}
