shader_type canvas_item;
render_mode unshaded;

// Display-space transfer from PS-057's blue render, matching its browser review.
uniform vec4 player_color : source_color = vec4(0.118, 0.533, 0.898, 1.0);

void fragment() {
	vec4 source = texture(TEXTURE, UV);
	vec3 blue = vec3(30.0, 136.0, 229.0) / 255.0;
	float diffuse = clamp((source.b - source.r) * 255.0 / 199.0, 0.0, 1.4);
	COLOR = vec4(clamp(source.rgb + diffuse * (player_color.rgb - blue), vec3(0.0), vec3(1.0)), source.a);
}
