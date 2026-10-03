shader_type spatial;
render_mode cull_disabled;

// Liquid inside a bottle. Fragments above the surface plane are discarded, so the
// surface stays level in world space when the bottle tilts, and it tilts further
// when Bottle3D's wobble spring moves `surface_normal`. Inside faces seen through
// the cut are shaded as the flat top of the liquid.

uniform vec3 surface_point;
uniform vec3 surface_normal = vec3(0.0, 1.0, 0.0);
uniform vec4 band_colors[6] : source_color;
uniform float band_tops[6];
uniform int band_count = 0;

varying vec3 world_pos;
varying vec3 world_normal;
varying float local_y;

void vertex() {
	local_y = VERTEX.y;
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	world_normal = normalize(mat3(MODEL_MATRIX) * NORMAL);
}

void fragment() {
	float depth_below = dot(surface_point - world_pos, surface_normal);
	if (band_count == 0 || depth_below < 0.0) {
		discard;
	}
	int top = band_count - 1;
	vec3 color = band_colors[top].rgb;
	for (int i = 0; i < 6; i++) {
		if (i < band_count && local_y <= band_tops[i]) {
			color = band_colors[i].rgb;
			break;
		}
	}
	if (dot(world_normal, CAMERA_POSITION_WORLD - world_pos) >= 0.0) {
		// Outer wall: the colored bands, with a light line where they meet the surface.
		ALBEDO = mix(color, vec3(1.0), smoothstep(0.035, 0.0, depth_below) * 0.4);
		ROUGHNESS = 0.3;
	} else {
		// Inner wall seen through the cut: draw it as the flat liquid surface.
		ALBEDO = mix(band_colors[top].rgb, vec3(1.0), 0.15);
		NORMAL = normalize((VIEW_MATRIX * vec4(surface_normal, 0.0)).xyz);
		ROUGHNESS = 0.15;
	}
}
