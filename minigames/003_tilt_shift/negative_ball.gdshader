shader_type canvas_item;

uniform vec4 ball_color : source_color;

void fragment() {
	vec4 source = texture(TEXTURE, UV);
	// The shared texture's dark rim becomes white; its light paper shading keeps the blue tint.
	float brightness = max(source.r, max(source.g, source.b));
	float rim = 1.0 - smoothstep(0.18, 0.30, brightness);
	vec3 fill = source.rgb * ball_color.rgb;
	COLOR = vec4(mix(fill, vec3(1.0), rim), source.a);
}
