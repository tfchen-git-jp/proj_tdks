class_name Perks
extends RefCounted
## The hero's rogue-like upgrades: cards and relics, 3 tiers each (drawing
## one you own raises its tier; relics are offered after RELIC_WAVES). All
## their tuning lives here; Sim applies them. Design: docs/DESIGN.md
## "Hero upgrades".

## Kills within this distance of the hero give XP (whoever lands the hit),
## or within XP_PAST_RANGE beyond the hero's range if that is larger
## (Long Shot): Sim.xp_radius().
const XP_RADIUS := 8.0
const XP_PAST_RANGE := 2.0
## XP to go from `level` to the next: XP_BASE + XP_STEP * (level - 1);
## the hero starts at level 1.
const XP_BASE := 10
const XP_STEP := 12
## A relic is offered after clearing these waves (1-based).
const RELIC_WAVES := [3, 6, 9, 12]
const OFFER_SIZE := 3
## Rerolls cost REROLL_COST, then 2x, 3x ... (over the whole run).
const REROLL_COST := 10
const MAX_TIER := 3

## Cards. v: the value per tier; desc: per tier, shown for the tier you'd
## get. Grouped: offence, utility, tower synergy.
const CARDS := {
	dmg = {name = "Sharpened Bolts", v = [1.2, 1.4, 1.6],
		desc = ["+20% bolt damage", "+40% bolt damage", "+60% bolt damage"]},
	aspd = {name = "Quick Draw", v = [1.1, 1.2, 1.35],
		desc = ["+10% attack speed", "+20% attack speed", "+35% attack speed"]},
	# v0.1.30 reworks (measured weak, docs/DESIGN.md "Card and relic value"):
	# Long Shot, Ricochet, Swift Boots, Scholar, Rally, Spotter, Engineer,
	# Bounty; Midas, Last Stand, Spirit Wisp.
	range = {name = "Long Shot", v = [[1.0, 0.15], [2.0, 0.3], [3.0, 0.45]],
		desc = ["+1 m range; +15% damage to enemies over 5 m away", "+2 m range; +30% damage over 5 m",
			"+3 m range; +45% damage over 5 m"]},
	multi = {name = "Multishot", v = [1, 2, 3],
		desc = ["+1 bolt (40% damage) at another enemy", "+2 bolts (40% damage) at other enemies",
			"+3 bolts (40% damage) at other enemies"]},
	pierce = {name = "Piercing Bolts", v = [1, 2, 3],
		desc = ["Bolts fly straight through 1 more enemy", "Bolts fly straight through 2 more enemies",
			"Bolts fly straight through 3 more enemies"]},
	ricochet = {name = "Ricochet", v = [1, 2, 3],
		desc = ["Bolts bounce to 1 nearby enemy (-25% each bounce)", "Bounce to 2 nearby enemies", "Bounce to 3 nearby enemies"]},
	# v0.1.30: measured the strongest card (was half damage, 0.9/1.2/1.5 m).
	blast = {name = "Explosive Tips", v = [0.8, 1.0, 1.2],
		desc = ["Hits explode: 35% damage within 0.8 m", "Blast radius 1.0 m", "Blast radius 1.2 m"]},
	fire = {name = "Fire Bolts", v = [0.4, 0.6, 0.9],
		desc = ["Set enemies ablaze: 40% of bolt damage per second for 3 s", "Burn 60% per second", "Burn 90% per second"]},
	frost = {name = "Frost Bolts", v = [0.2, 0.3, 0.4],
		desc = ["Hits chill: -20% walking and attack speed for 2 s", "Chill -30%", "Chill -40%"]},
	crit = {name = "Keen Eye", v = [0.1, 0.2, 0.3],
		desc = ["10% chance of a 2.5x critical hit", "20% critical chance", "30% critical chance"]},
	slayer = {name = "Giant Slayer", v = [1.4, 1.8, 2.2],
		desc = ["+40% damage to giants", "+80% damage to giants", "+120% damage to giants"]},
	boots = {name = "Swift Boots", v = [0.1, 0.2, 0.3],
		desc = ["+10% move speed, and +10% attack speed while moving", "+20% move speed and attack speed while moving",
			"+30% move speed and attack speed while moving"]},
	# Replaced Magnet (v0.1.17: coins fly to the hero at every wave's end).
	# Scholar (user, v0.1.30): +2% bolt damage per hero level (the level
	# now, not counted from the pick), on top of the XP.
	scholar = {name = "Scholar", v = [1.2, 1.4, 1.6],
		desc = ["+20% XP; +2% bolt damage per hero level", "+40% XP; +2% bolt damage per level",
			"+60% XP; +2% bolt damage per level"]},
	# Tower-wide cards scale with the whole build: small numbers.
	rally = {name = "Rally", v = [0.04, 0.08, 0.12],
		desc = ["All towers attack 4% faster; twice that within 6 m of you", "All towers attack 8% faster; 16% within 6 m of you",
			"All towers attack 12% faster; 24% within 6 m of you"]},
	spotter = {name = "Spotter", v = [0.12, 0.2, 0.3],
		desc = ["Enemies your bolts hit are marked for 4 s: towers deal them +12% damage", "Enemies your bolts hit are marked for 4 s: towers deal them +20% damage",
			"Enemies your bolts hit are marked for 4 s: towers deal them +30% damage"]},
	engineer = {name = "Engineer", v = [0.2, 0.35, 0.5],
		desc = ["All gates +20% HP", "All gates +35% HP", "All gates +50% HP"]},
	bounty = {name = "Bounty", v = [20, 40, 60],
		desc = ["Kills near you drop +1 gold (up to 20 a wave)", "Kills near you drop +1 gold (up to 40 a wave)",
			"Kills near you drop +1 gold (up to 60 a wave)"]},
}
## Rally's doubled ring around the hero; Spotter's mark (s).
const AURA := 6.0
const MARK_TIME := 4.0
## Long Shot's damage bonus counts beyond this distance.
const FAR := 5.0

## Relics: game-changing, 3 tiers each (user, 2026-10-10: a relic drawn
## again gets stronger, e.g. Thunderstrike strikes more often). v: per
## tier, read through Sim.rv(); desc: per tier, for the tier you'd get.
const RELICS := {
	twin = {name = "Twin Crossbow", v = [0.5, 0.7, 0.9],
		desc = ["Every shot fires a second volley at 50% damage right after the first.",
			"Second volley at 70% damage", "Second volley at 90% damage"]},
	volley = {name = "Volley", v = [[6, 4], [5, 5], [4, 6]],
		desc = ["Every 6th shot also looses a bolt at each of the 4 nearest enemies.",
			"Every 5th shot, 5 enemies", "Every 4th shot, 6 enemies"]},
	thunder = {name = "Thunderstrike", v = [[8.0, 5], [6.0, 6], [4.5, 8]],
		desc = ["Every 8 s lightning strikes the toughest enemy near you and chains through 4 more.",
			"Every 6 s, chains through 5 more", "Every 4.5 s, chains through 7 more"]},
	wisp = {name = "Spirit Wisp", v = [0.5, 0.35, 0.25],
		desc = ["A wisp circles you and shoots bolts with all your bolt cards (80% damage).", "The wisp shoots 40% faster",
			"The wisp shoots twice as fast"]},
	# Was every 40/30/20 kills: measured the best pick by far (v0.1.29).
	midas = {name = "Midas Touch", v = [60, 45, 30],
		desc = ["Every 60th kill near you drops a gold ingot (20).", "Every 45th kill", "Every 30th kill"]},
	# Last Stand (user, v0.1.30): a gate or the keep about to fall turns
	# invulnerable for v s instead, once per wave each (Horde.last_stand).
	laststand = {name = "Last Stand", v = [3.0, 5.0, 7.0],
		desc = ["Once per wave, a gate or the keep about to fall becomes invulnerable for 3 s.",
			"Invulnerable for 5 s", "Invulnerable for 7 s"]},
}
const THUNDER_RANGE := 9.0
const THUNDER_JUMP := 4.5  # m between chained enemies
const THUNDER_DAMAGE := 7.0  # x the hero's bolt damage
const WISP_DAMAGE := 0.8  # x the hero's bolt damage
const BLAST_DAMAGE := 0.35  # Explosive Tips: share of the hit's damage
const SCHOLAR_PER_LEVEL := 0.02  # bolt damage per hero level
const RICOCHET_RANGE := 5.0
const RICOCHET_FALLOFF := 0.75
const MULTI_DAMAGE := 0.4  # extra Multishot bolts
const BURN_TIME := 3.0
const CRIT_MULT := 2.5
const FROST_TIME := 2.0


static func xp_needed(level: int) -> int:
	return XP_BASE + XP_STEP * (level - 1)


## Card id or relic id -> what the offer shows: {id, relic, name, tier
## (0-based, the tier you'd get), desc}. owned: the tiers owned (cards or
## relics).
static func view(id: String, relic: bool, owned: Dictionary) -> Dictionary:
	if relic:
		var r := int(owned.get(id, 0))
		return {id = id, relic = true, name = RELICS[id].name, tier = r, desc = RELICS[id].desc[r]}
	var t := int(owned.get(id, 0))
	return {id = id, relic = false, name = CARDS[id].name, tier = t, desc = CARDS[id].desc[t]}
