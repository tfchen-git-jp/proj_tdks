class_name Sim
extends RefCounted
## The whole game's rules, free of nodes and rendering: main.gd feeds it a
## move vector each step, calls buy() / start_wave() from the popups, and
## draws what it reports. Headless balance runs and the tests drive this
## same class.
##
## Phases: "build" (no enemies; stand on a spot to build or upgrade, stand
## on the start spot for START_COUNTDOWN s to begin the next wave) and "attack" (the wave walks
## in; no building). Clearing the last wave (Level.WAVES) wins.

const DROP_CAP := 1400
## Selling a building pays back this share of everything spent on it
## (user, 2026-10-10: punishing on purpose).
const SELL_REFUND := 0.4
## The end-of-wave sweep: every coin left flies to the hero, longer
## flights taking longer (VACUUM_BASE + distance / VACUUM_SPEED).
const VACUUM_BASE := 0.35
const VACUUM_SPEED := 24.0
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
var base_hp: float = Level.BASE_HP  # the keep's HP (enemies at it hit it)
var _base_hit_t := 0.0  # rate limit for base_hit events
var start_t := 0.0  # seconds the hero has stood on the start pad (build phase)

var hero_pos: Vector3 = Level.HERO_START
var hero_prev: Vector3 = Level.HERO_START  # hero_pos before the last step (view interpolation)
var hero_vel := Vector3.ZERO
var hero_aim := Vector3.ZERO  # last shot direction (zero = none yet)
var hero_aim_t := 9.0  # seconds since the last shot
var _hero_cd := 0.0

## Hero upgrades (Perks). Kills near the hero give xp; each level banks a
## pick, offered after the wave (and a relic after Perks.RELIC_WAVES).
var xp := 0.0
var level := 1  # the hero's level (starts at 1; each level-up banks a pick)
var pending_levels := 0  # level-ups not yet offered
var pending_relics := 0
var perks := {}  # card id -> tier owned (1..MAX_TIER)
var relics := {}  # relic id -> tier owned (1..MAX_TIER)
var offer: Array = []  # the card / relic ids on offer now (build phase)
var offer_relic := false
var rerolls := 0
var _card_rng := RandomNumberGenerator.new()
var _shots := 0  # for Volley
var _thunder_cd := 0.0
var _wisp_cd := 0.0
var _near_kills := 0  # for Midas
var _bounty_left := 0
## Damage dealt by source (balance stats): hero (bolts, burning,
## lightning, wisp, blasts) and each tower kind.
var dealt_by := {}

## Built things by spot id: {spot, kind, level, spec, spent, cd, aim, pos,
## broken}. spec: the tower's level-IV choice ("" before); spent: all the
## gold paid for it (selling refunds SELL_REFUND of that).
var buildings := {}
## Flying shots: {kind, from, to, uid, t, dur, arc, dmg, splash, hits}.
var projectiles: Array[Dictionary] = []

## Coins on the ground (fly < 0) or flying to the hero (fly = seconds).
var drop_pos := PackedVector3Array()
var drop_val := PackedInt32Array()
var drop_fly := PackedFloat32Array()
var drop_from := PackedVector3Array()
var drop_dur := PackedFloat32Array()  # flight time to the hero, s

## Things that happened this step, for sound and effects:
## shot / hit / boom / pulse / kill / pay / built / gate_broken /
## wave_start / wave_cleared / base_hit.
var events: Array[Dictionary] = []
var _pending: Array[Dictionary] = []  # from buy() / start_wave() between steps

var _spawned: Array[int] = []
var _rng := RandomNumberGenerator.new()
var seed_value := 1
## The build-phase state just before the current wave began (to_save()):
## the game writes it as the run's checkpoint when the wave starts.
var checkpoint := {}


func _init(seed_v := 1) -> void:
	seed_value = seed_v
	_rng.seed = seed_v
	_card_rng.seed = seed_v * 7919 + 13
	for pts in Level.LANES:
		tracks.push_back(Track.new(pts))
	horde = Horde.new(tracks, seed_v)
	horde.keep_hp = base_hp


func step(dt: float, move: Vector2) -> void:
	events = _pending
	_pending = []
	time += dt
	# The hero holds still (and no menu opens) while the end-of-wave coin
	# sweep flies in.
	_hero_move(dt, move if state == "play" and not sweeping() else Vector2.ZERO)
	if state != "play":
		return
	if phase == "build" and finished():
		if drop_pos.is_empty():
			state = "win"
			return
	elif phase == "build":
		# The coin sweep lands first, then the picks open one by one; the
		# start countdown waits for all of them.
		if offer.is_empty() and drop_pos.is_empty():
			_next_offer()
		start_t = start_t + dt if at_start_spot() and not picks_waiting() else 0.0
		if start_t >= Level.START_COUNTDOWN:
			start_wave()
	if phase == "attack":
		wave_time += dt
		_spawn()
	_hero_shoot(dt)
	_engineer()
	_towers(dt)
	_projectiles(dt)
	var burnt := horde.burn_dealt
	var burnt_m := horde.burn_mortar
	horde.step(dt)
	dealt_by.hero = float(dealt_by.get("hero", 0.0)) + horde.burn_dealt - burnt
	if horde.burn_mortar > burnt_m:
		dealt_by.mortar = float(dealt_by.get("mortar", 0.0)) + horde.burn_mortar - burnt_m
	for sh in horde.shots:
		events.push_back({type = "enemy_shot", from = sh[0], to = sh[1]})
	_bosses()
	_gates()
	_drops_from_deaths()
	_drops_step(dt)
	_base_hit_t -= dt
	if horde.keep_hp < base_hp:
		base_hp = horde.keep_hp
		if _base_hit_t <= 0.0:
			_base_hit_t = 0.5
			events.push_back({type = "base_hit"})
	if base_hp <= 0:
		base_hp = 0
		state = "lose"
		return
	if phase == "attack" and _wave_spawned() and horde.count() == 0:
		_end_wave()


# --- phases ----------------------------------------------------------------

## End of a wave: coins still flying to the hero.
func sweeping() -> bool:
	return phase == "build" and not drop_pos.is_empty()


func at_start_spot() -> bool:
	return phase == "build" and not sweeping() and hero_pos.distance_to(Level.START_SPOT) < Level.SPOT_REACH


func start_wave() -> bool:
	if phase != "build" or state != "play":
		return false
	checkpoint = to_save()
	phase = "attack"
	wave_time = 0.0
	start_t = 0.0
	_spawned.clear()
	for g in Level.WAVES[wave]:
		_spawned.push_back(0)
	_bounty_left = int(pv("bounty", 0))
	_pending.push_back({type = "wave_start", wave = wave, new = Level.new_types(wave)})
	return true


func _spawn() -> void:
	var groups: Array = Level.WAVES[wave]
	for i in groups.size():
		var g: Dictionary = groups[i]
		while _spawned[i] < int(g.count) and wave_time >= float(g.t) + _spawned[i] * float(g.every):
			var boss: bool = Level.ENEMIES[int(g.type)].get("boss", false)
			horde.spawn(int(g.type), int(g.lane), float(g.get("hp", 1.0)) if boss else Level.wave_hp(wave))
			_spawned[i] += 1


func _wave_spawned() -> bool:
	var groups: Array = Level.WAVES[wave]
	for i in groups.size():
		if _spawned[i] < int(groups[i].count):
			return false
	return true


func _end_wave() -> void:
	var income := 0
	var cap := 0
	var rate := 0.0  # the best bank's rate (rates never stack)
	for b in buildings.values():
		if b.kind == "farm":
			income += int(Level.stats("farm", b.level).income)
		if b.kind == "bank":
			cap += int(Level.stats("bank", b.level).cap)
			rate = maxf(rate, float(Level.stats("bank", b.level).rate))
		if b.kind == "gate":  # repaired for the next wave
			b.broken = false
			_raise_gate(b)
	# Interest on what is held now (coins still on the ground included: they
	# are swept to the hero just below), before the farms pay.
	var held := coins
	for v in drop_val:
		held += v
	var interest := mini(floori(held * rate), cap)
	coins += income + interest
	if "laststand" in relics:
		base_hp = minf(Level.BASE_HP, base_hp + Level.BASE_HP * float(rv("laststand")))
		horde.keep_hp = base_hp
	events.push_back({type = "wave_cleared", wave = wave, income = income, interest = interest})
	_vacuum()
	if (wave + 1) in Perks.RELIC_WAVES:
		pending_relics += 1
	wave += 1
	phase = "build"
	# After the last wave the coins still fly in; the win follows (step).


## Every wave cleared (the game ends once the coin sweep has landed).
func finished() -> bool:
	return wave >= Level.WAVES.size()


## Bosses: at each Level.BOSS_PHASES HP fraction call BOSS_SUMMON armored
## men around itself; at the last one also go berserk (faster, harder
## hitting, and slows / freezes stop working on it).
func _bosses() -> void:
	var h := horde
	for i in h.count():
		if not Level.ENEMIES[h.kind[i]].get("boss", false) or h.hp[i] <= 0.0:
			continue
		var st := h.stage[i]
		if st >= Level.BOSS_PHASES.size() or h.hp[i] > h.max_hp[i] * float(Level.BOSS_PHASES[st]):
			continue
		h.stage[i] = st + 1
		var at := h.pos[i]
		var ln := h.lane[i]
		var d0 := h.d[i]
		for k in Level.BOSS_SUMMON:
			h.spawn(Level.BOSS_SUMMON_TYPE, ln, Level.wave_hp(wave), maxf(0.0, d0 - 1.2 - k * 0.5))
		var berserk := st + 1 == Level.BOSS_PHASES.size()
		if berserk:
			h.power[i] = Level.BOSS_RAGE
			h.spd[i] *= Level.BOSS_RAGE
			h.make_immune(i)
		events.push_back({type = "boss_phase", pos = at, berserk = berserk})


## Wave over: every coin still lying around flies to the hero (no point
## sweeping them by hand: gold can only be spent in the build phase).
func _vacuum() -> void:
	for i in drop_pos.size():
		if drop_fly[i] >= 0.0:
			continue
		drop_fly[i] = 0.0
		drop_from[i] = drop_pos[i]
		drop_dur[i] = VACUUM_BASE + _flat_dist(drop_pos[i], hero_pos) / VACUUM_SPEED + _rng.randf_range(0.0, 0.3)
	if not drop_pos.is_empty():
		events.push_back({type = "vacuum", n = drop_pos.size()})


## Damage enemy i, credited to `src` (dealt_by). Returns true if it died.
## armored false: armour doesn't count (the Sniper).
func _hurt(i: int, amount: float, src: String, armored := true) -> bool:
	var before := horde.dealt
	var died := horde.damage(i, amount, true, armored)
	dealt_by[src] = float(dealt_by.get(src, 0.0)) + horde.dealt - before
	return died


# --- hero upgrades ------------------------------------------------------------

## Tier owned of card `id` (0 = none).
func tier(id: String) -> int:
	return int(perks.get(id, 0))


## Card `id`'s value at the owned tier, or `none` without it.
func pv(id: String, none: float) -> float:
	var t := tier(id)
	return none if t == 0 else float(Perks.CARDS[id].v[t - 1])


## Relic `id`'s value at the owned tier (Perks.RELICS v), or null.
func rv(id: String) -> Variant:
	var t := int(relics.get(id, 0))
	return null if t == 0 else Perks.RELICS[id].v[t - 1]


func hero_damage() -> float:
	return float(Level.HERO.damage) * pv("dmg", 1.0) * (1.0 + standard_buff(hero_pos))


func hero_range() -> float:
	return float(Level.HERO.range) + pv("range", 0.0)


func hero_speed() -> float:
	return float(Level.HERO.speed) * pv("boots", 1.0)


func reroll_cost() -> int:
	return Perks.REROLL_COST * (rerolls + 1)


## Level-ups or relics still to pick (offered once the coins are in).
func picks_waiting() -> bool:
	return not offer.is_empty() or pending_levels + pending_relics > 0


## What is on offer, for the picker: [Perks.view(...)].
func offer_view() -> Array:
	var out := []
	for id in offer:
		out.push_back(Perks.view(id, offer_relic, relics if offer_relic else perks))
	return out


## Open the next offer if none is open: a pending relic first, then a
## pending level-up. Nothing left to give (all maxed) drops the pick.
func _next_offer() -> void:
	while offer.is_empty() and (pending_relics > 0 or pending_levels > 0):
		if pending_relics > 0:
			pending_relics -= 1
			_roll(true)
		else:
			pending_levels -= 1
			_roll(false)


func _roll(relic: bool) -> void:
	var pool := []
	if relic:
		for id in Perks.RELICS:
			if int(relics.get(id, 0)) < Perks.MAX_TIER:
				pool.push_back(id)
	else:
		for id in Perks.CARDS:
			if tier(id) < Perks.MAX_TIER:
				pool.push_back(id)
	# Fisher-Yates with the cards' own dice (saved with the run).
	for i in range(pool.size() - 1, 0, -1):
		var j := _card_rng.randi_range(0, i)
		var t: Variant = pool[i]
		pool[i] = pool[j]
		pool[j] = t
	offer = pool.slice(0, Perks.OFFER_SIZE)
	offer_relic = relic


## Take offer `k`. Returns false if there is no such offer.
func pick(k: int) -> bool:
	if k < 0 or k >= offer.size():
		return false
	var id: String = offer[k]
	if offer_relic:
		relics[id] = int(relics.get(id, 0)) + 1
	else:
		perks[id] = tier(id) + 1
	_pending.push_back({type = "perk", id = id, relic = offer_relic,
		tier = int(relics[id]) if offer_relic else tier(id)})
	offer = []
	_next_offer()
	return true


## Pay reroll_cost() for a fresh offer of the same kind.
func reroll() -> bool:
	if offer.is_empty() or coins < reroll_cost():
		return false
	coins -= reroll_cost()
	rerolls += 1
	_roll(offer_relic)
	return true


## Kills within this of the hero give XP: Perks.XP_RADIUS, or a little
## past the hero's shooting range when Long Shot takes that further.
func xp_radius() -> float:
	return maxf(Perks.XP_RADIUS, hero_range() + Perks.XP_PAST_RANGE)


func _gain_xp(n: float) -> void:
	n *= pv("scholar", 1.0)
	xp += n
	events.push_back({type = "xp", n = n})
	while xp >= Perks.xp_needed(level):
		xp -= Perks.xp_needed(level)
		level += 1
		pending_levels += 1
		var opened := []
		for sp in Level.SPOTS:
			if int(sp.get("lv", 1)) == level:
				opened.push_back(sp.id)
		events.push_back({type = "level_up", level = level, opened = opened})


## Engineer: gates near the hero shrug off part of the damage.
func _engineer() -> void:
	var armor := pv("engineer", 0.0)
	for g in horde.gate_armor.size():
		horde.gate_armor[g] = 0.0
	if armor <= 0.0:
		return
	for b in buildings.values():
		if b.kind == "gate" and not b.broken and _flat_dist(b.pos, hero_pos) <= Perks.ENGINEER_R:
			horde.gate_armor[int(b.spot.slot)] = armor


## Rally / Spotter: is a tower at p inside the hero's aura?
func _in_aura(p: Vector3) -> bool:
	return _flat_dist(p, hero_pos) <= Perks.AURA


static func _flat_dist(a: Vector3, b: Vector3) -> float:
	return Vector2(a.x - b.x, a.z - b.z).length()


## Where the Spirit Wisp is (circling above the hero).
func wisp_pos() -> Vector3:
	return hero_pos + Vector3(cos(time * 2.2) * 1.1, 1.6 + 0.15 * sin(time * 3.1), sin(time * 2.2) * 1.1)


# --- save / load ----------------------------------------------------------------

const SAVE_VERSION := 4  # 2: hero upgrades; 3: hero level counts from 1; 4: specs, spent, relic tiers


## The run as plain data (build phase only: no enemies or shots in flight).
func to_save() -> Dictionary:
	var bl := []
	for id in buildings:
		var b: Dictionary = buildings[id]
		bl.push_back([id, b.kind, b.level, b.spec, b.spent])
	# Build phase: every coin is on its way to the hero (_vacuum): bank it.
	var held := coins
	for v in drop_val:
		held += v
	return {v = SAVE_VERSION, seed = seed_value, wave = wave, coins = held, collected = collected,
		base_hp = base_hp, time = time, hero = [hero_pos.x, hero_pos.z], buildings = bl,
		rng = str(_rng.state), hrng = str(horde._rng.state), killed = horde.killed,
		xp = xp, level = level, pending_levels = pending_levels, pending_relics = pending_relics,
		perks = perks, relics = relics, offer = offer, offer_relic = offer_relic, rerolls = rerolls,
		crng = str(_card_rng.state), shots = _shots, near_kills = _near_kills}


## A Sim in the build phase of the saved wave.
static func from_save(d: Dictionary) -> Sim:
	var s := Sim.new(int(d.seed))
	s.wave = int(d.wave)
	s.coins = int(d.coins)
	s.collected = int(d.collected)
	s.base_hp = float(d.base_hp)
	s.horde.keep_hp = s.base_hp
	s.time = float(d.time)
	s.hero_pos = Vector3(float(d.hero[0]), 0.0, float(d.hero[1]))
	s.hero_prev = s.hero_pos
	s.horde.killed = int(d.killed)
	s._rng.state = int(d.rng)
	s.horde._rng.state = int(d.hrng)
	s.xp = float(d.xp)
	s.level = int(d.level) + (1 if int(d.v) < 3 else 0)  # v2 counted level-ups from 0
	s.pending_levels = int(d.pending_levels)
	s.pending_relics = int(d.pending_relics)
	# Cards / relics retired since the save (Magnet, v0.1.17) are dropped;
	# an offer that showed one is rolled again.
	for id in d.perks:
		if Perks.CARDS.has(String(id)):
			s.perks[String(id)] = int(d.perks[id])
	# v3 and before: a list of relic ids (one tier each).
	var rl: Dictionary = d.relics if d.relics is Dictionary else {}
	if d.relics is Array:
		for id in d.relics:
			rl[id] = 1
	for id in rl:
		if Perks.RELICS.has(String(id)):
			s.relics[String(id)] = int(rl[id])
	s.offer = Array(d.offer)
	s.offer_relic = bool(d.offer_relic)
	s.rerolls = int(d.rerolls)
	s._card_rng.state = int(d.crng)
	s._shots = int(d.shots)
	s._near_kills = int(d.near_kills)
	for id in s.offer:
		if not (Perks.RELICS if s.offer_relic else Perks.CARDS).has(String(id)):
			if s.offer_relic:
				s.pending_relics += 1
			else:
				s.pending_levels += 1
			s.offer = []
			s._next_offer()
			break
	for e in d.buildings:
		for sp in Level.SPOTS:
			if sp.id == e[0]:
				var kind := String(e[1])
				var lv := int(e[2])
				# v3: level IV meant the old plain IV: the first spec now.
				var spec := String(e[3]) if e.size() > 3 else ""
				if lv >= Level.BUILDINGS[kind].levels.size() and spec == "":
					spec = String(Level.BUILDINGS[kind].specs[0].id)
				var spent := 0
				for k in lv + 1:
					spent += int(Level.stats(kind, k, spec).cost)
				var b := {spot = sp, kind = kind, level = lv, spec = spec,
					spent = int(e[4]) if e.size() > 4 else spent, cd = 0.5, aim = Vector3(0, 0, 1),
					pos = sp.pos, broken = false}
				s.buildings[sp.id] = b
				if b.kind == "gate":
					s._raise_gate(b)
	return s


# --- building -----------------------------------------------------------------

## The spot the hero stands at (build phase only), or {}.
func spot_under_hero() -> Dictionary:
	if phase != "build" or state != "play" or sweeping():
		return {}
	# The nearest one: spots can sit close together (a gate pad by a tower).
	var best := {}
	var best_d := Level.SPOT_REACH
	for s in Level.SPOTS:
		var dd := hero_pos.distance_to(s.pos)
		if dd < best_d and unlocked(s):
			best = s
			best_d = dd
	return best


## What can be done at a spot: [{kind, level, spec, cost, name, desc,
## upgrade, ok}], plus {kind = "sell", cost = the refund} on a built one.
## An empty spot offers every building of its kind; a built one its next
## level (a tower at III: both specs; none at max).
func options(spot: Dictionary) -> Array:
	var out := []
	var b: Dictionary = buildings.get(spot.id, {})
	if b.is_empty():
		for kind in Level.BUILDINGS:
			if Level.BUILDINGS[kind].spot == spot.kind:
				out.push_back(_option(kind, 0, "", false))
		return out
	if b.level + 1 < Level.BUILDINGS[b.kind].levels.size():
		out.push_back(_option(b.kind, b.level + 1, "", true))
	elif b.level + 1 < Level.max_levels(b.kind):
		for sp in Level.BUILDINGS[b.kind].specs:
			out.push_back(_option(b.kind, b.level + 1, String(sp.id), true))
	out.push_back({kind = "sell", level = b.level, spec = "", cost = sell_value(b), upgrade = false, ok = true,
		name = "Sell", desc = ""})
	return out


func _option(kind: String, level: int, spec: String, upgrade: bool) -> Dictionary:
	var st := Level.stats(kind, level, spec)
	var cost := int(st.cost)
	return {kind = kind, level = level, spec = spec, cost = cost, upgrade = upgrade, ok = coins >= cost,
		name = st.get("name", Level.BUILDINGS[kind].name), desc = st.get("desc", Level.BUILDINGS[kind].desc)}


## Build `kind` on an empty spot, or upgrade what stands there (a tower at
## level III to `spec`). Returns true if it happened (enough gold, right
## phase).
func buy(spot_id: String, kind: String, spec := "") -> bool:
	if phase != "build" or state != "play":
		return false
	var spot := _spot(spot_id)
	if spot.is_empty() or Level.BUILDINGS[kind].spot != spot.kind or not unlocked(spot):
		return false
	var b: Dictionary = buildings.get(spot_id, {})
	var level := 0
	if not b.is_empty():
		if b.kind != kind or b.level + 1 >= Level.max_levels(kind):
			return false
		level = b.level + 1
	var specs: bool = level >= Level.BUILDINGS[kind].levels.size()
	if specs and Level.spec_of(kind, spec).is_empty() or not specs and spec != "":
		return false
	var cost := int(Level.stats(kind, level, spec).cost)
	if coins < cost:
		return false
	coins -= cost
	if b.is_empty():
		b = {spot = spot, kind = kind, level = 0, spec = "", spent = 0, cd = 0.5, aim = Vector3(0, 0, 1),
			pos = spot.pos, broken = false}
		buildings[spot_id] = b
	else:
		b.level = level
		b.spec = spec
	b.spent += cost
	if kind == "gate":
		_raise_gate(b)
	_pending.push_back({type = "built", spot = spot, kind = kind, level = level, spec = spec, cost = cost})
	return true


## Gold back for selling building b.
func sell_value(b: Dictionary) -> int:
	return floori(int(b.spent) * SELL_REFUND)


## Tear down what stands on `spot_id` for sell_value() (build phase).
func sell(spot_id: String) -> bool:
	if phase != "build" or state != "play" or not buildings.has(spot_id):
		return false
	var b: Dictionary = buildings[spot_id]
	var refund := sell_value(b)
	coins += refund
	buildings.erase(spot_id)
	if b.kind == "gate":
		var g := int(b.spot.slot)
		horde.gate_d[g] = -1.0
		horde.gate_hp[g] = 0.0
	_pending.push_back({type = "sold", spot = b.spot, kind = b.kind, refund = refund})
	return true


func _spot(id: String) -> Dictionary:
	for sp in Level.SPOTS:
		if sp.id == id:
			return sp
	return {}


func _raise_gate(b: Dictionary) -> void:
	var g := int(b.spot.slot)
	var ln := int(b.spot.lane)
	horde.gate_lane[g] = ln
	horde.gate_d[g] = tracks[ln].closest_d(b.spot.pos)
	horde.gate_hp[g] = float(Level.bstats(b).hp)


## HP fraction of the gate in `slot` (0 if none stands there).
func gate_hp_frac(slot: int) -> float:
	for b in buildings.values():
		if b.kind == "gate" and int(b.spot.slot) == slot and not b.broken:
			return clampf(horde.gate_hp[slot] / float(Level.bstats(b).hp), 0.0, 1.0)
	return 0.0


## Can the hero build on `spot` yet (its `lv` reached, or already built)?
func unlocked(spot: Dictionary) -> bool:
	return level >= int(spot.get("lv", 1)) or buildings.has(spot.id)


func _gates() -> void:
	for b in buildings.values():
		if b.kind != "gate" or b.broken:
			continue
		var g := int(b.spot.slot)
		if horde.gate_hp[g] <= 0.0:
			b.broken = true
			horde.gate_d[g] = -1.0
			events.push_back({type = "gate_broken", lane = int(b.spot.lane), spot = b.spot})


## Solid things as [centre, radius]: the keep and every building but gates.
func obstacles() -> Array:
	var out := [[Level.KEEP_POS, 1.9]]
	for b in buildings.values():
		if b.kind != "gate":
			out.push_back([b.pos, 0.9 if b.kind in ["farm", "bank"] else 0.75])
	return out


## Attack-speed bonus from War Banners covering point p (best one counts):
## a tower's (hero false) or the hero's (War Drums give the hero nothing,
## the Hero's Standard gives it more).
func banner_buff(p: Vector3, hero := false) -> float:
	var best := 0.0
	for b in buildings.values():
		if b.kind == "banner":
			var st := Level.bstats(b)
			if _flat_dist(p, b.pos) <= _reach(b, st):
				best = maxf(best, float(st.get("hero_buff", st.buff)) if hero else float(st.buff))
	return best


## The Hero's Standard's damage bonus for the hero at p (0 outside one).
func standard_buff(p: Vector3) -> float:
	var best := 0.0
	for b in buildings.values():
		if b.kind == "banner" and b.spec == "standard":
			var st := Level.bstats(b)
			if _flat_dist(p, b.pos) <= _reach(b, st):
				best = maxf(best, float(st.hero_buff))
	return best


# --- hero ------------------------------------------------------------------------

func _hero_move(dt: float, move: Vector2) -> void:
	hero_prev = hero_pos
	if move.length() > 1.0:
		move = move.normalized()
	var v := Vector3(move.x, 0.0, move.y) * hero_speed()
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
	_hero_cd -= dt * (1.0 + banner_buff(hero_pos, true))
	hero_aim_t += dt
	if "thunder" in relics:
		_thunder(dt)
	if "wisp" in relics:
		_wisp(dt)
	if _hero_cd > 0.0:
		return
	var r := hero_range()
	var first := horde.nearest(hero_pos, r)
	if first < 0:
		return
	_hero_cd = float(Level.HERO.interval) / pv("aspd", 1.0)
	var targets: Array[int] = [first]
	targets.append_array(horde.nearest_k(hero_pos, r, int(pv("multi", 0.0)), [horde.uid[first]]))
	for v in (2 if "twin" in relics else 1):
		for k in targets.size():
			_fire_bolt(targets[k], -0.12 * v, (float(rv("twin")) if v > 0 else 1.0) * (Perks.MULTI_DAMAGE if k > 0 else 1.0))
	_shots += 1
	if "volley" in relics and _shots % int(rv("volley")[0]) == 0:
		for i in horde.nearest_k(hero_pos, r + 2.0, int(rv("volley")[1])):
			_fire_bolt(i, 0.0, 1.0)
		events.push_back({type = "volley", pos = hero_pos})
	var to := horde.pos[first]
	hero_aim = Vector3(to.x - hero_pos.x, 0, to.z - hero_pos.z).normalized()
	hero_aim_t = 0.0
	events.push_back({type = "shot", kind = "hero", from = hero_pos + Vector3(0, MUZZLE.hero, 0)})


## One hero bolt at enemy i, `mult` x the hero's damage, starting `t0` s
## into its flight (negative: held back a moment). Piercing bolts fly straight through a line;
## others home in (and may ricochet).
func _fire_bolt(i: int, t0: float, mult: float) -> void:
	var from := hero_pos + Vector3(0, MUZZLE.hero, 0)
	var to := horde.pos[i] + Vector3(0, CHEST, 0)
	var p: Dictionary
	var pierce := int(pv("pierce", 0.0))
	if pierce > 0:
		var dir := Vector3(to.x - hero_pos.x, 0, to.z - hero_pos.z).normalized()
		var reach := hero_range() + 1.5
		var end := hero_pos + dir * reach + Vector3(0, CHEST, 0)
		var dur := from.distance_to(end) / float(Level.HERO.bolt_speed)
		p = _launch("bolt", from, end, -1, dur, 0.0, hero_damage() * mult)
		for h in horde.on_segment(hero_pos, hero_pos + dir * reach, 0.35, 1 + pierce):
			p.hits.push_back([h.x * dur, horde.uid[int(h.y)]])
	else:
		p = _launch("bolt", from, to, horde.uid[i], from.distance_to(to) / float(Level.HERO.bolt_speed), 0.05, hero_damage() * mult)
		p.bounces = int(pv("ricochet", 0.0))
	p.hero = true
	p.elem = "fire" if tier("fire") > 0 else ("frost" if tier("frost") > 0 else "")
	p.t = t0


## A hero bolt (or a ricochet of one) hits enemy i: every card applies.
func _hero_hit(i: int, p: Dictionary) -> void:
	var dmg: float = p.dmg
	if Level.ENEMIES[horde.kind[i]].get("heavy", false):
		dmg *= pv("slayer", 1.0)
	var crit := _rng.randf() < pv("crit", 0.0)
	if crit:
		dmg *= Perks.CRIT_MULT
	var at := horde.pos[i]
	var id := horde.uid[i]
	_hurt(i, dmg, "hero")
	events.push_back({type = "hit", pos = at, kind = "bolt", crit = crit})
	if tier("fire") > 0:
		horde.ignite(i, float(p.dmg) * pv("fire", 0.0), Perks.BURN_TIME)
	if tier("frost") > 0:
		horde.chill(i, pv("frost", 0.0), Perks.FROST_TIME)
	if tier("blast") > 0:
		var r := pv("blast", 0.0)
		for j in horde.within(at, r):
			if j != i:
				_hurt(j, dmg * 0.5, "hero")
		events.push_back({type = "blast", pos = at, r = r})
	if int(p.get("bounces", 0)) > 0:
		var chain: Array = p.get("chain", [])
		chain = chain + [id]
		var next := horde.nearest_k(at, Perks.RICOCHET_RANGE, 1, chain)
		if not next.is_empty():
			var j := next[0]
			var from := at + Vector3(0, CHEST, 0)
			var to := horde.pos[j] + Vector3(0, CHEST, 0)
			var q := _launch("bolt", from, to, horde.uid[j], from.distance_to(to) / float(Level.HERO.bolt_speed), 0.1,
				float(p.dmg) * Perks.RICOCHET_FALLOFF)
			q.hero = true
			q.elem = p.get("elem", "")
			q.bounces = int(p.bounces) - 1
			q.chain = chain


## Thunderstrike: every few s (by tier), lightning from the sky into the
## toughest enemy near the hero, chaining on to the nearest unhit ones.
func _thunder(dt: float) -> void:
	_thunder_cd -= dt
	if _thunder_cd > 0.0:
		return
	var near := horde.within(hero_pos, Perks.THUNDER_RANGE)
	if near.is_empty():
		return
	var first: int = near[0]
	for i in near:
		if horde.hp[i] > horde.hp[first]:
			first = i
	_thunder_cd = float(rv("thunder")[0])
	var dmg := hero_damage() * Perks.THUNDER_DAMAGE
	var p0 := horde.pos[first]
	var pts: Array[Vector3] = [p0 + Vector3(0.6, 14.0, -1.5)]
	var hit: Array = []
	var cur := first
	while cur >= 0 and hit.size() < int(rv("thunder")[1]):
		var at := horde.pos[cur]
		pts.push_back(at + Vector3(0, CHEST + 0.2, 0))
		hit.push_back(horde.uid[cur])
		_hurt(cur, dmg, "hero")
		var next := horde.nearest_k(at, Perks.THUNDER_JUMP, 1, hit)
		cur = next[0] if not next.is_empty() else -1
	events.push_back({type = "lightning", points = pts})


## Spirit Wisp: shoots plain magic bolts from where it circles.
func _wisp(dt: float) -> void:
	_wisp_cd -= dt
	if _wisp_cd > 0.0:
		return
	var i := horde.nearest(hero_pos, hero_range())
	if i < 0:
		return
	_wisp_cd = float(rv("wisp"))
	var from := wisp_pos()
	var to := horde.pos[i] + Vector3(0, CHEST, 0)
	_launch("wisp", from, to, horde.uid[i], from.distance_to(to) / 14.0, 0.3, hero_damage() * Perks.WISP_DAMAGE)


# --- towers -----------------------------------------------------------------------

func _towers(dt: float) -> void:
	for b in buildings.values():
		if not b.kind in Level.TOWER_KINDS or b.kind == "banner":
			continue
		var st := Level.bstats(b)
		b.cd -= dt * (1.0 + banner_buff(b.pos) + (pv("rally", 0.0) if _in_aura(b.pos) else 0.0))
		if b.cd > 0.0:
			continue
		match String(b.kind):
			"archer": _fire_archer(b, st)
			"ballista": _fire_ballista(b, st)
			"mortar": _fire_mortar(b, st)
			"frost": _pulse_frost(b, st)


## A tower's range, Spotter included.
func _reach(b: Dictionary, st: Dictionary) -> float:
	return float(st.range) + (pv("spotter", 0.0) if _in_aura(b.pos) else 0.0)


## Archer: the enemy nearest the keep (a Sniper: the one with the most HP;
## a Repeater shoots `targets` of them at once).
func _fire_archer(b: Dictionary, st: Dictionary) -> void:
	var r := _reach(b, st)
	var aims: Array[int] = []
	if st.get("toughest", false):
		var t := horde.toughest(b.pos, r)
		if t >= 0:
			aims.push_back(t)
	else:
		aims = horde.first_k(b.pos, r, int(st.get("targets", 1)))
	if aims.is_empty():
		return
	b.cd = float(st.interval)
	var from: Vector3 = b.pos + Vector3(0, MUZZLE.archer, 0)
	for i in aims:
		var to := horde.pos[i] + Vector3(0, CHEST, 0)
		var dist := from.distance_to(to)
		var p := _launch("arrow", from, to, horde.uid[i], dist / (ARROW_SPEED * (2.0 if st.has("toughest") else 1.0)),
			dist * 0.12, float(st.damage))
		p.pierce_armor = st.get("pierce_armor", false)
	var to0 := horde.pos[aims[0]]
	b.aim = Vector3(to0.x - from.x, 0, to0.z - from.z).normalized()
	events.push_back({type = "shot", kind = "archer", from = from, spec = b.spec})


func _fire_ballista(b: Dictionary, st: Dictionary) -> void:
	var i := horde.first_in_range(b.pos, _reach(b, st))
	if i < 0:
		return
	b.cd = float(st.interval)
	var dir: Vector3 = horde.pos[i] - b.pos
	dir.y = 0.0
	dir = dir.normalized()
	b.aim = dir
	var from: Vector3 = b.pos + Vector3(0, MUZZLE.ballista, 0)
	var end: Vector3 = b.pos + dir * (_reach(b, st) + 1.5) + Vector3(0, CHEST, 0)
	var dur := from.distance_to(end) / BALLISTA_SPEED
	# Every enemy on the line is hit when the bolt reaches it.
	var hits := []
	for h in horde.on_segment(b.pos, b.pos + dir * (_reach(b, st) + 1.5), 0.3, int(st.pierce)):
		hits.push_back([h.x * dur, horde.uid[int(h.y)]])
	var p := _launch("ballista", from, end, -1, dur, 0.0, float(st.damage))
	p.hits = hits
	p.harpoon = st.get("harpoon", [])
	events.push_back({type = "shot", kind = "ballista", from = from, spec = b.spec})


func _fire_mortar(b: Dictionary, st: Dictionary) -> void:
	var i := horde.first_in_range(b.pos, _reach(b, st), float(st.min_range), true)
	if i < 0:
		return
	b.cd = float(st.interval)
	# Lead the target: land where it will be when the shell comes down.
	var lead: Vector3 = horde.forward(i) * float(Level.ENEMIES[horde.kind[i]].speed) * horde.pace(i) * SHELL_TIME
	if horde.blocked[i] != 0:
		lead = Vector3.ZERO
	var land: Vector3 = horde.pos[i] + lead
	b.aim = Vector3(land.x - b.pos.x, 0, land.z - b.pos.z).normalized()
	var from: Vector3 = b.pos + Vector3(0, MUZZLE.mortar, 0)
	var spots: Array[Vector3] = [land]
	# Cluster: the shell bursts over the target into bomblets around it.
	var bl: Array = st.get("bomblets", [])
	if not bl.is_empty():
		spots.clear()
		for k in int(bl[0]):
			var ang := TAU * k / float(bl[0]) + _rng.randf_range(-0.3, 0.3)
			var rr := float(bl[1]) * (0.0 if k == 0 else _rng.randf_range(0.55, 1.0))
			spots.push_back(land + Vector3(cos(ang) * rr, 0, sin(ang) * rr))
	for k in spots.size():
		var p := _launch("shell", from, spots[k], -1, SHELL_TIME + 0.06 * k, 3.5, float(st.damage))
		p.splash = float(st.splash)
		p.burn = st.get("burn", [])
		p.small = not bl.is_empty()
	events.push_back({type = "shot", kind = "mortar", from = b.pos, spec = b.spec})


func _pulse_frost(b: Dictionary, st: Dictionary) -> void:
	var hit := horde.within(b.pos, _reach(b, st), true)
	if hit.is_empty():
		return
	b.cd = float(st.interval)
	var bri: Array = st.get("brittle", [])
	for i in hit:
		horde.chill(i, float(st.slow), float(st.slow_time))
		if st.has("freeze"):
			horde.freeze(i, float(st.freeze))
		if not bri.is_empty():
			horde.make_brittle(i, float(bri[0]), float(bri[1]))
		_hurt(i, float(st.damage), "frost")
	events.push_back({type = "pulse", pos = b.pos, r = _reach(b, st), spec = b.spec})


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
						if p.get("hero", false):
							_hero_hit(i, p)
						else:
							var hp_: Array = p.get("harpoon", [])
							if not hp_.is_empty():
								horde.chill(i, float(hp_[0]), float(hp_[1]))
							_hurt(i, p.dmg, "ballista")
							events.push_back({type = "hit", pos = horde.pos[i], kind = "ballista"})
				else:
					rest.push_back(h)
			p.hits = rest
		if p.t < p.dur:
			keep.push_back(p)
			continue
		match String(p.kind):
			"bolt", "arrow", "wisp":
				var i := horde.index_of(p.uid)
				if i >= 0:
					if p.get("hero", false):
						_hero_hit(i, p)
					else:
						_hurt(i, p.dmg, "hero" if p.kind == "wisp" else "archer", not p.get("pierce_armor", false))
						events.push_back({type = "hit", pos = horde.pos[i], kind = p.kind})
			"shell":
				var burn: Array = p.get("burn", [])
				for i in horde.within(p.to, p.splash, true):
					if not burn.is_empty():
						horde.ignite(i, float(burn[0]), float(burn[1]), "mortar")
					_hurt(i, p.dmg, "mortar")
				events.push_back({type = "boom", pos = p.to, r = p.splash, fire = not burn.is_empty(),
					small = p.get("small", false)})
	projectiles = keep


# --- coins ----------------------------------------------------------------------------

func _drops_from_deaths() -> void:
	for death in horde.deaths:
		# A slime bursts into its brood where it fell (same toughness).
		var split: Array = Level.ENEMIES[death.kind].get("split", [])
		for k in (int(split[1]) if not split.is_empty() else 0):
			horde.spawn(int(split[0]), int(death.lane), float(death.mult),
				maxf(0.0, float(death.d) + _rng.randf_range(-0.5, 0.3)), float(death.off) + _rng.randf_range(-0.5, 0.5))
		events.push_back({type = "kill", pos = death.pos, kind = death.kind, d = death.d, lane = death.lane})
		var gold := int(Level.ENEMIES[death.kind].gold)
		var spread := 1.1 if Level.ENEMIES[death.kind].get("big", false) else 0.35
		var pieces := gold_pieces(gold)
		if _flat_dist(death.pos, hero_pos) <= xp_radius():
			_gain_xp(float(Level.ENEMIES[death.kind].xp))
			if _bounty_left > 0:
				_bounty_left -= 1
				pieces.push_back(1)
			if "midas" in relics:
				_near_kills += 1
				if _near_kills % int(rv("midas")) == 0:
					pieces.push_back(20)
					events.push_back({type = "midas", pos = death.pos})
		for v in pieces:
			# On the ground under the body (a bat dies in the air).
			var p: Vector3 = death.pos + Vector3(_rng.randf_range(-spread, spread), 0.0, _rng.randf_range(-spread, spread))
			p.y = 0.0
			if drop_pos.size() >= DROP_CAP:
				drop_val[_rng.randi() % drop_val.size()] += v
				continue
			drop_pos.push_back(p)
			drop_val.push_back(v)
			drop_fly.push_back(-1.0)
			drop_from.push_back(p)
			drop_dur.push_back(FLY_TIME)
	horde.deaths.clear()


## Split a reward into pieces worth an ingot (20), a coin stack (5) or a
## coin (1), largest first, as few pieces as possible.
static func gold_pieces(gold: int) -> Array[int]:
	var out: Array[int] = []
	for v in [20, 5, 1]:
		while gold >= v:
			out.push_back(v)
			gold -= v
	return out


func _drops_step(dt: float) -> void:
	var mg := float(Level.HERO.magnet)
	var r2 := mg * mg
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
		var t := drop_fly[i] / drop_dur[i]
		if t >= 1.0:
			coins += drop_val[i]
			collected += drop_val[i]
			events.push_back({type = "coin"})
			_remove_drop(i)
			continue
		var p := drop_from[i].lerp(hero_pos + Vector3(0, 0.8, 0), t)
		p.y += sin(t * PI) * (0.9 + 1.5 * (drop_dur[i] - FLY_TIME))  # long flights arc higher
		drop_pos[i] = p
		i += 1


func _remove_drop(i: int) -> void:
	var last := drop_pos.size() - 1
	drop_pos[i] = drop_pos[last]; drop_val[i] = drop_val[last]
	drop_fly[i] = drop_fly[last]; drop_from[i] = drop_from[last]; drop_dur[i] = drop_dur[last]
	drop_pos.resize(last); drop_val.resize(last); drop_fly.resize(last); drop_from.resize(last); drop_dur.resize(last)
