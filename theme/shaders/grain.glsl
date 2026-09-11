#version 300 es
precision highp float;
in vec2 v_texcoord;
uniform sampler2D tex;
out vec4 fragColor;

const float amount = 0.055;

float hash(vec2 p) {
    vec3 q = fract(vec3(p.xyx) * 0.1031);
    q += dot(q, q.yzx + 33.33);
    return fract((q.x + q.y) * q.z);
}

void main() {
    vec2 res = vec2(textureSize(tex, 0));
    vec3 src = texture(tex, clamp(v_texcoord, 0.0, 1.0)).rgb;
    float n = (hash(v_texcoord * res) - 0.5) * amount;
    fragColor = vec4(clamp(src + n * (0.25 + src), 0.0, 1.0), 1.0);
}
