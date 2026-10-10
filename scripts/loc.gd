class_name Loc
extends RefCounted
## Languages (v0.1.24). The English text is the key: Loc.t("Guide") is
## "Guide" in English and the catalogue's text in another language
## (locale/<code>.po, gettext, listed in project.godot). A text with no
## entry shows its English. The same English that needs two translations
## takes a context: Loc.tc("Weak vs:", "enemy").
##
## The choice is saved in user://settings.cfg and cycles from the title
## menu (Language: English -> 繁體中文 -> ...), applied at once. The
## Chinese font (assets/fonts/NotoSansTC-Game.ttf, tools/make_font.py) is
## the default font's FALLBACK, so English draws exactly as before.

## Language codes in the order the menu cycles them; each named in itself.
const CHOICES := ["en", "zh_TW"]
const NAMES := {"en": "English", "zh_TW": "繁體中文"}
const FONT := "res://assets/fonts/NotoSansTC-Game.ttf"
const SETTINGS := "user://settings.cfg"

static var _font: FontFile


static func t(s: String) -> String:
	return TranslationServer.translate(s)


static func tc(s: String, ctx: String) -> String:
	return TranslationServer.translate(s, ctx)


## Fill a translated pattern: "%d"-style args in order, or "{0} {1}" when
## a language needs them in another order.
static func fmt(pattern: String, args: Array) -> String:
	if pattern.contains("{0}"):
		var out := pattern
		for k in args.size():
			out = out.replace("{%d}" % k, str(args[k]))
		return out
	return pattern % args


static func code() -> String:
	return TranslationServer.get_locale() if TranslationServer.get_locale() in CHOICES else "en"


## Saved choice, put in force (boot). Never the system's language: English
## until the player picks another.
static func boot() -> void:
	var cfg := ConfigFile.new()
	cfg.load(SETTINGS)
	apply(String(cfg.get_value("interface", "language", "en")))


static func apply(c: String) -> void:
	if not c in CHOICES:
		c = "en"
	TranslationServer.set_locale(c)
	_install_font()


## The next language in CHOICES, applied and saved.
static func cycle() -> String:
	var c: String = CHOICES[(CHOICES.find(code()) + 1) % CHOICES.size()]
	apply(c)
	var cfg := ConfigFile.new()
	cfg.load(SETTINGS)
	cfg.set_value("interface", "language", c)
	cfg.save(SETTINGS)
	return c


static func _install_font() -> void:
	if _font == null:
		_font = load(FONT) as FontFile
	if _font == null:
		return
	var base: Font = ThemeDB.fallback_font
	if base == null or base.fallbacks.has(_font):
		return
	var chain: Array[Font] = base.fallbacks.duplicate()
	chain.append(_font)
	base.fallbacks = chain
