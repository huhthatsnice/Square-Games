shader_type canvas_item;

uniform float blur_scale;
uniform float variance;

uniform sampler2D screen_texture : hint_screen_texture, filter_linear, repeat_disable;

void fragment() {
	vec4 color_sum = vec4(0.0);
	float sum_count = 0.0;
	vec2 blur_distance = SCREEN_PIXEL_SIZE * blur_scale;
	for (float x = max(SCREEN_UV.x - blur_distance.x, 0.0); x < min(SCREEN_UV.x + blur_distance.x, 1.0); x += SCREEN_PIXEL_SIZE.x * 1.0) {
		float weight = x - SCREEN_UV.x;
		float variance_2 = 2.0 * variance * variance;
		weight = inversesqrt(PI * variance_2) * exp(-((weight * weight) / variance_2));
		color_sum += texture(screen_texture, vec2(x,SCREEN_UV.y)) * weight;
		sum_count += weight;
	}
	COLOR = vec4((color_sum / sum_count).rgb, 1.0);
}