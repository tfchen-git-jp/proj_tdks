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

## name, source, height in metres (feet to top of head, frame 0 of walk),
## fps, clips: [name, source clip, loops].
const JOBS := [
	{name = "grunt", src = "res://assets/chars/mini_dungeon/character-human.glb", height = 0.95, fps = 30.0,
		clips = [["walk", "walk", true], ["attack", "attack-melee-right", true], ["die", "die", false], ["idle", "idle", true]]},
	{name = "armored", src = "res://assets/chars/mini_arena/character-soldier.glb", height = 1.05, fps = 30.0,
		clips = [["walk", "walk", true], ["attack", "attack-melee-right", true], ["die", "die", false], ["idle", "idle", true]]},
	{name = "brute", src = "res://assets/chars/giant/Quaternius_Giant.glb", height = 2.3, fps = 20.0,
		clips = [["walk", "EnemyArmature|EnemyArmature|EnemyArmature|Walk", true],
			["attack", "EnemyArmature|EnemyArmature|EnemyArmature|Attack", true],
			["die", "EnemyArmature|EnemyArmature|EnemyArmature|Death", false],
			["idle", "EnemyArmature|EnemyArmature|EnemyArmature|Idle", true]]},
]


func _init() -> void:
	process_frame.connect(_run, CONNECT_ONE_SHOT)


func _run() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://assets/vat"))
	for job in JOBS:
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

	# Merge every skinned surface into one vertex list.
	var src_v := PackedVector3Array()
	var src_n := PackedVector3Array()
	var uv := PackedVector2Array()
	var idx := PackedInt32Array()
	var owner: Array[int] = []  # which MeshInstance each vertex came from
	var bones := PackedInt32Array()
	var weights := PackedFloat32Array()
	var material: Material = null
	for m in mis.size():
		var arr := mis[m].mesh.surface_get_arrays(0)
		var base := src_v.size()
		var v: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
		src_v.append_array(v)
		src_n.append_array(arr[Mesh.ARRAY_NORMAL])
		uv.append_array(arr[Mesh.ARRAY_TEX_UV])
		var b: PackedInt32Array = arr[Mesh.ARRAY_BONES]
		var w: PackedFloat32Array = arr[Mesh.ARRAY_WEIGHTS]
		var per := b.size() / v.size()
		for i in v.size():
			owner.push_back(m)
			for k in 4:
				bones.push_back(b[i * per + k] if k < per else 0)
				weights.push_back(w[i * per + k] if k < per else 0.0)
		for i in (arr[Mesh.ARRAY_INDEX] as PackedInt32Array):
			idx.push_back(base + i)
		if material == null:
			material = mis[m].get_active_material(0)
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
			var out := _skin(mis, src_v, src_n, owner, bones, weights)
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
func _skin(mis: Array[MeshInstance3D], v: PackedVector3Array, nrm: PackedVector3Array,
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
