extends SceneTree
## Hero model probe: bone list, and per clip the lowest point of the body
## (skinned) and of the crossbow, at the game's scale (Models.HERO_HEIGHT).
##   godot --headless --path . --script res://tools/hero_probe.gd

func _init() -> void:
	process_frame.connect(_run, CONNECT_ONE_SHOT)


func _run() -> void:
	var h: Array = Models.hero()
	var root: Node3D = h[0]
	(h[2] as AnimationTree).active = false  # sample clips directly
	var ap: AnimationPlayer = root.find_children("*", "AnimationPlayer", true, false)[0]
	get_root().add_child(root)
	var skel: Skeleton3D = root.find_children("*", "Skeleton3D", true, false)[0]
	var names := []
	for b in skel.get_bone_count():
		names.append("%d:%s(p%d)" % [b, skel.get_bone_name(b), skel.get_bone_parent(b)])
	print("[bones] ", ", ".join(names))
	var bodies: Array[MeshInstance3D] = []
	var bow: MeshInstance3D = null
	for mi in root.find_children("*", "MeshInstance3D", true, false):
		if (mi as MeshInstance3D).skin:
			bodies.push_back(mi)
		elif mi.name == Models.HERO_WEAPON:
			bow = mi
	for clip in ["Idle", "2H_Ranged_Aiming", "2H_Ranged_Shooting", "Running_A", "Running_Strafe_Left",
			"Running_Strafe_Right", "Walking_Backwards", "Walking_A"]:
		var anim := ap.get_animation(clip)
		var body_min := INF
		var bow_min := INF
		var n := 12
		for f in n:
			ap.play(clip)
			ap.seek(anim.length * f / n, true)
			for mi in bodies:
				var arr := mi.mesh.surface_get_arrays(0)
				var v: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
				var bo: PackedInt32Array = arr[Mesh.ARRAY_BONES]
				var w: PackedFloat32Array = arr[Mesh.ARRAY_WEIGHTS]
				var per := bo.size() / v.size()
				var mats: Array[Transform3D] = []
				for k in mi.skin.get_bind_count():
					var bone := mi.skin.get_bind_bone(k)
					if bone < 0:
						bone = skel.find_bone(mi.skin.get_bind_name(k))
					mats.push_back(skel.global_transform * skel.get_bone_global_pose(bone) * mi.skin.get_bind_pose(k))
				for i in range(0, v.size(), 2):
					var p := Vector3.ZERO
					for k in per:
						if w[i * per + k] > 0.0:
							p += (mats[bo[i * per + k]] * v[i]) * w[i * per + k]
					body_min = minf(body_min, p.y)
			if bow:
				var att := bow.get_parent() as BoneAttachment3D
				var xf := skel.global_transform * skel.get_bone_global_pose(att.bone_idx) * bow.transform
				var bb := bow.mesh.get_aabb()
				for c in 8:
					var corner := bb.position + bb.size * Vector3(c & 1, (c >> 1) & 1, (c >> 2) & 1)
					bow_min = minf(bow_min, (xf * corner).y)
		print("[clip] %-22s len=%.2f body_min_y=%+.3f bow_min_y=%+.3f" % [clip, anim.length, body_min, bow_min])
	quit()
