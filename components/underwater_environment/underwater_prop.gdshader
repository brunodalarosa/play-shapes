shader_type spatial;
render_mode cull_back;
// Scenery recoloured for the underwater scene: one flat tint, an optional sway that bends the
// model more the higher a vertex sits (kelp), and caustic shimmer from above.

uniform vec4 tint : source_color = vec4(0.36, 0.5, 0.64, 1.0);
// Sideways sway at the top of the model, in model units. Zero keeps it still.
uniform float sway : hint_range(0.0, 1.0) = 0.0;
// Model height the sway reaches its full amount at.
uniform float sway_height = 1.0;
uniform float sway_speed : hint_range(0.0, 4.0) = 1.1;
uniform float caustic_strength : hint_range(0.0, 1.0) = 0.25;
uniform float caustic_scale = 1.6;
uniform float caustic_speed : hint_range(0.0, 3.0) = 0.7;

varying vec3 world_position;


void vertex() {
	if (sway > 0.0) {
		float bend = clamp(VERTEX.y / sway_height, 0.0, 1.0);
		float phase = TIME * sway_speed + NODE_POSITION_WORLD.x * 0.7 + NODE_POSITION_WORLD.z;
		VERTEX.x += sin(phase) * sway * bend * bend;
		VERTEX.z += cos(phase * 0.8) * sway * 0.4 * bend * bend;
	}
	world_position = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}


float caustics(vec2 p, float t) {
	float a = sin(p.x * 3.1 + t) + sin(p.y * 2.7 - t * 1.2);
	float b = sin((p.x + p.y) * 2.3 + t * 0.6) + sin((p.x - p.y) * 3.7 - t * 0.9);
	return pow(clamp(0.5 + 0.17 * (a + b), 0.0, 1.0), 3.0);
}


void fragment() {
	vec2 p = world_position.xz * caustic_scale + world_position.y * 0.3;
	float shimmer = caustics(p, TIME * caustic_speed) * caustic_strength;
	ALBEDO = tint.rgb;
	EMISSION = vec3(0.75, 0.95, 1.0) * shimmer * max(NORMAL.y * 0.5 + 0.5, 0.0);
	ROUGHNESS = 0.9;
	SPECULAR = 0.15;
}
