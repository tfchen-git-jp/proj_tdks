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
const VAT_SHADER := preload("res://shaders/vat.gdshader")
## Per enemy type: baked VAT name and recolour (a = strength).
const ENEMY_VAT := [
	{name = "grunt", tint = Color(0.9, 0.12, 0.1, 0.85), scale = 1.0},
	{name = "armored", tint = Color(1, 1, 1, 0.0), scale = 1.0},
	{name = "brute", tint = Color(0.85, 0.3, 0.25, 0.35), scale = 1.0},
	{name = "grunt", tint = Color(0.98, 0.72, 0.12, 0.85), scale = 0.85},  # runner
]
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
## Returns [root, model (turn this), AnimationTree].
static func hero() -> Array:
	var inst: Node3D = (load(HERO) as PackedScene).instantiate()
	for mi in inst.find_children("*", "MeshInstance3D", true, false):
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
	return [root, model, tree]


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
		"gate":
			out = [gate((Level.ROAD_HALF_WIDTH + 0.7) * 2.0), null, null]
	var root: Node3D = out[0]
	if kind != "gate":
		root.scale *= grow
		_no_receive_shadows(root)
	return out


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
	m.shader = VAT_SHADER
	m.set_shader_parameter("albedo_tex", src.albedo_texture if src else null)
	m.set_shader_parameter("pos_tex", load(base + "_pos.res"))
	m.set_shader_parameter("nrm_tex", load(base + "_nrm.res"))
	m.set_shader_parameter("rows_per_frame", int(meta.rows))
	m.set_shader_parameter("row_width", int(meta.row_w))
	m.set_shader_parameter("tint", cfg.tint)
	return [mesh, m, meta]
