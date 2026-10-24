shader_type spatial;
render_mode cull_back;
// The jellyfish bell and tentacles: a flat candy colour with a soft rim glow. Each instance's
// custom red channel flashes it white, for jellyfishes that cannot be caught yet.

uniform vec4 albedo : source_color = vec4(0.96, 0.56, 0.69, 1.0);
uniform vec4 glow_colour : source_color = vec4(1.0, 0.86, 0.93, 1.0);
uniform float glow_strength : hint_range(0.0, 2.0) = 0.55;
uniform float glow_power : hint_range(0.5, 8.0) = 2.4;

varying float flash;


void vertex() {
	flash = INSTANCE_CUSTOM.r;
}


void fragment() {
	float rim = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), glow_power);
	ALBEDO = mix(albedo.rgb, vec3(1.0), flash);
	EMISSION = glow_colour.rgb * rim * glow_strength + vec3(0.55 * flash);
	ROUGHNESS = 0.55;
	SPECULAR = 0.35;
}
