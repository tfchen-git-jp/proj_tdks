class_name Bot
extends RefCounted
## A simple player for demos, tests and balance runs. Build phase: follow
## PLAN (buy each step when it can afford it), sweep up coins, then start
## the wave. Attack phase: sweep up coins, else stand off the road beside
## the enemy nearest the keep.

## [spot id, building] in order; a repeated pair upgrades it.
const PLAN := [
	["k_east", "archer"], ["k_west", "archer"], ["e_in", "archer"], ["f_1", "farm"],
	["w_in", "archer"], ["e_mid", "frost"], ["g_centre", "gate"], ["w_mid", "mortar"],
	["k_east", "archer"], ["k_west", "archer"], ["f_3", "farm"], ["c_far", "ballista"],
	["g_east", "gate"], ["g_west", "gate"], ["w_out", "archer"],
	["e_in", "archer"], ["w_in", "archer"], ["w_mid", "mortar"], ["f_1", "farm"],
	["e_mid", "frost"], ["c_far", "ballista"], ["k_east", "archer"], ["k_west", "archer"],
]

var sim: Sim
var _step := 0


func _init(s: Sim) -> void:
	sim = s


func move() -> Vector2:
	var target := _target()
	var v := Vector2(target.x - sim.hero_pos.x, target.z - sim.hero_pos.z)
	if v.length() < 0.15:
		return Vector2.ZERO
	return v.normalized() * clampf(v.length() / 0.6, 0.3, 1.0)


func _target() -> Vector3:
	if sim.phase == "build":
		# Buy the next affordable plan step, walking to its spot first.
		while _step < PLAN.size() and _done(PLAN[_step]):
			_step += 1
		if _step < PLAN.size() and sim.coins >= _cost(PLAN[_step]):
			var spot := _spot(PLAN[_step][0])
			if sim.hero_pos.distance_to(spot.pos) < Level.SPOT_REACH * 0.8:
				sim.buy(spot.id, PLAN[_step][1])
			return spot.pos
		var coin := _nearest_coin()
		if coin != Vector3.INF:
			return coin
		if sim.at_start_spot():
			sim.start_wave()
		return Level.START_SPOT
	var coin := _nearest_coin()
	if coin != Vector3.INF:
		return coin
	var lead := sim.horde.first_in_range(sim.hero_pos, 1000.0)
	if lead >= 0:
		var t: Track = sim.tracks[sim.horde.lane[lead]]
		return t.point(clampf(sim.horde.d[lead], 0.0, t.length - 4.0), -3.0)
	return Level.HERO_START


## Has this plan step happened (built, or upgraded to its repeat count)?
func _done(step: Array) -> bool:
	var want := 0
	for k in _step + 1:
		if PLAN[k][0] == step[0] and PLAN[k][1] == step[1]:
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
