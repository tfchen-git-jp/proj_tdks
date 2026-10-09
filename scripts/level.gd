class_name Level
extends RefCounted
## Level 1 (design v2, docs/DESIGN.md): three lanes into the keep, six
## waves, a build phase before each. All tuning lives here as plain data.
## World: metres, x = screen right, z = screen down (toward the camera);
## enemies walk from the bottom (+z) up to the keep at the top.

## Lanes, spawn first, all ending at the keep. 0 = west, 1 = centre, 2 = east.
const LANES := [
	[Vector3(-13.5, 0, 40.0), Vector3(-12.5, 0, 31.0), Vector3(-9.5, 0, 24.0), Vector3(-11.0, 0, 16.0),
		Vector3(-8.5, 0, 8.0), Vector3(-7.5, 0, 1.0), Vector3(-4.5, 0, -4.5), Vector3(-2.4, 0, -8.6)],
	[Vector3(-2.0, 0, 44.0), Vector3(-1.5, 0, 35.0), Vector3(-3.0, 0, 27.0), Vector3(-1.0, 0, 19.0),
		Vector3(-2.5, 0, 11.0), Vector3(-1.2, 0, 3.0), Vector3(-1.0, 0, -8.4)],
	[Vector3(5.5, 0, 40.0), Vector3(5.3, 0, 31.0), Vector3(3.6, 0, 24.0), Vector3(5.2, 0, 16.0),
		Vector3(4.6, 0, 8.0), Vector3(3.6, 0, 1.0), Vector3(1.8, 0, -4.5), Vector3(0.4, 0, -8.6)],
]
const LANE_NAMES := ["West", "Centre", "East"]
const ROAD_HALF_WIDTH := 1.0
const KEEP_POS := Vector3(-1.0, 0, -11.2)
const BASE_HP := 600.0  # keep HP (enemies at it deal their dps)
const START_GOLD := 30
const HERO_START := Vector3(-1.0, 0, -5.5)
## Stand here during the build phase to start the next wave: it starts
## after START_COUNTDOWN s on the pad; walking off cancels.
const START_SPOT := Vector3(2.6, 0, -10.6)
const START_COUNTDOWN := 5.0
## Playable rectangle for the hero (x, z, width, depth).
const BOUNDS := Rect2(-14.5, -13.2, 21.7, 44.0)
const CLIFF_X := 7.6  # east gorge edge
## Enemies become targetable this far OUTSIDE the hero's walkable area
## (the "start line", marked on each road). Was 1.5 m inside it until
## v0.1.15: at the bottom of the centre lane enemies stood well inside the
## hero's range circle unhittable (user, 2026-10-09). Coins that would
## land out of the magnet's reach are nudged in (Sim.COIN_AREA).
const START_LINE_OUT := 2.0

const HERO := {
	speed = 5.2, range = 6.0, interval = 0.4, damage = 2.0,
	magnet = 2.0,  # coins inside this radius fly to the hero
	bolt_speed = 26.0,
}

## Buildings. Each has levels; level 0 is what you build, the rest are
## upgrades (towers I-IV, farms, banks and gates I-III). "spot" says which spot kind it goes on.
const BUILDINGS := {
	archer = {name = "Archer Tower", spot = "tower", desc = "Long range, quick single arrows.",
		levels = [{cost = 15, range = 6.0, interval = 0.8, damage = 2.0},
			{cost = 25, range = 6.5, interval = 0.65, damage = 3.0},
			{cost = 40, range = 7.0, interval = 0.5, damage = 4.5},
			{cost = 60, range = 7.5, interval = 0.4, damage = 6.5}]},
	ballista = {name = "Ballista", spot = "tower", desc = "Slow heavy bolt that pierces a line.",
		levels = [{cost = 30, range = 8.0, interval = 1.6, damage = 6.0, pierce = 6},
			{cost = 40, range = 8.5, interval = 1.4, damage = 9.0, pierce = 8},
			{cost = 60, range = 9.0, interval = 1.2, damage = 13.0, pierce = 10},
			{cost = 85, range = 9.5, interval = 1.0, damage = 18.0, pierce = 12}]},
	mortar = {name = "Mortar", spot = "tower", desc = "Lobs boulders that hit a group. Can't hit up close.",
		levels = [{cost = 35, range = 7.0, min_range = 2.5, interval = 2.4, damage = 6.0, splash = 1.3},
			{cost = 45, range = 7.5, min_range = 2.5, interval = 2.1, damage = 9.0, splash = 1.5},
			{cost = 65, range = 8.0, min_range = 2.5, interval = 1.8, damage = 13.0, splash = 1.7},
			{cost = 90, range = 8.5, min_range = 2.5, interval = 1.5, damage = 18.0, splash = 1.9}]},
	# Slow pulses, long chill (user, 2026-10-09: was a 1 s pulse). Chilled
	# enemies walk AND attack slower.
	frost = {name = "Frost Crystal", spot = "tower", desc = "Chills everything near it: slower walking and attacks, light damage.",
		levels = [{cost = 25, range = 3.8, interval = 2.5, damage = 1.0, slow = 0.35, slow_time = 3.5},
			{cost = 35, range = 4.2, interval = 2.5, damage = 1.8, slow = 0.45, slow_time = 4.0},
			{cost = 50, range = 4.6, interval = 2.5, damage = 2.8, slow = 0.55, slow_time = 4.5},
			{cost = 70, range = 5.0, interval = 2.5, damage = 4.0, slow = 0.62, slow_time = 5.0}]},
	banner = {name = "War Banner", spot = "tower", desc = "No attack. Towers AND the hero inside its ring attack faster.",
		levels = [{cost = 30, range = 4.5, buff = 0.25},
			{cost = 45, range = 5.0, buff = 0.4},
			{cost = 60, range = 5.5, buff = 0.55},
			{cost = 80, range = 6.0, buff = 0.7}]},
	farm = {name = "Farm", spot = "eco", desc = "A fixed amount of gold after every wave.",
		levels = [{cost = 20, income = 6}, {cost = 30, income = 12}, {cost = 45, income = 20}]},
	# Interest instead of a fixed income: BANK_RATE of the gold you hold when
	# a wave ends. The rate never stacks; each bank only adds to the cap, so
	# a bank beats a farm only while you sit on ~200+ gold (user, 2026-10-09).
	bank = {name = "Bank", spot = "eco", desc = "10% interest on the gold you hold after each wave, up to a cap.",
		levels = [{cost = 30, cap = 10}, {cost = 40, cap = 18}, {cost = 55, cap = 28}]},
	gate = {name = "Gate", spot = "gate", desc = "Blocks the lane until broken. Repaired after each wave.",
		levels = [{cost = 30, hp = 220.0}, {cost = 40, hp = 420.0}, {cost = 60, hp = 700.0}]},
}
const TOWER_KINDS := ["archer", "ballista", "mortar", "frost", "banner"]
const BANK_RATE := 0.1

## Building spots. kind: tower / gate / eco (farm or bank); gates also
## name their lane.
const SPOTS := [
	{id = "w_mid", kind = "tower", pos = Vector3(-6.0, 0, 20.0)},
	{id = "w_out", kind = "tower", pos = Vector3(-13.6, 0, 9.5)},
	{id = "w_in", kind = "tower", pos = Vector3(-4.6, 0, 3.6)},
	{id = "c_far", kind = "tower", pos = Vector3(0.9, 0, 28.5)},
	{id = "e_mid", kind = "tower", pos = Vector3(1.6, 0, 12.6)},
	{id = "e_in", kind = "tower", pos = Vector3(1.1, 0, 2.6)},
	{id = "k_west", kind = "tower", pos = Vector3(-4.6, 0, -8.6)},
	{id = "k_east", kind = "tower", pos = Vector3(3.6, 0, -7.2)},
	# One tower spot covering each gate's queue (user, 2026-10-10).
	{id = "gw_t", kind = "tower", pos = Vector3(-13.6, 0, 23.6)},
	{id = "gc_t", kind = "tower", pos = Vector3(-5.2, 0, 15.6)},
	{id = "ge_t", kind = "tower", pos = Vector3(1.5, 0, 22.2)},
	# Twice the tower spots (user, 2026-10-09: room for banner clusters):
	# found by a grid search for 2.3-3.4 m off a road, farthest from the rest.
	{id = "x_w1", kind = "tower", pos = Vector3(-8.2, 0, 29.6)},
	{id = "x_w2", kind = "tower", pos = Vector3(-11.2, 0, 2.6)},
	{id = "x_e1", kind = "tower", pos = Vector3(5.8, 0, -1.4)},
	{id = "x_w3", kind = "tower", pos = Vector3(-13.2, 0, 15.1)},
	{id = "x_c1", kind = "tower", pos = Vector3(-5.2, 0, 25.1)},
	{id = "x_w4", kind = "tower", pos = Vector3(-3.7, 0, -1.4)},
	{id = "x_c2", kind = "tower", pos = Vector3(0.3, 0, 7.6)},
	{id = "x_e2", kind = "tower", pos = Vector3(2.3, 0, 17.6)},
	{id = "x_c3", kind = "tower", pos = Vector3(-4.7, 0, 8.1)},
	{id = "x_w5", kind = "tower", pos = Vector3(-10.7, 0, 6.6)},
	{id = "x_w6", kind = "tower", pos = Vector3(-13.7, 0, 27.6)},
	{id = "g_west", kind = "gate", lane = 0, pos = Vector3(-14.0, 0, 21.0)},
	{id = "g_centre", kind = "gate", lane = 1, pos = Vector3(-5.6, 0, 12.4)},
	{id = "g_east", kind = "gate", lane = 2, pos = Vector3(6.5, 0, 20.2)},
	{id = "f_1", kind = "eco", pos = Vector3(-7.5, 0, -11.0)},
	{id = "f_2", kind = "eco", pos = Vector3(-10.5, 0, -4.5)},
	{id = "f_3", kind = "eco", pos = Vector3(5.2, 0, -10.4)},
]
const PAD_SIZE := 1.5
## How near a spot's centre the hero must stand for its build menu.
const SPOT_REACH := 1.45

## Seconds per attack swing cycle (matches the baked attack clips' feel).
const ATTACK_CYCLE := 0.55

## Enemy types. xp: what a kill near the hero is worth (Perks.XP_RADIUS).
## dps hits gates and the keep (enemies that reach the keep
## stand and attack it until killed).
## heavy: shoves light enemies out of its way in a gate queue (they never
## hold it up). reach: m behind the front rank it can still hit the gate
## from (a second giant swings over the first one's shoulder).
const ENEMIES := [
	{name = "grunt", hp = 3.0, speed = 1.7, radius = 0.28, gold = 1, xp = 1, dps = 2.0},
	{name = "armored", hp = 12.0, speed = 1.35, radius = 0.32, gold = 3, xp = 3, dps = 4.0},
	{name = "brute", hp = 90.0, speed = 0.95, radius = 0.7, gold = 15, xp = 12, dps = 18.0,
		heavy = true, reach = 1.3},
	{name = "runner", hp = 2.0, speed = 3.1, radius = 0.25, gold = 1, xp = 1, dps = 1.5},
]
enum { GRUNT, ARMORED, BRUTE, RUNNER }
const WEST := 0
const CENTRE := 1
const EAST := 2

const HP_PER_WAVE := 0.25
const HP_PER_WAVE2 := 0.05

## Waves. Each group: `count` enemies of `type` on `lane`, one every
## `every` s, starting `t` s into the wave.
const WAVES := [
	[{lane = CENTRE, type = GRUNT, count = 20, every = 0.7, t = 0.0}],
	[{lane = WEST, type = GRUNT, count = 22, every = 0.55, t = 0.0},
		{lane = EAST, type = GRUNT, count = 22, every = 0.55, t = 4.0},
		{lane = CENTRE, type = ARMORED, count = 3, every = 2.0, t = 8.0}],
	[{lane = CENTRE, type = GRUNT, count = 22, every = 0.5, t = 0.0},
		{lane = WEST, type = ARMORED, count = 6, every = 1.5, t = 3.0},
		{lane = EAST, type = RUNNER, count = 14, every = 0.4, t = 8.0}],
	[{lane = WEST, type = GRUNT, count = 25, every = 0.4, t = 0.0},
		{lane = CENTRE, type = GRUNT, count = 25, every = 0.4, t = 2.0},
		{lane = EAST, type = GRUNT, count = 25, every = 0.4, t = 4.0},
		{lane = CENTRE, type = BRUTE, count = 1, every = 1.0, t = 10.0},
		{lane = EAST, type = ARMORED, count = 8, every = 1.2, t = 12.0}],
	[{lane = WEST, type = GRUNT, count = 40, every = 0.28, t = 0.0},
		{lane = WEST, type = BRUTE, count = 1, every = 1.0, t = 6.0},
		{lane = CENTRE, type = RUNNER, count = 24, every = 0.3, t = 3.0},
		{lane = EAST, type = ARMORED, count = 16, every = 0.9, t = 0.0},
		{lane = EAST, type = BRUTE, count = 1, every = 1.0, t = 14.0}],
	[{lane = WEST, type = GRUNT, count = 35, every = 0.3, t = 0.0},
		{lane = EAST, type = GRUNT, count = 35, every = 0.3, t = 0.0},
		{lane = CENTRE, type = ARMORED, count = 12, every = 1.0, t = 2.0},
		{lane = CENTRE, type = RUNNER, count = 20, every = 0.3, t = 8.0},
		{lane = WEST, type = BRUTE, count = 1, every = 1.0, t = 10.0},
		{lane = EAST, type = BRUTE, count = 1, every = 1.0, t = 16.0}],
	[{lane = WEST, type = GRUNT, count = 45, every = 0.25, t = 0.0},
		{lane = CENTRE, type = ARMORED, count = 18, every = 0.8, t = 0.0},
		{lane = EAST, type = RUNNER, count = 30, every = 0.25, t = 4.0},
		{lane = CENTRE, type = BRUTE, count = 2, every = 6.0, t = 12.0},
		{lane = WEST, type = BRUTE, count = 1, every = 1.0, t = 20.0}],
	[{lane = WEST, type = GRUNT, count = 30, every = 0.28, t = 0.0},
		{lane = CENTRE, type = GRUNT, count = 30, every = 0.28, t = 0.0},
		{lane = EAST, type = GRUNT, count = 30, every = 0.28, t = 0.0},
		{lane = WEST, type = ARMORED, count = 14, every = 0.9, t = 6.0},
		{lane = EAST, type = ARMORED, count = 14, every = 0.9, t = 6.0},
		{lane = EAST, type = BRUTE, count = 2, every = 7.0, t = 10.0},
		{lane = CENTRE, type = BRUTE, count = 2, every = 7.0, t = 14.0}],
	[{lane = WEST, type = RUNNER, count = 40, every = 0.22, t = 0.0},
		{lane = CENTRE, type = GRUNT, count = 50, every = 0.22, t = 0.0},
		{lane = EAST, type = ARMORED, count = 24, every = 0.7, t = 0.0},
		{lane = WEST, type = BRUTE, count = 2, every = 7.0, t = 8.0},
		{lane = CENTRE, type = BRUTE, count = 1, every = 1.0, t = 12.0},
		{lane = EAST, type = BRUTE, count = 2, every = 7.0, t = 16.0}],
	# The finale: every lane at once, giants on each.
	[{lane = WEST, type = GRUNT, count = 40, every = 0.25, t = 0.0},
		{lane = CENTRE, type = GRUNT, count = 40, every = 0.25, t = 0.0},
		{lane = EAST, type = GRUNT, count = 40, every = 0.25, t = 0.0},
		{lane = WEST, type = ARMORED, count = 14, every = 1.0, t = 5.0},
		{lane = EAST, type = ARMORED, count = 14, every = 1.0, t = 5.0},
		{lane = CENTRE, type = RUNNER, count = 30, every = 0.25, t = 8.0},
		{lane = WEST, type = BRUTE, count = 3, every = 8.0, t = 10.0},
		{lane = CENTRE, type = BRUTE, count = 3, every = 7.0, t = 14.0},
		{lane = EAST, type = BRUTE, count = 3, every = 8.0, t = 18.0}],
]


static func wave_total(w: int) -> int:
	var n := 0
	for g in WAVES[w]:
		n += int(g.count)
	return n


## Per lane, how many of each enemy type wave `w` sends: [{type: count}, x3].
static func wave_preview(w: int) -> Array:
	var out := [{}, {}, {}]
	for g in WAVES[w]:
		var lane: Dictionary = out[int(g.lane)]
		lane[int(g.type)] = int(lane.get(int(g.type), 0)) + int(g.count)
	return out


## Enemy HP multiplier in wave w (0-based): later waves are tougher, ever
## faster, while gold per kill stays the same.
static func wave_hp(w: int) -> float:
	return 1.0 + HP_PER_WAVE * w + HP_PER_WAVE2 * w * w


static func stats(kind: String, level: int) -> Dictionary:
	return BUILDINGS[kind].levels[level]
