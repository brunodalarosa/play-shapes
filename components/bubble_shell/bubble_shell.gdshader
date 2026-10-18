shader_type spatial;
render_mode blend_mix, depth_draw_never, cull_back, unshaded, shadows_disabled;
// A soap-bubble shell that stays clear in its centre so whatever floats inside stays readable:
// colour and opacity gather at the rim, with a soft iridescent sheen and a fixed highlight.

uniform vec4 tint : source_color = vec4(0.72, 0.9, 1.0, 1.0);
// Opacity at the very centre of the shell.
uniform float centre_alpha : hint_range(0.0, 0.3) = 0.03;
// Opacity the rim adds at the silhouette.
uniform float rim_alpha : hint_range(0.0, 1.0) = 0.9;
// Higher keeps the rim thinner.
uniform float rim_power : hint_range(0.5, 8.0) = 2.6;
// How much the rim brightens toward white.
uniform float rim_glow : hint_range(0.0, 1.0) = 0.35;
// How far the rim colour drifts through the iridescent hues.
uniform float iridescence : hint_range(0.0, 1.0) = 0.45;
// Brightness of the window-like highlight.
uniform float highlight : hint_range(0.0, 1.0) = 0.85;
// Pull toward a direction in object space, scaled by its amount: the leading half stretches.
uniform vec3 stretch = vec3(0.0);


void vertex() {
	float amount = length(stretch);
	if (amount > 0.0001) {
		vec3 direction = stretch / amount;
		VERTEX += direction * max(dot(VERTEX, direction), 0.0) * amount;
	}
}


void fragment() {
	float facing = clamp(dot(NORMAL, VIEW), 0.0, 1.0);
	float rim = pow(1.0 - facing, rim_power);
	vec3 phase = vec3(0.0, 0.33, 0.67) + rim * 1.3 + TIME * 0.04;
	vec3 sheen = 0.55 + 0.45 * cos(6.28318 * phase);
	vec3 colour = mix(tint.rgb, sheen, iridescence * smoothstep(0.05, 0.6, rim));
	float main_spot = smoothstep(0.92, 0.975, dot(NORMAL, normalize(vec3(-0.5, 0.62, 0.6))));
	float side_spot = smoothstep(0.965, 0.99, dot(NORMAL, normalize(vec3(0.55, -0.5, 0.67))));
	float spot = (main_spot + side_spot * 0.45) * highlight;
	ALBEDO = mix(colour, vec3(1.0), clamp(spot + rim * rim_glow, 0.0, 1.0));
	ALPHA = clamp(centre_alpha + rim * rim_alpha * tint.a + spot, 0.0, 1.0);
}
