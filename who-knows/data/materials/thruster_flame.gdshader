shader_type spatial;
render_mode blend_add, unshaded, cull_back, depth_draw_never, shadows_disabled, fog_disabled;

// The exhaust flame behind a thruster (ThrusterFlame builds the mesh).
//
// Every flame on a ship is one instance of one MultiMesh, so each one's size
// arrives per instance, in the custom data ExteriorBuilder.show_thrust() writes:
//   r: the engine's throttle (1 is full, boost goes past it)
//   g: flame length, as a fraction of the mesh's authored length
//   b: flame width, likewise
// The mesh is authored at the largest flame, so this only ever shrinks it and
// the flame stays inside the bounds that culling sees. At zero throttle it
// shrinks to a point and draws nothing.
//
// Additive and unshaded: the flame is light, not a surface, so it glows over
// space and brightens whatever is behind it, and the sun doesn't light it.
uniform vec4 plume_colour : source_color = vec4(0.49803922, 0.83137256, 1.0, 1.0); // #7FD4FF, the bell's colour
uniform vec4 core_colour : source_color = vec4(0.9019608, 0.98039216, 1.0, 1.0);   // #E6FAFF
uniform float energy = 1.4;
uniform float edge_softness = 1.0;   // higher fades the silhouette sooner
uniform float flicker : hint_range(0.0, 0.5) = 0.12;   // length lost at the bottom of a wobble

varying float v_brightness;
varying vec2 v_shell;   // x: 1 on the core, 0 on the plume; y: 0 at the nozzle, 1 at the tip

void vertex() {
	float throttle = max(INSTANCE_CUSTOM.r, 0.0);
	// Two detuned sines make an irregular wobble. Each engine's own phase
	// keeps a bank of them from pulsing in step.
	float phase = float(INSTANCE_ID) * 2.39996;
	float wobble = 0.5 + 0.5 * sin(TIME * 37.0 + phase) * sin(TIME * 19.0 + phase * 1.618);
	vec3 size = vec3(INSTANCE_CUSTOM.b, INSTANCE_CUSTOM.b, INSTANCE_CUSTOM.g * (1.0 - flicker * wobble));
	VERTEX *= size;
	// Stretching the shape unevenly tilts its surfaces; normals follow by the
	// inverse stretch.
	NORMAL = normalize(NORMAL / max(size, vec3(0.001)));
	v_brightness = energy * min(sqrt(throttle), 1.3);
	v_shell = UV;
}

void fragment() {
	// Faces seen edge-on fade out, so the silhouette is soft and the body
	// glows; the tip burns away to nothing.
	float facing = pow(abs(dot(normalize(NORMAL), normalize(VIEW))), edge_softness);
	float burn = 1.0 - v_shell.y * v_shell.y;
	ALBEDO = mix(plume_colour.rgb, core_colour.rgb, v_shell.x) * v_brightness;
	ALPHA = facing * burn;
}
