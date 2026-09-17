shader_type spatial;
render_mode diffuse_burley, specular_schlick_ggx;

// NEXUS — متریال سفالِ نرم: زبری بالا، برآمدگی بسیار کم، هایلایتِ گرم.
// رنگ از mesh می‌آید؛ shader فقط «جنس» را می‌سازد تا خانواده‌ی جزیره/کره/پایه
// یکدست بماند. شدت موج آن‌قدر کم است که سیلوئت و خوانایی آموزشی قربانی نشود.
uniform vec4 base_color : source_color = vec4(0.95, 0.78, 0.35, 1.0);
uniform float wobble_strength : hint_range(0.0, 0.16) = 0.04;
uniform float roughness_value : hint_range(0.25, 1.0) = 0.78;

void vertex() {
	float ripple = sin(VERTEX.x * 3.1 + TIME * 0.32) * 0.55;
	ripple += cos(VERTEX.z * 4.7 - TIME * 0.27) * 0.35;
	VERTEX += NORMAL * ripple * wobble_strength * 0.08;
}

void fragment() {
	float light_wrap = 0.94 + 0.06 * max(NORMAL.y, 0.0);
	ALBEDO = base_color.rgb * light_wrap;
	ROUGHNESS = roughness_value;
	METALLIC = 0.0;
	SPECULAR = 0.22;
}
