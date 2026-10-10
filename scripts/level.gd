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
## hero's range circle unhittable (user, 2026-10-09). Coins left anywhere
## fly to the hero when the wave ends (Sim._vacuum).
const START_LINE_OUT := 2.0

const HERO := {
	speed = 5.2, range = 6.0, interval = 0.4, damage = 2.0,
	magnet = 2.0,  # coins inside this radius fly to the hero
	bolt_speed = 26.0,
}

## Buildings. Each has levels; level 0 is what you build, the rest are
## upgrades (towers I-IV, farms, banks and gates I-III). "spot" says which spot kind it goes on.
## Towers have three `levels` and two `specs`: level IV is one of them,
## picked when upgrading from III (user, 2026-10-10: a clear trade-off,
## neither one simply better). Spec keys beyond the plain stats:
## toughest (aims at the enemy with the most HP), pierce_armor, targets
## (arrows per shot), harpoon [slow, s] on every enemy hit, bomblets
## [count, spread m], burn [dps, s], freeze (s frozen solid), brittle
## [extra damage taken, s], hero_buff (Hero's Standard: the hero's
## damage and attack speed), buff (towers' attack speed).
const BUILDINGS := {
	archer = {name = "Archer Tower", spot = "tower", desc = "Fast single shots at one target.",
		weak = "armored, giants, the boss", strong = "grunts, runners, bats",
		levels = [{cost = 15, range = 6.0, interval = 0.8, damage = 2.5},
			{cost = 25, range = 6.5, interval = 0.65, damage = 3.5},
			{cost = 40, range = 7.0, interval = 0.5, damage = 5.0}],
		specs = [
			{id = "sniper", name = "Sniper Tower", cost = 70, range = 9.5, interval = 2.2, damage = 24.0,
				toughest = true, pierce_armor = true,
				desc = "Long shots at the toughest enemy in reach; ignore armor.",
				strong = "armored, giants, the boss", weak = "crowds, runners"},
			{id = "repeater", name = "Repeater Tower", cost = 60, range = 7.0, interval = 0.22, damage = 6.0,
				targets = 2,
				desc = "Rapid arrows at two enemies at once.",
				strong = "grunts, runners, bats, slimelings", weak = "armored, the boss"}]},
	ballista = {name = "Ballista", spot = "tower", desc = "Heavy bolt that pierces every enemy in a line.",
		weak = "scattered enemies (long reload)", strong = "armored, giants, the boss, crossbowmen",
		levels = [{cost = 30, range = 8.0, interval = 1.6, damage = 6.0, pierce = 6},
			{cost = 40, range = 8.5, interval = 1.4, damage = 9.0, pierce = 8},
			{cost = 60, range = 9.0, interval = 1.2, damage = 13.0, pierce = 10}],
		specs = [
			{id = "great", name = "Great Ballista", cost = 90, range = 10.0, interval = 1.8, damage = 60.0, pierce = 4,
				desc = "Huge bolts that pierce only a few enemies.",
				strong = "giants, the boss, captains", weak = "crowds"},
			{id = "harpoon", name = "Harpoon Ballista", cost = 80, range = 9.0, interval = 1.1, damage = 14.0,
				pierce = 14, harpoon = [0.5, 2.5],
				desc = "Barbed bolts: every enemy hit is slowed 50% for 2.5 s.",
				strong = "long lines, runners, slimes", weak = "the berserk boss, bats"}]},
	mortar = {name = "Mortar", spot = "tower", desc = "Lobbed boulders that splash a whole group.",
		weak = "bats, anything within 2.5 m", strong = "crowds, gate queues",
		levels = [{cost = 35, range = 7.0, min_range = 2.5, interval = 2.4, damage = 6.0, splash = 1.3},
			{cost = 45, range = 7.5, min_range = 2.5, interval = 2.1, damage = 9.0, splash = 1.5},
			{cost = 65, range = 8.0, min_range = 2.5, interval = 1.8, damage = 13.0, splash = 1.7}],
		specs = [
			{id = "cluster", name = "Cluster Mortar", cost = 90, range = 8.5, min_range = 2.5, interval = 1.7,
				damage = 11.0, splash = 1.1, bomblets = [5, 1.8],
				desc = "Shells burst into 5 bomblets over a wide area.",
				strong = "crowds, slimes, slimelings", weak = "armored, bats"},
			{id = "fire", name = "Fire Mortar", cost = 85, range = 8.5, min_range = 2.5, interval = 1.7,
				damage = 10.0, splash = 2.0, burn = [11.0, 4.0],
				desc = "Firepots: everything hit burns for 4 s, armor or not.",
				strong = "armored, gate queues, captains", weak = "runners, bats"}]},
	# Slow pulses, long chill (user, 2026-10-09: was a 1 s pulse). Chilled
	# enemies walk AND attack slower.
	frost = {name = "Frost Crystal", spot = "tower", desc = "Pulses slow walking and attacks of all nearby.",
		weak = "bats; it deals little damage", strong = "gate queues, giants, runners",
		levels = [{cost = 25, range = 3.8, interval = 2.5, damage = 1.0, slow = 0.35, slow_time = 3.5},
			{cost = 35, range = 4.2, interval = 2.5, damage = 1.8, slow = 0.45, slow_time = 4.0},
			{cost = 50, range = 4.6, interval = 2.5, damage = 2.8, slow = 0.55, slow_time = 4.5}],
		specs = [
			{id = "glacier", name = "Glacier Crystal", cost = 75, range = 5.5, interval = 4.0, damage = 3.0,
				slow = 0.55, slow_time = 4.0, freeze = 0.8,
				desc = "Freezes everything nearby solid for 0.8 s (bosses half), then chills.",
				strong = "giants, gate queues, crossbowmen", weak = "the berserk boss, bats"},
			{id = "frostbite", name = "Frostbite Crystal", cost = 70, range = 5.0, interval = 2.0, damage = 10.0,
				slow = 0.5, slow_time = 3.5, brittle = [0.5, 3.0],
				desc = "Weaker chill, but chilled enemies take 50% more damage.",
				strong = "the boss, giants, armored", weak = "bats"}]},
	banner = {name = "War Banner", spot = "tower", desc = "No attack: towers and hero nearby attack faster.",
		weak = "standing alone", strong = "tower clusters",
		levels = [{cost = 30, range = 4.5, buff = 0.25},
			{cost = 45, range = 5.0, buff = 0.4},
			{cost = 60, range = 5.5, buff = 0.55}],
		specs = [
			{id = "drums", name = "War Drums", cost = 80, range = 6.0, buff = 1.0, hero_buff = 0.0,
				desc = "Towers nearby attack twice as fast; the hero gets nothing.",
				strong = "tower clusters", weak = "a lone hero"},
			{id = "standard", name = "Hero's Standard", cost = 80, range = 8.0, buff = 0.35, hero_buff = 0.6,
				desc = "The hero nearby: +60% damage and attack speed; towers +35%.",
				strong = "a strong hero", weak = "towers far from the hero"}]},
	# Each upgrade pays back faster than a new level-1 farm (user, v0.1.18:
	# "build three level 1s and leave them" was always best): gold per gold
	# spent 0.24 / 0.29 / 0.31.
	farm = {name = "Farm", spot = "eco", desc = "Fixed gold after every wave.",
		weak = "nothing to defend with now", strong = "early builds; upgrades pay best",
		levels = [{cost = 25, income = 6}, {cost = 35, income = 16}, {cost = 45, income = 30}]},
	# Interest instead of a fixed income: `rate` of the gold you hold when a
	# wave ends, up to `cap`. The best bank's rate counts (rates never
	# stack); every bank adds its cap. Upgrades raise both.
	bank = {name = "Bank", spot = "eco", desc = "Interest on the gold you hold after each wave.",
		weak = "spending: no gold, no interest", strong = "saving up for big upgrades",
		levels = [{cost = 30, rate = 0.1, cap = 12}, {cost = 40, rate = 0.15, cap = 25},
			{cost = 55, rate = 0.2, cap = 45}]},
	gate = {name = "Gate", spot = "gate", desc = "Blocks its lane until broken; rebuilt each wave.",
		weak = "bats (fly over), crossbowmen (shoot from range)", strong = "holding crowds inside tower range",
		levels = [{cost = 30, hp = 220.0}, {cost = 40, hp = 420.0}, {cost = 60, hp = 700.0}]},
}
const TOWER_KINDS := ["archer", "ballista", "mortar", "frost", "banner"]

## Building spots. kind: tower / gate / eco (farm or bank); gates also
## name their lane.
## lv: the hero level that unlocks the spot (user, 2026-10-10: few spots
## at first, 1-2 more per level). Gates come in sets, one per lane, all
## unlocked together; `slot` is the gate's Horde slot (0-2 the inner set
## near the middle of the map, 3-5 the outer set nearer the lane mouths).
const SPOTS := [
	# Level 1: around the keep.
	{id = "k_west", kind = "tower", lv = 1, pos = Vector3(-4.6, 0, -8.6)},
	{id = "k_east", kind = "tower", lv = 1, pos = Vector3(3.6, 0, -7.2)},
	{id = "w_in", kind = "tower", lv = 1, pos = Vector3(-4.6, 0, 3.6)},
	{id = "e_in", kind = "tower", lv = 1, pos = Vector3(1.1, 0, 2.6)},
	{id = "x_w4", kind = "tower", lv = 1, pos = Vector3(-3.7, 0, -1.4)},
	{id = "f_1", kind = "eco", lv = 1, pos = Vector3(-7.5, 0, -11.0)},
	{id = "x_e1", kind = "tower", lv = 2, pos = Vector3(5.8, 0, -1.4)},
	{id = "x_c2", kind = "tower", lv = 2, pos = Vector3(0.3, 0, 7.6)},
	# Level 3: the inner gates, side by side across the middle of the map.
	{id = "g_w1", kind = "gate", lane = 0, slot = 0, lv = 3, pos = Vector3(-11.4, 0, 8.7)},
	{id = "g_c1", kind = "gate", lane = 1, slot = 1, lv = 3, pos = Vector3(-5.0, 0, 9.2)},
	{id = "g_e1", kind = "gate", lane = 2, slot = 2, lv = 3, pos = Vector3(2.0, 0, 9.8)},
	{id = "e_mid", kind = "tower", lv = 3, pos = Vector3(1.6, 0, 12.6)},
	{id = "w_out", kind = "tower", lv = 3, pos = Vector3(-13.6, 0, 9.5)},
	{id = "x_w2", kind = "tower", lv = 4, pos = Vector3(-11.2, 0, 2.6)},
	{id = "x_w5", kind = "tower", lv = 4, pos = Vector3(-10.9, 0, 5.8)},
	{id = "f_2", kind = "eco", lv = 4, pos = Vector3(-10.5, 0, -4.5)},
	{id = "gc_t", kind = "tower", lv = 5, pos = Vector3(-5.2, 0, 15.6)},
	{id = "x_e2", kind = "tower", lv = 5, pos = Vector3(2.3, 0, 17.6)},
	{id = "w_mid", kind = "tower", lv = 6, pos = Vector3(-6.0, 0, 20.0)},
	{id = "x_w3", kind = "tower", lv = 6, pos = Vector3(-13.2, 0, 15.1)},
	{id = "ge_t", kind = "tower", lv = 7, pos = Vector3(1.5, 0, 22.2)},
	{id = "f_3", kind = "eco", lv = 7, pos = Vector3(5.2, 0, -10.4)},
	# Level 8: the outer gates, nearer the lane mouths.
	{id = "g_w2", kind = "gate", lane = 0, slot = 3, lv = 8, pos = Vector3(-14.0, 0, 21.0)},
	{id = "g_c2", kind = "gate", lane = 1, slot = 4, lv = 8, pos = Vector3(-3.9, 0, 20.7)},
	{id = "g_e2", kind = "gate", lane = 2, slot = 5, lv = 8, pos = Vector3(6.5, 0, 20.2)},
	{id = "gw_t", kind = "tower", lv = 8, pos = Vector3(-13.6, 0, 23.6)},
	{id = "x_c1", kind = "tower", lv = 8, pos = Vector3(-5.2, 0, 25.1)},
	{id = "c_far", kind = "tower", lv = 9, pos = Vector3(0.9, 0, 28.5)},
	{id = "x_w1", kind = "tower", lv = 9, pos = Vector3(-8.2, 0, 29.6)},
	{id = "x_w6", kind = "tower", lv = 10, pos = Vector3(-13.7, 0, 27.6)},
]
## Gate slots in Horde (one standing gate per slot).
const GATE_SLOTS := 6
const PAD_SIZE := 1.5
## How near a spot's centre the hero must stand for its build menu.
const SPOT_REACH := 1.45

## Seconds per attack swing cycle (matches the baked attack clips' feel).
const ATTACK_CYCLE := 0.55

## Enemy types. xp: what a kill near the hero is worth (Perks.XP_RADIUS).
## dps hits gates and the keep (enemies that reach the keep stand and
## attack it until killed).
## heavy: shoves light enemies out of its way in a gate queue (they never
## hold it up). reach: m behind the front rank it can still hit the gate
## from (a second giant swings over the first one's shoulder).
## armor: taken off every hit (never below ARMOR_FLOOR of it): many small
## hits (archer, Multishot) do little, big ones (ballista, mortar) work.
## Burning ignores armour.
## flies: over gates, at fly_h m; mortars and frost can't touch it.
## ranged: stops this far short of the wall in its way (gate or keep) and
## shoots it, outside the queue. cycle: s per attack (default
## ATTACK_CYCLE). boss: fixed HP (no wave scaling), phases (Sim._bosses).
## desc / weak / strong: the three info lines (popup, intro, guide). big:
## draws a red HP bar.
## split: [type, count] it bursts into when it dies (slime). Support
## enemies (user, 2026-10-10: "the player will want to kill them first")
## work on allies within `aura` m, never on bosses: heal (share of max HP
## per second), haste (walk and attack faster). The best one counts.
const ENEMIES := [
	{name = "grunt", plural = "grunts", hp = 3.0, speed = 1.7, radius = 0.28, gold = 1, xp = 1, dps = 2.0,
		desc = "Basic foot soldier, comes in big crowds.", weak = "mortars, archers", strong = "nothing, but there are many"},
	{name = "armored", plural = "armored", hp = 7.0, speed = 1.35, radius = 0.32, gold = 3, xp = 3, dps = 4.0,
		armor = 1.0,
		desc = "Armor shrugs off small hits.", weak = "ballistas, mortars, fire", strong = "archers, Multishot"},
	{name = "brute", plural = "brutes", hp = 90.0, speed = 0.95, radius = 0.7, gold = 15, xp = 12, dps = 18.0,
		heavy = true, reach = 1.3, big = true,
		desc = "Giant: shoves past others and smashes gates.", weak = "ballistas, frost, Giant Slayer", strong = "gates"},
	{name = "runner", plural = "runners", hp = 2.0, speed = 3.1, radius = 0.25, gold = 1, xp = 1, dps = 1.5,
		desc = "Fast and fragile.", weak = "archers, frost", strong = "mortars (outruns the shells)"},
	{name = "bat", plural = "bats", hp = 4.0, speed = 2.3, radius = 0.35, gold = 2, xp = 2, dps = 2.5,
		flies = true, fly_h = 2.2,
		desc = "Flies over gates, straight to the keep.", weak = "archers, ballistas, the hero", strong = "gates, mortars, frost (can't reach it)"},
	{name = "crossbowman", plural = "crossbowmen", hp = 8.0, speed = 1.2, radius = 0.3, gold = 3, xp = 3, dps = 1.6,
		ranged = 6.5, cycle = 1.1,
		desc = "Shoots gates from 6 m away, outside the queue.", weak = "ballistas, the hero", strong = "gates"},
	{name = "Bone Warlord", plural = "Bone Warlords", hp = 1300.0, speed = 0.7, radius = 1.1, gold = 60, xp = 40,
		dps = 28.0, heavy = true, reach = 2.0, armor = 2.5, boss = true, big = true,
		desc = "Armored boss: calls armored men, berserk at 25%: no slow or freeze.",
		weak = "ballistas, Giant Slayer, fire", strong = "light hits, gates, slow (berserk)"},
	{name = "slime", plural = "slimes", hp = 22.0, speed = 1.0, radius = 0.5, gold = 2, xp = 3, dps = 5.0,
		split = [8, 4],  # 4 slimelings
		desc = "Bursts into 4 slimelings when it dies.", weak = "mortars, Harpoon", strong = "archers (more to kill)"},
	{name = "slimeling", plural = "slimelings", hp = 3.0, speed = 2.2, radius = 0.24, gold = 1, xp = 1, dps = 1.5,
		desc = "Small and quick, born from a slime.", weak = "mortars, frost, Repeater", strong = "single big shots"},
	{name = "bone mage", plural = "bone mages", hp = 10.0, speed = 1.2, radius = 0.3, gold = 4, xp = 4, dps = 1.0,
		ranged = 5.0, cycle = 1.4, aura = 4.5, heal = 0.05,
		desc = "Heals all within 4.5 m, 5% HP a second. Kill it first.", weak = "the hero, Sniper", strong = "gate queues"},
	{name = "captain", plural = "captains", hp = 26.0, speed = 1.3, radius = 0.36, gold = 5, xp = 5, dps = 5.0,
		armor = 1.0, aura = 4.0, haste = 0.4,
		desc = "All within 4 m walk and attack 40% faster.", weak = "ballistas, mortars", strong = "archers (armor)"},
]
## A hit on an armoured enemy does at least this share of its damage.
const ARMOR_FLOOR := 0.4
## The boss calls BOSS_SUMMON armored men at each of these HP fractions;
## at the last it also goes berserk (speed and damage x BOSS_RAGE, and
## slows / freezes no longer touch it: user, 2026-10-10).
const BOSS_PHASES := [0.75, 0.5, 0.25]
const BOSS_SUMMON := 6
const BOSS_SUMMON_TYPE := 1  # ARMORED
const BOSS_RAGE := 1.4
enum { GRUNT, ARMORED, BRUTE, RUNNER, BAT, SIEGE, BOSS, SLIME, SLIMELING, MAGE, CAPTAIN }
const WEST := 0
const CENTRE := 1
const EAST := 2

## Enemy HP x (1 + HP_PER_WAVE w + HP_PER_WAVE2 w^2) in wave w (0-based).
const HP_PER_WAVE := 0.2
const HP_PER_WAVE2 := 0.046

## Waves. Each group: `count` enemies of `type` on `lane`, one every
## `every` s, starting `t` s into the wave; `hp` (bosses): HP x this
## instead of the wave's toughness (bosses ignore it otherwise).
## 15 waves since v0.1.28 (user: wave 10 easier than the old wave 10,
## wave 15 harder than it). New kinds arrive alone or in small numbers
## first: bats 4, crossbowmen 5, slimes 6, bone mages 8, captains 9; the
## Bone Warlord at 10, two of them at 15.
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
		{lane = EAST, type = BAT, count = 8, every = 0.8, t = 6.0},
		{lane = CENTRE, type = BRUTE, count = 1, every = 1.0, t = 10.0},
		{lane = EAST, type = ARMORED, count = 6, every = 1.2, t = 14.0}],
	[{lane = WEST, type = GRUNT, count = 30, every = 0.32, t = 0.0},
		{lane = WEST, type = BRUTE, count = 1, every = 1.0, t = 6.0},
		{lane = CENTRE, type = GRUNT, count = 18, every = 0.4, t = 0.0},
		{lane = CENTRE, type = SIEGE, count = 3, every = 1.5, t = 6.0},
		{lane = EAST, type = ARMORED, count = 8, every = 1.0, t = 0.0}],
	# Slimes: a few down the centre.
	[{lane = WEST, type = GRUNT, count = 30, every = 0.3, t = 0.0},
		{lane = CENTRE, type = SLIME, count = 5, every = 1.6, t = 2.0},
		{lane = EAST, type = RUNNER, count = 18, every = 0.3, t = 4.0},
		{lane = EAST, type = ARMORED, count = 6, every = 1.0, t = 10.0},
		{lane = WEST, type = BRUTE, count = 1, every = 1.0, t = 12.0}],
	[{lane = WEST, type = GRUNT, count = 30, every = 0.32, t = 0.0},
		{lane = EAST, type = GRUNT, count = 30, every = 0.32, t = 0.0},
		{lane = CENTRE, type = ARMORED, count = 10, every = 1.0, t = 2.0},
		{lane = WEST, type = BAT, count = 10, every = 0.6, t = 6.0},
		{lane = CENTRE, type = RUNNER, count = 18, every = 0.3, t = 8.0},
		{lane = EAST, type = SIEGE, count = 4, every = 1.4, t = 10.0},
		{lane = EAST, type = BRUTE, count = 1, every = 1.0, t = 14.0}],
	# Bone mages: two, behind a centre crowd.
	[{lane = CENTRE, type = GRUNT, count = 40, every = 0.25, t = 0.0},
		{lane = CENTRE, type = MAGE, count = 2, every = 3.0, t = 6.0},
		{lane = WEST, type = ARMORED, count = 12, every = 0.9, t = 2.0},
		{lane = EAST, type = SLIME, count = 6, every = 1.4, t = 4.0},
		{lane = EAST, type = BAT, count = 10, every = 0.5, t = 10.0},
		{lane = WEST, type = BRUTE, count = 1, every = 1.0, t = 12.0}],
	# Captains: one leads each side crowd.
	[{lane = WEST, type = GRUNT, count = 36, every = 0.25, t = 0.0},
		{lane = WEST, type = CAPTAIN, count = 1, every = 1.0, t = 3.0},
		{lane = EAST, type = GRUNT, count = 36, every = 0.25, t = 0.0},
		{lane = EAST, type = CAPTAIN, count = 1, every = 1.0, t = 3.0},
		{lane = CENTRE, type = RUNNER, count = 24, every = 0.25, t = 4.0},
		{lane = CENTRE, type = SIEGE, count = 5, every = 1.2, t = 8.0},
		{lane = WEST, type = BAT, count = 10, every = 0.5, t = 10.0},
		{lane = CENTRE, type = BRUTE, count = 2, every = 7.0, t = 10.0}],
	# The Bone Warlord.
	[{lane = WEST, type = GRUNT, count = 30, every = 0.28, t = 0.0},
		{lane = CENTRE, type = GRUNT, count = 30, every = 0.28, t = 0.0},
		{lane = EAST, type = GRUNT, count = 30, every = 0.28, t = 0.0},
		{lane = WEST, type = ARMORED, count = 10, every = 1.0, t = 5.0},
		{lane = EAST, type = SLIME, count = 6, every = 1.2, t = 5.0},
		{lane = CENTRE, type = BAT, count = 12, every = 0.5, t = 8.0},
		{lane = CENTRE, type = MAGE, count = 2, every = 3.0, t = 14.0},
		{lane = EAST, type = BRUTE, count = 1, every = 1.0, t = 12.0},
		{lane = CENTRE, type = BOSS, count = 1, every = 1.0, t = 20.0}],
	[{lane = WEST, type = SLIME, count = 10, every = 1.0, t = 0.0},
		{lane = CENTRE, type = GRUNT, count = 45, every = 0.22, t = 0.0},
		{lane = CENTRE, type = CAPTAIN, count = 2, every = 4.0, t = 3.0},
		{lane = EAST, type = ARMORED, count = 18, every = 0.7, t = 0.0},
		{lane = EAST, type = MAGE, count = 2, every = 3.0, t = 8.0},
		{lane = WEST, type = BAT, count = 14, every = 0.45, t = 8.0},
		{lane = CENTRE, type = SIEGE, count = 6, every = 1.0, t = 12.0},
		{lane = WEST, type = BRUTE, count = 2, every = 7.0, t = 10.0}],
	[{lane = WEST, type = RUNNER, count = 40, every = 0.22, t = 0.0},
		{lane = CENTRE, type = GRUNT, count = 50, every = 0.22, t = 0.0},
		{lane = CENTRE, type = SLIME, count = 8, every = 1.0, t = 12.0},
		{lane = EAST, type = ARMORED, count = 22, every = 0.7, t = 0.0},
		{lane = EAST, type = CAPTAIN, count = 2, every = 5.0, t = 4.0},
		{lane = WEST, type = BAT, count = 16, every = 0.45, t = 6.0},
		{lane = CENTRE, type = MAGE, count = 3, every = 2.5, t = 8.0},
		{lane = EAST, type = SIEGE, count = 8, every = 1.0, t = 10.0},
		{lane = WEST, type = BRUTE, count = 2, every = 7.0, t = 8.0},
		{lane = CENTRE, type = BRUTE, count = 2, every = 7.0, t = 14.0}],
	[{lane = WEST, type = GRUNT, count = 40, every = 0.25, t = 0.0},
		{lane = CENTRE, type = SLIME, count = 14, every = 0.8, t = 0.0},
		{lane = EAST, type = GRUNT, count = 40, every = 0.25, t = 0.0},
		{lane = WEST, type = CAPTAIN, count = 3, every = 4.0, t = 3.0},
		{lane = EAST, type = MAGE, count = 3, every = 2.5, t = 6.0},
		{lane = WEST, type = ARMORED, count = 16, every = 0.8, t = 8.0},
		{lane = CENTRE, type = BAT, count = 18, every = 0.4, t = 8.0},
		{lane = EAST, type = SIEGE, count = 8, every = 1.0, t = 12.0},
		{lane = EAST, type = BRUTE, count = 2, every = 6.0, t = 10.0}],
	[{lane = WEST, type = ARMORED, count = 24, every = 0.6, t = 0.0},
		{lane = WEST, type = CAPTAIN, count = 3, every = 5.0, t = 2.0},
		{lane = CENTRE, type = RUNNER, count = 40, every = 0.2, t = 0.0},
		{lane = CENTRE, type = MAGE, count = 4, every = 2.5, t = 8.0},
		{lane = EAST, type = SLIME, count = 16, every = 0.7, t = 0.0},
		{lane = EAST, type = GRUNT, count = 40, every = 0.25, t = 4.0},
		{lane = EAST, type = BAT, count = 20, every = 0.4, t = 6.0},
		{lane = CENTRE, type = SIEGE, count = 8, every = 1.0, t = 12.0},
		{lane = WEST, type = BRUTE, count = 2, every = 7.0, t = 10.0},
		{lane = CENTRE, type = BRUTE, count = 2, every = 7.0, t = 14.0},
		{lane = EAST, type = BRUTE, count = 1, every = 1.0, t = 18.0}],
	# The finale: every lane at once, then two Bone Warlords.
	[{lane = WEST, type = GRUNT, count = 45, every = 0.22, t = 0.0},
		{lane = CENTRE, type = GRUNT, count = 45, every = 0.22, t = 0.0},
		{lane = EAST, type = GRUNT, count = 45, every = 0.22, t = 0.0},
		{lane = WEST, type = CAPTAIN, count = 2, every = 5.0, t = 3.0},
		{lane = EAST, type = CAPTAIN, count = 2, every = 5.0, t = 3.0},
		{lane = CENTRE, type = SLIME, count = 10, every = 1.0, t = 5.0},
		{lane = WEST, type = ARMORED, count = 16, every = 0.8, t = 6.0},
		{lane = EAST, type = ARMORED, count = 16, every = 0.8, t = 6.0},
		{lane = CENTRE, type = BAT, count = 20, every = 0.4, t = 8.0},
		{lane = CENTRE, type = MAGE, count = 3, every = 2.5, t = 10.0},
		{lane = WEST, type = SIEGE, count = 6, every = 1.2, t = 12.0},
		{lane = EAST, type = SIEGE, count = 6, every = 1.2, t = 12.0},
		{lane = WEST, type = BRUTE, count = 2, every = 8.0, t = 10.0},
		{lane = EAST, type = BRUTE, count = 2, every = 8.0, t = 18.0},
		{lane = WEST, type = BOSS, count = 1, every = 1.0, t = 22.0, hp = 1.6},
		{lane = EAST, type = BOSS, count = 1, every = 1.0, t = 30.0, hp = 1.6}],
]


## The three info lines of a building or enemy, translated (Loc). Ours
## (buildings) lead with what they beat; theirs (enemies) with what beats
## them (user). with_desc false: only the Strong / Weak lines.
static func info(e: Dictionary, with_desc := true) -> String:
	var lines := [Loc.t(e.desc)] if with_desc else []
	# Ours: a building, or a tower spec (has a cost); theirs: an enemy.
	var ours: bool = e.has("spot") or e.has("cost")
	var order := [["Strong vs:", e.strong], ["Weak vs:", e.weak]] if ours else [["Weak vs:", e.weak], ["Strong vs:", e.strong]]
	for o in order:
		var label := Loc.tc(o[0], "building" if ours else "enemy")
		# A full-width colon (Chinese) takes no space after it.
		lines.push_back(label + ("" if label.ends_with("：") else " ") + Loc.t(String(o[1])))
	return "\n".join(lines)


## Enemy type k's name for a heading ("Bat", 蝙蝠).
static func ename(k: int) -> String:
	return Loc.t(String(ENEMIES[k].name)).capitalize()


## "25 grunts" / "1 brute" (Chinese: one word, the count after it).
static func count_text(k: int, n: int) -> String:
	var e: Dictionary = ENEMIES[k]
	return Loc.fmt(Loc.t("%d %s"), [n, Loc.t(String(e.plural if n != 1 else e.name))])


## Enemy types wave `w` brings for the first time (for their intro).
static func new_types(w: int) -> Array:
	var seen := {}
	for k in w:
		for g in WAVES[k]:
			seen[int(g.type)] = true
	var out := []
	for g in WAVES[w]:
		if not seen.has(int(g.type)) and not int(g.type) in out:
			out.push_back(int(g.type))
	return out


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


## Stats of `kind` at `level` (0-based); a tower's level IV (3) is its
## spec's (`spec` = the spec id).
static func stats(kind: String, level: int, spec := "") -> Dictionary:
	var lv: Array = BUILDINGS[kind].levels
	if level < lv.size():
		return lv[level]
	for sp in BUILDINGS[kind].get("specs", []):
		if sp.id == spec:
			return sp
	return BUILDINGS[kind].specs[0] if spec == "" else {}


## A built building's current stats ({kind, level, spec}).
static func bstats(b: Dictionary) -> Dictionary:
	return stats(b.kind, b.level, String(b.get("spec", "")))


## How many levels `kind` has (towers: 3 + the spec level).
static func max_levels(kind: String) -> int:
	return BUILDINGS[kind].levels.size() + (1 if BUILDINGS[kind].has("specs") else 0)


## The spec with this id across all towers, or {}.
static func spec_of(kind: String, id: String) -> Dictionary:
	for sp in BUILDINGS[kind].get("specs", []):
		if sp.id == id:
			return sp
	return {}
