class_name UiText
extends RefCounted
## Rich UI text: unit and building names get their icon (tools/make_icons.gd
## renders assets/icons/), "Strong vs" / "Weak vs" are green / red, and
## elements keep fixed colours everywhere: fire orange-red, frost / chill /
## slow ice blue, lightning yellow, gold gold, armour steel.

const ICONS := "res://assets/icons/"
const STRONG := "7dff8a"
const WEAK := "ff8a7a"
const FIRE := "ff7a33"
const ICE := "8fd8ff"
const SHOCK := "ffe066"
const GOLD := "ffd24a"
const STEEL := "c0c8d8"

## Words that get an icon in front: word -> icon file. Longest first, so
## "the boss" wins over "boss".
const ICON_WORDS := [
	["crossbowmen", "siege"], ["crossbowman", "siege"], ["the boss", "boss"], ["Bone Warlord", "boss"],
	["giants", "brute"], ["brutes", "brute"], ["brute", "brute"], ["grunt", "grunt"], ["runner", "runner"],
	["bat", "bat"], ["grunts", "grunt"], ["runners", "runner"], ["bats", "bat"],
	["armored", "armored"], ["archers", "archer"], ["ballistas", "ballista"], ["mortars", "mortar"],
	["frost", "frost"], ["gates", "gate"], ["the hero", "hero"], ["tower clusters", "banner"],
]
## Coloured words (no icon): word -> colour. Checked after the icons.
const COLOR_WORDS := [
	["Fire Bolts", FIRE], ["ablaze", FIRE], ["Burn", FIRE], ["burn", FIRE], ["fire", FIRE],
	["Frost Bolts", ICE], ["chill", ICE], ["Chill", ICE], ["Slow", ICE], ["slow", ICE],
	["Lightning", SHOCK], ["lightning", SHOCK], ["Thunderstrike", SHOCK], ["critical", SHOCK],
	["interest", GOLD], ["gold", GOLD], ["Gold", GOLD], ["ingot", GOLD],
	["Armor", STEEL], ["armor", STEEL], ["armour", STEEL], ["Giant Slayer", STEEL], ["Multishot", STEEL],
]


## The element colour of a card / relic name ("" for none).
static func color_of(name: String) -> String:
	return {"Fire Bolts": FIRE, "Explosive Tips": FIRE, "Frost Bolts": ICE, "Thunderstrike": SHOCK,
		"Keen Eye": SHOCK, "Midas Touch": GOLD, "Bounty": GOLD}.get(name, "")


## BBCode for `text` (already translated), icons `px` high. The words are
## English keys, matched in their translation.
static func fmt(text: String, px := 26) -> String:
	var out := text.replace("[", "[lb]")
	# The labels in the current language (building and enemy wording may
	# differ, Loc.tc); each distinct text coloured once.
	var labels := {}
	labels[Loc.tc("Strong vs:", "building")] = STRONG
	labels[Loc.tc("Strong vs:", "enemy")] = STRONG
	labels[Loc.tc("Weak vs:", "building")] = WEAK
	labels[Loc.tc("Weak vs:", "enemy")] = WEAK
	# One pass over labels and words, longest first, through placeholder
	# marks, so a replacement is never matched again (被克制 holds 克制).
	var marks := {}
	var n := 0
	var lkeys := labels.keys()
	lkeys.sort_custom(func(a: String, b: String) -> bool: return a.length() > b.length())
	for l in lkeys:
		var key := "\u0001%d\u0002" % n
		n += 1
		marks[key] = "[color=#%s]%s[/color]" % [labels[l], l]
		out = out.replace(l, key)
	# Words as this language writes them, longest first (Chinese has no
	# spaces: 巨漢 must not be matched inside 蠻族巨漢).
	var seen := {}
	var words: Array = []
	for pair in ICON_WORDS + COLOR_WORDS:
		var w := Loc.t(String(pair[0]))
		if w != "" and not seen.has(w):
			seen[w] = true
			words.push_back([w, pair[1]])
	words.sort_custom(func(a: Array, b: Array) -> bool: return String(a[0]).length() > String(b[0]).length())
	for pair in words:
		var word: String = pair[0]
		var at := _find_word(out, word, 0)
		while at >= 0:
			var key := "\u0001%d\u0002" % n
			n += 1
			if ResourceLoader.exists(ICONS + String(pair[1]) + ".png"):
				marks[key] = "[img=%dx%d]%s%s.png[/img]%s" % [px, px, ICONS, pair[1], word]
			else:
				marks[key] = "[color=#%s]%s[/color]" % [pair[1], word]
			out = out.substr(0, at) + key + out.substr(at + word.length())
			at = _find_word(out, word, at + key.length())
	for key in marks:
		out = out.replace(key, marks[key])
	return out


## Index of `word` in `s` from `from` as a whole word, or -1.
static func _find_word(s: String, word: String, from: int) -> int:
	var at := s.find(word, from)
	while at >= 0:
		var before := s.substr(at - 1, 1) if at > 0 else " "
		var after := s.substr(at + word.length(), 1)
		if not _letter(before) and not _letter(after):
			return at
		at = s.find(word, at + 1)
	return -1


static func _letter(c: String) -> bool:
	return c != "" and (c.to_lower() != c.to_upper() or c == "\u0001" or c == "\u0002")


## A RichTextLabel set up like the HUD's labels (outline, wrapping, height
## fits the text). `center` centres every line.
static func label(size: int, center := false) -> RichTextLabel:
	var l := RichTextLabel.new()
	l.bbcode_enabled = true
	l.fit_content = true
	l.scroll_active = false
	l.autowrap_mode = TextServer.AUTOWRAP_WORD
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	l.add_theme_font_size_override("normal_font_size", size)
	l.add_theme_font_size_override("bold_font_size", size)
	l.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	l.add_theme_constant_override("outline_size", maxi(size / 5, 3))
	l.set_meta("center", center)
	return l


## Set a label from plain text (formatted here).
static func set_text(l: RichTextLabel, text: String, px := 26) -> void:
	var b := fmt(text, px)
	l.text = "[center]%s[/center]" % b if l.get_meta("center", false) else b
