shader_type spatial;
render_mode cull_disabled;

// Every window in the ship. CanopyPortal renders the outside from exactly
// where the viewing camera would be if the interior were inside the hull, so
// glass shows that view at its own screen position: any window, of any shape,
// lines up with the world outside from wherever the player stands or sits.
//
// all_glass makes the whole surface window -- pod panes, shoulder windows,
// portholes. Otherwise windows are cut from the surface by rounded rectangles
// in UV space: on the rounded nose UV.x is arc length across from the centre
// line and UV.y the height above the floor, both in metres (InteriorProps.nose).

uniform sampler2D canopy_view : source_color, filter_linear, repeat_disable, hint_default_black;
uniform bool all_glass = false;
uniform float view_energy = 1.0;
uniform vec3 shell_color : source_color = vec3(0.847, 0.78, 0.659);
uniform vec3 frame_color : source_color = vec3(0.929, 0.89, 0.816);

// (centre across, centre height, half width, half height), metres.
uniform vec4 window_0 = vec4(0.0, 1.325, 0.9, 0.375);
uniform vec4 window_1 = vec4(-1.95, 1.3, 0.5, 0.3);
uniform vec4 window_2 = vec4(1.95, 1.3, 0.5, 0.3);
uniform float window_corner = 0.14;
uniform float frame_width = 0.09;

float window_sd(vec2 p, vec4 w) {
	vec2 q = abs(p - w.xy) - w.zw + window_corner;
	return length(max(q, 0.0)) + min(max(q.x, q.y), 0.0) - window_corner;
}

void fragment() {
	float sd = all_glass ? -1.0
		: min(window_sd(UV, window_0), min(window_sd(UV, window_1), window_sd(UV, window_2)));
	ROUGHNESS = 0.85;
	if (sd < 0.0) {
		ALBEDO = vec3(0.0);
		SPECULAR = 0.0;
		EMISSION = texture(canopy_view, SCREEN_UV).rgb * view_energy;
	} else if (sd < frame_width) {
		ALBEDO = frame_color;
	} else {
		ALBEDO = shell_color;
	}
}
