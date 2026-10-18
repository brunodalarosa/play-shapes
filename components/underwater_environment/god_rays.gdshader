shader_type spatial;
render_mode blend_add, unshaded, cull_disabled, shadows_disabled, fog_disabled, depth_draw_never;
// Soft light shafts fanning down from above the top centre of the screen, slowly drifting. Drawn
// additively on a card behind the gameplay plane, since the renderer has no volumetric light.

uniform vec4 ray_colour : source_color = vec4(0.82, 0.96, 1.0, 1.0);
uniform float strength : hint_range(0.0, 1.0) = 0.22;
uniform float speed : hint_range(0.0, 2.0) = 0.25;
// How far down the screen the shafts reach, as a share of its height.
uniform float reach : hint_range(0.1, 1.5) = 0.85;


void fragment() {
	// Compatibility may flip the projection when drawing into a texture; only its scale matters.
	vec2 scale = abs(vec2(PROJECTION_MATRIX[0][0], PROJECTION_MATRIX[1][1]));
	vec2 ndc = VERTEX.xy / -VERTEX.z * scale;
	vec2 from_source = ndc - vec2(0.0, 1.35);
	float angle = atan(from_source.x, -from_source.y);
	float t = TIME * speed;
	float shafts = 0.0;
	shafts += pow(0.5 + 0.5 * cos(angle * 23.0 + t * 1.1), 6.0);
	shafts += 0.7 * pow(0.5 + 0.5 * cos(angle * 37.0 - t * 0.7 + 1.3), 8.0);
	shafts += 0.5 * pow(0.5 + 0.5 * cos(angle * 13.0 + t * 0.4 + 2.1), 4.0);
	float fan = smoothstep(0.75, 0.15, abs(angle));
	float depth = 1.0 - clamp(length(from_source) / (reach * 2.0 + 0.35), 0.0, 1.0);
	float light = shafts * fan * depth * depth * strength;
	ALBEDO = ray_colour.rgb * light;
}
