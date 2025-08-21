shader_type spatial;

uniform vec4 color : source_color = vec4(1.0, 0.5, 0.0, 0.9);
uniform sampler2D noise_texture : source_color, filter_linear_mipmap;
uniform float time : hint_range(0.0, 10.0) = 0.0;

void vertex() {
	VERTEX = VERTEX;
}

void fragment() {
	vec2 screen_uv = SCREEN_UV;
	vec3 noise = texture(noise_texture, screen_uv).rgb;
	float alpha = noise.r * color.a;
	ALBEDO = color.rgb;
	ALPHA = alpha;
}
