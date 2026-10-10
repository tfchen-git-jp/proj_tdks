class_name Fx
extends Node3D
## The hero-upgrade effects (Perks): glowing bolt tips, flames on burning
## enemies, the Spirit Wisp, the Rally/Spotter aura, Engineer rings on
## gates, lightning, blasts, crit sparks, level-up bursts. main.gd owns
## one, calls draw() every frame and the effect functions from events.

const GLOW_SHADER := preload("res://shaders/glow.gdshader")
const FLAME_SHADER := preload("res://shaders/flame.gdshader")
const GLOW_CAP := 256
const FLAME_CAP := 200
## Bolt tip colours by element (Sim projectile `elem`, or the wisp).
const ELEM_COLORS := {"": Color(1.0, 0.92, 0.65, 0.55), "fire": Color(1.0, 0.42, 0.08, 1.0),
	"frost": Color(0.45, 0.85, 1.0, 1.0), "wisp": Color(0.75, 0.45, 1.0, 1.0)}
## Flame height per enemy type (Level.ENEMIES order) in metres.
const BODY_H := [0.95, 1.05, 2.3, 0.8, 0.9, 1.15, 3.4]
const TO_CAMERA := Vector3(0, 0.829, 0.559)
const CAM_UP := Vector3(0, 0.559, -0.829)  # screen up, in the world (pitch 56)

var _glow_mm: MultiMesh
var _glow_buf := PackedFloat32Array()
var _flame_mm: MultiMesh
var _flame_buf := PackedFloat32Array()
var _wisp: Node3D
var _aura: MeshInstance3D
var _gate_rings := {}  # gate slot -> MeshInstance3D
var _last := {}  # effect name -> msec (rate limits)
var _ring_maker: Callable  # main._ring(r, colour, width)


func setup(ring_maker: Callable) -> void:
	_ring_maker = ring_maker
	_glow_mm = _batch(GLOW_SHADER, GLOW_CAP)
	_flame_mm = _batch(FLAME_SHADER, FLAME_CAP)
	_aura = ring_maker.call(Perks.AURA, Color(1.0, 0.8, 0.3, 0.35), 0.03)
	_aura.visible = false
	add_child(_aura)
	_wisp = _make_wisp()
	_wisp.visible = false
	add_child(_wisp)


func _batch(shader: Shader, cap: int) -> MultiMesh:
	var q := QuadMesh.new()
	q.size = Vector2.ONE
	var mat := ShaderMaterial.new()
	mat.shader = shader
	q.material = mat
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = true
	mm.mesh = q
	mm.instance_count = cap
	mm.visible_instance_count = 0
	mm.custom_aabb = AABB(Vector3(World.X0, -6, World.Z0), Vector3(World.X1 - World.X0, 30, World.Z1 - World.Z0))
	var mmi := MultiMeshInstance3D.new()
	mmi.multimesh = mm
	mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mmi)
	return mm


func _make_wisp() -> Node3D:
	var root := Node3D.new()
	var core := MeshInstance3D.new()
	var sph := SphereMesh.new()
	sph.radius = 0.11
	sph.height = 0.22
	core.mesh = sph
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.albedo_color = Color(0.95, 0.85, 1.0)
	core.material_override = m
	core.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(core)
	var halo := MeshInstance3D.new()
	var q := QuadMesh.new()
	q.size = Vector2.ONE * 0.9
	var hm := ShaderMaterial.new()
	hm.shader = GLOW_SHADER
	hm.set_shader_parameter("tint", Color(0.75, 0.45, 1.0, 1.0))
	q.material = hm
	halo.mesh = q
	halo.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(halo)
	var trail := CPUParticles3D.new()
	trail.amount = 28
	trail.color = Color.WHITE
	trail.lifetime = 0.5
	trail.local_coords = false
	trail.gravity = Vector3(0, 0.3, 0)
	trail.initial_velocity_max = 0.15
	trail.scale_amount_min = 0.5
	trail.scale_amount_max = 1.0
	var tm := StandardMaterial3D.new()
	tm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	tm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	tm.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	tm.vertex_color_use_as_albedo = true
	tm.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	var tq := QuadMesh.new()
	tq.size = Vector2.ONE * 0.12
	tq.material = tm
	trail.mesh = tq
	var grad := Gradient.new()
	grad.set_color(0, Color(0.8, 0.5, 1.0, 0.9))
	grad.set_color(1, Color(0.4, 0.2, 1.0, 0.0))
	trail.color_ramp = grad
	root.add_child(trail)
	return root


## Every frame: bolt glows, flames, wisp, aura, gate rings.
func draw(sim: Sim, hero_at: Vector3, alpha: float, dt_step: float) -> void:
	# Glows on hero bolts and wisp shots.
	if _glow_buf.size() != GLOW_CAP * 16:
		_glow_buf.resize(GLOW_CAP * 16)
	var n := 0
	for p in sim.projectiles:
		if n >= GLOW_CAP:
			break
		var hero: bool = p.get("hero", false)
		if not hero and p.kind != "wisp":
			continue
		var pt := float(p.t) - (1.0 - alpha) * dt_step
		if pt < 0.0:
			continue
		var col: Color = ELEM_COLORS["wisp" if p.kind == "wisp" else String(p.get("elem", ""))]
		var size := 0.55 if col.a > 0.9 else 0.32
		_put16(_glow_buf, n, Transform3D(Basis().scaled(Vector3.ONE * size), Sim.proj_pos(p, pt)), col)
		n += 1
	_glow_mm.buffer = _glow_buf
	_glow_mm.visible_instance_count = n
	# Flames on burning enemies.
	if _flame_buf.size() != FLAME_CAP * 16:
		_flame_buf.resize(FLAME_CAP * 16)
	var h := sim.horde
	var nf := 0
	for i in h.count():
		if nf >= FLAME_CAP:
			break
		if h.burn_t[i] <= 0.0 or h.hp[i] <= 0.0:
			continue
		var p := h.pos[i]
		if i < h.prev_pos.size():
			p = h.prev_pos[i].lerp(p, alpha)
		var bh: float = BODY_H[h.kind[i]]
		var rad := float(Level.ENEMIES[h.kind[i]].radius)
		var w := rad * 3.6
		var fade := clampf(h.burn_t[i] / 0.5, 0.3, 1.0)
		var fh := bh * 1.25 * fade
		# In front of the body (toward the camera), or the body hides it.
		# The billboard's base on the feet: offset along the camera's up.
		var at := p + CAM_UP * (fh * 0.5) + Vector3(0, 0.05, 0) + TO_CAMERA * (rad + 0.3 + fh * 0.5)
		var xf := Transform3D(Basis().scaled(Vector3(w, fh, w)), at)
		_put16(_flame_buf, nf, xf, Color(1, 1, 1, fmod(float(h.uid[i]) * 0.137, 1.0)))
		nf += 1
	_flame_mm.buffer = _flame_buf
	_flame_mm.visible_instance_count = nf
	# Wisp, aura.
	_wisp.visible = "wisp" in sim.relics and sim.state == "play"
	if _wisp.visible:
		_wisp.global_position = hero_at + (sim.wisp_pos() - sim.hero_pos)
	_aura.visible = sim.tier("rally") > 0 and sim.state == "play"
	if _aura.visible:
		_aura.position = hero_at + Vector3(0, 0.05, 0)
		(_aura.material_override as StandardMaterial3D).albedo_color.a = 0.22 + 0.12 * sin(sim.time * 3.0)
	# Engineer: a blue ring on each gate it strengthens.
	for b in sim.buildings.values():
		if b.kind != "gate":
			continue
		var ln := int(b.spot.slot)
		if not _gate_rings.has(ln):
			var r: MeshInstance3D = _ring_maker.call(2.1, Color(0.4, 0.75, 1.0, 0.55), 0.06)
			add_child(r)
			_gate_rings[ln] = r
		var ring: MeshInstance3D = _gate_rings[ln]
		ring.visible = sim.tier("engineer") > 0 and not b.broken
		if ring.visible:
			ring.position = sim.tracks[h.gate_lane[ln]].point(h.gate_d[ln]) + Vector3(0, 0.06, 0)
			var s := 1.0 + 0.05 * sin(sim.time * 5.0)
			ring.scale = Vector3(s, 1, s)


func _put16(buf: PackedFloat32Array, i: int, xf: Transform3D, c: Color) -> void:
	var o := i * 16
	var b := xf.basis
	buf[o] = b.x.x; buf[o + 1] = b.y.x; buf[o + 2] = b.z.x; buf[o + 3] = xf.origin.x
	buf[o + 4] = b.x.y; buf[o + 5] = b.y.y; buf[o + 6] = b.z.y; buf[o + 7] = xf.origin.y
	buf[o + 8] = b.x.z; buf[o + 9] = b.y.z; buf[o + 10] = b.z.z; buf[o + 11] = xf.origin.z
	buf[o + 12] = c.r; buf[o + 13] = c.g; buf[o + 14] = c.b; buf[o + 15] = c.a


func _limited(name: String, gap_ms: int) -> bool:
	var now := Time.get_ticks_msec()
	if now - int(_last.get(name, -100000)) < gap_ms:
		return true
	_last[name] = now
	return false


# --- one-off effects -------------------------------------------------------------

## Thunderstrike: a jagged, flickering bolt from the sky through every
## enemy hit, with a flash of light and sparks where it lands.
func lightning(points: Array) -> void:
	var mi := MeshInstance3D.new()
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	m.vertex_color_use_as_albedo = true
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	mi.material_override = m
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mi)
	mi.mesh = _bolt_mesh(points)
	var light := OmniLight3D.new()
	light.light_color = Color(0.6, 0.75, 1.0)
	light.light_energy = 6.0
	light.omni_range = 7.0
	light.position = points[1] + Vector3(0, 1.0, 0)
	add_child(light)
	for k in range(1, points.size()):
		_burst(points[k], Color(0.6, 0.85, 1.0), 14, 2.5)
	var tw := mi.create_tween()
	for f in 5:
		tw.tween_interval(0.05)
		tw.tween_callback(func() -> void: mi.mesh = _bolt_mesh(points))
	tw.tween_property(m, "albedo_color:a", 0.0, 0.18)
	tw.tween_callback(mi.queue_free)
	var lt := light.create_tween()
	lt.tween_property(light, "light_energy", 0.0, 0.4)
	lt.tween_callback(light.queue_free)


## A fresh random jag of the bolt: a wide blue glow and a thin white core,
## as camera-facing ribbons, plus a few short forks.
func _bolt_mesh(points: Array) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for k in range(points.size() - 1):
		var a: Vector3 = points[k]
		var b: Vector3 = points[k + 1]
		var jag := 0.55 if k == 0 else 0.28
		var path := _jagged(a, b, jag)
		_ribbon(st, path, 0.22, Color(0.35, 0.55, 1.0, 0.55))
		_ribbon(st, path, 0.07, Color(0.95, 0.97, 1.0, 1.0))
		for f in 2:
			var from: Vector3 = path[randi_range(1, path.size() - 2)]
			var dir := (b - a).normalized().rotated(Vector3.UP, randf_range(-1.2, 1.2)) + Vector3(0, randf_range(-0.6, 0.6), 0)
			_ribbon(st, _jagged(from, from + dir.normalized() * randf_range(0.6, 1.4), 0.2), 0.05,
				Color(0.6, 0.8, 1.0, 0.8))
	return st.commit()


func _jagged(a: Vector3, b: Vector3, jag: float) -> Array:
	var n := maxi(3, int(a.distance_to(b) / 0.45))
	var dir := (b - a).normalized()
	var side := dir.cross(TO_CAMERA).normalized()
	if side.length() < 0.1:
		side = Vector3.RIGHT
	var up := dir.cross(side).normalized()
	var out := [a]
	for i in range(1, n):
		var t := float(i) / n
		out.push_back(a.lerp(b, t) + side * randf_range(-jag, jag) + up * randf_range(-jag, jag) * 0.5)
	out.push_back(b)
	return out


func _ribbon(st: SurfaceTool, path: Array, w: float, col: Color) -> void:
	for i in range(path.size() - 1):
		var a: Vector3 = path[i]
		var b: Vector3 = path[i + 1]
		var side := (b - a).cross(TO_CAMERA).normalized() * w * 0.5
		st.set_color(col)
		st.add_vertex(a - side)
		st.add_vertex(b - side)
		st.add_vertex(b + side)
		st.add_vertex(a - side)
		st.add_vertex(b + side)
		st.add_vertex(a + side)


## Explosive Tips: a quick orange fireball and sparks.
func blast(p: Vector3, r: float) -> void:
	if _limited("blast", 40):
		return
	var mi := MeshInstance3D.new()
	var sph := SphereMesh.new()
	sph.radius = 1.0
	sph.height = 2.0
	sph.radial_segments = 12
	sph.rings = 6
	mi.mesh = sph
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	m.albedo_color = Color(1.0, 0.55, 0.15, 0.8)
	mi.material_override = m
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.position = p + Vector3(0, 0.45, 0)
	mi.scale = Vector3.ONE * r * 0.3
	add_child(mi)
	var tw := mi.create_tween().set_parallel()
	tw.tween_property(mi, "scale", Vector3.ONE * r, 0.22).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)
	tw.tween_property(m, "albedo_color", Color(0.6, 0.15, 0.02, 0.0), 0.28)
	tw.chain().tween_callback(mi.queue_free)
	_burst(p + Vector3(0, 0.4, 0), Color(1.0, 0.6, 0.2), 10, 2.5)


## Keen Eye: a bright yellow spark burst on a critical hit.
func crit(p: Vector3) -> void:
	if _limited("crit", 50):
		return
	_burst(p + Vector3(0, 0.6, 0), Color(1.0, 0.9, 0.3), 12, 3.5)


## A golden ring and rising sparks around the hero.
func level_up(p: Vector3) -> void:
	var ring: MeshInstance3D = _ring_maker.call(1.0, Color(1.0, 0.85, 0.35, 0.9), 0.12)
	ring.position = p + Vector3(0, 0.08, 0)
	ring.scale = Vector3(0.3, 1, 0.3)
	add_child(ring)
	var m := ring.material_override as StandardMaterial3D
	var tw := ring.create_tween().set_parallel()
	tw.tween_property(ring, "scale", Vector3(3.0, 1, 3.0), 0.6).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)
	tw.tween_property(m, "albedo_color:a", 0.0, 0.65)
	tw.chain().tween_callback(ring.queue_free)
	var sp := _burst(p + Vector3(0, 0.3, 0), Color(1.0, 0.85, 0.35), 30, 3.0)
	sp.direction = Vector3.UP
	sp.spread = 25.0
	var label := Label3D.new()
	label.text = Loc.t("LEVEL UP!")
	label.font_size = 64
	label.outline_size = 14
	label.pixel_size = 0.006
	label.modulate = Color(1.0, 0.85, 0.35)
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.no_depth_test = true
	label.position = p + Vector3(0, 2.2, 0)
	add_child(label)
	var lt := label.create_tween().set_parallel()
	lt.tween_property(label, "position:y", p.y + 3.4, 1.2)
	lt.tween_property(label, "modulate:a", 0.0, 1.2).set_delay(0.5)
	lt.chain().tween_callback(label.queue_free)


## One-shot spark burst; returns it for tweaks.
func _burst(p: Vector3, col: Color, amount: int, speed: float) -> CPUParticles3D:
	var d := CPUParticles3D.new()
	d.one_shot = true
	d.explosiveness = 0.95
	d.amount = amount
	d.lifetime = 0.5
	d.local_coords = false
	d.direction = Vector3.UP
	d.spread = 90.0
	d.initial_velocity_min = speed * 0.4
	d.initial_velocity_max = speed
	d.gravity = Vector3(0, -6.0, 0)
	d.scale_amount_min = 0.6
	d.scale_amount_max = 1.2
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	m.vertex_color_use_as_albedo = true
	m.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	var q := QuadMesh.new()
	q.size = Vector2.ONE * 0.09
	q.material = m
	d.mesh = q
	var grad := Gradient.new()
	grad.set_color(0, col)
	grad.set_color(1, Color(col.r, col.g * 0.6, col.b * 0.4, 0.0))
	d.color_ramp = grad
	d.position = p
	add_child(d)
	d.emitting = true
	get_tree().create_timer(1.0).timeout.connect(d.queue_free)
	return d
