shader_type spatial;
render_mode unshaded, cull_disabled;
// One face part drawn in front of scenery, on a body that is pushed the same way.

#include "res://characters/cubio_front.gdshaderinc"

uniform sampler2D part : source_color, filter_linear_mipmap_anisotropic, repeat_disable;
// Flips the part horizontally about its centre.
uniform bool mirror = false;


void vertex() {
	POSITION = pushed_position((MODELVIEW_MATRIX * vec4(VERTEX, 1.0)).xyz, PROJECTION_MATRIX);
}


void fragment() {
	vec2 uv = mirror ? vec2(1.0 - UV.x, UV.y) : UV;
	vec4 artwork = texture(part, uv);
	ALBEDO = artwork.rgb;
	ALPHA = artwork.a;
}
