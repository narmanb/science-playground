shader_type spatial;
render_mode cull_back, diffuse_burley, specular_schlick_ggx;

float hash21(vec2 p) {
    p = fract(p * vec2(234.34, 435.34));
    p += dot(p, p + 45.32);
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
    float value = 0.0;
    float amplitude = 0.55;
    for (int i = 0; i < 4; i++) {
        value += noise2(p) * amplitude;
        p = p * 2.11 + vec2(2.4, 6.8);
        amplitude *= 0.47;
    }
    return value;
}

void fragment() {
    float latitude = (UV.y - 0.5) * 2.0;
    float turbulence = fbm(vec2(UV.x * 7.0, UV.y * 4.0));
    float broad_bands = sin((latitude + (turbulence - 0.5) * 0.09) * 16.0);
    float narrow_bands = sin((latitude + turbulence * 0.035) * 41.0);
    float mix_value = broad_bands * 0.34 + narrow_bands * 0.10 + 0.50;

    vec3 dark_methane = vec3(0.055, 0.19, 0.25);
    vec3 blue_green = vec3(0.11, 0.39, 0.46);
    vec3 cyan_haze = vec3(0.25, 0.59, 0.62);
    vec3 color = mix(dark_methane, blue_green, smoothstep(0.18, 0.78, mix_value));

    float polar = smoothstep(0.61, 0.94, abs(latitude));
    color = mix(color, cyan_haze, polar * 0.48);
    float storm_belt = smoothstep(0.78, 0.94, turbulence) * (1.0 - polar);
    color = mix(color, vec3(0.34, 0.66, 0.67), storm_belt * 0.28);

    ALBEDO = color;
    ROUGHNESS = 0.82;
    METALLIC = 0.0;
}
