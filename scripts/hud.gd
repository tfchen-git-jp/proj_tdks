class_name Hud
extends CanvasLayer
## Coin counter, keep HP bar, wave / phase line, floating joystick, the
## build popup, HP bars over gates and giants, messages and the end screen. The joystick reads touch events only: on PC, Godot turns
## mouse clicks into touches (input_devices/pointing/emulate_touch_from_mouse),
## so the phone and PC run the same code path.

signal restart
signal card_pick(k: int)
signal card_reroll
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
var _boss_bars: Array = []  # per boss bar: [root, fill, name]
var _intro: RichTextLabel
var _intro_t := 0.0
var _top := 0.0  # status-bar inset
var _xp_fill: ColorRect
var _lv_label: Label
var _cards: Control
var _cards_title: Label
var _cards_sub: Label
var _cards_list: VBoxContainer
var _cards_reroll: Button
var _cards_key := ""
var _end_info: Label
var _end_stats: VBoxContainer
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
var _menu_desc: RichTextLabel
var _menu_list: VBoxContainer
var _menu_key := ""


func _ready() -> void:
	_root = Control.new()
	_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_root)
	var top := _safe_top()
	_top = top

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
	var hp_label := _label(tr("KEEP"), 18)
	hp_label.position = Vector2(20, top + 4)
	_root.add_child(hp_label)

	# Hero level and XP, under the keep bar.
	var xp_back := ColorRect.new()
	xp_back.color = Color(0.1, 0.1, 0.12, 0.75)
	xp_back.position = Vector2(20, top + 64)
	xp_back.size = Vector2(160, 14)
	_root.add_child(xp_back)
	_xp_fill = ColorRect.new()
	_xp_fill.color = Color(0.7, 0.45, 1.0)
	_xp_fill.position = Vector2(3, 3)
	_xp_fill.size = Vector2(0, 8)
	xp_back.add_child(_xp_fill)
	_lv_label = _label("Lv 0", 20)
	_lv_label.position = Vector2(188, top + 57)
	_root.add_child(_lv_label)

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
	var mstyle := _box(Color(0.08, 0.09, 0.11, 0.9), 22, Color(1, 1, 1, 0.8), 3)
	mstyle.content_margin_left = 18
	mstyle.content_margin_right = 18
	mstyle.content_margin_top = 10
	mstyle.content_margin_bottom = 20  # the last button kept off the border
	_menu.add_theme_stylebox_override("panel", mstyle)
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
	_menu_desc = UiText.label(22, true)
	_menu_desc.modulate = Color(1, 1, 1, 0.92)
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
	box.add_theme_constant_override("separation", 24)
	box.grow_horizontal = Control.GROW_DIRECTION_BOTH
	box.grow_vertical = Control.GROW_DIRECTION_BOTH
	_end.add_child(box)
	_build_cards()
	_end_label = _label("", 72)
	_end_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(_end_label)
	_end_info = _label("", 32)
	_end_info.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(_end_info)
	var sbox := PanelContainer.new()
	var sst := _box(Color(0.06, 0.07, 0.1, 0.85), 14, Color(1, 1, 1, 0.4), 2)
	sst.content_margin_left = 20
	sst.content_margin_right = 20
	sst.content_margin_top = 12
	sst.content_margin_bottom = 12
	sbox.add_theme_stylebox_override("panel", sst)
	box.add_child(sbox)
	sbox.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_end_stats = VBoxContainer.new()
	_end_stats.add_theme_constant_override("separation", 6)
	sbox.add_child(_end_stats)
	var again := Button.new()
	again.text = "  " + tr("Play again") + "  "
	again.add_theme_font_size_override("font_size", 44)
	again.add_theme_stylebox_override("normal", _box(Color(0.2, 0.65, 0.3), 18, Color.WHITE, 4))
	again.add_theme_stylebox_override("hover", _box(Color(0.25, 0.75, 0.35), 18, Color.WHITE, 4))
	again.add_theme_stylebox_override("pressed", _box(Color(0.15, 0.5, 0.25), 18, Color.WHITE, 4))
	again.pressed.connect(func() -> void: restart.emit())
	box.add_child(again)
	var home := Button.new()
	home.text = "  " + tr("Main menu") + "  "
	home.add_theme_font_size_override("font_size", 36)
	home.add_theme_stylebox_override("normal", _box(Color(0.3, 0.32, 0.38), 18, Color(1, 1, 1, 0.8), 3))
	home.add_theme_stylebox_override("hover", _box(Color(0.38, 0.4, 0.46), 18, Color.WHITE, 3))
	home.add_theme_stylebox_override("pressed", _box(Color(0.22, 0.24, 0.3), 18, Color.WHITE, 3))
	home.pressed.connect(func() -> void: to_menu.emit())
	box.add_child(home)


## The level-up / relic picker (build phase, modal): three cards and a
## reroll button. main.gd fills it from Sim.offer_view().
func _build_cards() -> void:
	_cards = ColorRect.new()
	(_cards as ColorRect).color = Color(0.03, 0.02, 0.08, 0.72)
	_cards.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_cards.visible = false
	_root.add_child(_cards)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_cards.add_child(center)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 18)
	center.add_child(box)
	_cards_title = _label("", 58)
	_cards_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(_cards_title)
	_cards_sub = _label("", 24)
	_cards_sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_cards_sub.modulate = Color(1, 1, 1, 0.75)
	box.add_child(_cards_sub)
	_cards_list = VBoxContainer.new()
	_cards_list.add_theme_constant_override("separation", 16)
	box.add_child(_cards_list)
	_cards_reroll = Button.new()
	_cards_reroll.add_theme_font_size_override("font_size", 30)
	_cards_reroll.custom_minimum_size = Vector2(0, 70)
	_cards_reroll.add_theme_stylebox_override("normal", _box(Color(0.45, 0.36, 0.12), 16, Color(1, 0.85, 0.4), 3))
	_cards_reroll.add_theme_stylebox_override("hover", _box(Color(0.55, 0.45, 0.16), 16, Color.WHITE, 3))
	_cards_reroll.add_theme_stylebox_override("pressed", _box(Color(0.35, 0.28, 0.1), 16, Color.WHITE, 3))
	_cards_reroll.add_theme_stylebox_override("disabled", _box(Color(0.22, 0.22, 0.24), 16, Color(1, 1, 1, 0.3), 3))
	_cards_reroll.pressed.connect(func() -> void: card_reroll.emit())
	box.add_child(_cards_reroll)


## Show an offer: views from Sim.offer_view(); `left` picks still to come
## after this one.
func show_cards(views: Array, relic: bool, left: int, cost: int, can_reroll: bool) -> void:
	_cards.visible = true
	minimap.visible = false
	_touch = -1
	_update_move()
	var key := str(views) + str(cost) + str(can_reroll) + str(left)
	if key == _cards_key:
		return
	_cards_key = key
	_cards_title.text = tr("RELIC") if relic else tr("LEVEL UP!")
	_cards_title.add_theme_color_override("font_color", Color(0.85, 0.6, 1.0) if relic else Color(1.0, 0.85, 0.35))
	_cards_sub.text = (tr("Choose one") if left == 0 else tr("Choose one  -  %d more to come") % left)
	_cards_reroll.text = tr("Reroll  (%d gold)") % cost
	_cards_reroll.disabled = not can_reroll
	for c in _cards_list.get_children():
		c.queue_free()
	for k in views.size():
		_cards_list.add_child(_card(views[k], k))


func hide_cards() -> void:
	if _cards.visible:
		_cards.visible = false
		minimap.visible = not _end.visible and not _menu.visible
	_cards_key = ""


func cards_open() -> bool:
	return _cards.visible


func _card(v: Dictionary, k: int) -> Button:
	var relic: bool = v.relic
	var tier: int = v.tier
	var tint := Color(0.42, 0.2, 0.6) if relic else Color(0.14, 0.3, 0.42)
	var b := Button.new()
	b.custom_minimum_size = Vector2(620, 150)
	b.add_theme_stylebox_override("normal", _box(tint, 18, Color(1, 1, 1, 0.75), 3))
	b.add_theme_stylebox_override("hover", _box(tint.lightened(0.15), 18, Color.WHITE, 3))
	b.add_theme_stylebox_override("pressed", _box(tint.darkened(0.2), 18, Color.WHITE, 4))
	b.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	b.pressed.connect(func() -> void: card_pick.emit(k))
	var col := VBoxContainer.new()
	col.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	col.offset_left = 22
	col.offset_right = -22
	col.offset_top = 14
	col.offset_bottom = -12
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.add_child(col)
	var head := HBoxContainer.new()
	head.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_child(head)
	var name := _label(tr(String(v.name)), 34)
	name.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var elem := UiText.color_of(String(v.name))
	if elem != "":
		name.add_theme_color_override("font_color", Color.html(elem))
	name.mouse_filter = Control.MOUSE_FILTER_IGNORE
	head.add_child(name)
	var badge := _label(tr("RELIC") if relic else (tr("NEW") if tier == 0 else Models.ROMAN[tier]), 30)
	badge.add_theme_color_override("font_color", Color(0.85, 0.6, 1.0) if relic
		else (Color(0.6, 1.0, 0.6) if tier == 0 else Models.BADGE_COLORS[tier].lightened(0.2)))
	badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	head.add_child(badge)
	var desc := UiText.label(24)
	UiText.set_text(desc, tr(String(v.desc)), 26)
	desc.modulate = Color(1, 1, 1, 0.92)
	col.add_child(desc)
	return b


func set_xp(level: int, frac: float) -> void:
	_lv_label.text = "Lv %d" % level
	_xp_fill.size.x = 154.0 * clampf(frac, 0.0, 1.0)


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
	if _end.visible or (_cards != null and _cards.visible):
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
## The boss's big HP bar under the wave line; [] hides it, else [name,
## hp fraction, berserk].
## bosses: [[name, hp fraction, berserk], ...] (one bar each, stacked).
func set_boss(bosses: Array) -> void:
	while _boss_bars.size() < bosses.size():
		var k := _boss_bars.size()
		var root := Control.new()
		root.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
		root.position = Vector2(-260, _top + 124 + k * 62)
		root.size = Vector2(520, 60)
		root.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_root.add_child(root)
		var back := ColorRect.new()
		back.color = Color(0.08, 0.04, 0.1, 0.85)
		back.position = Vector2(0, 30)
		back.size = Vector2(520, 26)
		root.add_child(back)
		var fill := ColorRect.new()
		fill.position = Vector2(4, 4)
		fill.size = Vector2(512, 18)
		back.add_child(fill)
		var name := _label("", 26)
		name.size = Vector2(520, 30)
		name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		root.add_child(name)
		_boss_bars.push_back([root, fill, name])
	for k in _boss_bars.size():
		var bar: Array = _boss_bars[k]
		(bar[0] as Control).visible = k < bosses.size()
		if k >= bosses.size():
			continue
		var b: Array = bosses[k]
		(bar[2] as Label).text = tr(String(b[0])) + ("  -  " + tr("BERSERK") if b[2] else "")
		(bar[1] as ColorRect).size.x = 512.0 * clampf(float(b[1]), 0.0, 1.0)
		(bar[1] as ColorRect).color = Color(0.95, 0.25, 0.2) if b[2] else Color(0.7, 0.35, 0.95)
	_msg.offset_top = _top + 150 + 62 * bosses.size()


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
	UiText.set_text(_menu_desc, desc, 24)
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
		# Sell: a smaller, brick-red button under the rest (it asks first).
		var col := Color(0.55, 0.22, 0.18) if o.get("sell", false) else Color(0.2, 0.5, 0.3)
		if o.get("sell", false):
			b.custom_minimum_size = Vector2(0, 56)
			b.add_theme_font_size_override("font_size", 24)
		b.add_theme_stylebox_override("normal", _box(col, 14, Color(1, 1, 1, 0.7), 2))
		b.add_theme_stylebox_override("hover", _box(col.lightened(0.12), 14, Color.WHITE, 2))
		b.add_theme_stylebox_override("pressed", _box(col.darkened(0.2), 14, Color.WHITE, 2))
		b.add_theme_stylebox_override("disabled", _box(Color(0.22, 0.22, 0.24), 14, Color(1, 1, 1, 0.3), 2))
		if o.has("icon") and ResourceLoader.exists(String(o.icon)):
			b.icon = load(String(o.icon))
			b.expand_icon = true
			b.add_theme_constant_override("icon_max_width", 52)
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


## New enemy types: a compact card under the wave line for `seconds`.
func show_intro(text: String, seconds: float) -> void:
	if _intro == null:
		_intro = UiText.label(24)
		var ist := _box(Color(0.06, 0.05, 0.1, 0.8), 14, Color(1.0, 0.75, 0.3, 0.8), 2)
		ist.content_margin_left = 18
		ist.content_margin_top = 12
		ist.content_margin_bottom = 12
		_intro.add_theme_stylebox_override("normal", ist)
		_intro.anchor_left = 0.0
		_intro.anchor_right = 1.0
		_intro.offset_left = 30
		_intro.offset_right = -30
		_intro.offset_top = _top + 215
		_intro.autowrap_mode = TextServer.AUTOWRAP_WORD
		_intro.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_root.add_child(_intro)
	UiText.set_text(_intro, text, 34)
	_intro_t = seconds
	_intro.modulate.a = 1.0
	_intro.visible = true


func message(text: String, seconds := 3.0) -> void:
	_msg.text = text
	_msg_t = seconds


## tables: [[title, [[icon, name, value, share %], ...]], ...] ([] hides).
## Each table is a grid -- icon + name, value, share -- so the columns line
## up in any language; the panel sits centred, as wide as its content.
func show_end(won: bool, info := "", tables := []) -> void:
	_touch = -1
	_update_move()
	_end_label.text = tr("VICTORY!") if won else tr("DEFEAT")
	_end_info.text = info
	for c in _end_stats.get_children():
		c.queue_free()
	for t in tables:
		if _end_stats.get_child_count() > 0:
			_end_stats.add_child(Control.new())  # a gap between the tables
		var head := _label(String(t[0]), 26)
		head.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		head.add_theme_color_override("font_color", Color(1.0, 0.85, 0.4))
		_end_stats.add_child(head)
		var grid := GridContainer.new()
		grid.columns = 3
		grid.add_theme_constant_override("h_separation", 28)
		grid.add_theme_constant_override("v_separation", 4)
		grid.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		_end_stats.add_child(grid)
		if (t[1] as Array).is_empty():
			grid.add_child(_label(tr("None"), 24))
		for r in t[1]:
			var row := HBoxContainer.new()
			row.add_theme_constant_override("separation", 8)
			var icon := TextureRect.new()
			icon.texture = load(UiText.ICONS + String(r[0]) + ".png")
			icon.custom_minimum_size = Vector2(34, 34)
			icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			row.add_child(icon)
			row.add_child(_label(String(r[1]), 24))
			grid.add_child(row)
			var v := _label(str(roundi(float(r[2]))), 24)
			v.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
			grid.add_child(v)
			var pct := _label("%.1f%%" % float(r[3]), 24)
			pct.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
			pct.modulate = Color(1, 1, 1, 0.75)
			grid.add_child(pct)
	if _intro != null:
		_intro.visible = false
	_msg_t = 0.0
	_msg.modulate.a = 0.0
	(_end_stats.get_parent() as Control).visible = not tables.is_empty()
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
	if _intro != null and _intro.visible:
		_intro_t -= delta
		_intro.modulate.a = clampf(_intro_t / 0.5, 0.0, 1.0)
		_intro.visible = _intro_t > 0.0
	if _msg_t > 0.0:
		_msg_t -= delta
		_msg.modulate.a = clampf(_msg_t / 0.4, 0.0, 1.0)
	_pulse = maxf(_pulse - delta, 0.0)
	_coin_label.scale = Vector2.ONE * (1.0 + _pulse * 1.2)
