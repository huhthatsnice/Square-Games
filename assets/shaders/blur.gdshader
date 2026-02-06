shader_type canvas_item;

uniform float blur_scale;

uniform sampler2D screen_texture : hint_screen_texture, filter_linear;

void fragment() {
	vec4 color_sum = vec4(0.0);
	float sum_count = 0.0;
	vec2 blur_distance = SCREEN_PIXEL_SIZE * blur_scale;
	for (float x = SCREEN_UV.x - blur_distance.x; x < SCREEN_UV.x + blur_distance.x; x += SCREEN_PIXEL_SIZE.x * 2.0) {
		for (float y = SCREEN_UV.y - blur_distance.y; y < SCREEN_UV.y + blur_distance.y; y += SCREEN_PIXEL_SIZE.y * 2.0) {
			float weight = length(blur_distance) - distance(SCREEN_UV.xy, vec2(x,y));
			color_sum += textureLod(screen_texture, vec2(x,y), 2) * weight;
			sum_count += weight;
		}
	}
	COLOR = color_sum / sum_count;
}