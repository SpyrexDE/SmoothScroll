shader_type canvas_item;

uniform int direction : hint_range(0, 1) = 0;
uniform float fade_size = 32.0;
uniform vec4 mask_rect = vec4(0.0, 0.0, 1.0, 1.0);
uniform vec2 viewport_size = vec2(1.0);
// x: start edge, y: end edge. Disabled edges remain fully opaque.
uniform vec2 edge_mask = vec2(0.0, 0.0);

void fragment() {
	vec2 rect_size = mask_rect.zw - mask_rect.xy;
	vec2 mask_uv = (SCREEN_UV - mask_rect.xy) / max(rect_size, vec2(0.0001));
	float edge_size = direction == 0
		? fade_size / max(1.0, rect_size.y * viewport_size.y)
		: fade_size / max(1.0, rect_size.x * viewport_size.x);

	float coordinate = direction == 0 ? mask_uv.y : mask_uv.x;
	float start_inside = smoothstep(0.0, edge_size, coordinate);
	float end_inside = 1.0 - smoothstep(1.0 - edge_size, 1.0, coordinate);
	float inside = mix(1.0, start_inside, edge_mask.x)
		* mix(1.0, end_inside, edge_mask.y);
	COLOR.a *= clamp(inside, 0.0, 1.0);
}
