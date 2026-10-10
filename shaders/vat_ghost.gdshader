shader_type spatial;
// The VAT crowd shader, see-through: COLOR.a is each instance's opacity
// (shades, half transparent; more solid while revealed).
render_mode cull_back, blend_mix, depth_draw_always;

#define GHOST
#include "res://shaders/vat_body.gdshaderinc"
