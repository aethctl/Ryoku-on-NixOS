#version 440

// skwd transition: ports VORONOI_SHATTER_FRAG from skwd-daemon
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

vec2 hash2(vec2 p) {
    return fract(sin(vec2(dot(p, vec2(127.1, 311.7)),
                          dot(p, vec2(269.5, 183.3)))) * 43758.5453);
}
void main() {
    vec2 v_uv = qt_TexCoord0;
    float scale = 14.0;
    vec2 p = v_uv * scale;
    vec2 g = floor(p);
    vec2 f = fract(p);
    float min_d = 100.0;
    vec2 cell = g;
    for (int y = -1; y <= 1; y++) {
        for (int x = -1; x <= 1; x++) {
            vec2 nb = vec2(float(x), float(y));
            vec2 q = nb + hash2(g + nb) - f;
            float d = dot(q, q);
            if (d < min_d) { min_d = d; cell = g + nb; }
        }
    }
    vec2 dir = normalize(hash2(cell) - 0.5 + vec2(0.0001));
    float shard_seed = hash2(cell).x;
    float shard_p = smoothstep(shard_seed * 0.5, shard_seed * 0.5 + 0.5, progress);
    vec2 displaced = v_uv - dir * shard_p * 1.5;
    vec4 a = texture(oldTex, displaced);
    vec4 b = texture(newTex, v_uv);
    fragColor = (mix(a, b, smoothstep(0.0, 0.5, shard_p))) * qt_Opacity;
}
