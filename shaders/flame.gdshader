shader_type spatial;
// Burning enemies (Fire Bolts): a camera-facing quad per flame in one
// MultiMesh, the flame shape drawn procedurally and licking upward.
// Instance COLOR.a: a random phase so flames don't move in step.
render_mode unshaded, blend_mix, depth_draw_never, cull_disabled, shadows_disabled;

varying float v_phase;

void vertex() {
	// Billboard that keeps the instance's scale.
	MODELVIEW_MATRIX = VIEW_MATRIX * mat4(INV_VIEW_MATRIX[0], INV_VIEW_MATRIX[1], INV_VIEW_MATRIX[2], MODEL_MATRIX[3]);
	MODELVIEW_MATRIX = MODELVIEW_MATRIX * mat4(vec4(length(MODEL_MATRIX[0].xyz), 0.0, 0.0, 0.0),
		vec4(0.0, length(MODEL_MATRIX[1].xyz), 0.0, 0.0), vec4(0.0, 0.0, length(MODEL_MATRIX[2].xyz), 0.0),
		vec4(0.0, 0.0, 0.0, 1.0));
	v_phase = COLOR.a * 40.0;
}

void fragment() {
	float t = TIME * 7.0 + v_phase;
	float y = 1.0 - UV.y;  // 0 at the bottom
	float wob = (sin(y * 7.0 - t) * 0.09 + sin(y * 13.0 - t * 1.7) * 0.045) * y;
	float x = abs(UV.x - 0.5 - wob);
	float width = 0.36 * (1.0 - y) * (0.75 + 0.25 * sin(t * 0.9)) + 0.015;
	float body = smoothstep(width, width * 0.25, x);
	float top = 1.0 - smoothstep(0.45, 0.95, y + 0.12 * sin(t * 1.3 + UV.x * 6.0));
	float a = body * top * smoothstep(0.0, 0.12, y);
	float core = smoothstep(width * 0.9, 0.0, x) * (1.0 - y);
	vec3 col = mix(vec3(1.0, 0.32, 0.03), vec3(1.0, 0.92, 0.5), core);
	ALBEDO = col * 1.25;
	ALPHA = clamp(a * 0.9, 0.0, 1.0);
}
