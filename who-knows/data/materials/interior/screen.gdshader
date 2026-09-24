shader_type spatial;
render_mode unshaded, shadows_disabled;

// Chunky animated readouts: big shapes, few of them, slow changes. Nothing
// here reads ship state -- it is set dressing that moves. Vertex colour red
// picks the mode (0, 0.25, 0.5 = bars, wave, dots, InteriorKit.Screen);
// green is a per-screen seed so no two screens match.
uniform vec3 back_color : source_color = vec3(0.102, 0.11, 0.137);
uniform vec3 color_a : source_color = vec3(1.0, 0.706, 0.353);
uniform vec3 color_b : source_color = vec3(0.725, 0.651, 0.878);
uniform vec3 color_c : source_color = vec3(0.549, 0.784, 0.941);
uniform vec3 color_d : source_color = vec3(0.941, 0.486, 0.353);
uniform float energy = 1.2;

float screen_hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

vec3 pick(float h) {
	if (h < 0.4) {
		return color_a;
	}
	if (h < 0.65) {
		return color_b;
	}
	if (h < 0.88) {
		return color_c;
	}
	return color_d;
}

void fragment() {
	int mode = int(floor(COLOR.r * 4.0 + 0.5));
	float seed = COLOR.g * 97.0;
	vec2 uv = UV;
	vec3 lit = vec3(0.0);
	if (mode == 0) {
		// Three rows of bars whose lengths step every few seconds.
		float r = floor(uv.y * 3.0);
		float fy = fract(uv.y * 3.0);
		float epoch = floor(TIME * 0.3 + screen_hash(vec2(r, seed)) * 3.0);
		float len = 0.25 + 0.65 * screen_hash(vec2(r + epoch, seed));
		float bar = step(0.08, uv.x) * step(uv.x, 0.08 + len * 0.84) * step(abs((fy - 0.5) * 0.333), 0.07);
		lit = pick(screen_hash(vec2(r, seed))) * bar;
	} else if (mode == 1) {
		float y = 0.5 + 0.28 * sin(uv.x * 9.0 + TIME * 1.6 + seed);
		lit = color_c * (1.0 - smoothstep(0.03, 0.06, abs(uv.y - y)));
	} else {
		vec2 grid = vec2(5.0, 2.0);
		vec2 cell = floor(uv * grid);
		float h = screen_hash(cell + seed);
		float dot_ = 1.0 - smoothstep(0.22, 0.28, length(fract(uv * grid) - 0.5));
		float on = step(0.5, fract(TIME * (0.15 + h * 0.6) + h));
		lit = pick(h) * dot_ * mix(0.25, 1.0, on);
	}
	ALBEDO = back_color + lit * energy;
}
