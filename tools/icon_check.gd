extends SceneTree
## Every info text (buildings, specs, enemies) and card / relic text in
## every language: a unit or
## building name that UiText shows without its icon is reported.
##   godot --headless --path . --script res://tools/icon_check.gd
func _init() -> void:
	var bad := 0
	for lang in Loc.CHOICES:
		Loc.apply(lang)
		var names := {}
		for k in Level.BUILDINGS:
			names[Loc.t(String(Level.BUILDINGS[k].name))] = true
			for sp in Level.BUILDINGS[k].get("specs", []):
				names[Loc.t(String(sp.name))] = true
		for e in Level.ENEMIES:
			names[Loc.t(String(e.name))] = true
			names[Loc.t(String(e.plural))] = true
		for pair in UiText.ICON_WORDS:
			names[Loc.t(String(pair[0]))] = true
		var texts := []
		for k in Level.BUILDINGS:
			texts.push_back(Level.info(Level.BUILDINGS[k]))
			for sp in Level.BUILDINGS[k].get("specs", []):
				texts.push_back(Level.info(sp))
		for e in Level.ENEMIES:
			texts.push_back(Level.info(e))
		for c in Perks.CARDS.values():
			for d in c.desc:
				texts.push_back(Loc.t(String(d)))
		for r in Perks.RELICS.values():
			for d in r.desc:
				texts.push_back(Loc.t(String(d)))
		for t in texts:
			var out := UiText.fmt(t)
			# An icon tag becomes just "[/img]" (its file path holds names too).
			out = RegEx.create_from_string("\\[img=[^\\]]*\\][^\\[]*\\[/img\\]").sub(out, "[/img]", true)
			# Coloured words (card names such as Giant Slayer) are not units.
			out = RegEx.create_from_string("\\[color=[^\\]]*\\][^\\[]*\\[/color\\]").sub(out, "~", true)
			# Longest names first; each occurrence must follow an icon tag
			# ("[/img]"), then it is masked so shorter names inside it
			# (巨人 in 巨人殺手) are not counted again.
			var keys := names.keys()
			keys.sort_custom(func(a: String, b: String) -> bool: return a.length() > b.length())
			for n in keys:
				if n.length() < 2:
					continue
				var at := out.find(n)
				while at >= 0:
					if not out.substr(maxi(at - 6, 0), mini(at, 6)).ends_with("[/img]") and UiText._find_word(out, n, at) == at:
						print("[%s] no icon for '%s' in: %s" % [lang, n, t.replace("\n", " / ")])
						bad += 1
					out = out.substr(0, at) + "#".repeat(n.length()) + out.substr(at + n.length())
					at = out.find(n, at)
	print("icon check: %s" % ("OK" if bad == 0 else "%d missing" % bad))
	quit(1 if bad else 0)
