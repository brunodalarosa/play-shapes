shader_type canvas_item;
render_mode unshaded;

uniform vec4 player_color : source_color = vec4(0.35, 0.55, 0.95, 1.0);
varying vec4 canvas_tint;

void vertex() {
	canvas_tint = COLOR;
}

void fragment() {
	vec4 source = texture(TEXTURE, UV);
	// The canonical BLUE art contains only colored fill/highlights/shadows.
	// Re-map its lightness rather than multiplying blue into every player color.
	// Faces use a separate, unshaded sprite and never receive this material.
	float lightness = dot(source.rgb, vec3(0.2126, 0.7152, 0.0722));
	float shade = clamp((lightness - 0.53) / 0.20, 0.0, 1.0);
	// Lift very dark requests toward slate so Kenney's dark mouth stays visible.
	// This is a display palette, not exact color reproduction (especially at black).
	float value = max(player_color.r, max(player_color.g, player_color.b));
	float lift = clamp((0.40 - value) / 0.40, 0.0, 1.0);
	vec3 base = mix(player_color.rgb, vec3(0.55), lift);
	vec3 shadow = base * 0.78;
	vec3 highlight = mix(base, vec3(1.0), 0.38);
	COLOR = vec4(mix(shadow, highlight, shade), source.a * player_color.a) * canvas_tint;
}
