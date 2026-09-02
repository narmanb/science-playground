shader_type spatial;
render_mode unshaded, cull_disabled;

uniform vec3 inner_color = vec3(0.24, 0.20, 0.17);
uniform vec3 outer_color = vec3(0.55, 0.48, 0.39);
uniform float inner_radius = 0.54;
uniform float opacity = 0.62;

float hash11(float p) {
    p = fract(p * 0.1031);
    p *= p + 33.33;
    p *= p + p;
    return fract(p);
}

void fragment() {
    vec2 p = (UV - vec2(0.5)) * 2.0;
    float radius = length(p);
    if (radius < inner_radius || radius > 1.0) {
        discard;
    }

    float normalized = (radius - inner_radius) / max(1.0 - inner_radius, 0.001);
    float bands = sin(radius * 132.0) * 0.5 + 0.5;
    float fine = sin(radius * 311.0 + hash11(floor(radius * 80.0)) * 3.0) * 0.5 + 0.5;
    float gaps = smoothstep(0.20, 0.58, bands * 0.72 + fine * 0.28);
    float edge_fade = smoothstep(0.0, 0.055, normalized) * (1.0 - smoothstep(0.90, 1.0, normalized));
    float azimuth = atan(p.y, p.x);
    float uneven = 0.82 + 0.18 * sin(azimuth * 7.0 + radius * 19.0);

    ALBEDO = mix(inner_color, outer_color, normalized * 0.72 + fine * 0.12);
    ALPHA = opacity * gaps * edge_fade * uneven;
}
