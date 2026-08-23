shader_type spatial;
render_mode cull_back, diffuse_burley, specular_schlick_ggx;

// Paints a livery stripe from a block's position on the ship, not from its
// own mesh-local UVs. `hull` and `hull_wedge` share ONE MultiMesh material
// each, so there is nowhere to store a per-instance "is this the stripe
// row" flag -- the height test has to happen in the shader instead.
//
// MODEL_MATRIX carries the full model-to-world transform, and for a
// MultiMesh that already includes the per-instance transform (each block's
// cell position within the ship). So long as the ship itself sits at
// identity/near-identity world transform -- true for the parked starter
// ship and true for most of normal flight, which is translation and yaw
// rather than sustained roll/pitch -- (MODEL_MATRIX * vec4(VERTEX,1)).y
// tracks the block's height on the ship. Slice 1 art direction spec §6
// specifies this exact formula; a fully hull-local band would need the
// hull's inverse transform threaded in as a uniform, which is out of
// scope here.
uniform vec4 hull_colour : source_color = vec4(0.8392157, 0.8235294, 0.7686275, 1.0);   // #D6D2C4
uniform vec4 livery_colour : source_color = vec4(0.7098039, 0.2039216, 0.1647059, 1.0); // #B5342A
uniform float band_center_m = 1.0;   // world-metre height of the stripe's middle
uniform float band_half_width_m = 0.35;
uniform float roughness_value : hint_range(0.0, 1.0) = 0.55;

varying float v_ship_height;

void vertex() {
	v_ship_height = (MODEL_MATRIX * vec4(VERTEX, 1.0)).y;
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
