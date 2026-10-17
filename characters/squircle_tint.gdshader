shader_type spatial;
// The player-tinted body, hands and feet.

#include "res://characters/squircle_front.gdshaderinc"

uniform vec4 player_color : source_color = vec4(0.12, 0.53, 0.9, 1.0);


void vertex() {
	POSITION = pushed_position((MODELVIEW_MATRIX * vec4(VERTEX, 1.0)).xyz, PROJECTION_MATRIX);
}


void fragment() {
	ALBEDO = player_color.rgb;
	ROUGHNESS = 0.32;
	SPECULAR = 0.5;
	RIM = 0.25;
	RIM_TINT = 0.6;
}
