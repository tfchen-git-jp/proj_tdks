class_name Perks
extends RefCounted
## The hero's rogue-like upgrades: cards (3 tiers each; drawing one you own
## raises its tier) and relics (one-off, offered after RELIC_WAVES). All
## their tuning lives here; Sim applies them. Design: docs/DESIGN.md
## "Hero upgrades".

## Kills within this distance of the hero give XP (whoever lands the hit),
## or within XP_PAST_RANGE beyond the hero's range if that is larger
## (Long Shot): Sim.xp_radius().
const XP_RADIUS := 8.0
const XP_PAST_RANGE := 2.0
## XP for the next level: XP_BASE + XP_STEP * levels so far.
const XP_BASE := 10
const XP_STEP := 12
## A relic is offered after clearing these waves (1-based).
const RELIC_WAVES := [3, 6, 9]
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
	range = {name = "Long Shot", v = [1.0, 2.0, 3.0],
		desc = ["+1 m range", "+2 m range", "+3 m range"]},
	multi = {name = "Multishot", v = [1, 2, 3],
		desc = ["+1 bolt (40% damage) at another enemy", "+2 bolts (40% damage) at other enemies",
			"+3 bolts (40% damage) at other enemies"]},
	pierce = {name = "Piercing Bolts", v = [1, 2, 3],
		desc = ["Bolts fly straight through 1 more enemy", "...through 2 more enemies", "...through 3 more enemies"]},
	ricochet = {name = "Ricochet", v = [1, 2, 3],
		desc = ["Bolts bounce to 1 nearby enemy (-40% each bounce)", "Bounce to 2 nearby enemies", "Bounce to 3 nearby enemies"]},
	blast = {name = "Explosive Tips", v = [0.9, 1.2, 1.5],
		desc = ["Hits explode: half damage within 0.9 m", "Blast radius 1.2 m", "Blast radius 1.5 m"]},
	fire = {name = "Fire Bolts", v = [0.4, 0.6, 0.9],
		desc = ["Set enemies ablaze: 40% of bolt damage per second for 3 s", "Burn 60% per second", "Burn 90% per second"]},
	frost = {name = "Frost Bolts", v = [0.2, 0.3, 0.4],
		desc = ["Hits chill: -20% walking and attack speed for 2 s", "Chill -30%", "Chill -40%"]},
	crit = {name = "Keen Eye", v = [0.1, 0.2, 0.3],
		desc = ["10% chance of a 2.5x critical hit", "20% critical chance", "30% critical chance"]},
	slayer = {name = "Giant Slayer", v = [1.4, 1.8, 2.2],
		desc = ["+40% damage to giants", "+80% damage to giants", "+120% damage to giants"]},
	boots = {name = "Swift Boots", v = [1.1, 1.2, 1.3],
		desc = ["+10% move speed", "+20% move speed", "+30% move speed"]},
	# Replaced Magnet (v0.1.17: coins fly to the hero at every wave's end).
	scholar = {name = "Scholar", v = [1.2, 1.4, 1.6],
		desc = ["+20% XP", "+40% XP", "+60% XP"]},
	rally = {name = "Rally", v = [0.1, 0.2, 0.3],
		desc = ["Towers within 5 m of you attack 10% faster", "...20% faster", "...30% faster"]},
	spotter = {name = "Spotter", v = [1.0, 2.0, 3.0],
		desc = ["Towers within 5 m of you: +1 m range", "...+2 m range", "...+3 m range"]},
	engineer = {name = "Engineer", v = [0.2, 0.35, 0.5],
		desc = ["Gates within 6 m of you take 20% less damage", "...35% less", "...50% less"]},
	bounty = {name = "Bounty", v = [10, 20, 30],
		desc = ["Kills near you drop +1 gold (up to 10 a wave)", "...up to 20 a wave", "...up to 30 a wave"]},
}
## Radius of the tower-synergy auras (Rally, Spotter) and Engineer.
const AURA := 5.0
const ENGINEER_R := 6.0

## Relics: one pick each, game-changing.
const RELICS := {
	twin = {name = "Twin Crossbow", desc = "Every shot fires a second, half-damage volley right after the first."},
	volley = {name = "Volley", desc = "Every 6th shot also looses a bolt at each of the 4 nearest enemies."},
	thunder = {name = "Thunderstrike", desc = "Every 8 s lightning strikes the toughest enemy near you and chains through 4 more."},
	wisp = {name = "Spirit Wisp", desc = "A wisp circles you and shoots magic bolts at enemies."},
	midas = {name = "Midas Touch", desc = "Every 40th kill near you drops a gold ingot (20)."},
	laststand = {name = "Last Stand", desc = "The keep regains 10% of its HP after every wave."},
}
const VOLLEY_EVERY := 6
const VOLLEY_TARGETS := 4
const THUNDER_EVERY := 8.0
const THUNDER_RANGE := 9.0
const THUNDER_CHAIN := 5  # enemies hit, the first included
const THUNDER_JUMP := 4.5  # m between chained enemies
const THUNDER_DAMAGE := 7.0  # x the hero's bolt damage
const WISP_INTERVAL := 0.7
const WISP_DAMAGE := 0.6  # x the hero's bolt damage
const MIDAS_EVERY := 40
const LASTSTAND_HEAL := 0.1
const RICOCHET_RANGE := 4.0
const RICOCHET_FALLOFF := 0.6
const MULTI_DAMAGE := 0.4  # extra Multishot bolts
const TWIN_DAMAGE := 0.5  # the Twin Crossbow's second volley
const BURN_TIME := 3.0
const CRIT_MULT := 2.5
const FROST_TIME := 2.0


static func xp_needed(level: int) -> int:
	return XP_BASE + XP_STEP * level


## Card id or relic id -> what the offer shows: {id, relic, name, tier
## (0-based, the tier you'd get), desc}.
static func view(id: String, relic: bool, owned: Dictionary) -> Dictionary:
	if relic:
		return {id = id, relic = true, name = RELICS[id].name, tier = -1, desc = RELICS[id].desc}
	var t := int(owned.get(id, 0))
	return {id = id, relic = false, name = CARDS[id].name, tier = t, desc = CARDS[id].desc[t]}
