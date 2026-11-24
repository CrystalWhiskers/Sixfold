extends SceneTree

## Boss defence, measured, with a scripted player at the Barracks.
##
## Two players, both starting from the same free draws:
##   * "decent" — once a second it merges any pair it has, buys income up to three
##     upgrades, keeps recruiting into whichever section is smallest, and drills
##     sections once they are full;
##   * "idle" — never touches anything after the opening draws.
## Prints how long each fight lasts, who won, when each crystal fell and when each
## phase began, how much Supply was spent, and what the simulation cost.
##
##   godot --headless --script res://tools/measure_boss.gd
##
## Environment: BOSS_RUNS (default 6), BOSS_HP / BOSS_ATK (override the boss),
## BOSS_POLICY (decent, idle or both — the default).

const LOADOUT := "res://data/loadouts/starter.tres"


static func act(b: Barracks, policy: String) -> void:
	## One second's worth of decisions for a scripted player.
	if policy != "decent":
		return
	for s in Barracks.SECTIONS:
		while b.merge_any(s):
			pass
	if b.income_level < 3 and b.supply >= b.income_price():
		b.upgrade_income()
		return
	var thinnest := b.unit_count(0)
	for s in Barracks.SECTIONS:
		thinnest = mini(thinnest, b.unit_count(s))
	# Once every section has a few units, save up for the next income upgrade
	# rather than spending everything on recruits as it comes in.
	if b.income_level < 3 and thinnest >= 3:
		return
	var smallest := -1
	for s in Barracks.SECTIONS:
		if b.free_slot(s) >= 0 and (smallest < 0 or b.unit_count(s) < b.unit_count(smallest)):
			smallest = s
	# Thin sections first; after that, alternate between upgrading the cheapest unit
	# type and adding bodies, whichever is cheaper right now.
	var cheapest: UnitData = null
	for t in b.types:
		if cheapest == null or b.upgrade_price(t.id) < b.upgrade_price(cheapest.id):
			cheapest = t
	var up_price := b.upgrade_price(cheapest.id) if cheapest != null else INF
	if smallest >= 0 and (thinnest < 3 or b.recruit_price() <= up_price):
		if b.supply >= b.recruit_price():
			b.recruit(smallest)
		return
	if cheapest != null and b.supply >= up_price:
		b.upgrade_type(cheapest.id)


static func fight(seed_value: int, boss: BossData, policy: String) -> Dictionary:
	BoardModel.use_map(BossFight.make_map())
	var board := BoardModel.new()
	var barracks := Barracks.new()
	barracks.setup(boss, load(LOADOUT) as LoadoutData, seed_value)
	var bf := BossFight.new()
	bf.place_structures(board, boss)
	var sim := CombatSim.new()
	bf.attach(sim, barracks)
	sim.setup(board, seed_value)
	bf.start()
	var t0 := Time.get_ticks_msec()
	var peak := 0
	while not sim.is_finished():
		var before := sim.elapsed
		sim.step_until(sim.elapsed + 1.0)
		barracks.tick(sim.elapsed - before)
		act(barracks, policy)
		peak = maxi(peak, bf.living_army())
		if OS.has_environment("BOSS_TRACE") and int(sim.elapsed) % 30 == 0:
			print("    t=%.0f finished=%s" % [sim.elapsed, sim.is_finished()])
	var ms := Time.get_ticks_msec() - t0
	var notes: PackedStringArray = []
	for e in sim.events:
		match e.kind:
			"death":
				for i in bf.crystals.size():
					if int(e.uid) == bf.crystals[i].uid:
						notes.append("%s crystal@%.0f" % [BossFight.ZONE_NAMES[i], e.t])
			"boss_phase":
				notes.append("%s@%.0f" % [e.name, e.t])
	var down := 0
	for i in 3:
		if not bf.crystals[i].is_alive():
			down += 1
	var result := {winner = sim.result(), t = sim.duration(), ms = ms, notes = notes,
		boss_hp = bf.boss.current_hp, crystals_down = down, waves = bf.waves,
		peak = peak, spent = barracks.spent, income = barracks.income,
		levels = barracks.level.values()}
	BoardModel.reset_map()
	return result


func _initialize() -> void:
	var boss := load("res://data/boss/arbiter.tres") as BossData
	var runs := int(OS.get_environment("BOSS_RUNS")) if OS.has_environment("BOSS_RUNS") else 6
	if OS.has_environment("BOSS_ATK"):
		boss.attack_damage = float(OS.get_environment("BOSS_ATK"))
	for pair in [["BOSS_INCOME", "base_income"], ["BOSS_STEP", "income_step"],
			["BOSS_STAT", "upgrade_stat_per_level"], ["BOSS_GROWTH", "recruit_growth"]]:
		if OS.has_environment(pair[0]):
			boss.set(pair[1], float(OS.get_environment(pair[0])))
	if OS.has_environment("BOSS_HP"):
		boss.max_hp = float(OS.get_environment("BOSS_HP"))
	var which := OS.get_environment("BOSS_POLICY") if OS.has_environment("BOSS_POLICY") else "both"
	var policies: Array = ["decent", "idle"] if which == "both" else [which]
	print("\n%s, %.0f health, %.0f attack" % [boss.display_name, boss.max_hp, boss.attack_damage])
	for policy in policies:
		print("\n  %s player:" % policy)
		var wins := 0
		var total := 0.0
		for i in runs:
			var r := fight(1000 + i * 77, boss, policy)
			var won := int(r.winner) == BoardModel.TEAM_B
			if won:
				wins += 1
			total += float(r.t)
			print("  seed %d: %s at %3.0fs (%d:%02d)  boss hp %6.0f  crystals down %d  waves %d  peak army %d  spent %.0f  income %.0f/s  levels %s  sim %d ms" % [
				i, "WIN " if won else "LOSS", r.t, int(r.t) / 60, int(r.t) % 60, r.boss_hp,
				r.crystals_down, r.waves, r.peak, r.spent, r.income, str(r.levels), r.ms])
			print("      ", "  ".join(r.notes))
		print("  %s: won %d of %d, average %.0fs" % [policy, wins, runs, total / maxf(runs, 1)])
	quit()
