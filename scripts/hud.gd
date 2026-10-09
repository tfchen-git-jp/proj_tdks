class_name Hud
extends CanvasLayer
## Coin counter, keep HP bar, wave / phase line, floating joystick, the
## build popup, HP bars over gates and giants, messages and the end screen. The joystick reads touch events only: on PC, Godot turns
## mouse clicks into touches (input_devices/pointing/emulate_touch_from_mouse),
## so the phone and PC run the same code path.

signal restart
signal to_menu
## A build-popup button was tapped (its option id).
signal menu_pick(id: String)
signal menu_opened

const JOY_RADIUS := 90.0

var move := Vector2.ZERO  # joystick, length <= 1, screen axes (y down)

var _root: Control
var _coin_label: Label
var _hp_fill: ColorRect
var _msg: Label
var _count: Label  # the big start-pad countdown digit
var _count_n := 0
var _count_pop := 0.0
var _msg_t := 0.0
var _end: Control
var _end_info: Label
var _end_label: Label
var _joy: Control
var _touch := -1
var _origin := Vector2.ZERO
var _knob := Vector2.ZERO
var _coins_shown := 0.0
var _pulse := 0.0
var _fps_label: Label
var _fps_t := 0.0
var _fps_n := 0
var _gate_bars: Array[ColorRect] = []  # pooled; blue fill is child 0
var _enemy_bars: Array[ColorRect] = []  # pooled; red fill is child 0
var minimap: Minimap
var _phase_label: Label
var _menu: PanelContainer
var _menu_title: Label
var _menu_desc: Label
var _menu_list: VBoxContainer
var _menu_key := ""


func _ready() -> void:
	_root = Control.new()
	_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_root)
	var top := _safe_top()

	# Coin pill, top right.
	var pill := PanelContainer.new()
	pill.add_theme_stylebox_override("panel", _box(Color(0.1, 0.1, 0.12, 0.75), 30, Color(1, 1, 1, 0.9), 3))
	pill.anchor_left = 1.0
	pill.anchor_right = 1.0
	pill.offset_left = -200
	pill.offset_right = -18
	pill.offset_top = top + 14
	pill.offset_bottom = top + 74
	_root.add_child(pill)
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_END
	row.add_theme_constant_override("separation", 10)
	pill.add_child(row)
	_coin_label = _label("0", 40)
	_coin_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_coin_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(_coin_label)
	var coin := Panel.new()
	coin.custom_minimum_size = Vector2(40, 40)
	coin.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	coin.add_theme_stylebox_override("panel", _box(Color(1.0, 0.78, 0.18), 20, Color(0.75, 0.5, 0.05), 4))
	row.add_child(coin)

	# Lodge HP, top left.
	var hp_back := ColorRect.new()
	hp_back.color = Color(0.1, 0.1, 0.12, 0.75)
	hp_back.position = Vector2(20, top + 30)
	hp_back.size = Vector2(220, 28)
	_root.add_child(hp_back)
	_hp_fill = ColorRect.new()
	_hp_fill.color = Color(0.35, 0.85, 0.35)
	_hp_fill.position = Vector2(4, 4)
	_hp_fill.size = Vector2(212, 20)
	hp_back.add_child(_hp_fill)
	var hp_label := _label("KEEP", 18)
	hp_label.position = Vector2(20, top + 4)
	_root.add_child(hp_label)

	# FPS, top centre (always on: the phone is judged by it).
	_fps_label = _label("-- FPS", 22)
	_fps_label.anchor_left = 0.5
	_fps_label.anchor_right = 0.5
	_fps_label.offset_left = -80
	_fps_label.offset_right = 80
	_fps_label.offset_top = top + 8
	_fps_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_root.add_child(_fps_label)

	# Build version, bottom left: which build is on the phone.
	var ver := _label("v" + str(ProjectSettings.get_setting("application/config/version", "?")), 16)
	ver.anchor_top = 1.0
	ver.anchor_bottom = 1.0
	ver.offset_left = 10
	ver.offset_top = -30
	ver.modulate = Color(1, 1, 1, 0.6)
	_root.add_child(ver)

	# Wave and phase, under the FPS.
	_phase_label = _label("", 26)
	_phase_label.anchor_left = 0.5
	_phase_label.anchor_right = 0.5
	_phase_label.offset_left = -200
	_phase_label.offset_right = 200
	_phase_label.offset_top = top + 84  # below the keep bar and coin pill
	_phase_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_root.add_child(_phase_label)

	# Minimap, bottom right (hidden while a popup is up).
	minimap = Minimap.new()
	minimap.anchor_left = 1.0
	minimap.anchor_right = 1.0
	minimap.anchor_top = 1.0
	minimap.anchor_bottom = 1.0
	minimap.offset_left = -minimap.size.x - 14
	minimap.offset_right = -14
	minimap.offset_top = -minimap.size.y - 40
	minimap.offset_bottom = -40
	_root.add_child(minimap)

	# Build popup, bottom of the screen (shown while standing on a spot).
	_menu = PanelContainer.new()
	_menu.add_theme_stylebox_override("panel", _box(Color(0.08, 0.09, 0.11, 0.9), 22, Color(1, 1, 1, 0.8), 3))
	_menu.anchor_left = 0.0
	_menu.anchor_right = 1.0
	_menu.anchor_top = 1.0
	_menu.anchor_bottom = 1.0
	_menu.offset_left = 24
	_menu.offset_right = -24
	_menu.offset_bottom = -60
	_menu.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_menu.visible = false
	_root.add_child(_menu)
	var mbox := VBoxContainer.new()
	mbox.add_theme_constant_override("separation", 10)
	_menu.add_child(mbox)
	_menu_title = _label("", 34)
	_menu_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	mbox.add_child(_menu_title)
	_menu_desc = _label("", 22)
	_menu_desc.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_menu_desc.autowrap_mode = TextServer.AUTOWRAP_WORD
	_menu_desc.modulate = Color(1, 1, 1, 0.8)
	mbox.add_child(_menu_desc)
	_menu_list = VBoxContainer.new()
	_menu_list.add_theme_constant_override("separation", 8)
	mbox.add_child(_menu_list)

	_msg = _label("", 44)
	_msg.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	_msg.anchor_left = 0.0
	_msg.anchor_right = 1.0
	_msg.offset_left = 0
	_msg.offset_right = 0
	_msg.offset_top = top + 150
	_msg.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_msg.autowrap_mode = TextServer.AUTOWRAP_WORD
	_root.add_child(_msg)

	# Start-pad countdown: one huge digit across the screen (font size set
	# from the screen height when shown).
	_count = _label("", 100)
	_count.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_count.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_count.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_count.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_count.visible = false
	_root.add_child(_count)
	_root.move_child(_count, 0)  # behind the popup and the rest of the HUD

	_joy = Control.new()
	_joy.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_joy.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_joy.draw.connect(_draw_joy)
	_root.add_child(_joy)

	_end = ColorRect.new()
	(_end as ColorRect).color = Color(0, 0, 0, 0.55)
	_end.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_end.visible = false
	_root.add_child(_end)
	var box := VBoxContainer.new()
	box.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_theme_constant_override("separation", 40)
	box.grow_horizontal = Control.GROW_DIRECTION_BOTH
	box.grow_vertical = Control.GROW_DIRECTION_BOTH
	_end.add_child(box)
	_end_label = _label("", 72)
	_end_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(_end_label)
	_end_info = _label("", 32)
	_end_info.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(_end_info)
	var again := Button.new()
	again.text = "  Play again  "
	again.add_theme_font_size_override("font_size", 44)
	again.add_theme_stylebox_override("normal", _box(Color(0.2, 0.65, 0.3), 18, Color.WHITE, 4))
	again.add_theme_stylebox_override("hover", _box(Color(0.25, 0.75, 0.35), 18, Color.WHITE, 4))
	again.add_theme_stylebox_override("pressed", _box(Color(0.15, 0.5, 0.25), 18, Color.WHITE, 4))
	again.pressed.connect(func() -> void: restart.emit())
	box.add_child(again)
	var home := Button.new()
	home.text = "  Main menu  "
	home.add_theme_font_size_override("font_size", 36)
	home.add_theme_stylebox_override("normal", _box(Color(0.3, 0.32, 0.38), 18, Color(1, 1, 1, 0.8), 3))
	home.add_theme_stylebox_override("hover", _box(Color(0.38, 0.4, 0.46), 18, Color.WHITE, 3))
	home.add_theme_stylebox_override("pressed", _box(Color(0.22, 0.24, 0.3), 18, Color.WHITE, 3))
	home.pressed.connect(func() -> void: to_menu.emit())
	box.add_child(home)


## Top inset for the status bar / camera notch on phones (0 on PC).
func _safe_top() -> float:
	var safe := DisplayServer.get_display_safe_area()
	var screen := DisplayServer.screen_get_size()
	if not OS.has_feature("mobile") or screen.y <= 0:
		return 0.0
	var vp := get_viewport().get_visible_rect().size
	return safe.position.y * vp.y / screen.y


func _label(text: String, size: int) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	l.add_theme_constant_override("outline_size", size / 5)
	return l


func _box(fill: Color, radius: int, border: Color, bw: int) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = fill
	s.set_corner_radius_all(radius)
	s.border_color = border
	s.set_border_width_all(bw)
	s.content_margin_left = 16
	s.content_margin_right = 12
	s.content_margin_top = 6
	s.content_margin_bottom = 6
	return s


func _input(event: InputEvent) -> void:
	if _end.visible:
		return
	if event is InputEventScreenTouch:
		var t := event as InputEventScreenTouch
		# Taps on the popup are for its buttons, not the joystick.
		if t.pressed and _menu.visible and _menu.get_global_rect().has_point(t.position):
			return
		if t.pressed and _touch == -1:
			_touch = t.index
			_origin = t.position
			_knob = t.position
		elif not t.pressed and t.index == _touch:
			_touch = -1
		_update_move()
	elif event is InputEventScreenDrag:
		var g := event as InputEventScreenDrag
		if g.index == _touch:
			_knob = g.position
			_update_move()


func _update_move() -> void:
	if _touch == -1:
		move = Vector2.ZERO
	else:
		var v := (_knob - _origin) / JOY_RADIUS
		move = v.limit_length(1.0)
		if move.length() < 0.12:
			move = Vector2.ZERO
	_joy.queue_redraw()


func _draw_joy() -> void:
	if _touch == -1:
		return
	_joy.draw_circle(_origin, JOY_RADIUS, Color(1, 1, 1, 0.12))
	_joy.draw_arc(_origin, JOY_RADIUS, 0, TAU, 48, Color(1, 1, 1, 0.5), 3.0, true)
	_joy.draw_circle(_origin + move * JOY_RADIUS, 34, Color(1, 1, 1, 0.75))


func set_coins(n: int) -> void:
	if n > _coins_shown:
		_pulse = 0.15
	_coins_shown = n
	_coin_label.text = str(n)


func set_base(frac: float) -> void:
	_hp_fill.size.x = 212.0 * clampf(frac, 0.0, 1.0)
	_hp_fill.color = Color(0.35, 0.85, 0.35) if frac > 0.5 else (Color(0.95, 0.75, 0.2) if frac > 0.25 else Color(0.95, 0.25, 0.2))


## Count frames; refresh the FPS readout twice a second.
func tick_fps(delta: float) -> void:
	_fps_t += delta
	_fps_n += 1
	if _fps_t >= 0.5:
		var fps := _fps_n / _fps_t
		_fps_label.text = "%d FPS" % roundi(fps)
		_fps_label.modulate = Color(0.6, 1.0, 0.6) if fps >= 55 else (Color(1.0, 0.9, 0.4) if fps >= 40 else Color(1.0, 0.45, 0.4))
		_fps_t = 0.0
		_fps_n = 0


## Blue HP bars over standing gates: [[screen position, frac], ...].
func set_gate_bars(bars: Array) -> void:
	_bars(_gate_bars, bars, Vector2(130, 18), Color(0.35, 0.75, 1.0), true)


## Red HP bars over enemies (giants only): [[screen position, frac], ...].
func set_enemy_bars(bars: Array) -> void:
	_bars(_enemy_bars, bars, Vector2(84, 12), Color(0.92, 0.18, 0.15), false)


func _bars(pool: Array[ColorRect], bars: Array, size: Vector2, col: Color, warn: bool) -> void:
	while pool.size() < bars.size():
		var back := ColorRect.new()
		back.color = Color(0.08, 0.06, 0.06, 0.8)
		back.size = size
		back.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var fill := ColorRect.new()
		fill.color = col
		fill.position = Vector2(3, 3)
		fill.size = size - Vector2(6, 6)
		back.add_child(fill)
		_root.add_child(back)
		_root.move_child(back, 0)  # under the rest of the HUD
		pool.push_back(back)
	for i in pool.size():
		var bar := pool[i]
		bar.visible = i < bars.size()
		if bar.visible:
			var frac := clampf(bars[i][1], 0.0, 1.0)
			bar.position = (bars[i][0] as Vector2) - bar.size * 0.5
			var fill := bar.get_child(0) as ColorRect
			fill.size.x = (size.x - 6.0) * frac
			if warn:
				fill.color = col if frac > 0.5 else (Color(0.95, 0.75, 0.2) if frac > 0.25 else Color(0.95, 0.25, 0.2))


func set_phase(text: String) -> void:
	_phase_label.text = text


## Show the build popup. `key` names what it is for: the buttons are only
## rebuilt when the key or the options change. options: [{id, text, ok}].
func show_menu(key: String, title: String, desc: String, options: Array) -> void:
	var full_key := key + str(options)
	_menu.visible = true
	minimap.visible = false
	if full_key == _menu_key:
		return
	var opened := _menu_key == ""
	_menu_key = full_key
	_menu_title.text = title
	_menu_desc.text = desc
	_menu_desc.visible = desc != ""
	for c in _menu_list.get_children():
		c.queue_free()
	for o in options:
		var b := Button.new()
		b.text = String(o.text)
		b.add_theme_font_size_override("font_size", 26)
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.custom_minimum_size = Vector2(0, 70)
		b.disabled = not o.ok
		b.add_theme_stylebox_override("normal", _box(Color(0.2, 0.5, 0.3), 14, Color(1, 1, 1, 0.7), 2))
		b.add_theme_stylebox_override("hover", _box(Color(0.24, 0.6, 0.36), 14, Color.WHITE, 2))
		b.add_theme_stylebox_override("pressed", _box(Color(0.15, 0.4, 0.24), 14, Color.WHITE, 2))
		b.add_theme_stylebox_override("disabled", _box(Color(0.22, 0.22, 0.24), 14, Color(1, 1, 1, 0.3), 2))
		var id := String(o.id)
		b.pressed.connect(func() -> void: menu_pick.emit(id))
		_menu_list.add_child(b)
	if opened:
		menu_opened.emit()


func menu_open() -> bool:
	return _menu.visible


func hide_menu() -> void:
	_menu.visible = false
	minimap.visible = not _end.visible
	_menu_key = ""


## The big countdown digit; 0 hides it.
func show_countdown(n: int) -> void:
	if n == _count_n:
		return
	_count_n = n
	_count.visible = n > 0
	if n <= 0:
		return
	# A digit's glyph is ~0.72 of the font size: this makes it ~60% of the
	# screen height.
	var h := get_viewport().get_visible_rect().size.y
	var fs := int(h * 0.6 / 0.72)
	_count.add_theme_font_size_override("font_size", fs)
	_count.add_theme_constant_override("outline_size", fs / 14)
	# Centre the digit itself, not the line box (it sits above the descent).
	_count.offset_top = -fs * 0.08
	_count.offset_bottom = -fs * 0.08
	_count.text = str(n)
	_count.pivot_offset = _count.size * 0.5
	_count_pop = 1.0


func message(text: String, seconds := 3.0) -> void:
	_msg.text = text
	_msg_t = seconds


func show_end(won: bool, info := "") -> void:
	_touch = -1
	_update_move()
	_end_label.text = "VICTORY!" if won else "DEFEAT"
	_end_info.text = info
	_end.visible = true
	minimap.visible = false


func hide_end() -> void:
	_end.visible = false


func _process(delta: float) -> void:
	if _count.visible:
		# Each new digit pops in big and settles, then fades a little.
		_count_pop = maxf(_count_pop - delta * 1.6, 0.0)
		var k := _count_pop * _count_pop
		_count.pivot_offset = _count.size * 0.5
		_count.scale = Vector2.ONE * (1.0 + 0.3 * k)
		_count.modulate = Color(1.0, 0.92, 0.55, 0.45 + 0.4 * k)
	if _msg_t > 0.0:
		_msg_t -= delta
		_msg.modulate.a = clampf(_msg_t / 0.4, 0.0, 1.0)
	_pulse = maxf(_pulse - delta, 0.0)
	_coin_label.scale = Vector2.ONE * (1.0 + _pulse * 1.2)
