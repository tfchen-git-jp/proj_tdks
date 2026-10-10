class_name Confirm
extends CanvasLayer
## A yes / no question over everything (Esc / Android back). ask() shows
## it; the answer calls back once. Esc / back again while it is up = No.

var _text: Label
var _yes: Button
var _no: Button
var _on_yes: Callable
var _on_no: Callable


func _ready() -> void:
	layer = 30
	visible = false
	var shade := ColorRect.new()
	shade.color = Color(0, 0, 0, 0.6)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(shade)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", _box(Color(0.08, 0.09, 0.11, 0.95), 22, Color(1, 1, 1, 0.8), 3, 36))
	center.add_child(panel)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 34)
	panel.add_child(box)
	_text = Label.new()
	_text.custom_minimum_size = Vector2(560, 0)
	_text.autowrap_mode = TextServer.AUTOWRAP_WORD
	_text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_text.add_theme_font_size_override("font_size", 32)
	box.add_child(_text)
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 30)
	box.add_child(row)
	_no = _button(tr("No"), Color(0.3, 0.32, 0.38))
	_no.pressed.connect(answer.bind(false))
	row.add_child(_no)
	_yes = _button(tr("Yes"), Color(0.6, 0.22, 0.2))
	_yes.pressed.connect(answer.bind(true))
	row.add_child(_yes)


func ask(text: String, on_yes: Callable, on_no := Callable(), yes_text := "Yes", no_text := "No") -> void:
	_text.text = text
	_yes.text = yes_text
	_no.text = no_text
	_on_yes = on_yes
	_on_no = on_no
	visible = true


func is_open() -> bool:
	return visible


func answer(yes: bool) -> void:
	if not visible:
		return
	visible = false
	var cb := _on_yes if yes else _on_no
	_on_yes = Callable()
	_on_no = Callable()
	if cb.is_valid():
		cb.call()


func _button(text: String, col: Color) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(230, 84)
	b.add_theme_font_size_override("font_size", 36)
	b.add_theme_stylebox_override("normal", _box(col, 18, Color(1, 1, 1, 0.8), 3, 0))
	b.add_theme_stylebox_override("hover", _box(col.lightened(0.15), 18, Color.WHITE, 3, 0))
	b.add_theme_stylebox_override("pressed", _box(col.darkened(0.2), 18, Color.WHITE, 3, 0))
	b.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	return b


func _box(fill: Color, radius: int, border: Color, bw: int, pad: int) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = fill
	s.set_corner_radius_all(radius)
	s.border_color = border
	s.set_border_width_all(bw)
	s.content_margin_left = pad
	s.content_margin_right = pad
	s.content_margin_top = pad
	s.content_margin_bottom = pad
	return s
