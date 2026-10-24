// Draws a character in front of scenery near its action plane without moving it on screen.
// Scaling a view-space position toward the camera keeps its projection and lowers its depth,
// so the character's own parts still sort correctly among themselves.

// World units of scenery the character draws in front of.
uniform float front_push = 2.0;

vec4 pushed_position(vec3 view_position, mat4 projection) {
	// Shadow cameras for directional lights are orthographic; leave shadows where the body is.
	if (projection[3][3] < 0.5) {
		float distance_to_camera = length(view_position);
		view_position *= max(distance_to_camera - front_push, 0.1) / distance_to_camera;
	}
	return projection * vec4(view_position, 1.0);
}
