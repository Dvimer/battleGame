shader_type canvas_item;

uniform sampler2D fog_texture;
uniform vec2 world_size = vec2(1.0, 1.0);

void fragment() {
	vec2 uv = SCREEN_UV;
	vec2 sample_uv = vec2(UV.x, UV.y);
	vec4 fog = texture(fog_texture, sample_uv);
	COLOR = vec4(0.0, 0.0, 0.0, fog.a);
}
