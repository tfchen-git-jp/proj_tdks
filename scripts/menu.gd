class_name MainMenu
extends CanvasLayer
## Title screen over the (idle) map: New game, Continue, Scores, Credits,
## Exit. Pages swap in place; main.gd starts the game from the signals.

signal new_game
signal continue_game
signal exit_game
signal language_changed

const TITLE_GOLD := Color(1.0, 0.82, 0.3)

var _pages := {}  # name -> Control
var _continue: Button
var _scores_box: GridContainer
var _shade: ColorRect
## The licence texts the engine and the font require with every copy
## (Godot MIT + its third-party parts, the font's SIL OFL); filled the
## first time the page opens (long text).
var _licenses_box: VBoxContainer


func _ready() -> void:
	layer = 10
	_shade = ColorRect.new()
	_shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_shade)
	_pages.main = _main_page()
	_pages.scores = _scores_page()
	_pages.credits = _credits_page()
	_pages.licenses = _licenses_page()
	_pages.guide = _guide_page()
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
		_continue.text = tr("Continue  (wave %d)") % (int(run.wave) + 1) if not run.is_empty() else tr("Continue")
	if name == "scores":
		_fill_scores()
	if name == "licenses" and _licenses_box.get_child_count() == 0:
		for sec in _licenses():  # a label per section: one 90 KB label is slow
			var l := _label(sec, 16)
			l.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
			l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			l.custom_minimum_size = Vector2(600, 0)
			_licenses_box.add_child(l)


# --- pages ------------------------------------------------------------------------

func _main_page() -> Control:
	var box := _column(36)
	var title := _label(tr("RogueShot"), 104)
	title.add_theme_color_override("font_color", TITLE_GOLD)
	box.add_child(title)
	var sub := _label(tr("TOWER DEFENSE"), 38)
	sub.modulate = Color(1, 1, 1, 0.85)
	box.add_child(sub)
	box.add_child(_gap(40))
	box.add_child(_button(tr("New game"), Color(0.2, 0.6, 0.3), func() -> void: new_game.emit()))
	_continue = _button(tr("Continue"), Color(0.2, 0.45, 0.65), func() -> void: continue_game.emit())
	box.add_child(_continue)
	box.add_child(_button(tr("Scores"), Color(0.45, 0.38, 0.2), func() -> void: show_page("scores")))
	box.add_child(_button(tr("Guide"), Color(0.25, 0.4, 0.4), func() -> void: show_page("guide")))
	box.add_child(_button(tr("Credits"), Color(0.35, 0.35, 0.4), func() -> void: show_page("credits")))
	# Each tap: the next language, at once (the menu is rebuilt in it).
	var lang := _button(tr("Language: %s") % Loc.NAMES[Loc.code()], Color(0.3, 0.3, 0.45),
		func() -> void:
			Loc.cycle()
			language_changed.emit())
	lang.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	box.add_child(lang)
	box.add_child(_button(tr("Exit"), Color(0.5, 0.2, 0.2), func() -> void: exit_game.emit()))
	return _centered(box)


func _scores_page() -> Control:
	var box := _column(24)
	var title := _label(tr("Top 10"), 72)
	title.add_theme_color_override("font_color", TITLE_GOLD)
	box.add_child(title)
	var hint := _label(tr("Most waves cleared, then score:\nkeep HP % x 10 + gold left + 50 per hero level"), 24)
	hint.modulate = Color(1, 1, 1, 0.7)
	box.add_child(hint)
	_scores_box = GridContainer.new()
	_scores_box.columns = 5
	_scores_box.add_theme_constant_override("h_separation", 22)
	_scores_box.add_theme_constant_override("v_separation", 10)
	box.add_child(_scores_box)
	box.add_child(_gap(20))
	box.add_child(_button(tr("Back"), Color(0.35, 0.35, 0.4), func() -> void: show_page("main")))
	return _centered(box)


func _fill_scores() -> void:
	for c in _scores_box.get_children():
		c.queue_free()
	var list := Save.scores()
	_scores_box.columns = 1 if list.is_empty() else 5
	if list.is_empty():
		_scores_box.add_child(_label(tr("No games finished yet."), 30))
		return
	for i in list.size():
		var e: Dictionary = list[i]
		var cells := ["%d." % (i + 1), tr("WIN") if e.won else "", tr("wave %d") % int(e.waves),
			tr("%d pts") % int(e.get("score", e.get("gold", 0))), String(e.date)]
		for c in cells.size():
			var cell := _label(cells[c], 28)
			cell.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT if c in [0, 3] else HORIZONTAL_ALIGNMENT_LEFT
			if i == 0:
				cell.add_theme_color_override("font_color", TITLE_GOLD)
			_scores_box.add_child(cell)


## Every building and enemy: name, then its three info lines.
func _guide_page() -> Control:
	var box := _column(16)
	var title := _label(tr("Guide"), 72)
	title.add_theme_color_override("font_color", TITLE_GOLD)
	box.add_child(title)
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(640, 860)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	var list := VBoxContainer.new()
	list.add_theme_constant_override("separation", 14)
	scroll.add_child(list)
	# [name, info dict, icon, branch]; a heading has no dict. Towers list
	# their two level-IV specs right after them as branches of a tree
	# (branch: "" a root, "mid" / "last" a spec under the tower above).
	var entries := [[tr("BUILDINGS"), null, "", ""]]
	for k in Level.BUILDINGS:
		entries.push_back([tr(String(Level.BUILDINGS[k].name)), Level.BUILDINGS[k], k, ""])
		var specs: Array = Level.BUILDINGS[k].get("specs", [])
		for i in specs.size():
			entries.push_back([tr("Lv 4: %s") % tr(String(specs[i].name)), specs[i], k,
				"last" if i == specs.size() - 1 else "mid"])
	entries.push_back([tr("ENEMIES"), null, ""])
	for k in Level.ENEMIES.size():
		entries.push_back([Level.ename(k), Level.ENEMIES[k], Models.enemy_icon(k), ""])
	for it in entries:
		if it[1] == null:
			var head := _label(it[0], 34)
			head.add_theme_color_override("font_color", TITLE_GOLD)
			list.add_child(head)
			continue
		# Name with its own icon, then the three info lines; a spec sits
		# indented under its tower, joined to it by tree lines.
		var branch: String = it[3]
		var width := 620 - (TREE_INDENT if branch != "" else 0)
		var entry := VBoxContainer.new()
		entry.add_theme_constant_override("separation", 4)
		var name := UiText.label(26 if branch != "" else 30)
		var icon_key: String = it[2]
		var px := 36 if branch != "" else 44
		name.text = ("[img=%dx%d]%s%s.png[/img] " % [px, px, UiText.ICONS, icon_key] if icon_key != "" else "") + String(it[0])
		name.custom_minimum_size = Vector2(width, 0)
		entry.add_child(name)
		var body := UiText.label(22)
		UiText.set_text(body, Level.info(it[1]), 26)
		body.custom_minimum_size = Vector2(width, 0)
		body.modulate = Color(1, 1, 1, 0.9)
		entry.add_child(body)
		if branch == "":
			list.add_child(entry)
			continue
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 0)
		var lines := Control.new()
		lines.custom_minimum_size = Vector2(TREE_INDENT, 0)
		lines.draw.connect(func() -> void: _tree_lines(lines, branch == "last", name.size.y * 0.5))
		row.add_child(lines)
		row.add_child(entry)
		list.add_child(row)
	box.add_child(scroll)
	box.add_child(_button(tr("Back"), Color(0.35, 0.35, 0.4), func() -> void: show_page("main")))
	return _centered(box)


## Guide tree: how far a spec sits in from its tower, px.
const TREE_INDENT := 44


## A spec's tree lines: down from the tower above (through the list's
## gap), across to the spec's name; a "mid" branch carries on down to the
## next spec.
func _tree_lines(c: Control, last: bool, mid_y: float) -> void:
	var x := 18.0
	var col := Color(1.0, 0.85, 0.45, 0.7)
	var bottom := mid_y if last else c.size.y + 14.0
	c.draw_line(Vector2(x, -14.0), Vector2(x, bottom), col, 3.0)
	c.draw_line(Vector2(x, mid_y), Vector2(TREE_INDENT - 4.0, mid_y), col, 3.0)


func _credits_page() -> Control:
	var box := _column(20)
	var title := _label(tr("Credits"), 72)
	title.add_theme_color_override("font_color", TITLE_GOLD)
	box.add_child(title)
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(620, 820)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	var text := _label(tr(CREDITS), 24)
	text.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	text.autowrap_mode = TextServer.AUTOWRAP_WORD
	text.custom_minimum_size = Vector2(600, 0)
	scroll.add_child(text)
	box.add_child(scroll)
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 20)
	for b in [_button(tr("Licenses"), Color(0.3, 0.4, 0.5), func() -> void: show_page("licenses")),
			_button(tr("Back"), Color(0.35, 0.35, 0.4), func() -> void: show_page("main"))]:
		b.custom_minimum_size.x = 300  # two side by side within the 620 px page
		row.add_child(b)
	box.add_child(row)
	return _centered(box)


func _licenses_page() -> Control:
	var box := _column(20)
	var title := _label(tr("Licenses"), 72)
	title.add_theme_color_override("font_color", TITLE_GOLD)
	box.add_child(title)
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(620, 820)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_licenses_box = VBoxContainer.new()
	_licenses_box.add_theme_constant_override("separation", 24)
	scroll.add_child(_licenses_box)
	box.add_child(scroll)
	box.add_child(_button(tr("Back"), Color(0.35, 0.35, 0.4), func() -> void: show_page("credits")))
	return _centered(box)


static func _licenses() -> PackedStringArray:
	var out := PackedStringArray()
	out.append("GODOT ENGINE\n\n" + Engine.get_license_text())
	out.append("NOTO SANS TC (font, subset)\n\n" + FileAccess.get_file_as_string("res://assets/fonts/OFL.txt"))
	var parts := PackedStringArray()
	for c in Engine.get_copyright_info():
		for p in c.parts:
			parts.append("%s: %s (%s)" % [c.name, ", ".join(p.copyright), p.license])
	out.append("GODOT THIRD-PARTY COMPONENTS\n\n" + "\n\n".join(parts))
	var info := Engine.get_license_info()
	for k in info:
		out.append(String(k).to_upper() + "\n\n" + String(info[k]))
	for i in out.size():
		out[i] = _reflow(out[i])
	return out


## Licence files break lines at ~70 columns: join the lines of each
## paragraph so the narrow page wraps them cleanly.
static func _reflow(text: String) -> String:
	var paras := PackedStringArray()
	for p in text.replace("\r", "").split("\n\n"):
		var lines := PackedStringArray()
		for l in p.split("\n"):
			lines.append(l.strip_edges())
		paras.append(" ".join(lines).strip_edges())
	return "\n\n".join(paras).strip_edges()


const CREDITS := """RogueShot Tower Defense
Game design and direction: David Chen JP
Programmed with Claude (Anthropic) as the coding assistant
Made with Godot Engine 4.7 (godotengine.org)

3D MODELS (CC0)
Kay Lousberg (kaylousberg.com): KayKit Adventurers (hero, barbarian, captain, shade, necromancer), Skeletons (crossbowmen, bone mages, sappers, warded, Bone Warlord), Medieval Hexagon (archer and sniper towers, fire mortar, windmill, market, keep, flags, gate), Dungeon Remastered (coins), Forest Nature (rocks)
Kenney (kenney.nl): Tower Defense Kit, Mini Dungeon, Mini Arena, Nature Kit
Quaternius (quaternius.com): Animated Monsters (bat, slime, drake)

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
