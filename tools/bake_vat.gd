extends SceneTree
## Bakes skinned enemy models into vertex-animation textures (VAT) so a
## crowd can be one MultiMesh per type: a shader reads each vertex's
## position for the current frame from a float texture instead of skinning.
##   godot --headless --path . --script res://tools/bake_vat.gd
## Writes assets/vat/<name>.res (merged mesh, frame-0 pose, metadata "vat")
## and <name>_pos.res / <name>_nrm.res (RGBAH textures).
## Texture layout: ROW_W texels per row; a frame takes `rows` rows; frames
## of all clips are stacked: row = (clip_start + frame) * rows + vid / ROW_W.

const ROW_W := 1024
const PALETTE_W := 16

## name, source, height in metres (feet to top of head, frame 0 of walk),
## fps, clips: [name, source clip, loops], attach: rigid meshes on bones
## (BoneAttachment3D children: weapons, hats) to bake along, extra: [file,
## bone] parts from separate files, palette: flat-coloured surfaces.
const JOBS := [
	{name = "grunt", src = "res://assets/chars/mini_dungeon/character-human.glb", height = 0.95, fps = 30.0,
		clips = [["walk", "walk", true], ["attack", "attack-melee-right", true], ["die", "die", false], ["idle", "idle", true]]},
	{name = "armored", src = "res://assets/chars/mini_arena/character-soldier.glb", height = 1.05, fps = 30.0,
		clips = [["walk", "walk", true], ["attack", "attack-melee-right", true], ["die", "die", false], ["idle", "idle", true]]},
	# KayKit Barbarian (the hero's pack and style; was Quaternius' Giant).
	{name = "brute", src = "res://assets/chars/barbarian/Barbarian.glb", height = 2.3, fps = 24.0,
		attach = ["2H_Axe", "Barbarian_Hat", "Barbarian_Cape"],
		clips = [["walk", "Walking_A", true], ["attack", "2H_Melee_Attack_Chop", true],
			["die", "Death_A", false], ["idle", "2H_Melee_Idle", true]]},
	# Quaternius Animated Monster Pack bat (flat colours -> palette).
	{name = "bat", src = "res://assets/chars/bat/Bat.glb", height = 0.9, fps = 24.0, palette = true,
		clips = [["walk", "Bat_Flying", true], ["attack", "Bat_Attack", true],
			["die", "Bat_Death", false], ["idle", "Bat_Flying", true]]},
	# KayKit skeletons: a crossbowman (siege archer) and the boss.
	{name = "siege", src = "res://assets/chars/skeleton/Skeleton_Rogue.glb", height = 1.15, fps = 18.0,
		attach = ["Skeleton_Rogue_Hood", "Skeleton_Rogue_Cape"],
		extra = [["res://assets/chars/skeleton/Skeleton_Crossbow.gltf", "handslot.r"]],
		clips = [["walk", "Walking_D_Skeletons", true], ["attack", "1H_Ranged_Shoot", true],
			["die", "Death_C_Skeletons", false], ["idle", "1H_Ranged_Aiming", true]]},
	{name = "boss", src = "res://assets/chars/skeleton/Skeleton_Warrior.glb", height = 3.4, fps = 15.0,
		attach = ["Skeleton_Warrior_Helmet"],
		extra = [["res://assets/chars/skeleton/Skeleton_Axe.gltf", "handslot.r"],
			["res://assets/chars/skeleton/Skeleton_Shield_Large_A.gltf", "handslot.l"]],
		clips = [["walk", "Walking_B", true], ["attack", "1H_Melee_Attack_Chop", true],
			["die", "Death_C_Skeletons", false], ["idle", "Idle_Combat", true]]},
	# v0.1.28: Quaternius slime (its brood is the same mesh, scaled), a
	# KayKit skeleton mage (healer) and the Adventurers knight (captain).
	{name = "slime", src = "res://assets/chars/slime/Slime.glb", height = 0.8, fps = 20.0, palette = true,
		clips = [["walk", "Slime_Walk", true], ["attack", "Slime_Attack", true],
			["die", "Slime_Death", false], ["idle", "Slime_Idle", true]]},
	{name = "mage", src = "res://assets/chars/skeleton/Skeleton_Mage.glb", height = 1.25, fps = 18.0,
		attach = ["Skeleton_Mage_Hat"],
		extra = [["res://assets/chars/skeleton/Skeleton_Staff.gltf", "handslot.r"]],
		clips = [["walk", "Walking_D_Skeletons", true], ["attack", "Spellcast_Shoot", true],
			["die", "Death_C_Skeletons", false], ["idle", "Spellcasting", true]]},
	{name = "captain", src = "res://assets/chars/knight/Knight.glb", height = 1.25, fps = 18.0,
		attach = ["Knight_Helmet", "Knight_Cape", "1H_Sword", "Badge_Shield"],
		clips = [["walk", "Walking_A", true], ["attack", "1H_Melee_Attack_Chop", true],
			["die", "Death_A", false], ["idle", "Idle", true]]},
	# v0.2.1: shade (KayKit Adventurers Rogue, two knives), sapper (KayKit
	# skeleton minion), drake (Quaternius Dragon, palette), necromancer
	# (KayKit Adventurers Mage with staff).
	{name = "shade", src = "res://assets/chars/rogue2/Rogue.glb", height = 1.2, fps = 18.0,
		attach = ["Rogue_Cape", "Knife", "Knife_Offhand"],
		clips = [["walk", "Running_B", true], ["attack", "Dualwield_Melee_Attack_Chop", true],
			["die", "Death_A", false], ["idle", "Idle", true]]},
	{name = "sapper", src = "res://assets/chars/skeleton/Skeleton_Minion.glb", height = 0.95, fps = 18.0,
		clips = [["walk", "Running_A", true], ["attack", "1H_Melee_Attack_Stab", true],
			["die", "Death_C_Skeletons", false], ["idle", "Idle", true]]},
	{name = "drake", src = "res://assets/chars/dragon/Dragon.glb", height = 1.5, fps = 18.0, palette = true,
		clips = [["walk", "Dragon_Flying", true], ["attack", "Dragon_Attack", true],
			["die", "Dragon_Death", false], ["idle", "Dragon_Flying", true]]},
	{name = "necro", src = "res://assets/chars/mage/Mage.glb", height = 1.3, fps = 18.0,
		attach = ["Mage_Hat", "Mage_Cape", "2H_Staff"],
		clips = [["walk", "Walking_A", true], ["attack", "Spellcast_Shoot", true],
			["die", "Death_A", false], ["idle", "Spellcasting", true]]},
]


func _init() -> void:
	process_frame.connect(_run, CONNECT_ONE_SHOT)


func _run() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://assets/vat"))
	# -- --only=a,b: bake just these.
	var only := []
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--only="):
			only = a.get_slice("=", 1).split(",")
	for job in JOBS:
		if only.is_empty() or job.name in only:
			_bake(job)
	quit()


func _bake(job: Dictionary) -> void:
	var inst: Node3D = (load(job.src) as PackedScene).instantiate()
	root.add_child(inst)
	var ap: AnimationPlayer = inst.find_children("*", "AnimationPlayer", true, false)[0]
	var mis: Array[MeshInstance3D] = []
	for n in inst.find_children("*", "MeshInstance3D", true, false):
		if (n as MeshInstance3D).skin != null:
			mis.push_back(n)

	# Extra rigid parts from separate files (KayKit skeleton weapons): put
	# on their bone like the pack's own weapons. extra: [[path, bone], ...]
	var skel0: Skeleton3D = inst.find_children("*", "Skeleton3D", true, false)[0]
	var attach_names: Array = job.get("attach", []).duplicate()
	for e in job.get("extra", []):
		var att := BoneAttachment3D.new()
		skel0.add_child(att)
		att.bone_name = e[1]
		var part: Node3D = (load(e[0]) as PackedScene).instantiate()
		var pmi: MeshInstance3D = part.find_children("*", "MeshInstance3D", true, false)[0]
		var mi := MeshInstance3D.new()
		mi.mesh = pmi.mesh
		mi.name = "extra_%d" % attach_names.size()
		att.add_child(mi)
		attach_names.push_back(mi.name)
		part.free()

	# Merge every skinned surface into one vertex list. Untextured models
	# (palette = true, Quaternius: one flat colour per surface) get their
	# colours painted into a small palette texture, each vertex's UV on its
	# surface's texel, so the VAT shader still just samples a texture.
	var src_v := PackedVector3Array()
	var src_n := PackedVector3Array()
	var uv := PackedVector2Array()
	var idx := PackedInt32Array()
	var owner: Array[int] = []  # which MeshInstance (or rigid part) each vertex came from
	var bones := PackedInt32Array()
	var weights := PackedFloat32Array()
	var material: Material = null
	# (lambdas capture locals by value: the material found inside add_surface
	# goes out through this array)
	var mat_box: Array = [null]
	var palette: bool = job.get("palette", false)
	var pal_cols: Array[Color] = []
	var add_surface := func(mi: MeshInstance3D, sf: int, own: int, rigid_part: bool) -> void:
		var arr := mi.mesh.surface_get_arrays(sf)
		var base := src_v.size()
		var v: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
		src_v.append_array(v)
		src_n.append_array(arr[Mesh.ARRAY_NORMAL])
		var mat := mi.get_active_material(sf)
		if palette:
			# glTF colour factors arrive linear; the palette texture is sRGB.
			var col := (mat as BaseMaterial3D).albedo_color.linear_to_srgb() if mat is BaseMaterial3D else Color.WHITE
			var k := pal_cols.find(col)
			if k < 0:
				k = pal_cols.size()
				pal_cols.push_back(col)
			for i in v.size():
				uv.push_back(Vector2((k + 0.5) / PALETTE_W, 0.5))
		else:
			uv.append_array(arr[Mesh.ARRAY_TEX_UV])
			if mat_box[0] == null:
				mat_box[0] = mat
		if rigid_part:
			for i in v.size():
				owner.push_back(own)
				bones.append_array([0, 0, 0, 0])
				weights.append_array([1.0, 0.0, 0.0, 0.0])
		else:
			var b: PackedInt32Array = arr[Mesh.ARRAY_BONES]
			var w: PackedFloat32Array = arr[Mesh.ARRAY_WEIGHTS]
			var per := b.size() / v.size()
			for i in v.size():
				owner.push_back(own)
				for k in 4:
					bones.push_back(b[i * per + k] if k < per else 0)
					weights.push_back(w[i * per + k] if k < per else 0.0)
		for i in (arr[Mesh.ARRAY_INDEX] as PackedInt32Array):
			idx.push_back(base + i)
	for m in mis.size():
		for sf in mis[m].mesh.get_surface_count():
			add_surface.call(mis[m], sf, m, false)
	# Rigid parts on bones: each its own "owner" following one bone.
	var rigid: Array = []  # [MeshInstance3D, BoneAttachment3D]
	for nm in attach_names:
		var mi := inst.find_child(nm, true, false) as MeshInstance3D
		var att := mi.get_parent() as BoneAttachment3D
		for sf in mi.mesh.get_surface_count():
			add_surface.call(mi, sf, mis.size() + rigid.size(), true)
		rigid.push_back([mi, att])
	material = mat_box[0]
	if palette:
		var img := Image.create_empty(PALETTE_W, 1, false, Image.FORMAT_RGBA8)
		for k in pal_cols.size():
			img.set_pixel(k, 0, pal_cols[k])
		var pm := StandardMaterial3D.new()
		pm.albedo_texture = ImageTexture.create_from_image(img)
		material = pm
	var nv := src_v.size()
	var rows := int(ceil(float(nv) / ROW_W))

	# Sample every clip.
	var frames_pos: Array[PackedVector3Array] = []
	var frames_nrm: Array[PackedVector3Array] = []
	var clip_meta := {}
	var fps: float = job.fps
	for c in job.clips:
		var anim := ap.get_animation(c[1])
		var loops: bool = c[2]
		var n := maxi(2, roundi(anim.length * fps))
		var count := n if loops else n + 1
		clip_meta[c[0]] = [frames_pos.size(), count, fps, loops]
		for f in count:
			var t := minf(f / fps, anim.length)
			ap.play(c[1])
			ap.seek(t, true)
			var out := _skin(mis, rigid, src_v, src_n, owner, bones, weights)
			frames_pos.push_back(out[0])
			frames_nrm.push_back(out[1])

	# Normalise: face -Z (glTF models face +Z), feet on y = 0, centred on
	# x/z, scaled to the wanted height -- all from frame 0 of the walk.
	var lo := Vector3.INF
	var hi := -Vector3.INF
	for p in frames_pos[0]:
		lo = lo.min(p)
		hi = hi.max(p)
	var s: float = job.height / (hi.y - lo.y)
	var xf := Transform3D(Basis(Vector3.UP, PI).scaled(Vector3.ONE * s), Vector3.ZERO)
	xf = xf * Transform3D(Basis(), -Vector3((lo.x + hi.x) * 0.5, lo.y, (lo.z + hi.z) * 0.5))
	var pos_img := Image.create_empty(ROW_W, rows * frames_pos.size(), false, Image.FORMAT_RGBAH)
	var nrm_img := Image.create_empty(ROW_W, rows * frames_pos.size(), false, Image.FORMAT_RGBAH)
	var box := AABB()
	for f in frames_pos.size():
		for i in nv:
			var p: Vector3 = xf * frames_pos[f][i]
			var nn: Vector3 = (xf.basis * frames_nrm[f][i]).normalized()
			frames_pos[f][i] = p
			box = AABB(p, Vector3.ZERO) if f == 0 and i == 0 else box.expand(p)
			var x := i % ROW_W
			var y := f * rows + i / ROW_W
			pos_img.set_pixel(x, y, Color(p.x, p.y, p.z, 1.0))
			nrm_img.set_pixel(x, y, Color(nn.x, nn.y, nn.z, 0.0))

	# The mesh itself carries frame 0 (for bounds); the shader replaces it.
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	var n0 := PackedVector3Array()
	for i in nv:
		n0.push_back((xf.basis * src_n[i]).normalized())
	arrays[Mesh.ARRAY_VERTEX] = frames_pos[0]
	arrays[Mesh.ARRAY_NORMAL] = n0
	arrays[Mesh.ARRAY_TEX_UV] = uv
	arrays[Mesh.ARRAY_INDEX] = idx
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	mesh.surface_set_material(0, material)
	mesh.custom_aabb = box.grow(0.1)
	mesh.set_meta("vat", {rows = rows, row_w = ROW_W, clips = clip_meta, frames = frames_pos.size()})
	var base_path: String = "res://assets/vat/" + String(job.name)
	ResourceSaver.save(mesh, base_path + ".res")
	ResourceSaver.save(ImageTexture.create_from_image(pos_img), base_path + "_pos.res")
	ResourceSaver.save(ImageTexture.create_from_image(nrm_img), base_path + "_nrm.res")
	var mat_info := ""
	if material is BaseMaterial3D:
		var bm := material as BaseMaterial3D
		mat_info = "albedo=%s tex=%s" % [bm.albedo_color, bm.albedo_texture.resource_path if bm.albedo_texture else "none"]
	print("[vat] %s: %d verts, %d tris, %d frames x %d rows, bounds %s, clips %s, %s" % [
		job.name, nv, idx.size() / 3, frames_pos.size(), rows, box, clip_meta, mat_info])
	inst.queue_free()


## CPU skinning of every vertex at the current animation pose, in the
## model's root space. Returns [positions, normals].
func _skin(mis: Array[MeshInstance3D], rigid: Array, v: PackedVector3Array, nrm: PackedVector3Array,
		owner: Array[int], bones: PackedInt32Array, weights: PackedFloat32Array) -> Array:
	var mats: Array = []
	for mi in mis:
		var skel := mi.get_node(mi.skeleton) as Skeleton3D
		var to_root := skel.global_transform
		var list: Array[Transform3D] = []
		for k in mi.skin.get_bind_count():
			var bone := mi.skin.get_bind_bone(k)
			if bone < 0:
				bone = skel.find_bone(mi.skin.get_bind_name(k))
			list.push_back(to_root * skel.get_bone_global_pose(bone) * mi.skin.get_bind_pose(k))
		mats.push_back(list)
	for r in rigid:
		var att: BoneAttachment3D = r[1]
		var skel := att.get_parent() as Skeleton3D
		mats.push_back([skel.global_transform * skel.get_bone_global_pose(att.bone_idx) * (r[0] as MeshInstance3D).transform])
	var out_v := PackedVector3Array()
	var out_n := PackedVector3Array()
	out_v.resize(v.size())
	out_n.resize(v.size())
	for i in v.size():
		var list: Array = mats[owner[i]]
		var p := Vector3.ZERO
		var nn := Vector3.ZERO
		for k in 4:
			var w := weights[i * 4 + k]
			if w <= 0.0:
				continue
			var m: Transform3D = list[bones[i * 4 + k]]
			p += (m * v[i]) * w
			nn += (m.basis * nrm[i]) * w
		out_v[i] = p
		out_n[i] = nn.normalized()
	return [out_v, out_n]
