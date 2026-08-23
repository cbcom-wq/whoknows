shader_type spatial;
render_mode cull_back, diffuse_burley, specular_schlick_ggx;

// Paints a livery stripe from a block's position on the ship, not from its
// own mesh-local UVs. `hull` and `hull_wedge` share ONE MultiMesh material
// each, so there is nowhere to store a per-instance "is this the stripe
// row" flag -- the height test has to happen in the shader instead.
//
// MODEL_MATRIX carries the full model-to-*world* transform, and for a
// MultiMesh that already includes the per-instance transform (each block's
// cell position within the ship) -- but it ALSO includes the hull
// RigidBody3D's own world rotation. Taking `(MODEL_MATRIX * vec4(VERTEX,1)).y`
// alone (the original Slice 1 art-direction spec §6 formula) therefore only
// gives ship-local height while the hull sits at identity/near-identity
// world rotation, e.g. a parked ship. Under any sustained roll or pitch --
// routine in this game's 6DOF flight -- that same formula reads *world*
// height instead, and the stripe visibly swims across the hull as it turns.
//
// Fix: `hull_inverse` is the hull's own inverse global transform, pushed
// every frame from `Ship._process()` (see ship.gd). Premultiplying by it
// cancels the hull's world rotation/translation before the height test, so
// `(hull_inverse * MODEL_MATRIX * vec4(VERTEX,1)).y` is genuinely ship-local
// height regardless of how the hull is oriented in the world.
uniform vec4 hull_colour : source_color = vec4(0.8392157, 0.8235294, 0.7686275, 1.0);   // #D6D2C4
uniform vec4 livery_colour : source_color = vec4(0.7098039, 0.2039216, 0.1647059, 1.0); // #B5342A
uniform float band_center_m = 1.0;   // ship-local metre height of the stripe's middle
uniform float band_half_width_m = 0.35;
uniform float roughness_value : hint_range(0.0, 1.0) = 0.55;
uniform mat4 hull_inverse;   // hull's inverse global transform; pushed per-frame by Ship

varying float v_ship_height;

void vertex() {
	v_ship_height = (hull_inverse * MODEL_MATRIX * vec4(VERTEX, 1.0)).y;
}

void fragment() {
	float dist = abs(v_ship_height - band_center_m);
	// Soft 5cm feather so the stripe edge isn't a hard aliased line.
	// Ascending edges (unlike the reverse order) keep this within spec --
	// GLSL leaves smoothstep(edge0 >= edge1, ...) undefined.
	float out_of_band = smoothstep(band_half_width_m - 0.05, band_half_width_m, dist);
	ALBEDO = mix(livery_colour.rgb, hull_colour.rgb, out_of_band);
	ROUGHNESS = roughness_value;
	METALLIC = 0.0;
}
