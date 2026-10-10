class_name Bot
extends RefCounted
## A simple player for demos, tests and balance runs. Build phase: follow
## PLAN (buy each step when it can afford it), sweep up coins, then start
## the wave. Attack phase: sweep up coins, else stand off the road beside
## the enemy nearest the keep.

## [spot id, building] in order; a repeated pair upgrades it.
const PLAN := [
	["k_east", "archer"], ["k_west", "archer"], ["e_in", "archer"], ["f_1", "farm"],
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
]

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
		var order: Array = RELIC_PRIORITY if sim.offer_relic else CARD_PRIORITY
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
				sim.buy(spot.id, plan[k][1])
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
		var t: Track = sim.tracks[sim.horde.lane[lead]]
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
	return b.kind != step[1] or b.level + 1 >= want or b.level + 1 >= Level.BUILDINGS[b.kind].levels.size()


func _cost(step: Array) -> int:
	var b: Dictionary = sim.buildings.get(step[0], {})
	var level: int = 0 if b.is_empty() else b.level + 1
	return int(Level.stats(step[1], mini(level, Level.BUILDINGS[step[1]].levels.size() - 1)).cost)


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
