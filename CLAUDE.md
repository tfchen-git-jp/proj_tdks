# proj_tdks — project notes

**RogueShot Tower Defense** (RogueShot TD / RSTD; renamed from "Kingshot
TD" on 2026-10-09 -- the hero is a rogue, not a king).

A 3D low-poly **tower defense for Android (and PC)**, made with Godot 4.7 by
directing Claude. It started as a recreation of the TD level in Kingshot's
ads (`ref/yt_BQE4bvmtvDo.mp4`) and now follows Thronefall's defense system
(`ref/yt_bHMSu6iMIYI.mp4`, design in `docs/DESIGN.md`). Personal use: the
user and friends, never published. Repo: github.com/tfchen-git-jp/proj_tdks
(private). The user designs later levels.

## The game today (v0.1.28)

- **Hero:** hooded crossbow rogue on a floating joystick (touch anywhere,
  drag; mouse drag on PC, WASD too). Auto-shoots the nearest enemy in range,
  also while moving (legs run/strafe/backpedal, upper body keeps aiming);
  with no enemy in reach it runs relaxed, crossbow carried (Running_A on
  the whole body, crossbow turned Models.HERO_CARRY_PITCH in the hand).
  Walks over dropped gold to collect it (magnet radius); when a wave ends
  every coin left flies to the hero (Sim._vacuum; user + tester: gold is
  only spent in the build phase, so sweeping by hand was pointless); the
  hero holds still and no popup opens until the sweep lands
  (Sim.sweeping). Coins drop on the ground, also under a dying bat.
- **Phases:** BUILD (no enemies; walk onto a spot and its popup appears;
  stand on the red START pad by the keep: it shows the next wave per lane
  and counts down Level.START_COUNTDOWN (5 s, full-screen digit); walking
  off cancels) and ATTACK (no building). 15 waves (10 until v0.1.26);
  clear them all to win.
  Enemies that reach the keep stand at it and hit it with their dps
  (queueing like at a gate) until killed; keep HP Level.BASE_HP (600).
- **Hero upgrades (rogue-like, scripts/perks.gd):** kills within
  Sim.xp_radius() of the hero give xp (ENEMIES `xp`), whoever kills: 8 m,
  or hero range + 2 m with Long Shot (up to 11 m). The hero starts at
  level 1 (Sim.level; Perks.xp_needed(level) = 10 + 12 (level - 1); save
  v3, v2 saves counted from 0 and are converted on load). Each gain floats as
  "+N XP" over the hero (no pop-up = out of range).
  Level-ups are banked during a wave; after it the picker (hud.show_cards,
  modal) offers 3 cards per level, a relic first after waves 3/6/9/12; the
  picker opens only once the end-of-wave coin sweep has landed, queued
  picks follow one another and the start countdown waits for them. 17
  cards x 3 tiers (drawing an owned one = next tier, maxed ones leave the
  pool; Scholar +XP replaced Magnet in v0.1.17), 6 relics, also tiered
  I-III since v0.1.28 (Perks.RELICS `v` per tier, Sim.rv(); Sim.relics
  is id -> tier). Reroll 10,
  20, 30... gold. Cards have their own dice
  (Sim._card_rng, saved). Visuals in scripts/fx.gd (+ shaders/flame,
  glow). Enemies attack only walls (user). No permanent unlocks until
  there are 50+ waves or several maps (user).
- **Menu / saves (scripts/menu.gd, save.gd, confirm.gd):** title screen
  over the drifting map: New game, Continue (user://run.json, written at
  every wave start and clear; Sim.to_save / from_save, SAVE_VERSION 2),
  Scores (top 10 in user://scores.json: waves cleared, then
  Save.score_of = keep HP % x 10 + gold + 50 per hero level,
  XP progress counting its share), Credits, Exit. Esc / Android
  back pauses and asks before leaving a game (mid-wave: Continue resumes
  from the wave's start; build phase: saved as it stands) or quitting.
  Save v4 (v0.1.28): buildings [id, kind, level, spec, spent], relics
  {id: tier}; v3 saves load (level-IV towers become the first spec,
  relics tier I).
  End screen: waves, keep, gold, hero level, score, and two tables with
  icons: damage dealt (hero incl. relics and burning, then archer,
  ballista, mortar, frost: Sim.dealt_by) and damage taken by gates and
  keep per enemy type (Horde.wall_dmg); Play again / Main menu. Debug args (main.DEBUG_ARGS) skip
  the menu and never save; real play uses a random seed. Save paths: PC
  %APPDATA%/Godot/app_userdata/RogueShot TD/, phone
  /data/user/0/com.tfc.rogueshottd/files/.
- **Map:** three lanes (west, centre, east) converging on the keep at the
  top. 30 spots: 21 tower, 6 gate, 3 economy ("GOLD": farm or bank).
  Spots unlock with the hero's level (Level.SPOTS `lv`; Sim.unlocked; user
  2026-10-10): Lv 1 = 5 tower + 1 gold spot near the keep, then 1-2 tower
  spots per level up to Lv 10, gold plots at 4 and 7. Gates come in two
  sets of three, one per lane, unlocked together: inner set (Lv 3, side by
  side across the middle, z ~9) and outer set (Lv 8, z ~21, nearer the
  lane mouths); later: synergy for a full set (user idea). Locked pads
  show "Lv N", smaller and dimmed; a level-up names what opened. Horde
  gates are 6 slots (`slot` 0-2 inner, 3-5 outer); an enemy is held by
  the nearest standing gate ahead on its lane (Horde.gate_of). The popup
  belongs to the NEAREST spot in reach (spots can sit close). Unbuilt
  gate pads show a see-through gate. Lane-entrance previews show the
  next wave.
- **Specs and selling (v0.1.28):** towers have 3 `levels` + 2 `specs`;
  level IV is one spec, picked in the popup at III (two-tap preview like
  building: info, stats, range ring). Archer: Sniper Tower (long reach,
  the enemy with the most HP, ignores armour) / Repeater Tower (two
  arrows a shot). Ballista: Great (huge bolts, pierce 4) / Harpoon
  (slows all it hits). Mortar: Cluster (5 bomblets) / Fire (burns 4 s,
  credited to the mortar). Frost: Glacier (freezes solid; bosses half)
  / Frostbite (damage, enemies brittle: +50% damage taken). Banner: War
  Drums (towers x2 attack speed, hero nothing) / Hero's Standard (hero
  +60% damage and attack speed, towers +35%). Level.stats(kind, lv,
  spec), Level.bstats(b), Level.max_levels(kind). Every built spot also
  offers Sell (Sim.sell: SELL_REFUND 40% of `spent`, Confirm yes / no;
  gates too). tools/meta_report.py `--specs=archer:repeater` A/Bs a spec
  against Bot.SPECS.
- **Buildings** (Level.BUILDINGS; towers 4 levels, farm / bank / gate 3;
  a bronze/silver/gold/ruby I-IV badge faces the camera on each): Archer
  (cheap, single target), Ballista (bolt piercing a line), Mortar (lobbed
  splash, minimum range), Frost Crystal (pulse every 2.5 s; 3.5-5 s chill
  slows walking AND attacks), War Banner (towers and hero in its ring
  attack faster), Farm (6/16/30 gold after each wave: an upgrade pays more
  per gold than another level-1 farm), Bank (interest on held gold
  after each wave: rate 10/15/20% by level, the best bank's rate counts;
  each bank adds 12/25/45 to the cap),
  Gate (blocks its lane, has HP, repaired after
  each wave). Range rings: on an empty tower spot the first tap on a
  tower previews its reach (blue; a mortar's dead zone red), the second
  builds; a built tower shows its reach and the next level's (gold).
  During an attack: the tower the hero stands next to (main.RING_NEAR).
  Level-1 reach: archer 6, ballista 8, mortar 2.5-7, frost 3.8, banner
  4.5 m.
- **Enemies:** grunt (red), armored (grey, `armor` 1), runner (yellow,
  fast), brute (giant, KayKit Barbarian, red HP bar), bat (wave 4+, flies
  over gates at 2.2 m; mortar and frost can't target it), crossbowman
  (wave 5+, skeleton; stops `ranged` 6.5 m short of the gate / keep, out
  of the queue, and shoots it), Bone Warlord (the
  boss of waves 10 and 15: own HP (a wave group's `hp` multiplies it:
  wave 15 sends two at x1.85), armour 2.5; at 75 / 50 / 25% HP calls 6
  armored men, at 25% goes berserk x1.4 and immune to slows and freezes
  (Horde.immune); one HP bar each at the top of the HUD), slime (wave 6+,
  bursts into 4 slimelings where it dies, same toughness: ENEMIES
  `split`, Sim._drops_from_deaths), bone mage (wave 8+, ranged caster,
  heals all within 4.5 m 5% max HP/s, green ring), captain (wave 9+,
  armoured knight, all within 4 m walk and attack 40% faster, orange
  ring); auras never touch bosses, the best one counts (Horde._auras,
  haste / healed per enemy). Freeze (Horde.freeze_t), brittle and
  Horde.pace(i) (slow x haste, 0 frozen). Armour: each hit loses
  `armor`, never below Level.ARMOR_FLOOR (40%) of it; burning ignores it.
  Every building and enemy has `desc` (~10 words) / `weak` / `strong`,
  shown as three lines (Level.info) in the build popup, the tower preview,
  the "NEW:" card when a wave first brings a type (hud.show_intro,
  Level.new_types) and the menu's Guide page. User rule (2026-10-10):
  UI text short and precise, no story-telling sentences. Buildings list
  "Strong vs" first, enemies "Weak vs" first (player's point of view).
  UiText.fmt (scripts/ui_text.gd) puts each unit / building's icon
  (assets/icons, rendered by tools/make_icons.gd: re-run after changing
  a model) in front of its name and colours Strong (green) / Weak (red)
  and elements: fire orange-red, frost / slow ice blue, lightning yellow,
  gold gold, armour steel. Card titles take their element's colour. Build
  popup buttons carry the building's icon; lane-entrance previews are
  icon + count rows (main._lane_preview). Leaving a spot forgets a
  previewed (tapped once) tower. HP x Level.wave_hp(w) = 1 +
  0.2 w + 0.05 w^2 since v0.1.28 (Horde.max_hp keeps it for the bars); gold per kill
  doesn't grow. Drops: coins (1), coin stacks (5), ingots (20)
  (Sim.gold_pieces). They walk in from beyond the map and are untargetable
  until their lane's start line (red dashes on the road,
  Level.START_LINE_OUT = 2 m outside the hero's walkable area). At a
  standing gate they queue: the front rank attacks, the rest wait and
  step up; giants shove small ones aside and a second giant hits over the
  first one's shoulder.
- **HUD:** keep HP + hero level / XP bar (top left), coins (top right), FPS
  (top centre), wave / phase line under them, minimap (bottom right;
  hidden while a popup is up), build version (bottom left), gate HP bars
  (blue), giant HP bars (red), boss HP bar (under the wave line).
- **Sound:** 32 SFX (assets/sfx) + looping BGM (assets/music, -16 dB).
- **PC build:** the exported exe sizes its window to 90% of the screen
  height (main._fit_pc_window); editor/WSL runs keep 450x1000.
- **Balance (v0.1.28, tools/meta_report.py):** target set by the user:
  the standard bot (Bot.PLAN, extended for waves 11-15; Bot.SPECS sniper /
  great / cluster / glacier / standard; Bot.CARD_PRIORITY) wins 60-65%.
  It wins 62% of 96 seeds (keep ~74% left in wins); losses: 3 at the
  wave-10 boss, the rest at wave 15 (two bosses). Waves 1-9 barely touch
  the keep; the boss waves decide. Hero ~41% of all damage. Enemy HP
  x(1 + 0.2w + 0.046w^2) (Level.wave_hp): the new wave 10 is x6.5
  (old wave 10: x8.4), wave 15 x12.8. The win rate is a knife edge:
  0.046 -> 0.05 on the quadratic, or wave-15 bosses x1.6 -> x1.85,
  each cost ~20 points. Spec A/B (tools/meta_report.py --specs): see
  docs/DESIGN.md "Spec balance". Random builds win only a few %.
  Older figures: v0.1.23 (10 waves) 91% standard, ~12% random. The user
  found v0.1.15 "feels good".

## Localization (v0.1.24)

- Languages cycle from the title menu's "Language: …" button, applied at
  once (the menu and scene are rebuilt, main._relocalize); saved in
  user://settings.cfg; never the system language. Loc.CHOICES = en,
  zh_TW (Japanese next, user). `--lang=zh_TW` for screenshots.
- `scripts/loc.gd` (Loc): t / tc (context) / fmt ({0}{1} when a language
  reorders) / boot / cycle. English text is the key; Control text goes
  through tr(), static code through Loc.t. Level.info / ename /
  count_text and UiText.fmt translate their words (UiText matches the
  TRANSLATED keyword, longest first).
- `locale/zh_TW.po` is GENERATED by `tools/gen_zh_tw.py` (edit that):
  G = the glossary, the user's picks from the picking page
  https://claude.ai/artifact/PRIVATE-LINK (db collection
  `picks`, doc per term id: {choice a|b|custom, custom, value}); every
  sentence is built from G, so a changed pick flows everywhere. All 65
  rows picked by the user on 2026-10-10 (title 俠盜塔防遊戲, app name
  俠盜塔防, 黃金, 左路／中路／右路, 雜兵, 巨人, 魔蝠, 骷髏戰閥 ...).
  **A new name = a new row on that page for the user**, never invented.
  v0.1.28 added the section "New in v0.1.28" (17 rows: the 10 spec
  names, slime, slimeling, bone mage, captain, Sell, Specialization,
  Freeze), all picked by the user (特化, 凍結, 分身史萊姆, 重型弩砲塔,
  散彈臼砲塔, 燃燒臼砲塔, 霜傷晶塔 ...).
- `tools/icon_check.gd` (run by `./build.sh test`): in every language,
  every unit / building name in the info texts and card / relic texts
  must carry its icon (UiText.ICON_WORDS). Gotcha fixed in v0.1.28: in
  Chinese the first name follows the label's full-width colon directly
  (克制：雜兵), and UiText._find_word took the label's placeholder mark
  for a letter, so that name never got its icon.
- Level.info: buildings AND tower specs (they have a `cost`) list
  Strong vs first with the building labels (克制／被克制).
- `tools/loc_check.py` (run by `./build.sh test`): every tr / Loc.t
  literal and table text has an entry, %-slots kept, characters in the
  font, no mainland word, full-width punctuation. `--pot` lists every
  text. Font: Noto Sans TC subset (`tools/make_font.py`, cache in
  tools/.cache, gitignored) as the default font's fallback; re-run when
  loc_check says a character is missing.
- Taiwan wording rules as in ~/proj_trts/notes/localization.md (遊戲 not
  游戏, 設定, 儲存, 爆擊 not 暴击, 公尺 not 米 ...); Chinese strong/weak
  labels: buildings 克制／被克制, enemies 弱點／強項 (picks).
- HUD phase line: BUILD PHASE / COMBAT PHASE (user: "ATTACK" read oddly).

## Next (docs/DESIGN.md "Build order")

- The user's play-test feedback on 15 waves / specs / new enemies.
- docs/DESIGN.md "Roadmap": done in v0.1.28: 15 waves, specs + selling,
  relic tiers. Left: endless mode + mutators (later, user), card
  evolutions + new relics (Hades-like combos: far future), second map;
  plus gate-set synergy, Japanese, QoL.
- Balance leads from the meta report: banner and frost are weak, ballista
  strong; Rally / Engineer cards weak.
- More levels / maps (the user designs them); then permanent unlocks and
  difficulty mutators.

## Architecture

- `scripts/sim.gd` (Sim) -- ALL rules, no nodes: phases, waves, hero
  (upgrades applied here), buildings (buy / upgrade), towers,
  projectiles, gates, coins, xp / offers / picks, save data, win/lose.
  `step(dt, move)` at fixed 60 Hz. `events` (shot / hit / boom / pulse /
  blast / lightning / volley / kill / coin / midas / built / perk /
  level_up / gate_broken / wave_start / wave_cleared / base_hit) drive
  effects and sound; buy() / start_wave() / pick() events are queued in
  `_pending` and come out on the next step.
- `scripts/horde.gd` -- every enemy as parallel packed arrays per lane
  (no nodes); stable `uid` per enemy (projectiles home by it); burning,
  chill; swap-remove at the end of each step. `_queue` = the gate / keep
  queue (see history).
- `scripts/track.gd` -- a lane as a 0.1 m lookup table, blended between
  entries: point(d, off), forward, right, closest_d. `off` > 0 = right of
  the walking direction.
- `scripts/level.gd` -- ALL level data and tuning: lanes, spots,
  buildings, enemies, waves. `scripts/perks.gd` -- cards, relics, XP
  curve. Balance changes go in these two only.
- `scripts/bot.gd` -- scripted player (PLAN build order, card priority)
  for --auto, --ff, tests and balance runs (`tools/balance.gd`); with a
  variant seed it randomises the build for `tools/meta.gd`, which
  `tools/meta_report.py --runs=N --jobs=J [--fixed]` runs in parallel and
  summarises (win rate, losses by wave, damage share by source, win rate
  by tower mix / economy / relic / card). Sim.dealt_by credits damage.
- `scripts/main.gd` -- view: camera, light, MultiMesh crowds/coins/
  projectiles, buildings, popups, effects, sound, music, menu flow, debug
  args. Draws between sim steps (`_alpha`).
- `scripts/fx.gd` -- hero-upgrade effects (bolt glows, flames, lightning,
  wisp, auras, blasts, level-up).
- `scripts/hud.gd` (+ `minimap.gd`) -- 2D overlay, joystick, build popup,
  card picker, countdown, end screen. `menu.gd` title menu, `confirm.gd`
  yes/no dialog, `save.gd` run + scores on disk.
- `scripts/world.gd` -- ground (shader + baked road distance field),
  procedural cliff slabs, pines/rocks, keep.
- `scripts/models.gd` -- every asset-pack model at its game size; hero
  AnimationTree; building(kind, level); level badges; enemy VAT materials.
- `scripts/sfx.gd` -- pooled SFX player, random variants, rate limits.
- World axes: x = screen right, z = screen down; enemies walk toward -z.
  Camera: no yaw, pitch 56, KEEP_WIDTH (same map width on every phone).

## Assets (all copied into assets/; sources in assets_in/, gitignored)

assets_in/INVENTORY.md lists 16 CC0 packs (previews in assets_in/_previews).
- Hero: KayKit Adventurers `Rogue_Hooded` (~4.8k tris, 76 clips; extra
  weapon meshes freed, only `2H_Crossbow` + cape kept).
- Enemies: Kenney Mini Dungeon `character-human` (grunt; runner = same,
  yellow tint, 0.85 scale), Mini Arena `character-soldier` (armored),
  KayKit Adventurers `Barbarian` (brute, with 2H axe / hat / cape baked as
  rigid bone parts; was Quaternius Giant until v0.1.10), Quaternius
  Animated Monster Pack Bat (CC0; .blend converted to GLB with Blender,
  NLA tracks per action; flat colours baked to a palette texture), KayKit
  Skeletons Rogue + crossbow (crossbowman) and Warrior + axe + shield
  (boss; weapons from separate gltf files via bake_vat `extra`), Mage +
  staff (bone mage), KayKit Adventurers Knight (captain), Quaternius
  Slime (.blend -> GLB with Blender, every action as an NLA track;
  palette; slimelings = the same VAT at half size, tinted). All
  baked to VAT (`--only=a,b` bakes just those); the raw .glb/.gltf are
  left out of exports.
- Downloaded on the main PC from github.com/KayKit-Game-Assets
  (CC0): Barbarian.glb, Dungeon Remastered coin_stack_*.glb, Hexagon
  building_market_blue (bank). Not yet in
  assets_in/INVENTORY.md (that lives on the other PC). Gold ingot is
  procedural (Models.ingot_mesh).
- Towers: Kenney Tower Defense Kit (round/square stacks, ballista,
  catapult, crystals, arrow/boulder ammo); KayKit Hexagon (archer tower,
  windmill farm, market bank, lumbermill keep, flag, stone gate). Pines:
  Kenney Nature (recoloured). Rocks: KayKit Forest. Coin and coin stacks:
  KayKit Dungeon.
- SFX: tools/sfx_build.py rebuilds assets/sfx from assets_in/sfx_src;
  credits in assets/sfx/CREDITS.txt (`wave_start` is CC-BY 4.0, "Kat").
- BGM: assets/music/bgm_city.mp3 = Pixabay "RPG City" (phantasticbeats),
  the user's download; fine inside the game, not to be redistributed alone.

## How the crowd is drawn (VAT)

`tools/bake_vat.gd` (headless; re-run after changing a character or clip
list) CPU-skins each enemy at every frame of walk / attack / die / idle and
writes assets/vat/<type>.res (merged mesh + meta "vat": clip -> [start,
frames, fps, loops]) and <type>_pos/_nrm.res (RGBAH, 1024 texels per row).
`shaders/vat.gdshader` texelFetch-es VERTEX/NORMAL by VERTEX_ID for the
frame in INSTANCE_CUSTOM. One MultiMesh per type, 20 floats per instance
written in one buffer per frame (main.gd `_put`); corpses share it.

## Releasing a build to the phone

`./build.sh apk` bumps build_number.txt -> Android versionCode and the
"v0.1.N" shown bottom-left, writes `D:\wsl_scratch\proj_tdks\rogueshot_td.apk`
and deletes the .idsig side file. The same debug key signs every build, so
a new APK installs over the old one. The user copies it to the phone and
taps it, or after pairing Wireless debugging (`./build.sh adb pair
IP:PORT CODE`, `./build.sh adb connect IP:PORT`) `./build.sh install`.
Never change package/unique_name (`com.tfc.rogueshottd`) or the keystore
(Android would refuse the update). History: v0.1.0-0.1.7 shipped as
`com.tfc.kingshottd` signed on the other PC; from v0.1.8 the package and
key are new (key made on this PC, 2026-10-09), so the old "Kingshot TD" app
is a separate install the user can delete.

## Build / test (`./build.sh`, see its header)

`check` (import + parse every script), `test` (headless rule tests incl. a
full bot win), `sim [--seed=N] [--idle] [--nopicks]` (balance timeline,
~5 s), `shot
NAME ARGS` (WSL screenshot; refuses to launch unless all scripts parse),
`export` + `native ARGS` (Windows exe), `apk`, `install`, `adb ARGS`,
`logcat`. Bakers: `tools/bake_vat.gd`, `tools/make_icons.gd` (GPU), `tools/bake_terrain.gd` (re-run
after changing Level.LANES; a test checks the stored hash). Probes:
`tools/inspect.gd`, `tools/hero_probe.gd`.
Game args (after `--`): `--auto --ff=SEC --speed=X (0 = freeze) --seed=N
--shot=PATH --shot-delay=S --bench=S --zoom=X --cam=X,Z|gate --hero=X,Z
--noshadow --mute --notree --drops --ff-idle --build=S:K[:N],... --load
--page=scores|credits|guide --play --newgame --perks=ID[:T],... --offer[=cards]
--preview=KIND
--lightning --ask --demo=anim|hero|clips --clips=A,B
--bowrot=X,Y,Z` (main.gd header explains each). `--demo=clips` (raw
hero clips side by side) is how the carry pitch was picked; render it
with `--resolution 1500x600`. `--bench` prints [prof] per-section ms and
[render] counters. README screenshots (docs/screens) were taken with
`shot` + `--build`, `--offer=cards`, `--lightning`.

## Target device

The user's phone: **(model in CLAUDE.local.md)**. Dimensity 7050 (2x A78 + 6x A55),
**Mali-G68 MC4**, 6.7" AMOLED **1080x2412** (20:9), 120 Hz, 8 GB. Holds the
60 fps cap (user, 2026-10-09). Judge performance there or in the native
Windows build, never in WSL.

## Environment

- Same two WSL2 PCs as ~/proj_3dim (see its CLAUDE.md "Environment" and
  ~/proj_trts/GODOT-BLENDER-WSL-PLAYBOOK.md). Godot 4.7.2,
  Blender 4.5, yt-dlp in ~/.local/bin. Builds go to `D:\wsl_scratch\proj_tdks\`.
- Renderer: **Compatibility (GLES3) everywhere**, so WSL shots show what
  the phone renders. Lighting set by measuring pixels: sun 0.45, ambient
  0.36, linear tonemap -> grass ~(53,174,119) vs the ad's ~(47,170,110).
- Android toolchain (no sudo): JDK 17 Temurin ~/opt/jdk-17, SDK
  ~/opt/android-sdk (build-tools 35.0.1, android-35), debug keystore
  ~/opt/android-debug.keystore (pass "android"; the v0.1.8+ key lives on
  the main PC -- copy it to the other PC before building there, or
  its APKs won't update the phone's install), paths in
  ~/.config/godot/editor_settings-4.7.tres. Non-Gradle export, arm64 only.
  Harmless export warnings: build-tools vs target SDK 36, "cannot connect to
  daemon at tcp:5037".
- Phone install uses the WINDOWS adb
  (`/mnt/d/wsl_scratch/android-platform-tools/platform-tools/adb.exe`);
  WSL2's network can't reach LAN devices.
- Touch on PC: `emulate_touch_from_mouse=true`, so a mouse drag is a touch
  drag; the HUD joystick reads touch events only.
- Before trusting a native benchmark, check the GPU is idle:
  `/mnt/c/Windows/System32/nvidia-smi.exe` (a 20 fps run on 2026-10-09 was
  another game holding it at 100%; idle, the game sits at the 120 fps cap with 170
  enemies; headless frame cost ~1 ms).
- `wait_idle` in build.sh yields to other Godot/Blender jobs; command lines
  containing `proj_tdks` or `proj-tdks` (our scratchpad) count as ours.
- ref/ (videos, the BGM source) and assets_in/ (755 MB of packs) are local
  only; re-fetch the videos with yt-dlp, the packs per INVENTORY.md.

## History and gotchas worth keeping

- v0.1.0-0.1.1: gray box of the Kingshot ad level, then real models. User:
  no town hall ("pure TD, not the commercial scam the original is").
- v0.1.2: scenery v2 (road distance field, slab cliffs, recoloured pines).
  Build hitch on the phone fixed by `_warm_up` (preload + draw one of every
  building/effect hidden at start so shaders compile early).
- v0.1.3: gate queue bug (giants idling 1-5 m short of the gate): each enemy
  used to pick a fixed stop distance at spawn. Horde._queue now keeps
  nobody closer than (ri+rj)*0.75 to the enemy ahead in its lane position
  (|off| < (ri+rj)*0.8); blocked 1 = hitting, 2 = held. Regression test.
- v0.1.4: shoot-while-moving AnimationTree. Upper-body filter includes the
  ROOT bone (KayKit strafe clips turn the root 60 deg). Plain Idle/Run hold
  the crossbow 25-33 cm below the feet (tools/hero_probe.gd), so they are
  never used for the arms with the crossbow at its own angle; the relaxed
  run turns the crossbow -45 deg instead (v0.1.9). The hero stands on pads
  at PAD_TOP.
- v0.1.5: design v2 (3 lanes, phases, 7 buildings, projectiles, SFX).
- v0.1.6: waves 1-2 bigger for more early gold. v0.1.7: gate tower spots,
  ghost gates, minimap, BGM, HUD overlap fix.
- v0.1.8: renamed RogueShot TD, new package + key (see Releasing).
- v0.1.9: camera follows the hero 1:1 sideways (was x*0.75, clamped at
  -8, so the westmost spots sat at the screen edge) and looks
  CAM_POPUP_LIFT lower while a build popup is open. Minimap clips lanes
  and the view outline to its frame. Frost: slower
  pulse, longer chill, chill also slows attacks. Relaxed hero run.
- v0.1.10: giants (ENEMIES `heavy`) no longer wait behind small enemies
  at a gate: Horde._queue shoves light ones in a giant's path sideways
  (SHOVE_SPEED, at most SHOVE_EDGE off-centre) and they never hold it.
  Giants still queue behind giants; `reach` lets a held one within reach
  of the gate hit it (2 giants hit together, a 3rd waits). User picked
  this (push + reach) over no-collision / spreading. Bot keep after wave
  6 fell from 30 to 16-26 (gates break faster).
- v0.1.11: 10 waves + tower level IV + per-wave HP growth; enemies attack
  the keep (no more leak/escaped); start pad countdown; tiered gold drops;
  level badges; Barbarian brute; PC window fit; smooth motion. Bot bug:
  it never got within SPOT_REACH*0.8 of a built farm (solid), so it never
  upgraded farms; it now buys when spot_under_hero() is the spot.
- v0.1.12: full-screen start countdown digit. v0.1.13: main menu, saves,
  scores, credits; bank; 11 more tower spots; attack-phase range ring;
  giant HP bars (were divided by the base HP, not the wave-scaled one, so
  the first 2/3 of a late giant's HP never showed: Horde.max_hp).
- v0.1.14: gold invisible after New game (drop MultiMesh list not
  cleared on restart: anything built per game must be cleared in
  main._start). v0.1.15: hero upgrades (XP, cards, relics, FX); save
  format v2 (older run.json files are ignored). Flames: billboards inside
  a body are hidden by it; Fx offsets them toward the camera.
- v0.1.16: Esc/back confirmations; start line moved from 1.5 m inside
  to 2 m outside the walkable area and marked (user: enemies "in range"
  at the bottom of the centre lane weren't shot); score = keep % x 10 +
  gold for ties on waves.
- v0.1.28: 15 waves, tower specs + selling, relic tiers, slimes / bone
  mages / captains, boss rework (two on wave 15). Balance by A/B runs:
  the bosses decide most games, so anything that hurts or holds a boss
  (Sniper aiming at the most HP, Glacier freezing it) swung the standard
  bot's win rate by 30-60 points; bosses thaw twice as fast, and specs
  were tuned until each swap stays within ~15 points. Mid-step spawns
  (a slime's brood) also push prev_pos (Horde.spawn) so _compact never
  reads past the end.
- v0.1.26: end-screen damage tables (centred grids, Hud.show_end), hero
  level in the score; the last wave's coin sweep lands before the win
  (Sim.finished); boss bar below the phase line.
- v0.1.24: Traditional Chinese (Loc, gen_zh_tw.py, loc_check.py, Noto
  Sans TC), Language button, COMBAT PHASE.
- v0.1.23: spots unlock by hero level; two gate sets (inner Lv 3, outer
  Lv 8), gates by slot; popup = nearest spot (the bot got stuck between a
  gate pad and a tower spot otherwise).
- v0.1.22: icons on build buttons and lane previews, hero level from 1.
- v0.1.21: inline unit icons, element colours, sweep holds the hero,
  popup bottom margin.
- v0.1.19: UI text pass (summary / weak vs / strong vs everywhere, Guide
  page, compact stat lines).
- v0.1.18: armour, bats, crossbowmen, Bone Warlord boss; farm / bank
  rework; picks wait for the coin sweep; meta-analysis tools. Bake gotcha:
  GDScript lambdas capture locals by value (the baked material came out
  null until it went through an array); glTF colour factors are linear
  (palette needs linear_to_srgb).
- v0.1.17 (tester feedback): end-of-wave coin sweep (bank interest counts
  coins still on the ground; saves bank them), Magnet -> Scholar, XP
  radius follows Long Shot, "+N XP" pop-ups, two-tap tower range preview,
  next-level ring.
- MultiMesh bounds go stale when the buffer is written directly: a close
  camera culled the whole crowd; `custom_aabb` = whole map.
- Kenney/KayKit building meshes shadow-acne at any bias: they don't
  receive shadows (Models._no_receive_shadows). Kenney colormaps are
  palette PNGs with dithered gradients: converted to RGBA + blurred.
- A GDScript parse error still opens a (blank, never-quitting) window:
  `build.sh shot` gates on `check`. Typed `var x: T =` for Variant values.
