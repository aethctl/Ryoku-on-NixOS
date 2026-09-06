#version 440

// skwd transition: ports CHROMATIC_BLOOM_FRAG from skwd-daemon
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
    float intensity = sin(p * 3.14159);
    vec2 c = v_uv - vec2(0.5);
    vec2 dir = c * intensity * 0.15;
    vec3 oldc = vec3(
        texture(oldTex, v_uv + dir).r,
        texture(oldTex, v_uv).g,
        texture(oldTex, v_uv - dir).b
    );
    vec3 newc = vec3(
        texture(newTex, v_uv + dir).r,
        texture(newTex, v_uv).g,
        texture(newTex, v_uv - dir).b
    );
    vec3 mixed = mix(oldc, newc, smoothstep(0.4, 0.6, p));
    vec3 bloom = vec3(0.0);
    for (int i = 1; i <= 4; i++) {
        float r = float(i) * 0.01 * intensity;
        bloom += texture(newTex, v_uv + vec2(r, 0.0)).rgb;
        bloom += texture(newTex, v_uv - vec2(r, 0.0)).rgb;
        bloom += texture(newTex, v_uv + vec2(0.0, r)).rgb;
        bloom += texture(newTex, v_uv - vec2(0.0, r)).rgb;
    }
    bloom /= 16.0;
    mixed = mix(mixed, mixed + bloom * 0.5, intensity);
    fragColor = (vec4(mixed, 1.0)) * qt_Opacity;
}
