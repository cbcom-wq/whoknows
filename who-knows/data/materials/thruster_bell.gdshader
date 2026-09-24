shader_type spatial;
render_mode cull_back, diffuse_burley, specular_schlick_ggx;

// The main thruster's emissive surface (thruster.tres surface 1: the bell,
// and the small dome forward). It glows as hard as that one engine fires.
//
// ExteriorBuilder draws every thruster on a ship from one MultiMesh, so they
// all share this material and the throttle can't be a uniform: engines that
// face different ways fire differently. It arrives per instance instead.
// ExteriorBuilder.show_thrust() writes each engine's eased throttle into its
// MultiMesh custom data, read here as INSTANCE_CUSTOM.r: 0 is lit but idle,
// 1 is full throttle, and boost runs on past 1.
//
// Glow grows with the square of the throttle. Emission is linear light, and
// the display's gamma squeezes the bright end, so a glow merely proportional
// to throttle looks nearly the same at half and full. Squaring roughly undoes
// that: the brightness you see follows thrust. Full throttle sits at
// full_energy, where the bell is exactly bell_colour; boost (2.5, so about six
// times the glow) saturates it to white. There is no bloom outside, so white
// is as bright as it gets. No special case for boost is needed.
uniform vec4 bell_colour : source_color = vec4(0.49803922, 0.83137256, 1.0, 1.0); // #7FD4FF, art direction §5.1
uniform float cold_albedo : hint_range(0.0, 1.0) = 0.2;   // share of bell_colour the metal shows in sunlight
uniform float idle_energy = 0.15;   // lit but not firing
uniform float full_energy = 1.0;    // full throttle
uniform float flicker : hint_range(0.0, 0.5) = 0.06;   // wobble at full throttle, as a fraction of the glow

varying flat float v_energy;

void vertex() {
	float throttle = max(INSTANCE_CUSTOM.r, 0.0);
	// Two detuned sines make an irregular wobble. Each engine's own phase
	// keeps a bank of them from pulsing in step.
	float phase = float(INSTANCE_ID) * 2.39996;
	float wobble = sin(TIME * 41.0 + phase) * sin(TIME * 23.0 + phase * 1.618);
	float glow = mix(idle_energy, full_energy, throttle * throttle);
	v_energy = glow * (1.0 + flicker * min(throttle, 1.0) * wobble);
}

void fragment() {
	ALBEDO = bell_colour.rgb * cold_albedo;
	EMISSION = bell_colour.rgb * v_energy;
}
