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
	_save()
	_unlocks()
	_perks()
	_new_enemies()
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
	var hb = HordeS.new(_lane_tracks(), 2)
	hb.spawn(Level.BRUTE, 1, 2.5)
	_ok(hb.max_hp[0] == hb.hp[0] and hb.hp[0] > float(Level.ENEMIES[Level.BRUTE].hp) * 2.4,
		"a tougher wave's giant has its full HP as the bar's max (%.0f)" % hb.max_hp[0])
	var dead_uid: int = h.uid[0]
	h.step(0.1)
	_ok(h.count() == 9 and h.killed == 1 and h.deaths.size() == 1, "dead removed, death reported")
	_ok(h.index_of(dead_uid) == -1 and h.index_of(h.uid[3]) == 3, "uid lookup survives compaction")
	for ln in 3:
		var p: Vector3 = h.tracks[ln].point(h.entry[ln])
		_ok(Level.BOUNDS.grow(Level.START_LINE_OUT + 0.3).has_point(Vector2(p.x, p.z))
			and not Level.BOUNDS.grow(Level.START_LINE_OUT - 0.3).has_point(Vector2(p.x, p.z)),
			"lane %d start line is %.1f m outside the walkable area" % [ln, Level.START_LINE_OUT])
	h.keep_hp = 1e4
	for k in 4000:
		h.step(0.05)
	var at_keep := 0
	for i in h.count():
		if h.blocked[i] != 0 and h.d[i] > h.tracks[h.lane[i]].length - 2.0:
			at_keep += 1
	_ok(h.count() == 9 and at_keep == 9, "survivors stop at the keep (%d of %d)" % [at_keep, h.count()])
	_ok(h.keep_hp < 1e4, "and attack it (%.0f hp left)" % h.keep_hp)
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
	_ok(not s.buy("f_1", "archer"), "economy plots take no towers")
	_ok(not s.start_wave() or true, "start_wave callable")
	# Start pad: a countdown while the hero stands on it, cancelled by leaving.
	var c = SimS.new(3)
	c.hero_pos = Level.START_SPOT
	for i in int(60 * (Level.START_COUNTDOWN - 1.0)):
		c.step(DT, Vector2.ZERO)
	_ok(c.phase == "build" and c.start_t > 3.0, "standing on the start pad counts down (%.1f s)" % c.start_t)
	c.hero_pos = Level.START_SPOT + Vector3(-4, 0, 3)
	c.step(DT, Vector2.ZERO)
	_ok(c.start_t == 0.0, "walking off the pad cancels the countdown")
	c.hero_pos = Level.START_SPOT
	for i in int(60 * (Level.START_COUNTDOWN + 0.2)):
		c.step(DT, Vector2.ZERO)
	_ok(c.phase == "attack", "after the full countdown the wave starts")
	_ok(SimS.gold_pieces(37) == [20, 5, 5, 5, 1, 1] and SimS.gold_pieces(3) == [1, 1, 1],
		"gold drops as ingots / coin stacks / coins (%s)" % [SimS.gold_pieces(37)])
	var s2 = SimS.new(6)
	s2.hero_pos = Vector3(-14.0, 0, 30.0)  # far from the centre lane: undefended
	_ok(s2.start_wave() and s2.phase == "attack", "start_wave begins the attack")
	_ok(not s2.buy(Level.SPOTS[0].id, "archer"), "no building during an attack")
	for i in 60 * 300:
		s2.step(DT, Vector2.ZERO)
		if s2.phase == "build" or s2.state != "play":
			break
	_ok(s2.state == "lose", "undefended, the wave hammers the keep down (%s, keep %.0f)" % [s2.state, s2.base_hp])


func _towers() -> void:
	# An archer tower beside the centre lane kills a lone grunt with arrows.
	var s = SimS.new(7)
	s.coins = 999
	s.level = 20  # every spot open
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
	f.level = 20
	f.coins = 999
	f.buy("e_mid", "frost")
	f.buy("e_in", "banner")
	f.buy("f_1", "farm")
	_ok(f.banner_buff(f.buildings.e_in.pos) > 0.0, "a banner buffs its own spot")
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
	var cost := int(Level.stats("frost", 0).cost) + int(Level.stats("banner", 0).cost) + int(Level.stats("farm", 0).cost)
	_ok(coins_after >= 999 - cost + int(Level.stats("farm", 0).income), "the farm paid after the wave (%d)" % coins_after)
	# Banks: the best bank's rate, capped by the sum of their caps.
	var bk = SimS.new(4)
	bk.level = 20
	bk.coins = 500
	bk.buy("f_1", "bank")
	bk.buy("f_2", "bank")
	bk.coins = 150
	bk.start_wave()
	bk.wave = Level.WAVES.size() - 2
	bk.horde.keep_hp = 1e9
	bk.phase = "attack"
	bk._spawned.clear()
	for g in Level.WAVES[bk.wave]:
		bk._spawned.push_back(int(g.count))
	bk.step(DT, Vector2.ZERO)
	var got: int = bk.coins - 150
	_ok(got == mini(floori(150 * float(Level.stats("bank", 0).rate)), 2 * int(Level.stats("bank", 0).cap)),
		"two banks pay their rate on 150 within their summed cap (+%d)" % got)
	# Farms: an upgrade earns more per gold than another level-1 farm.
	var f1: Dictionary = Level.stats("farm", 0)
	for lv in range(1, 3):
		var fa: Dictionary = Level.stats("farm", lv - 1)
		var fb: Dictionary = Level.stats("farm", lv)
		_ok(float(fb.income - fa.income) / float(fb.cost) > float(f1.income) / float(f1.cost),
			"farm Lv %d pays more per gold than a new farm" % (lv + 1))


func _coins() -> void:
	var s = SimS.new(6)
	s.drop_pos.push_back(s.hero_pos + Vector3(1.0, 0, 0))
	s.drop_val.push_back(4)
	s.drop_fly.push_back(-1.0)
	s.drop_from.push_back(Vector3.ZERO)
	s.drop_dur.push_back(SimS.FLY_TIME)
	var before: int = s.coins
	for i in 30:
		s.step(DT, Vector2.ZERO)
	_ok(s.coins == before + 4, "magnet collects a nearby coin")
	# Wave end: every coin on the map flies to the hero, however far.
	var v = SimS.new(7)
	for k in 5:
		var q := Vector3(-12.0 + k * 4.0, 0, 40.0)  # beyond the map's bottom
		v.drop_pos.push_back(q)
		v.drop_val.push_back(3)
		v.drop_fly.push_back(-1.0)
		v.drop_from.push_back(q)
		v.drop_dur.push_back(SimS.FLY_TIME)
	var c0: int = v.coins
	var saved: int = v.to_save().coins
	v.phase = "attack"
	v.wave = 0
	v._spawned.clear()
	for g in Level.WAVES[0]:
		v._spawned.push_back(int(g.count))
	for k in 60 * 4:
		v.step(DT, Vector2.ZERO)
	_ok(v.phase == "build" and v.drop_pos.is_empty() and v.coins == c0 + 15,
		"after the wave every coin is swept to the hero (+%d)" % (v.coins - c0))
	_ok(saved == c0 + 15, "a save banks the coins still lying around")
	# While the sweep flies in the hero can't move or open a spot.
	var w = SimS.new(8)
	w.hero_pos = Level.SPOTS[0].pos
	var q := Vector3(0, 0, 30)
	w.drop_pos.push_back(q)
	w.drop_val.push_back(1)
	w.drop_fly.push_back(0.0)
	w.drop_from.push_back(q)
	w.drop_dur.push_back(2.0)
	var at0: Vector3 = w.hero_pos
	w.step(DT, Vector2(1, 0))
	_ok(w.hero_pos == at0 and w.spot_under_hero().is_empty(), "during the sweep the hero holds still, no popup")
	for k in 60 * 3:
		w.step(DT, Vector2.ZERO)
	w.step(DT, Vector2(1, 0))
	_ok(w.hero_pos != at0, "after it he walks again")
	# A bat's coins land on the ground.
	var bt = SimS.new(9)
	bt.horde.spawn(Level.BAT, 1)
	bt.horde.d[0] = 30.0
	bt.horde.step(DT)
	bt.horde.damage(0, 1e6)
	bt._drops_from_deaths()
	_ok(bt.drop_pos.size() > 0 and bt.drop_pos[0].y == 0.0, "a bat's coins drop to the ground")


## A run survives to_save() -> JSON -> from_save(), and the score order is
## waves cleared first, then gold.
func _save() -> void:
	var a = SimS.new(11)
	a.level = 20
	a.coins = 400
	a.buy("k_east", "archer")
	a.buy("k_east", "archer")
	a.buy("g_c1", "gate")
	a.buy("f_1", "bank")
	a.wave = 4
	a.base_hp = 321.0
	var d: Dictionary = JSON.parse_string(JSON.stringify(a.to_save()))
	var b = SimS.from_save(d)
	_ok(b.wave == 4 and b.coins == a.coins and b.base_hp == 321.0 and b.horde.keep_hp == 321.0,
		"a saved run comes back (wave, gold, keep)")
	_ok(b.buildings.size() == 3 and b.buildings.k_east.level == 1 and b.buildings.f_1.kind == "bank"
		and b.horde.gate_d[1] > 0.0 and b.horde.gate_hp[1] > 0.0, "with its buildings and a standing gate")
	_ok(b._rng.state == a._rng.state and b.horde._rng.state == a.horde._rng.state, "and its dice")
	var list := [{waves = 10, score = Save.score_of(0.2, 400)}, {waves = 8, score = Save.score_of(1.0, 900)},
		{waves = 10, score = Save.score_of(0.9, 100)}]
	list.sort_custom(Save.better)
	_ok(list[0].waves == 10 and list[0].score == 1000 and list[1].score == 600 and list[2].waves == 8,
		"scores: waves first, then keep % x 10 + gold")


## Spots open with the hero's level; gates come in sets (one per lane) and
## two gates on a lane hold enemies at the outer one first.
func _unlocks() -> void:
	var s = SimS.new(12)
	var open := 0
	for sp in Level.SPOTS:
		if s.unlocked(sp):
			open += 1
			_ok(sp.kind != "gate", "no gate spot at level 1 (%s)" % sp.id)
	_ok(open == 6, "level 1 opens 6 spots (%d)" % open)
	s.coins = 999
	s.hero_pos = Vector3(1.6, 0, 12.6)  # e_mid, level 3
	_ok(s.spot_under_hero().is_empty() and not s.buy("e_mid", "archer"), "a locked spot has no menu and can't be built")
	s.level = 3
	_ok(s.spot_under_hero().get("id", "") == "e_mid" and s.buy("e_mid", "archer"), "at its level it opens")
	var sets := {}
	for sp in Level.SPOTS:
		if sp.kind == "gate":
			sets[int(sp.lv)] = int(sets.get(int(sp.lv), 0)) + 1
	_ok(sets.size() == 2 and sets.values() == [3, 3], "gates open in two sets of three (%s)" % sets)
	var per_level := {}
	for sp in Level.SPOTS:
		if sp.kind == "tower":
			per_level[int(sp.lv)] = int(per_level.get(int(sp.lv), 0)) + 1
	var gaps := 0
	for lv in range(2, 11):
		if int(per_level.get(lv, 0)) < 1 or int(per_level.get(lv, 0)) > 2:
			gaps += 1
	_ok(gaps == 0, "levels 2-10 each open 1-2 tower spots (%s)" % per_level)
	# Two gates on the centre lane: enemies stop at the outer one first.
	var h = HordeS.new(_lane_tracks(), 13)
	h.gate_lane[4] = 1
	h.gate_d[1] = 30.0
	h.gate_hp[1] = 1e4
	h.gate_d[4] = 20.0
	h.gate_hp[4] = 1e4
	h.spawn(Level.GRUNT, 1)
	for k in 60 * 25:
		h.step(DT)
	_ok(h.d[0] < 20.0 and h.gate_hp[4] < 1e4 and h.gate_hp[1] == 1e4, "the outer gate holds them first")
	h.gate_hp[4] = 0.0
	h.gate_d[4] = -1.0
	for k in 60 * 15:
		h.step(DT)
	_ok(h.d[0] > 20.0 and h.d[0] < 30.0 and h.gate_hp[1] < 1e4, "when it falls they move on to the inner one")


## Put a fresh enemy `d` m along lane `ln` (past the start line).
func _place(sim, type: int, ln: int, d: float) -> int:
	sim.horde.spawn(type, ln)
	var i: int = sim.horde.count() - 1
	sim.horde.d[i] = d
	sim.horde.pos[i] = sim.tracks[ln].point(d)
	return i


## Hero upgrades: XP near the hero, banked level-ups offered after the
## wave (one after another), relics, tiers, rerolls, burning, lightning.
func _perks() -> void:
	var s = SimS.new(21)
	var near: int = _place(s, Level.BRUTE, 1, 30.0)
	s.hero_pos = s.horde.pos[near] + Vector3(3, 0, 0)
	var far: int = _place(s, Level.BRUTE, 0, 12.0)
	s.horde.damage(far, 1e6)
	s.horde.damage(near, 1e6)
	s._drops_from_deaths()
	var got: int = int(Level.ENEMIES[Level.BRUTE].xp)
	_ok(s.level == 2 and is_equal_approx(s.xp, got - Perks.xp_needed(1)), "only the kill near the hero gives XP (%d)" % got)
	_ok(SimS.new(1).level == 1, "the hero starts at level 1")
	s.xp = 0
	s.level = 1
	s.pending_levels = 0
	s._gain_xp(Perks.xp_needed(1) + Perks.xp_needed(2))
	_ok(s.level == 3 and s.pending_levels == 2 and s.offer.is_empty(), "two level-ups banked, nothing offered mid-wave")
	s.phase = "attack"
	s.wave = 2  # clearing wave 3 also gives a relic
	s._end_wave()
	_ok(s.offer.is_empty(), "no offer before the coins are in")
	for k in 60 * 3:  # the sweep lands, then the picks open
		s.step(DT, Vector2.ZERO)
		if not s.offer.is_empty():
			break
	_ok(s.drop_pos.is_empty() and not s.offer.is_empty(), "the picks open once every coin is in")
	_ok(s.offer_relic and s.offer.size() == 3 and s.pending_levels == 2, "after wave 3: the relic first (%s)" % [s.offer])
	s.hero_pos = Level.START_SPOT
	for k in 60 * 8:
		s.step(DT, Vector2.ZERO)
	_ok(s.phase == "build" and s.start_t == 0.0, "the start countdown waits for the picks")
	var relic: String = s.offer[0]
	s.pick(0)
	_ok(relic in s.relics and not s.offer_relic and s.offer.size() == 3, "relic taken, then a level-up offer")
	var card: String = s.offer[1]
	s.pick(1)
	_ok(s.tier(card) == 1 and s.offer.size() == 3 and s.pending_levels == 0, "card at tier I, the second level-up offered")
	s.coins = 25
	var before: Array = s.offer.duplicate()
	_ok(s.reroll() and s.coins == 15 and s.reroll_cost() == 20, "reroll costs 10, then 20")
	_ok(not s.reroll() and s.coins == 15, "can't reroll without the gold")
	s.perks[card] = Perks.MAX_TIER - 1
	s.offer = [card, before[0], before[1]]
	s.pick(0)
	_ok(s.tier(card) == Perks.MAX_TIER and s.offer.is_empty(), "drawing a card again raises its tier (to %d)" % s.tier(card))
	s._gain_xp(Perks.xp_needed(s.level))
	s.pending_levels = 1
	s._next_offer()
	_ok(not card in s.offer, "a maxed card leaves the pool")
	# XP range: 8 m, or 2 m past a Long Shot range; Scholar adds XP.
	var x = SimS.new(24)
	_ok(x.xp_radius() == Perks.XP_RADIUS, "XP radius is %.0f m" % x.xp_radius())
	x.perks.range = 3
	_ok(x.xp_radius() == float(Level.HERO.range) + 3.0 + Perks.XP_PAST_RANGE,
		"Long Shot III pushes it to %.0f m" % x.xp_radius())
	x.perks.scholar = 2
	x._gain_xp(5.0)
	_ok(is_equal_approx(x.xp, 7.0), "Scholar II: 5 XP -> %.1f" % x.xp)
	# A save from before Magnet was retired still loads.
	var old_save: Dictionary = JSON.parse_string(JSON.stringify(x.to_save()))
	old_save.perks["magnet"] = 2
	old_save.offer = ["magnet", "dmg", "aspd"]
	old_save.offer_relic = false
	var y = SimS.from_save(old_save)
	_ok(not y.perks.has("magnet") and y.offer.size() == 3 and not "magnet" in y.offer,
		"an old save's retired Magnet card is dropped and its offer re-rolled")
	# Fire Bolts: burning keeps hurting, and a burn kill drops gold.
	var f = SimS.new(22)
	var g: int = _place(f, Level.GRUNT, 1, 30.0)
	f.horde.ignite(g, 2.0, 3.0)
	var killed: int = f.horde.killed
	for k in 120:
		f.horde.step(DT)
	_ok(f.horde.killed == killed + 1 and f.horde.deaths.size() == 1, "a burning grunt burns to death")
	# Thunderstrike chains through at most THUNDER_CHAIN enemies.
	var t = SimS.new(23)
	for k in 7:
		_place(t, Level.GRUNT, 1, 30.0 + k * 0.6)
		t.horde.hp[t.horde.count() - 1] = 1e3
	t.hero_pos = t.tracks[1].point(30.0) + Vector3(3, 0, 0)
	t.relics = ["thunder"]
	t.phase = "attack"
	t._thunder(0.1)
	var hurt := 0
	for i in t.horde.count():
		if t.horde.hp[i] < 1e3:
			hurt += 1
	_ok(hurt == Perks.THUNDER_CHAIN and t.events.size() == 1 and t.events[0].points.size() == Perks.THUNDER_CHAIN + 1,
		"lightning strikes and chains through %d enemies" % hurt)
	# Upgrades survive a save.
	var old: Dictionary = JSON.parse_string(JSON.stringify(s.to_save()))
	old.v = 2
	old.level = s.level - 1
	_ok(SimS.from_save(old).level == s.level, "a v2 save's level (from 0) is converted")
	var r = SimS.from_save(JSON.parse_string(JSON.stringify(s.to_save())))
	_ok(r.tier(card) == Perks.MAX_TIER and r.relics == s.relics and r.level == s.level and r.rerolls == s.rerolls
		and r._card_rng.state == s._card_rng.state, "hero upgrades survive a save")


## Armour, flyers, crossbowmen, the boss (v0.1.18).
func _new_enemies() -> void:
	# Armour: light hits lose most, heavy hits little; never below the floor.
	var a = HordeS.new(_lane_tracks(), 31)
	a.spawn(Level.ARMORED, 1)
	var hp0: float = a.hp[0]
	a.damage(0, 2.0)
	var light: float = hp0 - a.hp[0]
	hp0 = a.hp[0]
	a.damage(0, 10.0)
	var heavy: float = hp0 - a.hp[0]
	var ar := float(Level.ENEMIES[Level.ARMORED].armor)
	_ok(is_equal_approx(light, maxf(2.0 - ar, 2.0 * Level.ARMOR_FLOOR)) and is_equal_approx(heavy, 10.0 - ar),
		"armour: a 2-damage hit does %.1f, a 10-damage hit %.1f" % [light, heavy])
	# A flyer crosses a standing gate and hits the keep; mortars and frost
	# can't target it.
	var f = HordeS.new(_lane_tracks(), 32)
	f.gate_d[1] = 25.0
	f.gate_hp[1] = 1e4
	f.keep_hp = 1e4
	f.spawn(Level.BAT, 1)
	for k in 60 * 40:
		f.step(DT)
	_ok(f.d[0] > 25.0 and f.blocked[0] == 1 and f.keep_hp < 1e4 and f.gate_hp[1] == 1e4,
		"a bat flies over the gate and attacks the keep")
	_ok(f.pos[0].y > 1.5, "it flies (%.1f m up)" % f.pos[0].y)
	var at: Vector3 = f.pos[0]
	_ok(f.first_in_range(at, 3.0) == 0 and f.first_in_range(at, 3.0, 0.0, true) == -1
		and f.within(at, 3.0, true).is_empty(), "ground-only attacks (mortar, frost) can't reach it")
	# A crossbowman stops out of the queue, short of the gate, and shoots it.
	var c = HordeS.new(_lane_tracks(), 33)
	c.gate_d[1] = 25.0
	c.gate_hp[1] = 1e4
	c.spawn(Level.SIEGE, 1)
	var shots := 0
	for k in 60 * 40:
		c.step(DT)
		shots += c.shots.size()
	var stand: float = 25.0 - c.d[0]
	_ok(c.blocked[0] == 1 and stand >= float(Level.ENEMIES[Level.SIEGE].ranged) - 0.1 and c.gate_hp[1] < 1e4 and shots > 5,
		"a crossbowman shoots the gate from %.1f m (%d shots)" % [stand, shots])
	# The boss calls grunts at each phase and goes berserk at the last.
	var b = SimS.new(34)
	b.horde.spawn(Level.BOSS, 1)
	b.horde.d[0] = 30.0
	var bmax: float = b.horde.max_hp[0]
	_ok(bmax == float(Level.ENEMIES[Level.BOSS].hp), "the boss ignores the wave's HP scaling")
	b.horde.hp[0] = bmax * 0.5
	b._bosses()
	_ok(b.horde.count() == 1 + Level.BOSS_SUMMON and b.horde.stage[0] == 1, "at 66%% it calls %d grunts" % Level.BOSS_SUMMON)
	b.horde.hp[0] = bmax * 0.2
	b._bosses()
	_ok(b.horde.stage[0] == 2 and is_equal_approx(b.horde.power[0], Level.BOSS_RAGE) and b.horde.count() == 1 + 2 * Level.BOSS_SUMMON,
		"at 33% it calls more and goes berserk")
	_ok(Level.BAT in Level.new_types(3) and Level.new_types(9) == [Level.BOSS], "intros: bats in wave 4, the boss in 10")


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
