shader_type canvas_item;

uniform float blur_scale;
uniform float variance;
uniform float brightness;
uniform float contrast;
uniform float contrast_from;

uniform sampler2D screen_texture : hint_screen_texture, filter_linear;

void fragment() {
	vec4 color_sum = vec4(0.0);
	float sum_count = 0.0;
	vec2 blur_distance = SCREEN_PIXEL_SIZE * blur_scale;
	for (float y = SCREEN_UV.y - blur_distance.y; y < SCREEN_UV.y + blur_distance.y; y += SCREEN_PIXEL_SIZE.y * 1.0) {
		float weight = y - SCREEN_UV.y;
		float variance_2 = 2.0 * variance * variance;
		weight = inversesqrt(PI * variance_2) * exp(-((weight * weight) / variance_2));
		color_sum += texture(screen_texture, vec2(SCREEN_UV.x,y)) * weight;
		sum_count += weight;
	}
	vec3 out_color = (color_sum / sum_count).rgb;
	out_color *= brightness;
	out_color = mix(vec3(contrast_from), out_color.rgb, contrast);
	COLOR = vec4(out_color, 1.0);
}