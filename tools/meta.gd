extends SceneTree
## Meta runs for balance analysis: whole games played headlessly by a bot
## whose build plan is randomised per run (Bot variant), one JSON line per
## game ("[run] {...}") for tools/meta_report.py to aggregate.
##   godot --headless --path . --script res://tools/meta.gd -- --from=0 --count=20 [--fixed]
##     [--specs=archer:repeater,...]
## --fixed: the standard Bot.PLAN and card priority (only the seed varies).
## --specs: the fixed bot takes these specs instead of Bot.SPECS (A/B).

const SimS := preload("res://scripts/sim.gd")
const BotS := preload("res://scripts/bot.gd")
const DT := 1.0 / 60.0


func _init() -> void:
	var from := 0
	var count := 10
	var fixed := false
	var specs := {}
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--specs="):
			for item in a.get_slice("=", 1).split(","):
				specs[item.get_slice(":", 0)] = item.get_slice(":", 1)
		if a.begins_with("--from="):
			from = int(a.get_slice("=", 1))
		elif a.begins_with("--count="):
			count = int(a.get_slice("=", 1))
		elif a == "--fixed":
			fixed = true
	for r in range(from, from + count):
		print("[run] ", JSON.stringify(_play(r, fixed, specs)))
	quit()


func _play(r: int, fixed: bool, specs: Dictionary) -> Dictionary:
	var sim = SimS.new(1000 + r)
	var bot = BotS.new(sim, -1 if fixed else 5000 + r)
	for id in bot.layout():
		if specs.has(bot.layout()[id]):
			bot.specs[id] = specs[bot.layout()[id]]
	var keep_lost := []  # per wave
	var keep0: float = sim.base_hp
	var gates := 0
	while sim.state == "play" and sim.time < 5000.0:
		sim.step(DT, bot.move())
		for e in sim.events:
			match String(e.type):
				"wave_start":
					keep0 = sim.base_hp
				"wave_cleared":
					keep_lost.push_back(roundi(keep0 - sim.base_hp))
				"gate_broken":
					gates += 1
	if sim.state != "play" and keep_lost.size() < sim.wave + 1 and sim.state == "lose":
		keep_lost.push_back(roundi(keep0 - sim.base_hp))
	# Tower levels built per kind, economy buildings.
	var levels := {}
	for b in sim.buildings.values():
		levels[b.kind] = int(levels.get(b.kind, 0)) + int(b.level) + 1
	var wall := {}  # enemy name -> damage to gates and the keep
	for k in Level.ENEMIES.size():
		if sim.horde.wall_dmg[k] > 0.0:
			wall[Level.ENEMIES[k].name] = roundi(sim.horde.wall_dmg[k])
	var built_specs := {}  # spec id -> how many towers took it
	for b in sim.buildings.values():
		if String(b.spec) != "":
			built_specs[b.spec] = int(built_specs.get(b.spec, 0)) + 1
	var total := maxf(sim.horde.dealt, 1.0)
	var share := {}
	for k in sim.dealt_by:
		share[k] = snappedf(float(sim.dealt_by[k]) / total, 0.001)
	return {run = r, fixed = fixed, win = sim.state == "win", waves = sim.wave if sim.state != "win" else Level.WAVES.size(),
		keep = snappedf(sim.base_hp / Level.BASE_HP, 0.01), gold = sim.coins, level = sim.level,
		levels = levels, share = share, perks = sim.perks, relics = sim.relics, keep_lost = keep_lost,
		gates_broken = gates, layout = bot.layout(), specs = built_specs, wall = wall}
