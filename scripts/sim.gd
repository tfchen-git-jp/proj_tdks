class_name Sim
extends RefCounted
## The whole game's rules, free of nodes and rendering: main.gd feeds it a
## move vector each step, calls buy() / start_wave() from the popups, and
## draws what it reports. Headless balance runs and the tests drive this
## same class.
##
## Phases: "build" (no enemies; stand on a spot to build or upgrade, stand
## on the start spot to begin the next wave) and "attack" (the wave walks
## in; no building). Six waves; clearing the last one wins.

const DROP_CAP := 1400
const FLY_TIME := 0.22  # coin flight to the hero, s
## Where shots leave from, above the ground (m).
const MUZZLE := {hero = 0.9, archer = 2.3, ballista = 2.2, mortar = 1.7}
const ARROW_SPEED := 15.0
const BALLISTA_SPEED := 30.0
const SHELL_TIME := 1.0  # mortar flight, s
const CHEST := 0.5  # aim point above an enemy's feet

var tracks: Array[Track] = []
var horde: Horde
var time := 0.0
var wave_time := 0.0
var phase := "build"  # build / attack
var wave := 0  # the wave being fought (attack) or coming next (build)
var state := "play"  # play / win / lose
var coins: int = Level.START_GOLD
var collected := 0
var base_hp: int = Level.BASE_HP

var hero_pos: Vector3 = Level.HERO_START
var hero_vel := Vector3.ZERO
var hero_aim := Vector3.ZERO  # last shot direction (zero = none yet)
var hero_aim_t := 9.0  # seconds since the last shot
var _hero_cd := 0.0

## Built things by spot id: {spot, kind, level, cd, aim, pos, broken}.
var buildings := {}
## Flying shots: {kind, from, to, uid, t, dur, arc, dmg, splash, hits}.
var projectiles: Array[Dictionary] = []

## Coins on the ground (fly < 0) or flying to the hero (fly = seconds).
var drop_pos := PackedVector3Array()
var drop_val := PackedInt32Array()
var drop_fly := PackedFloat32Array()
var drop_from := PackedVector3Array()

## Things that happened this step, for sound and effects:
## shot / hit / boom / pulse / kill / pay / built / gate_broken /
## wave_start / wave_cleared / base_hit.
var events: Array[Dictionary] = []
var _pending: Array[Dictionary] = []  # from buy() / start_wave() between steps

var _spawned: Array[int] = []
var _rng := RandomNumberGenerator.new()


func _init(seed_value := 1) -> void:
	_rng.seed = seed_value
	for pts in Level.LANES:
		tracks.push_back(Track.new(pts))
	horde = Horde.new(tracks, seed_value)


func step(dt: float, move: Vector2) -> void:
	events = _pending
	_pending = []
	time += dt
	_hero_move(dt, move if state == "play" else Vector2.ZERO)
	if state != "play":
		return
	if phase == "attack":
		wave_time += dt
		_spawn()
	_hero_shoot(dt)
	_towers(dt)
	_projectiles(dt)
	horde.step(dt)
	_gates()
	_drops_from_deaths()
	_drops_step(dt)
	if horde.leaked > 0:
		base_hp -= horde.leaked
		horde.leaked = 0
		events.push_back({type = "base_hit"})
	if base_hp <= 0:
		base_hp = 0
		state = "lose"
		return
	if phase == "attack" and _wave_spawned() and horde.count() == 0:
		_end_wave()


# --- phases ----------------------------------------------------------------

func at_start_spot() -> bool:
	return phase == "build" and hero_pos.distance_to(Level.START_SPOT) < Level.SPOT_REACH


func start_wave() -> bool:
	if phase != "build" or state != "play":
		return false
	phase = "attack"
	wave_time = 0.0
	_spawned.clear()
	for g in Level.WAVES[wave]:
		_spawned.push_back(0)
	_pending.push_back({type = "wave_start", wave = wave})
	return true


func _spawn() -> void:
	var groups: Array = Level.WAVES[wave]
	for i in groups.size():
		var g: Dictionary = groups[i]
		while _spawned[i] < int(g.count) and wave_time >= float(g.t) + _spawned[i] * float(g.every):
			horde.spawn(int(g.type), int(g.lane))
			_spawned[i] += 1


func _wave_spawned() -> bool:
	var groups: Array = Level.WAVES[wave]
	for i in groups.size():
		if _spawned[i] < int(groups[i].count):
			return false
	return true


func _end_wave() -> void:
	var income := 0
	for b in buildings.values():
		if b.kind == "farm":
			income += int(Level.stats("farm", b.level).income)
		if b.kind == "gate":  # repaired for the next wave
			b.broken = false
			_raise_gate(b)
	coins += income
	events.push_back({type = "wave_cleared", wave = wave, income = income})
	wave += 1
	phase = "build"
	if wave >= Level.WAVES.size():
		state = "win"


# --- building -----------------------------------------------------------------

## The spot the hero stands at (build phase only), or {}.
func spot_under_hero() -> Dictionary:
	if phase != "build" or state != "play":
		return {}
	for s in Level.SPOTS:
		if hero_pos.distance_to(s.pos) < Level.SPOT_REACH:
			return s
	return {}


## What can be done at a spot: [{kind, level, cost, name, desc, upgrade, ok}].
## An empty spot offers every building of its kind; a built one offers its
## next level (none at max).
func options(spot: Dictionary) -> Array:
	var out := []
	var b: Dictionary = buildings.get(spot.id, {})
	if b.is_empty():
		for kind in Level.BUILDINGS:
			if Level.BUILDINGS[kind].spot == spot.kind:
				out.push_back(_option(kind, 0, false))
	elif b.level + 1 < Level.BUILDINGS[b.kind].levels.size():
		out.push_back(_option(b.kind, b.level + 1, true))
	return out


func _option(kind: String, level: int, upgrade: bool) -> Dictionary:
	var cost := int(Level.stats(kind, level).cost)
	return {kind = kind, level = level, cost = cost, upgrade = upgrade, ok = coins >= cost,
		name = Level.BUILDINGS[kind].name, desc = Level.BUILDINGS[kind].desc}


## Build `kind` on an empty spot, or upgrade what stands there. Returns
## true if it happened (enough gold, right phase).
func buy(spot_id: String, kind: String) -> bool:
	if phase != "build" or state != "play":
		return false
	var spot: Dictionary = {}
	for s in Level.SPOTS:
		if s.id == spot_id:
			spot = s
	if spot.is_empty() or Level.BUILDINGS[kind].spot != spot.kind:
		return false
	var b: Dictionary = buildings.get(spot_id, {})
	var level := 0
	if not b.is_empty():
		if b.kind != kind or b.level + 1 >= Level.BUILDINGS[kind].levels.size():
			return false
		level = b.level + 1
	var cost := int(Level.stats(kind, level).cost)
	if coins < cost:
		return false
	coins -= cost
	if b.is_empty():
		b = {spot = spot, kind = kind, level = 0, cd = 0.5, aim = Vector3(0, 0, 1), pos = spot.pos, broken = false}
		buildings[spot_id] = b
	else:
		b.level = level
	if kind == "gate":
		_raise_gate(b)
	_pending.push_back({type = "built", spot = spot, kind = kind, level = level, cost = cost})
	return true


func _raise_gate(b: Dictionary) -> void:
	var ln := int(b.spot.lane)
	horde.gate_d[ln] = tracks[ln].closest_d(b.spot.pos)
	horde.gate_hp[ln] = float(Level.stats("gate", b.level).hp)


func gate_hp_frac(ln: int) -> float:
	for b in buildings.values():
		if b.kind == "gate" and int(b.spot.lane) == ln and not b.broken:
			return clampf(horde.gate_hp[ln] / float(Level.stats("gate", b.level).hp), 0.0, 1.0)
	return 0.0


func _gates() -> void:
	for b in buildings.values():
		if b.kind != "gate" or b.broken:
			continue
		var ln := int(b.spot.lane)
		if horde.gate_hp[ln] <= 0.0:
			b.broken = true
			horde.gate_d[ln] = -1.0
			events.push_back({type = "gate_broken", lane = ln, spot = b.spot})


## Solid things as [centre, radius]: the keep and every building but gates.
func obstacles() -> Array:
	var out := [[Level.KEEP_POS, 1.9]]
	for b in buildings.values():
		if b.kind != "gate":
			out.push_back([b.pos, 0.75 if b.kind != "farm" else 0.9])
	return out


## Attack-speed bonus from War Banners covering point p (best one counts).
func banner_buff(p: Vector3) -> float:
	var best := 0.0
	for b in buildings.values():
		if b.kind == "banner":
			var st := Level.stats("banner", b.level)
			if Vector2(p.x - b.pos.x, p.z - b.pos.z).length() <= float(st.range):
				best = maxf(best, float(st.buff))
	return best


# --- hero ------------------------------------------------------------------------

func _hero_move(dt: float, move: Vector2) -> void:
	if move.length() > 1.0:
		move = move.normalized()
	var v := Vector3(move.x, 0.0, move.y) * float(Level.HERO.speed)
	var p := hero_pos + v * dt
	var b := Level.BOUNDS
	p.x = clampf(p.x, b.position.x, minf(b.end.x, Level.CLIFF_X - 0.4))
	p.z = clampf(p.z, b.position.y, b.end.y)
	for o in obstacles():
		var q: Vector3 = o[0]
		var r: float = o[1] + 0.3
		var dv := Vector2(p.x - q.x, p.z - q.z)
		if dv.length() < r:
			dv = (dv if dv.length() > 0.001 else Vector2(0, 1)).normalized() * r
			p.x = q.x + dv.x
			p.z = q.z + dv.y
	hero_vel = (p - hero_pos) / maxf(dt, 0.0001)
	hero_pos = p


func _hero_shoot(dt: float) -> void:
	_hero_cd -= dt * (1.0 + banner_buff(hero_pos))
	hero_aim_t += dt
	if _hero_cd > 0.0:
		return
	var i := horde.nearest(hero_pos, float(Level.HERO.range))
	if i < 0:
		return
	_hero_cd = float(Level.HERO.interval)
	var to := horde.pos[i] + Vector3(0, CHEST, 0)
	var from := hero_pos + Vector3(0, MUZZLE.hero, 0)
	hero_aim = Vector3(to.x - from.x, 0, to.z - from.z).normalized()
	hero_aim_t = 0.0
	_launch("bolt", from, to, horde.uid[i], from.distance_to(to) / float(Level.HERO.bolt_speed),
		0.05, float(Level.HERO.damage))
	events.push_back({type = "shot", kind = "hero", from = from})


# --- towers -----------------------------------------------------------------------

func _towers(dt: float) -> void:
	for b in buildings.values():
		if not b.kind in Level.TOWER_KINDS or b.kind == "banner":
			continue
		var st := Level.stats(b.kind, b.level)
		b.cd -= dt * (1.0 + banner_buff(b.pos))
		if b.cd > 0.0:
			continue
		match String(b.kind):
			"archer": _fire_archer(b, st)
			"ballista": _fire_ballista(b, st)
			"mortar": _fire_mortar(b, st)
			"frost": _pulse_frost(b, st)


func _fire_archer(b: Dictionary, st: Dictionary) -> void:
	var i := horde.first_in_range(b.pos, float(st.range))
	if i < 0:
		return
	b.cd = float(st.interval)
	var from: Vector3 = b.pos + Vector3(0, MUZZLE.archer, 0)
	var to := horde.pos[i] + Vector3(0, CHEST, 0)
	b.aim = Vector3(to.x - from.x, 0, to.z - from.z).normalized()
	var dist := from.distance_to(to)
	_launch("arrow", from, to, horde.uid[i], dist / ARROW_SPEED, dist * 0.12, float(st.damage))
	events.push_back({type = "shot", kind = "archer", from = from})


func _fire_ballista(b: Dictionary, st: Dictionary) -> void:
	var i := horde.first_in_range(b.pos, float(st.range))
	if i < 0:
		return
	b.cd = float(st.interval)
	var dir: Vector3 = horde.pos[i] - b.pos
	dir.y = 0.0
	dir = dir.normalized()
	b.aim = dir
	var from: Vector3 = b.pos + Vector3(0, MUZZLE.ballista, 0)
	var end: Vector3 = b.pos + dir * (float(st.range) + 1.5) + Vector3(0, CHEST, 0)
	var dur := from.distance_to(end) / BALLISTA_SPEED
	# Every enemy on the line is hit when the bolt reaches it.
	var hits := []
	for h in horde.on_segment(b.pos, b.pos + dir * (float(st.range) + 1.5), 0.3, int(st.pierce)):
		hits.push_back([h.x * dur, horde.uid[int(h.y)]])
	var p := _launch("ballista", from, end, -1, dur, 0.0, float(st.damage))
	p.hits = hits
	events.push_back({type = "shot", kind = "ballista", from = from})


func _fire_mortar(b: Dictionary, st: Dictionary) -> void:
	var i := horde.first_in_range(b.pos, float(st.range), float(st.min_range))
	if i < 0:
		return
	b.cd = float(st.interval)
	# Lead the target: land where it will be when the shell comes down.
	var lead: Vector3 = horde.forward(i) * Level.ENEMIES[horde.kind[i]].speed * (1.0 - horde.slow[i]) * SHELL_TIME
	if horde.blocked[i] != 0:
		lead = Vector3.ZERO
	var land: Vector3 = horde.pos[i] + lead
	b.aim = Vector3(land.x - b.pos.x, 0, land.z - b.pos.z).normalized()
	var p := _launch("shell", b.pos + Vector3(0, MUZZLE.mortar, 0), land, -1, SHELL_TIME, 3.5, float(st.damage))
	p.splash = float(st.splash)
	events.push_back({type = "shot", kind = "mortar", from = b.pos})


func _pulse_frost(b: Dictionary, st: Dictionary) -> void:
	var hit := horde.within(b.pos, float(st.range))
	if hit.is_empty():
		return
	b.cd = float(st.interval)
	for i in hit:
		horde.chill(i, float(st.slow), float(st.slow_time))
		horde.damage(i, float(st.damage))
	events.push_back({type = "pulse", pos = b.pos, r = float(st.range)})


# --- projectiles --------------------------------------------------------------------

func _launch(kind: String, from: Vector3, to: Vector3, target: int, dur: float, arc: float, dmg: float) -> Dictionary:
	var p := {kind = kind, from = from, to = to, uid = target, t = 0.0, dur = maxf(dur, 0.05),
		arc = arc, dmg = dmg, splash = 0.0, hits = []}
	projectiles.push_back(p)
	return p


## Where projectile p is at its time t (arc over a lerp).
static func proj_pos(p: Dictionary, t: float) -> Vector3:
	var s := clampf(t / float(p.dur), 0.0, 1.0)
	var from: Vector3 = p.from
	return from.lerp(p.to, s) + Vector3(0, float(p.arc) * 4.0 * s * (1.0 - s), 0)


func _projectiles(dt: float) -> void:
	var keep: Array[Dictionary] = []
	for p in projectiles:
		p.t += dt
		# Homing shots follow their target while it lives.
		if p.uid >= 0:
			var i := horde.index_of(p.uid)
			if i >= 0:
				p.to = horde.pos[i] + Vector3(0, CHEST, 0)
		# Ballista bolts hit each enemy on the line as they reach it.
		if not p.hits.is_empty():
			var rest := []
			for h in p.hits:
				if p.t >= h[0]:
					var i := horde.index_of(h[1])
					if i >= 0:
						horde.damage(i, p.dmg)
						events.push_back({type = "hit", pos = horde.pos[i], kind = "ballista"})
				else:
					rest.push_back(h)
			p.hits = rest
		if p.t < p.dur:
			keep.push_back(p)
			continue
		match String(p.kind):
			"bolt", "arrow":
				var i := horde.index_of(p.uid)
				if i >= 0:
					horde.damage(i, p.dmg)
					events.push_back({type = "hit", pos = horde.pos[i], kind = p.kind})
			"shell":
				for i in horde.within(p.to, p.splash):
					horde.damage(i, p.dmg)
				events.push_back({type = "boom", pos = p.to, r = p.splash})
	projectiles = keep


# --- coins ----------------------------------------------------------------------------

func _drops_from_deaths() -> void:
	for death in horde.deaths:
		events.push_back({type = "kill", pos = death.pos, kind = death.kind, d = death.d, lane = death.lane})
		var gold := int(Level.ENEMIES[death.kind].gold)
		var pieces := mini(gold, 5)
		var spread := 0.35 if death.kind != Level.BRUTE else 1.1
		for k in pieces:
			var v := floori(float(gold) / pieces) + (1 if k < gold % pieces else 0)
			var p: Vector3 = death.pos + Vector3(_rng.randf_range(-spread, spread), 0.0, _rng.randf_range(-spread, spread))
			if drop_pos.size() >= DROP_CAP:
				drop_val[_rng.randi() % drop_val.size()] += v
				continue
			drop_pos.push_back(p)
			drop_val.push_back(v)
			drop_fly.push_back(-1.0)
			drop_from.push_back(p)
	horde.deaths.clear()


func _drops_step(dt: float) -> void:
	var r2 := float(Level.HERO.magnet) * float(Level.HERO.magnet)
	var i := 0
	while i < drop_pos.size():
		if drop_fly[i] < 0.0:
			var q := drop_pos[i]
			if (q.x - hero_pos.x) * (q.x - hero_pos.x) + (q.z - hero_pos.z) * (q.z - hero_pos.z) < r2:
				drop_fly[i] = 0.0
				drop_from[i] = q
			i += 1
			continue
		drop_fly[i] += dt
		var t := drop_fly[i] / FLY_TIME
		if t >= 1.0:
			coins += drop_val[i]
			collected += drop_val[i]
			events.push_back({type = "coin"})
			_remove_drop(i)
			continue
		var p := drop_from[i].lerp(hero_pos + Vector3(0, 0.8, 0), t)
		p.y += sin(t * PI) * 0.9
		drop_pos[i] = p
		i += 1


func _remove_drop(i: int) -> void:
	var last := drop_pos.size() - 1
	drop_pos[i] = drop_pos[last]; drop_val[i] = drop_val[last]
	drop_fly[i] = drop_fly[last]; drop_from[i] = drop_from[last]
	drop_pos.resize(last); drop_val.resize(last); drop_fly.resize(last); drop_from.resize(last)
