shader_type spatial;
// Grass with soft colour variation and the road painted from a baked
// distance field (tools/bake_terrain.gd): soft, slightly ragged edges like
// the reference. Vertex COLOR multiplies (gorge floor darker).
render_mode cull_back;

uniform sampler2D road_dist : filter_linear, repeat_disable;
// R: broad smooth noise, G: finer noise (tileable, assets/terrain/noise.png).
uniform sampler2D noise_tex : filter_linear_mipmap, repeat_enable;
uniform vec2 map_origin;
uniform vec2 map_size;
uniform float max_dist = 4.0;
uniform float road_half = 1.15;
uniform vec3 grass : source_color = vec3(0.20, 0.62, 0.42);
uniform vec3 grass_dark : source_color = vec3(0.16, 0.55, 0.38);
uniform vec3 grass_light : source_color = vec3(0.25, 0.66, 0.45);
uniform vec3 road : source_color = vec3(0.80, 0.72, 0.58);
uniform vec3 road_edge : source_color = vec3(0.75, 0.65, 0.51);

varying vec3 wpos;

void vertex() {
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	vec2 uv = (wpos.xz - map_origin) / map_size;
	float d = texture(road_dist, uv).r * max_dist;
	vec2 nb = texture(noise_tex, wpos.xz * 0.035).rg;
	vec2 nf = texture(noise_tex, wpos.xz * 0.21 + 0.37).rg;
	float n = nb.r * 0.7 + nf.g * 0.3;
	vec3 g = mix(grass_dark, grass, smoothstep(0.25, 0.6, n));
	g = mix(g, grass_light, smoothstep(0.62, 0.9, n));
	float rag = (nf.r - 0.5) * 0.16;
	float on_road = 1.0 - smoothstep(road_half - 0.15, road_half + 0.2, d + rag);
	vec3 rc = mix(road, road_edge, smoothstep(road_half * 0.3, road_half + 0.1, d));
	rc *= 0.95 + texture(noise_tex, wpos.xz * 0.6).g * 0.1;
	ALBEDO = mix(g, rc, on_road) * COLOR.rgb;
	ROUGHNESS = 0.95;
}
