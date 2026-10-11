# Design — from the Kingshot ad toward Thronefall

Proposal 2026-10-09 (design v2); built step by step in v0.1.5-0.1.16. The
game as it stands is described in CLAUDE.md "The game today"; this file
keeps the decisions, the original analysis and what is left to build.

## Decisions taken (user, 2026-10-09/10) — these override the proposal below

- **No day/night.** Two phases, both daylight: BUILD (walk around, build,
  upgrade) and ATTACK (the wave). The wave starts from a START pad by the
  keep (stand on it for a 5 s countdown; its popup lists the coming
  enemies per lane).
- **Build between every wave** (Thronefall style); no building during an
  attack. A level = 15 waves (10 until v0.1.26; user 2026-10-10: the new
  wave 10 easier than the old one, wave 15 harder).
- **Balance is set by human play** (user, v0.2.1-0.2.2: "our game SHOULD
  be designed for players"). The standard bot's 60-65% target
  (v0.1.28-0.2.1) is dropped: it stands at fixed spots and relied on
  Cluster melting the boss; it now loses at wave 10. Bot runs remain for
  A/B comparisons between options.
- **Build popup appears when the hero stands on a spot** (no tapping the
  map); tap a button in it to build or upgrade.
- **Gold:** walk over dropped gold during a wave, and when the wave ends
  every coin left flies to the hero (gold is only spent in the build
  phase). Enemies become targetable at a start line just outside the
  hero's walkable area (marked on the road).
- Each gate gets its own tower spot beside its queue; unbuilt gate pads
  show a see-through gate across their lane.
- Upgrades are linear up to III (towers), farm / bank / gate I-III; at
  level IV every tower picks one of two specs with a clear trade-off,
  neither simply better (user, 2026-10-10; not only damage: frost and
  the banner matter in other ways). Selling a building refunds 40% of
  all it cost, after a yes / no (user: punishing on purpose; a maxed
  tower only offers Sell).
- **Enemies attack only walls** (gates, then the keep), never the hero or
  towers: no building HP, no hero death.
- **Spots unlock with the hero's level, by tactical value** (user,
  v0.1.30): one-lane spots and the keep's flanks first (4 tower + 1 gold
  at level 1), spots reaching two lanes from level 6, the crossroads spot
  (all three lanes) last at level 17; 5 gold plots (1, 4, 7, 12, 15).
  Gates come in two sets of three (one per lane), the inner set at
  level 3, the outer one nearer the lane mouths at level 9. Idea for
  later: synergy when a whole gate set stands.
- **Walls take up to 4 attackers at once**, side by side (a giant counts
  as two; user, v0.2.2: one or two in a line was too easy on gates).
  Gates have 70% of their old HP at twice the cost (user, v0.2.4).
- **Level-IV specs look different** (v0.2.5, lineup approved by the user):
  parts and colours from the same CC0 kits; the Harpoon Ballista shoots
  tridents.
- Economy plots take a farm (fixed income) or a bank (interest on held
  gold, capped).
- **Hero upgrades** (rogue-like): XP from kills near the hero, whoever
  kills; level-ups banked during a wave and picked after it (3 cards,
  tiers I-III, reroll for gold); a relic after waves 3/6/9/12, relics
  also tiered I-III (user, v0.1.28: Thunderstrike strikes more often,
  and so on). Hades-like combined effects: far future. No permanent
  unlocks until there are many more waves / maps.
- **Bosses** (user, v0.1.28): the Bone Warlord calls armored men (three
  times), and berserk it shrugs off slows and freezes. Wave 10 has one,
  wave 15 two tougher ones. v0.2.2: its HP grows with the wave like
  everyone's (the wave-15 pair died in 10-15 s), and a Cluster shell's
  bomblets hit it only once.
- **Support enemies** the player wants to kill first (user): bone mages
  heal, captains hasten everyone near them, necromancers raise an ally
  dying near them at full HP (each enemy only once, no cooldown since
  v0.2.4; never a boss); they walk with
  their crowd. Slimes burst into slimelings (the "spider and
  spiderlings" idea).
- **Enemies that force a mix** (user, v0.1.30 ideas, built v0.2.1):
  warded (the hero does 20%), shades (half-transparent, only hittable
  near a frost crystal or banner, or by the keep; they break gates
  without one), sappers (explode on gates and the keep), drakes
  (armoured flyers).
- Main menu with Continue (saved at every wave), top-10 scores (waves,
  then keep HP % x 10 + gold), credits; Esc / back always asks first.

Reference: `ref/yt_bHMSu6iMIYI.mp4` (Thronefall announce trailer, Xbox,
"coming November 11 2026"). The user wants Thronefall's defense system,
not Kingshot's: towers on fixed spots with different roles, several lanes,
real economic decisions, roguelike hero upgrades, and a HARD game. No unit
summoning / commanding.

## What the trailer shows

- **Day / night.** Bright days: the hero walks the map and spends gold at
  fixed building spots (wood-plank foundation squares). Dark nights: waves
  attack from the map edges, the hero fights beside the towers.
- **Fixed spots, upgrade branches.** Each spot builds one thing; a built
  tower opens an upgrade card ("Upgrade - Castle Tower: +150 Health, -40%
  Attack Cooldown, +100% Projectile Speed, Targets the closest unit", 0:26)
  with 4 option icons to pick from.
- **Economy buildings.** Houses / farms / mills on spots, income at dawn.
- **Walls and gates** close gaps between cliffs; enemies batter them.
- **Several entrances.** Enemies arrive along multiple routes at once;
  stage screen lists "Expected enemies" per night (1: 5 siege, 2: 85
  infantry, 3: 4 + 9, 4: 40 elite, 5: 20 + 119) and the starting gold (21).
- **Enemies hit buildings** (siege rams, ranged units) and the hero.
- **Loadout before a stage:** hero weapon (bow, spear, lightning staff...),
  perks (pick N of many), mutators (harder rules, more score).
- **Victory screen with score** (base + gold bonus + mutators + no restarts).
- World map of regions (each a level), unit squads with banners (skip).

## Adopt, in priority order

1. **Day / night loop** (replaced by build/attack phases, see above).
   Build phase (no enemies, unlimited time, a "Start night" button) then
   a wave. A level = N nights (5-8), last one a boss.
   Next night's enemies shown per lane at the lane mouths during the day.
2. **Three lanes** converging on the keep. Portrait camera follows the
   hero, who cannot cover all three: where you stand and build matters.
3. **Tower spots with roles and limited reach.** Spots are fixed and few;
   no spot covers more than one or two lanes. Tower types (all buildable
   on any tower spot; proposed 2 upgrade tiers with a choice, built as 4
   linear levels):
   - Archer: cheap, long range, single target.
   - Ballista: very long range, pierces a line, slow (today's tower).
   - Mortar: splash damage, minimum range, slow.
   - Frost: slows everything in its radius, little damage.
   - Banner: no attack; +attack speed / damage to towers and the hero
     within its radius.
   Plus wall / gate spots across lanes (today's gate, with HP).
4. **Economy decision.** Gold from kills (picked up, as now) plus dawn
   income from Farm spots: a farm built early pays off over the level
   but leaves a lane weaker tonight.
5. **Enemies fight back.** (Superseded: enemies attack only walls and the
   keep; runner built, siege / ranged / boss still to come.) Towers,
   walls and the hero have HP. Destroyed
   buildings come back at dawn (Thronefall rule) so a bad night hurts but
   doesn't snowball. Hero down = respawn at the keep after a few seconds.
   New roles: runner (fast, fragile), siege (targets buildings, high HP),
   ranged (shoots towers / hero from range), boss.
6. **Roguelike hero upgrades.** (Built v0.1.15, see Decisions.) After
   each night, pick 1 of 3 random
   cards: multishot, piercing / explosive bolts, attack speed, range,
   crit, move speed, magnet, regen, "towers near you +X%"... Rarities.
7. **Score + victory screen** (built: top 10, keep % x 10 + gold); later
   difficulty mutators and a level select.

## Leave out

- Unit summoning / squads / commanding (user: too complicated).
- Kingshot's town hall and city-building (already removed).
- Thronefall's region world map (later: a simple level list).
- Active weapon skills and multiple weapons (maybe later, one skill button).

## Build order (each step playable)

1. DONE (v0.1.5): three lanes, build/attack phases, wave preview, build
   popup at spots.
2. DONE (v0.1.5): tower roles (archer, ballista, mortar, frost, banner) +
   farm + gate; real projectiles; SFX.
3. DONE (v0.1.11), changed: enemies that reach the keep stand and attack
   it (keep HP, like a gate). Enemies attack only walls (user: hero /
   tower HP not a good idea).
4. DONE (v0.1.18): armour, flyers (bats), ranged siege (skeleton
   crossbowmen), a wave-10 boss with phases.
5. DONE (v0.1.15): hero upgrade cards and relics (scripts/perks.gd).
6. DONE (v0.1.11-0.1.16): 10 waves, bot balance (loses ~1 run in 6),
   score + top 10. Since: 15 waves (v0.1.28), balance by play-tests
   (v0.2.2). TODO: more levels / maps, then permanent unlocks and
   difficulty mutators.

## Spec balance (v0.1.28)

(Measured before v0.2.2 cut Cluster's damage to a single target: its
bomblets hit one enemy once a shell now.)

The standard bot takes Sniper / Great / Cluster / Glacier (it builds no
banner) and wins 62% of 96 seeds. Swapping one tower kind to its other
spec (tools/meta_report.py --fixed --specs=KIND:SPEC, 96 seeds each):
Repeater 44%, Harpoon 61%, Fire Mortar 64%, Frostbite 52%. The bosses
decide most games, so the boss-hurting / boss-holding side reads strong
in bot runs; a player who loses to crowds or gate breaks should find the
other side (Repeater, Frostbite) better. First passes had Repeater at
2-9% and Frostbite at 9-23%; Sniper slowed (2.2 s), Glacier's freeze cut
to 0.8 s and halved on bosses (Horde.BOSS_FREEZE), Repeater and
Frostbite strengthened. Banner specs untested by the bot. Random builds
win ~6%.

## Card and relic value (v0.1.29 measurement)

(Before the v0.1.30 reworks of the weak and strong ones; not re-measured.)

tools/meta_report.py --fixed --force=ID: the standard bot (62%) takes
that card / relic first whenever offered (96 seeds each). A minus means
"worse than the bot's usual first picks" (Sharpened Bolts, Quick Draw;
relic: Twin Crossbow), not useless.
Relics: Midas 93% (!), Volley 67, Twin 62 (= base), Thunderstrike 61,
Wisp 40, Last Stand 33. Cards: Explosive Tips 79, Keen Eye 73, Piercing
66, Frost Bolts 66, Multishot 65, Giant Slayer 64, Bounty 64, Sharpened
62, Quick Draw 60, Scholar 60 (+3.3 hero levels, no gain), Fire 58,
Ricochet 48, Long Shot 44, Rally 44, Spotter 36, Engineer 31, Boots 24
(useless to a bot that walks to fixed spots). Lesson: early gold
snowballs (Midas from wave 3 buys the whole plan waves earlier); the
gold left over at the end is only the plan running out.

## Roadmap (agreed 2026-10-10; batch 1 done in v0.1.18)

0. NOW: the user play-tests (v0.2.7: "more challenging" after the
   v0.2.2-0.2.4 enemy buffs); tune from that.
1. DONE: armour, flyers (bats), ranged siege (crossbowmen), wave-10 boss;
   v0.1.28 slimes, bone mages, captains; v0.2.1 warded, shades, sappers,
   drakes, necromancers.
2. Later (user, v0.1.28: not now): endless mode (after the last wave, ever-tougher waves; score = wave
   reached) + 2-3 mutators chosen before a run ("enemies +30% speed",
   "no gates", "keep 50% HP"), each adding a score bonus.
3. Card evolutions (two maxed cards fuse, e.g. Fire Bolts III + Explosive
   Tips III -> Inferno; Ricochet III + Multishot III -> Storm of Bolts)
   + 4-5 new relics, some changing towers ("archers shoot fire arrows",
   "gates reflect damage", "frost pulses deal damage").
4. DONE (v0.1.28, with 15 waves, relic tiers, new enemies and bosses):
   tower specialisations at level IV + selling (40% refund).
5. A second map (the user designs it; Claude adds a level file format and
   checks: spot placement, start lines, a bot test run).

Smaller ideas noted along the way:
- Gate-set synergy: a bonus while all three gates of a set stand (user).
- Japanese localization after TC (user); same picking-page process.
- DONE (v0.1.30): card / relic reworks from tools/meta_report.py
  --force. Maybe count slow / buff as contributions in the report.
- A bot that moves and drafts like a player, if bot runs are to say
  anything about difficulty again.
- Quality of life: 2x speed button, per-wave summary, first-run tips,
  settings (volume, FPS counter, vibration), the cards and relics held
  listed on the pause screen. DONE (v0.2.4): the run's build on the end
  screen.
- Later: a hero weapon choice before a run (crossbow / longbow / staff)
  and one active hero skill; permanent unlocks once there are 50+ waves
  or several maps.