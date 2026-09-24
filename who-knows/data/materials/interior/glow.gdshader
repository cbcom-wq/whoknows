shader_type spatial;
render_mode unshaded, shadows_disabled;

// Every lit strip, lamp face and indicator in one material. The vertex colour
// is the piece's colour pre-scaled by its share of `energy` (InteriorKit.lit),
// so one merged mesh holds lights of different strengths; alpha below 1 marks
// a blinking light and doubles as its phase. Unshaded albedo above 1 lands in
// the HDR buffer, which is what the interior environment's glow blooms.
uniform float energy = 2.4;

void fragment() {
	float on = 1.0;
	if (COLOR.a < 0.99) {
		on = mix(0.12, 1.0, step(0.5, fract(TIME * (0.35 + COLOR.a) + COLOR.a * 7.0)));
	}
	ALBEDO = COLOR.rgb * energy * on;
}
