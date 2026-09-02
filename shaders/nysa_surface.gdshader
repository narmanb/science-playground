shader_type spatial;
render_mode cull_back, diffuse_burley, specular_schlick_ggx;

float hash21(vec2 p) {
    p = fract(p * vec2(123.34, 456.21));
    p += dot(p, p + 45.32);
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
    float a = 0.52;
    for (int i = 0; i < 4; i++) {
        v += value_noise(p) * a;
        p = p * 2.03 + vec2(7.1, 3.7);
        a *= 0.5;
    }
    return v;
}

void fragment() {
    vec2 sphere_uv = UV;
    vec2 p = sphere_uv * vec2(7.0, 3.5);
    float broad = fbm(p + vec2(sin(sphere_uv.y * 15.0) * 0.24, 0.0));
    float detail = fbm(p * 2.2 + vec2(4.8, 1.6));
    float latitude = abs(sphere_uv.y - 0.5) * 2.0;

    float island_mask = smoothstep(0.64, 0.80, broad * 0.78 + detail * 0.34);
    island_mask *= 1.0 - smoothstep(0.68, 0.96, latitude);

    float shelf = smoothstep(0.42, 0.73, broad);
    vec3 deep_ocean = vec3(0.015, 0.075, 0.115);
    vec3 shelf_ocean = vec3(0.035, 0.23, 0.30);
    vec3 island = vec3(0.20, 0.31, 0.24);
    vec3 highland = vec3(0.36, 0.41, 0.31);

    vec3 ocean = mix(deep_ocean, shelf_ocean, shelf);
    vec3 land = mix(island, highland, smoothstep(0.72, 0.92, detail));
    vec3 color = mix(ocean, land, island_mask);

    float polar_haze = smoothstep(0.78, 1.0, latitude);
    color = mix(color, vec3(0.30, 0.43, 0.48), polar_haze * 0.32);

    ALBEDO = color;
    ROUGHNESS = mix(0.30, 0.78, island_mask);
    METALLIC = 0.02;
}
