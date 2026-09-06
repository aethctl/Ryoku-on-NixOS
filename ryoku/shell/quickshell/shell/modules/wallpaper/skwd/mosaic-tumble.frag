#version 440

// skwd transition: ports MOSAIC_TUMBLE_FRAG from skwd-daemon
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

const float PI = 3.14159265358979323;
const int endx = 2;
const int endy = -1;
float Rand(vec2 v) { return fract(sin(dot(v.xy, vec2(12.9898, 78.233))) * 43758.5453); }
vec2 Rotate(vec2 v, float a) {
    mat2 rm = mat2(cos(a), -sin(a), sin(a), cos(a));
    return rm * v;
}
float CosInterpolation(float x) { return -cos(x * PI) / 2.0 + 0.5; }
void main() {
    vec2 v_uv = qt_TexCoord0;
    vec2 p = v_uv - 0.5;
    vec2 rp = p;
    float rpr = (progress * 2.0 - 1.0);
    float z = -(rpr * rpr * 2.0) + 3.0;
    float az = abs(z);
    rp *= az;
    rp += mix(vec2(0.5, 0.5), vec2(float(endx) + 0.5, float(endy) + 0.5),
              CosInterpolation(progress) * CosInterpolation(progress));
    vec2 mrp = mod(rp, 1.0);
    vec2 crp = rp;
    int cx = int(floor(crp.x));
    int cy = int(floor(crp.y));
    bool onEnd = cx == endx && cy == endy;
    bool onStart = cx == 0 && cy == 0;
    if (onEnd) {
        fragColor = texture(newTex, mrp) * qt_Opacity;
    } else if (onStart) {
        fragColor = texture(oldTex, mrp) * qt_Opacity;
    } else {
        float ang = float(int(Rand(floor(crp)) * 4.0)) * 0.5 * PI;
        vec2 rotated = vec2(0.5) + Rotate(mrp - vec2(0.5), ang);
        if (Rand(floor(crp)) > 0.5) {
            fragColor = texture(newTex, rotated) * qt_Opacity;
        } else {
            fragColor = texture(oldTex, rotated) * qt_Opacity;
        }
    }
}
