shader_type spatial;
render_mode blend_mix, depth_draw_never, cull_back, unshaded;

float hash21(vec2 p) {
    p = fract(p * vec2(117.13, 391.71));
    p += dot(p, p + 31.47);
    return fract(p.x * p.y);
}

float value_noise(vec2 p) {
    vec2 i = floor(p);
    vec2 f = fract(p);
    f = f * f * (3.0 - 2.0 * f);
    float a = hash21(i);
    float b = hash21(i + vec2(1.0, 0.0));
    float c = hash21(i + vec2(0.0, 1.0));
    float d = hash21(i + vec2(1.0, 1.0));
    return mix(mix(a, b, f.x), mix(c, d, f.x), f.y);
}

float fbm(vec2 p) {
    float v = 0.0;
    float a = 0.55;
    for (int i = 0; i < 3; i++) {
        v += value_noise(p) * a;
        p = p * 2.08 + vec2(5.2, 8.7);
        a *= 0.48;
    }
    return v;
}

void fragment() {
    vec2 p = UV * vec2(9.0, 4.0);
    p.x += TIME * 0.012;
    float bands = sin((UV.y - 0.5) * 35.0 + fbm(p * 0.55) * 4.0) * 0.08;
    float cloud = fbm(p + vec2(bands, 0.0));
    float alpha = smoothstep(0.60, 0.78, cloud) * 0.48;
    ALBEDO = vec3(0.72, 0.84, 0.88);
    ALPHA = alpha;
}
