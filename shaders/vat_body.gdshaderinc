// Shared by vat.gdshader and vat_ghost.gdshader (see vat.gdshader).
uniform sampler2D albedo_tex : source_color, filter_linear_mipmap;
uniform highp sampler2D pos_tex : filter_nearest;
uniform highp sampler2D nrm_tex : filter_nearest;
uniform int rows_per_frame = 1;
uniform int row_width = 1024;
// Recolour toward `tint` by tint.a (0 = the texture's own colours).
uniform vec4 tint : source_color = vec4(1.0, 1.0, 1.0, 0.0);

varying vec3 v_flash;
varying float v_alpha;

void vertex() {
	int count = max(int(INSTANCE_CUSTOM.y), 1);
	float f = INSTANCE_CUSTOM.z;
	int f0 = clamp(int(floor(f)), 0, count - 1);
	float a = f - floor(f);
	int f1 = f0 + 1;
	if (INSTANCE_CUSTOM.w > 0.5) {
		f1 = f1 % count;
	} else {
		f1 = min(f1, count - 1);
	}
	int start = int(INSTANCE_CUSTOM.x);
	int vx = VERTEX_ID % row_width;
	int vy = VERTEX_ID / row_width;
	ivec2 p0 = ivec2(vx, (start + f0) * rows_per_frame + vy);
	ivec2 p1 = ivec2(vx, (start + f1) * rows_per_frame + vy);
	VERTEX = mix(texelFetch(pos_tex, p0, 0).xyz, texelFetch(pos_tex, p1, 0).xyz, a);
	NORMAL = normalize(mix(texelFetch(nrm_tex, p0, 0).xyz, texelFetch(nrm_tex, p1, 0).xyz, a));
	v_flash = COLOR.rgb;
	v_alpha = COLOR.a;
}

void fragment() {
	vec3 c = texture(albedo_tex, UV).rgb;
	float l = dot(c, vec3(0.3, 0.59, 0.11));
	c = mix(c, tint.rgb * (0.45 + l * 0.9), tint.a);
	ALBEDO = c * v_flash;
	ROUGHNESS = 0.85;
#ifdef GHOST
	ALPHA = v_alpha;
#endif
}
