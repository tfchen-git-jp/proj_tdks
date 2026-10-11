class_name Models
extends RefCounted
## Loads the real asset-pack models (see CLAUDE.md "Art plan") and builds
## game-ready nodes from them. Sizes are set here, in metres.

const HERO := "res://assets/chars/rogue/Rogue_Hooded.glb"
const HERO_HEIGHT := 1.65
const HERO_WEAPON := "2H_Crossbow"
const TD := "res://assets/props/td/"
const TOWER_SCALE := 1.25
const GATE := "res://assets/props/hexagon/wall_straight_gate.gltf"
const LODGE := "res://assets/props/hexagon/building_lumbermill_blue.gltf"
const LODGE_SCALE := 3.0
const COIN := "res://assets/props/coin/coin.glb"
const COIN_STACK := "res://assets/props/coin/coin_stack_small.glb"
const COIN_STACK_LARGE := "res://assets/props/coin/coin_stack_large.glb"
const VAT_SHADER := preload("res://shaders/vat.gdshader")
const VAT_GHOST_SHADER := preload("res://shaders/vat_ghost.gdshader")
## Per enemy type: baked VAT name and recolour (a = strength).
## name: the baked VAT (assets/vat); icon: assets/icons/<icon>.png.
const ENEMY_VAT := [
	{name = "grunt", icon = "grunt", tint = Color(0.9, 0.12, 0.1, 0.85), scale = 1.0},
	{name = "armored", icon = "armored", tint = Color(1, 1, 1, 0.0), scale = 1.0},
	{name = "brute", icon = "brute", tint = Color(0.85, 0.3, 0.25, 0.35), scale = 1.0},
	{name = "grunt", icon = "runner", tint = Color(0.98, 0.72, 0.12, 0.85), scale = 0.85},
	{name = "bat", icon = "bat", tint = Color(1, 1, 1, 0.0), scale = 1.0},
	{name = "siege", icon = "siege", tint = Color(1, 1, 1, 0.0), scale = 1.0},
	{name = "boss", icon = "boss", tint = Color(0.45, 0.2, 0.6, 0.45), scale = 1.0},
	{name = "slime", icon = "slime", tint = Color(1, 1, 1, 0.0), scale = 1.0},
	{name = "slime", icon = "slimeling", tint = Color(0.55, 0.95, 0.85, 0.5), scale = 0.5},
	{name = "mage", icon = "mage", tint = Color(1, 1, 1, 0.0), scale = 1.0},
	{name = "captain", icon = "captain", tint = Color(0.95, 0.6, 0.15, 0.3), scale = 1.0},
	# v0.2.1: the warded one is the Bone Warlord's model at man size, cyan;
	# the shade is see-through (ghost: the instance colour's alpha).
	{name = "boss", icon = "warded", tint = Color(0.35, 0.85, 1.0, 0.55), scale = 0.36},
	{name = "shade", icon = "shade", tint = Color(0.25, 0.2, 0.45, 0.6), scale = 1.0, ghost = true},
	{name = "sapper", icon = "sapper", tint = Color(1.0, 0.5, 0.12, 0.45), scale = 1.0},
	{name = "drake", icon = "drake", tint = Color(1, 1, 1, 0.0), scale = 1.0},
	{name = "necro", icon = "necro", tint = Color(0.35, 0.12, 0.45, 0.55), scale = 1.0},
]


## Enemy type k's icon name (assets/icons).
static func enemy_icon(k: int) -> String:
	return String(ENEMY_VAT[k].icon)
const HEX := "res://assets/props/hexagon/"


## Loaded scenes, kept referenced so nothing is read from disk mid-game.
static var _scenes := {}


static func scene(path: String) -> PackedScene:
	if not _scenes.has(path):
		_scenes[path] = load(path)
	return _scenes[path]


## Load every model the level can spawn later (towers, gate), so building
## one never stalls on disk reads.
static func preload_all() -> void:
	for kind in Level.BUILDINGS:
		building(kind, 0)[0].free()


## First MeshInstance3D's mesh in a model file (with its materials).
static func mesh_of(path: String) -> Mesh:
	var inst := (load(path) as PackedScene).instantiate()
	var mi: MeshInstance3D = inst.find_children("*", "MeshInstance3D", true, false)[0]
	var m := mi.mesh
	inst.free()
	return m


## Relaxed run (no enemy in range): the upper body follows Running_A, whose
## hand would point the crossbow at the ground; turning it this much about
## its own x carries it forward at chest height (renders, --demo=clips).
const HERO_CARRY_PITCH := -45.0

## Upper-body bones: they take the crossbow pose (aim / shoot) while the
## legs play locomotion, so the hero can shoot on the move. "root" is here
## too: KayKit's strafe clips turn the root +-60 deg, which would swing the
## aim off target; the legs side-step under a body square to the target.
const HERO_UPPER := ["root", "spine", "chest", "upperarm.l", "lowerarm.l", "wrist.l", "hand.l", "handslot.l",
	"upperarm.r", "lowerarm.r", "wrist.r", "hand.r", "handslot.r", "head",
	"elbowIK.l", "handIK.l", "elbowIK.r", "handIK.r"]


## The hero: model scaled to HERO_HEIGHT, facing -Z, only the two-handed
## crossbow shown, driven by an AnimationTree:
##   parameters/legs/blend_position  Vector2(right, forward) in the hero's
##                                   own frame, length = speed fraction
##   parameters/upper/blend_amount   0 = aiming (ready), 1 = shooting
##   parameters/mix/blend_amount     1 = upper body takes the aim/shoot pose,
##                                   0 = it follows the legs (relaxed run)
## Returns [root, model (turn this), AnimationTree, crossbow mesh].
static func hero() -> Array:
	var inst: Node3D = (load(HERO) as PackedScene).instantiate()
	var bow: MeshInstance3D = null
	for mi in inst.find_children("*", "MeshInstance3D", true, false):
		if mi.name == HERO_WEAPON:
			bow = mi
		var bone_parent := mi.get_parent() is BoneAttachment3D
		if bone_parent and mi.name != HERO_WEAPON and mi.name != "Rogue_Cape":
			mi.free()
	inst.scale = Vector3.ONE * (HERO_HEIGHT / 2.2)
	inst.rotation.y = PI
	var model := Node3D.new()
	model.add_child(inst)
	var root := Node3D.new()
	root.add_child(model)
	var ap: AnimationPlayer = inst.find_children("*", "AnimationPlayer", true, false)[0]
	for clip in ["Idle", "Running_A", "Running_Strafe_Left", "Running_Strafe_Right", "Walking_Backwards",
			"2H_Ranged_Shooting", "2H_Ranged_Aiming"]:
		ap.get_animation(clip).loop_mode = Animation.LOOP_LINEAR

	var legs := AnimationNodeBlendSpace2D.new()
	legs.min_space = Vector2(-1, -1)
	legs.max_space = Vector2(1, 1)
	for pt in [["Idle", Vector2.ZERO], ["Running_A", Vector2(0, 1)], ["Running_Strafe_Left", Vector2(-1, 0)],
			["Running_Strafe_Right", Vector2(1, 0)], ["Walking_Backwards", Vector2(0, -1)]]:
		var an := AnimationNodeAnimation.new()
		an.animation = pt[0]
		legs.add_blend_point(an, pt[1], -1, StringName(pt[0]))
	var upper := AnimationNodeBlend2.new()
	var mix := AnimationNodeBlend2.new()
	mix.filter_enabled = true
	for bone in HERO_UPPER:
		mix.set_filter_path(NodePath("Rig/Skeleton3D:" + bone), true)
	var aim := AnimationNodeAnimation.new()
	aim.animation = "2H_Ranged_Aiming"
	var shoot := AnimationNodeAnimation.new()
	shoot.animation = "2H_Ranged_Shooting"
	var bt := AnimationNodeBlendTree.new()
	bt.add_node("legs", legs)
	bt.add_node("aim", aim)
	bt.add_node("shoot", shoot)
	bt.add_node("upper", upper)
	bt.add_node("mix", mix)
	bt.connect_node("upper", 0, "aim")
	bt.connect_node("upper", 1, "shoot")
	bt.connect_node("mix", 0, "legs")
	bt.connect_node("mix", 1, "upper")
	bt.connect_node("output", 0, "mix")
	var tree := AnimationTree.new()
	tree.tree_root = bt
	inst.add_child(tree)
	tree.anim_player = tree.get_path_to(ap)
	tree.set("parameters/mix/blend_amount", 1.0)
	tree.active = true
	return [root, model, tree, bow]


## Ballista tower: stone round tower with the ballista on top.
## Returns [root, turning head, arrow].
static func tower() -> Array:
	var root := Node3D.new()
	var y := 0.0
	for part in ["tower-round-bottom-a", "tower-round-middle-a", "tower-round-top-a"]:
		var p: Node3D = scene(TD + part + ".glb").instantiate()
		p.position.y = y
		root.add_child(p)
		y += 0.6 if part != "tower-round-top-a" else 0.5
	var head: Node3D = scene(TD + "weapon-ballista.glb").instantiate()
	head.position.y = y - 0.12
	root.add_child(head)
	root.scale = Vector3.ONE * TOWER_SCALE
	var arrow: Node3D = head.find_child("arrow", true, false)
	return [root, head, arrow]


## Any building at its level: [root, turning head or null, extra or null].
## The head turns toward the building's aim (yaw only); `extra` is the
## ballista's bolt (hidden while reloading) or the windmill's fan.
static func building(kind: String, level: int) -> Array:
	var grow := 1.0 + 0.08 * level
	var out: Array
	match kind:
		"ballista":
			out = tower()
		"archer":
			var t := _stack([HEX + "building_tower_A_blue.gltf"], 1.3)
			out = [t, null, null]
		"mortar":
			var t := _stack([TD + "tower-square-bottom-a.glb", TD + "tower-square-middle-a.glb",
				TD + "tower-square-top-a.glb"], TOWER_SCALE)
			var head: Node3D = scene(TD + "weapon-catapult.glb").instantiate()
			head.position.y = float(t.get_meta("top")) - 0.05
			t.add_child(head)
			out = [t, head, null]
		"frost":
			var t := _stack([TD + "tower-round-bottom-a.glb", TD + "tower-round-middle-a.glb",
				TD + "tower-round-crystals.glb"], TOWER_SCALE)
			out = [t, t.get_child(2), null]
		"banner":
			var t := _stack([TD + "tower-round-bottom-a.glb", TD + "tower-round-base.glb"], TOWER_SCALE)
			var flag: Node3D = scene(HEX + "flag_blue.gltf").instantiate()
			flag.scale = Vector3.ONE * 6.5 / TOWER_SCALE
			flag.position.y = float(t.get_meta("top"))
			t.add_child(flag)
			out = [t, flag, null]
		"farm":
			var t := _stack([HEX + "building_windmill_blue.gltf"], 1.8)
			out = [t, null, t.find_child("building_windmill_top_fan_blue", true, false)]
		"bank":
			# KayKit's market hall with a heap of gold beside it.
			var t := _stack([HEX + "building_market_blue.gltf"], 1.7)
			var gold: Node3D = scene(COIN_STACK_LARGE).instantiate()
			gold.scale = Vector3.ONE * 0.55 / 1.7
			gold.position = Vector3(-0.42, 0.0, 0.2)
			t.add_child(gold)
			out = [t, null, null]
		"gate":
			out = [gate((Level.ROAD_HALF_WIDTH + 0.7) * 2.0), null, null]
	var root: Node3D = out[0]
	if kind != "gate":
		root.scale *= grow
		_no_receive_shadows(root)
	return out


## A level-IV tower's own look (spec id), from the same CC0 kits: Kenney
## Tower Defense Kit parts and KayKit Hexagon buildings in other colours.
## Returns [root, head (turns to aim) or null, spinner or null]; an
## unknown spec falls back to the level-III model, grown.
static func spec_tower(kind: String, spec: String) -> Array:
	var out: Array = []
	match spec:
		"sniper":  # a taller lookout, red roofs
			var t := _stack([HEX + "building_tower_B_red.gltf"], 1.3)
			out = [t, null, null]
		"repeater":  # square tower, rotary turret
			var t := _stack([TD + "tower-square-bottom-a.glb", TD + "tower-square-middle-b.glb",
				TD + "tower-square-top-a.glb"], TOWER_SCALE)
			var head: Node3D = scene(TD + "weapon-turret.glb").instantiate()
			head.position.y = float(t.get_meta("top")) - 0.05
			t.add_child(head)
			out = [t, head, null]
		"great":  # taller, wide crenellated top, a bigger bolt thrower
			var t := _stack([TD + "tower-round-bottom-b.glb", TD + "tower-round-middle-a.glb",
				TD + "tower-round-middle-a.glb", TD + "tower-round-top-b.glb"], TOWER_SCALE)
			var head: Node3D = scene(TD + "weapon-ballista.glb").instantiate()
			head.scale = Vector3.ONE * 1.35
			head.position.y = float(t.get_meta("top")) - 0.12
			t.add_child(head)
			out = [t, head, null]
		"harpoon":  # the ballista loaded with a trident (user, v0.2.4)
			var t := _stack([TD + "tower-round-bottom-a.glb", TD + "tower-round-middle-b.glb",
				TD + "tower-round-top-a.glb"], TOWER_SCALE)
			var head: Node3D = scene(TD + "weapon-ballista.glb").instantiate()
			head.position.y = float(t.get_meta("top")) - 0.12
			t.add_child(head)
			var kit: Node3D = head.find_child("arrow", true, false)
			kit.visible = false  # Kenney's bow + bolt are one mesh: ours replace both
			var bow := MeshInstance3D.new()
			bow.mesh = bow_mesh()
			bow.position = kit.position
			head.add_child(bow)
			var tri := MeshInstance3D.new()
			tri.mesh = trident_mesh()
			tri.scale = Vector3.ONE * 1.15
			tri.position = kit.position + Vector3(0, 0.03, 0.0)
			head.add_child(tri)
			out = [t, head, tri]
		"cluster":  # square tower, cannon
			var t := _stack([TD + "tower-square-bottom-b.glb", TD + "tower-square-middle-a.glb",
				TD + "tower-square-top-b.glb"], TOWER_SCALE)
			var head: Node3D = scene(TD + "weapon-cannon.glb").instantiate()
			head.position.y = float(t.get_meta("top")) - 0.05
			t.add_child(head)
			out = [t, head, null]
		"fire":  # KayKit's red catapult tower
			var t := _stack([HEX + "building_tower_catapult_red.gltf"], 1.3)
			out = [t, null, null]
		"glacier":  # icy white-blue crystals ringed with snow crystals
			var t := _stack([TD + "tower-round-bottom-a.glb", TD + "tower-round-middle-a.glb",
				TD + "tower-round-crystals.glb"], TOWER_SCALE)
			_tint(t.get_child(2), Color(0.75, 1.1, 1.45))
			for k in 3:
				var c: Node3D = scene(TD + "snow-detail-crystal-large.glb").instantiate()
				var a := TAU * k / 3.0 + 0.4
				c.position = Vector3(cos(a) * 0.45, 0.0, sin(a) * 0.45)
				c.rotation.y = a
				t.add_child(c)
			out = [t, t.get_child(2), null]
		"frostbite":  # jagged base, deep violet crystals, crystal spikes
			var t := _stack([TD + "tower-round-bottom-c.glb", TD + "tower-round-middle-c.glb",
				TD + "tower-round-crystals.glb"], TOWER_SCALE)
			_tint(t.get_child(2), Color(0.55, 0.35, 0.9))
			for k in 4:
				var c: Node3D = scene(TD + "detail-crystal.glb").instantiate()
				var a := TAU * k / 4.0 + 0.4
				c.position = Vector3(cos(a) * 0.5, 0.0, sin(a) * 0.5)
				c.scale = Vector3.ONE * 0.8
				_tint(c, Color(0.55, 0.35, 0.9))
				t.add_child(c)
			out = [t, t.get_child(2), null]
		"drums":  # two red war flags
			var t := _stack([TD + "tower-round-bottom-b.glb", TD + "tower-round-base.glb"], TOWER_SCALE)
			for k in 2:
				var flag: Node3D = scene(HEX + "flag_red.gltf").instantiate()
				flag.scale = Vector3.ONE * 5.5 / TOWER_SCALE
				flag.position = Vector3(-0.22 + 0.44 * k, float(t.get_meta("top")), 0.0)
				flag.rotation.y = PI * 0.5 * (1 - 2 * k) - 0.3
				t.add_child(flag)
			out = [t, t.get_child(2), null]
		"standard":  # one tall golden standard
			var t := _stack([TD + "tower-round-bottom-a.glb", TD + "tower-round-middle-a.glb",
				TD + "tower-round-base.glb"], TOWER_SCALE)
			var flag: Node3D = scene(HEX + "flag_yellow.gltf").instantiate()
			flag.scale = Vector3.ONE * 6.5 / TOWER_SCALE
			flag.position.y = float(t.get_meta("top"))
			flag.rotation.y = PI * 0.5
			t.add_child(flag)
			out = [t, flag, null]
		_:
			return building(kind, 3)
	var root: Node3D = out[0]
	root.scale *= 1.0 + 0.08 * 3
	_no_receive_shadows(root)
	return out


## Kenney-palette colours for the procedural pieces.
const KIT_STEEL := Color(0.72, 0.76, 0.95)
const KIT_WOOD := Color(0.55, 0.32, 0.2)
const KIT_ORANGE := Color(1.0, 0.56, 0.38)


## A trident along +z (tip forward), ~1 m: wooden shaft, steel head of
## three barbed prongs on a crossbar. The harpoon ballista's shot.
static func trident_mesh() -> Mesh:
	var st := _vc_begin()
	_box(st, Vector3(-0.025, -0.025, -0.42), Vector3(0.025, 0.025, 0.2), KIT_WOOD)
	_box(st, Vector3(-0.15, -0.03, 0.18), Vector3(0.15, 0.03, 0.24), KIT_STEEL)
	for x in [-0.125, 0.0, 0.125]:
		var top := 0.46 if x == 0.0 else 0.4
		_box(st, Vector3(x - 0.022, -0.022, 0.24), Vector3(x + 0.022, 0.022, top), KIT_STEEL)
		_spike(st, Vector3(x, 0, top), 0.045, 0.1, KIT_STEEL)
	return _vc_commit(st)


## The ballista's bow: two limbs swept back from the middle.
static func bow_mesh() -> Mesh:
	var st := _vc_begin()
	_box(st, Vector3(-0.07, -0.05, -0.06), Vector3(0.07, 0.05, 0.06), KIT_ORANGE)
	for sgn in [-1.0, 1.0]:
		var t := Transform3D(Basis(Vector3.UP, sgn * 0.45), Vector3(sgn * 0.05, 0, 0))
		_box(st, Vector3(minf(0.0, sgn * 0.3), -0.04, -0.035), Vector3(maxf(0.0, sgn * 0.3), 0.04, 0.035), KIT_ORANGE, t)
	return _vc_commit(st)


static func _vc_begin() -> SurfaceTool:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	return st


static func _vc_commit(st: SurfaceTool) -> Mesh:
	var m := st.commit()
	var mat := StandardMaterial3D.new()
	mat.vertex_color_use_as_albedo = true
	mat.roughness = 0.8
	mat.disable_receive_shadows = true
	m.surface_set_material(0, mat)
	return m


## A flat-shaded box a..b (transformed by t) in colour c.
static func _box(st: SurfaceTool, a: Vector3, b: Vector3, c: Color, t := Transform3D.IDENTITY) -> void:
	var p := []
	for k in 8:
		p.push_back(t * Vector3(b.x if k & 1 else a.x, b.y if k & 2 else a.y, b.z if k & 4 else a.z))
	# Faces as corner indices, counter-clockwise seen from outside.
	for f in [[0, 2, 3, 1], [4, 5, 7, 6], [0, 1, 5, 4], [2, 6, 7, 3], [0, 4, 6, 2], [1, 3, 7, 5]]:
		_quad(st, p[f[0]], p[f[1]], p[f[2]], p[f[3]], c)


## A four-sided point from a square base (half width w) at `base`, length h along +z.
static func _spike(st: SurfaceTool, base: Vector3, w: float, h: float, c: Color) -> void:
	var tip := base + Vector3(0, 0, h)
	var q := [base + Vector3(-w, -w, 0), base + Vector3(w, -w, 0), base + Vector3(w, w, 0), base + Vector3(-w, w, 0)]
	for k in 4:
		_tri(st, q[k], q[(k + 1) % 4], tip, c)
	_quad(st, q[0], q[3], q[2], q[1], c)


static func _quad(st: SurfaceTool, a: Vector3, b: Vector3, c2: Vector3, d: Vector3, c: Color) -> void:
	_tri(st, a, b, c2, c)
	_tri(st, a, c2, d, c)


## One flat triangle; Godot's front face is clockwise, so it is added reversed.
static func _tri(st: SurfaceTool, a: Vector3, b: Vector3, c2: Vector3, c: Color) -> void:
	var n := (b - a).cross(c2 - a).normalized()
	for v in [a, c2, b]:
		st.set_color(c)
		st.set_normal(n)
		st.add_vertex(v)


## Multiply every mesh colour under `n` by `c` (a palette tint on copies
## of the materials: the shared model keeps its colours).
static func _tint(n: Node, c: Color) -> void:
	var meshes := n.find_children("*", "MeshInstance3D", true, false)
	if n is MeshInstance3D:
		meshes.push_back(n)
	for mi in meshes:
		var m := (mi as MeshInstance3D).mesh.surface_get_material(0)
		if m is BaseMaterial3D:
			var d := (m as BaseMaterial3D).duplicate() as BaseMaterial3D
			d.albedo_color = d.albedo_color * c
			d.disable_receive_shadows = true  # as _no_receive_shadows
			(mi as MeshInstance3D).material_override = d


## Model files stacked bottom to top (each placed on the previous one's
## top), the whole scaled by `s`.
static func _stack(paths: Array, s: float) -> Node3D:
	var root := Node3D.new()
	var y := 0.0
	for path in paths:
		var p: Node3D = scene(path).instantiate()
		p.position.y = y
		root.add_child(p)
		var mi: MeshInstance3D = p if p is MeshInstance3D else p.find_children("*", "MeshInstance3D", true, false)[0]
		y += mi.mesh.get_aabb().end.y
	root.scale = Vector3.ONE * s
	root.set_meta("top", y)  # local height of the stack's top
	return root


## Kenney/KayKit building meshes shadow-acne under the sun whatever the
## bias (stippled stone, 2026-10-09): they cast shadows but don't receive.
static func _no_receive_shadows(root: Node) -> void:
	for mi in root.find_children("*", "MeshInstance3D", true, false):
		var m := (mi as MeshInstance3D).mesh.surface_get_material(0)
		if m is BaseMaterial3D and (mi as MeshInstance3D).material_override == null:
			var c := (m as BaseMaterial3D).duplicate() as BaseMaterial3D
			c.disable_receive_shadows = true
			(mi as MeshInstance3D).material_override = c


static func arrow_mesh() -> Mesh:
	return mesh_of(TD + "weapon-ammo-arrow.glb")


static func boulder_mesh() -> Mesh:
	return mesh_of(TD + "weapon-ammo-boulder.glb")


## Stone gate spanning `width` metres along local X.
static func gate(width: float) -> Node3D:
	var g: Node3D = scene(GATE).instantiate()
	g.scale = Vector3(width / 2.0, 1.5, 1.4)
	var root := Node3D.new()
	root.add_child(g)
	return root


static func lodge() -> Node3D:
	var l: Node3D = (load(LODGE) as PackedScene).instantiate()
	l.scale = Vector3.ONE * LODGE_SCALE
	return l


## ShaderMaterial playing type `k`'s baked animation. Returns [mesh, material, meta].
static func enemy(k: int) -> Array:
	var cfg: Dictionary = ENEMY_VAT[k]
	var base := "res://assets/vat/" + String(cfg.name)
	var mesh: ArrayMesh = load(base + ".res")
	var meta: Dictionary = mesh.get_meta("vat")
	var src := mesh.surface_get_material(0) as BaseMaterial3D
	var m := ShaderMaterial.new()
	m.shader = VAT_GHOST_SHADER if cfg.get("ghost", false) else VAT_SHADER
	m.set_shader_parameter("albedo_tex", src.albedo_texture if src else null)
	m.set_shader_parameter("pos_tex", load(base + "_pos.res"))
	m.set_shader_parameter("nrm_tex", load(base + "_nrm.res"))
	m.set_shader_parameter("rows_per_frame", int(meta.rows))
	m.set_shader_parameter("row_width", int(meta.row_w))
	m.set_shader_parameter("tint", cfg.tint)
	return [mesh, m, meta]


## Gold ingot (the top drop tier): a trapezoid bar, origin at its base.
static func ingot_mesh() -> Mesh:
	var lo := [Vector3(-0.23, 0, -0.11), Vector3(0.23, 0, -0.11), Vector3(0.23, 0, 0.11), Vector3(-0.23, 0, 0.11)]
	var hi := [Vector3(-0.17, 0.15, -0.07), Vector3(0.17, 0.15, -0.07), Vector3(0.17, 0.15, 0.07), Vector3(-0.17, 0.15, 0.07)]
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var quads := [[hi[0], hi[1], hi[2], hi[3]]]
	for k in 4:
		quads.push_back([lo[k], lo[(k + 1) % 4], hi[(k + 1) % 4], hi[k]])
	for q in quads:
		for t in [[0, 1, 2], [0, 2, 3]]:
			# Clockwise seen from outside (Godot's front face).
			st.add_vertex(q[t[0]])
			st.add_vertex(q[t[1]])
			st.add_vertex(q[t[2]])
	st.generate_normals()
	var m := st.commit()
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(1.0, 0.78, 0.22)
	mat.metallic = 0.3
	mat.roughness = 0.35
	mat.emission_enabled = true
	mat.emission = Color(0.3, 0.2, 0.02)
	m.surface_set_material(0, mat)
	return m


## Level badges: bronze I, silver II, gold III, ruby IV.
const BADGE_COLORS := [Color(0.78, 0.48, 0.24), Color(0.8, 0.84, 0.9), Color(1.0, 0.8, 0.2), Color(0.85, 0.2, 0.35)]
const ROMAN := ["I", "II", "III", "IV", "V"]
## Direction toward the camera (pitch 56, no yaw): badges face it.
const TO_CAMERA := Vector3(0, 0.829, 0.559)


## A round metal plate with the building's level in Roman numerals, facing
## the camera. Place it with a world position (it is top_level).
static func badge(level: int) -> Node3D:
	var root := Node3D.new()
	root.top_level = true
	var col: Color = BADGE_COLORS[mini(level, BADGE_COLORS.size() - 1)]
	var disc := MeshInstance3D.new()
	var cyl := CylinderMesh.new()
	cyl.top_radius = 0.27
	cyl.bottom_radius = 0.27
	cyl.height = 0.05
	cyl.radial_segments = 20
	cyl.rings = 1
	disc.mesh = cyl
	var mat := StandardMaterial3D.new()
	mat.albedo_color = col
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	disc.material_override = mat
	disc.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	# Cylinder axis (y) toward the camera.
	disc.basis = Basis(Vector3.RIGHT, acos(TO_CAMERA.y))
	root.add_child(disc)
	var rim := MeshInstance3D.new()
	var cyl2 := cyl.duplicate() as CylinderMesh
	cyl2.top_radius = 0.31
	cyl2.bottom_radius = 0.31
	cyl2.height = 0.03
	rim.mesh = cyl2
	var rm := StandardMaterial3D.new()
	rm.albedo_color = Color(0.12, 0.1, 0.08)
	rm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	rim.material_override = rm
	rim.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	rim.basis = disc.basis
	rim.position = -TO_CAMERA * 0.02
	root.add_child(rim)
	var label := Label3D.new()
	label.text = ROMAN[mini(level, ROMAN.size() - 1)]
	label.font_size = 72
	label.outline_size = 10
	label.pixel_size = 0.0045
	label.modulate = Color(0.16, 0.1, 0.05)
	label.outline_modulate = col.lightened(0.35)
	label.shaded = false
	label.double_sided = false
	# Label3D faces +z; tilt it to face the camera, just in front of the disc.
	label.basis = Basis(Vector3.RIGHT, -acos(TO_CAMERA.z))
	label.position = TO_CAMERA * 0.04
	root.add_child(label)
	return root


## Bounds of every mesh under `node`, in node's parent space.
static func bounds(node: Node3D) -> AABB:
	var box := AABB()
	var first := true
	for mi in node.find_children("*", "MeshInstance3D", true, false):
		var xf := Transform3D.IDENTITY
		var n: Node = mi
		while n != node.get_parent() and n is Node3D:
			xf = (n as Node3D).transform * xf
			n = n.get_parent()
		var b: AABB = xf * (mi as MeshInstance3D).get_aabb()
		box = b if first else box.merge(b)
		first = false
	return box
