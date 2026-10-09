extends Node3D
## Level view: runs Sim at a fixed 60 Hz and draws it. All rules live in
## Sim; this file is camera, models, effects, sound and input.
##
## Command-line args (after `--`):
##   --auto            the bot plays (demos, screenshots)
##   --ff=SEC          fast-forward SEC seconds of bot play before showing
##   --speed=X         game speed multiplier
##   --seed=N          RNG seed
##   --shot=PATH       save a screenshot then quit
##   --shot-delay=SEC  real seconds before the screenshot (default 1.5)
##   --bench=SEC       print frame-time stats after SEC seconds, then quit
##   --zoom=X          camera distance multiplier (close-up screenshots)
##   --cam=X,Z         camera looks at world (X, Z) instead of following the hero
##   --cam=gate        camera looks at the first standing gate
##   --hero=X,Z        put the hero there (after any --ff)
##   --build=S:K[:N],… build kind K on spot S (N levels) for free
##   --load            start from the saved run (as Continue does)
##   --drops           a coin, a coin stack and an ingot beside the hero
##   --ff-idle         during --ff the hero starts the wave, then stands aside
##   --noshadow        sun casts no shadows (performance / artefact tests)
##   --mute            no sound (screenshots, benchmarks)
##   --demo=anim|hero  enemy clip lineup / hero animation lineup
##   --demo=clips --clips=A,B  raw hero clips side by side

const DT := 1.0 / 60.0
const CAM_PITCH := 56.0
const CAM_FOV := 38.0  # horizontal (KEEP_WIDTH): same map width on every phone
const CAM_DIST := 19.0
const CAM_POPUP_LIFT := 3.5  # m the view moves down while a build popup is open
const ENEMY_CAP := 900
const CORPSE_CAP := 300
const CORPSE_HOLD := 0.6  # s lying still after the death clip
const CORPSE_SINK := 0.6  # s sinking into the ground
const PAD_TOP := 0.065  # pad surface height (see _make_pad)
const STRIDE := 20  # floats per MultiMesh instance: transform, colour, custom
const PROJ_CAP := 256

var sim: Sim
var bot: Bot
var hud: Hud
var sfx: Sfx
var cam: Camera3D

var _args := {}
var _acc := 0.0
## How far the screen is between the last sim step and the next (0..1):
## enemies and the hero are drawn that far from their previous position,
## so motion is smooth whatever the frame rate (was: jumpy walkers).
var _alpha := 1.0
var _count_seen := -1  # start-pad countdown second last shown (tick sound)
var _speed := 1.0
var _shot_t := -1.0
var _bench_t := -1.0
var _frames: PackedFloat32Array = []
var _zoom := 1.0
var _fast_forwarding := false

var _world: Node3D
var _hero: Node3D
var _hero_model: Node3D
var _hero_tree: AnimationTree
var _hero_shoot := 0.0  # upper-body blend, 0 aim .. 1 shoot
var _hero_relax := 0.0  # 0 combat stance .. 1 relaxed run (no enemy in range)
var _hero_bow: Node3D
var _hero_bow_x := 0.0  # the crossbow's own pitch in the aim pose
var _enemy: Array[Dictionary] = []  # per kind: {mm, buf, clips, scale}
var _corpses: Array[Dictionary] = []  # {pos, basis, kind, t}
## Dropped gold, one batch per tier: coin (1-4), coin stack (5-19),
## ingot (20+), by the piece's value.
const DROP_TIERS := [0, 5, 20]
var _drop_mm: Array[MultiMesh] = []
var _drop_buf: Array[PackedFloat32Array] = []
var _pay_mm: MultiMesh
var _pay_buf := PackedFloat32Array()
var _flying_pay: Array[Dictionary] = []  # coin visuals hero -> spot
var _arrow_mm: MultiMesh
var _arrow_buf := PackedFloat32Array()
var _rock_mm: MultiMesh
var _rock_buf := PackedFloat32Array()
var _pads := {}  # spot id -> {node, label}
var _start_pad: Node3D
var _built := {}  # spot id -> {root, head, extra, kind, level, reload, broken}
var _gate_fx := {}  # lane -> {dust, prev}
var _range_ring: MeshInstance3D
var _lane_labels: Array[Label3D] = []
var _cam_target := Vector3.ZERO
var _shake := 0.0
var _phase_seen := ""
var menu: MainMenu
var _in_menu := false
## Real play (no debug args): show the title menu, keep saves and scores.
var _persist := false
const DEBUG_ARGS := ["auto", "ff", "hero", "demo", "bench", "drops", "build", "cam", "play"]


func _ready() -> void:
	for a in OS.get_cmdline_user_args():
		var kv := a.trim_prefix("--").split("=", true, 1)
		_args[kv[0]] = kv[1] if kv.size() > 1 else "1"
	_speed = float(_args.get("speed", "1"))
	_zoom = float(_args.get("zoom", "1"))
	if _args.has("shot"):
		_shot_t = float(_args.get("shot-delay", "1.5"))
	if _args.has("bench"):
		_bench_t = float(_args.bench)
	_fit_pc_window()
	_persist = true
	for k in DEBUG_ARGS:
		if _args.has(k):
			_persist = false
	_start(Save.load_run() if _args.has("load") else {})
	if _persist and not _args.has("load"):
		_open_menu()


## Title menu over the idle map (also: Esc / Android back during a game;
## Continue then resumes from the last wave start).
func _open_menu() -> void:
	if menu == null:
		menu = MainMenu.new()
		menu.new_game.connect(func() -> void:
			Save.clear_run()
			_start()
			_close_menu())
		menu.continue_game.connect(func() -> void:
			var run := Save.load_run()
			if not run.is_empty():
				_start(run)
				_close_menu())
		add_child(menu)
	menu.visible = true
	menu.show_page(String(_args.get("page", "main")))  # --page=scores|credits (screenshots)
	hud.visible = false
	hud.hide_menu()
	_in_menu = true


func _close_menu() -> void:
	menu.visible = false
	hud.visible = true
	_in_menu = false


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_GO_BACK_REQUEST:
		_back()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and (event as InputEventKey).keycode == KEY_ESCAPE:
		_back()


## Back / Esc: in a game, to the menu; in the menu, up a page, then quit.
func _back() -> void:
	if not _persist:
		return
	if not _in_menu:
		_start(Save.load_run())
		_open_menu()
	elif menu.get("_pages").main.visible:
		get_tree().quit()
	else:
		menu.show_page("main")


## Exported PC build: the 450x1000 window was too small on a 2K monitor.
## Use 90% of the screen's height at the phone's shape (the HUD scales with
## it). Phones and editor / WSL runs (screenshots) keep the project size.
func _fit_pc_window() -> void:
	if not OS.has_feature("template") or OS.has_feature("mobile") or _args.has("shot"):
		return
	var area := DisplayServer.screen_get_usable_rect()
	var h := int(area.size.y * 0.9)
	var w := int(h * 0.45)
	DisplayServer.window_set_size(Vector2i(w, h))
	DisplayServer.window_set_position(area.position + (area.size - Vector2i(w, h)) / 2)
	print("[window] %dx%d on a %dx%d screen area" % [w, h, area.size.x, area.size.y])


## A new game, or the saved run `save` (Sim.to_save()) when given.
func _start(save := {}) -> void:
	for c in get_children():
		if c != menu:
			c.queue_free()
	_corpses.clear()
	_pads.clear()
	_built.clear()
	_gate_fx.clear()
	_flying_pay.clear()
	_enemy.clear()
	_lane_labels.clear()
	_phase_seen = ""
	sim = Sim.from_save(save) if not save.is_empty() else Sim.new(int(_args.get("seed", str(randi() % 100000 if _persist else 1))))
	bot = Bot.new(sim) if _args.has("auto") else null
	_build_scene()
	if not save.is_empty():
		_fast_forwarding = true
		for b in sim.buildings.values():
			_on_built({spot = b.spot, kind = b.kind, level = b.level})
		_fast_forwarding = false
	if _args.has("build"):  # spot:kind[:levels],... built for free
		var keep_coins := sim.coins
		for item in String(_args.build).split(","):
			var f := item.split(":")
			for k in (int(f[2]) if f.size() > 2 else 1):
				sim.coins = 9999
				sim.buy(f[0], f[1])
		sim.coins = keep_coins
		sim.step(DT, Vector2.ZERO)
		_apply_events()
	if _args.has("ff"):
		var ff_bot := bot if bot else Bot.new(sim)
		var steps := int(float(_args.ff) / DT)
		_fast_forwarding = true
		if _args.has("ff-idle"):
			sim.hero_pos = Level.START_SPOT
		for i in steps:
			if _args.has("ff-idle") and sim.phase == "attack":
				sim.hero_pos = Vector3(-13.0, 0, 28.0)  # out of the way
			sim.step(DT, Vector2.ZERO if _args.has("ff-idle") else ff_bot.move())
			_apply_events()
			_age_corpses(DT)
			if sim.state != "play":
				break
		_fast_forwarding = false
		if sim.state != "play":
			_game_over.call_deferred()
	if _args.has("hero"):
		var xz := String(_args.hero).split(",")
		sim.hero_pos = Vector3(float(xz[0]), 0.0, float(xz[1]))
		sim.hero_prev = sim.hero_pos
	if _args.has("drops"):  # one of each gold tier beside the hero
		for k in 3:
			var q := sim.hero_pos + Vector3(-1.2 + k * 1.2, 0, 2.6)
			sim.drop_pos.push_back(q)
			sim.drop_val.push_back([1, 5, 20][k])
			sim.drop_fly.push_back(-1.0)
			sim.drop_from.push_back(q)
	_cam_target = _cam_goal()
	_sync_view(0.0)
	if not _args.has("ff"):
		hud.message("Build your defences,\nthen stand on START to begin", 4.0)


func _build_scene() -> void:
	var env := WorldEnvironment.new()
	var e := Environment.new()
	e.background_mode = Environment.BG_COLOR
	e.background_color = Color(0.36, 0.55, 0.62)
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color = Color(0.72, 0.78, 0.9)
	e.ambient_light_energy = 0.36
	e.tonemap_mode = Environment.TONE_MAPPER_LINEAR
	env.environment = e
	add_child(env)

	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-58, -35, 0)
	sun.light_energy = 0.45
	sun.light_color = Color(1.0, 0.96, 0.88)
	sun.shadow_enabled = not _args.has("noshadow")
	sun.directional_shadow_mode = DirectionalLight3D.SHADOW_ORTHOGONAL
	sun.directional_shadow_max_distance = 36.0
	sun.shadow_bias = 0.12
	sun.shadow_normal_bias = 2.0
	add_child(sun)

	cam = Camera3D.new()
	cam.keep_aspect = Camera3D.KEEP_WIDTH
	cam.fov = CAM_FOV
	cam.far = 120.0
	cam.rotation_degrees = Vector3(-CAM_PITCH, 0, 0)
	add_child(cam)

	_world = Node3D.new()
	add_child(_world)
	World.build(_world, sim.tracks)

	# Enemies: one MultiMesh per type, animated by the VAT shader.
	for k in Level.ENEMIES.size():
		var got := Models.enemy(k)
		var cap := ENEMY_CAP + CORPSE_CAP if k != Level.BRUTE else 60
		var mm := _multimesh(got[0], cap, got[1], true)
		var buf := PackedFloat32Array()
		buf.resize(cap * STRIDE)
		_enemy.push_back({mm = mm, buf = buf, clips = got[2].clips, scale = float(Models.ENEMY_VAT[k].scale)})

	var coin := Models.mesh_of(Models.COIN)
	for m in [coin, Models.mesh_of(Models.COIN_STACK), Models.ingot_mesh()]:
		_drop_mm.push_back(_multimesh(m, Sim.DROP_CAP if m == coin else 128, null, false))
		_drop_buf.push_back(PackedFloat32Array())
	_pay_mm = _multimesh(coin, 64, null, false)
	_arrow_mm = _multimesh(Models.arrow_mesh(), PROJ_CAP, null, false)
	_rock_mm = _multimesh(Models.boulder_mesh(), 64, null, false)

	_hero = Node3D.new()
	var h := Models.hero()
	_hero_model = h[1]
	_hero_tree = h[2]
	_hero_bow = h[3]
	_hero_bow_x = _hero_bow.rotation_degrees.x
	if _args.has("notree"):
		_hero_tree.active = false
	_hero.add_child(h[0])
	_hero.add_child(_ring(float(Level.HERO.range), Color(1, 1, 1, 0.10)))
	add_child(_hero)

	for s in Level.SPOTS:
		_pads[s.id] = _make_pad(s)
	_start_pad = _make_start_pad()
	_range_ring = _ring(1.0, Color(0.5, 0.85, 1.0, 0.5), 0.015)
	_range_ring.visible = false
	add_child(_range_ring)
	for ln in Level.LANES.size():
		var l := Label3D.new()
		l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		l.font_size = 64
		l.outline_size = 16
		l.pixel_size = 0.01
		l.modulate = Color(1, 0.85, 0.8)
		l.outline_modulate = Color(0.25, 0.02, 0.02)
		l.no_depth_test = true
		var t: Track = sim.tracks[ln]
		l.position = t.point(sim.horde.entry[ln] + 1.0) + Vector3(0, 1.6, 0)
		add_child(l)
		_lane_labels.push_back(l)

	sfx = Sfx.new()
	sfx.muted = _args.has("mute") or _args.has("shot") or _args.has("bench")
	add_child(sfx)

	hud = Hud.new()
	hud.restart.connect(func() -> void:
		if _persist:
			Save.clear_run()
		_start())
	hud.to_menu.connect(func() -> void:
		_start()
		_open_menu())
	hud.menu_pick.connect(_on_menu_pick)
	hud.menu_opened.connect(func() -> void: sfx.play("ui_open", -6.0))
	add_child(hud)
	hud.minimap.set_sim(sim, cam)
	if not sfx.muted:
		var music := AudioStreamPlayer.new()
		var stream: AudioStreamMP3 = load("res://assets/music/bgm_city.mp3")
		stream.loop = true
		music.stream = stream
		music.volume_db = -16.0
		add_child(music)
		music.play()
	_warm_up()


## Draw one of everything that appears mid-game (each building, dust,
## flash) for a few frames, hidden under the ground in view, so their
## shaders compile now and not as a hitch when the first one is built.
func _warm_up() -> void:
	Models.preload_all()
	var holder := Node3D.new()
	holder.position = sim.hero_pos + Vector3(0, -9.0, -2.0)
	add_child(holder)
	for kind in Level.BUILDINGS:
		holder.add_child(Models.building(kind, 0)[0])
	var dust := _dust()
	holder.add_child(dust)
	dust.emitting = true
	_flash(holder.position)
	get_tree().create_timer(0.3).timeout.connect(holder.queue_free)


## A MultiMesh drawn by one MultiMeshInstance3D. `mat` null keeps the
## mesh's own materials; `custom` adds per-instance colour + custom data.
func _multimesh(mesh: Mesh, cap: int, mat: Material, custom: bool) -> MultiMesh:
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = custom
	mm.use_custom_data = custom
	mm.mesh = mesh
	mm.instance_count = cap
	mm.visible_instance_count = 0
	# Instances move every frame anywhere on the map: give the batch the
	# whole map as bounds, or a close camera culls it on stale bounds.
	mm.custom_aabb = AABB(Vector3(World.X0, -6, World.Z0), Vector3(World.X1 - World.X0, 16, World.Z1 - World.Z0))
	var mmi := MultiMeshInstance3D.new()
	mmi.multimesh = mm
	if mat:
		mmi.material_override = mat
	mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mmi)
	return mm


## A flat ring on the ground, radius r, band width w (scaled with it).
func _ring(r: float, col: Color, w := 0.08) -> MeshInstance3D:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	st.set_color(col)
	st.set_normal(Vector3.UP)
	var n := 64
	for i in n:
		var a0 := TAU * i / n
		var a1 := TAU * (i + 1) / n
		var o0 := Vector3(cos(a0), 0, sin(a0))
		var o1 := Vector3(cos(a1), 0, sin(a1))
		for v in [o0 * r, o1 * (r - w), o1 * r, o0 * r, o0 * (r - w), o1 * (r - w)]:
			st.add_vertex(v + Vector3(0, 0.05, 0))
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.vertex_color_use_as_albedo = true
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	var mi := MeshInstance3D.new()
	mi.mesh = st.commit()
	mi.material_override = m
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return mi


# --- frame loop ------------------------------------------------------------------

## --demo=anim: every enemy type (rows) playing every clip (columns),
## seen from a low angle, to check the baked animations.
var _demo_t := 0.0


func _demo_anim(delta: float) -> void:
	_demo_t += delta
	var names := ["walk", "attack", "idle", "die"]
	for k in _enemy.size():
		var en: Dictionary = _enemy[k]
		var n := 0
		for c in names.size():
			var clip: Array = en.clips[names[c]]
			var len_s := float(clip[1]) / float(clip[2])
			var t := fmod(_demo_t, len_s + (1.0 if not clip[3] else 0.0))
			var frame := minf(t * float(clip[2]), float(clip[1]) - 1.0) if not clip[3] else fmod(t * float(clip[2]), float(clip[1]))
			var p := Vector3((c - 1.5) * (3.2 if k == Level.BRUTE else 1.6), 0, 9.0 + k * 2.2)
			_put(en.buf, n, Transform3D(Basis(Vector3.UP, PI * 0.5), p), Color.WHITE, clip, frame)
			n += 1
		en.mm.buffer = en.buf
		en.mm.visible_instance_count = n
	cam.rotation_degrees = Vector3(-20, 0, 0)
	cam.position = Vector3(0, 3.5, 22.5)


## --demo=hero: six heroes side by side: aim idle, shooting while running
## forward / strafing left / strafing right / backing up, relaxed run.
var _demo_heroes: Array = []


func _demo_hero() -> void:
	if not _demo_heroes.is_empty():
		return
	_hero.visible = false
	var poses := [[Vector2.ZERO, 0.0], [Vector2(0, 1), 1.0], [Vector2(-1, 0), 1.0], [Vector2(1, 0), 1.0], [Vector2(0, -1), 1.0],
		[Vector2(0, 1), 0.0, 1.0]]
	for i in poses.size():
		var h := Models.hero()
		var root: Node3D = h[0]
		root.position = Vector3((i - 2.5) * 1.2, 0, 9.0)
		if poses[i].size() > 2:  # relaxed run (no enemy in range)
			(h[2] as AnimationTree).set("parameters/mix/blend_amount", 0.0)
			(h[3] as Node3D).rotation_degrees.x += Models.HERO_CARRY_PITCH
		(h[1] as Node3D).rotation.y = -PI * 0.5  # face screen right
		add_child(root)
		var tree: AnimationTree = h[2]
		tree.set("parameters/legs/blend_position", poses[i][0])
		tree.set("parameters/upper/blend_amount", poses[i][1])
		_demo_heroes.push_back(root)
	cam.rotation_degrees = Vector3(-12, 0, 0)
	cam.position = Vector3(0, 1.8, 19.0)


## --demo=clips --clips=A,B,..: raw clips side by side (no AnimationTree).
func _demo_clips() -> void:
	if not _demo_heroes.is_empty():
		return
	_hero.visible = false
	var clips := String(_args.get("clips", "Idle,Running_A")).split(",")
	for i in clips.size():
		var h := Models.hero()
		var root: Node3D = h[0]
		root.position = Vector3((i - (clips.size() - 1) * 0.5) * 1.0, 0, -2.0)
		(h[1] as Node3D).rotation.y = -PI * 0.5
		add_child(root)
		(h[2] as AnimationTree).active = false
		var ap: AnimationPlayer = root.find_children("*", "AnimationPlayer", true, false)[0]
		ap.play(clips[i])
		if _args.has("bowrot"):
			var r := String(_args.bowrot).split(",")
			for mi in root.find_children(Models.HERO_WEAPON, "MeshInstance3D", true, false):
				mi.rotation_degrees += Vector3(float(r[0]), float(r[1]), float(r[2]))
		_demo_heroes.push_back(root)
	cam.rotation_degrees = Vector3(-4, 0, 0)
	cam.position = Vector3(0, 1.0, 7.0)


func _process(delta: float) -> void:
	if _args.get("demo") == "clips":
		_demo_clips()
		_tick_tools(delta)
		return
	if _args.get("demo") == "hero":
		_demo_hero()
		_tick_tools(delta)
		return
	if _args.get("demo") == "anim":
		_demo_anim(delta)
		_tick_tools(delta)
		return
	if _in_menu:
		_menu_camera(delta)
		_tick_tools(delta)
		return
	_acc += minf(delta, 0.1) * _speed
	var steps := 0
	while _acc >= DT and steps < 30:
		_acc -= DT
		steps += 1
		var mv := hud.move + _keys()
		if bot and mv == Vector2.ZERO:
			mv = bot.move()
		var was := sim.state
		var t0 := Time.get_ticks_usec()
		sim.step(DT, mv)
		t0 = _t("sim", t0)
		_apply_events()
		_age_corpses(DT)
		_t("events", t0)
		if was == "play" and sim.state != "play":
			_game_over()
	_alpha = clampf(_acc / DT, 0.0, 1.0)
	_sync_view(delta)
	_tick_tools(delta)


## Won or lost: record the score, drop the saved run, show the end screen.
func _game_over() -> void:
	hud.hide_menu()
	var won := sim.state == "win"
	var cleared := Level.WAVES.size() if won else sim.wave
	var rank := 0
	if _persist:
		Save.clear_run()
		rank = Save.add_score(cleared, sim.coins, won)
	hud.show_end(won, "Waves cleared: %d / %d\nGold: %d%s" % [cleared, Level.WAVES.size(), sim.coins,
		"\nNew top-10 score: #%d" % rank if rank > 0 else ""])
	sfx.play("victory" if won else "defeat")


## Behind the title menu: a slow drift over the map.
var _menu_t := 0.0


func _menu_camera(delta: float) -> void:
	_menu_t += delta
	var target := Vector3(-3.0 + 4.0 * sin(_menu_t * 0.11), 0.0, 9.0 + 13.0 * sin(_menu_t * 0.07))
	var back := Vector3(0, sin(deg_to_rad(CAM_PITCH)), cos(deg_to_rad(CAM_PITCH))) * CAM_DIST * 1.25
	cam.position = target + back


func _keys() -> Vector2:
	var v := Vector2.ZERO
	if Input.is_key_pressed(KEY_A) or Input.is_key_pressed(KEY_LEFT): v.x -= 1
	if Input.is_key_pressed(KEY_D) or Input.is_key_pressed(KEY_RIGHT): v.x += 1
	if Input.is_key_pressed(KEY_W) or Input.is_key_pressed(KEY_UP): v.y -= 1
	if Input.is_key_pressed(KEY_S) or Input.is_key_pressed(KEY_DOWN): v.y += 1
	return v.normalized()


# --- build popup ------------------------------------------------------------------

## During an attack: the reach of the one tower the hero stands next to
## (nearest within RING_NEAR m), e.g. to see who a banner covers.
const RING_NEAR := 2.3


func _ring_near_hero() -> void:
	var best := RING_NEAR
	var r := 0.0
	var at := Vector3.ZERO
	if sim.state == "play":
		for b in sim.buildings.values():
			var st := Level.stats(b.kind, b.level)
			var dd := Vector2(b.pos.x - sim.hero_pos.x, b.pos.z - sim.hero_pos.z).length()
			if st.has("range") and dd < best:
				best = dd
				r = float(st.range)
				at = b.pos
	_range_ring.visible = r > 0.0
	_range_ring.position = at
	_range_ring.scale = Vector3(r, 1, r)


## Show the right popup for where the hero stands (build phase only).
func _sync_menu() -> void:
	if sim.state != "play" or sim.phase != "build":
		hud.show_countdown(0)
		hud.hide_menu()
		_ring_near_hero()
		return
	if sim.at_start_spot():
		_range_ring.visible = false
		var left := ceili(Level.START_COUNTDOWN - sim.start_t)
		if left != _count_seen:
			_count_seen = left
			sfx.play("ui_click", -4.0)
		hud.show_countdown(left)
		hud.show_menu("start%d" % left, "Wave %d of %d starts in %d" % [sim.wave + 1, Level.WAVES.size(), left],
			_preview_text(sim.wave) + "\nWalk off the pad to wait.", [])
		return
	_count_seen = -1
	hud.show_countdown(0)
	var spot := sim.spot_under_hero()
	if spot.is_empty():
		hud.hide_menu()
		_range_ring.visible = false
		return
	var b: Dictionary = sim.buildings.get(spot.id, {})
	var opts := []
	for o in sim.options(spot):
		var verb := "Upgrade to Lv %d" % (o.level + 1) if o.upgrade else String(o.name)
		opts.push_back({id = o.kind, text = "  %s   -   %d gold" % [verb, o.cost], ok = o.ok})
	var title := ""
	var desc := ""
	if b.is_empty():
		title = {tower = "Tower spot", eco = "Economy plot", gate = "Gate spot"}[spot.kind]
		desc = {tower = "Pick what to build.", eco = "Farm: steady gold. Bank: interest on the gold you save.",
			gate = String(Level.BUILDINGS.gate.desc)}[spot.kind]
	else:
		title = "%s  Lv %d" % [Level.BUILDINGS[b.kind].name, b.level + 1]
		desc = _stats_text(b.kind, b.level)
		if opts.is_empty():
			desc += "\nFully upgraded."
	hud.show_menu(spot.id, title, desc, opts)
	# Show the reach of what stands here.
	var r := 0.0
	if not b.is_empty() and Level.stats(b.kind, b.level).has("range"):
		r = float(Level.stats(b.kind, b.level).range)
	_range_ring.visible = r > 0.0
	_range_ring.position = spot.pos
	_range_ring.scale = Vector3(r, 1, r)


func _stats_text(kind: String, level: int) -> String:
	var st := Level.stats(kind, level)
	match kind:
		"archer", "ballista":
			return "Damage %s, every %.2fs, range %s" % [st.damage, st.interval, st.range]
		"mortar":
			return "Damage %s in %.1fm, every %.1fs, range %s-%s" % [st.damage, st.splash, st.interval, st.min_range, st.range]
		"frost":
			return "Slows walking and attacks %d%% for %.1fs, pulse every %.1fs, range %s" % [roundi(st.slow * 100), st.slow_time, st.interval, st.range]
		"banner":
			return "+%d%% attack speed for towers and the hero within %sm" % [roundi(st.buff * 100), st.range]
		"farm":
			return "+%d gold after every wave" % st.income
		"bank":
			return "+%d%% of your gold after every wave, up to %d (banks add up their caps)" % [
				roundi(Level.BANK_RATE * 100), st.cap]
		"gate":
			return "%d HP, repaired after each wave" % roundi(st.hp)
	return ""


func _preview_text(w: int) -> String:
	var lines := []
	var prev := Level.wave_preview(w)
	for ln in prev.size():
		var parts := []
		for k in prev[ln]:
			parts.push_back("%d %s" % [prev[ln][k], Level.ENEMIES[k].name + "s"])
		if not parts.is_empty():
			lines.push_back("%s: %s" % [Level.LANE_NAMES[ln], ", ".join(parts)])
	return "\n".join(lines)


func _on_menu_pick(id: String) -> void:
	var spot := sim.spot_under_hero()
	if not spot.is_empty() and sim.buy(spot.id, id):
		sfx.play("ui_click")
	else:
		sfx.play("ui_click", -10.0, 0.7)


# --- events -> effects and sound --------------------------------------------------------

func _apply_events() -> void:
	for e in sim.events:
		match String(e.type):
			"shot":
				sfx.play({hero = "hero_shot", archer = "arrow_shot", ballista = "ballista_shot",
					mortar = "mortar_shot"}[e.kind], -4.0 if e.kind == "archer" else 0.0)
				if e.kind == "ballista":
					for id in _built:
						var bv: Dictionary = _built[id]
						if bv.kind == "ballista" and Vector2(bv.root.position.x - e.from.x, bv.root.position.z - e.from.z).length() < 0.1:
							bv.reload = 0.35
			"hit":
				sfx.play("hit_flesh", -2.0)
			"boom":
				sfx.play("mortar_boom", -3.0)
				if not _fast_forwarding:
					_boom(e.pos, e.r)
			"pulse":
				sfx.play("frost_pulse", -8.0)
				if not _fast_forwarding:
					_pulse(e.pos, e.r)
			"kill":
				if _corpses.size() < CORPSE_CAP:
					var f: Vector3 = sim.tracks[e.lane].forward(e.d)
					_corpses.push_back({pos = e.pos, basis = Basis.looking_at(f, Vector3.UP), kind = e.kind, t = 0.0})
				if e.kind == Level.BRUTE:
					_shake = maxf(_shake, 0.25)
					sfx.play("brute_die")
				else:
					sfx.play("enemy_die", -4.0)
			"coin":
				sfx.play("coin_pickup", -4.0)
			"built":
				_on_built(e)
				sfx.play("build" if e.level == 0 else "upgrade")
				for k in mini(int(e.cost), 12):
					_flying_pay.push_back({a = sim.hero_pos + Vector3(0, 0.9, 0), b = e.spot.pos, t = -k * 0.03})
			"gate_broken":
				_shake = 0.4
				sfx.play("gate_break")
				hud.message("The %s gate fell!" % Level.LANE_NAMES[e.lane].to_lower(), 2.0)
			"wave_start":
				if _persist:
					Save.save_run(sim.checkpoint)
				sfx.play("wave_start", -4.0)
				hud.message("Wave %d!" % (e.wave + 1), 2.0)
			"wave_cleared":
				if sim.state == "play" and _persist:
					Save.save_run(sim.to_save())
				if sim.state == "play":
					sfx.play("wave_clear")
					var extra := "\n+%d gold from farms" % e.income if e.income > 0 else ""
					if int(e.get("interest", 0)) > 0:
						extra += "\n+%d gold interest" % e.interest
					hud.message("Wave %d cleared!%s" % [e.wave + 1, extra], 3.0)
			"base_hit":
				sfx.play("base_hit", -3.0)
				_shake = maxf(_shake, 0.15)


func _age_corpses(dt: float) -> void:
	var keep: Array[Dictionary] = []
	for c in _corpses:
		c.t += dt
		var clip: Array = _enemy[c.kind].clips.die
		var life: float = float(clip[1]) / float(clip[2]) + CORPSE_HOLD + CORPSE_SINK
		if c.t < life:
			keep.push_back(c)
	_corpses = keep


## A building went up or was upgraded: (re)make its model with a pop.
func _on_built(e: Dictionary) -> void:
	var spot: Dictionary = e.spot
	if _built.has(spot.id):
		(_built[spot.id].root as Node3D).queue_free()
	var got := Models.building(e.kind, e.level)
	var root := Node3D.new()
	root.add_child(got[0])
	if e.kind == "gate":
		var ln := int(spot.lane)
		var gd: float = sim.horde.gate_d[ln]
		var r: Vector3 = sim.tracks[ln].right(gd)
		root.transform = Transform3D(Basis(r, Vector3.UP, r.cross(Vector3.UP)), sim.tracks[ln].point(gd))
		if not _gate_fx.has(ln):
			var dust := _dust()
			dust.position = Vector3(0, 0.3, 0.6)
			_gate_fx[ln] = {dust = dust, prev = 1.0}
		else:
			(_gate_fx[ln].dust as Node).get_parent().remove_child(_gate_fx[ln].dust)
		root.add_child(_gate_fx[ln].dust)
	else:
		root.position = spot.pos
	add_child(root)
	# Level badge on the side facing the camera (at the gate: above its middle).
	var badge := Models.badge(e.level)
	root.add_child(badge)
	var box := Models.bounds(got[0])
	if e.kind == "gate":
		badge.global_position = root.global_position + Vector3(0, box.end.y + 0.35, 0)
	else:
		badge.global_position = root.global_position + Vector3(0, box.size.y * 0.42, box.end.z + 0.1)
	_built[spot.id] = {root = root, head = got[1], extra = got[2], kind = e.kind, level = e.level,
		reload = 0.0, broken = false, wall = got[0]}
	if e.kind != "gate":
		_pads[spot.id].node.visible = false
	if not _fast_forwarding:
		var final := root.scale
		root.scale = Vector3(final.x, 0.01, final.z)
		var tw := root.create_tween()
		tw.tween_property(root, "scale", final * Vector3(1.0, 1.15, 1.0), 0.22).set_trans(Tween.TRANS_QUAD)
		tw.tween_property(root, "scale", final, 0.12)
		_flash(root.position)
		_shake = maxf(_shake, 0.15)


## Dust kicked up while enemies hammer a gate (emitting toggled per frame).
func _dust() -> CPUParticles3D:
	var p := CPUParticles3D.new()
	p.amount = 24
	p.lifetime = 0.7
	p.emitting = false
	p.local_coords = false
	p.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	p.emission_box_extents = Vector3(1.6, 0.2, 0.2)
	p.direction = Vector3(0, 1, 0.6)
	p.spread = 35.0
	p.initial_velocity_min = 0.8
	p.initial_velocity_max = 2.0
	p.gravity = Vector3(0, -2.0, 0)
	p.scale_amount_min = 0.5
	p.scale_amount_max = 1.2
	var curve := Curve.new()
	curve.add_point(Vector2(0, 0.4))
	curve.add_point(Vector2(0.3, 1.0))
	curve.add_point(Vector2(1, 0.0))
	p.scale_amount_curve = curve
	var m := SphereMesh.new()
	m.radius = 0.12
	m.height = 0.24
	m.radial_segments = 6
	m.rings = 3
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.85, 0.76, 0.6)
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.material = mat
	p.mesh = m
	return p


## Mortar impact: a one-shot burst of dust the size of the splash.
func _boom(p: Vector3, r: float) -> void:
	var d := _dust()
	d.one_shot = true
	d.amount = 18
	d.explosiveness = 0.9
	d.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	d.emission_sphere_radius = r * 0.6
	d.direction = Vector3.UP
	d.spread = 70.0
	d.initial_velocity_min = 1.5
	d.initial_velocity_max = 3.5
	d.position = p + Vector3(0, 0.2, 0)
	add_child(d)
	d.emitting = true
	get_tree().create_timer(1.2).timeout.connect(d.queue_free)
	_shake = maxf(_shake, 0.08)


## Frost pulse: an icy ring growing to the crystal's reach and fading.
func _pulse(p: Vector3, r: float) -> void:
	var ring := _ring(1.0, Color(0.6, 0.9, 1.0, 0.7), 0.07)
	ring.position = p
	ring.scale = Vector3(0.3, 1, 0.3)
	add_child(ring)
	var m := ring.material_override as StandardMaterial3D
	var tw := ring.create_tween().set_parallel()
	tw.tween_property(ring, "scale", Vector3(r, 1, r), 0.45).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_property(m, "albedo_color:a", 0.0, 0.5)
	tw.chain().tween_callback(ring.queue_free)


## Golden pillar of light where something was just built.
func _flash(p: Vector3) -> void:
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	m.albedo_color = Color(1.0, 0.8, 0.3, 0.8)
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	var c := CylinderMesh.new()
	c.top_radius = 1.0
	c.bottom_radius = 1.1
	c.height = 4.0
	c.cap_top = false
	c.cap_bottom = false
	var mi := MeshInstance3D.new()
	mi.mesh = c
	mi.material_override = m
	mi.position = p + Vector3(0, 2.0, 0)
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mi)
	var tw := mi.create_tween().set_parallel()
	tw.tween_property(m, "albedo_color:a", 0.0, 0.7)
	tw.tween_property(mi, "scale", Vector3(0.3, 1.3, 0.3), 0.7)
	tw.chain().tween_callback(mi.queue_free)


# --- per-frame drawing ---------------------------------------------------------------

var _prof := {}  # --bench: microseconds per section


func _t(name: String, t0: int) -> int:
	var now := Time.get_ticks_usec()
	_prof[name] = int(_prof.get(name, 0)) + now - t0
	return now


func _sync_view(delta: float) -> void:
	var t0 := Time.get_ticks_usec()
	_sync_hero(delta)
	t0 = _t("hero", t0)
	_draw_enemies()
	t0 = _t("enemies", t0)
	_draw_drops()
	_draw_projectiles()
	_draw_pay(delta)
	t0 = _t("drops/proj/pay", t0)
	_sync_buildings(delta)
	_sync_phase()
	t0 = _t("buildings/phase", t0)

	# Camera: follow the hero.
	_cam_target = _cam_target.lerp(_cam_goal(), minf(1.0, delta * 4.0) if delta > 0 else 1.0)
	_shake = maxf(_shake - delta, 0.0)
	var jitter := Vector3(randf_range(-1, 1), 0, randf_range(-1, 1)) * _shake * 0.5
	var back := Vector3(0, sin(deg_to_rad(CAM_PITCH)), cos(deg_to_rad(CAM_PITCH))) * CAM_DIST * _zoom
	cam.position = _cam_target + back + jitter

	_sync_gates()
	_sync_enemy_bars()
	t0 = _t("gates/bars", t0)
	_sync_menu()
	hud.set_coins(sim.coins)
	hud.set_base(float(sim.base_hp) / Level.BASE_HP)
	_t("menu/hud", t0)


func _cam_goal() -> Vector3:
	if _args.get("cam") == "gate":
		for ln in Level.LANES.size():
			if sim.horde.gate_d[ln] >= 0.0:
				return sim.tracks[ln].point(sim.horde.gate_d[ln] - 1.5)
	if _args.has("cam") and _args.cam != "gate":
		var xz := String(_args.cam).split(",")
		return Vector3(float(xz[0]), 0.0, float(xz[1]))
	# Follow the hero 1:1 sideways, stopping a few metres inside the map's
	# edges (the westmost spots used to sit at the screen edge). A build
	# popup covers the bottom third: look further down so the hero stands
	# above it.
	var p := sim.hero_prev.lerp(sim.hero_pos, _alpha)
	var lift := CAM_POPUP_LIFT if hud.menu_open() else 0.0
	return Vector3(clampf(p.x, Level.BOUNDS.position.x + 4.0, Level.BOUNDS.end.x - 4.0), 0.0,
		clampf(p.z + 1.0 + lift, -9.0, 27.0 + lift))


## Phase line, lane previews and pads that only show while building.
func _sync_phase() -> void:
	var building := sim.phase == "build" and sim.state == "play"
	if sim.state == "play":
		var left := sim.horde.count()
		hud.set_phase("WAVE %d/%d  -  %s" % [mini(sim.wave + 1, Level.WAVES.size()), Level.WAVES.size(),
			"BUILD" if building else "ATTACK  (%d)" % left])
	var key := "%s%d" % [sim.phase, sim.wave]
	if key == _phase_seen:
		return
	_phase_seen = key
	_start_pad.visible = building
	if building and sim.wave < Level.WAVES.size():
		var prev := Level.wave_preview(sim.wave)
		for ln in _lane_labels.size():
			var parts := []
			for k in prev[ln]:
				parts.push_back("%d %s" % [prev[ln][k], Level.ENEMIES[k].name])
			_lane_labels[ln].text = "\n".join(parts)
			_lane_labels[ln].visible = not parts.is_empty()
	else:
		for l in _lane_labels:
			l.visible = false
	for id in _pads:
		var b: Dictionary = sim.buildings.get(id, {})
		_pads[id].node.visible = building and (b.is_empty() or b.kind == "gate")
		if _pads[id].ghost:
			_pads[id].ghost.visible = building and b.is_empty()


func _sync_hero(delta: float) -> void:
	# Stand on top of a build pad, not in it.
	var on_pad := 0.0
	for s in Level.SPOTS:
		var q: Vector3 = s.pos
		if _pads[s.id].node.visible and absf(sim.hero_pos.x - q.x) < Level.PAD_SIZE * 0.5 \
				and absf(sim.hero_pos.z - q.z) < Level.PAD_SIZE * 0.5:
			on_pad = PAD_TOP
	_hero.position = sim.hero_prev.lerp(sim.hero_pos, _alpha) + Vector3(0, on_pad, 0)
	var vel := sim.hero_vel
	vel.y = 0.0
	var speed := vel.length()
	var moving := speed > 0.5
	var shooting := sim.hero_aim_t < 0.45 and sim.hero_aim != Vector3.ZERO
	# Face the target while shooting (even on the move), else the way we go.
	var face := sim.hero_aim if shooting else (vel if moving else Vector3.ZERO)
	face.y = 0.0
	var k := minf(1.0, delta * 14.0) if delta > 0 else 1.0
	if face.length() > 0.1:
		_hero_model.rotation.y = lerp_angle(_hero_model.rotation.y, atan2(-face.x, -face.z), k)
	# Legs: the move direction in the hero's own frame (x right, y forward).
	var legs := Vector2.ZERO
	if moving:
		var yaw := _hero_model.rotation.y
		var fwd := Vector3(-sin(yaw), 0, -cos(yaw))
		var right := Vector3(-fwd.z, 0, fwd.x)
		var dir := vel / speed
		legs = Vector2(dir.dot(right), dir.dot(fwd)) * clampf(speed / float(Level.HERO.speed), 0.0, 1.0)
	var cur: Vector2 = _hero_tree.get("parameters/legs/blend_position")
	_hero_tree.set("parameters/legs/blend_position", cur.lerp(legs, k))
	_hero_shoot = move_toward(_hero_shoot, 1.0 if shooting else 0.0, delta * 6.0 if delta > 0 else 1.0)
	_hero_tree.set("parameters/upper/blend_amount", _hero_shoot)
	# No enemy in reach (no shot for a while): run with the crossbow carried,
	# not aimed. Standing still keeps the ready pose either way.
	var combat := sim.hero_aim_t < 0.8 and sim.hero_aim != Vector3.ZERO
	var relax := 0.0 if combat else clampf(speed / float(Level.HERO.speed), 0.0, 1.0)
	_hero_relax = move_toward(_hero_relax, relax, delta * 5.0 if delta > 0 else 1.0)
	_hero_tree.set("parameters/mix/blend_amount", 1.0 - _hero_relax)
	_hero_bow.rotation_degrees.x = _hero_bow_x + Models.HERO_CARRY_PITCH * _hero_relax


func _draw_enemies() -> void:
	var h := sim.horde
	var counts := [0, 0, 0, 0]
	for i in h.count():
		var k := h.kind[i]
		var en: Dictionary = _enemy[k]
		var n: int = counts[k]
		if n >= en.mm.instance_count:
			continue
		counts[k] = n + 1
		var p := h.pos[i]
		var ph := h.phase[i]
		if i < h.prev_pos.size():
			p = h.prev_pos[i].lerp(p, _alpha)
			ph = lerpf(h.prev_phase[i], ph, _alpha)
		var clip: Array = en.clips.walk
		var cycle := fposmod(ph / TAU, 1.0)
		if h.blocked[i] == 1:
			clip = en.clips.attack
		elif h.blocked[i] == 2:
			clip = en.clips.idle
			cycle = fposmod(ph / TAU * 0.4, 1.0)
		var frame := cycle * float(clip[1])
		var b := Basis.looking_at(h.forward(i), Vector3.UP).scaled(Vector3.ONE * float(en.scale))
		var col := Color(1.7, 1.7, 1.7) if h.flash[i] > 0.0 else (Color(0.7, 0.85, 1.25) if h.slow[i] > 0.0 else Color.WHITE)
		_put(en.buf, n, Transform3D(b, p), col, clip, frame)
	for c in _corpses:
		var k: int = c.kind
		var en: Dictionary = _enemy[k]
		var n: int = counts[k]
		if n >= en.mm.instance_count:
			continue
		counts[k] = n + 1
		var clip: Array = en.clips.die
		var clip_len := float(clip[1]) / float(clip[2])
		var frame := minf(c.t * float(clip[2]), float(clip[1]) - 1.0)
		var sink := maxf(0.0, c.t - clip_len - CORPSE_HOLD) / CORPSE_SINK
		var p: Vector3 = c.pos - Vector3(0, sink * (1.2 if k == Level.BRUTE else 0.6), 0)
		_put(en.buf, n, Transform3D((c.basis as Basis).scaled(Vector3.ONE * float(en.scale)), p), Color.WHITE, clip, frame)
	for k in _enemy.size():
		_enemy[k].mm.buffer = _enemy[k].buf
		_enemy[k].mm.visible_instance_count = counts[k]


## Write instance `i`: transform, colour and VAT custom data
## (clip start, clip frames, frame position, loops).
func _put(buf: PackedFloat32Array, i: int, xf: Transform3D, col: Color, clip: Array, frame: float) -> void:
	var o := i * STRIDE
	var b := xf.basis
	buf[o] = b.x.x; buf[o + 1] = b.y.x; buf[o + 2] = b.z.x; buf[o + 3] = xf.origin.x
	buf[o + 4] = b.x.y; buf[o + 5] = b.y.y; buf[o + 6] = b.z.y; buf[o + 7] = xf.origin.y
	buf[o + 8] = b.x.z; buf[o + 9] = b.y.z; buf[o + 10] = b.z.z; buf[o + 11] = xf.origin.z
	buf[o + 12] = col.r; buf[o + 13] = col.g; buf[o + 14] = col.b; buf[o + 15] = col.a
	buf[o + 16] = float(clip[0]); buf[o + 17] = float(clip[1]); buf[o + 18] = frame
	buf[o + 19] = 1.0 if clip[3] else 0.0


## Plain transform-only instance (12 floats).
func _put12(buf: PackedFloat32Array, i: int, xf: Transform3D) -> void:
	var o := i * 12
	var b := xf.basis
	buf[o] = b.x.x; buf[o + 1] = b.y.x; buf[o + 2] = b.z.x; buf[o + 3] = xf.origin.x
	buf[o + 4] = b.x.y; buf[o + 5] = b.y.y; buf[o + 6] = b.z.y; buf[o + 7] = xf.origin.y
	buf[o + 8] = b.x.z; buf[o + 9] = b.y.z; buf[o + 10] = b.z.z; buf[o + 11] = xf.origin.z


func _draw_drops() -> void:
	var n := [0, 0, 0]
	for k in 3:
		if _drop_buf[k].size() != _drop_mm[k].instance_count * 12:
			_drop_buf[k].resize(_drop_mm[k].instance_count * 12)
	var t := sim.time
	for i in sim.drop_pos.size():
		var v := sim.drop_val[i]
		var k := 2 if v >= DROP_TIERS[2] else (1 if v >= DROP_TIERS[1] else 0)
		if n[k] >= _drop_mm[k].instance_count:
			continue
		var flying := sim.drop_fly[i] >= 0.0
		var spin := float(i) * 2.399 + t * 2.5
		var bob := 0.0 if flying else 0.06 + 0.05 * sin(t * 3.0 + float(i))
		var xf: Transform3D
		match k:
			0:  # a coin, face tilted up toward the camera, wobbling round
				var b := Basis(Vector3.RIGHT, 0.45) * Basis(Vector3.UP, spin)
				xf = Transform3D(b.scaled(Vector3.ONE * 0.95), sim.drop_pos[i] + Vector3(0, 0.12 + bob, 0))
			1:
				xf = Transform3D(Basis(Vector3.UP, spin * 0.4).scaled(Vector3.ONE * 0.55), sim.drop_pos[i] + Vector3(0, bob, 0))
			2:
				xf = Transform3D(Basis(Vector3.UP, spin * 0.4).scaled(Vector3.ONE * 1.3), sim.drop_pos[i] + Vector3(0, bob, 0))
		_put12(_drop_buf[k], n[k], xf)
		n[k] += 1
	for k in 3:
		_drop_mm[k].buffer = _drop_buf[k]
		_drop_mm[k].visible_instance_count = n[k]


## Arrows, crossbow bolts and ballista bolts share the arrow mesh (scaled);
## mortar shells are boulders. Each points along its flight.
func _draw_projectiles() -> void:
	if _arrow_buf.size() != _arrow_mm.instance_count * 12:
		_arrow_buf.resize(_arrow_mm.instance_count * 12)
		_rock_buf.resize(_rock_mm.instance_count * 12)
	var na := 0
	var nr := 0
	for p in sim.projectiles:
		var pt := float(p.t) - (1.0 - _alpha) * DT  # between sim steps, like the crowd
		var at := Sim.proj_pos(p, pt)
		if p.kind == "shell":
			if nr < _rock_mm.instance_count:
				var spin := Basis(Vector3(1, 0.3, 0).normalized(), float(p.t) * 9.0).scaled(Vector3.ONE * 1.3)
				_put12(_rock_buf, nr, Transform3D(spin, at))
				nr += 1
			continue
		if na >= _arrow_mm.instance_count:
			continue
		var ahead := Sim.proj_pos(p, pt + 0.02)
		var dir := ahead - at
		if dir.length() < 0.0001:
			dir = (p.to as Vector3) - (p.from as Vector3)
		var s: float = {bolt = 1.2, arrow = 1.5, ballista = 2.6}[p.kind]
		var basis := Basis.looking_at(dir.normalized(), Vector3.UP).scaled(Vector3.ONE * s)
		_put12(_arrow_buf, na, Transform3D(basis, at))
		na += 1
	_arrow_mm.buffer = _arrow_buf
	_arrow_mm.visible_instance_count = na
	_rock_mm.buffer = _rock_buf
	_rock_mm.visible_instance_count = nr


func _draw_pay(delta: float) -> void:
	if _pay_buf.size() != _pay_mm.instance_count * 12:
		_pay_buf.resize(_pay_mm.instance_count * 12)
	var n := 0
	var keep: Array[Dictionary] = []
	for c in _flying_pay:
		c.t += delta / 0.3
		if c.t >= 1.0:
			sfx.play("coin_pay", -6.0)
			continue
		keep.push_back(c)
		if c.t < 0.0 or n >= _pay_mm.instance_count:
			continue
		var p: Vector3 = (c.a as Vector3).lerp(c.b, c.t)
		p.y += sin(c.t * PI) * 1.2
		var b := Basis(Vector3.UP, c.t * 9.0) * Basis(Vector3.RIGHT, 1.2)
		_put12(_pay_buf, n, Transform3D(b.scaled(Vector3.ONE * 1.0), p))
		n += 1
	_flying_pay = keep
	_pay_mm.buffer = _pay_buf
	_pay_mm.visible_instance_count = n


## Turn tower heads to their aim, spin the windmills and frost crystals,
## hide a ballista's bolt while it reloads.
func _sync_buildings(delta: float) -> void:
	for id in _built:
		var bv: Dictionary = _built[id]
		var b: Dictionary = sim.buildings.get(id, {})
		if b.is_empty():
			continue
		match String(bv.kind):
			"ballista":
				bv.head.rotation.y = atan2(b.aim.x, b.aim.z)
				bv.reload = maxf(bv.reload - delta, 0.0)
				if bv.extra:
					bv.extra.visible = bv.reload <= 0.0
			"mortar":
				bv.head.rotation.y = atan2(b.aim.x, b.aim.z)
			"frost":
				bv.head.rotation.y += delta * 0.8
			"farm":
				if bv.extra:
					bv.extra.rotation.z += delta * 1.5


## Gates: HP bars, dust and shudder while hit, fall when broken, stand
## again when repaired after the wave.
func _sync_gates() -> void:
	var bars := []
	for id in _built:
		var bv: Dictionary = _built[id]
		if bv.kind != "gate":
			continue
		var b: Dictionary = sim.buildings[id]
		var ln := int(b.spot.lane)
		var fx: Dictionary = _gate_fx[ln]
		if b.broken != bv.broken:
			bv.broken = b.broken
			var root: Node3D = bv.root
			var tw := root.create_tween()
			if b.broken:
				tw.tween_property(root, "scale", Vector3(1.1, 0.05, 1.1), 0.35).set_trans(Tween.TRANS_QUAD)
			else:
				tw.tween_property(root, "scale", Vector3.ONE, 0.3).set_trans(Tween.TRANS_BACK)
		if b.broken:
			fx.dust.emitting = false
			continue
		var frac := sim.gate_hp_frac(ln)
		var hit: bool = frac < float(fx.prev) - 0.00001
		fx.prev = frac
		fx.dust.emitting = hit
		if hit:
			sfx.play("gate_hit", -4.0)
		(bv.wall as Node3D).position = Vector3(randf_range(-1, 1) * 0.03, 0, randf_range(-1, 1) * 0.03) if hit else Vector3.ZERO
		var top: Vector3 = (bv.root as Node3D).position + Vector3(0, 2.6, 0)
		if not cam.is_position_behind(top):
			bars.push_back([cam.unproject_position(top), frac])
	hud.set_gate_bars(bars)


## Red HP bars over the giants (not the small fry: too many, too busy).
func _sync_enemy_bars() -> void:
	var bars: Array = []
	var h := sim.horde
	for i in h.count():
		if h.kind[i] != Level.BRUTE or h.hp[i] <= 0.0:
			continue
		var top := h.pos[i] + Vector3(0, 2.75, 0)
		if not cam.is_position_behind(top):
			bars.push_back([cam.unproject_position(top), h.hp[i] / h.max_hp[i]])
	hud.set_enemy_bars(bars)


## A build spot: dark green pad with a dashed border and its kind written on.
func _make_pad(spot: Dictionary) -> Dictionary:
	var s := Level.PAD_SIZE
	var node := Node3D.new()
	node.position = spot.pos + Vector3(0, 0.04, 0)
	add_child(node)
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var tint: Color = {tower = Color(0.1, 0.38, 0.28), eco = Color(0.42, 0.34, 0.16), gate = Color(0.3, 0.3, 0.36)}[spot.kind]
	World.box(st, Vector3(0, 0, 0), Vector3(s * 0.5, 0.02, s * 0.5), tint)
	# Dashed white border: 5 dashes per side.
	var e := s * 0.5 - 0.06
	var white := Color(0.95, 0.97, 0.95)
	for k in 5:
		var along := s * 0.5 * ((k + 0.5) / 5.0 * 2.0 - 1.0)
		World.box(st, Vector3(along, 0.03, e), Vector3(s * 0.06, 0.01, 0.035), white)
		World.box(st, Vector3(along, 0.03, -e), Vector3(s * 0.06, 0.01, 0.035), white)
		World.box(st, Vector3(e, 0.03, along), Vector3(0.035, 0.01, s * 0.06), white)
		World.box(st, Vector3(-e, 0.03, along), Vector3(0.035, 0.01, s * 0.06), white)
	var base := MeshInstance3D.new()
	base.mesh = st.commit()
	base.material_override = World.vertex_material()
	base.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	node.add_child(base)
	var label := Label3D.new()
	label.text = {tower = "TOWER", eco = "GOLD", gate = "GATE"}[spot.kind]
	label.font_size = 48
	label.outline_size = 12
	label.pixel_size = 0.009
	label.outline_modulate = Color(0.05, 0.15, 0.1)
	label.rotation_degrees = Vector3(-90, 0, 0)
	label.position = Vector3(0, 0.08, 0)
	node.add_child(label)
	var ghost: Node3D = null
	if spot.kind == "gate":
		ghost = _ghost_gate(spot)
	return {node = node, label = label, ghost = ghost}


## See-through gate standing across its lane where it would be built, with
## a strip linking it to the pad: which lane a gate pad is for is obvious.
func _ghost_gate(spot: Dictionary) -> Node3D:
	var ln := int(spot.lane)
	var t: Track = sim.tracks[ln]
	var gd := t.closest_d(spot.pos)
	var r := t.right(gd)
	var root := Node3D.new()
	var g := Models.gate((Level.ROAD_HALF_WIDTH + 0.7) * 2.0)
	root.add_child(g)
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(0.55, 0.85, 1.0, 0.35)
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	for mi in g.find_children("*", "MeshInstance3D", true, false):
		(mi as MeshInstance3D).material_override = m
		(mi as MeshInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.transform = Transform3D(Basis(r, Vector3.UP, r.cross(Vector3.UP)), t.point(gd))
	add_child(root)
	# Dotted strip from the pad to the ghost.
	var a: Vector3 = spot.pos
	var b := t.point(gd)
	var n := int(a.distance_to(b) / 0.45)
	for i in range(1, n):
		var dot := MeshInstance3D.new()
		var q := BoxMesh.new()
		q.size = Vector3(0.18, 0.02, 0.18)
		dot.mesh = q
		dot.material_override = m
		dot.position = a.lerp(b, float(i) / n) + Vector3(0, 0.05, 0) - root.position
		dot.position = root.transform.basis.inverse() * dot.position
		root.add_child(dot)
	return root


## The start spot by the keep: a flag on a pad, shown while building.
func _make_start_pad() -> Node3D:
	var node := Node3D.new()
	node.position = Level.START_SPOT + Vector3(0, 0.04, 0)
	add_child(node)
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	World.box(st, Vector3.ZERO, Vector3(0.8, 0.02, 0.8), Color(0.55, 0.12, 0.1))
	var base := MeshInstance3D.new()
	base.mesh = st.commit()
	base.material_override = World.vertex_material()
	node.add_child(base)
	var flag: Node3D = Models.scene(Models.HEX + "flag_blue.gltf").instantiate()
	flag.scale = Vector3.ONE * 6.0
	flag.position = Vector3(0.55, 0, -0.55)
	node.add_child(flag)
	var label := Label3D.new()
	label.text = "START"
	label.font_size = 44
	label.outline_size = 12
	label.pixel_size = 0.009
	label.rotation_degrees = Vector3(-90, 0, 0)
	label.position = Vector3(0, 0.08, 0.1)
	node.add_child(label)
	return node


# --- screenshots and benchmarks --------------------------------------------------------

func _tick_tools(delta: float) -> void:
	_frames.push_back(delta)
	hud.tick_fps(delta)
	if _shot_t >= 0.0:
		_shot_t -= delta
		if _shot_t < 0.0:
			var img := get_viewport().get_texture().get_image()
			img.save_png(String(_args.shot))
			print("[shot] %s  t=%.1f wave=%d %s enemies=%d coins=%d projectiles=%d menu=%s" % [_args.shot, sim.time,
				sim.wave + 1, sim.phase, sim.horde.count(), sim.coins, sim.projectiles.size(), hud._menu.visible])
			get_tree().quit()
	if _bench_t >= 0.0:
		_bench_t -= delta
		if _bench_t < 0.0:
			var f := _frames.slice(30)
			f.sort()
			var sum := 0.0
			for x in f:
				sum += x
			var parts := []
			for k in _prof:
				parts.push_back("%s=%.2fms" % [k, _prof[k] / 1000.0 / _frames.size()])
			print("[prof] per frame: ", ", ".join(parts))
			print("[render] draw_calls=%d objects=%d primitives=%d nodes=%d vram=%dMB process=%.1fms" % [
				Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME),
				Performance.get_monitor(Performance.RENDER_TOTAL_OBJECTS_IN_FRAME),
				Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME),
				Performance.get_monitor(Performance.OBJECT_NODE_COUNT),
				Performance.get_monitor(Performance.RENDER_VIDEO_MEM_USED) / 1048576,
				Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0])
			print("[bench] frames=%d avg=%.1f fps  p99 frame=%.1f ms  enemies=%d corpses=%d" % [
				f.size(), f.size() / sum, f[int(f.size() * 0.99)] * 1000.0, sim.horde.count(), _corpses.size()])
			get_tree().quit()
