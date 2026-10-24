shader_type spatial;
render_mode unshaded, cull_disabled, shadows_disabled, fog_disabled, depth_draw_never;
// The water behind everything: a vertical gradient from bright cyan to deep blue with a rippling,
// brighter surface band across the top. Positions come from the screen, so the backdrop fills
// any aspect ratio the same way.

uniform vec4 top_colour : source_color = vec4(0.33, 0.82, 0.98, 1.0);
uniform vec4 bottom_colour : source_color = vec4(0.03, 0.27, 0.6, 1.0);
uniform vec4 surface_colour : source_color = vec4(0.86, 0.98, 1.0, 1.0);
// Share of the screen height the surface band covers from the top.
uniform float surface_height : hint_range(0.0, 0.5) = 0.16;
uniform float surface_strength : hint_range(0.0, 1.0) = 0.75;
uniform float ripple_speed : hint_range(0.0, 3.0) = 0.6;


float facets(vec2 p, float t) {
	float a = sin(p.x * 9.0 + t) + sin(p.x * 5.3 - p.y * 11.0 + t * 1.3);
	float b = sin((p.x + p.y) * 7.1 - t * 0.8) + sin(p.y * 13.0 + t * 0.6);
	return clamp(0.5 + 0.18 * (a + b), 0.0, 1.0);
}


void fragment() {
	// Compatibility may flip the projection when drawing into a texture; only its scale matters.
	vec2 scale = abs(vec2(PROJECTION_MATRIX[0][0], PROJECTION_MATRIX[1][1]));
	vec2 ndc = VERTEX.xy / -VERTEX.z * scale;
	float height = clamp(ndc.y * 0.5 + 0.5, 0.0, 1.0);
	vec3 colour = mix(bottom_colour.rgb, top_colour.rgb, pow(height, 1.35));
	float band = smoothstep(1.0 - surface_height, 1.0, height);
	vec2 surface_point = vec2(ndc.x * 1.7, (1.0 - height) * 9.0);
	float ripple = facets(surface_point, TIME * ripple_speed);
	float light = band * surface_strength * (0.35 + 0.65 * floor(ripple * 4.0) / 4.0);
	ALBEDO = mix(colour, surface_colour.rgb, clamp(light, 0.0, 1.0));
}
