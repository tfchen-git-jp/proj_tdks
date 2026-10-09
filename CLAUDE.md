# proj_tdks — project notes

**RogueShot Tower Defense** (RogueShot TD / RSTD; renamed from "Kingshot
TD" on 2026-10-09 -- the hero is a rogue, not a king).

A 3D low-poly **tower defense for Android (and PC)**, made with Godot 4.7 by
directing Claude. It started as a recreation of the TD level in Kingshot's
ads (`ref/yt_BQE4bvmtvDo.mp4`) and now follows Thronefall's defense system
(`ref/yt_bHMSu6iMIYI.mp4`, design in `docs/DESIGN.md`). Personal use: the
user and friends, never published. Repo: github.com/tfchen-git-jp/proj_tdks
(private). The user designs later levels.

## The game today (v0.1.13)

- **Hero:** hooded crossbow rogue on a floating joystick (touch anywhere,
  drag; mouse drag on PC, WASD too). Auto-shoots the nearest enemy in range,
  also while moving (legs run/strafe/backpedal, upper body keeps aiming);
  with no enemy in reach it runs relaxed, crossbow carried (Running_A on
  the whole body, crossbow turned Models.HERO_CARRY_PITCH in the hand).
  Walks over dropped gold to collect it (magnet radius).
- **Phases:** BUILD (no enemies; walk onto a spot and its popup appears;
  stand on the red START pad by the keep: it shows the next wave per lane
  and counts down Level.START_COUNTDOWN (5 s); walking off cancels) and
  ATTACK (no building). 10 waves; clear them all to win. Enemies that reach
  the keep stand at it and hit it with their dps (queue like at a gate)
  until killed; keep HP Level.BASE_HP (600), lose at 0.
- **Menu:** title screen over the drifting map (scripts/menu.gd): New game,
  Continue (user://run.json, written at every wave start and clear by
  scripts/save.gd; Sim.to_save / from_save), Scores (top 10 in
  user://scores.json: waves cleared, then gold), Credits, Exit. Esc /
  Android back returns to it (the run resumes from the last wave start).
  End screen: Play again / Main menu. Debug args (main.DEBUG_ARGS) skip
  the menu and never save; real play uses a random seed.
- **Map:** three lanes (west, centre, east) converging on the keep at the
  top. 28 spots: 22 tower (11 x_* added v0.1.13 by a grid search), 3 gate
  (one per lane, each with a tower spot beside it), 3 economy ("GOLD":
  farm or bank). Unbuilt gate pads show a see-through gate across the
  lane they block. Lane labels at each entrance preview the next wave.
- **Buildings** (towers 4 levels, farm and gate 3; Level.BUILDINGS; a
  bronze/silver/gold/ruby badge with I-IV faces the camera on each): Archer (cheap, single
  target), Ballista (slow bolt piercing a line), Mortar (lobbed splash, has
  a minimum range), Frost Crystal (pulse every 2.5 s, 3.5-4.5 s chill slows walking AND
  attacks, chips), War Banner (towers
  AND hero in its ring attack faster), Farm (gold after each wave), Bank
  (10% interest on held gold after each wave; the rate never stacks, each
  bank adds 10/18/28 to the cap), Gate
  (blocks its lane, has HP, repaired after each wave).
- **Enemies:** grunt (red), armored (grey), runner (yellow, fast), brute
  (giant, KayKit Barbarian, red HP bar). HP grows each wave
  (Level.wave_hp: 1 + 0.05 w + 0.022 w^2), gold per kill doesn't. They
  drop gold as coins (1), coin stacks (5) and ingots (20) (Sim.gold_pieces).
  They walk in from beyond the map and are untargetable
  until past their lane's start line (inside the hero's reach), so every
  coin lands where it can be picked up. At a standing gate they queue: the
  front rank attacks, the rest wait and step up; giants shove small ones
  aside and a second giant hits over the first one's shoulder.
- **Range ring:** in the build popup for the spot's building; during an
  attack for the tower the hero stands next to (main.RING_NEAR).
- **HUD:** keep HP (top left), coins (top right), FPS (top centre), wave /
  phase line under them, minimap (bottom right; hidden while a popup is up),
  build version (bottom left), gate HP bars (blue), giant HP bars (red).
- **Sound:** 32 SFX (assets/sfx) + looping BGM (assets/music, -16 dB).
- Balance: user beat 6 waves on v0.1.6 (felt waves 1-2 a bit easy, 5-6 a
  bit hard) and finished v0.1.10 with 300+ gold. v0.1.11 (10 waves): bot
  wins ~5 of 6 seeds with the keep at 15-70%, damage mostly in waves 7 and
  10, idle loses in wave 3. Gold left after wave 10 is that wave's loot.
- **PC build:** the exported exe sizes its window to 90% of the screen
  height (main._fit_pc_window); editor/WSL runs keep 450x1000.
- Motion is drawn between sim steps (main._alpha; Horde.prev_pos /
  prev_phase, Sim.hero_prev) and Track.point blends its 0.1 m table: both
  were behind "jumpy" walkers.

## Next (docs/DESIGN.md "Build order")

Enemies attack only walls (gates, keep), never the hero or towers (user).
4. New enemy roles (siege, ranged) and a boss wave.
5. Roguelike hero upgrade cards after each wave.
6. Score screen; then more levels.

## Architecture

- `scripts/sim.gd` (Sim) -- ALL rules, no nodes: phases, waves, hero,
  buildings (buy / upgrade), towers, projectiles, gates, coins, win/lose.
  `step(dt, move)` at fixed 60 Hz. `events` (shot / hit / boom / pulse /
  kill / coin / built / gate_broken / wave_start / wave_cleared / base_hit)
  drive effects and sound; buy() / start_wave() events are queued in
  `_pending` and come out on the next step.
- `scripts/horde.gd` -- every enemy as parallel packed arrays per lane
  (no nodes); stable `uid` per enemy (projectiles home by it); swap-remove
  at the end of each step. `_queue` = the gate queue (see history).
- `scripts/track.gd` -- a lane as a 0.1 m lookup table: point(d, off),
  forward, right, closest_d. `off` > 0 = right of the walking direction.
- `scripts/level.gd` -- ALL level data and tuning: lanes, spots,
  buildings, enemies, waves. Balance changes go here only.
- `scripts/bot.gd` -- scripted player (PLAN build order) for --auto, --ff,
  tests and balance runs.
- `scripts/main.gd` -- view: camera, light, MultiMesh crowds/coins/
  projectiles, buildings, popups, effects, sound, music, debug args.
- `scripts/hud.gd` (+ `minimap.gd`) -- 2D overlay and joystick.
- `scripts/world.gd` -- ground (shader + baked road distance field),
  procedural cliff slabs, pines/rocks, keep.
- `scripts/models.gd` -- every asset-pack model at its game size; hero
  AnimationTree; building(kind, level); enemy VAT materials.
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
  rigid bone parts; was Quaternius Giant until v0.1.10). All baked to VAT.
- Downloaded on the main PC from github.com/KayKit-Game-Assets
  (CC0): Barbarian.glb, Dungeon Remastered coin_stack_*.glb, Hexagon
  building_market_blue (bank). Not yet in
  assets_in/INVENTORY.md (that lives on the other PC). Gold ingot is
  procedural (Models.ingot_mesh).
- Towers: Kenney Tower Defense Kit (round/square stacks, ballista,
  catapult, crystals, arrow/boulder ammo); KayKit Hexagon (archer tower,
  windmill farm, lumbermill keep, flag, stone gate). Pines: Kenney Nature
  (recoloured). Rocks: KayKit Forest. Coin: KayKit Dungeon.
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
full bot win), `sim [--seed=N] [--idle]` (balance timeline, ~3 s), `shot
NAME ARGS` (WSL screenshot; refuses to launch unless all scripts parse),
`export` + `native ARGS` (Windows exe), `apk`, `install`, `adb ARGS`,
`logcat`. Bakers: `tools/bake_vat.gd`, `tools/bake_terrain.gd` (re-run
after changing Level.LANES; a test checks the stored hash). Probes:
`tools/inspect.gd`, `tools/hero_probe.gd`.
Game args (after `--`): `--auto --ff=SEC --speed=X (0 = freeze) --seed=N
--shot=PATH --shot-delay=S --bench=S --zoom=X --cam=X,Z|gate --hero=X,Z
--noshadow --mute --notree --drops --ff-idle --build=S:K[:N],... --load
--page=scores|credits --play --demo=anim|hero|clips --clips=A,B
--bowrot=X,Y,Z`. `--demo=clips` (raw hero clips side by side) is how
the carry pitch was picked; render it with `--resolution 1500x600`. `--bench` prints [prof]
per-section ms and [render] counters.

## Target device

The user's phone: **(model in CLAUDE.local.md)**. Dimensity 7050 (2x A78 + 6x A55),
**Mali-G68 MC4**, 6.7" AMOLED **1080x2412** (20:9), 120 Hz, 8 GB. Holds the
60 fps cap (user, 2026-10-09). Judge performance there or in the native
Windows build, never in WSL.

## Environment

- Same two WSL2 PCs as ~/proj_3dim (see its CLAUDE.md "Environment" and
  ~/proj_trts/proto-rts/GODOT-BLENDER-WSL-PLAYBOOK.md). Godot 4.7.2,
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
- MultiMesh bounds go stale when the buffer is written directly: a close
  camera culled the whole crowd; `custom_aabb` = whole map.
- Kenney/KayKit building meshes shadow-acne at any bias: they don't
  receive shadows (Models._no_receive_shadows). Kenney colormaps are
  palette PNGs with dithered gradients: converted to RGBA + blurred.
- A GDScript parse error still opens a (blank, never-quitting) window:
  `build.sh shot` gates on `check`. Typed `var x: T =` for Variant values.
