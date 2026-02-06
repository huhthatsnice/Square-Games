shader_type canvas_item;

uniform float blur_scale;

uniform sampler2D screen_texture : hint_screen_texture;

void fragment() {
	vec4 color_sum = vec4(0.0);
	float sum_count = 0.0;
	for (float x = SCREEN_UV.x - blur_scale * SCREEN_PIXEL_SIZE.x; x < SCREEN_UV.x + blur_scale * SCREEN_PIXEL_SIZE.x; x += SCREEN_PIXEL_SIZE.x) {
		for (float y = SCREEN_UV.y - blur_scale * SCREEN_PIXEL_SIZE.y; y < SCREEN_UV.y + blur_scale * SCREEN_PIXEL_SIZE.y; y += SCREEN_PIXEL_SIZE.y) {
			float weight = length(blur_scale * SCREEN_PIXEL_SIZE.xy) - distance(SCREEN_UV.xy, vec2(x,y));
			color_sum += texture(screen_texture, vec2(x,y)) * weight;
			sum_count += weight;
		}
	}
	COLOR = color_sum / sum_count;
}