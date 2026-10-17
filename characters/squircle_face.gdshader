shader_type spatial;
render_mode unshaded;
// The untinted face artwork, neutral or blinking.

#include "res://characters/squircle_front.gdshaderinc"

uniform sampler2D face : source_color, filter_linear_mipmap;


void vertex() {
	POSITION = pushed_position((MODELVIEW_MATRIX * vec4(VERTEX, 1.0)).xyz, PROJECTION_MATRIX);
}


void fragment() {
	vec4 artwork = texture(face, UV);
	ALBEDO = artwork.rgb;
	ALPHA = artwork.a;
	ALPHA_SCISSOR_THRESHOLD = 0.5;
}
