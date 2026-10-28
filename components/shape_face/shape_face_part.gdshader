shader_type spatial;
render_mode unshaded, cull_disabled;
// One face part drawn in front of scenery, on a body that is pushed the same way.

#include "res://characters/cubio_front.gdshaderinc"
#include "res://characters/cubio_dither.gdshaderinc"

uniform sampler2D part : source_color, filter_linear_mipmap_anisotropic, repeat_disable;
// Flips the part horizontally about its centre.
uniform bool mirror = false;

// The push moves each vertex along its view ray, so it stays put on screen but its W changes,
// and the GPU would interpolate the texture with the wrong perspective. Carrying UV scaled by
// pushed W over true W, and that ratio, lets the fragment undo it.
varying vec3 corrected_uv;


void vertex() {
	vec3 view_position = (MODELVIEW_MATRIX * vec4(VERTEX, 1.0)).xyz;
	float true_w = (PROJECTION_MATRIX * vec4(view_position, 1.0)).w;
	POSITION = pushed_position(view_position, PROJECTION_MATRIX);
	float ratio = POSITION.w / true_w;
	corrected_uv = vec3(UV * ratio, ratio);
}


void fragment() {
	if (dithered_out(FRAGCOORD.xy)) {
		discard;
	}
	vec2 uv = corrected_uv.xy / corrected_uv.z;
	uv = mirror ? vec2(1.0 - uv.x, uv.y) : uv;
	vec4 artwork = texture(part, uv);
	ALBEDO = artwork.rgb;
	ALPHA = artwork.a;
}
