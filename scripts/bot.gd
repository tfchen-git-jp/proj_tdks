class_name Bot
extends RefCounted
## A simple player for demos, tests and balance runs. Build phase: follow
## PLAN (buy each step when it can afford it), sweep up coins, then start
## the wave. Attack phase: sweep up coins, else stand off the road beside
## the enemy nearest the keep.

## [spot id, building] in order; a repeated pair upgrades it.
const PLAN := [
	# v0.1.30: the spots open by tactical value; the cheap one-lane spots
	# come first.
	["k_east", "archer"], ["k_west", "archer"], ["x_e1", "archer"], ["f_1", "farm"], ["x_w2", "archer"],
	["e_in", "archer"],
	["w_in", "archer"], ["e_mid", "frost"], ["g_c1", "gate"], ["w_mid", "mortar"],
	["k_east", "archer"], ["k_west", "archer"], ["f_3", "farm"], ["x_e2", "ballista"],
	["g_e1", "gate"], ["g_w1", "gate"], ["w_out", "archer"],
	["e_in", "archer"], ["w_in", "archer"], ["w_mid", "mortar"], ["f_1", "farm"],
	["e_mid", "frost"], ["c_far", "ballista"], ["k_east", "archer"], ["k_west", "archer"],
	["f_2", "farm"], ["gc_t", "mortar"], ["g_c2", "gate"], ["ge_t", "archer"], ["gw_t", "archer"],
	["g_e2", "gate"], ["g_w2", "gate"], ["w_mid", "mortar"], ["c_far", "ballista"],
	["gc_t", "mortar"], ["ge_t", "archer"], ["gw_t", "archer"], ["e_in", "archer"], ["w_in", "archer"],
	["e_mid", "frost"], ["w_out", "archer"], ["e_in", "archer"], ["w_in", "archer"],
	["c_far", "ballista"], ["w_mid", "mortar"], ["gc_t", "mortar"],
	# Waves 11-15 (v0.1.28): the spots opened late, gates up, more specs.
	["g_c1", "gate"], ["g_e1", "gate"], ["g_w1", "gate"], ["x_c2", "ballista"], ["x_e1", "mortar"],
	["x_c2", "ballista"], ["x_e1", "mortar"], ["x_w2", "archer"], ["x_w5", "mortar"],
	["c_far", "ballista"], ["e_mid", "frost"], ["x_c2", "ballista"], ["x_e1", "mortar"],
	["x_w2", "archer"], ["x_w5", "mortar"], ["x_w2", "archer"], ["x_w5", "mortar"],
	["g_c1", "gate"], ["g_e1", "gate"], ["g_w1", "gate"], ["x_c1", "ballista"], ["x_w3", "archer"],
	["x_c2", "ballista"], ["x_e1", "mortar"], ["x_c1", "ballista"], ["x_w3", "archer"],
	["g_c2", "gate"], ["g_e2", "gate"], ["g_w2", "gate"], ["x_c1", "ballista"], ["x_w3", "archer"],
	["x_w4", "archer"], ["x_w4", "archer"], ["x_w4", "archer"], ["x_w1", "mortar"], ["x_w1", "mortar"],
	["f_4", "farm"], ["f_5", "farm"],
]

## The spec each tower kind takes at level IV (a variant bot picks at
## random per spot).
const SPECS := {archer = "sniper", ballista = "great", mortar = "cluster", frost = "glacier", banner = "standard"}

## Card / relic preferences, best first (it never rerolls).
const CARD_PRIORITY := ["dmg", "aspd", "multi", "ricochet", "fire", "crit", "slayer", "pierce", "blast",
	"range", "rally", "frost", "engineer", "spotter", "bounty", "boots", "scholar"]
const RELIC_PRIORITY := ["twin", "thunder", "volley", "wisp", "laststand", "midas"]

var sim: Sim
var _step := 0
## The build order this bot follows: PLAN, or (variant >= 0) PLAN with a
## random tower kind on each tower spot and farm / bank on each gold plot,
## the same for every step on that spot (tools/meta.gd).
var plan: Array = PLAN
var _rng: RandomNumberGenerator = null  # set: random card / relic picks
var specs := {}  # spot id -> spec id (variant bots; else SPECS by kind)
## Pick orders in use (tools/meta.gd --force puts one card / relic first).
var card_priority: Array = CARD_PRIORITY.duplicate()
var relic_priority: Array = RELIC_PRIORITY.duplicate()


func _init(s: Sim, variant := -1) -> void:
	sim = s
	if variant < 0:
		return
	_rng = RandomNumberGenerator.new()
	_rng.seed = variant
	var kinds := {}
	plan = []
	for st in PLAN:
		var id: String = st[0]
		var kind: String = st[1]
		if not kinds.has(id):
			if kind in Level.TOWER_KINDS:
				kinds[id] = Level.TOWER_KINDS[_rng.randi() % Level.TOWER_KINDS.size()]
			elif kind in ["farm", "bank"]:
				kinds[id] = "farm" if _rng.randf() < 0.5 else "bank"
			else:
				kinds[id] = kind
			var sp: Array = Level.BUILDINGS[kinds[id]].get("specs", [])
			if not sp.is_empty():
				specs[id] = sp[_rng.randi() % sp.size()].id
		plan.push_back([id, kinds[id]])


## What tower kind / economy building each spot ends up with (stats).
func layout() -> Dictionary:
	var out := {}
	for st in plan:
		out[st[0]] = st[1]
	return out


func move() -> Vector2:
	var target := _target()
	var v := Vector2(target.x - sim.hero_pos.x, target.z - sim.hero_pos.z)
	if v.length() < 0.15:
		return Vector2.ZERO
	return v.normalized() * clampf(v.length() / 0.6, 0.3, 1.0)


func _target() -> Vector3:
	if sim.phase == "build" and not sim.offer.is_empty():
		var order: Array = relic_priority if sim.offer_relic else card_priority
		var best := 0
		for k in sim.offer.size():
			if order.find(sim.offer[k]) < order.find(sim.offer[best]):
				best = k
		sim.pick(best if _rng == null else _rng.randi() % sim.offer.size())
	if sim.phase == "build":
		# Buy the next affordable plan step on an unlocked spot (locked ones
		# wait for a later level), walking to its spot first.
		while _step < plan.size() and _done(_step):
			_step += 1
		var k := _step
		while k < plan.size() and (_done(k) or not sim.unlocked(_spot(plan[k][0]))):
			k += 1
		if k < plan.size() and sim.coins >= _cost(plan[k]):
			var spot := _spot(plan[k][0])
			# Built farms are solid: the hero can't reach the middle, only
			# the popup range (what a player sees).
			if sim.spot_under_hero().get("id", "") == spot.id:
				sim.buy(spot.id, plan[k][1], _spec_for(plan[k]))
			return spot.pos
		var coin := _nearest_coin()
		if coin != Vector3.INF:
			return coin
		return Level.START_SPOT  # standing there starts the countdown
	var coin := _nearest_coin()
	if coin != Vector3.INF:
		return coin
	var lead := sim.horde.first_in_range(sim.hero_pos, 1000.0)
	if lead >= 0:
		var t: Track = sim.horde.track_of(lead)
		return t.point(clampf(sim.horde.d[lead], 0.0, t.length - 4.0), -3.0)
	return Level.HERO_START


## Has plan step `idx` happened (built, or upgraded to its repeat count)?
func _done(idx: int) -> bool:
	var step: Array = plan[idx]
	var want := 0
	for k in idx + 1:
		if plan[k][0] == step[0] and plan[k][1] == step[1]:
			want += 1
	var b: Dictionary = sim.buildings.get(step[0], {})
	if b.is_empty():
		return false
	return b.kind != step[1] or b.level + 1 >= want or b.level + 1 >= Level.max_levels(b.kind)


## The spec to ask for at plan step `step` ("" unless it is the spec level).
func _spec_for(step: Array) -> String:
	var b: Dictionary = sim.buildings.get(step[0], {})
	if b.is_empty() or b.level + 1 < Level.BUILDINGS[step[1]].levels.size():
		return ""
	return String(specs.get(step[0], SPECS.get(step[1], "")))


func _cost(step: Array) -> int:
	var b: Dictionary = sim.buildings.get(step[0], {})
	var level: int = 0 if b.is_empty() else b.level + 1
	return int(Level.stats(step[1], mini(level, Level.max_levels(step[1]) - 1), _spec_for(step)).cost)


func _spot(id: String) -> Dictionary:
	for s in Level.SPOTS:
		if s.id == id:
			return s
	return {}


func _nearest_coin() -> Vector3:
	var reach := Level.BOUNDS.grow(float(Level.HERO.magnet) - 0.3)
	var best := INF
	var best_p := Vector3.INF
	for i in sim.drop_pos.size():
		if sim.drop_fly[i] >= 0.0:
			continue
		var q := sim.drop_pos[i]
		if not reach.has_point(Vector2(q.x, q.z)):
			continue
		var dd := q.distance_squared_to(sim.hero_pos)
		if dd < best:
			best = dd
			best_p = q
	return best_p
