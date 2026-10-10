class_name Horde
extends RefCounted
## Every enemy as parallel arrays, no nodes: hundreds stay cheap and the
## rules run headless in tests. Indices are stable within one step();
## dead enemies are swap-removed at the end of it. `uid` is stable for an
## enemy's whole life (projectiles in flight track their target by it).

var tracks: Array[Track] = []  # one per lane
var entry := PackedFloat32Array()  # per lane: the start line (road distance)
var kind := PackedInt32Array()
var lane := PackedInt32Array()
var uid := PackedInt32Array()
var hp := PackedFloat32Array()
var max_hp := PackedFloat32Array()  # with the wave's toughness (HP bars)
var d := PackedFloat32Array()  # metres along its lane
var off := PackedFloat32Array()  # metres right of the walking direction
var spd := PackedFloat32Array()
var gap := PackedFloat32Array()  # how far short of a gate this one stops (at the wall)
var phase := PackedFloat32Array()  # walk (or, when blocked, attack) cycle, radians
var flash := PackedFloat32Array()  # hit-flash timer, s
var slow := PackedFloat32Array()  # current slow fraction (0..1)
var slow_t := PackedFloat32Array()  # seconds the slow lasts
var burn_dps := PackedFloat32Array()  # Fire Bolts: damage per second while burning
var burn_t := PackedFloat32Array()  # seconds it keeps burning
var burn_src := PackedByteArray()  # who lit it: 0 the hero (Fire Bolts), 1 a Fire Mortar
var power := PackedFloat32Array()  # damage multiplier (an enraged boss)
var mult := PackedFloat32Array()  # the HP multiplier it spawned with (a slime's brood gets the same)
var freeze_t := PackedFloat32Array()  # seconds frozen solid (Glacier): no walking, no attacks
var brittle := PackedFloat32Array()  # extra damage taken (Frostbite) ...
var brittle_t := PackedFloat32Array()  # ... for this many seconds
var immune := PackedByteArray()  # 1 = slows and freezes don't work (the berserk boss)
## Per enemy this step: the best haste from a captain nearby (walk and
## attack x 1 + haste), and whether a bone mage is healing it (view).
var haste := PackedFloat32Array()
var healed := PackedByteArray()
var stage := PackedInt32Array()  # boss phase reached (Sim._bosses)
var blocked := PackedByteArray()  # 1 = at the gate, hitting it; 2 = held up
                                  # behind another enemy in the queue; 0 = walking
var pos := PackedVector3Array()
## pos and phase at the start of the last step(): the view draws between
## them and the current ones (the sim runs at 60 Hz, the screen doesn't).
var prev_pos := PackedVector3Array()
var prev_phase := PackedFloat32Array()

## Per gate slot (Level.SPOTS `slot`), set by the game: its lane, road
## distance (-1 = none) and HP. An enemy is held by the first standing
## gate ahead of it on its lane. Slots 0-2 are lanes 0-2 (tests use them).
var gate_lane := PackedInt32Array([0, 1, 2, 0, 1, 2])
var gate_d := PackedFloat32Array([-1.0, -1.0, -1.0, -1.0, -1.0, -1.0])
var gate_hp := PackedFloat32Array([0.0, 0.0, 0.0, 0.0, 0.0, 0.0])
## Per gate slot, set by the game: fraction of damage blocked (Engineer).
var gate_armor := PackedFloat32Array([0.0, 0.0, 0.0, 0.0, 0.0, 0.0])
## The keep: every lane ends at it. Enemies that get there stop and attack
## it like a gate (queueing the same way) until killed; one HP pool.
var keep_hp := 1e9

## Results since the caller last drained them.
var deaths: Array[Dictionary] = []  # {pos, kind, d, lane, off, mult}
var killed := 0
var dealt := 0.0  # all damage taken (balance stats)
var burn_dealt := 0.0  # of which by burning (Fire Bolts)
var burn_mortar := 0.0  # ... and by Fire Mortars' flames
## Damage done to gates and the keep, by enemy type (end-of-game stats).
var wall_dmg := PackedFloat32Array()
## Ranged enemies' shots this step, for the view: [from, to].
var shots: Array = []

var _rng := RandomNumberGenerator.new()
var _next_uid := 1
var _index := {}  # uid -> index, rebuilt every step

## Half thickness of the gate wall (Models.gate depth), m.
const GATE_HALF_DEPTH := 0.55
## The queue at a gate only sorts out enemies this close to it, m.
const QUEUE_ZONE := 8.0
## How far past its lane's end an enemy may walk to reach the keep, m.
const KEEP_REACH := 1.0
## Shoved light enemies sidestep this fast (m/s), at most this far off the
## lane's centre (m); a heavy one drifts to the centre this fast near a gate.
const SHOVE_SPEED := 3.0
const SHOVE_EDGE := Level.ROAD_HALF_WIDTH + 0.1
const HEAVY_CENTRING := 0.5


func _init(lane_tracks: Array[Track], seed_value := 1) -> void:
	tracks = lane_tracks
	_rng.seed = seed_value
	wall_dmg.resize(Level.ENEMIES.size())
	for t in tracks:
		entry.push_back(start_line(t))


## Road distance where a lane comes within START_LINE_OUT of the hero's
## walkable area: enemies before it can't be hit yet.
static func start_line(t: Track) -> float:
	var reach := Level.BOUNDS.grow(Level.START_LINE_OUT)
	var dd := 0.0
	while dd < t.length:
		var p := t.point(dd)
		if reach.has_point(Vector2(p.x, p.z)):
			return dd
		dd += 0.25
	return 0.0


func count() -> int:
	return kind.size()


## hp_mult: the wave's toughness (Level.wave_hp; Sim gives bosses their
## own). at_d >= 0: appear there (a boss's summons, a slime's brood)
## instead of at the lane's start; at_off: across the road there too.
func spawn(type: int, ln: int, hp_mult := 1.0, at_d := -1.0, at_off := INF) -> void:
	var e: Dictionary = Level.ENEMIES[type]
	var lim := Level.ROAD_HALF_WIDTH - float(e.radius) * 0.6
	kind.push_back(type)
	lane.push_back(ln)
	uid.push_back(_next_uid)
	_index[_next_uid] = kind.size() - 1
	_next_uid += 1
	hp.push_back(float(e.hp) * hp_mult)
	power.push_back(1.0)
	mult.push_back(hp_mult)
	freeze_t.push_back(0.0)
	brittle.push_back(0.0)
	brittle_t.push_back(0.0)
	immune.push_back(0)
	haste.push_back(0.0)
	healed.push_back(0)
	stage.push_back(0)
	max_hp.push_back(float(e.hp) * hp_mult)
	d.push_back(_rng.randf_range(0.0, 0.6) if at_d < 0.0 else at_d)
	if float(e.get("ranged", 0.0)) > 0.0:  # along the road's edges, out of the queue's way
		off.push_back(_rng.randf_range(0.55, 0.95) * (1.0 if _rng.randf() < 0.5 else -1.0))
	elif e.get("flies", false):
		off.push_back(_rng.randf_range(-1.3, 1.3))
	else:
		off.push_back(_rng.randf_range(-lim, lim) if not e.get("heavy", false) else _rng.randf_range(-0.3, 0.3))
	spd.push_back(float(e.speed) * _rng.randf_range(0.9, 1.1))
	gap.push_back(GATE_HALF_DEPTH + float(e.radius) * 0.8 + _rng.randf_range(0.0, 0.25)
		if float(e.get("ranged", 0.0)) <= 0.0 else _rng.randf_range(0.0, 1.6))
	phase.push_back(_rng.randf() * TAU)
	flash.push_back(0.0)
	slow.push_back(0.0)
	slow_t.push_back(0.0)
	burn_dps.push_back(0.0)
	burn_t.push_back(0.0)
	burn_src.push_back(0)
	blocked.push_back(0)
	if at_off != INF:
		off[off.size() - 1] = clampf(at_off, -lim, lim)
	pos.push_back(tracks[ln].point(d[d.size() - 1], off[off.size() - 1]))
	# Spawned mid-step (a slime's brood): the view interpolates from here.
	if prev_pos.size() < pos.size():
		prev_pos.push_back(pos[pos.size() - 1])
		prev_phase.push_back(phase[phase.size() - 1])


## Index of the living enemy with this uid, or -1.
func index_of(id: int) -> int:
	var i: int = _index.get(id, -1)
	return i if i >= 0 and i < count() and uid[i] == id and hp[i] > 0.0 else -1


## Can towers and the hero hit it yet (past its lane's start line)?
func targetable(i: int) -> bool:
	return hp[i] > 0.0 and d[i] >= entry[lane[i]]


## Deal damage; returns true if this hit killed it. Hits on the already
## dead (hp <= 0, waiting for removal) do nothing.
## armored: false for burning and the Sniper (armour doesn't stop them).
## A brittle enemy (Frostbite) takes its extra share.
func damage(i: int, amount: float, flashes := true, armored := true) -> bool:
	if hp[i] <= 0.0:
		return false
	if brittle_t[i] > 0.0:
		amount *= 1.0 + brittle[i]
	if armored:
		var ar := float(Level.ENEMIES[kind[i]].get("armor", 0.0))
		if ar > 0.0:
			amount = maxf(amount - ar, amount * Level.ARMOR_FLOOR)
	dealt += minf(amount, hp[i])
	hp[i] -= amount
	if flashes:
		flash[i] = 0.12
	if hp[i] <= 0.0:
		killed += 1
		deaths.push_back({pos = pos[i], kind = kind[i], d = d[i], lane = lane[i], off = off[i], mult = mult[i]})
		return true
	return false


## Set enemy i ablaze (the stronger burn wins; the timer restarts). src:
## "hero" or "mortar" (whose damage it counts as).
func ignite(i: int, dps: float, seconds: float, src := "hero") -> void:
	if dps >= burn_dps[i]:
		burn_src[i] = 1 if src == "mortar" else 0
	burn_dps[i] = maxf(burn_dps[i], dps)
	burn_t[i] = maxf(burn_t[i], seconds)


## Slow enemy i (walking and attacks); not a berserk boss.
func chill(i: int, fraction: float, seconds: float) -> void:
	if immune[i]:
		return
	slow[i] = maxf(slow[i], fraction)
	slow_t[i] = maxf(slow_t[i], seconds)


## Freeze enemy i solid (Glacier): it neither walks nor attacks. Bosses
## thaw in half the time.
const BOSS_FREEZE := 0.5


func freeze(i: int, seconds: float) -> void:
	if immune[i]:
		return
	if Level.ENEMIES[kind[i]].get("boss", false):
		seconds *= BOSS_FREEZE
	freeze_t[i] = maxf(freeze_t[i], seconds)


## Frostbite: enemy i takes `extra` more damage for `seconds`.
func make_brittle(i: int, extra: float, seconds: float) -> void:
	brittle[i] = maxf(brittle[i], extra)
	brittle_t[i] = maxf(brittle_t[i], seconds)


## Slows and freezes stop working on enemy i, and any on it end (a boss
## going berserk).
func make_immune(i: int) -> void:
	immune[i] = 1
	slow[i] = 0.0
	slow_t[i] = 0.0
	freeze_t[i] = 0.0


## How much slower enemy i acts now: 1 = normal, 0 = frozen (slow and
## haste included).
func pace(i: int) -> float:
	if freeze_t[i] > 0.0:
		return 0.0
	return (1.0 - slow[i]) * (1.0 + haste[i])


## Walking direction of enemy i.
func forward(i: int) -> Vector3:
	return tracks[lane[i]].forward(d[i])


func step(dt: float) -> void:
	prev_pos = pos.duplicate()
	prev_phase = phase.duplicate()
	var n := count()
	var prev := d.duplicate()
	_auras(dt)
	# 1. Everyone walks; nobody passes a standing gate on their lane.
	for i in n:
		if hp[i] <= 0.0:
			continue
		flash[i] = maxf(flash[i] - dt, 0.0)
		if burn_t[i] > 0.0:
			burn_t[i] -= dt
			var before := dealt
			var died := damage(i, burn_dps[i] * dt, false, false)
			if burn_src[i] == 1:
				burn_mortar += dealt - before
			else:
				burn_dealt += dealt - before
			if died:
				continue
			if burn_t[i] <= 0.0:
				burn_dps[i] = 0.0
		slow_t[i] -= dt
		if slow_t[i] <= 0.0:
			slow[i] = 0.0
		freeze_t[i] = maxf(freeze_t[i] - dt, 0.0)
		brittle_t[i] -= dt
		var nd := d[i] + spd[i] * pace(i) * dt
		blocked[i] = 0
		var stop := d[i] + 1e9
		var rng_r := float(Level.ENEMIES[kind[i]].get("ranged", 0.0))
		var g := gate_of(i)
		if g >= 0:
			stop = gate_d[g] - (gap[i] if rng_r <= 0.0 else rng_r + gap[i])
		else:
			stop = tracks[lane[i]].length - (_keep_gap(i) if rng_r <= 0.0 else rng_r + gap[i])
		if nd >= stop:
			nd = maxf(stop, d[i])
			blocked[i] = 1
		d[i] = nd
	# 2. Near a standing gate and at the keep, queue: nobody overlaps the one
	# ahead of them in their lane, so the back ranks wait and step up.
	for g in gate_d.size():
		if gate_d[g] >= 0.0 and gate_hp[g] > 0.0:
			_queue(gate_lane[g], gate_d[g], g, prev, dt)
	for ln in tracks.size():
		_queue(ln, tracks[ln].length + KEEP_REACH, -1, prev, dt)
	# 3. Gate / keep damage, animation phase, positions.
	shots.clear()
	for i in n:
		if hp[i] <= 0.0:
			continue
		var e: Dictionary = Level.ENEMIES[kind[i]]
		# Frost slows attacks as much as walking (swing and damage); a
		# captain's haste speeds both up.
		var pc := pace(i)
		if blocked[i] == 1:
			var dmg := float(e.dps) * power[i] * pc * dt
			var g := gate_of(i)
			if g >= 0:
				dmg *= 1.0 - gate_armor[g]
				gate_hp[g] -= dmg
			else:
				keep_hp -= dmg
			wall_dmg[kind[i]] += dmg
		if blocked[i] == 0:
			phase[i] += spd[i] * pc * dt * 7.0
		else:
			var inc := pc * dt * TAU / float(e.get("cycle", Level.ATTACK_CYCLE))
			# A ranged attacker looses a bolt once per attack cycle.
			if blocked[i] == 1 and float(e.get("ranged", 0.0)) > 0.0 and floori((phase[i] + inc) / TAU) > floori(phase[i] / TAU):
				shots.push_back([pos[i] + Vector3(0, 1.0, 0), _wall_point(i)])
			phase[i] += inc
		pos[i] = tracks[lane[i]].point(d[i], off[i])
		if e.get("flies", false):
			pos[i].y += float(e.fly_h) + 0.18 * sin(phase[i] * 0.5)
	_compact()


## Support enemies: bone mages heal and captains hasten everyone within
## their aura (themselves included, bosses never); the best one counts.
func _auras(dt: float) -> void:
	var n := count()
	var heal := PackedFloat32Array()
	heal.resize(n)
	for i in n:
		haste[i] = 0.0
		healed[i] = 0
	for j in n:
		var ej: Dictionary = Level.ENEMIES[kind[j]]
		if hp[j] <= 0.0 or not ej.has("aura") or not targetable(j):
			continue
		var r := float(ej.aura)
		var pj := pos[j]
		for i in n:
			if hp[i] <= 0.0 or Level.ENEMIES[kind[i]].get("boss", false):
				continue
			var q := pos[i]
			if (q.x - pj.x) * (q.x - pj.x) + (q.z - pj.z) * (q.z - pj.z) > r * r:
				continue
			haste[i] = maxf(haste[i], float(ej.get("haste", 0.0)))
			heal[i] = maxf(heal[i], float(ej.get("heal", 0.0)))
	for i in n:
		if heal[i] > 0.0 and hp[i] > 0.0 and hp[i] < max_hp[i]:
			hp[i] = minf(max_hp[i], hp[i] + max_hp[i] * heal[i] * dt)
			healed[i] = 1


## The gate slot holding enemy i up: the nearest standing gate ahead of it
## on its lane, or -1 (none, or it flies).
func gate_of(i: int) -> int:
	if Level.ENEMIES[kind[i]].get("flies", false):
		return -1
	var best := -1
	for g in gate_d.size():
		if gate_lane[g] == lane[i] and gate_d[g] >= 0.0 and gate_hp[g] > 0.0 and d[i] < gate_d[g] \
				and (best < 0 or gate_d[g] < gate_d[best]):
			best = g
	return best


func _at_gate(i: int) -> bool:
	return gate_of(i) >= 0


## Where enemy i's attacks land: its gate, or the keep.
func _wall_point(i: int) -> Vector3:
	var g := gate_of(i)
	if g >= 0:
		return tracks[lane[i]].point(gate_d[g]) + Vector3(0, 1.0, 0)
	return Level.KEEP_POS + Vector3(0, 1.5, 0)


## Walks in the gate / keep queue (not flyers, not ranged attackers).
func queues(i: int) -> bool:
	var e: Dictionary = Level.ENEMIES[kind[i]]
	return not e.get("flies", false) and float(e.get("ranged", 0.0)) <= 0.0


## How far short of its lane's end enemy i stops (negative: past it, up to
## the keep's steps; lanes end a little before the keep).
func _keep_gap(i: int) -> float:
	return float(Level.ENEMIES[kind[i]].radius) * 0.8 - KEEP_REACH


## Front-to-back over the enemies close behind wall `gd` (gate slot `slot`
## on lane `ln`, or the keep at the lane's end when slot < 0): each may
## come no closer than its spacing to any enemy ahead that overlaps its
## lane position. Never pushes anyone backwards (from `prev`).
## Heavy enemies (giants) don't wait for light ones: the light ones just
## ahead of or beside a giant sidestep out of its path, and it walks
## through to the gate. Giants queue behind each other as usual, and one
## held within its reach of the gate hits it anyway.
func _queue(ln: int, gd: float, slot: int, prev: PackedFloat32Array, dt: float) -> void:
	var keep := slot < 0
	var near: Array = []
	for i in count():
		if hp[i] > 0.0 and lane[i] == ln and d[i] <= gd and gd - d[i] < QUEUE_ZONE and gate_of(i) == slot and queues(i):
			near.push_back(Vector2(d[i], i))
	near.sort()
	near.reverse()  # front (largest d) first
	# Shove: light ones in a giant's path step aside.
	for v in near:
		var i := int(v.y)
		if not Level.ENEMIES[kind[i]].get("heavy", false):
			continue
		off[i] = move_toward(off[i], 0.0, HEAVY_CENTRING * dt)
		var ri := float(Level.ENEMIES[kind[i]].radius)
		for w in near:
			var j := int(w.y)
			if Level.ENEMIES[kind[j]].get("heavy", false):
				continue
			var clear := (ri + float(Level.ENEMIES[kind[j]].radius)) * 0.8
			var ahead := d[j] - d[i]
			if ahead < -clear or ahead > clear * 1.5 or absf(off[j] - off[i]) >= clear:
				continue
			var side := signf(off[j] - off[i]) if absf(off[j] - off[i]) > 0.01 else (-1.0 if off[i] > 0.0 else 1.0)
			if absf(off[i] + side * clear) > SHOVE_EDGE:
				side = -side  # no room on that side of the road
			var goal := clampf(off[i] + side * clear, -SHOVE_EDGE, SHOVE_EDGE)
			off[j] = move_toward(off[j], goal, SHOVE_SPEED * dt)
	# Queue.
	var placed: Array[int] = []
	for v in near:
		var i := int(v.y)
		var ei: Dictionary = Level.ENEMIES[kind[i]]
		var heavy: bool = ei.get("heavy", false)
		var ri := float(ei.radius)
		var limit := d[i]
		var held := false
		for j in placed:
			if heavy and not Level.ENEMIES[kind[j]].get("heavy", false):
				continue  # it's being shoved aside
			var rj := float(Level.ENEMIES[kind[j]].radius)
			if absf(off[i] - off[j]) >= (ri + rj) * 0.8:
				continue
			var cap := d[j] - (ri + rj) * 0.75
			if cap < limit:
				limit = cap
				held = true
		if held:
			d[i] = maxf(limit, minf(prev[i], d[i]))
			var reach := float(ei.get("reach", 0.0))
			var stop_gap := _keep_gap(i) + KEEP_REACH if keep else gap[i]
			blocked[i] = 1 if reach > 0.0 and gd - d[i] <= stop_gap + reach else 2
		placed.push_back(i)


## Index of the targetable enemy nearest to `p` within `r`, or -1.
func nearest(p: Vector3, r: float) -> int:
	var best := r * r
	var best_i := -1
	for i in count():
		if not targetable(i):
			continue
		var q := pos[i]
		var dd := (q.x - p.x) * (q.x - p.x) + (q.z - p.z) * (q.z - p.z)
		if dd < best:
			best = dd
			best_i = i
	return best_i


## Up to k targetable enemies within r of p, nearest first, skipping the
## uids in `skip`.
func nearest_k(p: Vector3, r: float, k: int, skip: Array = []) -> Array[int]:
	var found: Array = []
	for i in count():
		if not targetable(i) or uid[i] in skip:
			continue
		var q := pos[i]
		var dd := (q.x - p.x) * (q.x - p.x) + (q.z - p.z) * (q.z - p.z)
		if dd < r * r:
			found.push_back(Vector2(dd, i))
	found.sort()
	var out: Array[int] = []
	for v in found.slice(0, k):
		out.push_back(int(v.y))
	return out


## Index of the targetable enemy closest to the keep (least road left)
## between `r_min` and `r` of `p` -- the classic TD "first" target -- or -1.
func first_in_range(p: Vector3, r: float, r_min := 0.0, ground_only := false) -> int:
	var best_left := INF
	var best_i := -1
	for i in count():
		if not targetable(i) or (ground_only and Level.ENEMIES[kind[i]].get("flies", false)):
			continue
		var left := tracks[lane[i]].length - d[i]
		if left >= best_left:
			continue
		var q := pos[i]
		var dd := (q.x - p.x) * (q.x - p.x) + (q.z - p.z) * (q.z - p.z)
		if dd < r * r and dd >= r_min * r_min:
			best_left = left
			best_i = i
	return best_i


## Up to k targetable enemies within r of p, the nearest to the keep first
## (a Repeater's arrows).
func first_k(p: Vector3, r: float, k: int) -> Array[int]:
	var found: Array = []
	for i in count():
		if not targetable(i):
			continue
		var q := pos[i]
		if (q.x - p.x) * (q.x - p.x) + (q.z - p.z) * (q.z - p.z) < r * r:
			found.push_back(Vector2(tracks[lane[i]].length - d[i], i))
	found.sort()
	var out: Array[int] = []
	for v in found.slice(0, k):
		out.push_back(int(v.y))
	return out


## The targetable enemy with the most HP within r of p (a Sniper's aim), or
## -1.
func toughest(p: Vector3, r: float) -> int:
	var best := -1
	for i in count():
		if not targetable(i):
			continue
		var q := pos[i]
		if (q.x - p.x) * (q.x - p.x) + (q.z - p.z) * (q.z - p.z) < r * r and (best < 0 or hp[i] > hp[best]):
			best = i
	return best


## Targetable enemies within `r` of `p` (xz); ground_only skips flyers.
func within(p: Vector3, r: float, ground_only := false) -> Array[int]:
	var out: Array[int] = []
	for i in count():
		if not targetable(i) or (ground_only and Level.ENEMIES[kind[i]].get("flies", false)):
			continue
		var q := pos[i]
		var rr := r + float(Level.ENEMIES[kind[i]].radius)
		if (q.x - p.x) * (q.x - p.x) + (q.z - p.z) * (q.z - p.z) < rr * rr:
			out.push_back(i)
	return out


## Targetable enemies within `half_width` of the segment a-b (xz), as
## Vector2(fraction along a-b, index), nearest to a first, at most `limit`.
func on_segment(a: Vector3, b: Vector3, half_width: float, limit: int) -> Array:
	var ab := Vector2(b.x - a.x, b.z - a.z)
	var len2 := ab.length_squared()
	var hits: Array = []
	for i in count():
		if not targetable(i):
			continue
		var ap := Vector2(pos[i].x - a.x, pos[i].z - a.z)
		var t := clampf(ap.dot(ab) / len2, 0.0, 1.0)
		var r := half_width + float(Level.ENEMIES[kind[i]].radius)
		if (ap - ab * t).length_squared() < r * r:
			hits.push_back(Vector2(t, i))
	hits.sort()
	return hits.slice(0, limit)


func _compact() -> void:
	var i := 0
	while i < count():
		if hp[i] > 0.0:
			i += 1
			continue
		var last := count() - 1
		kind[i] = kind[last]; lane[i] = lane[last]; uid[i] = uid[last]; hp[i] = hp[last]; max_hp[i] = max_hp[last]
		power[i] = power[last]; stage[i] = stage[last]
		mult[i] = mult[last]; freeze_t[i] = freeze_t[last]; brittle[i] = brittle[last]
		brittle_t[i] = brittle_t[last]; immune[i] = immune[last]; haste[i] = haste[last]; healed[i] = healed[last]
		d[i] = d[last]; off[i] = off[last]; spd[i] = spd[last]; gap[i] = gap[last]
		phase[i] = phase[last]; flash[i] = flash[last]; slow[i] = slow[last]
		slow_t[i] = slow_t[last]; blocked[i] = blocked[last]; pos[i] = pos[last]
		burn_dps[i] = burn_dps[last]; burn_t[i] = burn_t[last]; burn_src[i] = burn_src[last]
		prev_pos[i] = prev_pos[last]; prev_phase[i] = prev_phase[last]
		kind.resize(last); lane.resize(last); uid.resize(last); hp.resize(last); max_hp.resize(last)
		power.resize(last); stage.resize(last)
		mult.resize(last); freeze_t.resize(last); brittle.resize(last); brittle_t.resize(last)
		immune.resize(last); haste.resize(last); healed.resize(last)
		d.resize(last); off.resize(last); spd.resize(last); gap.resize(last)
		phase.resize(last); flash.resize(last); slow.resize(last)
		slow_t.resize(last); blocked.resize(last); pos.resize(last)
		burn_dps.resize(last); burn_t.resize(last); burn_src.resize(last)
		prev_pos.resize(last); prev_phase.resize(last)
	_index.clear()
	for k in count():
		_index[uid[k]] = k
