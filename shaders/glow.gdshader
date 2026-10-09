shader_type spatial;
// Soft round glow on a camera-facing quad (bolt tips, the wisp, sparks).
// Instance / vertex COLOR: rgb tint, a strength.
render_mode unshaded, blend_add, depth_draw_never, cull_disabled, shadows_disabled;

uniform vec4 tint : source_color = vec4(1.0);  // for single (non-MultiMesh) glows
varying vec4 v_col;

void vertex() {
	MODELVIEW_MATRIX = VIEW_MATRIX * mat4(INV_VIEW_MATRIX[0], INV_VIEW_MATRIX[1], INV_VIEW_MATRIX[2], MODEL_MATRIX[3]);
	MODELVIEW_MATRIX = MODELVIEW_MATRIX * mat4(vec4(length(MODEL_MATRIX[0].xyz), 0.0, 0.0, 0.0),
		vec4(0.0, length(MODEL_MATRIX[1].xyz), 0.0, 0.0), vec4(0.0, 0.0, length(MODEL_MATRIX[2].xyz), 0.0),
		vec4(0.0, 0.0, 0.0, 1.0));
	v_col = COLOR * tint;
}

void fragment() {
	float d = length(UV - 0.5) * 2.0;
	float a = pow(max(0.0, 1.0 - d), 2.2);
	ALBEDO = v_col.rgb * (1.0 + 1.5 * pow(max(0.0, 1.0 - d * 1.8), 3.0));
	ALPHA = clamp(a * v_col.a, 0.0, 1.0);
}
