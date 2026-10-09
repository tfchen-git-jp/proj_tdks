# Design v2 — from the Kingshot ad toward Thronefall

Proposal 2026-10-09; steps 1-2 built in v0.1.5-0.1.7 (2026-10-10).

## Decisions taken (user, 2026-10-09/10) — these override the proposal below

- **No day/night.** Two phases, both daylight: BUILD (walk around, build,
  upgrade) and ATTACK (the wave). The wave starts from a START pad by the
  keep (its popup lists the coming enemies per lane).
- **Build between every wave** (Thronefall style); no building during an
  attack. A level = 10 waves (6 until v0.1.10).
- **Build popup appears when the hero stands on a spot** (no tapping the
  map); tap a button in it to build or upgrade.
- **Keep walking over dropped gold.** Enemies are untargetable until past a
  start line inside the hero's reach, so no coin is ever out of reach.
- Each gate gets its own tower spot beside its queue; unbuilt gate pads
  show a see-through gate across their lane.
- Upgrades are linear (3 levels per building) for now, not 2-way choices.

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

1. **Day / night loop** (replaced by build/attack phases, see above). Build phase (no enemies, unlimited time, a "Start
   night" button) then a wave. A level = N nights (5-8), last one a boss.
   Next night's enemies shown per lane at the lane mouths during the day.
2. **Three lanes** converging on the keep. Portrait camera follows the
   hero, who cannot cover all three: where you stand and build matters.
3. **Tower spots with roles and limited reach.** Spots are fixed and few;
   no spot covers more than one or two lanes. Tower types (all buildable
   on any tower spot, each with 2 upgrade tiers, tier 2 a choice of 2):
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
5. **Enemies fight back.** Towers, walls and the hero have HP. Destroyed
   buildings come back at dawn (Thronefall rule) so a bad night hurts but
   doesn't snowball. Hero down = respawn at the keep after a few seconds.
   New roles: runner (fast, fragile), siege (targets buildings, high HP),
   ranged (shoots towers / hero from range), boss.
6. **Roguelike hero upgrades.** After each night, pick 1 of 3 random
   cards: multishot, piercing / explosive bolts, attack speed, range,
   crit, move speed, magnet, regen, "towers near you +X%"... Rarities.
7. **Score + victory screen;** later difficulty mutators and a level select.

## Leave out

- Unit summoning / squads / commanding (user: too complicated).
- Kingshot's town hall and city-building (already removed).
- Thronefall's region world map (later: a simple level list).
- Active weapon skills and multiple weapons (maybe later, one skill button).

## Build order (each step playable)

1. DONE (v0.1.5): three lanes, build/attack phases, wave preview, build
   popup at spots.
2. DONE (v0.1.5): tower roles (archer, ballista, mortar, frost, banner) +
   farm + gate, 3 levels each; real projectiles; SFX.
3. DONE (v0.1.11): enemies that reach the keep stand and attack it (keep
   HP, like a gate) instead of a fixed loss per leak. Enemies attack ONLY
   walls (gates, keep), never the hero or towers (user, 2026-10-09: not a
   good idea).
4. New enemy roles; boss wave.
5. Hero upgrade cards after each wave.
6. DONE in part (v0.1.11): 10 waves, tower level IV, per-wave enemy HP
   growth, bot loses sometimes (about 1 run in 6). Still to do: score
   screen.
