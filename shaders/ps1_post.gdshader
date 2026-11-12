shader_type canvas_item;
// PS1-style output pass for the low-resolution 3D viewport:
// ordered dithering to a reduced colour depth, film grain, vignette,
// plus gameplay-driven glitch (the Signal) and damage tint.

uniform float color_depth = 20.0;
uniform float dither_strength = 1.0;
uniform float grain = 0.07;
uniform float vignette = 0.6;
uniform float glitch = 0.0;
uniform float damage = 0.0;
uniform float fade = 1.0;
uniform vec2 resolution = vec2(427.0, 240.0);

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(12.9898, 78.233))) * 43758.5453);
}

float bayer2(vec2 a) {
	a = floor(a);
	return fract(a.x / 2.0 + a.y * a.y * 0.75);
}

float bayer4(vec2 a) {
	return bayer2(0.5 * a) * 0.25 + bayer2(a);
}

void fragment() {
	vec2 uv = UV;
	if (glitch > 0.0) {
		float row = floor(uv.y * 48.0);
		float n = hash(vec2(row, floor(TIME * 18.0)));
		if (n < glitch * 0.45) {
			uv.x += (hash(vec2(row, TIME)) - 0.5) * 0.14 * glitch;
		}
	}
	vec3 col = texture(TEXTURE, uv).rgb;
	if (glitch > 0.0) {
		col.r = texture(TEXTURE, uv + vec2(0.007 * glitch, 0.0)).r;
		col.b = texture(TEXTURE, uv - vec2(0.007 * glitch, 0.0)).b;
		col += (hash(uv * resolution + TIME) - 0.5) * glitch * 0.45;
	}
	vec2 px = floor(uv * resolution);
	col += (hash(px + floor(TIME * 24.0) * 7.31) - 0.5) * grain;
	float d = (bayer4(px) - 0.5) * dither_strength / color_depth;
	col = floor((col + d) * color_depth + 0.5) / color_depth;
	float v = distance(UV, vec2(0.5));
	col *= 1.0 - smoothstep(0.3, 0.85, v) * vignette;
	col = mix(col, vec3(0.45, 0.0, 0.0) + col * 0.4, damage * smoothstep(0.15, 0.75, v));
	COLOR = vec4(col * fade, 1.0);
}
