shader_type spatial;
// Vertex-animation-texture playback for MultiMesh crowds (tools/bake_vat.gd).
// Per instance: INSTANCE_CUSTOM = (clip start frame, clip frame count,
// frame position (float), loops 0/1); COLOR = hit-flash multiplier.
render_mode cull_back;

#include "res://shaders/vat_body.gdshaderinc"
