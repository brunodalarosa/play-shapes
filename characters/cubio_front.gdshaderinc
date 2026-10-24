// Draws a character in front of scenery near its action plane without moving it on screen.
// Only the depth changes: it is the depth of the same point moved toward the camera along its
// view ray. Keeping the clip-space W unchanged keeps textures and lighting interpolated with
// the true perspective, so a face drawn on the character does not warp across its triangles.

// World units of scenery the character draws in front of.
uniform float front_push = 2.0;

vec4 pushed_position(vec3 view_position, mat4 projection) {
	vec4 position = projection * vec4(view_position, 1.0);
	// Shadow cameras for directional lights are orthographic; leave shadows where the body is.
	if (projection[3][3] < 0.5) {
		float distance_to_camera = length(view_position);
		float pushed_distance = max(distance_to_camera - front_push, 0.1);
		vec4 pushed = projection * vec4(view_position * pushed_distance / distance_to_camera, 1.0);
		position.z = pushed.z / pushed.w * position.w;
	}
	return position;
}
