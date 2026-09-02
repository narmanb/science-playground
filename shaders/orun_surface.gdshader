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
    float bands = sin((latitude + (warp - 0.5) * 0.13) * 27.0);
    float fine = sin((latitude - warp * 0.06) * 61.0);
    float storm = fbm(vec2(UV.x * 11.0 + warp, UV.y * 6.0));

    float band_mix = bands * 0.5 + fine * 0.18 + 0.5;
    vec3 deep = vec3(0.075, 0.16, 0.25);
    vec3 mid = vec3(0.16, 0.37, 0.48);
    vec3 pale = vec3(0.34, 0.57, 0.63);
    vec3 color = mix(deep, mid, smoothstep(0.18, 0.76, band_mix));
    color = mix(color, pale, smoothstep(0.73, 0.94, storm) * 0.42);

    float polar = smoothstep(0.68, 1.0, abs(latitude));
    color = mix(color, vec3(0.25, 0.47, 0.58), polar * 0.35);

    ALBEDO = color;
    ROUGHNESS = 0.79;
    METALLIC = 0.0;
}
