shader_type spatial;
render_mode cull_back, diffuse_burley, specular_schlick_ggx;

float hash31(vec3 p) {
    p = fract(p * 0.1031);
    p += dot(p, p.yzx + 33.33);
    return fract((p.x + p.y) * p.z);
}

float noise3(vec3 p) {
    vec3 i = floor(p);
    vec3 f = fract(p);
    f = f * f * (3.0 - 2.0 * f);
    float n000 = hash31(i);
    float n100 = hash31(i + vec3(1.0, 0.0, 0.0));
    float n010 = hash31(i + vec3(0.0, 1.0, 0.0));
    float n110 = hash31(i + vec3(1.0, 1.0, 0.0));
    float n001 = hash31(i + vec3(0.0, 0.0, 1.0));
    float n101 = hash31(i + vec3(1.0, 0.0, 1.0));
    float n011 = hash31(i + vec3(0.0, 1.0, 1.0));
    float n111 = hash31(i + vec3(1.0));
    float x00 = mix(n000, n100, f.x);
    float x10 = mix(n010, n110, f.x);
    float x01 = mix(n001, n101, f.x);
    float x11 = mix(n011, n111, f.x);
    return mix(mix(x00, x10, f.y), mix(x01, x11, f.y), f.z);
}

float fbm(vec3 p) {
    float value = 0.0;
    float amplitude = 0.55;
    for (int i = 0; i < 4; i++) {
        value += noise3(p) * amplitude;
        p = p * 2.07 + vec3(3.1, 5.7, 2.4);
        amplitude *= 0.48;
    }
    return value;
}

void fragment() {
    vec3 p = normalize(VERTEX) * 5.2;
    float crust = fbm(p);
    float detail = fbm(p * 2.6 + vec3(4.0, 1.0, 7.0));
    float ridge = abs(fract((crust * 2.2 + detail) * 4.0) - 0.5) * 2.0;
    float fissure = 1.0 - smoothstep(0.03, 0.13, ridge);

    vec3 basalt = vec3(0.085, 0.055, 0.045);
    vec3 iron = vec3(0.34, 0.105, 0.045);
    vec3 dust = vec3(0.48, 0.20, 0.075);
    vec3 color = mix(basalt, iron, smoothstep(0.38, 0.74, crust));
    color = mix(color, dust, smoothstep(0.69, 0.90, detail) * 0.55);

    // Faint emissive fractures are visual evidence of active geology, not a
    // claim that the 439 K equilibrium-temperature surface is globally molten.
    vec3 hot = vec3(1.0, 0.18, 0.025);
    EMISSION = hot * fissure * smoothstep(0.66, 0.92, detail) * 0.45;
    ALBEDO = color;
    ROUGHNESS = mix(0.96, 0.76, fissure);
    METALLIC = 0.035;
}
