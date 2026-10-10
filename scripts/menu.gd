class_name MainMenu
extends CanvasLayer
## Title screen over the (idle) map: New game, Continue, Scores, Credits,
## Exit. Pages swap in place; main.gd starts the game from the signals.

signal new_game
signal continue_game
signal exit_game

const TITLE_GOLD := Color(1.0, 0.82, 0.3)

var _pages := {}  # name -> Control
var _continue: Button
var _scores_box: GridContainer
var _shade: ColorRect


func _ready() -> void:
	layer = 10
	_shade = ColorRect.new()
	_shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_shade)
	_pages.main = _main_page()
	_pages.scores = _scores_page()
	_pages.credits = _credits_page()
	for p in _pages.values():
		add_child(p)
	var ver := _label("v" + String(ProjectSettings.get_setting("application/config/version")), 20)
	ver.modulate = Color(1, 1, 1, 0.5)
	ver.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT)
	ver.offset_left = 14
	ver.offset_top = -40
	add_child(ver)
	show_page("main")


func show_page(name: String) -> void:
	for k in _pages:
		(_pages[k] as Control).visible = k == name
	# Darker behind the text pages.
	_shade.color = Color(0.02, 0.04, 0.03, 0.55 if name == "main" else 0.8)
	if name == "main":
		var run := Save.load_run()
		_continue.disabled = run.is_empty()
		_continue.text = "Continue  (wave %d)" % (int(run.wave) + 1) if not run.is_empty() else "Continue"
	if name == "scores":
		_fill_scores()


# --- pages ------------------------------------------------------------------------

func _main_page() -> Control:
	var box := _column(36)
	var title := _label("RogueShot", 104)
	title.add_theme_color_override("font_color", TITLE_GOLD)
	box.add_child(title)
	var sub := _label("TOWER DEFENSE", 38)
	sub.modulate = Color(1, 1, 1, 0.85)
	box.add_child(sub)
	box.add_child(_gap(40))
	box.add_child(_button("New game", Color(0.2, 0.6, 0.3), func() -> void: new_game.emit()))
	_continue = _button("Continue", Color(0.2, 0.45, 0.65), func() -> void: continue_game.emit())
	box.add_child(_continue)
	box.add_child(_button("Scores", Color(0.45, 0.38, 0.2), func() -> void: show_page("scores")))
	box.add_child(_button("Credits", Color(0.35, 0.35, 0.4), func() -> void: show_page("credits")))
	box.add_child(_button("Exit", Color(0.5, 0.2, 0.2), func() -> void: exit_game.emit()))
	return _centered(box)


func _scores_page() -> Control:
	var box := _column(24)
	var title := _label("Top 10", 72)
	title.add_theme_color_override("font_color", TITLE_GOLD)
	box.add_child(title)
	var hint := _label("Most waves cleared, then score:\nkeep HP % x 10 + gold left", 24)
	hint.modulate = Color(1, 1, 1, 0.7)
	box.add_child(hint)
	_scores_box = GridContainer.new()
	_scores_box.columns = 5
	_scores_box.add_theme_constant_override("h_separation", 22)
	_scores_box.add_theme_constant_override("v_separation", 10)
	box.add_child(_scores_box)
	box.add_child(_gap(20))
	box.add_child(_button("Back", Color(0.35, 0.35, 0.4), func() -> void: show_page("main")))
	return _centered(box)


func _fill_scores() -> void:
	for c in _scores_box.get_children():
		c.queue_free()
	var list := Save.scores()
	_scores_box.columns = 1 if list.is_empty() else 5
	if list.is_empty():
		_scores_box.add_child(_label("No games finished yet.", 30))
		return
	for i in list.size():
		var e: Dictionary = list[i]
		var cells := ["%d." % (i + 1), "WIN" if e.won else "", "wave %d" % int(e.waves),
			"%d pts" % int(e.get("score", e.get("gold", 0))), String(e.date)]
		for c in cells.size():
			var cell := _label(cells[c], 28)
			cell.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT if c in [0, 3] else HORIZONTAL_ALIGNMENT_LEFT
			if i == 0:
				cell.add_theme_color_override("font_color", TITLE_GOLD)
			_scores_box.add_child(cell)


func _credits_page() -> Control:
	var box := _column(20)
	var title := _label("Credits", 72)
	title.add_theme_color_override("font_color", TITLE_GOLD)
	box.add_child(title)
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(620, 820)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	var text := _label(CREDITS, 24)
	text.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	text.autowrap_mode = TextServer.AUTOWRAP_WORD
	text.custom_minimum_size = Vector2(600, 0)
	scroll.add_child(text)
	box.add_child(scroll)
	box.add_child(_button("Back", Color(0.35, 0.35, 0.4), func() -> void: show_page("main")))
	return _centered(box)


const CREDITS := """RogueShot Tower Defense
Made with Godot Engine 4.7 (godotengine.org), by directing Claude.

3D MODELS (CC0)
Kay Lousberg (kaylousberg.com): KayKit Adventurers (hero, barbarian), Skeletons (crossbowmen, Bone Warlord), Medieval Hexagon (archer tower, windmill, market, keep, flag, gate), Dungeon Remastered (coins), Forest Nature (rocks)
Kenney (kenney.nl): Tower Defense Kit, Mini Dungeon, Mini Arena, Nature Kit
Quaternius (quaternius.com): Animated Monsters (bat)

SOUND (CC0 unless noted)
Kenney: RPG Audio, Impact Sounds, Interface Sounds, Casino Audio, Sci-fi Sounds, Music Jingles
OpenGameArt: artisticdude (bow, freeze spell), Vehicle / Jan Schupke (Tinysized SFX), bart (ice spells), rubberduck (creature SFX), Joth (chunky explosion), qubodup (dull explosion), fvcalderan (fanfare), 0new4y (game-over trumpet)
Wave horn: "Scary Echoey Horn Esque Sound" by Kat, CC-BY 4.0 (opengameart.org)

MUSIC
"RPG City" by phantasticbeats (Pixabay)

Thanks for playing!"""


# --- widgets ------------------------------------------------------------------------

func _centered(inner: Control) -> Control:
	var c := CenterContainer.new()
	c.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	c.add_child(inner)
	return c


func _column(sep: int) -> VBoxContainer:
	var box := VBoxContainer.new()
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_theme_constant_override("separation", sep)
	return box


func _gap(h: float) -> Control:
	var c := Control.new()
	c.custom_minimum_size = Vector2(0, h)
	return c


func _label(text: String, size: int) -> Label:
	var l := Label.new()
	l.text = text
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	l.add_theme_constant_override("outline_size", maxi(size / 6, 4))
	return l


func _button(text: String, col: Color, on: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(460, 84)
	b.add_theme_font_size_override("font_size", 38)
	b.add_theme_stylebox_override("normal", _box(col, 18, Color(1, 1, 1, 0.8), 3))
	b.add_theme_stylebox_override("hover", _box(col.lightened(0.15), 18, Color.WHITE, 3))
	b.add_theme_stylebox_override("pressed", _box(col.darkened(0.2), 18, Color.WHITE, 3))
	b.add_theme_stylebox_override("disabled", _box(Color(0.22, 0.22, 0.24, 0.8), 18, Color(1, 1, 1, 0.3), 3))
	b.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	b.pressed.connect(on)
	return b


func _box(fill: Color, radius: int, border: Color, bw: int) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = fill
	s.set_corner_radius_all(radius)
	s.border_color = border
	s.set_border_width_all(bw)
	return s
