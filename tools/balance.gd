extends SceneTree
## Headless balance run: the bot plays level 1 at a fixed 60 Hz step.
##   godot --headless --path . --script res://tools/balance.gd -- [--seed=N] [--idle]
## --idle: the hero never moves or builds: how far does nothing get?
## --nopicks: no hero upgrades (baseline).

const SimS := preload("res://scripts/sim.gd")
const BotS := preload("res://scripts/bot.gd")


func _init() -> void:
	var seed_value := 1
	var idle := false
	var nopicks := false
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--seed="):
			seed_value = int(a.get_slice("=", 1))
		elif a == "--idle":
			idle = true
		elif a == "--nopicks":  # hero upgrades off (baseline)
			nopicks = true
	var sim = SimS.new(seed_value)
	var bot = BotS.new(sim)
	var dt := 1.0 / 60.0
	var peak := 0
	var t0 := Time.get_ticks_msec()
	var wave_peak := 0
	var keep_at_start := 0.0
	var spent := 0
	while sim.state == "play" and sim.time < 3000.0:
		if idle:
			sim.step(dt, Vector2.ZERO)
			if sim.phase == "build":
				sim.start_wave()
		else:
			if nopicks:
				sim.offer.clear()
				sim.pending_levels = 0
				sim.pending_relics = 0
			sim.step(dt, bot.move())
		peak = maxi(peak, sim.horde.count())
		wave_peak = maxi(wave_peak, sim.horde.count())
		for e in sim.events:
			match String(e.type):
				"built":
					spent += int(e.cost)
					print("  %6.1fs  built %s L%d at %s (-%d, %d left)" % [sim.time, e.kind, e.level + 1, e.spot.id, e.cost, sim.coins])
				"wave_start":
					print("%6.1fs WAVE %d starts  coins=%d keep=%d" % [sim.time, e.wave + 1, sim.coins, sim.base_hp])
					wave_peak = 0
					keep_at_start = sim.base_hp
				"wave_cleared":
					print("%6.1fs wave %d cleared  income=%d coins=%d keep=%d/%d (-%d) peak=%d spent_total=%d level=%d" % [
						sim.time, e.wave + 1, e.income, sim.coins, sim.base_hp, Level.BASE_HP,
						keep_at_start - sim.base_hp, wave_peak, spent, sim.level])
				"perk":
					print("  %6.1fs  picked %s%s" % [sim.time, e.id, " (relic)" if e.relic else " -> tier %d" % e.tier])
				"gate_broken":
					print("  %6.1fs  gate broken on %s" % [sim.time, Level.LANE_NAMES[e.lane]])
	print("RESULT %s at %.1fs wave=%d/%d keep=%d/%d killed=%d coins=%d spent=%d peak=%d level=%d (%d ms)" % [
		sim.state, sim.time, sim.wave + (1 if sim.state != "win" else 0), Level.WAVES.size(), sim.base_hp, Level.BASE_HP,
		sim.horde.killed, sim.coins, spent, peak, sim.level, Time.get_ticks_msec() - t0])
	print("hero dealt %.0f of %.0f damage (%.0f%%)" % [sim.dealt_by.get("hero", 0.0), sim.horde.dealt, 100.0 * float(sim.dealt_by.get("hero", 0.0)) / maxf(sim.horde.dealt, 1.0)])
	quit()
