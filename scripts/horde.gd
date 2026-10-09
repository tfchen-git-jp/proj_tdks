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
var d := PackedFloat32Array()  # metres along its lane
var off := PackedFloat32Array()  # metres right of the walking direction
var spd := PackedFloat32Array()
var gap := PackedFloat32Array()  # how far short of a gate this one stops (at the wall)
var phase := PackedFloat32Array()  # walk (or, when blocked, attack) cycle, radians
var flash := PackedFloat32Array()  # hit-flash timer, s
var slow := PackedFloat32Array()  # current slow fraction (0..1)
var slow_t := PackedFloat32Array()  # seconds the slow lasts
var blocked := PackedByteArray()  # 1 = at the gate, hitting it; 2 = held up
                                  # behind another enemy in the queue; 0 = walking
var pos := PackedVector3Array()

## Per lane, set by the game: gate road distance (-1 = none) and its HP.
var gate_d := PackedFloat32Array([-1.0, -1.0, -1.0])
var gate_hp := PackedFloat32Array([0.0, 0.0, 0.0])

## Results since the caller last drained them.
var deaths: Array[Dictionary] = []  # {pos, kind, d, lane}
var leaked := 0  # keep damage taken
var killed := 0
var escaped := 0

var _rng := RandomNumberGenerator.new()
var _next_uid := 1
var _index := {}  # uid -> index, rebuilt every step

## Half thickness of the gate wall (Models.gate depth), m.
const GATE_HALF_DEPTH := 0.55
## The queue at a gate only sorts out enemies this close to it, m.
const QUEUE_ZONE := 8.0
## Shoved light enemies sidestep this fast (m/s), at most this far off the
## lane's centre (m); a heavy one drifts to the centre this fast near a gate.
const SHOVE_SPEED := 3.0
const SHOVE_EDGE := Level.ROAD_HALF_WIDTH + 0.1
const HEAVY_CENTRING := 0.5


func _init(lane_tracks: Array[Track], seed_value := 1) -> void:
	tracks = lane_tracks
	_rng.seed = seed_value
	for t in tracks:
		entry.push_back(start_line(t))


## Road distance where a lane enters the hero's reach (+ margin): enemies
## before it can't be hit, so nobody dies where coins can't be collected.
static func start_line(t: Track) -> float:
	var reach := Level.BOUNDS.grow(-Level.START_LINE_MARGIN)
	var dd := 0.0
	while dd < t.length:
		var p := t.point(dd)
		if reach.has_point(Vector2(p.x, p.z)):
			return dd
		dd += 0.25
	return 0.0


func count() -> int:
	return kind.size()


func spawn(type: int, ln: int) -> void:
	var e: Dictionary = Level.ENEMIES[type]
	var lim := Level.ROAD_HALF_WIDTH - float(e.radius) * 0.6
	kind.push_back(type)
	lane.push_back(ln)
	uid.push_back(_next_uid)
	_index[_next_uid] = kind.size() - 1
	_next_uid += 1
	hp.push_back(e.hp)
	d.push_back(_rng.randf_range(0.0, 0.6))
	off.push_back(_rng.randf_range(-lim, lim) if type != Level.BRUTE else _rng.randf_range(-0.3, 0.3))
	spd.push_back(float(e.speed) * _rng.randf_range(0.9, 1.1))
	gap.push_back(GATE_HALF_DEPTH + float(e.radius) * 0.8 + _rng.randf_range(0.0, 0.25))
	phase.push_back(_rng.randf() * TAU)
	flash.push_back(0.0)
	slow.push_back(0.0)
	slow_t.push_back(0.0)
	blocked.push_back(0)
	pos.push_back(tracks[ln].point(d[d.size() - 1], off[off.size() - 1]))


## Index of the living enemy with this uid, or -1.
func index_of(id: int) -> int:
	var i: int = _index.get(id, -1)
	return i if i >= 0 and i < count() and uid[i] == id and hp[i] > 0.0 else -1


## Can towers and the hero hit it yet (past its lane's start line)?
func targetable(i: int) -> bool:
	return hp[i] > 0.0 and d[i] >= entry[lane[i]]


## Deal damage; returns true if this hit killed it. Hits on the already
## dead (hp <= 0, waiting for removal) do nothing.
func damage(i: int, amount: float) -> bool:
	if hp[i] <= 0.0:
		return false
	hp[i] -= amount
	flash[i] = 0.12
	if hp[i] <= 0.0:
		killed += 1
		deaths.push_back({pos = pos[i], kind = kind[i], d = d[i], lane = lane[i]})
		return true
	return false


func chill(i: int, fraction: float, seconds: float) -> void:
	slow[i] = maxf(slow[i], fraction)
	slow_t[i] = maxf(slow_t[i], seconds)


## Walking direction of enemy i.
func forward(i: int) -> Vector3:
	return tracks[lane[i]].forward(d[i])


func step(dt: float) -> void:
	var n := count()
	var prev := d.duplicate()
	# 1. Everyone walks; nobody passes a standing gate on their lane.
	for i in n:
		if hp[i] <= 0.0:
			continue
		flash[i] = maxf(flash[i] - dt, 0.0)
		slow_t[i] -= dt
		if slow_t[i] <= 0.0:
			slow[i] = 0.0
		var nd := d[i] + spd[i] * (1.0 - slow[i]) * dt
		blocked[i] = 0
		var ln := lane[i]
		if gate_d[ln] >= 0.0 and gate_hp[ln] > 0.0 and d[i] < gate_d[ln]:
			var stop := gate_d[ln] - gap[i]
			if nd >= stop:
				nd = maxf(stop, d[i])
				blocked[i] = 1
		d[i] = nd
	# 2. Near a standing gate, queue: nobody overlaps the one ahead of them
	# in their lane, so the back ranks wait and step up as the front dies.
	for ln in tracks.size():
		if gate_d[ln] >= 0.0 and gate_hp[ln] > 0.0:
			_queue(ln, prev, dt)
	# 3. Gate damage, animation phase, leaks, positions.
	for i in n:
		if hp[i] <= 0.0:
			continue
		var e: Dictionary = Level.ENEMIES[kind[i]]
		# Frost slows attacks as much as walking (swing and gate damage).
		if blocked[i] == 1:
			gate_hp[lane[i]] -= float(e.dps) * (1.0 - slow[i]) * dt
		if blocked[i] == 0:
			phase[i] += spd[i] * (1.0 - slow[i]) * dt * 7.0
		else:
			phase[i] += (1.0 - slow[i]) * dt * TAU / Level.ATTACK_CYCLE
		if d[i] >= tracks[lane[i]].length:
			leaked += int(e.leak)
			escaped += 1
			hp[i] = 0.0
			continue
		pos[i] = tracks[lane[i]].point(d[i], off[i])
	_compact()


## Front-to-back over the enemies close behind lane `ln`'s gate: each may
## come no closer than its spacing to any enemy ahead that overlaps its
## lane position. Never pushes anyone backwards (from `prev`).
## Heavy enemies (giants) don't wait for light ones: the light ones just
## ahead of or beside a giant sidestep out of its path, and it walks
## through to the gate. Giants queue behind each other as usual, and one
## held within its reach of the gate hits it anyway.
func _queue(ln: int, prev: PackedFloat32Array, dt: float) -> void:
	var gd := gate_d[ln]
	var near: Array = []
	for i in count():
		if hp[i] > 0.0 and lane[i] == ln and d[i] < gd and gd - d[i] < QUEUE_ZONE:
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
			blocked[i] = 1 if reach > 0.0 and gd - d[i] <= gap[i] + reach else 2
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


## Index of the targetable enemy closest to the keep (least road left)
## between `r_min` and `r` of `p` -- the classic TD "first" target -- or -1.
func first_in_range(p: Vector3, r: float, r_min := 0.0) -> int:
	var best_left := INF
	var best_i := -1
	for i in count():
		if not targetable(i):
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


## Targetable enemies within `r` of `p` (xz).
func within(p: Vector3, r: float) -> Array[int]:
	var out: Array[int] = []
	for i in count():
		if not targetable(i):
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
		kind[i] = kind[last]; lane[i] = lane[last]; uid[i] = uid[last]; hp[i] = hp[last]
		d[i] = d[last]; off[i] = off[last]; spd[i] = spd[last]; gap[i] = gap[last]
		phase[i] = phase[last]; flash[i] = flash[last]; slow[i] = slow[last]
		slow_t[i] = slow_t[last]; blocked[i] = blocked[last]; pos[i] = pos[last]
		kind.resize(last); lane.resize(last); uid.resize(last); hp.resize(last)
		d.resize(last); off.resize(last); spd.resize(last); gap.resize(last)
		phase.resize(last); flash.resize(last); slow.resize(last)
		slow_t.resize(last); blocked.resize(last); pos.resize(last)
	_index.clear()
	for k in count():
		_index[uid[k]] = k
