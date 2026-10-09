extends SceneTree
## Print a model's node tree, mesh sizes, skeleton and animations.
##   godot --headless --path . --script res://tools/inspect.gd -- res://path.glb [--clips]

func _init() -> void:
	var args := OS.get_cmdline_user_args()
	for path in args:
		if path.begins_with("--"):
			continue
		var root: Node = (load(path) as PackedScene).instantiate()
		print("=== ", path)
		_walk(root, 0)
		var aps := root.find_children("*", "AnimationPlayer", true, false)
		for ap in aps:
			var names: PackedStringArray = (ap as AnimationPlayer).get_animation_list()
			var out := []
			for n in names:
				out.append("%s(%.2f)" % [n, (ap as AnimationPlayer).get_animation(n).length])
			print("  clips[%d]: %s" % [names.size(), ", ".join(out)])
		root.free()
	quit()

func _walk(n: Node, depth: int) -> void:
	var line := "  ".repeat(depth) + "%s <%s>" % [n.name, n.get_class()]
	if n is MeshInstance3D:
		var mi := n as MeshInstance3D
		var aabb := mi.mesh.get_aabb()
		var tris := 0
		for s in mi.mesh.get_surface_count():
			var arr := mi.mesh.surface_get_arrays(s)
			var idx: PackedInt32Array = arr[Mesh.ARRAY_INDEX] if arr[Mesh.ARRAY_INDEX] != null else PackedInt32Array()
			tris += idx.size() / 3 if idx.size() > 0 else (arr[Mesh.ARRAY_VERTEX] as PackedVector3Array).size() / 3
		line += " surf=%d tris=%d verts=%d aabb=%s skin=%s" % [mi.mesh.get_surface_count(), tris, (mi.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX] as PackedVector3Array).size(), aabb, mi.skin != null]
	if n is Skeleton3D:
		line += " bones=%d" % (n as Skeleton3D).get_bone_count()
	if n is Node3D and (n as Node3D).transform != Transform3D.IDENTITY:
		line += " xf=%s" % [(n as Node3D).transform]
	print(line)
	for c in n.get_children():
		_walk(c, depth + 1)
