extends SceneTree
## Renders a small transparent portrait of every enemy, building and the
## hero to assets/icons/<name>.png (inline icons in UI text, UiText).
## Needs a GPU (run windowed, like build.sh shot):
##   LD_LIBRARY_PATH=/usr/lib/wsl/lib GALLIUM_DRIVER=d3d12 godot --path . \
##     --rendering-method gl_compatibility --script res://tools/make_icons.gd

const SIZE := 128
const OUT := "res://assets/icons/"

var _vp: SubViewport
var _cam: Camera3D
var _jobs: Array = []  # [name, Node3D]


func _init() -> void:
	process_frame.connect(_run, CONNECT_ONE_SHOT)


func _run() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	_vp = SubViewport.new()
	_vp.size = Vector2i(SIZE, SIZE)
	_vp.transparent_bg = true
	_vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	_vp.own_world_3d = true
	root.add_child(_vp)
	var env := WorldEnvironment.new()
	var e := Environment.new()
	e.background_mode = Environment.BG_CLEAR_COLOR
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color = Color.WHITE
	e.ambient_light_energy = 0.55
	env.environment = e
	_vp.add_child(env)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-45, -35, 0)
	sun.light_energy = 0.9
	_vp.add_child(sun)
	_cam = Camera3D.new()
	_cam.projection = Camera3D.PROJECTION_ORTHOGONAL
	_vp.add_child(_cam)
	for k in Level.ENEMIES.size():
		var got := Models.enemy(k)
		var mi := MeshInstance3D.new()
		mi.mesh = got[0]
		mi.material_override = got[1]
		var holder := Node3D.new()
		holder.add_child(mi)
		holder.rotation_degrees.y = 180.0 - 35.0  # baked models face -Z
		_jobs.push_back([Models.enemy_icon(k), holder])
	for kind in Level.BUILDINGS:
		var b: Node3D = Models.building(kind, 0)[0]
		var holder := Node3D.new()
		holder.add_child(b)
		holder.rotation_degrees.y = -25.0 if kind != "gate" else -20.0
		_jobs.push_back([kind, holder])
	var h: Array = Models.hero()
	(h[2] as AnimationTree).active = false
	var hero := Node3D.new()
	hero.add_child(h[0])
	hero.rotation_degrees.y = 180.0 - 35.0
	_jobs.push_back(["hero", hero])
	for j in _jobs:
		_vp.add_child(j[1])
		(j[1] as Node3D).visible = false
	for j in _jobs:
		_shoot(j[0], j[1])
		for f in 3:
			await process_frame
		var img := _vp.get_texture().get_image()
		img.save_png(ProjectSettings.globalize_path(OUT + String(j[0]) + ".png"))
		(j[1] as Node3D).visible = false
		print("[icon] ", j[0])
	quit()


## Frame node n: orthographic camera from the front-above, fitted to its
## bounds.
func _shoot(name: String, n: Node3D) -> void:
	n.visible = true
	var box := _bounds(n)
	var c := box.get_center()
	var size := maxf(box.size.y, maxf(box.size.x, box.size.z) * 0.9)
	_cam.size = size * 1.12
	_cam.rotation_degrees = Vector3(-14, 0, 0)
	_cam.position = c + Vector3(0, sin(deg_to_rad(14.0)), cos(deg_to_rad(14.0))) * (size * 3.0 + 4.0)
	_cam.far = size * 8.0 + 20.0


func _bounds(n: Node3D) -> AABB:
	var box := AABB()
	var first := true
	for mi in n.find_children("*", "MeshInstance3D", true, false):
		var m := mi as MeshInstance3D
		var b: AABB = m.global_transform * m.get_aabb()
		box = b if first else box.merge(b)
		first = false
	return box
