shader_type spatial;
render_mode cull_back, diffuse_burley, specular_schlick_ggx;

float hash21(vec2 p) {
    p = fract(p * vec2(123.34, 345.45));
    p += dot(p, p + 34.345);
    return fract(p.x * p.y);
}

float noise2(vec2 p) {
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
    float a = 0.54;
    for (int i = 0; i < 4; i++) {
        v += noise2(p) * a;
        p = p * 2.02 + vec2(5.1, 1.7);
        a *= 0.48;
    }
    return v;
}

void fragment() {
    float latitude = (UV.y - 0.5) * 2.0;
    float warp = fbm(vec2(UV.x * 8.0, UV.y * 3.0));
    float bands = sin((latitude + (warp - 0.5) * 0.11) * 24.0);
    float fine = sin((latitude - warp * 0.05) * 53.0);
    float storm = fbm(vec2(UV.x * 10.0 + warp, UV.y * 5.5));

    float band_mix = bands * 0.25 + fine * 0.07 + 0.52;
    vec3 deep = vec3(0.13, 0.27, 0.36);
    vec3 mid = vec3(0.25, 0.49, 0.59);
    vec3 pale = vec3(0.45, 0.67, 0.71);
    vec3 color = mix(deep, mid, smoothstep(0.22, 0.78, band_mix));
    color = mix(color, pale, smoothstep(0.76, 0.95, storm) * 0.30);

    float polar = smoothstep(0.68, 1.0, abs(latitude));
    color = mix(color, vec3(0.35, 0.57, 0.66), polar * 0.32);

    ALBEDO = color;
    EMISSION = color * 0.038;
    ROUGHNESS = 0.86;
    METALLIC = 0.0;
}
