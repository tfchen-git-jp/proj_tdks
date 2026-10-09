class_name Save
extends RefCounted
## The saved run (Continue in the main menu) and the top-10 scores, as
## JSON in user:// (on the phone: the app's private storage).
##   run:    Sim.to_save() -- written when a wave starts and when one is
##           cleared, deleted when the game is won or lost.
##   scores: [{waves, score, keep, gold, won, date}], best first: more
##           waves cleared, then the higher score (keep HP % x 10 + gold).

const RUN := "user://run.json"
const SCORES := "user://scores.json"
const TOP := 10


static func has_run() -> bool:
	return not load_run().is_empty()


static func save_run(d: Dictionary) -> void:
	_write(RUN, d)


static func load_run() -> Dictionary:
	var v: Variant = _read(RUN)
	return v if v is Dictionary and int((v as Dictionary).get("v", 0)) == Sim.SAVE_VERSION else {}


static func clear_run() -> void:
	if FileAccess.file_exists(RUN):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(RUN))


static func scores() -> Array:
	var v: Variant = _read(SCORES)
	return v if v is Array else []


## Tie-break score for the same waves cleared: every 1% of the keep's HP
## left is worth 10 gold (a full keep = 1000), plus the gold in hand.
static func score_of(keep_frac: float, gold: int) -> int:
	return roundi(clampf(keep_frac, 0.0, 1.0) * 1000.0) + gold


## Adds a finished game; returns its rank (1-based), or 0 if it didn't make
## the top 10.
static func add_score(waves: int, keep_frac: float, gold: int, won: bool) -> int:
	var list := scores()
	var entry := {waves = waves, score = score_of(keep_frac, gold), keep = roundi(keep_frac * 100.0), gold = gold,
		won = won, date = Time.get_date_string_from_system()}
	list.push_back(entry)
	list.sort_custom(better)
	var rank := list.find(entry) + 1
	list.resize(mini(list.size(), TOP))
	_write(SCORES, list)
	return rank if rank <= TOP else 0


## Ranking: more waves cleared first, then the higher score (entries from
## before v0.1.16 have no score: their gold stands in).
static func better(a: Dictionary, b: Dictionary) -> bool:
	if int(a.waves) != int(b.waves):
		return int(a.waves) > int(b.waves)
	return int(a.get("score", a.get("gold", 0))) > int(b.get("score", b.get("gold", 0)))


static func _write(path: String, v: Variant) -> void:
	var f := FileAccess.open(path, FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify(v))


static func _read(path: String) -> Variant:
	if not FileAccess.file_exists(path):
		return null
	return JSON.parse_string(FileAccess.get_file_as_string(path))
