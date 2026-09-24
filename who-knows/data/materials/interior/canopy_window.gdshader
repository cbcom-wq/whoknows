shader_type spatial;
render_mode cull_disabled;

// The rounded cockpit nose: a flat-coloured shell with window openings cut
// by a rounded-rectangle mask in the shell's UV space (UV.x = arc length
// across the nose from its centre line, UV.y = height above the floor, both
// in metres; see InteriorProps.nose). Inside a window each fragment looks the
// canopy camera's view up by *direction from the pilot's eye*, so every
// window on the curve lines up into one continuous view and the velocity
// marker drawn into that view stays registered against it.

uniform vec3 shell_color : source_color = vec3(0.847, 0.78, 0.659);
uniform vec3 frame_color : source_color = vec3(0.929, 0.89, 0.816);
uniform sampler2D canopy_view : source_color, filter_linear, repeat_disable, hint_default_black;
uniform vec3 eye_world = vec3(0.0);
uniform float tan_half_fov_y = 0.36397;
uniform float aspect = 3.0;
uniform float view_energy = 1.0;

// (centre across, centre height, half width, half height), metres.
uniform vec4 window_0 = vec4(0.0, 1.325, 0.9, 0.375);
uniform vec4 window_1 = vec4(-1.95, 1.3, 0.5, 0.3);
uniform vec4 window_2 = vec4(1.95, 1.3, 0.5, 0.3);
uniform float window_corner = 0.14;
uniform float frame_width = 0.09;

varying vec3 world_pos;

float window_sd(vec2 p, vec4 w) {
	vec2 q = abs(p - w.xy) - w.zw + window_corner;
	return length(max(q, 0.0)) + min(max(q.x, q.y), 0.0) - window_corner;
}

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	float sd = min(window_sd(UV, window_0), min(window_sd(UV, window_1), window_sd(UV, window_2)));
	ROUGHNESS = 0.85;
	if (sd < 0.0) {
		// The canopy camera looks down -Z with the interior's own axes, so the
		// eye-to-fragment offset is already a view-space direction.
		vec3 d = world_pos - eye_world;
		vec3 view = vec3(0.0);
		if (d.z < -0.01) {
			vec2 ndc = vec2(d.x / (-d.z * tan_half_fov_y * aspect), d.y / (-d.z * tan_half_fov_y));
			vec2 uv = vec2(ndc.x * 0.5 + 0.5, 0.5 - ndc.y * 0.5);
			if (all(greaterThanEqual(uv, vec2(0.0))) && all(lessThanEqual(uv, vec2(1.0)))) {
				view = texture(canopy_view, uv).rgb;
			}
		}
		ALBEDO = vec3(0.0);
		SPECULAR = 0.0;
		EMISSION = view * view_energy;
	} else if (sd < frame_width) {
		ALBEDO = frame_color;
	} else {
		ALBEDO = shell_color;
	}
}
