#version 440

// skwd transition: ports IRIS_FRAG from skwd-daemon
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
    vec2 c = v_uv - vec2(0.5);
    c.x *= 1.7777;
    float d = length(c);
    float r = progress * 1.2;
    float feather = 0.05;
    float t = smoothstep(r + feather, r - feather, d);
    float edge = exp(-abs(d - r) * 100.0);
    vec3 chrom = vec3(
        texture(newTex, v_uv + vec2(0.012, 0.0) * edge).r,
        texture(newTex, v_uv).g,
        texture(newTex, v_uv - vec2(0.012, 0.0) * edge).b
    );
    vec4 a = texture(oldTex, v_uv);
    fragColor = (mix(a, vec4(chrom, 1.0), t)) * qt_Opacity;
}
