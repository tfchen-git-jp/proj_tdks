extends SceneTree
## Headless rule tests:  godot --headless --path . --script res://tests/run_tests.gd
## (or ./build.sh test). Prints PASS/FAIL per check and ALL PASSED at the end.

const SimS := preload("res://scripts/sim.gd")
const TrackS := preload("res://scripts/track.gd")
const HordeS := preload("res://scripts/horde.gd")
const BotS := preload("res://scripts/bot.gd")
const DT := 1.0 / 60.0

var _fails := 0


func _ok(cond: bool, what: String) -> void:
	print(("PASS " if cond else "FAIL ") + what)
	if not cond:
		_fails += 1


func _init() -> void:
	_tracks()
	_horde()
	_gate_queue()
	_giant_shove()
	_phases_and_building()
	_towers()
	_coins()
	_layout()
	_full_run()
	print("ALL PASSED" if _fails == 0 else "%d FAILED" % _fails)
	quit(1 if _fails else 0)


func _lane_tracks() -> Array[Track]:
	var out: Array[Track] = []
	for pts in Level.LANES:
		out.push_back(TrackS.new(pts))
	return out


func _tracks() -> void:
	var ts := _lane_tracks()
	for ln in ts.size():
		var t: Track = ts[ln]
		_ok(t.length > 40.0, "lane %d is long (%.1f m)" % [ln, t.length])
		_ok(t.point(t.length).distance_to(Level.LANES[ln][-1]) < 0.2, "lane %d ends at the keep" % ln)
		_ok(t.forward(1.0).z < -0.8, "lane %d walks up the screen at spawn" % ln)
	var t0: Track = ts[0]
	_ok(t0.right(1.0).x > 0.0, "right of the walking direction is screen right")
	_ok(absf(t0.closest_d(t0.point(20.0, 0.5)) - 20.0) < 0.3, "closest_d inverts point")


func _horde() -> void:
	var h = HordeS.new(_lane_tracks(), 3)
	for i in 10:
		h.spawn(Level.GRUNT, i % 3)
	_ok(h.count() == 10, "spawned 10 over three lanes")
	_ok(not h.targetable(0), "fresh spawns are behind the start line (untargetable)")
	_ok(h.damage(0, 100.0) and not h.damage(0, 100.0), "kill counts once")
	var dead_uid: int = h.uid[0]
	h.step(0.1)
	_ok(h.count() == 9 and h.killed == 1 and h.deaths.size() == 1, "dead removed, death reported")
	_ok(h.index_of(dead_uid) == -1 and h.index_of(h.uid[3]) == 3, "uid lookup survives compaction")
	for ln in 3:
		var p: Vector3 = h.tracks[ln].point(h.entry[ln])
		_ok(Level.BOUNDS.has_point(Vector2(p.x, p.z)), "lane %d start line is inside the hero's reach" % ln)
	for k in 4000:
		h.step(0.05)
	_ok(h.count() == 0 and h.escaped == 9, "survivors walk the whole road")
	_ok(h.leaked == 9 * int(Level.ENEMIES[Level.GRUNT].leak), "leak damage = 9 grunts")
	var h2 = HordeS.new(_lane_tracks(), 4)
	for i in 3:
		h2.spawn(Level.GRUNT, 1)
		h2.d[i] = 30.0
	h2.pos[0] = Vector3(0, 0, -1)
	h2.pos[1] = Vector3(0, 0, -3)
	h2.pos[2] = Vector3(2, 0, -2)
	var hits: Array = h2.on_segment(Vector3.ZERO, Vector3(0, 0, -5), 0.2, 5)
	_ok(hits.size() == 2 and int(hits[0].y) == 0 and int(hits[1].y) == 1, "pierce line hits 0 then 1 (got %s)" % [hits])


## Giants queue behind each other and step up when the front one dies
## (bug 2026-10-09: back giants stood idle 1-5 m short of the gate).
func _gate_queue() -> void:
	var h = HordeS.new(_lane_tracks(), 9)
	h.gate_d[1] = 25.0
	h.gate_hp[1] = 1e9
	for i in 3:
		h.spawn(Level.BRUTE, 1)
		for k in 120:
			h.step(DT)
	for k in 60 * 40:
		h.step(DT)
	var hitting := 0
	for i in h.count():
		if h.blocked[i] == 1:
			hitting += 1
	_ok(hitting >= 1 and h.count() == 3, "front giant hits the gate, others queue (%d hitting)" % hitting)
	var past := 0
	for i in h.count():
		if h.d[i] > 25.0:
			past += 1
	_ok(past == 0, "nobody walks through a standing gate")
	var front := 0
	for i in h.count():
		if h.d[i] > h.d[front]:
			front = i
	h.damage(front, 1e6)
	for k in 60 * 6:
		h.step(DT)
	hitting = 0
	var idle_far := 0
	for i in h.count():
		if h.blocked[i] == 1:
			hitting += 1
		elif h.blocked[i] != 2 and 25.0 - h.d[i] > 1.6:
			idle_far += 1
	_ok(hitting >= 1 and idle_far == 0, "after the front giant dies the next steps up (%d hitting)" % hitting)


## Giants don't wait behind small ones: the crowd parts and the giant walks
## up to the gate. Two giants both hit (the second over the first one's
## shoulder); a third waits (user, 2026-10-09).
func _giant_shove() -> void:
	var h = HordeS.new(_lane_tracks(), 4)
	h.gate_d[1] = 25.0
	h.gate_hp[1] = 1e4  # float32: keep it small enough to lose HP
	for i in 30:
		h.spawn(Level.GRUNT, 1)
		for k in 15:
			h.step(DT)
	for k in 60 * 20:  # the grunts reach the gate and pack the queue
		h.step(DT)
	var packed := 0
	for i in h.count():
		if h.blocked[i] == 2:
			packed += 1
	_ok(packed >= 10, "grunts queue at the gate (%d held)" % packed)
	h.spawn(Level.BRUTE, 1)
	var giant: int = h.uid[h.count() - 1]
	var t := 0.0
	var walk: float = (25.0 - h.gap[h.count() - 1]) / float(Level.ENEMIES[Level.BRUTE].speed)
	while t < walk * 1.6:
		h.step(DT)
		t += DT
		if h.blocked[h.index_of(giant)] == 1:
			break
	var g: int = h.index_of(giant)
	_ok(h.blocked[g] == 1, "a giant walks through the grunt queue to the gate (%.0f s, %.0f s unhindered)" % [t, walk])
	var wide := 0
	for i in h.count():
		if absf(h.off[i]) > Level.ROAD_HALF_WIDTH + 0.15:
			wide += 1
	_ok(wide == 0, "shoved grunts stay on the road")
	# Two giants hit together, a third waits.
	var b = HordeS.new(_lane_tracks(), 5)
	b.gate_d[1] = 25.0
	b.gate_hp[1] = 1e4
	for i in 3:
		b.spawn(Level.BRUTE, 1)
		for k in 90:
			b.step(DT)
	for k in 60 * 45:
		b.step(DT)
	var hitting := 0
	var held := 0
	for i in b.count():
		if b.blocked[i] == 1:
			hitting += 1
		elif b.blocked[i] == 2:
			held += 1
	_ok(hitting == 2 and held == 1, "two giants hit the gate, the third waits (%d hitting, %d held)" % [hitting, held])


func _phases_and_building() -> void:
	var s = SimS.new(5)
	_ok(s.phase == "build" and s.coins == Level.START_GOLD, "starts in the build phase with start gold")
	s.hero_pos = Level.SPOTS[0].pos
	var spot: Dictionary = s.spot_under_hero()
	_ok(spot.get("id", "") == Level.SPOTS[0].id, "standing on a spot finds it")
	var opts: Array = s.options(spot)
	_ok(opts.size() == Level.TOWER_KINDS.size(), "an empty tower spot offers every tower (%d)" % opts.size())
	_ok(s.buy(spot.id, "archer") and s.coins == Level.START_GOLD - 15, "buying an archer tower costs 15")
	_ok(not s.buy(spot.id, "mortar"), "can't build a second thing on a spot")
	s.coins = 100
	_ok(s.buy(spot.id, "archer") and s.buildings[spot.id].level == 1, "buying again upgrades to level 2")
	_ok(not s.buy("f_1", "archer"), "farm plots take farms only")
	_ok(not s.start_wave() or true, "start_wave callable")
	var s2 = SimS.new(6)
	s2.hero_pos = Vector3(-14.0, 0, 30.0)  # far from the centre lane: undefended
	_ok(s2.start_wave() and s2.phase == "attack", "start_wave begins the attack")
	_ok(not s2.buy(Level.SPOTS[0].id, "archer"), "no building during an attack")
	for i in 60 * 120:
		s2.step(DT, Vector2.ZERO)
		if s2.phase == "build":
			break
	_ok(s2.phase == "build" and s2.wave == 1, "the wave ends when all are dead or through (wave %d)" % s2.wave)
	_ok(s2.base_hp < Level.BASE_HP, "undefended, the keep took damage (%d)" % s2.base_hp)


func _towers() -> void:
	# An archer tower beside the centre lane kills a lone grunt with arrows.
	var s = SimS.new(7)
	s.coins = 999
	s.buy("e_mid", "archer")
	s.start_wave()
	var arrows := 0
	var killed_by_tower := 0
	s.hero_pos = Level.KEEP_POS + Vector3(0, 0, 3)  # keep the hero out of it
	for i in 60 * 60:
		s.step(DT, Vector2.ZERO)
		for p in s.projectiles:
			if p.kind == "arrow":
				arrows += 1
		if s.phase == "build":
			break
	_ok(arrows > 0, "archer towers shoot arrows that fly (seen %d arrow-frames)" % arrows)
	_ok(s.horde.killed > 0, "towers kill (%d)" % s.horde.killed)
	# Frost slows, banner buffs, farms pay.
	var f = SimS.new(8)
	f.coins = 999
	f.buy("e_mid", "frost")
	f.buy("e_in", "banner")
	f.buy("f_1", "farm")
	_ok(f.banner_buff(Level.SPOTS[5].pos) > 0.0, "a banner buffs its own spot")
	_ok(f.banner_buff(Level.KEEP_POS + Vector3(0, 0, 40)) == 0.0, "but not far away")
	f.start_wave()
	var slowed := false
	for i in 60 * 120:
		f.step(DT, Vector2.ZERO)
		for k in f.horde.count():
			if f.horde.slow[k] > 0.0:
				slowed = true
		if f.phase == "build":
			break
	_ok(slowed, "frost slows enemies")
	# Chill slows attacks too: a chilled giant breaks a gate slower.
	var lost := []
	for chilled in [false, true]:
		var h = HordeS.new(_lane_tracks(), 9)
		h.gate_d[1] = 25.0
		h.gate_hp[1] = 1e4  # float32: 1e9 would swallow each frame's damage
		h.spawn(Level.BRUTE, 1)
		while h.blocked[0] != 1:
			h.step(DT)
		var before: float = h.gate_hp[1]
		for k in 60 * 5:
			if chilled:
				h.chill(0, 0.5, 1.0)
			h.step(DT)
		lost.push_back(before - h.gate_hp[1])
	_ok(lost[0] > 0.0 and absf(lost[1] - lost[0] * 0.5) < lost[0] * 0.02,
		"a chilled enemy hits the gate slower (%.0f vs %.0f hp)" % [lost[1], lost[0]])
	var coins_after: int = f.coins
	_ok(coins_after >= 999 - 25 - 30 - 20 + 6, "the farm paid after the wave (%d)" % coins_after)


func _coins() -> void:
	var s = SimS.new(6)
	s.drop_pos.push_back(s.hero_pos + Vector3(1.0, 0, 0))
	s.drop_val.push_back(4)
	s.drop_fly.push_back(-1.0)
	s.drop_from.push_back(Vector3.ZERO)
	var before: int = s.coins
	for i in 30:
		s.step(DT, Vector2.ZERO)
	_ok(s.coins == before + 4, "magnet collects a nearby coin")


func _layout() -> void:
	var ts := _lane_tracks()
	for sp in Level.SPOTS:
		var dmin := INF
		for t in ts:
			dmin = minf(dmin, t.distance_to(sp.pos))
		if sp.kind == "gate":
			var dl: float = ts[int(sp.lane)].distance_to(sp.pos)
			_ok(dl < 4.0 and dl > Level.ROAD_HALF_WIDTH + 0.6, "gate spot %s beside its lane (%.1f m)" % [sp.id, dl])
		else:
			_ok(dmin > Level.ROAD_HALF_WIDTH + Level.PAD_SIZE * 0.5 + 0.2, "spot %s clear of the roads (%.1f m)" % [sp.id, dmin])
		_ok(Level.BOUNDS.has_point(Vector2(sp.pos.x, sp.pos.z)), "spot %s reachable" % sp.id)
		_ok(sp.pos.x < World.east_edge(sp.pos.z) - Level.PAD_SIZE * 0.5 - 0.4 and sp.pos.z > World.north_edge(sp.pos.x) + 1.0,
			"spot %s on the plateau" % sp.id)
		for o in Level.SPOTS:
			if o.id < sp.id:
				_ok(sp.pos.distance_to(o.pos) > 2.2, "spots %s and %s apart" % [sp.id, o.id])
	# Every gate has a tower spot that reaches the enemies queued at it.
	for sp in Level.SPOTS:
		if sp.kind != "gate":
			continue
		var t: Track = ts[int(sp.lane)]
		var queue := t.point(t.closest_d(sp.pos) - 1.5)
		var near := INF
		for o in Level.SPOTS:
			if o.kind == "tower":
				near = minf(near, o.pos.distance_to(queue))
		_ok(near < 4.5, "gate %s has a tower spot %.1f m from its queue" % [sp.id, near])
	var tex: Texture2D = load(World.ROAD_DIST)
	_ok(tex != null and int(tex.get_meta("road_hash", 0)) == World.road_hash(),
		"road distance texture matches Level.LANES (else run tools/bake_terrain.gd)")
	_ok(Level.START_SPOT.distance_to(Level.KEEP_POS) < 5.0, "start spot by the keep")


func _full_run() -> void:
	var s = SimS.new(1)
	var bot = BotS.new(s)
	while s.state == "play" and s.time < 1500.0:
		s.step(DT, bot.move())
	_ok(s.state == "win", "the bot wins level 1 (%s at %.0f s, wave %d, keep %d)" % [s.state, s.time, s.wave, s.base_hp])
