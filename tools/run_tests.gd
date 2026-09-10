extends SceneTree

var _passed := 0
var _failed := 0
var _loadout: LoadoutData


func _initialize() -> void:
	_loadout = load("res://data/loadouts/starter.tres") as LoadoutData
	if _loadout == null:
		push_error("Run tools/generate_data.gd first.")
		quit(1)
		return

	print("\n=== Six by Eleven — headless tests ===\n")
	_test_board_geometry()
	_test_deploy_zones()
	_test_mirror()
	_test_placement_and_movement()
	_test_data_is_linked_not_embedded()
	_test_merging()
	_test_merge_lottery()
	_test_stat_modifiers()
	_test_draw_determinism()
	_test_combat_runs()
	_test_combat_determinism()
	_test_move_lockout()
	_test_movement_rules()
	_test_retinue()
	_test_chassis()
	_test_engineer_build()
	_test_aegis()
	_test_retribution()
	_test_shadowstep_bait()
	_test_pathing_weighs_the_detour()
	_test_targets_are_not_all_the_same()
	_test_levy_is_capped()
	_test_reaver()
	_test_roster_order()
	_test_grief_mana()
	_test_vigil_raises_by_tier()
	_test_remembrance_adds_raises()
	_test_devourer_ascends()
	_test_devourer_cannot_start_alone()
	_test_gluttony()
	_test_empowered_paragon_is_slow()
	_test_melee_reaches_the_corners()
	_test_a_stuck_unit_still_swings()
	_test_nothing_in_reach_is_not_an_attack()
	_test_breakable_stone()
	_test_high_ground_rules()
	_test_stairs_are_the_only_way_up()
	_test_every_plateau_has_stairs()
	_test_the_round_clock()
	_test_a_mason_wall_is_a_real_wall()
	_test_sapper_and_mason_in_battle()
	_test_walls_have_health()
	_test_units_walk_round_stone()
	_test_a_sealed_unit_digs_out()
	_test_the_sapper_prefers_the_wall()
	_test_a_unit_kept_waiting_digs()
	_test_mason_opens_with_a_wall()
	_test_the_terrain_buffs()
	_test_the_shell_takes_time()
	_test_the_ground_keeps_burning()
	_test_siphon_answers_the_biggest_thing()
	_test_siphon_ignores_shields()
	_test_the_new_ranged_buffs()
	_test_the_mason_wall_is_a_firing_slit()
	_test_the_mason_owns_its_walls()
	_test_the_mason_builds_underfoot()
	_test_builders_step_off_their_own_work()
	_test_walls_do_not_outlive_the_round()
	_test_the_pariah_is_nothing_without_elbow_room()
	_test_pariah_isolation_is_fixed_at_the_bell()
	_test_the_pariah_share_climbs_with_tier()
	_test_blight_opens_the_target_up()
	_test_blight_bites_current_health()
	_test_blight_shuts_the_target_down()
	_test_stasis_freezes()
	_test_a_frozen_death_leaves_nothing()
	_test_overkill_is_measured_against_the_whole_bar()
	_test_every_death_names_its_unit()
	_test_permafrost()
	_test_spite()
	_test_the_colossus_hardens_when_struck()
	_test_rapid_weak_fire_cannot_break_it()
	_test_tempering()
	_test_critical_hits()
	_test_a_crit_actually_doubles()
	_test_every_kind_of_damage_can_crit()
	_test_portraits_are_wired()
	_test_audio_files_are_present()
	_test_paragon_empowerment()
	_test_paragon_in_battle()
	_test_tyrant()
	_test_new_units_are_readable()
	_test_spire_never_raises_a_spire()
	_test_transcendence_rate()
	_test_abilities()
	_test_buff_data()
	_test_buff_pool()
	_test_buff_effects()
	_test_merge_procs()
	_test_new_units()
	_test_range_bands()
	_test_exclusive_buffs()
	_test_transcendence()
	_test_new_trio()
	_test_unit_codex()
	_test_force_bar()
	_test_summon_room()
	_test_spire_lifecycle()
	_test_apex_and_guard()
	_test_beam_wash()
	_test_maps()
	_test_terrain()
	_test_line_of_fire()
	_test_raised_units_instacast()
	_test_tier_colours()
	_test_the_compound()
	_test_the_labyrinth()
	_test_sudden_death()
	_test_live_counts()
	_test_this_pass()
	_test_mirror_matchup_is_fair()

	print("\n%d passed, %d failed" % [_passed, _failed])
	if _failed > 0:
		print("FAILURES PRESENT")
	quit(1 if _failed > 0 else 0)


func _check(label: String, condition: bool, detail := "") -> void:
	if condition:
		_passed += 1
		print("  ok    %s" % label)
	else:
		_failed += 1
		print("  FAIL  %s %s" % [label, detail])


func _section(name: String) -> void:
	print("\n%s" % name)


func _unit(idx: int, team: int) -> UnitInstance:
	return UnitInstance.create(_loadout.units[idx], team)


func _stock_board(counts: Array) -> BoardModel:
	var b := BoardModel.new()
	var base_cells := b.deploy_cells(BoardModel.TEAM_A)
	for team in 2:
		var i := 0
		for idx in counts.size():
			for n in counts[idx]:
				var c: Vector2i = base_cells[i]
				if team == BoardModel.TEAM_B:
					c = BoardModel.mirror(c)
				if not b.place(_unit(idx, team), c):
					push_error("test helper failed to place at %s for team %d" % [c, team])
				i += 1
	return b


func _test_board_geometry() -> void:
	_section("Board geometry")
	_check("6 wide, 11 tall", BoardModel.WIDTH == 6 and BoardModel.HEIGHT == 11)
	_check("neutral row is 5", BoardModel.NEUTRAL_ROW == 5)
	_check("neutral row is equidistant",
		BoardModel.NEUTRAL_ROW == BoardModel.HEIGHT - 1 - BoardModel.NEUTRAL_ROW)
	var b := BoardModel.new()
	_check("corners in bounds", b.in_bounds(Vector2i(0, 0)) and b.in_bounds(Vector2i(5, 10)))
	_check("off-board rejected",
		not b.in_bounds(Vector2i(6, 0)) and not b.in_bounds(Vector2i(0, 11))
		and not b.in_bounds(Vector2i(-1, 0)))


func _test_deploy_zones() -> void:
	_section("Deploy zones")
	var b := BoardModel.new()
	_check("A owns rows 0-4", b.can_deploy(BoardModel.TEAM_A, Vector2i(3, 4)))
	_check("B owns rows 6-10", b.can_deploy(BoardModel.TEAM_B, Vector2i(3, 6)))
	_check("A cannot deploy in B's half", not b.can_deploy(BoardModel.TEAM_A, Vector2i(3, 6)))
	_check("neutral row refused for A", not b.can_deploy(BoardModel.TEAM_A, Vector2i(3, 5)))
	_check("neutral row refused for B", not b.can_deploy(BoardModel.TEAM_B, Vector2i(3, 5)))
	_check("30 tiles per side",
		b.deploy_cells(BoardModel.TEAM_A).size() == 30
		and b.deploy_cells(BoardModel.TEAM_B).size() == 30,
		"got %d/%d" % [b.deploy_cells(0).size(), b.deploy_cells(1).size()])
	_check("60 deployable + 6 neutral = 66", 30 + 30 + BoardModel.WIDTH == 66)


func _test_mirror() -> void:
	_section("Mirror symmetry")
	var ok := true
	var centre_fixed := true
	for y in BoardModel.HEIGHT:
		for x in BoardModel.WIDTH:
			var c := Vector2i(x, y)
			if BoardModel.mirror(BoardModel.mirror(c)) != c:
				ok = false
			if y == BoardModel.NEUTRAL_ROW and BoardModel.mirror(c) != c:
				centre_fixed = false
	_check("mirror round-trips every cell", ok)
	_check("neutral row maps to itself", centre_fixed)
	_check("mirror swaps the deploy zones",
		BoardModel.mirror(Vector2i(2, 1)) == Vector2i(2, 9))


func _test_placement_and_movement() -> void:
	_section("Placement and movement")
	var b := BoardModel.new()
	var u := _unit(0, BoardModel.TEAM_A)
	_check("place succeeds in own zone", b.place(u, Vector2i(2, 2)))
	_check("cell recorded", u.cell == Vector2i(2, 2))
	_check("tile now occupied", not b.is_empty(Vector2i(2, 2)))
	_check("double-place refused", not b.place(_unit(1, BoardModel.TEAM_A), Vector2i(2, 2)))
	_check("place in neutral row refused", not b.place(_unit(1, BoardModel.TEAM_A), Vector2i(2, 5)))
	_check("move to empty tile", b.move_unit(u, Vector2i(3, 3)))
	_check("old tile freed", b.is_empty(Vector2i(2, 2)))

	var v := _unit(1, BoardModel.TEAM_A)
	b.place(v, Vector2i(1, 1))
	_check("move onto occupied refused", not b.move_unit(u, Vector2i(1, 1)))
	_check("swap works", b.swap_cells(Vector2i(3, 3), Vector2i(1, 1)))
	_check("swap moved both", u.cell == Vector2i(1, 1) and v.cell == Vector2i(3, 3))
	b.remove(u)
	_check("remove frees the tile", b.is_empty(Vector2i(1, 1)))


func _test_data_is_linked_not_embedded() -> void:
	_section("Data files link, not embed")

	var first: UnitData = _loadout.units[0]
	var flexible := LoadoutData.new()
	flexible.units = [_loadout.units[0], _loadout.units[1]] as Array[UnitData]
	_check("a roster of any size is valid", flexible.is_valid(),
		"pinning the count turns a one-character edit into an unexplained crash")
	var holed := LoadoutData.new()
	holed.units = [_loadout.units[0], null] as Array[UnitData]
	_check("a roster with a hole in it is not", not holed.is_valid())
	_check("an empty roster is not", LoadoutData.new().is_valid() == false)

	_check("a loadout unit knows its own file",
		not first.resource_path.is_empty(),
		"resource_path is empty, so it was embedded")

	var from_disk := load(first.resource_path) as UnitData
	_check("the loadout points at the file on disk, not a copy",
		from_disk == first,
		"%s loaded a different object" % first.resource_path)

	_check("next_tier links to its own file",
		first.next_tier != null and not first.next_tier.resource_path.is_empty(),
		"tier 2 is embedded inside tier 1")
	_check("the ability links to its own file",
		first.ability != null and not first.ability.resource_path.is_empty(),
		"the ability is embedded")

	var text := FileAccess.get_file_as_string("res://data/loadouts/starter.tres")
	_check("starter.tres embeds nothing", not text.contains("[sub_resource"),
		"it still carries inline copies")
	_check("starter.tres references the unit files", text.contains("data/units/"))


func _test_merging() -> void:
	_section("Merging")
	var b := BoardModel.new()
	var a := _unit(0, BoardModel.TEAM_A)
	var c := _unit(0, BoardModel.TEAM_A)
	b.place(a, Vector2i(0, 0))
	b.place(c, Vector2i(1, 0))
	_check("identical units can merge", b.can_merge(a, c))
	_check("different types cannot", not b.can_merge(a, _unit(1, BoardModel.TEAM_A)))
	_check("cross-team cannot", not b.can_merge(a, _unit(0, BoardModel.TEAM_B)))
	_check("a unit cannot merge with itself", not b.can_merge(a, a))

	var hp_before := a.stat(StatModifier.Stat.MAX_HP)
	var merged := b.merge(a, c, Vector2i(1, 0))
	_check("merge returned a unit", merged != null)
	_check("result is tier 2", merged != null and merged.data.tier == 2)
	_check("stats went up", merged != null and merged.stat(StatModifier.Stat.MAX_HP) > hp_before)
	_check("merge freed a tile", b.is_empty(Vector2i(0, 0)))
	_check("merged unit sits on the drop tile", b.unit_at(Vector2i(1, 0)) == merged)
	_check("board holds one unit", b.all_units().size() == 1)

	var chain := _loadout.units[0].chain_length()
	_check("the merge chain is 6 tiers deep", chain == 6, "it is %d" % chain)

	var top := _loadout.units[0]
	var tier := 1
	while top.next_tier != null:
		var prev := top
		top = top.next_tier
		tier += 1
		_check("tier %d doubles health" % tier,
			is_equal_approx(top.max_hp, prev.max_hp * 2.0),
			"%.0f -> %.0f" % [prev.max_hp, top.max_hp])
		_check("tier %d doubles damage" % tier,
			is_equal_approx(top.attack_damage, prev.attack_damage * 2.0),
			"%.1f -> %.1f" % [prev.attack_damage, top.attack_damage])
		_check("tier %d keeps its attack speed" % tier,
			is_equal_approx(top.attack_speed, prev.attack_speed))
		_check("tier %d keeps its reach" % tier, top.attack_range == prev.attack_range)

	_check("tier %d is the top" % tier, top.is_max_tier())
	_check("a tier 6 is 32x a tier 1",
		is_equal_approx(top.max_hp, _loadout.units[0].max_hp * 32.0),
		"%.0f vs %.0f" % [top.max_hp, _loadout.units[0].max_hp * 32.0])

	var cost := int(pow(2, chain - 1))
	var dealt := MatchState.UNITS_PER_DRAW * (MatchState.WINS_NEEDED * 2 - 1)
	_check("the top tier is reachable within a match", cost <= dealt,
		"tier %d costs %d units, a match deals at most %d" % [chain, cost, dealt])

	var b2 := BoardModel.new()
	var maxed := _unit(0, BoardModel.TEAM_A)
	maxed.data = top
	var maxed2 := _unit(0, BoardModel.TEAM_A)
	maxed2.data = top
	b2.place(maxed, Vector2i(0, 0))
	b2.place(maxed2, Vector2i(1, 0))
	_check("merging at max tier refused", not b2.can_merge(maxed, maxed2))


func _test_merge_lottery() -> void:
	_section("Merge lottery")
	var b := BoardModel.new()
	b.configure_merges(_loadout.units, 31337)

	var seen := {}
	var tiers_ok := true
	for i in 200:
		var a := _unit(0, BoardModel.TEAM_A)
		var c := _unit(0, BoardModel.TEAM_A)
		b.clear()
		b.place(a, Vector2i(0, 0))
		b.place(c, Vector2i(1, 0))
		var m := b.merge(a, c, Vector2i(1, 0))
		if m == null:
			continue
		seen[m.data.id] = true
		if m.data.tier != 2:
			tiers_ok = false

	_check("the roll always lands one tier up", tiers_ok)
	_check("two of the same unit can produce a different type", seen.size() > 1,
		"only ever rolled %s" % str(seen.keys()))
	_check("every result comes from the loadout", _all_in_loadout(seen.keys()),
		str(seen.keys()))

	var first := _roll_sequence(9001)
	var again := _roll_sequence(9001)
	var other := _roll_sequence(4242)
	_check("same seed rolls the same merges", first == again, "%s vs %s" % [first, again])
	_check("a different seed rolls differently", first != other)

	var plain := BoardModel.new()
	var p1 := _unit(0, BoardModel.TEAM_A)
	var p2 := _unit(0, BoardModel.TEAM_A)
	plain.place(p1, Vector2i(0, 0))
	plain.place(p2, Vector2i(1, 0))
	var pm := plain.merge(p1, p2, Vector2i(1, 0))
	_check("no pool means deterministic promotion",
		pm != null and pm.data.id == _loadout.units[0].id)


func _roll_sequence(seed_value: int) -> Array:
	var b := BoardModel.new()
	b.configure_merges(_loadout.units, seed_value)
	var out: Array = []
	for i in 12:
		var a := _unit(0, BoardModel.TEAM_A)
		var c := _unit(0, BoardModel.TEAM_A)
		b.clear()
		b.place(a, Vector2i(0, 0))
		b.place(c, Vector2i(1, 0))
		var m := b.merge(a, c, Vector2i(1, 0))
		out.append(String(m.data.id) if m != null else "null")
	return out


func _all_in_loadout(ids: Array) -> bool:
	var valid := {}
	for u in _loadout.units:
		valid[u.id] = true
	for id in ids:
		if not valid.has(id):
			return false
	return true


func _test_stat_modifiers() -> void:
	_section("Stat modifiers")
	var u := _unit(1, BoardModel.TEAM_A)
	var base := u.stat(StatModifier.Stat.ATTACK_DAMAGE)
	u.apply_modifiers([StatModifier.make(
		StatModifier.Stat.ATTACK_DAMAGE, StatModifier.Mode.FLAT, 5.0)])
	_check("flat modifier applies",
		is_equal_approx(u.stat(StatModifier.Stat.ATTACK_DAMAGE), base + 5.0))
	u.apply_modifiers([StatModifier.make(
		StatModifier.Stat.ATTACK_DAMAGE, StatModifier.Mode.PERCENT, 0.5)])
	_check("percent applies after flat",
		is_equal_approx(u.stat(StatModifier.Stat.ATTACK_DAMAGE), (base + 5.0) * 1.5))

	var hp_u := _unit(0, BoardModel.TEAM_A)
	hp_u.take_damage(20.0)
	var hp_mid := hp_u.current_hp
	hp_u.apply_modifiers([StatModifier.make(
		StatModifier.Stat.MAX_HP, StatModifier.Mode.FLAT, 40.0)])
	_check("max-HP buff heals by the same amount",
		is_equal_approx(hp_u.current_hp, hp_mid + 40.0))

	var fast := _unit(1, BoardModel.TEAM_A)
	fast.apply_modifiers([StatModifier.make(
		StatModifier.Stat.ATTACK_SPEED, StatModifier.Mode.PERCENT, 500.0)])
	_check("attack interval clamped above zero",
		fast.attack_interval() >= UnitInstance.MIN_TIME,
		"an unclamped +50000% buff would hang the sim")

	var slug := _unit(1, BoardModel.TEAM_A)
	slug.apply_modifiers([StatModifier.make(
		StatModifier.Stat.ATTACK_SPEED, StatModifier.Mode.PERCENT, -5.0)])
	_check("attack speed floors at zero, never negative",
		slug.stat(StatModifier.Stat.ATTACK_SPEED) >= 0.0
		and slug.attack_interval() > 0.0,
		"interval came back as %.3f" % slug.attack_interval())

	var doubled := _unit(1, BoardModel.TEAM_A)
	var before := doubled.attack_interval()
	doubled.apply_modifiers([StatModifier.make(
		StatModifier.Stat.ATTACK_SPEED, StatModifier.Mode.PERCENT, 1.0)])
	_check("+100% attack speed halves the interval",
		is_equal_approx(doubled.attack_interval(), before * 0.5),
		"%.3f -> %.3f" % [before, doubled.attack_interval()])


func _test_draw_determinism() -> void:
	_section("Draw")
	var r1 := RandomNumberGenerator.new()
	var r2 := RandomNumberGenerator.new()
	r1.seed = 12345
	r2.seed = 12345
	var a := _loadout.draw(r1, 40)
	var b := _loadout.draw(r2, 40)
	var same := true
	for i in a.size():
		if a[i] != b[i]:
			same = false
	_check("same seed gives the same draw", same)
	_check("draw returns real units", a.size() == 40 and a[0] != null)

	var r3 := RandomNumberGenerator.new()
	r3.seed = 999
	var c := _loadout.draw(r3, 40)
	var differs := false
	for i in a.size():
		if a[i] != c[i]:
			differs = true
	_check("a different seed gives a different draw", differs)


func _test_combat_runs() -> void:
	_section("Combat")
	var b := _stock_board([2, 2, 1, 1, 1])
	var sim := CombatSim.new()
	sim.setup(b, 42)
	var winner := sim.run()
	_check("battle terminates", sim.is_finished())
	_check("battle produced events", sim.events.size() > 10,
		"got %d" % sim.events.size())
	_check("battle took a sensible time",
		sim.duration() > 0.5 and sim.duration() < CombatSim.DEFAULT_TIMEOUT,
		"took %.1fs" % sim.duration())
	_check("someone won or it drew",
		winner in [BoardModel.TEAM_A, BoardModel.TEAM_B, CombatSim.RESULT_DRAW])
	var kinds := {}
	for e in sim.events:
		kinds[e.kind] = true
	_check("units moved", kinds.has("move"))
	_check("units attacked", kinds.has("attack"))
	_check("units died", kinds.has("death"))
	_check("log ends with an end event", sim.events[-1].kind == "end")

	var crossed := false
	for e in sim.events:
		if e.kind == "move" and e.to.y == BoardModel.NEUTRAL_ROW:
			crossed = true
	_check("units cross the neutral row", crossed)


func _test_combat_determinism() -> void:
	_section("Determinism")
	var results: Array[int] = []
	var logs: Array[int] = []
	var durations: Array[float] = []
	for i in 3:
		var b := _stock_board([2, 2, 1, 1, 1])
		var sim := CombatSim.new()
		sim.setup(b, 777)
		results.append(sim.run())
		logs.append(sim.events.size())
		durations.append(sim.duration())
	_check("same seed, same winner", results[0] == results[1] and results[1] == results[2])
	_check("same seed, same event count", logs[0] == logs[1] and logs[1] == logs[2],
		str(logs))
	_check("same seed, same duration",
		is_equal_approx(durations[0], durations[1]) and is_equal_approx(durations[1], durations[2]))


func _test_move_lockout() -> void:
	_section("Movement lockout")

	var slow := _run_crossing(4.0)
	var fast := _run_crossing(-0.75)

	_check("a slow walker dies crossing the board", slow == BoardModel.TEAM_A,
		"the archer should shoot it down during the committed moves")
	_check("a fast walker survives the crossing and wins", fast == BoardModel.TEAM_B,
		"move_time is the lever; if this doesn't flip, the lockout isn't biting")
	_check("move_time alone flips the outcome", slow != fast)


func _run_crossing(move_pct: float) -> int:
	# By name, not by slot. These were _unit(2) and _unit(1) until the roster was
	# reordered under them, at which point this test quietly became an Archer
	# walking at a Lancer and stopped measuring the movement lockout at all.
	var b := BoardModel.new()
	var archer := UnitInstance.create(_find("archer"), BoardModel.TEAM_A)
	var walker := UnitInstance.create(_find("lancer"), BoardModel.TEAM_B)
	walker.apply_modifiers([StatModifier.make(
		StatModifier.Stat.MOVE_TIME, StatModifier.Mode.PERCENT, move_pct)])
	var gap := archer.stat_int(StatModifier.Stat.ATTACK_RANGE)
	b.place(archer, Vector2i(2, BoardModel.NEUTRAL_ROW - 2))
	b.place(walker, Vector2i(2, BoardModel.NEUTRAL_ROW - 2 + gap))
	var sim := CombatSim.new()
	sim.setup(b, 5)
	# Crits off. This is a duel decided on the margin — the whole test is that
	# move_time alone flips it — so one lucky doubled arrow decides the outcome
	# instead of the lever being measured.
	sim.crit_chance = 0.0
	return sim.run()


func _test_movement_rules() -> void:
	_section("Movement and displacement")
	_check("diagonal movement is off", not BoardModel.DIAGONAL_MOVEMENT)
	_check("diagonal range is off", not BoardModel.DIAGONAL_RANGE)

	_check("orthogonal neighbour is distance 1",
		BoardModel.tile_distance(Vector2i(2, 2), Vector2i(2, 3)) == 1)
	_check("diagonal neighbour is distance 2",
		BoardModel.tile_distance(Vector2i(2, 2), Vector2i(3, 3)) == 2,
		"melee range 1 therefore cannot reach diagonally")
	_check("distance is Manhattan",
		BoardModel.tile_distance(Vector2i(0, 0), Vector2i(3, 4)) == 7)

	var b := BoardModel.new()
	var walker := _unit(1, BoardModel.TEAM_B)
	var foe := _unit(0, BoardModel.TEAM_A)
	b.place(walker, Vector2i(5, 10))
	b.place(foe, Vector2i(0, 0))
	var sim := CombatSim.new()
	sim.setup(b, 4)
	sim.run(40.0)
	var diagonal_steps := 0
	for e in sim.events:
		if e.kind != "move":
			continue
		var d: Vector2i = e.to - e.from
		if d.x != 0 and d.y != 0:
			diagonal_steps += 1
	_check("no unit ever steps diagonally", diagonal_steps == 0,
		"%d diagonal steps in the log" % diagonal_steps)

	_test_displacement()
	_test_corridor_traffic()


func _test_corridor_traffic() -> void:
	# A one-tile corridor is where movement rules stop being cosmetic. These two
	# cases are why a maze board used to run to the timeout with a dozen units
	# still standing on it.
	var corridor := MapData.new()
	corridor.id = &"test_corridor"
	corridor.display_name = "Corridor"
	corridor.width = 3
	corridor.height = 11
	corridor.has_neutral = true
	corridor.rows = PackedStringArray([
		"...", "...", "...",
		"#.#", "#.#", "#.#", "#.#", "#.#",
		"...", "...", "...",
	])
	_check("the corridor test map is legal", corridor.is_valid(),
		corridor.invalid_reason())
	BoardModel.use_map(corridor)

	# A rooted unit cannot move and cannot be talked round. Parked in the
	# corridor it used to seal its own side in for the rest of the round. The
	# Spire is the shipped example, but it spends itself on its summon and so
	# clears the way on its own — this is a bollard, to test the rule itself.
	var bollard := (_find("warden").duplicate() as UnitData)
	bollard.can_move = false
	bollard.ability = null
	var b := BoardModel.new()
	var spire := UnitInstance.create(bollard, BoardModel.TEAM_B)
	var walker := UnitInstance.create(_find("lancer"), BoardModel.TEAM_B)
	var foe := UnitInstance.create(_find("warden"), BoardModel.TEAM_A)
	var placed := b.place(spire, Vector2i(1, 6)) and b.place(walker, Vector2i(1, 7))
	b.place(foe, Vector2i(1, 1))
	_check("the corridor test units are all on the board", placed,
		"place() refused — the deploy halves moved")
	var sim := CombatSim.new()
	sim.setup(b, 11)
	sim.run(40.0)
	_check("a unit shoves past a rooted friend blocking the only way through",
		walker.cell.y < 6,
		"walker stuck at %s, bollard at %s" % [walker.cell, spire.cell])
	var shoved := 0
	for e in sim.events:
		if e.kind == "move" and e.uid == spire.uid:
			shoved += 1
	_check("the shove moves the rooted unit rather than deleting it",
		shoved > 0, "a unit that cannot walk never appears in a move event")
	_check("and the log carries both halves, so the view can animate it",
		shoved > 0 and sim.events.any(func(e: Dictionary) -> bool:
			return e.kind == "move" and e.uid == walker.uid))
	_check("a corridor fight with a rooted cork in it still ends",
		sim.is_finished(), "ran %.1fs without finishing" % sim.duration())

	# A friend that can walk will clear the way itself, so the one behind should
	# queue rather than wander off down the corridor wall.
	var b2 := BoardModel.new()
	var front := UnitInstance.create(_find("warden"), BoardModel.TEAM_B)
	var back := UnitInstance.create(_find("warden"), BoardModel.TEAM_B)
	var mark := UnitInstance.create(_find("warden"), BoardModel.TEAM_A)
	b2.place(front, Vector2i(1, 6))
	b2.place(back, Vector2i(1, 7))
	b2.place(mark, Vector2i(1, 1))
	var sim2 := CombatSim.new()
	sim2.setup(b2, 12)
	sim2.step()
	sim2.step()
	_check("a unit does not swap places with a friend that can walk",
		back.cell.y >= front.cell.y,
		"back at %s overtook front at %s" % [back.cell, front.cell])

	BoardModel.reset_map()


func _test_displacement() -> void:
	var b := BoardModel.new()
	var u := _unit(0, BoardModel.TEAM_B)
	b.place(u, Vector2i(3, 8))

	_check("a push moves the requested distance",
		b.push(u, Vector2i(0, 1), 2) == 2 and u.cell == Vector2i(3, 10),
		"ended at %s" % u.cell)
	_check("a push stops at the board edge",
		b.push(u, Vector2i(0, 1), 3) == 0 and u.cell == Vector2i(3, 10))

	var blocker := _unit(0, BoardModel.TEAM_B)
	b.place(blocker, Vector2i(3, 9))
	_check("a push stops at an occupied tile",
		b.push(u, Vector2i(0, -1), 3) == 0 and u.cell == Vector2i(3, 10),
		"ended at %s" % u.cell)

	_check("a push ignores deploy zones",
		b.push(u, Vector2i(-1, 0), 3) == 3 and u.cell == Vector2i(0, 10))
	_check("teleport refuses an occupied tile", not b.teleport(u, Vector2i(3, 9)))
	_check("teleport crosses the board freely", b.teleport(u, Vector2i(1, 2)))

	var b2 := BoardModel.new()
	var a := _unit(0, BoardModel.TEAM_A)
	var d := _unit(0, BoardModel.TEAM_B)
	b2.place(a, Vector2i(2, 2))
	b2.place(d, Vector2i(2, 8))
	var sim2 := CombatSim.new()
	sim2.setup(b2, 1)
	sim2.step()
	var moved := sim2.displace(d, Vector2i(0, 1), 2)
	var found := false
	for e in sim2.events:
		if e.kind == "displace" and e.uid == d.uid:
			found = true
	_check("displacement emits an event for playback", moved == 2 and found)


func _test_abilities() -> void:
	_section("Abilities")

	# From the roster, not the starter loadout. The starter is the first five off
	# UNIT_TABLE, so keying this off it means inserting a unit anywhere near the
	# front silently drops another one out and this whole section starts testing
	# a KeyError.
	var by_id := {}
	for u in _roster().units:
		by_id[String(u.id)] = u
	_check("all five units have an ability",
		_all_have_abilities(), "one or more ability slots are empty")
	_check("mana bar is the same for everyone", UnitInstance.MANA_MAX == 100.0)

	_test_shield(by_id)
	_test_haste(by_id)
	_test_dot(by_id)
	_test_burst(by_id)
	_test_pierce(by_id)


func _all_have_abilities() -> bool:
	for u in _loadout.units:
		if u.ability == null:
			return false
	return true


func _make(data: UnitData, team: int) -> UnitInstance:
	return UnitInstance.create(data, team)


func _test_shield(by_id: Dictionary) -> void:
	var warden: UnitData = by_id["warden"]
	var b := BoardModel.new()
	var w := _make(warden, BoardModel.TEAM_A)
	var foe := _make(by_id["lancer"], BoardModel.TEAM_B)
	b.place(w, Vector2i(2, 4))
	b.place(foe, Vector2i(2, 6))
	var sim := CombatSim.new()
	sim.setup(b, 11)
	_check("the Warden's shield is up before the first tick, not after one",
		w.shield > 0.0, "shield is %.0f straight out of setup" % w.shield)
	for i in 6:
		sim.step()
	_check("Warden opens the battle with a shield up", w.shield > 0.0,
		"shield is %.0f" % w.shield)

	var s2 := _make(warden, BoardModel.TEAM_A)
	s2.add_shield(50.0, 70.0)
	var hp_before := s2.current_hp
	s2.take_damage(30.0)
	_check("damage hits the shield before health",
		is_equal_approx(s2.current_hp, hp_before) and is_equal_approx(s2.shield, 20.0),
		"hp %.0f shield %.0f" % [s2.current_hp, s2.shield])
	s2.take_damage(40.0)
	_check("overflow carries into health",
		is_zero_approx(s2.shield) and is_equal_approx(s2.current_hp, hp_before - 20.0),
		"hp %.0f shield %.0f" % [s2.current_hp, s2.shield])
	s2.heal_to_full()
	_check("healing does not restore the shield", is_zero_approx(s2.shield))

	s2.add_shield(70.0, 70.0)
	s2.add_shield(70.0, 70.0)
	_check("shield tops up to the cap, never past it", is_equal_approx(s2.shield, 70.0),
		"shield is %.0f" % s2.shield)


func _test_haste(by_id: Dictionary) -> void:
	var archer: UnitData = by_id["archer"]
	var a := _make(archer, BoardModel.TEAM_A)
	var base := a.attack_interval()
	var ab: AbilityData = archer.ability

	for i in 3:
		a.haste_stacks += 1
		a.add_battle_modifier(StatModifier.make(
			StatModifier.Stat.ATTACK_SPEED, StatModifier.Mode.PERCENT, ab.haste_percent))
	var hasted := a.attack_interval()
	_check("haste stacks shorten the interval between attacks", hasted < base,
		"%.3f -> %.3f" % [base, hasted])

	a.reset_for_battle()
	_check("haste does not survive into the next round",
		is_equal_approx(a.attack_interval(), base) and a.haste_stacks == 0,
		"interval came back as %.3f" % a.attack_interval())

	_check("Archer casts during a battle", _ability_fires(by_id, "archer", "warden"))


func _test_dot(by_id: Dictionary) -> void:
	var victim := _make(by_id["lancer"], BoardModel.TEAM_B)
	var hp0 := victim.current_hp
	victim.apply_dot(10.0, 3, 0.5, 999)
	_check("a dot is recorded", victim.dots.size() == 1)

	var b := BoardModel.new()
	b.force_place(victim, Vector2i(2, 10))
	b.force_place(_make(by_id["warden"], BoardModel.TEAM_A), Vector2i(5, 0))
	var sim := CombatSim.new()
	sim.setup(b, 3)
	# Crits off: this measures an exact damage total, and a 5% doubling on any
	# one tick makes the figure a lottery. The crit itself is tested separately.
	sim.crit_chance = 0.0
	victim.apply_dot(10.0, 3, 0.5, 999)
	for i in 20:
		sim.step()
	_check("the dot ticked for its full duration",
		is_equal_approx(victim.current_hp, hp0 - 30.0),
		"lost %.0f, expected 30" % (hp0 - victim.current_hp))
	_check("the dot expires", victim.dots.is_empty())
	_check("Vexer casts during a battle", _ability_fires(by_id, "vexer", "warden"))


func _test_burst(by_id: Dictionary) -> void:
	var pyre: UnitData = by_id["pyre"]
	var ab: AbilityData = pyre.ability
	_check("burst hurts the main target far more than its neighbours",
		ab.burst_damage > ab.splash_damage * 3.0,
		"%.0f vs %.0f" % [ab.burst_damage, ab.splash_damage])
	_check("Pyre casts during a battle", _ability_fires(by_id, "pyre", "warden"))


func _test_pierce(by_id: Dictionary) -> void:
	var lancer: UnitData = by_id["lancer"]
	_check("Lancer's passive pierces two", lancer.pierce_targets == 2)
	_check("everyone else pierces one",
		by_id["archer"].pierce_targets == 1 and by_id["warden"].pierce_targets == 1)
	_check("the ability pierces more than the passive",
		lancer.ability.pierce_targets > lancer.pierce_targets)

	var b := BoardModel.new()
	var l := _make(lancer, BoardModel.TEAM_A)
	var front := _make(by_id["warden"], BoardModel.TEAM_B)
	var back := _make(by_id["warden"], BoardModel.TEAM_B)
	b.place(l, Vector2i(2, 4))
	b.force_place(front, Vector2i(2, 5))
	b.force_place(back, Vector2i(2, 6))
	var sim := CombatSim.new()
	sim.setup(b, 7)
	var back_start := back.effective_hp()
	for i in 12:
		sim.step()
	_check("a passive swing reaches the unit behind",
		back.effective_hp() < back_start,
		"the back rank took no damage (shield included)")
	_check("Lancer casts during a battle", _ability_fires(by_id, "lancer", "warden"))


func _ability_fires(by_id: Dictionary, caster: String, foe: String) -> bool:
	var b := BoardModel.new()
	var c := _make(by_id[caster], BoardModel.TEAM_A)
	c.apply_modifiers([StatModifier.make(
		StatModifier.Stat.MAX_HP, StatModifier.Mode.FLAT, 100000.0)])
	c.heal_to_full()
	b.place(c, Vector2i(2, 4))
	for i in 3:
		var f := _make(by_id[foe], BoardModel.TEAM_B)
		b.force_place(f, Vector2i(1 + i, 6))
	var sim := CombatSim.new()
	sim.setup(b, 23)
	sim.run(40.0)
	for e in sim.events:
		if e.kind == "ability" and e.uid == c.uid:
			return true
	return false


func _test_mirror_matchup_is_fair() -> void:
	_section("Mirror matchup fairness")
	var wins := [0, 0, 0]
	var runs := 120
	for i in runs:
		var b := _stock_board([2, 2, 1, 1, 1])
		var sim := CombatSim.new()
		sim.setup(b, i * 31 + 7)
		var w := sim.run()
		wins[w if w >= 0 else 2] += 1
	var decisive: int = wins[0] + wins[1]
	var rate := float(wins[0]) / maxf(float(decisive), 1.0)
	print("    A %d / B %d / draw %d  -> A wins %.0f%%" % [wins[0], wins[1], wins[2], rate * 100.0])
	_check("mirror matchup is near even", decisive > 0 and absf(rate - 0.5) < 0.22,
		"a real lean here means a bug, not balance")


func _pool() -> BuffPool:
	var p := BuffPool.new()
	p.load_all()
	return p


func _test_buff_data() -> void:
	_section("Buff data")

	var pool := _pool()
	_check("every buff on disk loaded", pool.buffs.size() == 43,
		"loaded %d, expected 43" % pool.buffs.size())

	var ids := {}
	var missing: PackedStringArray = []
	for b in pool.buffs:
		ids[String(b.id)] = b
	for want in ["mending_wind", "rupture", "windfall", "promotion", "full_muster",
			"war_drums", "ironwall", "marksmanship", "vigor", "conflagration", "swarm",
			"shadowcraft", "fanfare", "undying", "grace", "covenant",
			"far_sight", "levy", "alchemy", "conscription", "reckless",
			"bloodletting", "conclave", "oblation"]:
		if not ids.has(want):
			missing.append(want)
	_check("all twenty-four buffs are present", missing.is_empty(),
		"missing %s" % ", ".join(missing))
	if not missing.is_empty():
		return

	var drums: BuffData = ids["war_drums"]
	_check("bronze/silver/gold escalate",
		drums.magnitude(BuffData.Rarity.BRONZE).x < drums.magnitude(BuffData.Rarity.SILVER).x
		and drums.magnitude(BuffData.Rarity.SILVER).x < drums.magnitude(BuffData.Rarity.GOLD).x)
	var drum_b := drums.magnitude(BuffData.Rarity.BRONZE).x
	_check("War Drums starts at +20% attack speed",
		is_equal_approx(drum_b, 0.20), "%.2f" % drum_b)
	_check("and doubles to silver, triples to gold",
		is_equal_approx(drums.magnitude(BuffData.Rarity.SILVER).x, drum_b * 2.0)
		and is_equal_approx(drums.magnitude(BuffData.Rarity.GOLD).x, drum_b * 3.0),
		"%.2f / %.2f / %.2f" % [drum_b,
			drums.magnitude(BuffData.Rarity.SILVER).x,
			drums.magnitude(BuffData.Rarity.GOLD).x])
	_check("global buffs have no unit filter", drums.is_global())

	var marks: BuffData = ids["marksmanship"]
	_check("Marksmanship only touches Archers", not marks.is_global()
		and marks.unit_id == &"archer")
	var marks_g := marks.magnitude(BuffData.Rarity.GOLD)
	_check("Marksmanship carries two separate numbers",
		marks.uses_second_stat and marks_g.x > 0.0 and marks_g.y > 0.0
		and not is_equal_approx(marks_g.x, marks_g.y),
		"gold is %s" % marks_g)

	var mods := marks.modifiers_for(BuffData.Rarity.SILVER)
	_check("a two-stat buff makes two modifiers", mods.size() == 2,
		"made %d" % mods.size())
	_check("both modifiers are percentages",
		mods.size() == 2
		and mods[0].mode == StatModifier.Mode.PERCENT
		and mods[1].mode == StatModifier.Mode.PERCENT)

	var empty_desc := false
	for b in pool.buffs:
		for r in [BuffData.Rarity.BRONZE, BuffData.Rarity.SILVER, BuffData.Rarity.GOLD]:
			if String(b.describe(r)).is_empty():
				empty_desc = true
	_check("every buff describes itself at every rarity", not empty_desc)

	var non_stat := 0
	for b in pool.buffs:
		if b.kind != BuffData.Kind.STAT:
			non_stat += 1
	_check("eleven buffs do something other than bump a stat", non_stat == 11,
		"found %d" % non_stat)


func _test_buff_pool() -> void:
	_section("Buff picking")

	var pool := _pool()
	var rng := RandomNumberGenerator.new()
	rng.seed = 12345
	var offer := pool.offer(rng, 3)
	_check("an offer is three buffs", offer.size() == 3, "got %d" % offer.size())

	var seen := {}
	for b in offer:
		seen[String(b.id)] = true
	_check("the three options are distinct", seen.size() == 3)

	rng.seed = 12345
	var again := pool.offer(rng, 3)
	var same := again.size() == offer.size()
	for i in offer.size():
		if i < again.size() and again[i].id != offer[i].id:
			same = false
	_check("the same seed offers the same three", same)

	var excluded := pool.offer(rng, 3, [offer[0].id, offer[1].id, offer[2].id])
	var overlap := false
	for b in excluded:
		if seen.has(String(b.id)):
			overlap = true
	_check("buffs already taken are not offered again", not overlap)

	_test_rarity_odds()


func _test_rarity_odds() -> void:
	_section("Buff rarity roll")

	_check("there is a row of odds for every buff pick in a match",
		RarityTable.rows() == 4, "%d rows" % RarityTable.rows())

	var sums_to_one := true
	for pick in range(1, RarityTable.rows() + 1):
		var total := 0.0
		for r in [BuffData.Rarity.BRONZE, BuffData.Rarity.SILVER, BuffData.Rarity.GOLD]:
			total += RarityTable.chance(r, pick)
		if not is_equal_approx(total, 1.0):
			sums_to_one = false
	_check("each pick's odds add up to 100%", sums_to_one)

	_check("gold can turn up on the very first pick",
		RarityTable.chance(BuffData.Rarity.GOLD, 1) > 0.0,
		"gold is %.0f%% on pick 1" % (RarityTable.chance(BuffData.Rarity.GOLD, 1) * 100.0))
	_check("bronze is still possible on the last pick",
		RarityTable.chance(BuffData.Rarity.BRONZE, 4) > 0.0)

	var gold_climbs := true
	var bronze_falls := true
	for pick in range(2, RarityTable.rows() + 1):
		if RarityTable.chance(BuffData.Rarity.GOLD, pick) <= RarityTable.chance(
				BuffData.Rarity.GOLD, pick - 1):
			gold_climbs = false
		if RarityTable.chance(BuffData.Rarity.BRONZE, pick) >= RarityTable.chance(
				BuffData.Rarity.BRONZE, pick - 1):
			bronze_falls = false
	_check("gold gets likelier every pick", gold_climbs)
	_check("bronze gets rarer every pick", bronze_falls)

	_check("picks past the table reuse the last row",
		RarityTable.odds_for(9) == RarityTable.odds_for(4)
		and RarityTable.odds_for(0) == RarityTable.odds_for(1))

	var rng := RandomNumberGenerator.new()
	rng.seed = 4242
	var first: Array[int] = []
	for i in 24:
		first.append(int(RarityTable.roll(rng, 1)))
	rng.seed = 4242
	var again: Array[int] = []
	for i in 24:
		again.append(int(RarityTable.roll(rng, 1)))
	_check("the same seed rolls the same rarities", first == again)

	_test_roll_matches_odds(1)
	_test_roll_matches_odds(4)


func _test_roll_matches_odds(pick: int) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 99 + pick
	var counts := [0, 0, 0]
	var runs := 12000
	for i in runs:
		counts[int(RarityTable.roll(rng, pick))] += 1

	var worst := 0.0
	for r in 3:
		var seen := float(counts[r]) / float(runs)
		worst = maxf(worst, absf(seen - RarityTable.chance(r as BuffData.Rarity, pick)))
	_check("pick %d rolls match its stated odds" % pick, worst < 0.02,
		"off by %.1f points — %s" % [worst * 100.0, str(counts)])
	_check("pick %d can roll all three rarities" % pick,
		counts[0] > 0 and counts[1] > 0 and counts[2] > 0, str(counts))


func _by_unit_id(id: String) -> UnitData:
	for u in _loadout.units:
		if String(u.id) == id:
			return u
	return null


func _test_buff_effects() -> void:
	_section("Buff effects")

	var pool := _pool()
	var tb := TeamBuffs.new()
	tb.add(pool.by_id(&"war_drums"), BuffData.Rarity.GOLD)

	var archer := UnitInstance.create(_by_unit_id("archer"), BoardModel.TEAM_A)
	var base_interval := archer.attack_interval()
	tb.apply_to(archer)
	var speed_up: float = pool.by_id(&"war_drums").magnitude(
		BuffData.Rarity.GOLD).x
	_check("attack speed divides the interval rather than subtracting from it",
		is_equal_approx(archer.attack_interval(), base_interval / (1.0 + speed_up)),
		"%.3f -> %.3f, expected %.3f" % [
			base_interval, archer.attack_interval(),
			base_interval / (1.0 + speed_up)])

	var warden := UnitInstance.create(_by_unit_id("warden"), BoardModel.TEAM_A)
	var wall := TeamBuffs.new()
	wall.add(pool.by_id(&"ironwall"), BuffData.Rarity.SILVER)
	var hp_before := warden.stat(StatModifier.Stat.MAX_HP)
	wall.apply_to(warden)
	_check("Ironwall gives Warden two and a half times health at silver",
		is_equal_approx(warden.stat(StatModifier.Stat.MAX_HP), hp_before * 2.5),
		"%.0f -> %.0f" % [hp_before, warden.stat(StatModifier.Stat.MAX_HP)])
	_check("a max-health buff also fills the new health",
		is_equal_approx(warden.current_hp, warden.stat(StatModifier.Stat.MAX_HP)))

	var other := UnitInstance.create(_by_unit_id("archer"), BoardModel.TEAM_A)
	var other_hp := other.stat(StatModifier.Stat.MAX_HP)
	wall.apply_to(other)
	_check("a Warden buff does nothing for an Archer",
		is_equal_approx(other.stat(StatModifier.Stat.MAX_HP), other_hp))

	var regen := TeamBuffs.new()
	regen.add(pool.by_id(&"mending_wind"), BuffData.Rarity.GOLD)
	_check("regen reads its gold magnitude back",
		is_equal_approx(regen.regen_fraction(),
			pool.by_id(&"mending_wind").magnitude(BuffData.Rarity.GOLD).x),
		"%.3f" % regen.regen_fraction())
	_check("a stat holder reports no regen",
		is_equal_approx(tb.regen_fraction(), 0.0))

	var stacked := TeamBuffs.new()
	stacked.add(pool.by_id(&"mending_wind"), BuffData.Rarity.BRONZE)
	stacked.add(pool.by_id(&"mending_wind"), BuffData.Rarity.SILVER)
	# Read off the buff rather than typed in: a test that restates a tuning value
	# only tests that nobody retuned it.
	var want_stack: float = pool.by_id(&"mending_wind").magnitude(
			BuffData.Rarity.BRONZE).x \
		+ pool.by_id(&"mending_wind").magnitude(BuffData.Rarity.SILVER).x
	_check("two copies of a regen buff add up",
		is_equal_approx(stacked.regen_fraction(), want_stack),
		"%.3f, wanted %.3f" % [stacked.regen_fraction(), want_stack])

	var muster := TeamBuffs.new()
	muster.add(pool.by_id(&"full_muster"), BuffData.Rarity.BRONZE)
	_check("Full Muster is held back as a conditional",
		muster.full_roster_modifiers().size() == 2
		and is_equal_approx(muster.regen_fraction(), 0.0))
	var untouched := UnitInstance.create(_by_unit_id("lancer"), BoardModel.TEAM_A)
	var lancer_hp := untouched.stat(StatModifier.Stat.MAX_HP)
	muster.apply_to(untouched)
	_check("Full Muster does not apply outside of battle",
		is_equal_approx(untouched.stat(StatModifier.Stat.MAX_HP), lancer_hp))

	_test_idle_buffs(pool)
	_test_new_unit_buffs(pool)
	_test_buff_pool_gate(pool)
	_test_regen_in_battle(pool)


func _test_new_unit_buffs(pool: BuffPool) -> void:
	var table := {
		shadowcraft = {
			unit = "assassin", a = StatModifier.Stat.ATTACK_SPEED,
			b = StatModifier.Stat.ATTACK_DAMAGE, bronze = Vector2(0.10, 0.15),
		},
		fanfare = {
			unit = "herald", a = StatModifier.Stat.ATTACK_DAMAGE,
			b = StatModifier.Stat.MAX_HP, bronze = Vector2(0.20, 0.25),
		},
		undying = {
			unit = "revenant", a = StatModifier.Stat.MAX_HP,
			b = StatModifier.Stat.ATTACK_DAMAGE, bronze = Vector2(0.50, 0.50),
		},
		grace = {
			unit = "seraph", a = StatModifier.Stat.MAX_HP,
			b = StatModifier.Stat.HEAL_POWER, bronze = Vector2(0.35, 0.10),
		},
		covenant = {
			unit = "conjurer", a = StatModifier.Stat.MAX_HP,
			b = StatModifier.Stat.ATTACK_DAMAGE, bronze = Vector2(0.50, 0.30),
		},
	}

	var wrong: PackedStringArray = []
	for id in table:
		var want: Dictionary = table[id]
		var buff := pool.by_id(StringName(id))
		if buff == null:
			wrong.append("%s missing" % id)
			continue
		if String(buff.unit_id) != want.unit:
			wrong.append("%s names %s" % [id, buff.unit_id])
		if buff.stat_a != want.a or buff.stat_b != want.b or not buff.uses_second_stat:
			wrong.append("%s buffs the wrong pair" % id)
		if not buff.magnitude(BuffData.Rarity.BRONZE).is_equal_approx(want.bronze):
			wrong.append("%s bronze is %s, wanted %s" % [
				id, buff.magnitude(BuffData.Rarity.BRONZE), want.bronze])
	_check("each new unit buff hits the right two stats at the right numbers",
		wrong.is_empty(), "; ".join(wrong))

	var doubling: PackedStringArray = []
	for id in table:
		var buff := pool.by_id(StringName(id))
		if buff == null:
			continue
		var b := buff.magnitude(BuffData.Rarity.BRONZE)
		if not buff.magnitude(BuffData.Rarity.SILVER).is_equal_approx(b * 2.0):
			doubling.append("%s silver" % id)
		if not buff.magnitude(BuffData.Rarity.GOLD).is_equal_approx(b * 3.0):
			doubling.append("%s gold" % id)
	# One, two, three times bronze — not one, two, four. Gold at 4x made the last
	# pick of a match worth more than the three before it put together, and this
	# is the only place that law is written down.
	_check("they run one, two, three times bronze",
		doubling.is_empty(), "; ".join(doubling))

	var covenant := pool.by_id(&"covenant")
	var conjurer := UnitInstance.create(_find("conjurer"), BoardModel.TEAM_B)
	var wisp := UnitInstance.create(
		load("res://data/units/wisp_t1.tres") as UnitData, BoardModel.TEAM_B)
	var stranger := UnitInstance.create(_find("archer"), BoardModel.TEAM_B)
	_check("the Conjurer buff covers its Wisps as well as the Conjurer",
		covenant.applies_to(conjurer) and covenant.applies_to(wisp)
		and not covenant.applies_to(stranger))

	var held := TeamBuffs.new()
	held.add(covenant, BuffData.Rarity.GOLD)
	var wisp_hp := wisp.stat(StatModifier.Stat.MAX_HP)
	var wisp_dmg := wisp.stat(StatModifier.Stat.ATTACK_DAMAGE)
	held.apply_to(wisp)
	var cov := covenant.magnitude(BuffData.Rarity.GOLD)
	_check("a Wisp really inherits the Conjurer's buff",
		is_equal_approx(wisp.stat(StatModifier.Stat.MAX_HP),
			wisp_hp * (1.0 + cov.x))
		and is_equal_approx(wisp.stat(StatModifier.Stat.ATTACK_DAMAGE),
			wisp_dmg * (1.0 + cov.y)),
		"%.0f hp, %.1f damage" % [wisp.stat(StatModifier.Stat.MAX_HP),
			wisp.stat(StatModifier.Stat.ATTACK_DAMAGE)])
	_check("Wisps are melee, so the attack half of that buff is worth having",
		wisp.data.attack_range == 1
		and wisp.data.attack_type == UnitData.AttackType.MELEE)

	_check("a Covenant is live while only Wisps are left standing",
		TeamBuffs.is_live(covenant, {&"wisp": true})
		and TeamBuffs.is_live(covenant, {&"conjurer": true})
		and not TeamBuffs.is_live(covenant, {&"archer": true}))

	_test_healing_buff(pool)


func _test_healing_buff(pool: BuffPool) -> void:
	var seraph := _find("seraph")
	var board := BoardModel.new()
	var healer := UnitInstance.create(seraph, BoardModel.TEAM_B)
	var hurt := UnitInstance.create(_find("lancer"), BoardModel.TEAM_B)
	board.place(healer, Vector2i(2, 8))
	board.place(hurt, Vector2i(3, 8))
	board.place(UnitInstance.create(_find("warden"), BoardModel.TEAM_A), Vector2i(2, 2))

	_check("healing power starts at exactly 1x",
		is_equal_approx(healer.stat(StatModifier.Stat.HEAL_POWER), 1.0))

	var grace := TeamBuffs.new()
	grace.add(pool.by_id(&"grace"), BuffData.Rarity.GOLD)
	grace.apply_to(healer)
	var grace_y: float = pool.by_id(&"grace").magnitude(BuffData.Rarity.GOLD).y
	_check("Grace lifts healing power, not raw health alone",
		is_equal_approx(healer.stat(StatModifier.Stat.HEAL_POWER), 1.0 + grace_y),
		"heal power is %.2f" % healer.stat(StatModifier.Stat.HEAL_POWER))

	var sim := CombatSim.new()
	sim.setup(board, 33)
	hurt.current_hp = 1.0
	healer.mana = UnitInstance.MANA_MAX
	for i in 20:
		sim.step()

	var healed := 0.0
	for e in sim.events:
		if e.kind == "heal" and e.uid == hurt.uid:
			healed = float(e.amount)
	var plain: float = hurt.stat(StatModifier.Stat.MAX_HP) * seraph.ability.heal_percent
	_check("the bigger heal actually lands in battle",
		healed > plain * 1.3,
		"healed %.0f, an unbuffed cast would be %.0f" % [healed, plain])


func _test_buff_pool_gate(pool: BuffPool) -> void:
	var five := {&"warden": true, &"lancer": true, &"archer": true,
		&"vexer": true, &"pyre": true}
	var offered := pool.pool_for(five)
	var ids: Array[StringName] = []
	for b in offered:
		ids.append(b.id)
	_check("a classic loadout never sees the new units' buffs",
		not ids.has(&"shadowcraft") and not ids.has(&"undying")
		and not ids.has(&"covenant"),
		"pool was %s" % str(ids))
	_check("it still sees its own unit buffs",
		ids.has(&"ironwall") and ids.has(&"marksmanship") and ids.has(&"swarm"))
	_check("global buffs are always in the pool",
		ids.has(&"war_drums") and ids.has(&"mending_wind") and ids.has(&"rupture"))

	var newcomers := {&"assassin": true, &"herald": true, &"revenant": true,
		&"seraph": true, &"conjurer": true}
	var fresh: Array[StringName] = []
	for b in pool.pool_for(newcomers):
		fresh.append(b.id)
	_check("bringing the new units shuffles their buffs in",
		fresh.has(&"shadowcraft") and fresh.has(&"fanfare")
		and fresh.has(&"undying") and fresh.has(&"grace") and fresh.has(&"covenant"))
	_check("and drops the buffs for units you left at home",
		not fresh.has(&"ironwall") and not fresh.has(&"marksmanship"))

	var rng := RandomNumberGenerator.new()
	rng.seed = 808
	var leaked: PackedStringArray = []
	for i in 60:
		for b in pool.offer(rng, 3, [], five):
			if not b.is_global() and not five.has(b.unit_id):
				leaked.append(String(b.id))
	_check("sixty draws never leak a buff for a unit you did not bring",
		leaked.is_empty(), "; ".join(leaked))

	var everything := 0
	for b in pool.buffs:
		if b.available_at(BuffData.Rarity.GOLD):
			everything += 1
	_check("an unknown loadout falls back to every buff that rarity allows",
		pool.pool_for({}).size() == everything)


func _test_idle_buffs(pool: BuffPool) -> void:
	var all_five := {}
	for u in _loadout.units:
		all_five[u.id] = true
	var no_warden := all_five.duplicate()
	no_warden.erase(&"warden")
	var lone_archer := {&"archer": true}
	var empty := {}

	var ironwall := pool.by_id(&"ironwall")
	_check("a Warden buff is live while a Warden is out",
		TeamBuffs.is_live(ironwall, all_five))
	_check("a Warden buff greys out once the Wardens are gone",
		not TeamBuffs.is_live(ironwall, no_warden))
	_check("the greyed-out reason names the missing unit",
		TeamBuffs.why_idle(ironwall, no_warden).contains("Warden"),
		TeamBuffs.why_idle(ironwall, no_warden))

	var muster := pool.by_id(&"full_muster")
	_check("Full Muster is live with all five types out",
		TeamBuffs.is_live(muster, all_five))
	_check("Full Muster greys out one type short",
		not TeamBuffs.is_live(muster, no_warden))
	_check("its reason explains the roster requirement, not a unit",
		TeamBuffs.why_idle(muster, no_warden).contains("all 5"),
		TeamBuffs.why_idle(muster, no_warden))

	var drums := pool.by_id(&"war_drums")
	var regen := pool.by_id(&"mending_wind")
	var windfall := pool.by_id(&"windfall")
	_check("a global buff stays live with a single unit out",
		TeamBuffs.is_live(drums, lone_archer)
		and TeamBuffs.is_live(regen, lone_archer)
		and TeamBuffs.is_live(windfall, lone_archer))
	_check("a global buff has no idle reason to give",
		TeamBuffs.why_idle(drums, lone_archer).is_empty())

	_check("nothing is live on an empty board",
		not TeamBuffs.is_live(drums, empty)
		and not TeamBuffs.is_live(ironwall, empty)
		and not TeamBuffs.is_live(muster, empty))
	_check("an empty board says so",
		TeamBuffs.why_idle(drums, empty).contains("no units"),
		TeamBuffs.why_idle(drums, empty))

	var held := TeamBuffs.new()
	held.add(ironwall, BuffData.Rarity.GOLD)
	held.add(drums, BuffData.Rarity.BRONZE)
	held.add(muster, BuffData.Rarity.SILVER)
	var want_partial: Array[bool] = [false, true, false]
	var want_all: Array[bool] = [true, true, true]
	_check("a bar gets one live/idle flag per buff held",
		held.active_flags(no_warden) == want_partial,
		str(held.active_flags(no_warden)))
	_check("the same buffs read live with the full roster out",
		held.active_flags(all_five) == want_all)

	_check("the sim and the bar agree on what a full roster is",
		TeamBuffs.FULL_ROSTER_TYPES == _loadout.units.size(),
		"%d types wanted, loadout has %d" % [
			TeamBuffs.FULL_ROSTER_TYPES, _loadout.units.size()])

	_check("greying out changes the colour without losing it",
		BuffBar.grey_out(Color(0.92, 0.76, 0.32)).a < 1.0
		and BuffBar.grey_out(Color(0.92, 0.76, 0.32)).s
			< Color(0.92, 0.76, 0.32).s)
	_test_rupture_in_battle(pool)
	_test_full_muster_in_battle(pool)


func _test_regen_in_battle(pool: BuffPool) -> void:
	var b := BoardModel.new()
	var hurt := _unit(0, BoardModel.TEAM_A)
	b.place(hurt, b.deploy_cells(BoardModel.TEAM_A)[0])
	b.place(_unit(0, BoardModel.TEAM_B),
		BoardModel.mirror(b.deploy_cells(BoardModel.TEAM_A)[0]))

	var tb := TeamBuffs.new()
	tb.add(pool.by_id(&"mending_wind"), BuffData.Rarity.GOLD)

	var sim := CombatSim.new()
	sim.team_buffs = {BoardModel.TEAM_A: tb}
	sim.setup(b, 99)
	hurt.current_hp = hurt.stat(StatModifier.Stat.MAX_HP) * 0.4
	for i in 12:
		sim.step()

	var heals := 0
	for e in sim.events:
		if e.kind == "heal" and e.uid == hurt.uid:
			heals += 1
	_check("regen ticks once a second, not once a frame", heals == 1,
		"saw %d heals in 1.2 simulated seconds" % heals)
	_check("regen never spills over max health",
		hurt.current_hp <= hurt.stat(StatModifier.Stat.MAX_HP) + 0.001)


func _test_rupture_in_battle(pool: BuffPool) -> void:
	var plain := _rupture_damage(null)
	var tb := TeamBuffs.new()
	tb.add(pool.by_id(&"rupture"), BuffData.Rarity.GOLD)
	var boosted := _rupture_damage(tb)
	_check("Rupture adds damage scaled off the victim's health",
		boosted > plain, "%.1f vs %.1f" % [boosted, plain])

	var victim := _unit(0, BoardModel.TEAM_B)
	var rup: float = pool.by_id(&"rupture").magnitude(
		BuffData.Rarity.GOLD).x
	var expected: float = victim.stat(StatModifier.Stat.MAX_HP) * rup
	_check("Rupture adds its gold share of the target's max health",
		is_equal_approx(boosted - plain, expected),
		"added %.2f, expected %.2f" % [boosted - plain, expected])


func _rupture_damage(tb: TeamBuffs) -> float:
	var b := BoardModel.new()
	var cell: Vector2i = b.deploy_cells(BoardModel.TEAM_A)[0]
	var attacker := _unit(0, BoardModel.TEAM_A)
	var victim := _unit(0, BoardModel.TEAM_B)
	b.place(attacker, cell)
	b.place(victim, BoardModel.mirror(cell))

	var sim := CombatSim.new()
	if tb != null:
		sim.team_buffs = {BoardModel.TEAM_A: tb}
	sim.setup(b, 7)
	sim._damage(victim, 10.0, attacker)
	for e in sim.events:
		if e.kind == "damage" and e.uid == victim.uid:
			return float(e.amount)
	return 0.0


func _test_full_muster_in_battle(pool: BuffPool) -> void:
	var tb := TeamBuffs.new()
	tb.add(pool.by_id(&"full_muster"), BuffData.Rarity.GOLD)

	var five := BoardModel.new()
	var cells := five.deploy_cells(BoardModel.TEAM_A)
	for i in 5:
		five.place(_unit(i, BoardModel.TEAM_A), cells[i])
	five.place(_unit(0, BoardModel.TEAM_B), BoardModel.mirror(cells[0]))
	var sample: UnitInstance = five.unit_at(cells[0])
	var solo_hp := sample.stat(StatModifier.Stat.MAX_HP)

	var sim := CombatSim.new()
	sim.team_buffs = {BoardModel.TEAM_A: tb}
	sim.setup(five, 5)
	var muster: float = 1.0 + _pool().by_id(&"full_muster").magnitude(
		BuffData.Rarity.GOLD).x
	_check("Full Muster fires when all five types are out",
		is_equal_approx(sample.stat(StatModifier.Stat.MAX_HP), solo_hp * muster),
		"%.0f -> %.0f, expected %.0f" % [
			solo_hp, sample.stat(StatModifier.Stat.MAX_HP), solo_hp * muster])

	var four := BoardModel.new()
	for i in 4:
		four.place(_unit(i, BoardModel.TEAM_A), cells[i])
	four.place(_unit(0, BoardModel.TEAM_B), BoardModel.mirror(cells[0]))
	var short_sample: UnitInstance = four.unit_at(cells[0])
	var short_hp := short_sample.stat(StatModifier.Stat.MAX_HP)

	var sim2 := CombatSim.new()
	sim2.team_buffs = {BoardModel.TEAM_A: tb}
	sim2.setup(four, 5)
	_check("Full Muster stays quiet with only four types",
		is_equal_approx(short_sample.stat(StatModifier.Stat.MAX_HP), short_hp))

	var sim3 := CombatSim.new()
	sim3.team_buffs = {BoardModel.TEAM_A: tb}
	sim3.setup(five, 5)
	_check("Full Muster does not stack up round after round",
		is_equal_approx(sample.stat(StatModifier.Stat.MAX_HP), solo_hp * muster),
		"%.0f after a second battle" % sample.stat(StatModifier.Stat.MAX_HP))


func _test_merge_procs() -> void:
	_section("Merge procs")

	var pool := _pool()
	# Enough copies to reach certainty, worked out from the buff rather than typed
	# in. Stacking seven was a magic number that only held while gold was 4x
	# bronze; retuning it to 3x quietly left this test below 100% and it started
	# failing on a third of its seeds.
	var always_tier := TeamBuffs.new()
	for i in _copies_for_certainty(pool.by_id(&"promotion")):
		always_tier.add(pool.by_id(&"promotion"), BuffData.Rarity.GOLD)
	_check("stacked merge chances cap at certainty",
		is_equal_approx(always_tier.merge_extra_tier_chance(), 1.0))

	var tiers := 0
	var extras := 0
	for seed_value in 40:
		var res := _merge_with(always_tier, seed_value)
		if res.tier:
			tiers += 1
	_check("a guaranteed Promotion always adds a tier", tiers == 40,
		"fired %d times out of 40" % tiers)

	var always_unit := TeamBuffs.new()
	for i in _copies_for_certainty(pool.by_id(&"windfall")):
		always_unit.add(pool.by_id(&"windfall"), BuffData.Rarity.GOLD)
	_check("Windfall stacks to certainty",
		is_equal_approx(always_unit.merge_extra_unit_chance(), 1.0))
	for seed_value in 40:
		var res := _merge_with(always_unit, seed_value)
		if res.extra:
			extras += 1
	_check("a guaranteed Windfall always summons one more", extras == 40,
		"fired %d times out of 40" % extras)

	var none := TeamBuffs.new()
	var quiet := 0
	for seed_value in 20:
		var res := _merge_with(none, seed_value)
		if not res.tier and not res.extra:
			quiet += 1
	_check("no buffs means no procs", quiet == 20, "%d of 20 stayed quiet" % quiet)

	var drums := TeamBuffs.new()
	drums.add(pool.by_id(&"war_drums"), BuffData.Rarity.GOLD)
	var merged := _merge_with(drums, 3)
	var drum_g: float = 1.0 + pool.by_id(&"war_drums").magnitude(
		BuffData.Rarity.GOLD).x
	_check("a merged unit inherits the team's buffs",
		is_equal_approx(merged.speed, merged.base_speed * drum_g),
		"%.2f vs %.2f" % [merged.speed, merged.base_speed * drum_g])


func _merge_with(tb: TeamBuffs, seed_value: int) -> Dictionary:
	var b := BoardModel.new()
	b.team_buffs = {BoardModel.TEAM_A: tb}
	b.configure_merges(_loadout.units, seed_value)
	var cells := b.deploy_cells(BoardModel.TEAM_A)
	var a := _unit(0, BoardModel.TEAM_A)
	var c := _unit(0, BoardModel.TEAM_A)
	b.place(a, cells[0])
	b.place(c, cells[1])
	var out := b.merge(a, c, cells[1])
	var procs := b.last_merge_procs
	var base: float = 0.0
	var now: float = 0.0
	if out != null:
		base = out.data.attack_speed
		now = out.stat(StatModifier.Stat.ATTACK_SPEED)
	return {
		tier = procs.get("extra_tier", false),
		extra = procs.get("extra_unit", null) != null,
		speed = now,
		base_speed = base,
	}


func _roster() -> LoadoutData:
	return load("res://data/loadouts/roster.tres") as LoadoutData


func _must_find(id: String) -> UnitData:
	# _find() returns null for anything not in the roster, which includes every
	# hidden unit. A test that quietly built its dummies out of null passed three
	# checks for the wrong reason once; this makes that a failure instead.
	var u := _find(id)
	_check("the roster has a %s to test with" % id, u != null)
	return u


func _find(id: String) -> UnitData:
	for u in _roster().units:
		if String(u.id) == id:
			return u
	return null


func _duel_board(a: UnitData, b: UnitData) -> BoardModel:
	var board := BoardModel.new()
	var cell: Vector2i = board.deploy_cells(BoardModel.TEAM_A)[0]
	board.place(UnitInstance.create(a, BoardModel.TEAM_A), cell)
	board.place(UnitInstance.create(b, BoardModel.TEAM_B), BoardModel.mirror(cell))
	return board


func _test_new_units() -> void:
	_section("New units")

	var roster := _roster()
	_check("the roster loadout exists and is valid",
		roster != null and roster.is_valid())
	if roster == null:
		return
	_check("twenty-eight unit types are pickable", roster.units.size() == 28,
		"%d in the roster" % roster.units.size())
	# Ids are file names, so a duplicate means one row quietly overwrites another
	# and the roster is short without anything reporting it.
	var seen_ids := {}
	var clashes: Array[String] = []
	for u in roster.units:
		var key := String(u.id)
		if seen_ids.has(key):
			clashes.append(key)
		seen_ids[key] = true
	_check("and no two of them share an id", clashes.is_empty(),
		", ".join(clashes))

	var wanted := ["assassin", "herald", "revenant", "seraph", "conjurer"]
	var missing: PackedStringArray = []
	for id in wanted:
		if _find(id) == null:
			missing.append(id)
	_check("all five new units are in the roster", missing.is_empty(),
		"missing %s" % ", ".join(missing))
	if not missing.is_empty():
		return

	_check("the summoned Wisp is never offered in a loadout",
		_find("wisp") == null and load("res://data/units/wisp_t1.tres") != null,
		"the Wisp should exist as data but stay out of the roster")

	_test_assassin()
	_test_herald()
	_test_revenant()
	_test_seraph()
	_test_conjurer()


func _test_assassin() -> void:
	var assassin := _find("assassin")
	var ab: AbilityData = assassin.ability
	_check("the Assassin opens with its ability",
		assassin.casts_at_battle_start and ab.kind == AbilityData.Kind.BLINK_STRIKE)

	_check("blink damage doubles every tier, like health and attack",
		_blink_damage_at(assassin, 6) > 0.0
		and is_equal_approx(_blink_damage_at(assassin, 2),
			_blink_damage_at(assassin, 1) * 2.0)
		and is_equal_approx(_blink_damage_at(assassin, 6),
			_blink_damage_at(assassin, 1) * 32.0),
		"t1 %.0f, t2 %.0f, t6 %.0f" % [_blink_damage_at(assassin, 1),
			_blink_damage_at(assassin, 2), _blink_damage_at(assassin, 6)])
	_check("the burst still matters against tier-6 health pools",
		_blink_damage_at(assassin, 6) > _find("archer").max_hp * 32.0 * 0.5,
		"%.0f burst vs a %.0f-hp tier 6 Archer" % [
			_blink_damage_at(assassin, 6), _find("archer").max_hp * 32.0])

	var board := BoardModel.new()
	var victim := UnitInstance.create(_find("warden"), BoardModel.TEAM_A)
	var killer := UnitInstance.create(assassin, BoardModel.TEAM_B)
	board.place(victim, Vector2i(2, 3))
	board.place(killer, Vector2i(2, 8))
	var start := victim.cell
	var sim := CombatSim.new()
	sim.setup(board, 11)
	for i in 20:
		sim.step()

	var blinked := false
	var struck := 0.0
	for e in sim.events:
		if e.kind == "blink" and e.uid == killer.uid:
			blinked = true
		if e.kind == "ability" and e.uid == killer.uid and e.has("amount"):
			struck = float(e.amount)
	_check("the Assassin blinks before it strikes", blinked)
	_check("its opening hit is worth far more than a normal swing",
		struck > killer.stat(StatModifier.Stat.ATTACK_DAMAGE) * 2.0,
		"%.0f burst vs %.0f a swing" % [
			struck, killer.stat(StatModifier.Stat.ATTACK_DAMAGE)])
	_check("it lands on the far side of its victim",
		killer.cell == start + Vector2i(0, -1),
		"assassin at %s, victim started at %s" % [killer.cell, start])
	_check("it strikes on the opening tick, with no wind-up",
		_first_ability_time(sim, killer.uid) <= 0.0,
		"first cast landed at t=%.2f" % _first_ability_time(sim, killer.uid))

	killer.stealth_left = 3.0
	_check("a hidden unit is not a valid target",
		board.nearest_enemy(victim) == null,
		"the Warden still found it")
	_check("stealth does not make it dead", killer.is_alive() and killer.is_hidden())
	killer.stealth_left = 0.0
	_check("it becomes targetable again when stealth runs out",
		board.nearest_enemy(victim) == killer)


func _blink_damage_at(assassin: UnitData, tier: int) -> float:
	var ab: AbilityData = assassin.ability
	return ab.blink_base_damage * pow(2.0, float(tier - 1))


func _first_ability_time(sim: CombatSim, uid: int) -> float:
	for e in sim.events:
		if e.kind == "ability" and e.uid == uid:
			return float(e.t)
	return 999.0


func _test_herald() -> void:
	var herald := _find("herald")
	var ab: AbilityData = herald.ability
	_check("the Herald opens with its horn",
		herald.casts_at_battle_start and ab.kind == AbilityData.Kind.SPEED_AURA)

	var board := BoardModel.new()
	var cells := board.deploy_cells(BoardModel.TEAM_B)
	var spot: Vector2i = cells[cells.size() / 2]
	var buffer := UnitInstance.create(herald, BoardModel.TEAM_B)
	board.place(buffer, spot)
	var neighbour := UnitInstance.create(_find("lancer"), BoardModel.TEAM_B)
	var far := UnitInstance.create(_find("lancer"), BoardModel.TEAM_B)
	board.place(neighbour, spot + Vector2i(1, 0))
	board.place(far, spot + Vector2i(3, 0) if board.in_bounds(spot + Vector2i(3, 0))
		else spot - Vector2i(3, 0))
	board.place(UnitInstance.create(_find("warden"), BoardModel.TEAM_A),
		BoardModel.mirror(spot))

	var near_before := neighbour.attack_interval()
	var far_before := far.attack_interval()
	var sim := CombatSim.new()
	sim.setup(board, 3)
	for i in 12:
		sim.step()

	_check("the Herald speeds up the ally beside it",
		neighbour.attack_interval() < near_before,
		"%.3f -> %.3f" % [near_before, neighbour.attack_interval()])
	_check("allies out of reach get nothing",
		is_equal_approx(far.attack_interval(), far_before))
	_check("the horn is a battle-only buff, gone next round",
		neighbour.battle_modifiers.size() > 0)
	neighbour.reset_for_battle()
	_check("the speed goes away when the round ends",
		is_equal_approx(neighbour.attack_interval(), near_before))

	var t6 := UnitInstance.create(BoardModel.at_tier(herald, 6), BoardModel.TEAM_B)
	_check("the horn scales with the Herald's tier",
		ab.aura_percent_per_tier * float(t6.data.tier)
			> ab.aura_percent_per_tier * 1.0)

	_test_horn_stacks()


func _test_horn_stacks() -> void:
	var herald := _find("herald")
	var board := BoardModel.new()
	var spot := Vector2i(2, 8)
	var ally := UnitInstance.create(_find("lancer"), BoardModel.TEAM_B)
	board.place(ally, spot)
	board.place(UnitInstance.create(herald, BoardModel.TEAM_B), spot + Vector2i(-1, 0))
	board.place(UnitInstance.create(herald, BoardModel.TEAM_B), spot + Vector2i(1, 0))
	board.place(UnitInstance.create(_find("warden"), BoardModel.TEAM_A),
		BoardModel.mirror(spot))

	var plain := ally.attack_interval()
	var sim := CombatSim.new()
	sim.setup(board, 17)
	var doubled := ally.attack_interval()

	var one := BoardModel.new()
	var solo := UnitInstance.create(_find("lancer"), BoardModel.TEAM_B)
	one.place(solo, spot)
	one.place(UnitInstance.create(herald, BoardModel.TEAM_B), spot + Vector2i(-1, 0))
	one.place(UnitInstance.create(_find("warden"), BoardModel.TEAM_A),
		BoardModel.mirror(spot))
	var solo_sim := CombatSim.new()
	solo_sim.setup(one, 17)
	var single := solo.attack_interval()

	_check("two Heralds stack on the same ally", doubled < single,
		"one horn %.4f, two horns %.4f, unbuffed %.4f" % [single, doubled, plain])
	_check("each Herald contributes its own modifier",
		ally.battle_modifiers.size() == 2,
		"%d modifiers on the ally" % ally.battle_modifiers.size())

	var drums := TeamBuffs.new()
	drums.add(_pool().by_id(&"war_drums"), BuffData.Rarity.GOLD)
	drums.apply_to(ally)
	_check("the horn stacks on top of attack-speed buffs too",
		ally.attack_interval() < doubled,
		"%.4f with War Drums on top of two horns" % ally.attack_interval())


func _test_revenant() -> void:
	var revenant := _find("revenant")
	var ab: AbilityData = revenant.ability
	_check("the Revenant's ability is a revive, not a cast",
		ab.kind == AbilityData.Kind.REVIVE and not revenant.casts_at_battle_start)
	_check("the revive is an even coin flip",
		is_equal_approx(ab.revive_chance, 0.5))
	_check("it gets back up after one second, at full health",
		is_equal_approx(ab.revive_delay, 1.0)
		and is_equal_approx(ab.revive_hp_percent, 1.0),
		"%.1fs delay at %d%% health" % [
			ab.revive_delay, roundi(ab.revive_hp_percent * 100.0)])

	var revived := 0
	var stayed_down := 0
	for seed_value in 40:
		if _revenant_gets_up(revenant, seed_value):
			revived += 1
		else:
			stayed_down += 1
	_check("it comes back roughly half the time",
		revived > 8 and stayed_down > 8,
		"%d up, %d down out of 40" % [revived, stayed_down])

	var board := _duel_board(_find("pyre"), revenant)
	var corpse: UnitInstance = board.units_of(BoardModel.TEAM_B)[0]
	var sim := CombatSim.new()
	sim.setup(board, 5)
	corpse.current_hp = 1.0
	sim.step()
	corpse.take_damage(999.0)
	board.remove(corpse)
	sim._try_queue_revive(corpse)
	if sim.pending_respawns(BoardModel.TEAM_B) > 0:
		_check("a pending revive keeps the battle alive",
			not sim.is_finished(),
			"the sim called the round while someone was still getting up")
		for i in 40:
			sim.step()
			if corpse.is_alive():
				break
		_check("it is back on the board after the delay",
			corpse.is_alive() and board.in_bounds(corpse.cell),
			corpse.describe())
		var back_at := _respawn_hp(sim, corpse.uid)
		_check("it comes back at full health, as good as new",
			back_at.size() == 2 and is_equal_approx(back_at[0], back_at[1]),
			"came back on %s" % str(back_at))
		_check("it comes back with a clean slate — no mana, shield, poison or haste",
			is_zero_approx(corpse.mana) and is_zero_approx(corpse.shield)
			and corpse.dots.is_empty() and corpse.haste_stacks == 0
			and corpse.battle_modifiers.is_empty())
		_check("the board counts it as a live unit again",
			corpse.is_alive() and board.unit_at(corpse.cell) == corpse)

	_test_endless_revives()


func _test_endless_revives() -> void:
	var revenant := _find("revenant")
	var board := _duel_board(_find("pyre"), revenant)
	var corpse: UnitInstance = board.units_of(BoardModel.TEAM_B)[0]
	var sim := CombatSim.new()
	sim.setup(board, 4242)

	var got_up := 0
	for attempt in 12:
		if not corpse.is_alive():
			continue
		corpse.take_damage(999999.0)
		board.remove(corpse)
		if not sim._try_queue_revive(corpse):
			continue
		for i in 20:
			sim.step()
		if corpse.is_alive():
			got_up += 1
	_check("there is no cap on how often it can get back up", got_up > 1,
		"only came back %d times in 12 deaths" % got_up)
	_check("the revive counter tracks every comeback",
		corpse.revives == got_up, "counter says %d, saw %d" % [corpse.revives, got_up])


func _respawn_hp(sim: CombatSim, uid: int) -> Array[float]:
	for e in sim.events:
		if e.kind == "respawn" and e.uid == uid:
			return [float(e.hp), float(e.max_hp)] as Array[float]
	return [] as Array[float]


func _revenant_gets_up(revenant: UnitData, seed_value: int) -> bool:
	var board := _duel_board(_find("pyre"), revenant)
	var corpse: UnitInstance = board.units_of(BoardModel.TEAM_B)[0]
	var sim := CombatSim.new()
	sim.setup(board, seed_value)
	corpse.take_damage(99999.0)
	board.remove(corpse)
	return sim._try_queue_revive(corpse)


func _test_seraph() -> void:
	var seraph := _find("seraph")
	var ab: AbilityData = seraph.ability
	_check("the Seraph heals on a full bar, not at the start",
		ab.kind == AbilityData.Kind.BURST_HEAL and not seraph.casts_at_battle_start)

	var board := BoardModel.new()
	var cells := board.deploy_cells(BoardModel.TEAM_B)
	var spot: Vector2i = cells[cells.size() / 2]
	var healer := UnitInstance.create(seraph, BoardModel.TEAM_B)
	var hurt := UnitInstance.create(_find("warden"), BoardModel.TEAM_B)
	board.place(healer, spot)
	board.place(hurt, spot + Vector2i(1, 0))
	board.place(UnitInstance.create(_find("warden"), BoardModel.TEAM_A),
		BoardModel.mirror(spot))

	var scratched := UnitInstance.create(_find("lancer"), BoardModel.TEAM_B)
	board.place(scratched, spot + Vector2i(-1, 0))

	var sim := CombatSim.new()
	sim.setup(board, 9)
	hurt.current_hp = hurt.stat(StatModifier.Stat.MAX_HP) * 0.2
	scratched.current_hp = scratched.stat(StatModifier.Stat.MAX_HP) * 0.9
	var before := hurt.current_hp
	var scratched_before := scratched.current_hp
	healer.mana = UnitInstance.MANA_MAX
	for i in 20:
		sim.step()

	_check("a full bar puts health back into a hurt ally",
		hurt.current_hp > before,
		"%.0f -> %.0f" % [before, hurt.current_hp])
	_check("the burst is big, not a trickle",
		hurt.current_hp - before
			> hurt.stat(StatModifier.Stat.MAX_HP) * 0.3,
		"healed %.0f of a %.0f pool" % [hurt.current_hp - before,
			hurt.stat(StatModifier.Stat.MAX_HP)])

	var healed_uids := {}
	for e in sim.events:
		if e.kind == "heal":
			healed_uids[e.uid] = true
	_check("it heals exactly one target, not everyone nearby",
		healed_uids.size() == 1 and healed_uids.has(hurt.uid),
		"healed %d units" % healed_uids.size())
	_check("the lightly hurt ally was never topped up",
		scratched.current_hp <= scratched_before + 0.001,
		"%.0f -> %.0f" % [scratched_before, scratched.current_hp])

	var pick := BoardModel.new()
	var chooser := UnitInstance.create(seraph, BoardModel.TEAM_B)
	var worst := UnitInstance.create(_find("lancer"), BoardModel.TEAM_B)
	var better := UnitInstance.create(_find("lancer"), BoardModel.TEAM_B)
	var whole := UnitInstance.create(_find("lancer"), BoardModel.TEAM_B)
	pick.place(chooser, Vector2i(2, 8))
	pick.place(worst, Vector2i(3, 8))
	pick.place(better, Vector2i(1, 8))
	pick.place(whole, Vector2i(2, 7))
	worst.current_hp = worst.stat(StatModifier.Stat.MAX_HP) * 0.1
	better.current_hp = better.stat(StatModifier.Stat.MAX_HP) * 0.6
	var chooser_sim := CombatSim.new()
	chooser_sim.board = pick
	_check("it picks whoever is hurt worst, by fraction of health",
		chooser_sim._worst_hurt_ally(chooser, seraph.ability.heal_radius) == worst,
		"picked the wrong ally")
	worst.heal_to_full()
	_check("with the worst healed it moves to the next one down",
		chooser_sim._worst_hurt_ally(chooser, seraph.ability.heal_radius) == better)
	better.heal_to_full()
	_check("a whole team at full health gets no heal at all",
		chooser_sim._worst_hurt_ally(chooser, seraph.ability.heal_radius) == null)
	_check("healing never overflows max health",
		hurt.current_hp <= hurt.stat(StatModifier.Stat.MAX_HP) + 0.001)


func _test_conjurer() -> void:
	var conjurer := _find("conjurer")
	var ab: AbilityData = conjurer.ability
	_check("the Conjurer opens by summoning",
		conjurer.casts_at_battle_start and ab.kind == AbilityData.Kind.SUMMON)
	_check("it has something to summon", ab.summon_unit != null,
		"summon_unit is empty — the generator did not link it")
	if ab.summon_unit == null:
		return
	_check("what it summons is the Wisp", String(ab.summon_unit.id) == "wisp")

	var sim := CombatSim.new()
	var t1 := UnitInstance.create(conjurer, BoardModel.TEAM_B)
	var t6 := UnitInstance.create(BoardModel.at_tier(conjurer, 6), BoardModel.TEAM_B)
	var caps: PackedInt32Array = []
	for tier in range(1, 7):
		var at_tier := UnitInstance.create(
			BoardModel.at_tier(conjurer, tier), BoardModel.TEAM_B)
		caps.append(sim.summon_cap(at_tier, ab))
	_check("the wisp cap goes 1, 1, 2, 2, 3, 3 across the six tiers",
		caps == PackedInt32Array([1, 1, 2, 2, 3, 3]), str(caps))
	_check("a tier 1 holds one wisp, a tier 6 holds three",
		sim.summon_cap(t1, ab) == 1 and sim.summon_cap(t6, ab) == 3,
		"t1 caps at %d, t6 at %d" % [sim.summon_cap(t1, ab), sim.summon_cap(t6, ab)])

	var board := _duel_board(_find("warden"), BoardModel.at_tier(conjurer, 6))
	var caster: UnitInstance = board.units_of(BoardModel.TEAM_B)[0]
	var before := board.count_of(BoardModel.TEAM_B)
	var live := CombatSim.new()
	live.setup(board, 21)
	for i in 30:
		live.step()

	var summons := 0
	for e in live.events:
		if e.kind == "summon":
			summons += 1
	_check("it puts a wisp on the board", summons > 0)
	_check("the wisp joins the board, not just the log",
		board.count_of(BoardModel.TEAM_B) > before,
		"%d before, %d after" % [before, board.count_of(BoardModel.TEAM_B)])
	_check("it never exceeds its tier cap",
		caster.summons_made <= live.summon_cap(caster, ab),
		"made %d, cap %d" % [caster.summons_made, live.summon_cap(caster, ab)])
	_check("summoned wisps take their turns like anything else",
		live.unit_map().size() > _duel_size(),
		"the sim never adopted the new units")


func _duel_size() -> int:
	return 2


func _test_this_pass() -> void:
	_section("Tuning pass")
	_test_warden_shield()
	_test_assassin_goes_deep()
	_test_seraph_scaling()
	_test_conjurer_shape()
	_test_horn_reach_and_power()
	_test_round_boundaries()


func _test_warden_shield() -> void:
	var warden := _find("warden")
	var ab: AbilityData = warden.ability
	_check("the Warden trades tempo for weight",
		warden.attack_speed < 0.5 and warden.move_time > 0.7
		and warden.attack_damage > 25.0 and warden.max_hp > 200.0,
		"%.0f hp, %.0f damage, %.2f attacks/s, %.2fs a step" % [
			warden.max_hp, warden.attack_damage, warden.attack_speed,
			warden.move_time])

	var b := BoardModel.new()
	var w := UnitInstance.create(warden, BoardModel.TEAM_A)
	b.place(w, Vector2i(2, 4))
	b.place(UnitInstance.create(_find("lancer"), BoardModel.TEAM_B), Vector2i(2, 6))
	var sim := CombatSim.new()
	sim.setup(b, 11)
	var pool := w.stat(StatModifier.Stat.MAX_HP)
	_check("the shield is bigger than the Warden's own health",
		w.shield > pool, "%.0f shield on %.0f health" % [w.shield, pool])
	_check("the shield is a share of max health, not a flat number",
		is_equal_approx(w.shield, pool * ab.shield_percent),
		"%.0f shield, expected %.0f" % [w.shield, pool * ab.shield_percent])

	var big := BoardModel.new()
	var buffed := UnitInstance.create(warden, BoardModel.TEAM_A)
	var wall := TeamBuffs.new()
	wall.add(_pool().by_id(&"ironwall"), BuffData.Rarity.GOLD)
	wall.apply_to(buffed)
	big.place(buffed, Vector2i(2, 4))
	big.place(UnitInstance.create(_find("lancer"), BoardModel.TEAM_B), Vector2i(2, 6))
	var big_sim := CombatSim.new()
	big_sim.setup(big, 11)
	# The shield is a share of max health, so a health buff has to grow it. Stated
	# as a ratio of the buff rather than a fixed multiple, so retuning Ironwall
	# does not fail a test that is about the shield, not about Ironwall.
	var iron: float = 1.0 + _pool().by_id(&"ironwall").magnitude(
		BuffData.Rarity.GOLD).x
	_check("Ironwall makes the shield bigger too, which was the whole point",
		is_equal_approx(buffed.shield, w.shield * iron),
		"%.0f buffed vs %.0f plain" % [buffed.shield, w.shield])

	var top := UnitInstance.create(BoardModel.at_tier(warden, 6), BoardModel.TEAM_A)
	var tall := BoardModel.new()
	tall.place(top, Vector2i(2, 4))
	tall.place(UnitInstance.create(_find("lancer"), BoardModel.TEAM_B), Vector2i(2, 6))
	var tall_sim := CombatSim.new()
	tall_sim.setup(tall, 11)
	_check("a tier 6 Warden gets a tier 6 shield",
		is_equal_approx(top.shield, w.shield * 32.0),
		"%.0f vs %.0f" % [top.shield, w.shield * 32.0])


func _test_assassin_goes_deep() -> void:
	var board := BoardModel.new()
	var front := UnitInstance.create(_find("warden"), BoardModel.TEAM_A)
	var back := UnitInstance.create(_find("archer"), BoardModel.TEAM_A)
	var killer := UnitInstance.create(_find("assassin"), BoardModel.TEAM_B)
	board.place(front, Vector2i(2, 4))
	board.place(back, Vector2i(2, 1))
	board.place(killer, Vector2i(2, 9))

	var sim := CombatSim.new()
	sim.setup(board, 13)
	_check("the Assassin skips the front rank and goes for the back line",
		killer.cell.y < front.cell.y,
		"landed at %s with the front rank at %s" % [killer.cell, front.cell])
	_check("it lands right behind the deepest enemy",
		killer.cell == back.cell + Vector2i(0, -1),
		"landed at %s, back rank at %s" % [killer.cell, back.cell])

	var hurt := false
	for e in sim.events:
		if e.kind == "damage" and e.uid == back.uid:
			hurt = true
	_check("the back-line unit is the one that gets hit", hurt)


func _test_seraph_scaling() -> void:
	var seraph := _find("seraph")
	var ab: AbilityData = seraph.ability
	var t1 := UnitInstance.create(seraph, BoardModel.TEAM_B)
	var t6 := UnitInstance.create(BoardModel.at_tier(seraph, 6), BoardModel.TEAM_B)
	_check("the heal grows with the Seraph's own tier",
		CombatSim.heal_fraction(t6, ab) > CombatSim.heal_fraction(t1, ab) * 1.5,
		"t1 heals %.0f%%, t6 heals %.0f%%" % [
			CombatSim.heal_fraction(t1, ab) * 100.0,
			CombatSim.heal_fraction(t6, ab) * 100.0])
	_check("a tier 1 Seraph still heals its stated share",
		is_equal_approx(CombatSim.heal_fraction(t1, ab), ab.heal_percent))
	_check("the Seraph fills its bar quickly",
		seraph.mana_per_attack >= 30.0 and ab.cast_time <= 0.3,
		"%.0f mana a hit, %.2fs cast" % [seraph.mana_per_attack, ab.cast_time])


func _test_retinue() -> void:
	_section("A retinue is who is standing, not who was made")
	var conjurer := _find("conjurer")
	var ab: AbilityData = conjurer.ability
	_check("Call Wisp is a retinue, not a one-off", ab.summon_retinue)

	# The opener should fill the retinue in one go. Before this it made exactly
	# one wisp whatever the tier, so a tier 6 opened with one instead of three.
	var opened: PackedInt32Array = []
	for tier in range(1, 7):
		var b := BoardModel.new()
		var cj := UnitInstance.create(
			BoardModel.at_tier(conjurer, tier), BoardModel.TEAM_B)
		b.place(cj, Vector2i(2, 8))
		b.place(UnitInstance.create(_find("warden"), BoardModel.TEAM_A),
			Vector2i(2, 1))
		var sim := CombatSim.new()
		sim.setup(b, 3)
		opened.append(sim.retinue_size(cj))
	_check("the opening cast fills the retinue: 1, 1, 2, 2, 3, 3",
		opened == PackedInt32Array([1, 1, 2, 2, 3, 3]), str(opened))

	# A wisp that dies must free its place, or the Conjurer is done for the round
	# after its opener however long the fight runs.
	var board := BoardModel.new()
	var six := UnitInstance.create(
		BoardModel.at_tier(conjurer, 6), BoardModel.TEAM_B)
	board.place(six, Vector2i(2, 8))
	board.place(UnitInstance.create(_find("warden"), BoardModel.TEAM_A),
		Vector2i(2, 1))
	var live := CombatSim.new()
	live.setup(board, 7)
	_check("a tier 6 opens with three wisps", live.retinue_size(six) == 3,
		"opened with %d" % live.retinue_size(six))

	for u in board.all_units():
		if u.summoned_by == six.uid and u.is_alive():
			u.current_hp = 0.0
			board.remove(u)
			break
	_check("losing one leaves room for one more",
		live.retinue_size(six) == 2
		and live.summon_want(six, ab) == 1,
		"retinue %d, wants %d" % [
			live.retinue_size(six), live.summon_want(six, ab)])

	six.mana = UnitInstance.MANA_MAX
	# Long enough for the 0.5s wind-up to finish; a cast is not instant.
	for i in 12:
		live.step()
	_check("and the next full bar replaces it",
		live.retinue_size(six) == 3,
		"retinue back to %d, made %d all round" % [
			live.retinue_size(six), six.summons_made])
	_check("the replacement is counted as a fourth summon, not a reused slot",
		six.summons_made == 4, "summons_made is %d" % six.summons_made)


func _test_chassis() -> void:
	_section("Mechanical and biological")
	var sentry: UnitData = load("res://data/units/sentry_t1.tres")
	var engineer := _find("engineer")
	_check("the Sentry exists and is mechanical",
		sentry != null and sentry.is_mechanical())
	_check("the Spire is mechanical too, so an Engineer can keep one alive",
		_find("spire").is_mechanical())
	var bio := 0
	for d in _roster().units:
		if not d.is_mechanical():
			bio += 1
	_check("but most of the roster is not", bio >= _roster().units.size() - 2,
		"%d of %d are biological" % [bio, _roster().units.size()])

	# rooted and harmless used to be one flag. The Sentry is the reason they
	# are two: it is bolted to the floor and it is the opposite of harmless.
	_check("the Sentry cannot move", not sentry.can_move)
	_check("but it can very much shoot", sentry.can_attack)
	_check("the Spire still cannot do either",
		not _find("spire").can_move and not _find("spire").can_attack)
	_check("the Sentry sees the whole board",
		sentry.attack_range == UnitData.RangeBand.UNLIMITED)
	_check("and fires rarely and hard",
		UnitInstance.create(sentry, 0).attack_interval() > 3.0
		and sentry.attack_damage > _find("archer").attack_damage * 2.0,
		"every %.1fs for %.0f" % [
			UnitInstance.create(sentry, 0).attack_interval(), sentry.attack_damage])
	_check("the Sentry is built, not drawn", not _roster().units.has(sentry))

	# Repair is a trait, not an ability: the Engineer's ability slot is spent on
	# building the thing it repairs.
	_check("the Engineer repairs, and it is a trait not an ability",
		engineer.repair_per_second > 0.0
		and engineer.ability.kind == AbilityData.Kind.SUMMON)
	var b := BoardModel.new()
	var eng := UnitInstance.create(engineer, BoardModel.TEAM_B)
	var mech := UnitInstance.create(sentry, BoardModel.TEAM_B)
	var flesh := UnitInstance.create(_find("archer"), BoardModel.TEAM_B)
	b.place(eng, Vector2i(2, 8))
	b.place(mech, Vector2i(3, 8))
	b.place(flesh, Vector2i(1, 8))
	b.place(UnitInstance.create(_find("warden"), BoardModel.TEAM_A), Vector2i(2, 1))
	var sim := CombatSim.new()
	sim.setup(b, 4)
	mech.current_hp = 10.0
	flesh.current_hp = 10.0
	for i in 15:
		sim.step()
	_check("standing beside it repairs a mechanical ally",
		mech.current_hp > 10.0, "sentry still on %.0f" % mech.current_hp)
	_check("and does nothing at all for a biological one",
		is_equal_approx(flesh.current_hp, 10.0),
		"archer went to %.0f" % flesh.current_hp)


func _test_engineer_build() -> void:
	_section("The Engineer builds where it stands")
	var engineer := _find("engineer")
	var ab: AbilityData = engineer.ability
	_check("it builds at the start of the round", engineer.casts_at_battle_start)
	_check("and the build takes real time, unlike every other opener",
		ab.opener_takes_time and ab.cast_time >= 3.0,
		"cast_time %.1f — meant to be a considerable commitment" % ab.cast_time)
	_check("it is by a distance the longest cast in the game",
		_longest_cast_is(ab), "something else winds up for longer")
	_check("it is exposed while it works, not protected",
		ab.exposes_caster > 0.0 and not ab.guards_caster)

	# A Spire as the opposition: rooted and harmless. This test is about where the
	# Sentry lands and what the Engineer does afterwards, and at a ten second
	# build even a lone tier 1 Warden walks over and kills it before it finishes —
	# which is a real property of the unit, but not the one being measured here.
	var b := BoardModel.new()
	var eng := UnitInstance.create(engineer, BoardModel.TEAM_B)
	var home := Vector2i(2, 8)
	b.place(eng, home)
	b.place(UnitInstance.create(
		BoardModel.at_tier(_find("spire"), 4), BoardModel.TEAM_A), Vector2i(2, 1))
	var sim := CombatSim.new()
	sim.setup(b, 5)
	_check("it starts the round mid-build",
		eng.state == UnitInstance.State.CASTING)
	_check("and takes double damage while it does",
		is_equal_approx(eng.exposure(), 2.0), "x%.2f" % eng.exposure())
	_check("nothing is built on the first tick",
		sim.retinue_size(eng) == 0)

	# Derived from the ability, not typed in: the build time is a tuning number
	# and this test should not care what it currently is.
	var ticks := ceili(ab.cast_time / CombatSim.TICK) + 4
	for i in ticks:
		sim.step()
	_check("the Sentry lands on the tile the Engineer was standing on",
		board_holds(b, home, "sentry"), "nothing of the sort at %s" % home)
	_check("and the Engineer has stepped off it", eng.cell != home,
		"still at %s" % eng.cell)
	_check("and it stays beside what it built, tending it",
		BoardModel.tile_distance(eng.cell, home) <= 1,
		"wandered off to %s" % eng.cell)
	_check("it is no longer exposed once the build is done",
		is_equal_approx(eng.exposure(), 1.0), "x%.2f" % eng.exposure())
	_check("exactly one Sentry, not one per tick",
		sim.retinue_size(eng) == 1, "%d" % sim.retinue_size(eng))

	# A full bar with a healthy Sentry must not restart the build: it would
	# stand exposed for two and a half seconds and produce nothing.
	eng.mana = UnitInstance.MANA_MAX
	_check("a full bar with its Sentry alive does not restart the build",
		not sim.can_cast(eng) and ab.holds_when_capped)
	for i in 5:
		sim.step()
	_check("so it stays out of the casting state", eng.state != UnitInstance.State.CASTING)

	# But a destroyed Sentry must be replaceable, or the Engineer is finished.
	for u in b.all_units():
		if u.summoned_by == eng.uid and u.is_alive():
			u.current_hp = 0.0
			b.remove(u)
			break
	_check("but a destroyed Sentry frees it to build again", sim.can_cast(eng))

	# The build is long enough that finishing it is the whole gamble: a third of
	# an average round, head-down, at double damage.
	_check("the build is a serious slice of a round",
		ab.cast_time >= 8.0 and ab.cast_time <= CombatSim.SUDDEN_DEATH * 0.5,
		"%.1fs against a %.0fs sudden-death mark" % [
			ab.cast_time, CombatSim.SUDDEN_DEATH])

	# Five seconds at double damage is a long time to stand still, and the
	# Assassin is the unit that punishes it: Shadowstep opens *behind* the enemy
	# line, which is exactly where an Engineer goes to be safe. Measured at 100%
	# build completion with no Assassin on the board against 62% with one, so
	# this is the counter, not noise. If Shadowstep ever stops opening behind,
	# the Engineer quietly becomes a much safer unit than it is meant to be.
	var shadow: AbilityData = _find("assassin").ability
	_check("the Assassin still opens behind the line, which is what punishes it",
		shadow.kind == AbilityData.Kind.BLINK_STRIKE
		and _find("assassin").casts_at_battle_start)
	_check("and it opens instantly, before the build can finish",
		not shadow.opener_takes_time and shadow.cast_time < ab.cast_time,
		"assassin winds up %.1fs, engineer %.1fs" % [
			shadow.cast_time, ab.cast_time])


func _longest_cast_is(ab: AbilityData) -> bool:
	var dir := DirAccess.open("res://data/abilities")
	if dir == null:
		return false
	for f in dir.get_files():
		if not f.ends_with(".tres"):
			continue
		var other: AbilityData = load("res://data/abilities/" + f)
		if other != null and other.id != ab.id and other.cast_time >= ab.cast_time:
			return false
	return true


func board_holds(b: BoardModel, c: Vector2i, id: String) -> bool:
	var u := b.unit_at(c)
	return u != null and String(u.data.id) == id


func _test_new_units_are_readable() -> void:
	# Everything a unit does has to be legible from its card, or the player is
	# guessing. These three carry rules nothing else in the game has.
	var eng := UnitCodex.card(_find("engineer"))
	_check("the Engineer's card says it repairs",
		eng.to_lower().contains("repair"), eng)
	_check("and that it is exposed while building",
		eng.to_lower().contains("more damage while"), eng)
	var sentry: UnitData = load("res://data/units/sentry_t1.tres")
	var sen := UnitCodex.card(sentry)
	_check("the Sentry's card says it is mechanical",
		sen.contains("Mechanical"), sen)
	_check("and that it never moves", sen.contains("Never moves"), sen)
	var par := UnitCodex.card(_find("paragon"))
	_check("the Paragon's card explains empowerment",
		par.to_lower().contains("exactly one")
		and par.to_lower().contains("empowered"), par)
	_check("and warns that a summoned one never gets it",
		par.to_lower().contains("after the opening bell"), par)
	_check("and says the ability needs it",
		par.to_lower().contains("only works while it is empowered"), par)
	# Assert the meaning, not a phrasing: this ability carries a hand-written
	# description, which overrides the generated one, so testing my own wording
	# would only ever test the fallback nobody sees.
	var stand: String = _find("paragon").ability.describe().to_lower()
	_check("Last Stand's own text admits it cannot move",
		stand.contains("cannot move") or stand.contains("neither move"), stand)
	_check("and that it cannot attack",
		stand.contains("cannot swing") or stand.contains("nor swing"), stand)
	_check("and says how much damage it shrugs off",
		stand.contains("90%"), stand)

	var tyr := UnitCodex.card(_find("tyrant"))
	_check("the Tyrant's card owns up to its drawback",
		tyr.contains("Your own units within"), tyr)
	_check("every unit's headline names its chassis",
		UnitCodex.headline(_find("archer")).contains("Biological"),
		UnitCodex.headline(_find("archer")))


func _test_aegis() -> void:
	_section("The Aegis")
	var aegis := _find("aegis")
	var ab: AbilityData = aegis.ability
	_check("it shrugs off some of everything, always",
		aegis.damage_resist > 0.0, "%.2f" % aegis.damage_resist)
	var bare := UnitInstance.create(aegis, BoardModel.TEAM_B)
	_check("and that shows up as a damage multiplier below one",
		is_equal_approx(bare.damage_taken_multiplier(), 1.0 - aegis.damage_resist),
		"x%.2f" % bare.damage_taken_multiplier())
	_check("nothing else on the roster has innate resist",
		_only_resister(aegis), "something else resists too")

	# Retaliation adds resist as flat percentage points, not as a percentage of
	# a percentage — 15 points on top of 15 is 30, not 17.25.
	var buff := load("res://data/buffs/retaliation.tres") as BuffData
	_check("its buff exists and belongs to it",
		buff != null and buff.unit_id == &"aegis")
	var tb := TeamBuffs.new()
	tb.add(buff, BuffData.Rarity.GOLD)
	var strong := UnitInstance.create(aegis, BoardModel.TEAM_B)
	tb.apply_to(strong)
	var want := aegis.damage_resist + buff.magnitude(BuffData.Rarity.GOLD).y
	_check("gold Retaliation adds its resist on top of the innate share",
		is_equal_approx(strong.resist(), want),
		"%.2f, expected %.2f" % [strong.resist(), want])
	_check("and raises health as a percentage",
		is_equal_approx(strong.stat(StatModifier.Stat.MAX_HP),
			aegis.max_hp * (1.0 + buff.magnitude(BuffData.Rarity.GOLD).x)))

	# Resistance must never reach certainty, or a unit becomes unkillable.
	var piled := UnitInstance.create(aegis, BoardModel.TEAM_B)
	for i in 8:
		piled.add_battle_modifier(StatModifier.make(StatModifier.Stat.RESIST,
			StatModifier.Mode.FLAT, 0.45))
	_check("resistance is capped short of total immunity",
		piled.resist() <= UnitInstance.MAX_RESIST
		and piled.damage_taken_multiplier() > 0.0,
		"%.2f resist, x%.3f taken" % [
			piled.resist(), piled.damage_taken_multiplier()])


func _only_resister(who: UnitData) -> bool:
	for d in _roster().units:
		if d.id != who.id and d.damage_resist > 0.0:
			return false
	return true


func _test_retribution() -> void:
	_section("Retribution sends it back")
	var aegis := _find("aegis")
	var ab: AbilityData = aegis.ability
	_check("Retribution is a reflect", ab.kind == AbilityData.Kind.REFLECT)
	_check("and it sends back more than it took",
		ab.reflect_percent >= 2.0, "x%.1f" % ab.reflect_percent)

	var b := BoardModel.new()
	var me := UnitInstance.create(aegis, BoardModel.TEAM_B)
	var melee := UnitInstance.create(
		BoardModel.at_tier(_find("reaver"), 3), BoardModel.TEAM_A)
	var bow := UnitInstance.create(
		BoardModel.at_tier(_find("archer"), 3), BoardModel.TEAM_A)
	b.force_place(me, Vector2i(2, 6))
	b.force_place(melee, Vector2i(2, 5))
	b.force_place(bow, Vector2i(5, 1))
	var sim := CombatSim.new()
	sim.setup(b, 4)
	var plain := me.damage_taken_multiplier()
	me.mana = UnitInstance.MANA_MAX
	var bow_hp := bow.current_hp
	for i in 40:
		sim.step()

	_check("casting it puts the reflect up", me.is_reflecting())
	_check("and it hardens while it holds",
		me.damage_taken_multiplier() < plain,
		"x%.2f against x%.2f" % [me.damage_taken_multiplier(), plain])
	# Unlike the Paragon's taunt, this one does not plant the caster.
	_check("but it can still move and swing, unlike a taunt",
		me.can_move_now() and me.can_attack_now())

	var sent_back := 0.0
	var hit_the_bow := false
	for e in sim.events:
		if e.kind != "reflect":
			continue
		sent_back += e.amount
		if e.target_uid == bow.uid:
			hit_the_bow = true
	_check("something adjacent took damage back", sent_back > 0.0,
		"nothing was reflected at all")
	_check("but the archer across the board took none of it",
		not hit_the_bow and is_equal_approx(bow.current_hp, bow_hp),
		"the bow lost %.0f" % (bow_hp - bow.current_hp))

	# Two of them facing each other must not bounce a hit forever.
	var duel := BoardModel.new()
	var x := UnitInstance.create(aegis, BoardModel.TEAM_B)
	var y := UnitInstance.create(aegis, BoardModel.TEAM_A)
	duel.force_place(x, Vector2i(2, 6))
	duel.force_place(y, Vector2i(2, 5))
	var duel_sim := CombatSim.new()
	duel_sim.setup(duel, 5)
	x.mana = UnitInstance.MANA_MAX
	y.mana = UnitInstance.MANA_MAX
	for i in 60:
		if duel_sim.is_finished():
			break
		duel_sim.step()
	_check("two reflectors facing each other do not bounce a hit forever",
		duel_sim.events.size() < 4000,
		"%d events, which smells like a loop" % duel_sim.events.size())
	_check("and both are still standing or properly dead",
		x.current_hp >= 0.0 and y.current_hp >= 0.0)


func _test_shadowstep_bait() -> void:
	_section("Shadowstep takes the deepest, so it can be baited")
	# The Engineer's ten second build makes it the obvious Shadowstep victim.
	# The counter is to stand something tougher further back, because the blink
	# picks by depth — this is the strategy, so it gets an assertion.
	var b := BoardModel.new()
	var killer := UnitInstance.create(
		BoardModel.at_tier(_find("assassin"), 4), BoardModel.TEAM_A)
	var engineer := UnitInstance.create(_find("engineer"), BoardModel.TEAM_B)
	var decoy := UnitInstance.create(
		BoardModel.at_tier(_find("aegis"), 4), BoardModel.TEAM_B)
	b.force_place(killer, Vector2i(2, 1))
	b.force_place(engineer, Vector2i(2, 8))
	b.force_place(decoy, Vector2i(2, 10))
	# Asked of the targeting directly, without running setup(): the Assassin's
	# opener fires during setup and, at tier 4, kills a mid-build Engineer
	# outright — so by the time the board settles the unit this is about is gone,
	# and the check would pass or fail for the wrong reason.
	var sim := CombatSim.new()
	sim.board = b
	var picked := sim._backline_enemy(killer)
	_check("the blink lands on the unit standing furthest back",
		picked == decoy,
		"it went for %s" % ("nothing" if picked == null
			else picked.data.display_name))

	# Without the decoy it takes the Engineer, which is the problem being solved.
	var b2 := BoardModel.new()
	var killer2 := UnitInstance.create(
		BoardModel.at_tier(_find("assassin"), 4), BoardModel.TEAM_A)
	var eng2 := UnitInstance.create(_find("engineer"), BoardModel.TEAM_B)
	var friend := UnitInstance.create(_find("archer"), BoardModel.TEAM_B)
	b2.force_place(killer2, Vector2i(2, 1))
	b2.force_place(eng2, Vector2i(2, 10))
	b2.force_place(friend, Vector2i(2, 8))
	var sim2 := CombatSim.new()
	sim2.board = b2
	var found := sim2._backline_enemy(killer2)
	_check("with nothing behind it, the Engineer is the one that gets found",
		found == eng2,
		"picked %s at %s; engineer at %s, friend at %s" % [
			"nothing" if found == null else found.data.display_name,
			"-" if found == null else str(found.cell), eng2.cell, friend.cell])


func _test_pathing_weighs_the_detour() -> void:
	_section("Pathing weighs the detour against the wait")
	_check("a friendly tile costs more to path through than an empty one",
		CombatSim.CONGESTION_COST > 1)

	# A wall with two gaps: one right in front, one across the board. The near
	# gap has one of our own standing in it.
	#
	# The old field treated any occupied tile as solid, so it would march all the
	# way to the far gap to avoid a single body — a twelve step detour to dodge a
	# one second wait. Charging CONGESTION_COST instead makes that a comparison
	# rather than a reflex.
	var gated := MapData.new()
	gated.width = 6
	gated.height = 11
	gated.has_neutral = true
	gated.rows = PackedStringArray([
		"......", "......", "......",
		".####.",
		"......", "......", "......",
		".####.",
		"......", "......", "......"])
	_check("the two-gate map is legal", gated.is_valid(), gated.invalid_reason())
	BoardModel.use_map(gated)

	var b := BoardModel.new()
	var walker := UnitInstance.create(_find("lancer"), BoardModel.TEAM_B)
	var plug := UnitInstance.create(_find("warden"), BoardModel.TEAM_B)
	var mark := UnitInstance.create(_find("warden"), BoardModel.TEAM_A)
	b.force_place(walker, Vector2i(0, 8))
	b.force_place(plug, Vector2i(0, 7))
	b.force_place(mark, Vector2i(0, 1))
	var sim := CombatSim.new()
	sim.setup(b, 4)
	walker.target = mark
	var step := sim._next_step(walker)
	_check("it holds at the near gate rather than crossing to the far one",
		step == Vector2i(0, 7),
		"it chose %s; the far gate would send it sideways to (1, 8)" % step)

	# The other half has to still work: a detour that is genuinely short is taken
	# rather than waited out.
	BoardModel.reset_map()
	var open_field := BoardModel.new()
	var w2 := UnitInstance.create(_find("lancer"), BoardModel.TEAM_B)
	var block := UnitInstance.create(_find("warden"), BoardModel.TEAM_B)
	var foe2 := UnitInstance.create(_find("warden"), BoardModel.TEAM_A)
	open_field.force_place(w2, Vector2i(2, 8))
	open_field.force_place(block, Vector2i(2, 7))
	open_field.force_place(foe2, Vector2i(2, 2))
	var sim2 := CombatSim.new()
	sim2.setup(open_field, 4)
	w2.target = foe2
	var step2 := sim2._next_step(w2)
	_check("but on open ground it walks round a single body instead of waiting",
		step2 != Vector2i(2, 7) and step2 != w2.cell,
		"it chose %s" % step2)
	_check("and the tile it chose is free",
		open_field.unit_at(step2) == null, "%s is occupied" % step2)


func _test_targets_are_not_all_the_same() -> void:
	_section("Attack choice has some give in it")
	_check("there is a slack band at all", CombatSim.TARGET_SLACK > 0)

	# Six of ours facing three of theirs, all within the band. Under strict
	# nearest-enemy every one of ours picks the same body and the rest of their
	# line is unopposed.
	var b := BoardModel.new()
	var mine: Array[UnitInstance] = []
	for x in 3:
		for y in [8, 9]:
			var u := UnitInstance.create(_find("lancer"), BoardModel.TEAM_B)
			b.force_place(u, Vector2i(x + 1, y))
			mine.append(u)
	var theirs: Array[UnitInstance] = []
	for x in 3:
		var f := UnitInstance.create(
			BoardModel.at_tier(_find("warden"), 6), BoardModel.TEAM_A)
		b.force_place(f, Vector2i(x + 1, 6))
		theirs.append(f)
	var sim := CombatSim.new()
	sim.setup(b, 17)
	for u in mine:
		u.target = null
	var chosen := {}
	for u in mine:
		var pick := sim._choose_enemy(u)
		if pick != null:
			chosen[pick.uid] = true
	_check("they do not all converge on one body",
		chosen.size() > 1, "all %d picked the same target" % mine.size())

	# But a choice, once made, has to stick, or a unit re-decides every tick and
	# walks back and forth between two enemies forever.
	var first := mine[0]
	var held := sim._choose_enemy(first)
	first.target = held
	var same := true
	for i in 5:
		if sim._choose_enemy(first) != held:
			same = false
	_check("and a unit sticks with what it is already fighting", same,
		"it changed its mind while its target was still in reach")

	# The seeded rng means a replay is still exact.
	var runs: Array[int] = []
	for i in 3:
		var rb := BoardModel.new()
		for k in 4:
			rb.place(UnitInstance.create(_find("archer"), BoardModel.TEAM_B),
				Vector2i(k + 1, 8))
			rb.place(UnitInstance.create(_find("lancer"), BoardModel.TEAM_A),
				Vector2i(k + 1, 2))
		var rs := CombatSim.new()
		rs.setup(rb, 99)
		rs.run()
		runs.append(rs.events.size())
	_check("random targeting is still deterministic for a given seed",
		runs[0] == runs[1] and runs[1] == runs[2], str(runs))


func _test_levy_is_capped() -> void:
	_section("Levy tops up to a headcount")
	var levy := _pool().by_id(&"levy")
	var target := roundi(levy.magnitude(BuffData.Rarity.GOLD).x)
	_check("Levy fills to a fixed number now, not to the board's edges",
		target > 1 and target <= 40, "target is %d" % target)
	_check("and it is the same at every rarity, being gold-only",
		is_equal_approx(levy.magnitude(BuffData.Rarity.BRONZE).x, float(target)))
	var text := levy.describe(BuffData.Rarity.GOLD)
	_check("its card says the number rather than promising the whole half",
		text.contains(str(target)) and not text.to_lower().contains("every free tile"),
		text)


func _test_reaver() -> void:
	_section("The Reaver")
	var blade := _find("reaver")
	var ab: AbilityData = blade.ability
	_check("it hits harder than anything else that swings this fast",
		blade.attack_damage * blade.attack_speed
		> _find("archer").attack_damage * _find("archer").attack_speed,
		"%.0f dps against the Archer's %.0f" % [
			blade.attack_damage * blade.attack_speed,
			_find("archer").attack_damage * _find("archer").attack_speed])
	# Against the roster rather than a magic number: the brief is "high damage,
	# low survivability", so what has to be true is that nothing as fragile as it
	# hits as hard, and that it sits in the soft half of the roster.
	var healths: Array[float] = []
	for d in _roster().units:
		healths.append(d.max_hp)
	healths.sort()
	var median: float = healths[healths.size() / 2]
	_check("it is in the soft half of the roster", blade.max_hp < median,
		"%.0f health against a median of %.0f" % [blade.max_hp, median])
	var mine := blade.attack_damage * blade.attack_speed
	var out_dps := 0
	for d in _roster().units:
		if String(d.id) == "reaver" or d.max_hp > blade.max_hp:
			continue
		if d.attack_damage * d.attack_speed > mine:
			out_dps += 1
	_check("and nothing that fragile puts out more damage", out_dps == 0,
		"%d softer units out-damage it" % out_dps)
	_check("Execute is a burst on one target", ab.kind == AbilityData.Kind.FOCUS_BURST)
	_check("and it does not splash, so it is a duel and not a bomb",
		is_zero_approx(ab.splash_damage) and ab.splash_radius == 0)

	# The whole reason Execute is written as a multiple: a flat burst does not
	# scale with tier or with any buff, so a tier 6 would hit for the same as a
	# tier 1. The Pyre still has that problem; this one must not.
	_check("its burst is a multiple of its attack, not a flat number",
		ab.burst_attack_multiple > 0.0)
	var sim := CombatSim.new()
	var t1 := UnitInstance.create(blade, BoardModel.TEAM_B)
	var t6 := UnitInstance.create(
		BoardModel.at_tier(blade, 6), BoardModel.TEAM_B)
	var b1 := sim.burst_damage_of(t1, ab)
	var b6 := sim.burst_damage_of(t6, ab)
	_check("so a tier 6 Execute hits far harder than a tier 1",
		b6 > b1 * 20.0, "%.0f against %.0f" % [b6, b1])
	_check("and it is worth casting at all — bigger than an ordinary swing",
		b1 > t1.stat(StatModifier.Stat.ATTACK_DAMAGE) * 2.0,
		"burst %.0f against a swing of %.0f" % [
			b1, t1.stat(StatModifier.Stat.ATTACK_DAMAGE)])

	# Whetstone raises attack, so it has to reach the burst too.
	var buffed := UnitInstance.create(blade, BoardModel.TEAM_B)
	var tb := TeamBuffs.new()
	tb.add(load("res://data/buffs/whetstone.tres"), BuffData.Rarity.GOLD)
	tb.apply_to(buffed)
	_check("and Whetstone's attack bonus reaches the burst",
		sim.burst_damage_of(buffed, ab) > b1 * 2.0,
		"%.0f buffed against %.0f bare" % [sim.burst_damage_of(buffed, ab), b1])
	_check("Whetstone raises attack and attack speed",
		buffed.stat(StatModifier.Stat.ATTACK_DAMAGE) > blade.attack_damage
		and buffed.stat(StatModifier.Stat.ATTACK_SPEED) > blade.attack_speed)

	# It has to actually land in a real fight.
	var board := BoardModel.new()
	var me := UnitInstance.create(blade, BoardModel.TEAM_B)
	# A Spire: rooted and harmless, so this measures whether the Reaver charges
	# its bar and casts, not whether it survives long enough to. A tier 5 Warden
	# was the first thing I tried and it one-shots a 65 health unit.
	var mark := UnitInstance.create(
		BoardModel.at_tier(_find("spire"), 5), BoardModel.TEAM_A)
	board.force_place(me, Vector2i(2, 6))
	board.force_place(mark, Vector2i(2, 5))
	var live := CombatSim.new()
	live.setup(board, 12)
	var cast := false
	for i in 200:
		if live.is_finished():
			break
		live.step()
		for e in live.events:
			if e.kind == "ability" and e.uid == me.uid:
				cast = true
		if cast:
			break
	_check("it charges its bar by swinging and gets the cast off", cast,
		"never cast in 20 seconds of fighting")


func _test_roster_order() -> void:
	_section("The roster reads simplest first")
	var roster := _roster()
	var ids: Array[String] = []
	for u in roster.units:
		ids.append(String(u.id))
	# The table's order is the menu's order and the starter loadout's order, so
	# it is a real decision rather than a listing: easy units first.
	_check("the Warden opens the roster", ids[0] == "warden", str(ids.slice(0, 3)))
	for late in ["engineer", "spire", "paragon"]:
		_check("the %s is in the back half, where the fiddly ones live" % late,
			ids.find(late) >= ids.size() / 2,
			"%s sits at %d of %d" % [late, ids.find(late), ids.size()])
	for early in ["warden", "archer", "lancer"]:
		_check("the %s is in the front half" % early,
			ids.find(early) < ids.size() / 2,
			"%s sits at %d of %d" % [early, ids.find(early), ids.size()])

	# The starter loadout is the first few off the table, so the order decides
	# what a new player is handed. It must not hand them the hard ones.
	var starter := load(GameSetup.FALLBACK_LOADOUT) as LoadoutData
	_check("the fallback loadout exists", starter != null)
	if starter == null:
		return
	var hard := ["engineer", "spire", "paragon", "conjurer", "transcendence"]
	var given: Array[String] = []
	for u in starter.units:
		given.append(String(u.id))
	var tricky := 0
	for id in given:
		if hard.has(id):
			tricky += 1
	_check("and the starting five are units you can read at a glance",
		tricky == 0, "starter holds %s" % ", ".join(given))
	# Named, because the starter is a side effect of table order and inserting a
	# unit near the front silently pushes one out. That happened once already.
	_check("the starting five are the five the table means them to be",
		given == ["warden", "archer", "lancer", "reaver", "vexer"],
		", ".join(given))
	_check("neither summon is pickable from it",
		not given.has("wisp") and not given.has("sentry"), ", ".join(given))


func _test_paragon_empowerment() -> void:
	_section("The Paragon empowers alone")
	var par := _find("paragon")
	_check("it is the kind of unit that empowers", par.solo_empower)
	_check("and empowering is worth something",
		par.empower_hp_mult > 1.5 and par.empower_damage_mult > 1.5
		and par.empower_splash_radius >= 1)

	# One on the board: empowered.
	var b := BoardModel.new()
	var solo := UnitInstance.create(par, BoardModel.TEAM_B)
	b.place(solo, Vector2i(2, 8))
	b.place(UnitInstance.create(_find("warden"), BoardModel.TEAM_A), Vector2i(2, 1))
	var sim := CombatSim.new()
	sim.setup(b, 3)
	_check("one on the board is empowered", solo.empowered)
	_check("and it really is bigger",
		solo.stat(StatModifier.Stat.MAX_HP) > par.max_hp * 2.0
		and solo.stat(StatModifier.Stat.ATTACK_DAMAGE) > par.attack_damage * 1.5,
		"%.0f hp, %.0f damage" % [
			solo.stat(StatModifier.Stat.MAX_HP),
			solo.stat(StatModifier.Stat.ATTACK_DAMAGE)])
	_check("and it starts the round at that full health",
		is_equal_approx(solo.current_hp, solo.stat(StatModifier.Stat.MAX_HP)))

	# Two on the board: neither. Fielding a second is a downgrade, not a stack.
	var b2 := BoardModel.new()
	var a := UnitInstance.create(par, BoardModel.TEAM_B)
	var c := UnitInstance.create(par, BoardModel.TEAM_B)
	b2.place(a, Vector2i(2, 8))
	b2.place(c, Vector2i(3, 8))
	b2.place(UnitInstance.create(_find("warden"), BoardModel.TEAM_A), Vector2i(2, 1))
	var sim2 := CombatSim.new()
	sim2.setup(b2, 3)
	_check("two on the board and neither is empowered",
		not a.empowered and not c.empowered)
	_check("the default cap is one", sim2.empowered_cap(BoardModel.TEAM_B) == 1)

	# Gold Solitude raises the cap to two. Silver and bronze do not.
	var gold := TeamBuffs.new()
	gold.add(load("res://data/buffs/solitude.tres"), BuffData.Rarity.GOLD)
	_check("gold Solitude raises the cap to two", gold.empowered_cap() == 2)
	for lesser in [BuffData.Rarity.BRONZE, BuffData.Rarity.SILVER]:
		var tb := TeamBuffs.new()
		tb.add(load("res://data/buffs/solitude.tres"), lesser)
		_check("but %s Solitude does not" % BuffData.Rarity.keys()[lesser],
			tb.empowered_cap() == 1)

	var b3 := BoardModel.new()
	var d := UnitInstance.create(par, BoardModel.TEAM_B)
	var e := UnitInstance.create(par, BoardModel.TEAM_B)
	b3.place(d, Vector2i(2, 8))
	b3.place(e, Vector2i(3, 8))
	b3.place(UnitInstance.create(_find("warden"), BoardModel.TEAM_A), Vector2i(2, 1))
	var sim3 := CombatSim.new()
	sim3.team_buffs = {BoardModel.TEAM_B: gold}
	sim3.setup(b3, 3)
	_check("so under gold Solitude both of two are empowered",
		d.empowered and e.empowered)
	_check("and the cap belongs to the team that holds the buff, not the board",
		sim3.empowered_cap(BoardModel.TEAM_A) == 1)

	# Anything arriving after the bell stays small, whatever brought it.
	var b4 := BoardModel.new()
	var spire := UnitInstance.create(
		BoardModel.at_tier(_find("spire"), 3), BoardModel.TEAM_B)
	var only_paragons: Array[UnitData] = [par]
	b4.team_merge_pools[BoardModel.TEAM_B] = only_paragons
	b4.place(spire, Vector2i(2, 8))
	b4.place(UnitInstance.create(_find("warden"), BoardModel.TEAM_A), Vector2i(2, 1))
	var sim4 := CombatSim.new()
	sim4.setup(b4, 9)
	spire.mana = UnitInstance.MANA_MAX
	for i in 40:
		sim4.step()
	var raised := 0
	var wrongly_empowered := 0
	for u in b4.all_units():
		if String(u.data.id) != "paragon":
			continue
		raised += 1
		if u.empowered:
			wrongly_empowered += 1
	_check("a Spire really did raise some Paragons", raised > 0,
		"nothing was raised, so this proves nothing")
	_check("but nothing raised after the bell is ever empowered",
		wrongly_empowered == 0, "%d of %d came up empowered" % [
			wrongly_empowered, raised])


func _test_paragon_in_battle() -> void:
	_section("Empowered swings and Last Stand")
	var par := _find("paragon")
	var ab: AbilityData = par.ability
	_check("Last Stand is a taunt", ab.kind == AbilityData.Kind.TAUNT)
	_check("and only an empowered Paragon may use it", ab.requires_empowered)
	_check("it makes it very hard to kill while it holds",
		ab.taunt_damage_taken <= 0.10, "takes x%.2f" % ab.taunt_damage_taken)

	# The empowered swing lands on the square around what it hit.
	var b := BoardModel.new()
	var p := UnitInstance.create(par, BoardModel.TEAM_B)
	b.place(p, Vector2i(2, 6))
	var struck: Array[UnitInstance] = []
	for c in [Vector2i(2, 5), Vector2i(1, 4), Vector2i(3, 4)]:
		var m := UnitInstance.create(
			BoardModel.at_tier(_find("warden"), 4), BoardModel.TEAM_A)
		b.place(m, c)
		struck.append(m)
	var sim := CombatSim.new()
	sim.setup(b, 4)
	_check("the lone Paragon is empowered for this", p.empowered)
	var pool: Array[float] = []
	for m in struck:
		pool.append(m.current_hp + m.shield)
	var multi := 0
	for i in 60:
		sim.step()
		var hurt := 0
		for j in struck.size():
			if struck[j].current_hp + struck[j].shield < pool[j]:
				hurt += 1
		multi = maxi(multi, hurt)
		if multi > 1:
			break
	_check("one swing damages more than the unit it aimed at", multi > 1,
		"only %d of 3 were ever touched" % multi)

	# The taunt has to *pull* a unit, not merely agree with what it already did,
	# so every foe gets a closer friendly target to prefer first.
	# force_place, not place: the bait has to stand in the enemy half to be the
	# closer target, and place() honours the deploy zones. Getting this wrong the
	# first time left the bait off the board entirely and made the test pass for
	# the wrong reason.
	var b2 := BoardModel.new()
	var q := UnitInstance.create(par, BoardModel.TEAM_B)
	b2.force_place(q, Vector2i(2, 8))
	var near_foe := UnitInstance.create(_find("archer"), BoardModel.TEAM_A)
	var far_foe := UnitInstance.create(_find("archer"), BoardModel.TEAM_A)
	b2.force_place(near_foe, Vector2i(2, 5))
	b2.force_place(far_foe, Vector2i(5, 0))
	var bait := UnitInstance.create(_find("archer"), BoardModel.TEAM_B)
	var far_bait := UnitInstance.create(_find("archer"), BoardModel.TEAM_B)
	b2.force_place(bait, Vector2i(2, 4))
	b2.force_place(far_bait, Vector2i(5, 1))
	_check("the taunt test board is actually set up",
		b2.all_units().size() == 5,
		"%d units placed, wanted 5" % b2.all_units().size())
	var sim2 := CombatSim.new()
	sim2.setup(b2, 6)
	_check("before the taunt, the near foe prefers the closer bait",
		sim2.board.nearest_enemy(near_foe) == bait,
		"it was already looking at the Paragon, so this proves nothing")
	q.mana = UnitInstance.MANA_MAX
	for i in 12:
		sim2.step()
	_check("casting it plants the Paragon", q.is_taunting())
	_check("it cannot move while it holds", not q.can_move_now())
	_check("and it cannot swing either", not q.can_attack_now())
	_check("it takes a tenth of the damage",
		is_equal_approx(q.taunt_damage_taken(), ab.taunt_damage_taken))
	_check("a foe inside the radius is pulled off the bait onto it",
		near_foe.target == q,
		"near foe still aimed at %s" % near_foe.target.data.display_name)
	_check("a foe outside it is left alone",
		far_foe.target != q,
		"a foe %d tiles away was pulled, radius is %d" % [
			BoardModel.tile_distance(q.cell, far_foe.cell), ab.taunt_radius])

	# It has to end, or the Paragon never fights again. On its own board, so a
	# side being wiped cannot stop the clock before the hold runs out.
	var b3 := BoardModel.new()
	var lone := UnitInstance.create(par, BoardModel.TEAM_B)
	# A tier 1 Warden, deliberately: a tier 6 hits for 1088 and one-shots a 375
	# health Paragon, which ends the round before the hold can run out and makes
	# this test measure nothing.
	var mark := UnitInstance.create(_find("warden"), BoardModel.TEAM_A)
	b3.force_place(lone, Vector2i(2, 9))
	b3.force_place(mark, Vector2i(2, 0))
	var sim3 := CombatSim.new()
	sim3.setup(b3, 8)
	lone.mana = UnitInstance.MANA_MAX
	for i in 12:
		sim3.step()
	_check("the hold is running on the clean board", lone.is_taunting(),
		"never started")
	var ran := 0
	for i in ceili(ab.taunt_duration / CombatSim.TICK) + 10:
		if sim3.is_finished():
			break
		sim3.step()
		ran += 1
	_check("the round did not end early and hide the answer",
		not sim3.is_finished(),
		"finished after %d ticks; paragon alive=%s on %.0f hp" % [
			ran, lone.is_alive(), lone.current_hp])
	var q_end := lone
	_check("the hold ends on its own", not q_end.is_taunting(),
		"%.1fs still left" % q_end.taunt_left)
	_check("and it can act again afterwards",
		q_end.can_move_now() and q_end.can_attack_now())
	_check("and takes full damage again",
		is_equal_approx(q_end.taunt_damage_taken(), 1.0))


func _test_tyrant() -> void:
	_section("The Tyrant is your problem")
	var tyrant := _find("tyrant")
	_check("it has no ability, it is just a body", tyrant.ability == null)
	_check("and it is plainly above curve",
		tyrant.attack_damage > _find("warden").attack_damage
		and tyrant.max_hp >= _find("warden").max_hp,
		"%.0f dmg / %.0f hp" % [tyrant.attack_damage, tyrant.max_hp])
	_check("it burdens the units around it",
		tyrant.burden_radius > 0 and tyrant.burden_percent > 0.0)

	var b := BoardModel.new()
	var ty := UnitInstance.create(tyrant, BoardModel.TEAM_B)
	var near := UnitInstance.create(_find("archer"), BoardModel.TEAM_B)
	var away := UnitInstance.create(_find("archer"), BoardModel.TEAM_B)
	var foe := UnitInstance.create(_find("archer"), BoardModel.TEAM_A)
	b.place(ty, Vector2i(2, 8))
	b.place(near, Vector2i(3, 8))
	b.place(away, Vector2i(0, 10))
	b.place(foe, Vector2i(2, 1))
	var sim := CombatSim.new()
	sim.setup(b, 2)
	_check("a friend standing next to it takes more damage",
		sim._burden_on(near) > 1.0, "x%.2f" % sim._burden_on(near))
	_check("a friend well clear of it does not",
		is_equal_approx(sim._burden_on(away), 1.0), "x%.2f" % sim._burden_on(away))
	_check("the Tyrant does not burden itself",
		is_equal_approx(sim._burden_on(ty), 1.0), "x%.2f" % sim._burden_on(ty))
	_check("and it is not a gift to the enemy either",
		is_equal_approx(sim._burden_on(foe), 1.0), "x%.2f" % sim._burden_on(foe))

	# Asked at the moment of the hit, so it stops mattering the instant the
	# Tyrant is gone rather than leaving stale aura state behind.
	ty.current_hp = 0.0
	b.remove(ty)
	_check("kill the Tyrant and the burden lifts immediately",
		is_equal_approx(sim._burden_on(near), 1.0), "x%.2f" % sim._burden_on(near))


func _test_spire_never_raises_a_spire() -> void:
	_section("A Spire never raises a Spire")
	var spire := _find("spire")
	var ab: AbilityData = spire.ability
	_check("Raise Host spends its caster and rolls at random",
		ab.consumes_caster and ab.summon_random)

	var board := BoardModel.new()
	board.team_merge_pools[BoardModel.TEAM_B] = _roster().units.duplicate()
	var sim := CombatSim.new()
	sim.board = board
	var pool := sim._random_summon_pool(BoardModel.TEAM_B)
	var ids := {}
	for d in pool:
		ids[String(d.id)] = true
	_check("the roster it rolls from has the Spire taken out",
		not ids.has("spire"), "pool: %s" % str(ids.keys()))
	_check("but everything else is still rollable",
		pool.size() == _roster().units.size() - 1,
		"%d of %d" % [pool.size(), _roster().units.size()])

	# Written against the mechanic, not the name: anything that spends itself to
	# summon would otherwise pay for its own replacement.
	var recursive := 0
	for d in _roster().units:
		var a: AbilityData = d.ability
		if a != null and a.kind == AbilityData.Kind.SUMMON and a.consumes_caster:
			recursive += 1
	_check("and the rule catches every self-spending summoner there is",
		recursive == _roster().units.size() - pool.size(),
		"%d such units, %d filtered" % [
			recursive, _roster().units.size() - pool.size()])


func _test_transcendence_rate() -> void:
	_section("The apex beam reloads")
	var apex := BoardModel.at_tier(_find("transcendence"), 6)
	var five := BoardModel.at_tier(_find("transcendence"), 5)
	var u := UnitInstance.create(apex, BoardModel.TEAM_B)
	var u5 := UnitInstance.create(five, BoardModel.TEAM_B)
	_check("tier 6 fires slower than tier 5, not just harder",
		u.attack_interval() > u5.attack_interval() * 1.5,
		"t6 every %.2fs, t5 every %.2fs" % [
			u.attack_interval(), u5.attack_interval()])
	_check("it is the slowest thing on the board", _slowest_is(apex),
		"something else swings slower than the apex beam")
	_check("but it still fires inside a normal round",
		u.attack_interval() < 8.0, "every %.2fs" % u.attack_interval())


func _slowest_is(who: UnitData) -> bool:
	var mine := UnitInstance.create(who, BoardModel.TEAM_B).attack_interval()
	for d in _roster().units:
		var top := BoardModel.at_tier(d, 6)
		if top == null or top.id == who.id or not top.can_attack:
			continue
		if UnitInstance.create(top, BoardModel.TEAM_B).attack_interval() > mine:
			return false
	return true


func _test_conjurer_shape() -> void:
	var conjurer := _find("conjurer")
	_check("the Conjurer is a slow, tanky body",
		conjurer.max_hp >= 140.0 and conjurer.attack_speed <= 0.65,
		"%.0f hp at %.2f attacks/s" % [conjurer.max_hp, conjurer.attack_speed])

	var board := BoardModel.new()
	var caster := UnitInstance.create(BoardModel.at_tier(conjurer, 5), BoardModel.TEAM_B)
	board.place(caster, Vector2i(2, 8))
	board.place(UnitInstance.create(_find("warden"), BoardModel.TEAM_A), Vector2i(2, 2))
	var sim := CombatSim.new()
	sim.setup(board, 19)

	var wisp: UnitInstance = null
	for u in board.units_of(BoardModel.TEAM_B):
		if String(u.data.id) == "wisp":
			wisp = u
	_check("the opening summon puts a wisp on the board", wisp != null)
	if wisp == null:
		return
	_check("a wisp matches the tier of the Conjurer that called it",
		wisp.data.tier == caster.data.tier,
		"tier %d wisp from a tier %d Conjurer" % [
			wisp.data.tier, caster.data.tier])

	var base := load("res://data/units/wisp_t1.tres") as UnitData
	_check("so its health and damage scale with his level",
		is_equal_approx(wisp.data.max_hp, base.max_hp * 16.0)
		and is_equal_approx(wisp.data.attack_damage, base.attack_damage * 16.0),
		"%.0f hp, %.0f damage" % [wisp.data.max_hp, wisp.data.attack_damage])
	_check("the opening wisp is free to appear away from its summoner",
		BoardModel.tile_distance(wisp.cell, caster.cell) >= 1
		and board.can_deploy(BoardModel.TEAM_B, wisp.cell),
		"wisp at %s, Conjurer at %s" % [wisp.cell, caster.cell])


func _test_horn_reach_and_power() -> void:
	var herald := _find("herald")
	var ab: AbilityData = herald.ability
	var board := BoardModel.new()
	var spot := Vector2i(2, 8)
	var horn := UnitInstance.create(herald, BoardModel.TEAM_B)
	board.place(horn, spot)

	var orthogonal: Array[UnitInstance] = []
	for step in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
		var mate := UnitInstance.create(_find("lancer"), BoardModel.TEAM_B)
		if board.place(mate, spot + step):
			orthogonal.append(mate)
	var corner := UnitInstance.create(_find("lancer"), BoardModel.TEAM_B)
	board.place(corner, spot + Vector2i(1, 1))
	board.place(UnitInstance.create(_find("warden"), BoardModel.TEAM_A), Vector2i(2, 2))

	var corner_before := corner.attack_interval()
	var sim := CombatSim.new()
	sim.setup(board, 23)

	var buffed := 0
	for mate in orthogonal:
		if mate.battle_modifiers.size() > 0:
			buffed += 1
	_check("the horn reaches all four units directly beside it",
		buffed == orthogonal.size() and orthogonal.size() == 4,
		"buffed %d of %d neighbours" % [buffed, orthogonal.size()])
	_check("it does not reach diagonally — four units is the ceiling",
		corner.battle_modifiers.is_empty()
		and is_equal_approx(corner.attack_interval(), corner_before))

	var plain := ab.aura_percent_per_tier * 1.0
	var loud := UnitInstance.create(herald, BoardModel.TEAM_B)
	var fanfare := TeamBuffs.new()
	fanfare.add(_pool().by_id(&"fanfare"), BuffData.Rarity.GOLD)
	fanfare.apply_to(loud)
	_check("Fanfare makes the horn itself louder",
		loud.stat(StatModifier.Stat.AURA_POWER) > 1.0,
		"aura power is %.2f" % loud.stat(StatModifier.Stat.AURA_POWER))
	_check("a Fanfare Herald hands out a bigger speed buff than a plain one",
		plain * loud.stat(StatModifier.Stat.AURA_POWER) > plain,
		"%.0f%% vs %.0f%%" % [
			plain * loud.stat(StatModifier.Stat.AURA_POWER) * 100.0, plain * 100.0])
	_check("aura power sits at 1x with no Fanfare",
		is_equal_approx(horn.stat(StatModifier.Stat.AURA_POWER), 1.0))


func _test_round_boundaries() -> void:
	var held := TeamBuffs.new()
	held.add(_pool().by_id(&"war_drums"), BuffData.Rarity.GOLD)
	var u := _unit(0, BoardModel.TEAM_B)
	var clean := u.attack_interval()

	held.resync(u)
	var once := u.attack_interval()
	held.resync(u)
	held.resync(u)
	_check("re-applying buffs at round start does not stack them up",
		is_equal_approx(u.attack_interval(), once) and once < clean,
		"%.4f after one pass, %.4f after three" % [once, u.attack_interval()])
	_check("a resync leaves exactly one modifier per buff held",
		u.modifiers.size() == 1, "%d modifiers" % u.modifiers.size())

	u.mana = 88.0
	u.shield = 120.0
	u.haste_stacks = 4
	u.stealth_left = 2.0
	u.add_battle_modifier(StatModifier.make(
		StatModifier.Stat.ATTACK_DAMAGE, StatModifier.Mode.PERCENT, 5.0))
	u.apply_dot(9.0, 3, 0.5, 1)
	u.current_hp = 5.0

	u.reset_for_battle()
	_check("mana, shield, poison and battle stat buffs are all wiped at the round boundary",
		is_zero_approx(u.mana) and is_zero_approx(u.shield)
		and u.dots.is_empty() and u.battle_modifiers.is_empty()
		and u.haste_stacks == 0 and is_zero_approx(u.stealth_left))
	_check("the buffs you picked survive that reset",
		u.modifiers.size() == 1 and is_equal_approx(u.attack_interval(), once))
	_check("and it comes back at full health",
		is_equal_approx(u.current_hp, u.stat(StatModifier.Stat.MAX_HP)))


func _test_range_bands() -> void:
	_section("Range bands")

	# The value IS the tile count, so these numbers are load-bearing. New bands
	# may only ever be appended at the top: inserting one in the middle would
	# silently hand a tile of reach to every unit above it.
	_check("the ladder starts where it always did",
		UnitData.RangeBand.MELEE == 1 and UnitData.RangeBand.MEDIUM == 2
		and UnitData.RangeBand.LONG == 3 and UnitData.RangeBand.SNIPER == 4)
	_check("and it now runs on past Sniper",
		UnitData.RangeBand.SIEGE == 5 and UnitData.RangeBand.HORIZON == 6
		and UnitData.RangeBand.UNLIMITED == 7)
	_check("each band has a name you can put on screen",
		UnitData.band_name(1) == "Melee" and UnitData.band_name(2) == "Medium"
		and UnitData.band_name(3) == "Long" and UnitData.band_name(4) == "Sniper"
		and UnitData.band_name(5) == "Siege" and UnitData.band_name(6) == "Horizon"
		and UnitData.band_name(7) == "Unlimited")
	_check("every band below the top is simply that many tiles",
		UnitData.band_tiles(1) == 1 and UnitData.band_tiles(2) == 2
		and UnitData.band_tiles(3) == 3 and UnitData.band_tiles(4) == 4
		and UnitData.band_tiles(5) == 5 and UnitData.band_tiles(6) == 6)

	var longest := BoardModel.tile_distance(Vector2i(0, 0),
		Vector2i(BoardModel.WIDTH - 1, BoardModel.HEIGHT - 1))
	_check("the top band covers the whole board, corner to corner",
		UnitData.band_tiles(UnitData.RangeBand.UNLIMITED) >= longest,
		"it reaches %d, the board's longest shot is %d" % [
			UnitData.band_tiles(UnitData.RangeBand.UNLIMITED), longest])
	_check("nonsense bands are clamped, not crashed",
		UnitData.band_tiles(0) == 1
		and UnitData.band_tiles(99) == UnitData.band_tiles(
			UnitData.RangeBand.UNLIMITED)
		and UnitData.band_name(-3) == "Melee")

	var seen := {}
	var strays: PackedStringArray = []
	for u in _roster().units:
		if u.attack_range < 1 or u.attack_range > UnitData.RangeBand.UNLIMITED:
			strays.append("%s at %d" % [u.id, u.attack_range])
		seen[u.range_name()] = true
	_check("every unit sits in a real band", strays.is_empty(), "; ".join(strays))
	_check("the roster spreads across the bands it uses",
		seen.has("Melee") and seen.has("Medium") and seen.has("Long"),
		"bands in use: %s" % str(seen.keys()))
	# Reserved-for-buffs used to include Sniper, which left exactly one printable
	# band above Long and made the Culverin illegal. Two new bands at the top gave
	# the ladder room: Sniper is now somewhere a unit may actually live, and the
	# reserve — the bands only a buff can reach — sits above it.
	var over: PackedStringArray = []
	for u in _roster().units:
		if u.attack_range > UnitData.MAX_PRINTED_BAND:
			over.append("%s at %s" % [u.id, u.range_name()])
	_check("no unit is printed above the highest printable band",
		over.is_empty(), "; ".join(over))
	_check("and bands remain above it for buffs to reach",
		UnitData.RangeBand.UNLIMITED > UnitData.MAX_PRINTED_BAND)
	_check("the heaviest gun on the roster is the one that sits at Sniper",
		seen.has("Sniper"), "bands in use: %s" % str(seen.keys()))

	var want := {
		archer = "Long", warden = "Melee", lancer = "Melee", vexer = "Medium",
		pyre = "Medium", conjurer = "Medium", seraph = "Medium",
		herald = "Melee", revenant = "Melee", assassin = "Melee",
	}
	var off: PackedStringArray = []
	for id in want:
		var unit := _find(id)
		if unit != null and unit.range_name() != want[id]:
			off.append("%s is %s, wanted %s" % [id, unit.range_name(), want[id]])
	var wisp := load("res://data/units/wisp_t1.tres") as UnitData
	if wisp.range_name() != "Melee":
		off.append("wisp is %s" % wisp.range_name())
	_check("every unit is in the band it was given", off.is_empty(),
		"; ".join(off))

	var tiers_hold := true
	var top := _find("archer")
	while top.next_tier != null:
		if top.next_tier.attack_range != top.attack_range:
			tiers_hold = false
		top = top.next_tier
	_check("merging never changes a unit's band", tiers_hold)

	_test_band_reach_in_battle()


func _test_band_reach_in_battle() -> void:
	_check("a long-range unit opens fire from three tiles without walking",
		_shoots_without_closing(_find("archer"), 3),
		"the Archer closed the gap instead of shooting")
	_check("a medium-range unit has to close that same gap first",
		not _shoots_without_closing(_find("vexer"), 3),
		"the Vexer somehow shot from three tiles out")
	_check("the medium unit can shoot once it is two tiles out",
		_shoots_without_closing(_find("vexer"), 2))
	_check("a melee unit has to be right on top of you",
		not _shoots_without_closing(_find("warden"), 2)
		and _shoots_without_closing(_find("warden"), 1))

	var far := _reach_of(_find("archer"))
	var near := _reach_of(_find("vexer"))
	_check("the band is what decides who shoots first", far > near,
		"long reaches %d, medium reaches %d" % [far, near])

	var u := UnitInstance.create(_find("archer"), BoardModel.TEAM_A)
	_check("the Archer starts at Long", u.range_name() == "Long")
	u.apply_modifiers([StatModifier.make(
		StatModifier.Stat.ATTACK_RANGE, StatModifier.Mode.FLAT, 1.0)])
	_check("a range modifier moves a unit up one band",
		u.range_name() == "Sniper" and u.attack_reach() == 4)
	u.apply_modifiers([StatModifier.make(
		StatModifier.Stat.ATTACK_RANGE, StatModifier.Mode.FLAT, 1.0)])
	_check("two bands up puts it into Siege",
		u.range_name() == "Siege" and u.attack_reach() == 5,
		"%s reaching %d" % [u.range_name(), u.attack_reach()])
	u.apply_modifiers([StatModifier.make(
		StatModifier.Stat.ATTACK_RANGE, StatModifier.Mode.FLAT, 2.0)])
	_check("four bands up is the whole board",
		u.range_name() == "Unlimited" and u.attack_reach() >= 15,
		"%s reaching %d" % [u.range_name(), u.attack_reach()])
	u.apply_modifiers([StatModifier.make(
		StatModifier.Stat.ATTACK_RANGE, StatModifier.Mode.FLAT, 4.0)])
	_check("stacking past Unlimited changes nothing",
		u.range_name() == "Unlimited" and u.attack_reach() == UnitData.UNLIMITED_TILES)


func _reach_of(data: UnitData) -> int:
	return UnitInstance.create(data, BoardModel.TEAM_A).attack_reach()


func _shoots_without_closing(data: UnitData, gap: int) -> bool:
	var board := BoardModel.new()
	var shooter := UnitInstance.create(data, BoardModel.TEAM_A)
	var victim := UnitInstance.create(_find("lancer"), BoardModel.TEAM_B)
	board.place(shooter, Vector2i(2, 3))
	board.force_place(victim, Vector2i(2, 3 + gap))

	var start := shooter.cell
	var sim := CombatSim.new()
	sim.setup(board, 5)
	for i in 6:
		sim.step()
	for e in sim.events:
		if e.kind == "attack" and e.uid == shooter.uid:
			return shooter.cell == start
	return false


func _test_exclusive_buffs() -> void:
	_section("Exclusive and one-shot buffs")

	var pool := _pool()
	var gold_only := ["far_sight", "levy", "alchemy"]
	var silver_only := ["conclave", "oblation"]
	var wrong: PackedStringArray = []
	for id in gold_only:
		var b := pool.by_id(StringName(id))
		if not b.available_at(BuffData.Rarity.GOLD) \
				or b.available_at(BuffData.Rarity.SILVER) \
				or b.available_at(BuffData.Rarity.BRONZE):
			wrong.append("%s is not gold-only" % id)
	for id in silver_only:
		var b := pool.by_id(StringName(id))
		if not b.available_at(BuffData.Rarity.SILVER) \
				or b.available_at(BuffData.Rarity.GOLD):
			wrong.append("%s is not silver-only" % id)
	_check("the exclusives only exist at their own rarity", wrong.is_empty(),
		"; ".join(wrong))
	_check("an ordinary buff shows up at every rarity",
		pool.by_id(&"war_drums").available_at(BuffData.Rarity.BRONZE)
		and pool.by_id(&"war_drums").available_at(BuffData.Rarity.GOLD))

	var rng := RandomNumberGenerator.new()
	rng.seed = 4141
	var leaked: PackedStringArray = []
	for i in 80:
		for b in pool.offer(rng, 3, [], {}, BuffData.Rarity.BRONZE):
			if b.is_exclusive():
				leaked.append(String(b.id))
	_check("a bronze round never offers an exclusive", leaked.is_empty(),
		"; ".join(leaked))

	var saw_gold := false
	for i in 80:
		for b in pool.offer(rng, 3, [], {}, BuffData.Rarity.GOLD):
			if String(b.id) == "far_sight":
				saw_gold = true
	_check("a gold round can offer the gold exclusives", saw_gold)

	_check("the one-shots are marked as such",
		pool.by_id(&"levy").is_one_shot() and pool.by_id(&"conclave").is_one_shot()
		and pool.by_id(&"oblation").is_one_shot()
		and not pool.by_id(&"war_drums").is_one_shot())

	_test_far_sight(pool)
	_test_reckless(pool)
	_test_bloodletting(pool)
	_test_conscription(pool)
	_test_wild_merge(pool)
	_test_sacrifice_maths()


func _test_far_sight(pool: BuffPool) -> void:
	var buff := pool.by_id(&"far_sight")
	_check("Far Sight is a flat band, not a percentage", buff.flat)
	var held := TeamBuffs.new()
	held.add(buff, BuffData.Rarity.GOLD)

	var melee := UnitInstance.create(_find("warden"), BoardModel.TEAM_A)
	var ranged := UnitInstance.create(_find("archer"), BoardModel.TEAM_A)
	held.apply_to(melee)
	held.apply_to(ranged)
	_check("Far Sight lifts every unit one band",
		melee.range_name() == "Medium" and ranged.range_name() == "Sniper",
		"%s and %s" % [melee.range_name(), ranged.range_name()])
	_check("it reaches further in tiles too, not just in name",
		melee.attack_reach() == 2 and ranged.attack_reach() == 4)


func _test_reckless(pool: BuffPool) -> void:
	var buff := pool.by_id(&"reckless")
	_check("Reckless hits harder the rarer it is, and hurts less",
		buff.bronze.x < buff.silver.x and buff.silver.x < buff.gold.x
		and buff.bronze.y > buff.silver.y and buff.silver.y > buff.gold.y,
		"%s / %s / %s" % [buff.bronze, buff.silver, buff.gold])
	_check("the numbers are the ones asked for",
		buff.bronze.is_equal_approx(Vector2(0.60, 0.20))
		and buff.silver.is_equal_approx(Vector2(0.90, 0.15))
		and buff.gold.is_equal_approx(Vector2(1.20, 0.10)))

	var held := TeamBuffs.new()
	held.add(buff, BuffData.Rarity.BRONZE)
	var u := UnitInstance.create(_find("lancer"), BoardModel.TEAM_A)
	var hit := u.stat(StatModifier.Stat.ATTACK_DAMAGE)
	_check("an unbuffed unit takes damage at face value",
		is_equal_approx(u.damage_taken_multiplier(), 1.0))
	held.apply_to(u)
	_check("it swings 60% harder",
		is_equal_approx(u.stat(StatModifier.Stat.ATTACK_DAMAGE), hit * 1.6))
	_check("and takes 20% more in return",
		is_equal_approx(u.damage_taken_multiplier(), 1.2),
		"multiplier is %.2f" % u.damage_taken_multiplier())

	var board := BoardModel.new()
	var glass := UnitInstance.create(_find("lancer"), BoardModel.TEAM_B)
	held.apply_to(glass)
	board.place(glass, Vector2i(2, 7))
	var puncher := UnitInstance.create(_find("lancer"), BoardModel.TEAM_A)
	board.place(puncher, Vector2i(2, 3))
	var sim := CombatSim.new()
	sim.setup(board, 3)
	sim.events.clear()
	sim._damage(glass, 100.0, puncher)
	var swung := 0.0
	for e in sim.events:
		if e.kind == "damage" and e.uid == glass.uid:
			swung = float(e.amount)
	_check("the extra damage taken lands in the sim",
		is_equal_approx(swung, 120.0), "a 100 swing landed as %.0f" % swung)

	var tough := UnitInstance.create(_find("lancer"), BoardModel.TEAM_B)
	board.force_place(tough, Vector2i(3, 7))
	sim.events.clear()
	sim._damage(tough, 20.0, puncher)
	var plain_hit := 0.0
	for e in sim.events:
		if e.kind == "damage" and e.uid == tough.uid:
			plain_hit = float(e.amount)
	_check("an unbuffed unit beside it takes the swing at face value",
		is_equal_approx(plain_hit, 20.0), "landed as %.0f" % plain_hit)


func _test_bloodletting(pool: BuffPool) -> void:
	var buff := pool.by_id(&"bloodletting")
	_check("lifesteal runs 20 / 40 / 60%",
		is_equal_approx(buff.bronze.x, 0.20) and is_equal_approx(buff.silver.x, 0.40)
		and is_equal_approx(buff.gold.x, 0.60))

	var held := TeamBuffs.new()
	held.add(buff, BuffData.Rarity.GOLD)
	var board := BoardModel.new()
	var vampire := UnitInstance.create(_find("lancer"), BoardModel.TEAM_A)
	held.apply_to(vampire)
	board.place(vampire, Vector2i(2, 3))
	board.place(UnitInstance.create(_find("warden"), BoardModel.TEAM_B), Vector2i(2, 7))
	var prey: UnitInstance = board.units_of(BoardModel.TEAM_B)[0]

	_check("lifesteal reads as a plain fraction",
		is_equal_approx(vampire.lifesteal(), 0.60),
		"%.2f" % vampire.lifesteal())

	var sim := CombatSim.new()
	sim.setup(board, 3)
	vampire.current_hp = 10.0
	sim._damage(prey, 100.0, vampire)
	_check("hitting somebody heals the attacker for its share",
		is_equal_approx(vampire.current_hp, 70.0),
		"%.0f hp after draining 100 damage" % vampire.current_hp)

	var plain := UnitInstance.create(_find("lancer"), BoardModel.TEAM_A)
	_check("nobody steals life without the buff", is_zero_approx(plain.lifesteal()))


func _test_conscription(pool: BuffPool) -> void:
	var buff := pool.by_id(&"conscription")
	var held := TeamBuffs.new()
	_check("no buff means no extra units", held.extra_draw() == 0)
	held.add(buff, BuffData.Rarity.BRONZE)
	_check("bronze adds one a turn", held.extra_draw() == 1)

	var silver := TeamBuffs.new()
	silver.add(buff, BuffData.Rarity.SILVER)
	var gold := TeamBuffs.new()
	gold.add(buff, BuffData.Rarity.GOLD)
	_check("silver adds two and gold adds three",
		silver.extra_draw() == 2 and gold.extra_draw() == 3)
	_check("it is not a stat buff, so it changes nobody's numbers",
		buff.modifiers_for(BuffData.Rarity.GOLD).is_empty())


func _test_wild_merge(pool: BuffPool) -> void:
	var board := BoardModel.new()
	board.configure_merges(_loadout.units, 7)
	var a := UnitInstance.create(_find("warden"), BoardModel.TEAM_A)
	var b := UnitInstance.create(_find("archer"), BoardModel.TEAM_A)
	board.place(a, board.deploy_cells(BoardModel.TEAM_A)[0])
	board.place(b, board.deploy_cells(BoardModel.TEAM_A)[1])

	_check("two different units cannot normally merge", not board.can_merge(a, b))
	board.set_wild_merge(BoardModel.TEAM_A, true)
	_check("Alchemy lets them merge anyway", board.can_merge(a, b))

	var mismatched := UnitInstance.create(
		BoardModel.at_tier(_find("archer"), 2), BoardModel.TEAM_A)
	board.place(mismatched, board.deploy_cells(BoardModel.TEAM_A)[2])
	_check("even wild merging still needs matching tiers",
		not board.can_merge(a, mismatched))
	_check("and it does not spill over to the other side",
		not board.wild_merge_for(BoardModel.TEAM_B))

	var held := TeamBuffs.new()
	held.add(pool.by_id(&"alchemy"), BuffData.Rarity.GOLD)
	_check("holding Alchemy is what turns it on",
		held.wild_merge() and not TeamBuffs.new().wild_merge())


func _test_sacrifice_maths() -> void:
	var got: PackedInt32Array = []
	for tier in range(1, 7):
		got.append(_sacrifice_yield(tier))
	_check("a sacrifice is worth 1, 1, 2, 2, 3, 3 tiers by the offering's tier",
		got == PackedInt32Array([1, 1, 2, 2, 3, 3]), str(got))


func _sacrifice_yield(tier: int) -> int:
	return clampi((tier + 1) / 2, 1, 3)


func _test_transcendence() -> void:
	_section("Transcendence")

	var transcendence := _find("transcendence")
	_check("the Transcendence is on the roster", transcendence != null)
	if transcendence == null:
		return
	_check("it is a medium-range stat stick with no ability",
		transcendence.range_name() == "Medium" and transcendence.ability == null
		and transcendence.max_hp > 150.0)
	_check("it is flagged as a merge magnet", transcendence.merge_magnet)
	_check("nothing else is", not _find("warden").merge_magnet
		and not _find("archer").merge_magnet)

	var board := BoardModel.new()
	board.configure_merges(_loadout.units, 99)
	board.set_wild_merge(BoardModel.TEAM_A, true)
	var cells := board.deploy_cells(BoardModel.TEAM_A)
	var stick := UnitInstance.create(transcendence, BoardModel.TEAM_A)
	var other := UnitInstance.create(_find("archer"), BoardModel.TEAM_A)
	board.place(stick, cells[0])
	board.place(other, cells[1])
	var merged := board.merge(stick, other, cells[1])
	_check("merging anything with an Transcendence gives you an Transcendence",
		merged != null and String(merged.data.id) == "transcendence",
		"got %s" % ("nothing" if merged == null else String(merged.data.id)))
	_check("and it is one tier up", merged != null and merged.data.tier == 2)

	var reversed := BoardModel.new()
	reversed.configure_merges(_loadout.units, 99)
	reversed.set_wild_merge(BoardModel.TEAM_A, true)
	var lead := UnitInstance.create(_find("archer"), BoardModel.TEAM_A)
	var magnet := UnitInstance.create(transcendence, BoardModel.TEAM_A)
	reversed.place(lead, cells[0])
	reversed.place(magnet, cells[1])
	var out := reversed.merge(lead, magnet, cells[1])
	_check("the order of the two does not matter",
		out != null and String(out.data.id) == "transcendence")

	var lottery_holds := true
	for seed_value in 12:
		var b := BoardModel.new()
		b.configure_merges(_loadout.units, seed_value)
		var x := UnitInstance.create(transcendence, BoardModel.TEAM_A)
		var y := UnitInstance.create(transcendence, BoardModel.TEAM_A)
		b.place(x, cells[0])
		b.place(y, cells[1])
		var r := b.merge(x, y, cells[1])
		if r == null or String(r.data.id) != "transcendence":
			lottery_holds = false
	_check("it beats the merge lottery every single time", lottery_holds)

	var apex := BoardModel.at_tier(transcendence, 6)
	var five := BoardModel.at_tier(transcendence, 5)
	_check("tiers 1 to 5 stay medium range",
		five.range_name() == "Medium" and five.pierce_targets == 1)
	_check("tier 6 goes unlimited range and unlimited pierce",
		apex.range_name() == "Unlimited" and apex.pierce_targets > 20,
		"%s range, pierce %d" % [apex.range_name(), apex.pierce_targets])
	_check("the apex jumps well past the usual doubling",
		apex.max_hp > five.max_hp * 4.0 and apex.attack_damage > five.attack_damage * 4.0,
		"%.0f hp and %.0f damage against a tier 5's %.0f and %.0f" % [
			apex.max_hp, apex.attack_damage, five.max_hp, five.attack_damage])

	var top := UnitInstance.create(apex, BoardModel.TEAM_A)
	_check("an awakened Transcendence can hit anything on the board",
		top.attack_reach() >= BoardModel.tile_distance(Vector2i(0, 0),
			Vector2i(BoardModel.WIDTH - 1, BoardModel.HEIGHT - 1)))
	_check("the Transcendence is never a summon target — it is drawn like anything else",
		_find("transcendence") != null and load("res://data/units/transcendence_t1.tres") != null)


func _test_new_trio() -> void:
	_section("Amalgam, Spire and Wellspring")
	_test_amalgam()
	_test_spire()
	_test_wellspring()
	_test_trio_buffs()
	_test_cast_animation()


func _test_amalgam() -> void:
	var amalgam := _find("amalgam")
	_check("the Amalgam is in the roster", amalgam != null)
	if amalgam == null:
		return
	_check("it is a melee body with real health and honest damage",
		amalgam.range_name() == "Melee" and amalgam.max_hp >= 150.0
			and amalgam.attack_damage >= 12.0,
		"%s, %.0f hp, %.0f damage" % [
			amalgam.range_name(), amalgam.max_hp, amalgam.attack_damage])
	_check("it carries the wild-merge flag itself", amalgam.wild_merge)
	_check("nothing else in the roster merges wild on its own",
		not _find("warden").wild_merge and not _find("archer").wild_merge)

	var board := BoardModel.new()
	board.configure_merges(_loadout.units, 5)
	var cells := board.deploy_cells(BoardModel.TEAM_A)
	var mixed := UnitInstance.create(amalgam, BoardModel.TEAM_A)
	var stranger := UnitInstance.create(_find("archer"), BoardModel.TEAM_A)
	board.place(mixed, cells[0])
	board.place(stranger, cells[1])
	_check("an Amalgam merges with a unit of a different type",
		board.can_merge(mixed, stranger))
	_check("and it works from either side",
		board.can_merge(stranger, mixed))

	var mismatched := UnitInstance.create(
		BoardModel.at_tier(_find("archer"), 3), BoardModel.TEAM_A)
	board.place(mismatched, cells[2])
	_check("but only across matching tiers",
		not board.can_merge(mixed, mismatched))

	var a := UnitInstance.create(_find("archer"), BoardModel.TEAM_A)
	var b := UnitInstance.create(_find("warden"), BoardModel.TEAM_A)
	board.place(a, cells[3])
	board.place(b, cells[4])
	_check("two ordinary units still cannot merge across types",
		not board.can_merge(a, b))


func _test_spire() -> void:
	var spire := _find("spire")
	_check("the Spire is in the roster", spire != null)
	if spire == null:
		return
	_check("it can neither move nor attack",
		not spire.can_move and not spire.can_attack)
	_check("it gathers 8 a charge instead of hitting things",
		is_equal_approx(spire.mana_per_charge, 8.0)
			and is_zero_approx(spire.mana_per_attack),
		"%.1f a charge, %.1f per attack" % [
			spire.mana_per_charge, spire.mana_per_attack])
	_check("and it charges once a second like everything else",
		is_equal_approx(spire.mana_charge_time, 1.0),
		"%.1fs" % spire.mana_charge_time)
	_check("but it banks that bar between rounds", spire.keeps_mana)

	var ab: AbilityData = spire.ability
	_check("its ability summons two at random",
		ab != null and ab.kind == AbilityData.Kind.SUMMON
			and ab.summon_count == 2 and ab.summon_random)
	if ab == null:
		return
	_check("that summon is not capped by tier", not ab.summon_cap_by_tier)

	var live := UnitInstance.create(spire, BoardModel.TEAM_B)
	_check("its computed charge reads straight off the unit",
		is_equal_approx(live.mana_per_charge(), 8.0), "%.2f" % live.mana_per_charge())
	_check("can_act() is false, so it never wanders or swings",
		not live.can_act())

	# 100 mana at 8 a second is thirteen seconds. A tier 6 body and a tier 1
	# heavy the board away keep it alive long enough to actually fire.
	var board := BoardModel.new()
	board.configure_merges(_loadout.units, 7)
	var caster := UnitInstance.create(BoardModel.at_tier(spire, 6), BoardModel.TEAM_B)
	board.place(caster, Vector2i(2, 10))
	board.place(UnitInstance.create(_find("warden"), BoardModel.TEAM_A), Vector2i(5, 0))
	var sim := CombatSim.new()
	sim.setup(board, 31)
	for i in 400:
		sim.step()

	var summoned: Array[UnitInstance] = []
	for u in board.units_of(BoardModel.TEAM_B):
		if u != caster:
			summoned.append(u)
	_check("it eventually raises a host of two", summoned.size() >= 2,
		"%d raised after %.1fs" % [summoned.size(), sim.elapsed])
	if summoned.is_empty():
		return
	var tiers_match := true
	for u in summoned:
		if u.data.tier != caster.data.tier:
			tiers_match = false
	_check("what it raises comes in at its own tier", tiers_match,
		"caster is tier %d" % caster.data.tier)

	var drawable := {}
	for u in _loadout.units:
		drawable[String(u.id)] = true
	var kinds := {}
	var all_drawable := true
	for u in summoned:
		kinds[String(u.data.id)] = true
		if not drawable.has(String(u.data.id)):
			all_drawable = false
	_check("and what it raises is drawn from your own roster", all_drawable,
		"raised %s" % ", ".join(PackedStringArray(kinds.keys())))

	var moved := false
	for e in sim.events:
		if e.kind == "move" and int(e.uid) == caster.uid:
			moved = true
		if e.kind == "attack" and int(e.uid) == caster.uid:
			moved = true
	_check("the Spire never took a step or a swing all battle", not moved)


func _test_wellspring() -> void:
	var well := _find("wellspring")
	_check("the Wellspring is in the roster", well != null)
	if well == null:
		return
	_check("it is a medium-range caster that opens instantly",
		well.range_name() == "Medium" and well.casts_at_battle_start,
		well.range_name())
	var ab: AbilityData = well.ability
	_check("its ability is a mana aura one tile out — a true three-by-three",
		ab != null and ab.kind == AbilityData.Kind.MANA_AURA
			and ab.mana_aura_radius == 1)
	_check("it puts out 6 mana a second",
		is_equal_approx(well.mana_per_charge, 6.0)
			and is_equal_approx(well.mana_charge_time, 1.0),
		"%.1f every %.1fs" % [well.mana_per_charge, well.mana_charge_time])

	var board := BoardModel.new()
	var caster := UnitInstance.create(well, BoardModel.TEAM_B)
	board.place(caster, Vector2i(2, 8))
	# Diagonal neighbour: inside the box, outside a Manhattan radius of 1.
	var corner := UnitInstance.create(_find("archer"), BoardModel.TEAM_B)
	board.place(corner, Vector2i(3, 9))
	var far := UnitInstance.create(_find("archer"), BoardModel.TEAM_B)
	board.place(far, Vector2i(5, 10))
	board.place(UnitInstance.create(
		BoardModel.at_tier(_find("warden"), 6), BoardModel.TEAM_A), Vector2i(0, 0))

	var sim := CombatSim.new()
	sim.setup(board, 41)
	var opened := false
	for e in sim.events:
		if e.kind == "aura_zone":
			opened = true
	_check("the pool is open before the first tick", opened)

	var corner_before := corner.mana
	for i in 12:
		sim.step()
	_check("a diagonal neighbour is inside the zone and gains mana",
		corner.mana > corner_before,
		"%.1f -> %.1f" % [corner_before, corner.mana])
	_check("someone standing well outside gains nothing from it",
		is_zero_approx(far.mana) or far.mana < corner.mana,
		"far has %.1f, corner has %.1f" % [far.mana, corner.mana])
	_check("the Wellspring does not pour its own regen back into itself",
		caster.mana < UnitInstance.MANA_MAX,
		"it sat at %.1f mana" % caster.mana)


func _test_trio_buffs() -> void:
	var pool := _pool()
	for id in ["cohesion", "incubation", "confluence", "ascension"]:
		_check("%s is on disk" % id, pool.by_id(StringName(id)) != null)

	var cohesion := pool.by_id(&"cohesion")
	if cohesion != null:
		_check("Cohesion is Amalgam-only",
			String(cohesion.unit_id) == "amalgam")
		_check("Cohesion runs 100/200/300% health",
			is_equal_approx(cohesion.bronze.x, 1.0)
				and is_equal_approx(cohesion.silver.x, 2.0)
				and is_equal_approx(cohesion.gold.x, 3.0))
		var amal := UnitInstance.create(_find("amalgam"), BoardModel.TEAM_A)
		var base := amal.stat(StatModifier.Stat.MAX_HP)
		amal.apply_modifiers(cohesion.modifiers_for(BuffData.Rarity.GOLD))
		_check("a gold Cohesion quadruples the body",
			is_equal_approx(amal.stat(StatModifier.Stat.MAX_HP), base * 4.0),
			"%.0f from %.0f" % [amal.stat(StatModifier.Stat.MAX_HP), base])

	var incubation := pool.by_id(&"incubation")
	if incubation != null:
		_check("Incubation is Spire-only", String(incubation.unit_id) == "spire")
		var spire := UnitInstance.create(_find("spire"), BoardModel.TEAM_A)
		var hp0 := spire.stat(StatModifier.Stat.MAX_HP)
		spire.apply_modifiers(incubation.modifiers_for(BuffData.Rarity.BRONZE))
		_check("bronze Incubation is +3 flat mana a charge",
			is_equal_approx(spire.mana_per_charge(), 11.0),
			"%.1f" % spire.mana_per_charge())
		_check("and +50% health on top, as a percentage",
			is_equal_approx(spire.stat(StatModifier.Stat.MAX_HP), hp0 * 1.5),
			"%.0f from %.0f" % [spire.stat(StatModifier.Stat.MAX_HP), hp0])

		var gold_spire := UnitInstance.create(_find("spire"), BoardModel.TEAM_A)
		var ghp := gold_spire.stat(StatModifier.Stat.MAX_HP)
		gold_spire.apply_modifiers(incubation.modifiers_for(BuffData.Rarity.GOLD))
		var inc_g := incubation.magnitude(BuffData.Rarity.GOLD)
		_check("gold Incubation reaches its full mana and health numbers",
			is_equal_approx(gold_spire.mana_per_charge(), 8.0 + inc_g.x)
				and is_equal_approx(gold_spire.stat(StatModifier.Stat.MAX_HP),
					ghp * (1.0 + inc_g.y)),
			"%.1f/s, %.0f hp" % [
				gold_spire.mana_per_charge(),
				gold_spire.stat(StatModifier.Stat.MAX_HP)])

	var confluence := pool.by_id(&"confluence")
	if confluence != null:
		_check("Confluence is Wellspring-only",
			String(confluence.unit_id) == "wellspring")
		var w := UnitInstance.create(_find("wellspring"), BoardModel.TEAM_A)
		var whp := w.stat(StatModifier.Stat.MAX_HP)
		w.apply_modifiers(confluence.modifiers_for(BuffData.Rarity.SILVER))
		_check("silver Confluence is +6 mana a charge and +60% health",
			is_equal_approx(w.mana_per_charge(), 12.0)
				and is_equal_approx(w.stat(StatModifier.Stat.MAX_HP), whp * 1.6),
			"%.1f a charge, %.0f hp" % [
				w.mana_per_charge(), w.stat(StatModifier.Stat.MAX_HP)])

	var ascension := pool.by_id(&"ascension")
	if ascension != null:
		_check("Ascension is Transcendence-only",
			String(ascension.unit_id) == "transcendence")
		var t := UnitInstance.create(_find("transcendence"), BoardModel.TEAM_A)
		var thp := t.stat(StatModifier.Stat.MAX_HP)
		var tdmg := t.stat(StatModifier.Stat.ATTACK_DAMAGE)
		t.apply_modifiers(ascension.modifiers_for(BuffData.Rarity.GOLD))
		_check("gold Ascension is +150% to both health and attack",
			is_equal_approx(t.stat(StatModifier.Stat.MAX_HP), thp * 2.5)
				and is_equal_approx(t.stat(StatModifier.Stat.ATTACK_DAMAGE), tdmg * 2.5),
			"%.0f hp, %.0f damage" % [
				t.stat(StatModifier.Stat.MAX_HP),
				t.stat(StatModifier.Stat.ATTACK_DAMAGE)])

	var fielded := {&"amalgam": true}
	var live := pool.pool_for(fielded, BuffData.Rarity.GOLD)
	var has_cohesion := false
	var has_incubation := false
	for b in live:
		if b.id == &"cohesion":
			has_cohesion = true
		if b.id == &"incubation":
			has_incubation = true
	_check("Cohesion only enters the pool once you field an Amalgam",
		has_cohesion and not has_incubation)


func _test_cast_animation() -> void:
	var board := _duel_board(_find("archer"), _find("vexer"))
	var sim := CombatSim.new()
	sim.setup(board, 55)
	for i in 120:
		sim.step()

	var casts := 0
	var named := 0
	for e in sim.events:
		if e.kind != "cast_start":
			continue
		casts += 1
		if String(e.get("name", "")) != "":
			named += 1
	_check("casts are announced before they land", casts > 0)
	_check("every cast_start carries the ability's name for the view",
		casts > 0 and named == casts, "%d of %d named" % [named, casts])

	var opener_board := _duel_board(_find("warden"), _find("herald"))
	var opener := CombatSim.new()
	opener.setup(opener_board, 56)
	var openers := 0
	for e in opener.events:
		if e.kind == "cast_start" and bool(e.get("opener", false)):
			openers += 1
	_check("battle-start abilities announce themselves too", openers > 0)

	var view := UnitView.new()
	view.unit = UnitInstance.create(_find("archer"), BoardModel.TEAM_A)
	view.begin_cast(0.4, "QUICKDRAW")
	_check("a UnitView told to cast enters the casting state",
		view.casting and is_equal_approx(view.cast_progress(), 0.0))
	view.cast_left = 0.1
	_check("its wind-up reads three quarters through",
		is_equal_approx(view.cast_progress(), 0.75), "%.2f" % view.cast_progress())
	view.end_cast()
	_check("and it clears when the cast resolves",
		not view.casting and view.cast_label.is_empty())
	view.begin_cast(0.4, "QUICKDRAW")
	view.die()
	_check("dying cancels a cast in flight", not view.casting)
	view.free()

	var archer := _find("archer")
	var quickdraw: AbilityData = archer.ability
	_check("the Archer still winds up before it speeds up",
		quickdraw.cast_time > 0.0, "%.2fs" % quickdraw.cast_time)
	var shooter := UnitInstance.create(archer, BoardModel.TEAM_A)
	var interval := shooter.attack_interval()
	for i in quickdraw.haste_max_stacks:
		shooter.haste_stacks += 1
		shooter.add_battle_modifier(StatModifier.make(
			StatModifier.Stat.ATTACK_SPEED, StatModifier.Mode.PERCENT,
			quickdraw.haste_percent))
	_check("and Quickdraw still stacks all the way up",
		shooter.haste_stacks == quickdraw.haste_max_stacks
			and shooter.attack_interval() < interval,
		"%d stacks, %.3fs -> %.3fs" % [
			shooter.haste_stacks, interval, shooter.attack_interval()])


func _test_unit_codex() -> void:
	_section("Unit codex")

	var loadout := _roster()
	var missing: PackedStringArray = []
	for u in loadout.units:
		if u.note.strip_edges().is_empty():
			missing.append(String(u.id))
	_check("every unit carries its own one-line note", missing.is_empty(),
		"blank on %s" % ", ".join(missing))

	var wisp: UnitData = load("res://data/units/wisp_t1.tres")
	_check("even the unpickable Wisp has one",
		wisp != null and not wisp.note.is_empty())

	var t4: UnitData = BoardModel.at_tier(_find("warden"), 4)
	_check("the note survives to every tier", t4.note == _find("warden").note)

	var warden := _find("warden")
	var card := UnitCodex.card(warden)
	_check("a card names the unit and its range band",
		card.contains("Warden") and card.contains("Melee"))
	_check("a card carries the note", card.contains(warden.note))
	_check("a card names the ability and explains it",
		card.contains("Bulwark") and card.contains(warden.ability.describe()))
	_check("a card says the ability fires at the opening bell",
		card.to_lower().contains("opening bell"))
	_check("a card shows health, damage and rate",
		card.contains("hp") and card.contains("damage") and card.contains("attacks/s"))
	_check("a card says how the bar fills",
		card.contains("20 mana per attack landed"))

	var archer_card := UnitCodex.card(_find("archer"))
	_check("a bar that fills by attacking says how many attacks that is",
		archer_card.contains("every 4 attacks"), archer_card)

	var vexer_card := UnitCodex.card(_find("vexer"))
	_check("a cheap bar counts more attacks, not fewer",
		vexer_card.contains("every 9 attacks"), vexer_card)

	var traits := UnitCodex.traits(_find("spire"))
	_check("the Spire reads as immobile and harmless by itself",
		String(traits[0]).contains("Never moves"), str(traits))
	_check("it also advertises its banked bar and its one-shot life",
		_has_phrase(traits, "from one round to the next")
			and _has_phrase(traits, "dies on the spot"), str(traits))
	_check("the Amalgam advertises its wild merge",
		_has_phrase(UnitCodex.traits(_find("amalgam")), "any unit of the same tier"))
	_check("the Transcendence advertises its magnet",
		_has_phrase(UnitCodex.traits(_find("transcendence")), "comes out as this unit"))
	_check("the Lancer advertises its free pierce",
		_has_phrase(UnitCodex.traits(_find("lancer")), "cut through 2"))
	_check("an ordinary unit claims no passives",
		UnitCodex.traits(_find("archer")).is_empty())

	var apex := BoardModel.at_tier(_find("transcendence"), 6)
	_check("an unlimited-pierce apex doesn't claim to cut through 99",
		_has_phrase(UnitCodex.traits(apex), "everything in line"),
		str(UnitCodex.traits(apex)))

	var amalgam := _find("amalgam")
	_check("a unit with no ability says so plainly",
		UnitCodex.card(amalgam).contains("No ability"))
	_check("and it is not asked how it charges",
		UnitCodex.charge_line(amalgam).is_empty())
	_check("a unit that only charges on its own clock says how often",
		UnitCodex.charge_line(_find("spire")).contains("8 mana on its own every second"),
		UnitCodex.charge_line(_find("spire")))
	_check("a one-second charge reads as a second, not '1 seconds'",
		UnitCodex.charge_line(_find("wellspring")).contains("every second"),
		UnitCodex.charge_line(_find("wellspring")))

	var plain := UnitInstance.create(_find("lancer"), BoardModel.TEAM_B)
	_check("an unbuffed unit's card does not mention buffs",
		not UnitCodex.card_of(plain).contains("buffed"))
	plain.apply_modifiers([StatModifier.make(
		StatModifier.Stat.MAX_HP, StatModifier.Mode.PERCENT, 1.0)] as Array[StatModifier])
	var buffed := UnitCodex.card_of(plain)
	_check("a buffed unit's card shows the buffed number",
		buffed.contains("%d hp" % roundi(plain.stat(StatModifier.Stat.MAX_HP))))
	_check("and says what the base was",
		buffed.contains("buffed") and buffed.contains("%d hp" % roundi(
			_find("lancer").max_hp)))

	var line := UnitCodex.one_line_of(plain)
	_check("the one-liner fits a status bar", line.length() < 140, "%d chars" % line.length())
	_check("the one-liner still names the ability", line.contains("Impale"))


func _has_phrase(list: PackedStringArray, needle: String) -> bool:
	for s in list:
		if String(s).contains(needle):
			return true
	return false


func _test_force_bar() -> void:
	_section("Force bar")

	var bar := ForceBar.new()
	bar.set_counts(5, 5)
	_check("an even fight splits the bar down the middle",
		is_equal_approx(bar.mine_share(), 0.5), "%.2f" % bar.mine_share())

	bar.set_counts(9, 3)
	_check("the bar is proportional, not binary",
		is_equal_approx(bar.mine_share(), 0.75), "%.2f" % bar.mine_share())
	_check("it knows the total on the field", bar.total() == 12)

	bar.set_counts(4, 0)
	_check("wiping them out fills the whole bar your way",
		is_equal_approx(bar.mine_share(), 1.0), "%.2f" % bar.mine_share())
	bar.set_counts(0, 4)
	_check("being wiped out fills the whole bar their way",
		is_equal_approx(bar.mine_share(), 0.0), "%.2f" % bar.mine_share())

	bar.set_counts(0, 0)
	_check("a double wipe does not divide by zero",
		is_equal_approx(bar.mine_share(), 0.5))
	bar.set_counts(-3, 2)
	_check("counts never go negative", bar.mine == 0 and bar.theirs == 2)
	bar.free()


func _test_summon_room() -> void:
	_section("Nothing summoned goes missing")
	_test_all_or_nothing()
	_test_persistent_host()
	_test_revive_always_lands()
	_test_charge_cadence()


func _crowd_board(board: BoardModel, filler: UnitData, team: int, leave := 0) -> int:
	# force_place ignores halves, so this fills the neutral row too.
	var free := board.free_cells()
	var made := 0
	for i in maxi(free.size() - leave, 0):
		board.force_place(UnitInstance.create(filler, team), free[i])
		made += 1
	return made


func _crowd_half(board: BoardModel, team: int, filler: UnitData, leave := 0) -> int:
	var free := board.free_deploy_cells(team)
	var made := 0
	for i in maxi(free.size() - leave, 0):
		board.place(UnitInstance.create(filler, team), free[i])
		made += 1
	return made


func _test_all_or_nothing() -> void:
	var spire := _find("spire")
	var conjurer := _find("conjurer")
	var warden := _find("warden")

	# Two needed, one tile free on the entire board: raise neither. The Spire has
	# its half's worth of headroom, so this is the physical check, not the
	# round-capacity one.
	var board := BoardModel.new()
	board.configure_merges(_loadout.units, 11)
	var caster := UnitInstance.create(BoardModel.at_tier(spire, 6), BoardModel.TEAM_B)
	board.place(caster, Vector2i(0, 10))
	_crowd_board(board, _find("archer"), BoardModel.TEAM_A, 1)
	_check("the board really is down to one free tile",
		board.free_cells().size() == 1, "%d free" % board.free_cells().size())

	var sim := CombatSim.new()
	sim.setup(board, 5)
	_check("the Spire has the capacity headroom, so only space is stopping it",
		sim.persist_room(BoardModel.TEAM_B) >= 2,
		"%d" % sim.persist_room(BoardModel.TEAM_B))
	caster.mana = UnitInstance.MANA_MAX
	var ab: AbilityData = caster.data.ability
	_check("the shortfall is named, and it is space",
		sim.summon_shortfall(caster, ab) == "no_room",
		sim.summon_shortfall(caster, ab))
	# The Spire casts anyway. That was a deliberate call: burning the bar with no
	# room is the pressure to merge before it is ready. `holds_when_capped` is
	# the opt-out, and the Spire does not take it — the Engineer does, because
	# standing exposed for two and a half seconds to produce nothing is a trap
	# rather than pressure.
	_check("it starts the cast regardless, because that is the punishment",
		sim.can_cast(caster) and not ab.holds_when_capped)

	var before := board.count_of(BoardModel.TEAM_B)
	for i in 20:
		sim.step()
	_check("a host that cannot fit whole is not raised in part",
		board.count_of(BoardModel.TEAM_B) <= before,
		"%d before, %d after" % [before, board.count_of(BoardModel.TEAM_B)])
	var refused := ""
	for e in sim.events:
		if e.kind == "ability" and bool(e.get("wasted", false)):
			refused = String(e.get("reason", ""))
			break
	_check("it spends the bar anyway, and the waste is reported",
		refused != "", "no wasted cast was emitted")
	_check("and the waste names space as the reason", refused == "no_room", refused)
	_check("so the bar really is gone — that is the punishment",
		caster.mana < UnitInstance.MANA_MAX, "%.0f" % caster.mana)

	# A summoner is never displaced by its own summon.
	var open_board := BoardModel.new()
	open_board.configure_merges(_loadout.units, 12)
	var caster2 := UnitInstance.create(BoardModel.at_tier(conjurer, 5), BoardModel.TEAM_B)
	open_board.place(caster2, Vector2i(2, 8))
	open_board.place(UnitInstance.create(
		BoardModel.at_tier(warden, 6), BoardModel.TEAM_A), Vector2i(0, 0))
	var live := CombatSim.new()
	live.setup(open_board, 13)
	var summoned := 0
	for e in live.events:
		if e.kind == "summon":
			summoned += 1
	_check("the Conjurer still opens with a wisp", summoned > 0)
	_check("and it is still standing on its own tile afterwards",
		open_board.unit_at(caster2.cell) == caster2 and caster2.is_alive())

	# A wisp is temporary, so it may take a tile outside its own half.
	var packed := BoardModel.new()
	packed.configure_merges(_loadout.units, 14)
	var summoner := UnitInstance.create(BoardModel.at_tier(conjurer, 5), BoardModel.TEAM_B)
	packed.place(summoner, Vector2i(0, 10))
	_crowd_half(packed, BoardModel.TEAM_B, _find("archer"), 0)
	packed.place(UnitInstance.create(warden, BoardModel.TEAM_A), Vector2i(0, 0))
	_check("our half is genuinely full", packed.free_deploy_cells(
		BoardModel.TEAM_B).is_empty())
	var spill := CombatSim.new()
	spill.setup(packed, 17)
	var wisp_cell := Vector2i(-1, -1)
	for e in spill.events:
		if e.kind == "summon":
			wisp_cell = e.cell
	_check("a temporary summon still finds a tile somewhere on the board",
		wisp_cell != Vector2i(-1, -1), "no wisp was placed at all")
	if wisp_cell != Vector2i(-1, -1):
		_check("even if that tile is outside its own half",
			not packed.can_deploy(BoardModel.TEAM_B, wisp_cell)
			or packed.free_deploy_cells(BoardModel.TEAM_B).is_empty())


func _test_persistent_host() -> void:
	var spire := _find("spire")
	var ab: AbilityData = spire.ability
	_check("Raise Host keeps what it raises", ab.summon_persists)
	_check("Call Wisp does not", not _find("conjurer").ability.summon_persists)

	var board := BoardModel.new()
	board.configure_merges(_loadout.units, 21)
	var caster := UnitInstance.create(BoardModel.at_tier(spire, 6), BoardModel.TEAM_B)
	board.place(caster, Vector2i(2, 10))
	board.place(UnitInstance.create(_find("archer"), BoardModel.TEAM_A), Vector2i(5, 0))

	var sim := CombatSim.new()
	sim.setup(board, 23)
	_check("a fresh Spire starts its first round on empty", is_zero_approx(caster.mana))
	var cap := board.half_capacity(BoardModel.TEAM_B)
	_check("a half holds thirty units", cap == 30, "%d" % cap)
	_check("one Spire alone leaves room for twenty-nine more",
		sim.persist_room(BoardModel.TEAM_B) == cap - 1,
		"%d" % sim.persist_room(BoardModel.TEAM_B))

	for i in 400:
		sim.step()
	var kept := sim.recruits()
	_check("what it raised is on the books", kept.size() >= 2,
		"%d recruits after %.1fs" % [kept.size(), sim.elapsed])
	if kept.is_empty():
		return
	var all_marked := true
	for entry in kept:
		var u: UnitInstance = entry.unit
		if not u.permanent:
			all_marked = false
	_check("every recruit is marked permanent", all_marked)
	_check("the room left shrinks by what was raised",
		sim.persist_room(BoardModel.TEAM_B) == cap - 1 - kept.size(),
		"%d left after %d raised" % [
			sim.persist_room(BoardModel.TEAM_B), kept.size()])

	var one: UnitInstance = kept[0].unit
	one.reset_for_battle()
	_check("and being reset for the next round does not un-mark it", one.permanent)

	# The gate is half capacity, not whatever happens to be free this instant.
	var full := BoardModel.new()
	full.configure_merges(_loadout.units, 25)
	var blocked := UnitInstance.create(BoardModel.at_tier(spire, 4), BoardModel.TEAM_B)
	full.place(blocked, Vector2i(0, 10))
	_crowd_half(full, BoardModel.TEAM_B, _find("archer"), 0)
	full.place(UnitInstance.create(
		BoardModel.at_tier(_find("warden"), 6), BoardModel.TEAM_A), Vector2i(5, 0))
	var jammed := CombatSim.new()
	jammed.setup(full, 27)
	_check("a full half leaves no room for a permanent host",
		jammed.persist_room(BoardModel.TEAM_B) == 0,
		"%d" % jammed.persist_room(BoardModel.TEAM_B))
	for i in 500:
		jammed.step()
	_check("so a Spire on a full board raises nothing at all, ever",
		jammed.recruits().is_empty(),
		"%d slipped through" % jammed.recruits().size())
	_check("the shortfall is named, and it is the round's capacity",
		jammed.summon_shortfall(blocked, blocked.data.ability) == "no_home",
		jammed.summon_shortfall(blocked, blocked.data.ability))
	var burned := 0
	for e in jammed.events:
		if e.kind == "cast_start" and int(e.uid) == blocked.uid:
			burned += 1
	_check("and it burns a bar every time it tries — bring fewer units",
		burned > 0, "%d casts" % burned)
	var reasons := 0
	for e in jammed.events:
		if e.kind == "ability" and String(e.get("reason", "")) == "no_home":
			reasons += 1
	_check("each of those is reported as wasted for want of a home",
		reasons > 0, "%d refusals" % reasons)


func _test_revive_always_lands() -> void:
	var revenant := _find("revenant")
	var board := BoardModel.new()
	board.configure_merges(_loadout.units, 31)
	var hero := UnitInstance.create(revenant, BoardModel.TEAM_B)
	board.place(hero, Vector2i(2, 10))
	_crowd_half(board, BoardModel.TEAM_B, _find("warden"), 0)
	board.place(UnitInstance.create(
		BoardModel.at_tier(_find("pyre"), 6), BoardModel.TEAM_A), Vector2i(2, 0))

	var free := board.free_cells()
	_check("every tile around the Revenant is taken",
		_ring_is_full(board, hero.cell), "%d free on the whole board" % free.size())

	var sim := CombatSim.new()
	sim.setup(board, 41)
	for i in 600:
		sim.step()
	var starts := 0
	var lands := 0
	for e in sim.events:
		if e.kind == "respawn_start":
			starts += 1
		if e.kind == "respawn":
			lands += 1
	_check("a Revenant that rolled its revive actually comes back",
		starts == lands, "%d started rising, only %d landed" % [starts, lands])


func _ring_is_full(board: BoardModel, centre: Vector2i) -> bool:
	for dy in range(-1, 2):
		for dx in range(-1, 2):
			var c := centre + Vector2i(dx, dy)
			if board.in_bounds(c) and board.is_empty(c):
				return false
	return true


func _test_charge_cadence() -> void:
	var spire := _find("spire")
	var board := BoardModel.new()
	board.configure_merges(_loadout.units, 51)
	var caster := UnitInstance.create(BoardModel.at_tier(spire, 6), BoardModel.TEAM_B)
	board.place(caster, Vector2i(2, 10))
	board.place(UnitInstance.create(_find("archer"), BoardModel.TEAM_A), Vector2i(0, 0))

	var sim := CombatSim.new()
	sim.setup(board, 53)
	for i in 400:
		sim.step()

	var charges := 0
	var first_cast := -1.0
	for e in sim.events:
		if e.kind == "mana" and int(e.uid) == caster.uid and float(e.mana) > 0.0:
			charges += 1
		if e.kind == "cast_start" and int(e.uid) == caster.uid:
			first_cast = e.t
			break
	_check("filling the bar takes thirteen charges",
		charges >= 12 and charges <= 14, "%d charges to fill" % charges)
	_check("and thirteen charges is about thirteen seconds again",
		first_cast > 11.0 and first_cast < 16.0, "first cast at t=%.1f" % first_cast)



	var buffed := UnitInstance.create(spire, BoardModel.TEAM_B)
	var pool := _pool()
	var incubation := pool.by_id(&"incubation")
	if incubation != null:
		buffed.apply_modifiers(incubation.modifiers_for(BuffData.Rarity.GOLD))
		_check("Incubation buys charge size, not charge speed",
			is_equal_approx(buffed.mana_per_charge(), 17.0)
				and is_equal_approx(buffed.charge_time(), 1.0),
			"%.1f every %.1fs" % [buffed.mana_per_charge(), buffed.charge_time()])
		_check("its buff text talks about charges, not seconds",
			incubation.describe(BuffData.Rarity.GOLD).contains("mana a charge"),
			incubation.describe(BuffData.Rarity.GOLD))


func _test_spire_lifecycle() -> void:
	_section("The Spire spends itself")
	_test_summons_land_close()
	_test_banked_bar()
	_test_caster_is_spent()


func _test_summons_land_close() -> void:
	var conjurer := _find("conjurer")
	var board := BoardModel.new()
	board.configure_merges(_loadout.units, 61)
	var caster := UnitInstance.create(BoardModel.at_tier(conjurer, 5), BoardModel.TEAM_B)
	board.place(caster, Vector2i(2, 8))
	board.place(UnitInstance.create(
		BoardModel.at_tier(_find("warden"), 6), BoardModel.TEAM_A), Vector2i(0, 0))

	_check("Raise Host plants its units at the Spire's shoulder",
		_find("spire").ability.summon_adjacent)
	_check("Call Wisp puts its wisp beside the Conjurer too",
		conjurer.ability.summon_adjacent)

	var sim := CombatSim.new()
	sim.setup(board, 63)
	var at := Vector2i(-1, -1)
	for e in sim.events:
		if e.kind == "summon":
			at = e.cell
	_check("the opening wisp arrives", at != Vector2i(-1, -1))
	if at == Vector2i(-1, -1):
		return
	_check("and it lands right beside its summoner",
		BoardModel.tile_distance(at, Vector2i(2, 8)) == 1,
		"wisp at %s, Conjurer at (2, 8)" % at)

	# Wall an adjacent summoner in: it should take the next ring out, not a
	# random tile across the board.
	var boxed := BoardModel.new()
	boxed.configure_merges(_loadout.units, 65)
	var walled := UnitInstance.create(BoardModel.at_tier(_find("spire"), 6),
		BoardModel.TEAM_B)
	boxed.place(walled, Vector2i(2, 8))
	# Spires for the walls: an archer would walk off before the cast landed.
	for c in [Vector2i(1, 8), Vector2i(3, 8), Vector2i(2, 7), Vector2i(2, 9)]:
		boxed.force_place(UnitInstance.create(_find("spire"), BoardModel.TEAM_B), c)
	boxed.place(UnitInstance.create(_find("archer"), BoardModel.TEAM_A), Vector2i(0, 0))
	var walled_sim := CombatSim.new()
	walled_sim.setup(boxed, 67)
	walled.mana = UnitInstance.MANA_MAX
	for i in 40:
		walled_sim.step()
	var worst := 0
	var seen := 0
	for e in walled_sim.events:
		if e.kind == "summon":
			seen += 1
			worst = maxi(worst, BoardModel.tile_distance(e.cell, Vector2i(2, 8)))
	_check("a boxed-in summoner still raises its host", seen >= 2, "%d raised" % seen)
	if seen >= 2:
		_check("and it lands two tiles out — the closest thing left",
			worst == 2, "furthest landed %d tiles away" % worst)

	# Two at once should both be close, not one near and one anywhere.
	var pair := BoardModel.new()
	pair.configure_merges(_loadout.units, 69)
	var spire := UnitInstance.create(BoardModel.at_tier(_find("spire"), 6),
		BoardModel.TEAM_B)
	pair.place(spire, Vector2i(2, 8))
	pair.place(UnitInstance.create(_find("archer"), BoardModel.TEAM_A), Vector2i(0, 0))
	var host := CombatSim.new()
	host.setup(pair, 71)
	for i in 250:
		host.step()
	var far := 0
	var raised := 0
	for e in host.events:
		if e.kind != "summon":
			continue
		raised += 1
		if BoardModel.tile_distance(e.cell, Vector2i(2, 8)) > 2:
			far += 1
	_check("a whole host lands on the summoner's doorstep", raised >= 2 and far == 0,
		"%d raised, %d of them further than two tiles" % [raised, far])


func _test_banked_bar() -> void:
	var spire := _find("spire")
	var carrier := UnitInstance.create(spire, BoardModel.TEAM_B)
	carrier.gain_mana(60.0)
	carrier.reset_for_battle()
	_check("a Spire carries its charge into the next round",
		is_equal_approx(carrier.mana, 60.0), "%.0f" % carrier.mana)

	var archer := UnitInstance.create(_find("archer"), BoardModel.TEAM_B)
	archer.gain_mana(60.0)
	archer.reset_for_battle()
	_check("everyone else still starts every round on empty",
		is_zero_approx(archer.mana), "%.0f" % archer.mana)

	# A part-charged Spire fires sooner than a fresh one, in the same battle.
	var board := BoardModel.new()
	board.configure_merges(_loadout.units, 73)
	var loaded := UnitInstance.create(BoardModel.at_tier(spire, 6), BoardModel.TEAM_B)
	loaded.gain_mana(80.0)
	board.place(loaded, Vector2i(2, 10))
	board.place(UnitInstance.create(_find("archer"), BoardModel.TEAM_A), Vector2i(0, 0))
	var sim := CombatSim.new()
	sim.setup(board, 75)
	_check("setting up a battle does not wipe the bank",
		is_equal_approx(loaded.mana, 80.0), "%.0f after setup" % loaded.mana)
	for i in 120:
		sim.step()
	var first := -1.0
	for e in sim.events:
		if e.kind == "cast_start" and int(e.uid) == loaded.uid:
			first = e.t
			break
	_check("so a Spire that banked 80 fires in about three seconds",
		first > 0.0 and first < 5.0, "first cast at t=%.1f" % first)


func _test_caster_is_spent() -> void:
	var spire := _find("spire")
	var ab: AbilityData = spire.ability
	_check("Raise Host is marked as using its caster up", ab.consumes_caster)
	_check("Call Wisp is not", not _find("conjurer").ability.consumes_caster)

	var board := BoardModel.new()
	board.configure_merges(_loadout.units, 81)
	var caster := UnitInstance.create(BoardModel.at_tier(spire, 6), BoardModel.TEAM_B)
	caster.gain_mana(95.0)
	board.place(caster, Vector2i(2, 10))
	board.place(UnitInstance.create(_find("archer"), BoardModel.TEAM_A), Vector2i(0, 0))

	var sim := CombatSim.new()
	sim.setup(board, 83)
	for i in 120:
		sim.step()

	var raised := 0
	var spent_at := -1.0
	var first_raise := -1.0
	for e in sim.events:
		if e.kind == "summon":
			raised += 1
			if first_raise < 0.0:
				first_raise = e.t
		if e.kind == "death" and int(e.uid) == caster.uid:
			spent_at = e.t
			_check("the death that spends it names no killer",
				int(e.get("killer_uid", 0)) == -1, str(e))
			_check("and it is flagged as spent, not simply killed",
				bool(e.get("consumed", false)), str(e))
	_check("it raised its host", raised == 2, "%d raised" % raised)
	_check("and then died", spent_at >= 0.0)
	_check("the host arrives before the Spire goes",
		first_raise >= 0.0 and spent_at >= first_raise,
		"raised at %.1f, spent at %.1f" % [first_raise, spent_at])
	_check("it is off the board", board.unit_at(Vector2i(2, 10)) != caster
		and not caster.is_alive())
	_check("it is marked consumed so the roster drops it", caster.consumed)
	caster.reset_for_battle()
	_check("and resetting it for the next round does not un-mark it",
		caster.consumed)

	var back_up := 0
	for e in sim.events:
		if e.kind == "respawn_start" and int(e.uid) == caster.uid:
			back_up += 1
	_check("nothing tries to bring it back", back_up == 0)

	# A cast with nowhere to put the host must not kill the caster.
	var jammed := BoardModel.new()
	jammed.configure_merges(_loadout.units, 85)
	var survivor := UnitInstance.create(BoardModel.at_tier(spire, 6), BoardModel.TEAM_B)
	jammed.place(survivor, Vector2i(0, 10))
	_crowd_board(jammed, _find("archer"), BoardModel.TEAM_A, 1)
	var stuck := CombatSim.new()
	stuck.setup(jammed, 87)
	survivor.mana = UnitInstance.MANA_MAX
	for i in 25:
		stuck.step()
	_check("a wasted cast leaves the Spire standing",
		not survivor.consumed and survivor.is_alive(),
		"consumed=%s alive=%s" % [survivor.consumed, survivor.is_alive()])


func _test_apex_and_guard() -> void:
	_section("The laser and the guard")

	var apex := BoardModel.at_tier(_find("transcendence"), 6)
	var five := BoardModel.at_tier(_find("transcendence"), 5)
	_check("unlimited means a hundred tiles now, not ninety-nine",
		UnitData.UNLIMITED_TILES == 100, "%d" % UnitData.UNLIMITED_TILES)
	_check("the apex sits on band 5, the top of the ladder",
		apex.attack_range == UnitData.RangeBand.UNLIMITED
			and apex.range_name() == "Unlimited",
		"band %d" % apex.attack_range)
	_check("and band 5 reaches the whole board",
		apex.reach_tiles() == 100, "%d" % apex.reach_tiles())
	_check("every Transcendence fires a beam",
		apex.beam_attack and five.beam_attack and _find("transcendence").beam_attack)
	_check("but only the apex's is endless",
		apex.beam_endless and not five.beam_endless)
	_check("and only the apex's washes anything beside it",
		apex.beam_splash > 0.0 and is_zero_approx(five.beam_splash))
	_check("nothing else on the roster fires one",
		not _find("archer").beam_attack and not _find("warden").beam_attack)
	_check("its pierce keeps pace with the constant, so it reads as endless",
		apex.pierce_targets >= UnitData.UNLIMITED_TILES,
		"pierce %d against %d" % [apex.pierce_targets, UnitData.UNLIMITED_TILES])
	_check("so its card says it cuts through everything, not through a number",
		_has_phrase(UnitCodex.traits(apex), "everything in line"),
		str(UnitCodex.traits(apex)))

	# The guard: a Spire cannot be killed mid-cast.
	var spire := _find("spire")
	var ab: AbilityData = spire.ability
	_check("Raise Host guards its caster", ab.guards_caster)
	_check("and takes long enough to be worth guarding", ab.cast_time >= 1.0,
		"%.2fs" % ab.cast_time)
	_check("Call Wisp does not guard", not _find("conjurer").ability.guards_caster)

	var board := BoardModel.new()
	board.configure_merges(_loadout.units, 91)
	var caster := UnitInstance.create(spire, BoardModel.TEAM_B)
	board.place(caster, Vector2i(2, 6))
	_check("a Spire standing idle is not invulnerable", not caster.is_invulnerable())

	# A wall of heavy hitters right on top of it, and a full bar.
	for c in [Vector2i(2, 5), Vector2i(1, 5), Vector2i(3, 5)]:
		board.force_place(UnitInstance.create(
			BoardModel.at_tier(_find("warden"), 6), BoardModel.TEAM_A), c)

	var sim := CombatSim.new()
	sim.setup(board, 93)
	caster.mana = UnitInstance.MANA_MAX
	var hp_before := caster.current_hp
	var casting_seen := false
	for i in 16:
		sim.step()
		if caster.state == UnitInstance.State.CASTING:
			casting_seen = true
			_check_once("it is invulnerable for as long as it is casting",
				caster.is_invulnerable())
			_check_once("and takes nothing while it stands there",
				is_equal_approx(caster.current_hp, hp_before),
				"%.0f from %.0f" % [caster.current_hp, hp_before])
	_check("the Spire got its cast off", casting_seen)

	var blocks := 0
	var landed := 0
	for e in sim.events:
		if e.kind == "blocked" and int(e.uid) == caster.uid:
			blocks += 1
		if e.kind == "damage" and int(e.uid) == caster.uid:
			landed += 1
	_check("the blows are reported as blocked, so the view can show it",
		blocks > 0, "%d blocked" % blocks)
	_check("and none of them landed while it was guarded",
		landed == 0 or blocks > 0, "%d landed, %d blocked" % [landed, blocks])

	var raised := 0
	for e in sim.events:
		if e.kind == "summon":
			raised += 1
	_check("a guarded Spire lives long enough to finish", raised == 2,
		"%d raised" % raised)

	var guarded_flag := false
	for e in sim.events:
		if e.kind == "cast_start" and bool(e.get("guarded", false)):
			guarded_flag = true
	_check("the cast tells the view it is guarded", guarded_flag)


var _once: Dictionary = {}


func _check_once(label: String, condition: bool, detail := "") -> void:
	if _once.has(label):
		return
	_once[label] = true
	_check(label, condition, detail)


func _test_beam_wash() -> void:
	_section("The beam takes the rank with it")

	var apex := BoardModel.at_tier(_find("transcendence"), 6)
	_check("the apex washes half its damage over the beam",
		is_equal_approx(apex.beam_splash, 0.5), "%.2f" % apex.beam_splash)
	_check("lower tiers wash nothing",
		is_zero_approx(BoardModel.at_tier(_find("transcendence"), 5).beam_splash))

	var board := BoardModel.new()
	board.configure_merges(_loadout.units, 101)
	var gun := UnitInstance.create(apex, BoardModel.TEAM_B)
	board.place(gun, Vector2i(2, 10))

	# Spires for targets: they never move, so the geometry holds still, and they
	# raise no shield, so the damage shows up in current_hp instead of soaking.
	var post := BoardModel.at_tier(_find("spire"), 6)
	var front := UnitInstance.create(post, BoardModel.TEAM_A)
	var behind := UnitInstance.create(post, BoardModel.TEAM_A)
	var beside := UnitInstance.create(post, BoardModel.TEAM_A)
	var clear := UnitInstance.create(post, BoardModel.TEAM_A)
	# Spaced so the intended target is nearer than everything else by more than
	# CombatSim.TARGET_SLACK. Targeting picks at random inside that band now, and
	# at the old spacing the gun would sometimes aim at the unit this test calls
	# "beside" — which then took a direct hit and made the wash look equal to it.
	board.force_place(front, Vector2i(2, 6))
	board.force_place(behind, Vector2i(2, 2))
	board.force_place(beside, Vector2i(3, 3))
	board.force_place(clear, Vector2i(5, 0))
	var spread := [front, behind, beside, clear].map(
		func(v: UnitInstance) -> int:
			return BoardModel.tile_distance(gun.cell, v.cell))
	_check("the intended target is unambiguously the closest",
		int(spread[0]) + CombatSim.TARGET_SLACK < int(spread[1])
		and int(spread[0]) + CombatSim.TARGET_SLACK < int(spread[2]),
		"distances %s with a slack of %d" % [spread, CombatSim.TARGET_SLACK])

	var sim := CombatSim.new()
	sim.setup(board, 103)
	var line := sim.beam_cells(Vector2i(2, 10), Vector2i(2, 6))
	_check("the beam runs from the shooter to the far edge",
		line.has(Vector2i(2, 3)) and line.has(Vector2i(2, 0))
			and not line.has(Vector2i(2, 10)),
		"%d cells" % line.size())

	var hp := {
		front = front.current_hp, behind = behind.current_hp,
		beside = beside.current_hp, clear = clear.current_hp,
	}
	for i in 20:
		sim.step()

	_check("whatever it aimed at is hit", front.current_hp < hp.front,
		"%.0f from %.0f" % [front.current_hp, hp.front])
	_check("so is whatever stood behind it",
		behind.current_hp < hp.behind or not behind.is_alive(),
		"%.0f from %.0f" % [behind.current_hp, hp.behind])
	_check("and so is whatever stood beside the beam",
		beside.current_hp < hp.beside or not beside.is_alive(),
		"%.0f from %.0f" % [beside.current_hp, hp.beside])
	_check("but not something well clear of it",
		is_equal_approx(clear.current_hp, hp.clear),
		"%.0f from %.0f" % [clear.current_hp, hp.clear])

	var full: float = hp.front - front.current_hp
	var wash: float = hp.beside - beside.current_hp
	if full > 0.0 and wash > 0.0:
		_check("the wash hurts less than a direct hit", wash < full,
			"%.0f beside against %.0f ahead" % [wash, full])

	var announced := false
	for e in sim.events:
		if e.kind != "beam":
			continue
		announced = true
		_check("the beam event carries its line and its wash for the view",
			not e.get("cells", []).is_empty() and not e.get("washed", []).is_empty())
		break
	_check("the beam is announced to the view", announced)

	# Nothing else fires one.
	var plain := BoardModel.new()
	plain.configure_merges(_loadout.units, 105)
	plain.place(UnitInstance.create(_find("archer"), BoardModel.TEAM_B), Vector2i(2, 8))
	plain.place(UnitInstance.create(_find("warden"), BoardModel.TEAM_A), Vector2i(2, 3))
	var quiet := CombatSim.new()
	quiet.setup(plain, 107)
	for i in 60:
		quiet.step()
	var stray := 0
	for e in quiet.events:
		if e.kind == "beam":
			stray += 1
	_check("an ordinary unit never fires one", stray == 0, "%d beams" % stray)


func _test_maps() -> void:
	_section("Maps")

	var maps := _load_maps()
	_check("every map on disk loaded", maps.size() >= 10,
		"found %d" % maps.size())

	var bad: PackedStringArray = []
	for m in maps:
		var why := m.invalid_reason()
		if not why.is_empty():
			bad.append("%s: %s" % [m.id, why])
	_check("every map is playable and fair", bad.is_empty(),
		"; ".join(bad))

	var undivided := 0
	for m in maps:
		if not m.has_neutral:
			undivided += 1
	_check("some maps have no divider at all", undivided > 0)

	_check("an even board with a divider is rejected", not _map(10, true).is_valid())
	_check("an odd board without one is rejected", not _map(9, false).is_valid())
	_check("an even board without one is fine", _map(10, false).is_valid())
	_check("an odd board with one is fine", _map(11, true).is_valid())

	for m in maps:
		_check_map_geometry(m)
	BoardModel.reset_map()
	_check("the default board comes back after all that",
		BoardModel.WIDTH == 6 and BoardModel.HEIGHT == 11
			and BoardModel.HAS_NEUTRAL,
		"%dx%d" % [BoardModel.WIDTH, BoardModel.HEIGHT])

	_test_play_on_every_map(maps)


func _map(h: int, neutral: bool) -> MapData:
	var m := MapData.new()
	m.width = 6
	m.height = h
	m.has_neutral = neutral
	return m


func _load_maps() -> Array[MapData]:
	var out: Array[MapData] = []
	var dir := DirAccess.open("res://data/maps")
	if dir == null:
		return out
	var names := dir.get_files()
	names.sort()
	for file_name in names:
		var clean := file_name.trim_suffix(".remap")
		if not clean.ends_with(".tres"):
			continue
		var res := load("res://data/maps/%s" % clean)
		if res is MapData:
			out.append(res as MapData)
	return out


func _flood(board: BoardModel) -> int:
	var open := board.playable_cells()
	if open.is_empty():
		return 0
	var seen := {open[0]: true}
	var queue: Array[Vector2i] = [open[0]]
	var head := 0
	while head < queue.size():
		var c: Vector2i = queue[head]
		head += 1
		for off in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			var n: Vector2i = c + off
			if seen.has(n) or not BoardModel.is_playable(n):
				continue
			if BoardModel.blocks_between(c, n):
				continue
			seen[n] = true
			queue.append(n)
	return seen.size()


func _check_map_geometry(m: MapData) -> void:
	BoardModel.use_map(m)
	var board := BoardModel.new()

	var a := board.deploy_cells(BoardModel.TEAM_A)
	var b := board.deploy_cells(BoardModel.TEAM_B)
	_check("%s: both sides get the same number of tiles" % m.display_name,
		a.size() == b.size(), "%d against %d" % [a.size(), b.size()])
	_check("%s: a half is width times half the rows" % m.display_name,
		a.size() == m.half_tiles(), "%d, expected %d" % [a.size(), m.half_tiles()])

	var overlap := 0
	for c in a:
		if b.has(c):
			overlap += 1
	_check("%s: the halves never overlap" % m.display_name, overlap == 0,
		"%d shared tiles" % overlap)

	var claimed := a.size() + b.size()
	var neutral_tiles := 0
	var dead := 0
	for c in board.playable_cells():
		if board.is_neutral(c):
			neutral_tiles += 1
	for y in m.height:
		for x in m.width:
			if m.blocked(Vector2i(x, y)):
				dead += 1
	_check("%s: halves, divider and terrain account for the whole board" % m.display_name,
		claimed + neutral_tiles + dead == m.tiles(),
		"%d + %d + %d against %d" % [claimed, neutral_tiles, dead, m.tiles()])

	if not m.has_neutral:
		_check("%s: and no tile is neutral" % m.display_name,
			not board.is_neutral(Vector2i(0, m.half_rows())))
	else:
		var divider_open := false
		for x in m.width:
			if board.can_deploy(BoardModel.TEAM_A, Vector2i(x, m.half_rows())) \
					or board.can_deploy(BoardModel.TEAM_B, Vector2i(x, m.half_rows())):
				divider_open = true
		_check("%s: the divider is out of bounds for both sides" % m.display_name,
			not divider_open)

	var mirrored_wrong := 0
	for c in a:
		var mirrored := BoardModel.mirror(c)
		if not board.can_deploy(BoardModel.TEAM_B, mirrored):
			mirrored_wrong += 1
	_check("%s: every tile mirrors onto the other half" % m.display_name,
		mirrored_wrong == 0, "%d tiles mirror off-side" % mirrored_wrong)

	_check("%s: half_capacity agrees with the deploy list" % m.display_name,
		board.half_capacity(BoardModel.TEAM_B) == b.size())

	var reachable := _flood(board)
	_check("%s: every usable tile can be walked to" % m.display_name,
		reachable == board.playable_cells().size(),
		"%d of %d tiles reachable" % [reachable, board.playable_cells().size()])


func _test_play_on_every_map(maps: Array[MapData]) -> void:
	for m in maps:
		BoardModel.use_map(m)
		var board := BoardModel.new()
		board.configure_merges(_loadout.units, 5)
		var rng := RandomNumberGenerator.new()
		rng.seed = 404
		for team in [BoardModel.TEAM_A, BoardModel.TEAM_B]:
			var free := board.free_deploy_cells(team)
			for i in mini(5, free.size()):
				var pick := _loadout.draw_one(rng)
				board.place(UnitInstance.create(pick, team), free[i])

		var sim := CombatSim.new()
		sim.setup(board, 909)
		var result := sim.run()
		_check("%s: a whole battle resolves on it" % m.display_name,
			sim.is_finished(), "still running after %.1fs" % sim.elapsed)
		_check("%s: it ends with a winner or an honest draw" % m.display_name,
			result == CombatSim.RESULT_DRAW or result == BoardModel.TEAM_A
				or result == BoardModel.TEAM_B, str(result))
		var stray := 0
		for u in board.all_units():
			if not board.in_bounds(u.cell):
				stray += 1
		_check("%s: nothing ended up off the board" % m.display_name, stray == 0,
			"%d strays" % stray)
	BoardModel.reset_map()


func _test_terrain() -> void:
	_section("Terrain")
	_test_terrain_blocks()
	_test_barriers()
	_test_high_ground()
	BoardModel.reset_map()


func _terrain_map(shape: PackedStringArray, barriers: Array[Vector4i],
		neutral := true) -> MapData:
	var m := MapData.new()
	m.id = &"probe"
	m.display_name = "Probe"
	m.width = shape[0].length()
	m.height = shape.size()
	m.has_neutral = neutral
	m.rows = shape
	m.lines = barriers
	return m


func _test_terrain_blocks() -> void:
	var m := _terrain_map(PackedStringArray([
		"......",
		"..##..",
		"......",
		"XX..XX",
		"......",
		"......",
		"......",
		"XX..XX",
		"......",
		"..##..",
		"......",
	]), [] as Array[Vector4i])
	_check("a hand-built terrain map validates", m.is_valid(), m.invalid_reason())
	BoardModel.use_map(m)
	var board := BoardModel.new()

	_check("a wall is a wall", BoardModel.is_wall(Vector2i(2, 1)))
	_check("a hole is a hole", BoardModel.is_void(Vector2i(0, 3)))
	_check("both count as blocked",
		BoardModel.is_blocked(Vector2i(2, 1))
			and BoardModel.is_blocked(Vector2i(0, 3)))
	_check("open ground is neither",
		not BoardModel.is_blocked(Vector2i(3, 0)))
	_check("blocked tiles are not playable",
		not BoardModel.is_playable(Vector2i(2, 1))
			and BoardModel.is_playable(Vector2i(3, 0)))

	_check("nothing deploys onto a wall",
		not board.can_deploy(BoardModel.TEAM_A, Vector2i(2, 1)))
	_check("nothing deploys into a hole",
		not board.can_deploy(BoardModel.TEAM_A, Vector2i(0, 3)))
	_check("a blocked tile never reads as empty",
		not board.is_empty(Vector2i(2, 1)) and not board.is_empty(Vector2i(0, 3)))

	var unit := UnitInstance.create(_find("archer"), BoardModel.TEAM_A)
	_check("placing onto a wall fails", not board.place(unit, Vector2i(2, 1)))
	_check("even force_place refuses it",
		not board.force_place(unit, Vector2i(0, 3)))
	_check("but open ground still takes it", board.place(unit, Vector2i(3, 0)))

	var deploys := board.deploy_cells(BoardModel.TEAM_A)
	var bad := 0
	for c in deploys:
		if BoardModel.is_blocked(c):
			bad += 1
	_check("the deploy list skips terrain", bad == 0, "%d blocked tiles listed" % bad)
	_check("so the half is smaller than width times rows",
		deploys.size() < m.width * m.half_rows(),
		"%d against %d" % [deploys.size(), m.width * m.half_rows()])
	_check("and half_capacity says the same",
		board.half_capacity(BoardModel.TEAM_A) == deploys.size())

	var free := board.free_cells()
	var leaked := 0
	for c in free:
		if BoardModel.is_blocked(c):
			leaked += 1
	_check("free_cells never offers a blocked tile", leaked == 0,
		"%d leaked" % leaked)

	# A summoner cannot drop a minion into a wall.
	BoardModel.use_map(m)
	var live := BoardModel.new()
	live.configure_merges(_loadout.units, 3)
	var conjurer := UnitInstance.create(
		BoardModel.at_tier(_find("conjurer"), 5), BoardModel.TEAM_B)
	live.place(conjurer, Vector2i(3, 8))
	live.place(UnitInstance.create(_find("archer"), BoardModel.TEAM_A), Vector2i(3, 0))
	var sim := CombatSim.new()
	sim.setup(live, 7)
	for i in 60:
		sim.step()
	var into_stone := 0
	for e in sim.events:
		if e.kind == "summon" and BoardModel.is_blocked(e.cell):
			into_stone += 1
	_check("summons never land in stone", into_stone == 0, "%d did" % into_stone)


func _test_barriers() -> void:
	# A wall with no thickness: both tiles usable, nothing crosses between them.
	var walls: Array[Vector4i] = []
	for x in 6:
		if x == 3:
			continue
		walls.append(Vector4i(x, 4, x, 5))
		walls.append(Vector4i(x, 6, x, 5))
	var m := _terrain_map(PackedStringArray([
		"......", "......", "......", "......", "......",
		"......",
		"......", "......", "......", "......", "......",
	]), walls)
	_check("a barrier map validates", m.is_valid(), m.invalid_reason())
	BoardModel.use_map(m)
	var board := BoardModel.new()

	_check("a barrier blocks the step across it",
		BoardModel.blocks_between(Vector2i(0, 4), Vector2i(0, 5)))
	_check("and it blocks it from either side",
		BoardModel.blocks_between(Vector2i(0, 5), Vector2i(0, 4)))
	_check("the gap in the line is open",
		not BoardModel.blocks_between(Vector2i(3, 4), Vector2i(3, 5)))
	_check("a barrier costs no tile — both sides of it stay usable",
		board.is_empty(Vector2i(0, 4)) and board.is_empty(Vector2i(0, 5))
			and not BoardModel.is_blocked(Vector2i(0, 4)))
	_check("it does not block the tile beside it",
		not BoardModel.blocks_between(Vector2i(0, 4), Vector2i(1, 4)))

	# A walker on the far side of the line must route through the gap.
	var mover := UnitInstance.create(_find("lancer"), BoardModel.TEAM_B)
	board.place(mover, Vector2i(0, 10))
	board.place(UnitInstance.create(
		BoardModel.at_tier(_find("warden"), 6), BoardModel.TEAM_A), Vector2i(0, 0))
	var sim := CombatSim.new()
	sim.setup(board, 11)
	var crossed_wall := 0
	for i in 240:
		sim.step()
	var route: Array[Vector2i] = []
	for e in sim.events:
		if e.kind == "move" and int(e.uid) == mover.uid:
			route.append(e.to)
			if BoardModel.blocks_between(e.from, e.to):
				crossed_wall += 1
	_check("the walker actually walked", route.size() > 3,
		"%d steps" % route.size())
	_check("and never stepped through a barrier", crossed_wall == 0,
		"%d illegal steps" % crossed_wall)
	var used_gap := false
	for c in route:
		if c.x == 3 and (c.y == 4 or c.y == 5 or c.y == 6):
			used_gap = true
	_check("it found the one gap in the line instead of getting stuck", used_gap,
		"route: %s" % str(route.slice(0, 12)))


func _test_high_ground() -> void:
	var shape := PackedStringArray([
		".^^^^.", "......", "......", "......", "......",
		"......",
		"......", "......", "......", "......", ".^^^^.",
	])
	var m := _terrain_map(shape, [] as Array[Vector4i])
	_check("a high-ground map validates", m.is_valid(), m.invalid_reason())
	BoardModel.use_map(m)

	_check("the ridge is high ground", BoardModel.is_high(Vector2i(2, 0)))
	_check("the flat is not", not BoardModel.is_high(Vector2i(0, 0)))
	_check("high ground is still walkable and deployable",
		BoardModel.is_playable(Vector2i(2, 0))
			and BoardModel.new().can_deploy(BoardModel.TEAM_A, Vector2i(2, 0)))

	var archer := UnitInstance.create(_find("archer"), BoardModel.TEAM_B)
	_check("an archer reaches 3 on the flat", archer.reach_on(false) == 3,
		"%d" % archer.reach_on(false))
	_check("and 4 on high ground", archer.reach_on(true) == 4,
		"%d" % archer.reach_on(true))

	var lancer := UnitInstance.create(_find("lancer"), BoardModel.TEAM_B)
	_check("a melee unit gains nothing from the height",
		lancer.reach_on(true) == lancer.reach_on(false),
		"%d against %d" % [lancer.reach_on(true), lancer.reach_on(false)])
	_check("because the bonus goes by attack type, not by band",
		archer.takes_high_ground() and not lancer.takes_high_ground())

	var pyre := UnitInstance.create(_find("pyre"), BoardModel.TEAM_B)
	_check("a spellcaster counts as ranged for this",
		pyre.reach_on(true) == pyre.reach_on(false) + 1)

	# It really changes who can be shot at.
	var board := BoardModel.new()
	var shooter := UnitInstance.create(_find("archer"), BoardModel.TEAM_B)
	board.place(shooter, Vector2i(2, 10))
	var mark := UnitInstance.create(
		BoardModel.at_tier(_find("spire"), 6), BoardModel.TEAM_A)
	board.force_place(mark, Vector2i(2, 6))
	_check("the target is exactly four tiles away",
		BoardModel.tile_distance(Vector2i(2, 10), Vector2i(2, 6)) == 4)
	_check("which is out of reach from the flat", shooter.reach_on(false) < 4)
	_check("and in reach from the ridge", shooter.reach_on(true) >= 4)

	var sim := CombatSim.new()
	sim.setup(board, 13)
	var hp := mark.current_hp
	for i in 12:
		sim.step()
	_check("standing on the ridge, it opens fire without closing in",
		mark.current_hp < hp and shooter.cell == Vector2i(2, 10),
		"target on %.0f hp, shooter at %s" % [mark.current_hp, shooter.cell])


func _test_line_of_fire() -> void:
	_section("Walls stop shots")

	var m := _terrain_map(PackedStringArray([
		".........",
		"#######..",
		".........",
		"..#######",
		".........",
		"####..###",
		"###...###",
		"####..###",
		".........",
		"..#######",
		".........",
		"#######..",
		".........",
	]), [] as Array[Vector4i])
	_check("the labyrinth shape validates", m.is_valid(), m.invalid_reason())
	BoardModel.use_map(m)

	_check("a clear line is clear",
		BoardModel.line_of_fire(Vector2i(0, 0), Vector2i(8, 0)))
	_check("a wall between two tiles stops the shot",
		not BoardModel.line_of_fire(Vector2i(0, 0), Vector2i(0, 2)))
	_check("and it stops it from the other end too",
		not BoardModel.line_of_fire(Vector2i(0, 2), Vector2i(0, 0)))
	_check("firing through the gap in the wall is fine",
		BoardModel.line_of_fire(Vector2i(8, 0), Vector2i(8, 2)))
	_check("a unit can always shoot itself's own tile",
		BoardModel.line_of_fire(Vector2i(4, 4), Vector2i(4, 4)))
	_check("adjacent tiles always see each other",
		BoardModel.line_of_fire(Vector2i(0, 0), Vector2i(0, 1))
			and BoardModel.line_of_fire(Vector2i(3, 1), Vector2i(3, 2)))

	var pairs := 0
	var mismatched := 0
	for ay in 13:
		for ax in 9:
			for by in 13:
				var a := Vector2i(ax, ay)
				var b := Vector2i(ax, by)
				pairs += 1
				if BoardModel.line_of_fire(a, b) != BoardModel.line_of_fire(b, a):
					mismatched += 1
	_check("sight is symmetric everywhere on the board", mismatched == 0,
		"%d of %d pairs disagree" % [mismatched, pairs])

	# Holes let shots through; only stone stops them.
	var gap := _terrain_map(PackedStringArray([
		"......", "......", "XXXXXX", "......", "......",
		"......",
		"......", "......", "XXXXXX", "......", "......",
	]), [] as Array[Vector4i])
	BoardModel.use_map(gap)
	_check("a hole in the board does not block a shot",
		BoardModel.line_of_fire(Vector2i(0, 1), Vector2i(0, 3)))

	# A barrier is waist-high: it stops bodies, not arrows.
	var fence := _terrain_map(PackedStringArray([
		"......", "......", "......", "......", "......",
		"......",
		"......", "......", "......", "......", "......",
	]), [Vector4i(0, 4, 0, 5), Vector4i(0, 6, 0, 5)] as Array[Vector4i])
	BoardModel.use_map(fence)
	_check("a barrier blocks the step",
		BoardModel.blocks_between(Vector2i(0, 4), Vector2i(0, 5)))
	_check("but not the shot over it",
		BoardModel.line_of_fire(Vector2i(0, 3), Vector2i(0, 6)))

	_test_shooting_at_a_wall()
	BoardModel.reset_map()


func _test_shooting_at_a_wall() -> void:
	# An archer four tiles from its target with stone in between must close in
	# rather than firing through it.
	var m := _terrain_map(PackedStringArray([
		"......", "......", "......", "..##..", "......",
		"......",
		"......", "..##..", "......", "......", "......",
	]), [] as Array[Vector4i])
	_check("the wall map validates", m.is_valid(), m.invalid_reason())
	BoardModel.use_map(m)

	var board := BoardModel.new()
	var archer := UnitInstance.create(_find("archer"), BoardModel.TEAM_B)
	board.place(archer, Vector2i(2, 9))
	var mark := UnitInstance.create(
		BoardModel.at_tier(_find("spire"), 6), BoardModel.TEAM_A)
	board.force_place(mark, Vector2i(2, 6))
	_check("the target is inside the archer's range",
		BoardModel.tile_distance(Vector2i(2, 9), Vector2i(2, 6))
			<= archer.attack_reach())
	_check("but there is a wall between them",
		not BoardModel.line_of_fire(Vector2i(2, 9), Vector2i(2, 6)))

	var sim := CombatSim.new()
	sim.setup(board, 17)
	var hp := mark.current_hp
	for i in 6:
		sim.step()
	_check("so it holds its fire", is_equal_approx(mark.current_hp, hp),
		"target took %.0f" % (hp - mark.current_hp))
	_check("and starts walking instead of standing there",
		archer.cell != Vector2i(2, 9), "still at %s" % archer.cell)

	for i in 120:
		sim.step()
	_check("once it has a clear line it opens fire",
		mark.current_hp < hp, "target still on %.0f" % mark.current_hp)
	_check("and by then it really can see the target",
		BoardModel.line_of_fire(archer.cell, mark.cell)
			or not archer.is_alive(),
		"archer at %s" % archer.cell)

	# A melee unit is never gated on sight — it is standing next to the thing.
	var lancer := UnitInstance.create(_find("lancer"), BoardModel.TEAM_B)
	_check("melee is exempt from the check",
		not lancer.is_ranged() and archer.is_ranged())


func _test_raised_units_instacast() -> void:
	_section("A raised host arrives casting")
	BoardModel.reset_map()

	var spire := _find("spire")
	var ab: AbilityData = spire.ability
	_check("Raise Host says its units arrive mid-cast", ab.summon_instacasts)
	_check("Call Wisp does not", not _find("conjurer").ability.summon_instacasts)
	_check("and the ability text tells the player",
		ab.describe().contains("already casting"), ab.describe())

	var board := BoardModel.new()
	board.configure_merges(_loadout.units, 131)
	var caster := UnitInstance.create(BoardModel.at_tier(spire, 6), BoardModel.TEAM_B)
	caster.gain_mana(95.0)
	board.place(caster, Vector2i(2, 10))
	board.place(UnitInstance.create(
		BoardModel.at_tier(_find("warden"), 4), BoardModel.TEAM_A), Vector2i(2, 0))

	var sim := CombatSim.new()
	sim.setup(board, 133)
	for i in 60:
		sim.step()

	var raised: Array[int] = []
	var raised_at := -1.0
	for e in sim.events:
		if e.kind == "summon":
			raised.append(int(e.uid))
			raised_at = e.t
	_check("the host was raised", raised.size() == 2, "%d raised" % raised.size())
	if raised.size() < 2:
		return

	var opened := 0
	var late := 0
	for e in sim.events:
		if e.kind != "cast_start" or not raised.has(int(e.uid)):
			continue
		opened += 1
		if e.t > raised_at + 0.01:
			late += 1
	var with_abilities := 0
	for uid in raised:
		var u := sim.unit_map().get(uid, null) as UnitInstance
		if u != null and u.data.ability != null and not u.data.ability.consumes_caster:
			with_abilities += 1
	_check("every raised unit that has an ability used it",
		opened == with_abilities,
		"%d cast, %d could" % [opened, with_abilities])
	if with_abilities > 0:
		_check("and it happened the instant they landed, not later",
			late == 0, "%d cast late" % late)

	# A raised Spire must not raise more Spires — that would never stop.
	var chain := BoardModel.new()
	var only_spires: Array[UnitData] = [spire]
	chain.configure_merges(only_spires, 137)
	chain.set_team_pool(BoardModel.TEAM_B, only_spires)
	var parent := UnitInstance.create(BoardModel.at_tier(spire, 6), BoardModel.TEAM_B)
	parent.gain_mana(95.0)
	chain.place(parent, Vector2i(2, 10))
	chain.place(UnitInstance.create(_find("archer"), BoardModel.TEAM_A), Vector2i(0, 0))
	var runaway := CombatSim.new()
	runaway.setup(chain, 139)
	for i in 40:
		runaway.step()
	var total := 0
	for e in runaway.events:
		if e.kind == "summon":
			total += 1
	_check("a Spire raising Spires does not cascade", total <= 2,
		"%d units raised from one cast" % total)
	_check("the board did not run away with itself",
		chain.count_of(BoardModel.TEAM_B) <= 3,
		"%d on the board" % chain.count_of(BoardModel.TEAM_B))


func _test_tier_colours() -> void:
	_section("Tiers read apart")

	var seen := {}
	for tier in range(1, DataBuilder.TIERS + 1):
		var c := UnitView.tier_color(tier)
		seen[c] = tier
	_check("every tier has its own colour", seen.size() == DataBuilder.TIERS,
		"%d distinct colours for %d tiers" % [seen.size(), DataBuilder.TIERS])

	var worst := 99.0
	var pair := ""
	for a in range(1, DataBuilder.TIERS + 1):
		for b in range(a + 1, DataBuilder.TIERS + 1):
			var ca := UnitView.tier_color(a)
			var cb := UnitView.tier_color(b)
			var gap: float = (absf(ca.r - cb.r) + absf(ca.g - cb.g)
				+ absf(ca.b - cb.b))
			if gap < worst:
				worst = gap
				pair = "T%d and T%d" % [a, b]
	_check("no two of them are near-identical", worst > 0.30,
		"%s differ by only %.2f" % [pair, worst])

	var dark := 0
	for tier in range(1, DataBuilder.TIERS + 1):
		var c := UnitView.tier_color(tier)
		if c.get_luminance() < 0.35:
			dark += 1
	_check("all of them are light enough to carry dark badge text", dark == 0,
		"%d are too dark" % dark)

	_check("asking for a tier past the top clamps instead of crashing",
		UnitView.tier_color(99) == UnitView.tier_color(DataBuilder.TIERS)
			and UnitView.tier_color(0) == UnitView.tier_color(1))

	# The top two are the ones players actually look for, and which is which is
	# a deliberate choice rather than an ordering accident.
	var t5 := UnitView.tier_color(5)
	var t6 := UnitView.tier_color(6)
	_check("tier 5 is yellow", t5.r > 0.9 and t5.g > 0.7 and t5.b < 0.5,
		str(t5))
	_check("tier 6 is red", t6.r > 0.9 and t6.g < 0.6 and t6.b < 0.6, str(t6))
	_check("and the two are not each other", t5 != t6)


func _test_the_compound() -> void:
	_section("The Compound")
	BoardModel.reset_map()

	var m: MapData = null
	for candidate in _load_maps():
		if candidate.id == &"the_compound":
			m = candidate
	_check("the compound is on disk", m != null)
	if m == null:
		return
	_check("and it is a legal board", m.is_valid(), m.invalid_reason())
	_check("it is by far the biggest thing in the game",
		m.tiles() >= 250 and m.half_tiles() >= 70,
		"%s, %d tiles a side" % [m.shape(), m.half_tiles()])

	BoardModel.use_map(m)
	var board := BoardModel.new()

	# Rooms: every open tile should have few open neighbours, because the whole
	# board is two- and three-tile pockets rather than open field.
	var open := board.playable_cells()
	var roomy := 0
	for c in open:
		var ways := 0
		for off in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			if BoardModel.is_playable(c + off):
				ways += 1
		if ways >= 4:
			roomy += 1
	_check("most of it is corridor and pocket, not open ground",
		float(roomy) / float(open.size()) < 0.45,
		"%d of %d tiles are fully open on all four sides" % [roomy, open.size()])

	var gates := 0
	for x in BoardModel.WIDTH:
		if BoardModel.is_playable(Vector2i(x, BoardModel.NEUTRAL_ROW - 1)):
			gates += 1
	_check("only a few ways lead into the middle", gates >= 3 and gates <= 6,
		"%d gates" % gates)

	# Separate rooms: two units a few tiles apart should often be unable to see
	# each other, which is what makes a fight here several small ones.
	var blind := 0
	var pairs := 0
	for a in open:
		for b in open:
			if a == b or BoardModel.tile_distance(a, b) != 3:
				continue
			pairs += 1
			if not BoardModel.line_of_fire(a, b):
				blind += 1
	_check("plenty of tiles three apart cannot see each other",
		pairs > 0 and float(blind) / float(pairs) > 0.20,
		"%d of %d blind" % [blind, pairs])

	# And it still plays: a full battle from a full draw resolves.
	board.configure_merges(_loadout.units, 5)
	var rng := RandomNumberGenerator.new()
	rng.seed = 909
	for team in [BoardModel.TEAM_A, BoardModel.TEAM_B]:
		var free := board.free_deploy_cells(team)
		for i in mini(10, free.size()):
			board.place(UnitInstance.create(_loadout.draw_one(rng), team), free[i])
	var sim := CombatSim.new()
	sim.setup(board, 911)
	sim.run()
	_check("a twenty-unit battle still resolves on it", sim.is_finished(),
		"unfinished after %.1fs" % sim.elapsed)
	var stray := 0
	for u in board.all_units():
		if BoardModel.is_blocked(u.cell):
			stray += 1
	_check("and nothing ended up inside a wall", stray == 0, "%d buried" % stray)
	BoardModel.reset_map()


func _test_sudden_death() -> void:
	_section("Rounds always end")
	BoardModel.reset_map()

	var sim := CombatSim.new()
	sim.setup(_duel_board(_find("archer"), _find("archer")), 3)
	_check("nothing is amplified at the start",
		is_equal_approx(sim.pressure(), 1.0), "%.2f" % sim.pressure())
	while sim.elapsed < CombatSim.SUDDEN_DEATH and not sim.is_finished():
		sim.step()
	_check("and nothing is amplified up to the threshold",
		is_equal_approx(sim.pressure(), 1.0), "%.2f at %.1fs" % [
			sim.pressure(), sim.elapsed])

	# The pair that could not finish: two tier 1 Wardens and a Revenant.
	var board := BoardModel.new()
	board.configure_merges(_loadout.units, 5)
	board.place(UnitInstance.create(_find("warden"), BoardModel.TEAM_A),
		Vector2i(3, 0))
	board.place(UnitInstance.create(_find("revenant"), BoardModel.TEAM_A),
		Vector2i(2, 1))
	board.place(UnitInstance.create(_find("warden"), BoardModel.TEAM_B),
		Vector2i(2, 10))
	var slog := CombatSim.new()
	slog.setup(board, 7)
	var result := slog.run()
	_check("a grind that used to time out now finishes", slog.is_finished()
		and slog.elapsed < CombatSim.DEFAULT_TIMEOUT,
		"ran %.1fs of %.1fs" % [slog.elapsed, CombatSim.DEFAULT_TIMEOUT])
	_check("and it finishes with somebody actually wiped out",
		board.living_units_of(BoardModel.TEAM_A).is_empty()
			or board.living_units_of(BoardModel.TEAM_B).is_empty(),
		"A %d, B %d" % [board.living_units_of(BoardModel.TEAM_A).size(),
			board.living_units_of(BoardModel.TEAM_B).size()])
	_check("the winner is a real side", result != CombatSim.RESULT_DRAW
		or slog.elapsed < CombatSim.DEFAULT_TIMEOUT)

	var announced := false
	for e in slog.events:
		if e.kind == "sudden_death":
			announced = true
			_check("sudden death is announced when it starts, not before",
				float(e.at) > CombatSim.SUDDEN_DEATH
					and float(e.at) < CombatSim.SUDDEN_DEATH + 1.0,
				"announced at %.1fs" % float(e.at))
	_check("and it is announced exactly once",
		announced and _count_events(slog, "sudden_death") == 1,
		"%d announcements" % _count_events(slog, "sudden_death"))

	# It presses both sides equally, so it cannot decide a round by itself.
	var wins := [0, 0]
	for seed_value in 24:
		var b := BoardModel.new()
		b.configure_merges(_loadout.units, seed_value)
		var cell: Vector2i = b.deploy_cells(BoardModel.TEAM_A)[2]
		b.place(UnitInstance.create(_find("warden"), BoardModel.TEAM_A), cell)
		b.place(UnitInstance.create(_find("warden"), BoardModel.TEAM_B),
			BoardModel.mirror(cell))
		var duel := CombatSim.new()
		duel.setup(b, seed_value + 91)
		var who := duel.run()
		if who >= 0:
			wins[who] += 1
	_check("a mirror duel under pressure is still near even",
		absi(wins[0] - wins[1]) <= 8, "A %d / B %d" % [wins[0], wins[1]])


func _overkill_stage(victim_tier: int) -> Dictionary:
	## One Warden on each side, far enough apart that neither reaches the other on
	## its own. Nothing happens in this fixture that the test does not do to it.
	BoardModel.reset_map()
	var b := BoardModel.new()
	var killer := UnitInstance.create(
		BoardModel.at_tier(_must_find("warden"), 6), BoardModel.TEAM_A)
	b.force_place(killer, Vector2i(2, 2))
	var mark := UnitInstance.create(
		BoardModel.at_tier(_must_find("warden"), victim_tier), BoardModel.TEAM_B)
	b.force_place(mark, Vector2i(2, 9))
	var sim := CombatSim.new()
	sim.setup(b, 517)
	# A crit is a doubling rolled inside _damage, so leaving it on would make the
	# thing under test depend on a coin flip.
	sim.crit_chance = 0.0
	# setup() resolves the openers, and the Warden's opener is a shield worth more
	# than its own health. Overkill is measured against the health BAR, so a
	# leftover shield would only change how much damage it takes to reach the
	# death — never the flag — and stripping it keeps the arithmetic in these
	# checks readable.
	mark.shield = 0.0
	return {sim = sim, killer = killer, mark = mark}


func _death_flag(sim: CombatSim, uid: int, key: String, fallback := false) -> bool:
	for e in sim.events:
		if e.kind == "death" and int(e.uid) == uid:
			return bool(e.get(key, fallback))
	return fallback


func _test_overkill_is_measured_against_the_whole_bar() -> void:
	_section("Overkill is a hit bigger than the whole health bar")

	# The same victim, at full health, killed two different ways. Both die; only
	# one of them is an overkill, and the difference is the SIZE of the blow and
	# nothing else — same unit, same tier, same starting health.
	var big := _overkill_stage(3)
	var max_hp: float = big.mark.stat(StatModifier.Stat.MAX_HP)
	big.sim._damage(big.mark, max_hp * 3.0, big.killer)
	_check("a blow three times the bar kills it", not big.mark.is_alive())
	_check("and it is flagged as an overkill",
		_death_flag(big.sim, big.mark.uid, "overkill"))

	# The chip death. The victim is worn down to a sliver first, then finished by
	# a hit far smaller than its bar. This is the case the naive rule — "damage
	# bigger than the health remaining" — gets wrong, and it is by far the most
	# common death in the game, which is why it must not be the loud one.
	var chip := _overkill_stage(3)
	var bar: float = chip.mark.stat(StatModifier.Stat.MAX_HP)
	chip.mark.shield = 0.0
	chip.mark.current_hp = 1.0
	chip.sim._damage(chip.mark, bar * 0.5, chip.killer)
	_check("a hit worth half a bar still kills a unit on a sliver",
		not chip.mark.is_alive())
	_check("but being finished off is not an overkill",
		not _death_flag(chip.sim, chip.mark.uid, "overkill"))

	# And the threshold moves with the victim, not with some fixed number. The
	# exact same blow is an overkill against a tier 1 and an ordinary death
	# against a tier 6, because a tier 6 Warden's bar is far larger.
	var small := _overkill_stage(1)
	var large := _overkill_stage(6)
	var blow: float = small.mark.stat(StatModifier.Stat.MAX_HP) * 2.0
	# The big unit is stood on the same amount of health the blow will land for,
	# so it dies to it as surely as the small one does. That is the point: both
	# deaths are certain, and the only thing separating them is the size of the
	# bar the blow is measured against.
	large.mark.current_hp = blow * 0.9
	small.sim._damage(small.mark, blow, small.killer)
	large.sim._damage(large.mark, blow, large.killer)
	_check("both are dead", not small.mark.is_alive()
		and not large.mark.is_alive())
	_check("one blow overkills the small unit",
		_death_flag(small.sim, small.mark.uid, "overkill"))
	_check("and merely kills the big one",
		not _death_flag(large.sim, large.mark.uid, "overkill"),
		"%.0f damage against a %.0f bar" % [
			blow, large.mark.stat(StatModifier.Stat.MAX_HP)])


func _test_every_death_names_its_unit() -> void:
	_section("Every death says which unit it was")

	# The view needs this to pick a voice line, and it cannot ask the roster: a
	# summon that was never on the loadout has no row there to find.
	var stage := _overkill_stage(3)
	stage.sim._damage(stage.mark, 999999.0, stage.killer)
	var named := ""
	for e in stage.sim.events:
		if e.kind == "death" and int(e.uid) == stage.mark.uid:
			named = String(e.get("unit_id", ""))
	_check("the death carries the unit's id", named == "warden",
		"named '%s'" % named)

	# Including the one death that is not a kill. A unit that spends itself still
	# drops a body, and the body still belongs to somebody.
	var spire := _find_consuming_caster()
	if spire == null:
		_check("no self-consuming unit on the roster to check", true)
		return
	BoardModel.reset_map()
	var b := BoardModel.new()
	var caster := UnitInstance.create(BoardModel.at_tier(spire, 3),
		BoardModel.TEAM_A)
	b.force_place(caster, Vector2i(3, 3))
	var foe := UnitInstance.create(
		BoardModel.at_tier(_must_find("warden"), 1), BoardModel.TEAM_B)
	b.force_place(foe, Vector2i(3, 9))
	var sim := CombatSim.new()
	sim.setup(b, 41)
	sim._consume_caster(caster)
	var spent := ""
	for e in sim.events:
		if e.kind == "death" and int(e.uid) == caster.uid:
			spent = String(e.get("unit_id", ""))
	_check("a spent caster's death names it too", spent == String(spire.id),
		"named '%s', expected '%s'" % [spent, spire.id])


func _find_consuming_caster() -> UnitData:
	for u in _roster().units:
		if u.ability != null and u.ability.consumes_caster:
			return u
	return null


func _count_events(sim: CombatSim, kind: String) -> int:
	var n := 0
	for e in sim.events:
		if e.kind == kind:
			n += 1
	return n


func _test_live_counts() -> void:
	_section("The live count is the sim's own")
	BoardModel.reset_map()

	var board := BoardModel.new()
	board.configure_merges(_loadout.units, 3)
	var rng := RandomNumberGenerator.new()
	rng.seed = 61
	for team in [BoardModel.TEAM_A, BoardModel.TEAM_B]:
		var free := board.free_deploy_cells(team)
		for i in 6:
			board.place(UnitInstance.create(_loadout.draw_one(rng), team), free[i])

	var sim := CombatSim.new()
	sim.setup(board, 63)
	var opening := -1
	for e in sim.events:
		if e.kind == "counts":
			opening = int(e.b)
			break
	_check("the opening tally is announced before a blow is struck",
		opening == 6, "%d" % opening)

	# Replay it the way the view does and compare against the model at each step.
	var replay := CombatSim.new()
	replay.setup(board, 63)
	var drift := 0
	var checks := 0
	var seen := [-1, -1]
	while not replay.is_finished() and replay.elapsed < 40.0:
		replay.step()
		for e in replay.events:
			if e.kind == "counts":
				seen = [int(e.a), int(e.b)]
		checks += 1
		if seen[BoardModel.TEAM_A] != replay.living_count(BoardModel.TEAM_A) \
				or seen[BoardModel.TEAM_B] != replay.living_count(BoardModel.TEAM_B):
			drift += 1
	_check("what the log says never drifts from what the board holds",
		drift == 0, "%d of %d ticks disagreed" % [drift, checks])

	_check("a unit mid-revive is still counted for its side",
		_revive_stays_counted())

	var quiet := 0
	var last := [-1, -1]
	for e in sim.events:
		if e.kind != "counts":
			continue
		if int(e.a) == last[0] and int(e.b) == last[1]:
			quiet += 1
		last = [int(e.a), int(e.b)]
	_check("and it only speaks up when the tally actually changes",
		quiet == 0, "%d repeated announcements" % quiet)


func _revive_stays_counted() -> bool:
	var board := BoardModel.new()
	board.place(UnitInstance.create(_find("revenant"), BoardModel.TEAM_B),
		Vector2i(2, 10))
	board.place(UnitInstance.create(
		BoardModel.at_tier(_find("pyre"), 6), BoardModel.TEAM_A), Vector2i(2, 0))
	var sim := CombatSim.new()
	sim.setup(board, 67)
	for i in 400:
		sim.step()
		var rising := sim.pending_respawns(BoardModel.TEAM_B)
		if rising > 0:
			return sim.living_count(BoardModel.TEAM_B) >= rising
	return true


func _test_the_labyrinth() -> void:
	_section("The Labyrinth")
	BoardModel.reset_map()

	var m: MapData = null
	for candidate in _load_maps():
		if candidate.id == &"the_labyrinth":
			m = candidate
	_check("the labyrinth is on disk", m != null)
	if m == null:
		return
	_check("and it is a legal board", m.is_valid(), m.invalid_reason())

	BoardModel.use_map(m)
	var board := BoardModel.new()
	var open := board.playable_cells()

	# Muster ground: both far ends fully open, and enough of it to deploy into.
	var stage := 0
	while stage < BoardModel.HEIGHT and _row_is_open(stage):
		stage += 1
	_check("each side musters on open rows at its own end", stage >= 2,
		"only %d open rows at the end" % stage)
	var far := 0
	while far < BoardModel.HEIGHT and _row_is_open(BoardModel.HEIGHT - 1 - far):
		far += 1
	_check("and the two muster grounds are the same size", far == stage,
		"%d at the top, %d at the bottom" % [stage, far])
	_check("there is real room to deploy in it",
		stage * BoardModel.WIDTH >= 18,
		"%d muster tiles" % (stage * BoardModel.WIDTH))

	# Everything between is corridor.
	var junctions := 0
	var inner := 0
	for c in open:
		if c.y < stage or c.y >= BoardModel.HEIGHT - stage:
			continue
		inner += 1
		if _open_ways(c) >= 3:
			junctions += 1
	_check("the middle is one tile wide almost everywhere",
		inner > 0 and float(junctions) / float(inner) < 0.20,
		"%d junctions in %d maze tiles" % [junctions, inner])
	var dead_ends := 0
	for c in open:
		if c.y >= stage and c.y < BoardModel.HEIGHT - stage and _open_ways(c) == 1:
			dead_ends += 1
	_check("and it has dead ends, like a maze should", dead_ends >= 4,
		"%d dead ends" % dead_ends)

	var crossings := 0
	for x in BoardModel.WIDTH:
		if BoardModel.is_playable(Vector2i(x, BoardModel.NEUTRAL_ROW)):
			crossings += 1
	_check("only a couple of ways lead through the middle",
		crossings >= 1 and crossings <= 3, "%d crossings" % crossings)

	_check("every tile of it is still reachable",
		_flood(board) == open.size(),
		"%d of %d" % [_flood(board), open.size()])
	_check("and you cannot see from one muster ground to the other",
		not BoardModel.line_of_fire(Vector2i(BoardModel.WIDTH / 2, 0),
			Vector2i(BoardModel.WIDTH / 2, BoardModel.HEIGHT - 1)))

	# It plays: a real draw on both sides, fought to a finish.
	board.configure_merges(_loadout.units, 5)
	var rng := RandomNumberGenerator.new()
	rng.seed = 313
	for team in [BoardModel.TEAM_A, BoardModel.TEAM_B]:
		var free := board.free_deploy_cells(team)
		for i in mini(6, free.size()):
			board.place(UnitInstance.create(_loadout.draw_one(rng), team), free[i])
	var sim := CombatSim.new()
	sim.setup(board, 317)
	sim.run()
	_check("a battle in the maze still finishes", sim.is_finished(),
		"unfinished after %.1fs" % sim.elapsed)
	var buried := 0
	for u in board.all_units():
		if BoardModel.is_blocked(u.cell):
			buried += 1
	_check("with nobody stuck inside a wall", buried == 0, "%d buried" % buried)
	BoardModel.reset_map()


func _row_is_open(y: int) -> bool:
	for x in BoardModel.WIDTH:
		if not BoardModel.is_playable(Vector2i(x, y)):
			return false
	return true


func _open_ways(c: Vector2i) -> int:
	var n := 0
	for off in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
		if BoardModel.is_playable(c + off):
			n += 1
	return n


func _copies_for_certainty(buff: BuffData) -> int:
	var each := buff.magnitude(BuffData.Rarity.GOLD).x
	if each <= 0.0:
		return 1
	return ceili(1.0 / each)



func _test_grief_mana() -> void:
	_section("Charging off your own dead")
	var vig := _find("vigil")
	var dev := _find("devourer")
	_check("the Vigil gains nothing from swinging", vig.mana_per_attack == 0.0,
		"%.0f a swing" % vig.mana_per_attack)
	_check("the Devourer gains nothing from swinging either",
		dev.mana_per_attack == 0.0, "%.0f a swing" % dev.mana_per_attack)
	_check("both charge off allied deaths",
		vig.mana_per_ally_death > 0.0 and dev.mana_per_ally_death > 0.0)
	# Nobody else in the game does. If a second unit ever wants this the test
	# should be updated deliberately rather than quietly passing.
	var eaters: Array[String] = []
	for u in _roster().units:
		if u.mana_per_ally_death > 0.0:
			eaters.append(String(u.id))
	eaters.sort()
	_check("and only those two do", eaters == ["devourer", "vigil"],
		", ".join(eaters))

	# The bar has to move when a friend dies, and NOT when an enemy dies.
	var b := BoardModel.new()
	var v := UnitInstance.create(vig, BoardModel.TEAM_A)
	b.force_place(v, Vector2i(0, 0))
	var friend := UnitInstance.create(
		BoardModel.at_tier(_must_find("archer"), 1), BoardModel.TEAM_A)
	b.force_place(friend, Vector2i(1, 0))
	var foe := UnitInstance.create(
		BoardModel.at_tier(_must_find("archer"), 1), BoardModel.TEAM_B)
	b.force_place(foe, Vector2i(5, 10))
	var sim := CombatSim.new()
	sim.setup(b, 11)
	var before := v.mana
	sim._damage(foe, 9999.0, friend)
	_check("an enemy dying does nothing for it", is_equal_approx(v.mana, before),
		"mana went %.0f -> %.0f" % [before, v.mana])
	sim._damage(friend, 9999.0, foe)
	_check("one of its own dying fills part of the bar",
		v.mana >= vig.mana_per_ally_death - 0.01,
		"mana is %.0f after a friendly death" % v.mana)


func _test_vigil_raises_by_tier() -> void:
	_section("The Vigil, and how many it hands back")
	var vig := _find("vigil")
	var ab: AbilityData = vig.ability
	_check("Lament is a raise", ab != null and ab.kind == AbilityData.Kind.RAISE)
	_check("and they come back hurt, not whole",
		is_equal_approx(ab.raise_hp_percent, 0.85),
		"%.2f of max" % ab.raise_hp_percent)

	# Count scales with tier and nothing else. Tier 1 gives one, tier 6 gives six.
	for t in [1, 3, 6]:
		var b := BoardModel.new()
		var v := UnitInstance.create(BoardModel.at_tier(vig, t), BoardModel.TEAM_A)
		b.force_place(v, Vector2i(0, 0))
		var sim := CombatSim.new()
		sim.setup(b, 3)
		_check("a tier %d Vigil raises %d" % [t, t], sim.raise_count(v) == t,
			"it would raise %d" % sim.raise_count(v))

	# And they actually stand back up, at the right health, on the board.
	var b2 := BoardModel.new()
	var v2 := UnitInstance.create(BoardModel.at_tier(vig, 3), BoardModel.TEAM_A)
	b2.force_place(v2, Vector2i(0, 5))
	var dead: Array[UnitInstance] = []
	for i in 4:
		var m := UnitInstance.create(
			BoardModel.at_tier(_must_find("archer"), 1), BoardModel.TEAM_A)
		b2.force_place(m, Vector2i(1, 4 + i))
		dead.append(m)
	var killer := UnitInstance.create(
		BoardModel.at_tier(_must_find("archer"), 1), BoardModel.TEAM_B)
	b2.force_place(killer, Vector2i(5, 0))
	var sim2 := CombatSim.new()
	sim2.setup(b2, 7)
	for m in dead:
		sim2._damage(m, 9999.0, killer)
	_check("four of its own fell", not dead[0].is_alive() and not dead[3].is_alive())
	v2.mana = UnitInstance.MANA_MAX
	sim2._resolve_ability(v2)
	var up := 0
	for m in dead:
		if m.is_alive():
			up += 1
	_check("a tier 3 Vigil brings exactly three of the four back", up == 3,
		"%d got up" % up)
	for m in dead:
		if not m.is_alive():
			continue
		var want: float = m.stat(StatModifier.Stat.MAX_HP) * 0.85
		_check("and it comes back at 85%%, not whole",
			absf(m.current_hp - want) < 0.5,
			"%.0f of %.0f" % [m.current_hp, m.stat(StatModifier.Stat.MAX_HP)])
		break
	# Nothing is raised twice: the fourth body is still down and the pile is empty
	# of everything already standing.
	v2.mana = UnitInstance.MANA_MAX
	sim2._resolve_ability(v2)
	var up2 := 0
	for m in dead:
		if m.is_alive():
			up2 += 1
	_check("a second cast finds only the one body it has not used", up2 == 4,
		"%d standing after the second cast" % up2)


func _test_remembrance_adds_raises() -> void:
	_section("Remembrance")
	var pool := _pool()
	var buff: BuffData = null
	for x in pool.buffs:
		if x.id == &"remembrance":
			buff = x
	_check("the Vigil has its own buff", buff != null)
	if buff == null:
		return
	_check("it is a max-health buff at 50/100/150%",
		is_equal_approx(buff.bronze.x, 0.50) and is_equal_approx(buff.silver.x, 1.00)
			and is_equal_approx(buff.gold.x, 1.50),
		"%.2f / %.2f / %.2f" % [buff.bronze.x, buff.silver.x, buff.gold.x])
	_check("and it adds one more raise per step",
		buff.extra_raises_at(BuffData.Rarity.BRONZE) == 1
			and buff.extra_raises_at(BuffData.Rarity.SILVER) == 2
			and buff.extra_raises_at(BuffData.Rarity.GOLD) == 3)

	for r in [BuffData.Rarity.BRONZE, BuffData.Rarity.SILVER, BuffData.Rarity.GOLD]:
		var b := BoardModel.new()
		var v := UnitInstance.create(
			BoardModel.at_tier(_find("vigil"), 2), BoardModel.TEAM_A)
		b.force_place(v, Vector2i(0, 0))
		var sim := CombatSim.new()
		sim.setup(b, 5)
		var tb := TeamBuffs.new()
		tb.add(buff, r)
		sim.team_buffs[BoardModel.TEAM_A] = tb
		var want: int = 2 + buff.extra_raises_at(r)
		_check("a tier 2 Vigil with the %s pick raises %d" % [
				BuffData.rarity_name(r).to_lower(), want],
			sim.raise_count(v) == want, "it raises %d" % sim.raise_count(v))

	# It must not leak onto anything else. Remembrance is the Vigil's buff.
	var b3 := BoardModel.new()
	var other := UnitInstance.create(_find("warden"), BoardModel.TEAM_A)
	b3.force_place(other, Vector2i(0, 0))
	var sim3 := CombatSim.new()
	sim3.setup(b3, 5)
	var tb3 := TeamBuffs.new()
	tb3.add(buff, BuffData.Rarity.GOLD)
	_check("and a Warden gets no raises out of it",
		tb3.extra_raises_for(other) == 0)


func _test_devourer_ascends() -> void:
	_section("The Devourer, and the swing that deletes")
	var dev := _find("devourer")
	var ab: AbilityData = dev.ability
	_check("Gorge is an ascension", ab != null and ab.kind == AbilityData.Kind.ASCEND)
	_check("the changed form is bigger", ab.ascend_hp_mult > 1.0)
	_check("faster to swing", ab.ascend_attack_speed_mult > 1.0)
	_check("and faster on its feet", ab.ascend_move_mult < 1.0)

	var b := BoardModel.new()
	var d := UnitInstance.create(BoardModel.at_tier(dev, 2), BoardModel.TEAM_A)
	b.force_place(d, Vector2i(0, 0))
	var prey := UnitInstance.create(
		BoardModel.at_tier(_find("warden"), 6), BoardModel.TEAM_B)
	b.force_place(prey, Vector2i(1, 0))
	var sim := CombatSim.new()
	sim.setup(b, 9)

	var hp_before := d.stat(StatModifier.Stat.MAX_HP)
	var swing_before := d.attack_interval()
	var walk_before := d.stat(StatModifier.Stat.MOVE_TIME)
	d.mana = UnitInstance.MANA_MAX
	sim._resolve_ability(d)
	_check("the first full bar changes it", d.ascended)
	_check("it does not arm a swing at the same time", not d.executes_next)
	_check("its health went up", d.stat(StatModifier.Stat.MAX_HP) > hp_before,
		"%.0f -> %.0f" % [hp_before, d.stat(StatModifier.Stat.MAX_HP)])
	_check("it swings faster", d.attack_interval() < swing_before,
		"%.2fs -> %.2fs" % [swing_before, d.attack_interval()])
	_check("and it walks faster", d.stat(StatModifier.Stat.MOVE_TIME) < walk_before,
		"%.2fs -> %.2fs" % [walk_before, d.stat(StatModifier.Stat.MOVE_TIME)])

	# The second bar arms rather than transforming again.
	d.mana = UnitInstance.MANA_MAX
	sim._resolve_ability(d)
	_check("the next full bar arms a swing instead", d.executes_next)

	# And the armed swing deletes a tier 6 Warden outright — shield and all. That
	# unit is chosen on purpose: its opening shield is worth more than its health,
	# so anything short of a real execute leaves it standing.
	prey.add_shield(prey.stat(StatModifier.Stat.MAX_HP), prey.stat(StatModifier.Stat.MAX_HP) * 2.0)
	var pool := prey.effective_hp()
	_check("the prey is very much alive and shielded", prey.is_alive() and pool > 1000.0,
		"%.0f effective health" % pool)
	d.target = prey
	sim._begin_attack(d)
	_check("one armed swing kills it whatever its health", not prey.is_alive(),
		"it has %.0f left" % prey.effective_hp())
	_check("and the swing is spent", not d.executes_next)


func _test_devourer_cannot_start_alone() -> void:
	_section("The Devourer cannot feed itself")
	# The whole shape of the unit is that it needs its own side to die. An
	# unascended Devourer swinging all day must never fill its own bar.
	var b := BoardModel.new()
	var d := UnitInstance.create(_find("devourer"), BoardModel.TEAM_A)
	b.force_place(d, Vector2i(0, 0))
	var sack := UnitInstance.create(
		BoardModel.at_tier(_find("warden"), 6), BoardModel.TEAM_B)
	b.force_place(sack, Vector2i(1, 0))
	var sim := CombatSim.new()
	sim.setup(b, 13)
	d.target = sack
	for i in 12:
		sim._begin_attack(d)
	_check("twelve swings leave the bar exactly where it started",
		is_zero_approx(d.mana), "mana is %.0f" % d.mana)
	_check("so it has not changed", not d.ascended)

	# Once changed, the same swings do charge it.
	d.mana = UnitInstance.MANA_MAX
	sim._resolve_ability(d)
	_check("after it changes, it is ascended", d.ascended)
	d.mana = 0.0
	sim._begin_attack(d)
	_check("and now a swing moves the bar", d.mana > 0.0,
		"mana is %.0f" % d.mana)


func _test_gluttony() -> void:
	_section("Gluttony")
	var pool := _pool()
	var buff: BuffData = null
	for x in pool.buffs:
		if x.id == &"gluttony":
			buff = x
	_check("the Devourer has its own buff", buff != null)
	if buff == null:
		return
	_check("max health at 50 / 100 / 150%",
		is_equal_approx(buff.bronze.x, 0.50) and is_equal_approx(buff.silver.x, 1.00)
			and is_equal_approx(buff.gold.x, 1.50),
		"%.2f / %.2f / %.2f" % [buff.bronze.x, buff.silver.x, buff.gold.x])
	_check("attack speed at 20 / 40 / 60%",
		buff.uses_second_stat
			and is_equal_approx(buff.bronze.y, 0.20)
			and is_equal_approx(buff.silver.y, 0.40)
			and is_equal_approx(buff.gold.y, 0.60),
		"%.2f / %.2f / %.2f" % [buff.bronze.y, buff.silver.y, buff.gold.y])
	_check("and it is the Devourer's, not everyone's",
		buff.unit_id == &"devourer" and not buff.is_global())


func _test_empowered_paragon_is_slow() -> void:
	_section("The empowered Paragon winds up")
	var par := _must_find("paragon")
	_check("its empowered form swings slower, not faster",
		par.empower_attack_speed_mult < 1.0,
		"x%.2f attack speed" % par.empower_attack_speed_mult)
	_check("and hits much harder to pay for it",
		par.empower_damage_mult >= 3.0,
		"x%.1f damage" % par.empower_damage_mult)
	# Nobody else empowers into a slower form. If a second unit ever does, this
	# should be changed deliberately.
	for u in _roster().units:
		if u.id == &"paragon":
			continue
		_check_once("no other unit slows itself down when empowered",
			is_equal_approx(u.empower_attack_speed_mult, 1.0),
			"%s is at x%.2f" % [u.id, u.empower_attack_speed_mult])

	# One on the board: empowered, and demonstrably slower than the plain unit.
	var solo := BoardModel.new()
	var alone := UnitInstance.create(par, BoardModel.TEAM_A)
	solo.force_place(alone, Vector2i(0, 0))
	var s1 := CombatSim.new()
	s1.setup(solo, 21)
	_check("a lone Paragon is empowered", alone.empowered)
	var slow := alone.attack_interval()

	# Two on the board: neither is empowered, so neither is slowed. This is the
	# check that matters — the wind-up must be a cost of the empowered form and
	# not a nerf to the unit itself.
	var pair := BoardModel.new()
	var a := UnitInstance.create(par, BoardModel.TEAM_A)
	var b := UnitInstance.create(par, BoardModel.TEAM_A)
	pair.force_place(a, Vector2i(0, 0))
	pair.force_place(b, Vector2i(1, 0))
	var s2 := CombatSim.new()
	s2.setup(pair, 21)
	_check("two Paragons are both ordinary", not a.empowered and not b.empowered)
	var quick := a.attack_interval()
	_check("the empowered one takes far longer between swings", slow > quick * 2.0,
		"%.2fs empowered vs %.2fs plain" % [slow, quick])
	_check("and its wind-up is measured in seconds", slow >= 3.0,
		"%.2fs between swings" % slow)

	# Per swing it must be worth much more than the plain unit, or the trade is
	# simply bad rather than different.
	_check("but one empowered swing is worth several ordinary ones",
		alone.stat(StatModifier.Stat.ATTACK_DAMAGE)
			>= a.stat(StatModifier.Stat.ATTACK_DAMAGE) * 3.0,
		"%.0f vs %.0f a swing" % [
			alone.stat(StatModifier.Stat.ATTACK_DAMAGE),
			a.stat(StatModifier.Stat.ATTACK_DAMAGE)])


func _test_melee_reaches_the_corners() -> void:
	_section("Melee swings at the corners too")
	_check("the eight tiles around a cell all count as beside it",
		BoardModel.is_beside(Vector2i(3, 3), Vector2i(2, 2))
			and BoardModel.is_beside(Vector2i(3, 3), Vector2i(4, 4))
			and BoardModel.is_beside(Vector2i(3, 3), Vector2i(3, 2)))
	_check("but its own tile does not",
		not BoardModel.is_beside(Vector2i(3, 3), Vector2i(3, 3)))
	_check("and two tiles away does not",
		not BoardModel.is_beside(Vector2i(3, 3), Vector2i(5, 3)))
	# Only the melee band changes. A medium unit still reaches a diamond, so the
	# corner of its 5x5 is out — that is the whole reason in_reach takes a band
	# rather than just measuring in boxes everywhere.
	_check("a medium unit still measures in steps, not boxes",
		BoardModel.in_reach(Vector2i(3, 3), Vector2i(3, 5), 2)
			and not BoardModel.in_reach(Vector2i(3, 3), Vector2i(5, 5), 2))

	# In the sim: a melee unit diagonally adjacent to its enemy must swing rather
	# than shuffle. Before this it was two Manhattan steps away and out of reach.
	var b := BoardModel.new()
	var hitter := UnitInstance.create(_must_find("reaver"), BoardModel.TEAM_A)
	b.force_place(hitter, Vector2i(2, 4))
	var mark := UnitInstance.create(
		BoardModel.at_tier(_must_find("warden"), 1), BoardModel.TEAM_B)
	b.force_place(mark, Vector2i(3, 5))
	_check("they are set up on a diagonal",
		BoardModel.tile_distance(hitter.cell, mark.cell) == 2
			and BoardModel.is_beside(hitter.cell, mark.cell))
	var sim := CombatSim.new()
	sim.setup(b, 31)
	sim._decide(hitter)
	_check("the melee unit attacks rather than walking round",
		hitter.state == UnitInstance.State.ATTACKING,
		"it is %d" % hitter.state)
	_check("and it has not moved off its tile", hitter.cell == Vector2i(2, 4))


func _test_a_stuck_unit_still_swings() -> void:
	_section("A unit that cannot walk still fights")
	# The bug: a unit whose chosen target is unreachable used to try to move,
	# fail, and then do nothing at all — even with an enemy at its elbow.
	#
	# Getting a unit to WANT something it cannot reach takes work, and two
	# earlier versions of this test failed to do it:
	#   - Boxing it in with Spires does not box it in. _begin_move trades places
	#     with a rooted neighbour on purpose, so that wall is a door.
	#   - Boxing it in with movable friends does box it in, but then it simply
	#     targets the adjacent enemy and attacks through the ordinary path. The
	#     test passed without the fix and proved nothing.
	# A taunt is the honest case: _mark_for overrides distance entirely, so the
	# unit is committed to something across the board while being elbowed.
	var b := BoardModel.new()
	var boxed := UnitInstance.create(_must_find("reaver"), BoardModel.TEAM_A)
	b.force_place(boxed, Vector2i(2, 2))
	for c in [Vector2i(1, 2), Vector2i(3, 2), Vector2i(2, 1), Vector2i(2, 3)]:
		b.force_place(UnitInstance.create(
			BoardModel.at_tier(_must_find("warden"), 1), BoardModel.TEAM_A), c)
	var corner := UnitInstance.create(
		BoardModel.at_tier(_must_find("warden"), 1), BoardModel.TEAM_B)
	b.force_place(corner, Vector2i(1, 1))
	# The Paragon must be the LONE one of its kind to empower, and only an
	# empowered Paragon may taunt.
	var roarer := UnitInstance.create(_must_find("paragon"), BoardModel.TEAM_B)
	b.force_place(roarer, Vector2i(2, 4))
	var sim := CombatSim.new()
	sim.setup(b, 37)
	_check("the Paragon is empowered and can hold", roarer.empowered)
	sim._resolve_taunt(roarer, roarer.data.ability)
	_check("and it is taunting", roarer.is_taunting())

	# What it WANTS, asked before _decide runs — the fallback deliberately
	# re-points u.target at whatever it settled for, so reading target afterwards
	# tells you nothing about who it was called to.
	_check("the taunt takes its attention off the enemy beside it",
		sim._mark_for(boxed) == roarer,
		"it wants %s" % ("nothing" if sim._mark_for(boxed) == null
			else sim._mark_for(boxed).data.display_name))

	boxed.state = UnitInstance.State.IDLE
	boxed.state_timer = 0.0
	sim._decide(boxed)
	_check("it cannot walk to the thing it wants", boxed.cell == Vector2i(2, 2),
		"it moved to %s" % boxed.cell)
	_check("so it swings at what it can reach instead",
		boxed.state == UnitInstance.State.ATTACKING,
		"it is state %d" % boxed.state)
	_check("and what it settled for is the one at its corner",
		boxed.target == corner)


func _test_nothing_in_reach_is_not_an_attack() -> void:
	_section("The consolation swing is not a free one")
	# The other half of the same rule: a unit that cannot move and has nothing in
	# reach must still do nothing, rather than reaching across the board.
	var b := BoardModel.new()
	var boxed := UnitInstance.create(_must_find("reaver"), BoardModel.TEAM_A)
	b.force_place(boxed, Vector2i(2, 2))
	for c in [Vector2i(1, 2), Vector2i(3, 2), Vector2i(2, 1), Vector2i(2, 3)]:
		b.force_place(UnitInstance.create(
			BoardModel.at_tier(_must_find("warden"), 1), BoardModel.TEAM_A), c)
	b.force_place(UnitInstance.create(
		BoardModel.at_tier(_must_find("warden"), 1), BoardModel.TEAM_B),
		Vector2i(2, 9))
	var sim := CombatSim.new()
	sim.setup(b, 39)
	sim._decide(boxed)
	_check("with nothing within arm's length it does not invent an attack",
		boxed.state != UnitInstance.State.ATTACKING,
		"it is state %d" % boxed.state)
	_check("and it stays where it is", boxed.cell == Vector2i(2, 2))


func _high_board() -> Dictionary:
	# The Terrace, so the rules are exercised against the shape a player will
	# actually meet rather than a synthetic plateau.
	var m: MapData = load("res://data/maps/the_terrace.tres")
	BoardModel.use_map(m)
	var b := BoardModel.new()
	var sim := CombatSim.new()
	return {map = m, board = b, sim = sim}


func _test_high_ground_rules() -> void:
	_section("High ground, and who can reach it")
	var m: MapData = load("res://data/maps/the_terrace.tres")
	_check("The Terrace loads", m != null and m.is_valid(),
		"" if m == null else m.invalid_reason())
	if m == null:
		return
	var high := 0
	var stairs := 0
	for y in m.height:
		for x in m.width:
			var c := Vector2i(x, y)
			if m.is_high(c):
				high += 1
			elif m.is_stairs(c):
				stairs += 1
	_check("it has a terrace on it", high > 0, "%d high tiles" % high)
	_check("and stairs to get onto it", stairs > 0, "%d stair tiles" % stairs)

	var stage := _high_board()
	var b: BoardModel = stage.board
	# The front lip of the terrace, a stair tile beside it, and the open tile
	# directly below — all three orthogonally adjacent, so range is never what
	# decides any of these checks.
	var top := Vector2i(4, 2)
	var step := Vector2i(3, 3)
	var ground := Vector2i(4, 3)
	_check("the board agrees which tiles are which",
		BoardModel.is_high(top) and BoardModel.is_stairs(step)
		and not BoardModel.is_high(ground) and not BoardModel.is_stairs(ground),
		"%s / %s / %s" % [top, step, ground])

	var holder := UnitInstance.create(
		BoardModel.at_tier(_must_find("archer"), 1), BoardModel.TEAM_A)
	b.force_place(holder, top)
	var swordsman := UnitInstance.create(
		BoardModel.at_tier(_must_find("reaver"), 1), BoardModel.TEAM_B)
	b.force_place(swordsman, ground)
	var sim: CombatSim = stage.sim
	sim.setup(b, 97)
	_check("the two are standing next to each other",
		BoardModel.tile_distance(swordsman.cell, holder.cell) == 1)

	# Melee against high ground is not a penalty, it is a refusal.
	_check("a melee unit on the ground cannot reach the terrace at all",
		sim.reach_against(swordsman, holder) == 0,
		"reach %d" % sim.reach_against(swordsman, holder))
	_check("even standing directly beneath it",
		not BoardModel.in_reach(swordsman.cell, holder.cell,
			sim.reach_against(swordsman, holder)))

	# ...and on the stairs it still cannot, because the stairs are ground.
	swordsman.cell = step
	_check("and it still cannot from the stairs — those are the way up, not up",
		sim.reach_against(swordsman, holder) == 0)

	# Climb, and everything is ordinary again.
	var was := ground
	swordsman.cell = Vector2i(3, 2)
	_check("once it is up there it swings normally",
		sim.reach_against(swordsman, holder)
			== UnitData.band_tiles(swordsman.stat_int(StatModifier.Stat.ATTACK_RANGE)),
		"reach %d" % sim.reach_against(swordsman, holder))
	swordsman.cell = was

	# Ranged loses a band shooting UP.
	var shooter := UnitInstance.create(
		BoardModel.at_tier(_must_find("archer"), 1), BoardModel.TEAM_B)
	b.force_place(shooter, Vector2i(4, 5))
	var flat := UnitInstance.create(
		BoardModel.at_tier(_must_find("reaver"), 1), BoardModel.TEAM_A)
	b.force_place(flat, Vector2i(6, 5))
	var band := shooter.stat_int(StatModifier.Stat.ATTACK_RANGE)
	_check("an archer shooting along the ground has its printed range",
		sim.reach_against(shooter, flat) == UnitData.band_tiles(band),
		"reach %d" % sim.reach_against(shooter, flat))
	_check("but shooting up at the terrace it is a band short",
		sim.reach_against(shooter, holder) == UnitData.band_tiles(band - 1),
		"%d against %d" % [sim.reach_against(shooter, holder),
			UnitData.band_tiles(band - 1)])
	_check("which is strictly less far",
		sim.reach_against(shooter, holder) < sim.reach_against(shooter, flat))

	# Standing on the terrace is worth a band, which cancels the penalty when
	# both are up: a duel across two terraces is fought at flat-ground range.
	shooter.cell = Vector2i(4, 13)
	_check("shooting from the terrace is worth a band",
		sim.reach_against(shooter, flat) == UnitData.band_tiles(band + 1),
		"reach %d" % sim.reach_against(shooter, flat))
	_check("and terrace to terrace the two cancel exactly",
		sim.reach_against(shooter, holder) == UnitData.band_tiles(band),
		"reach %d" % sim.reach_against(shooter, holder))
	BoardModel.reset_map()


func _test_stairs_are_the_only_way_up() -> void:
	_section("Stairs are the only way up")
	var stage := _high_board()
	var b: BoardModel = stage.board
	var top := Vector2i(4, 1)
	var step := Vector2i(3, 3)

	# The rule itself, read straight off the board.
	_check("you cannot step onto the terrace from open ground",
		not BoardModel.can_climb(Vector2i(4, 4), Vector2i(4, 3))
			or not BoardModel.can_climb(Vector2i(0, 1), top),
		"open ground got up")
	_check("you can from a staircase", BoardModel.can_climb(step, Vector2i(3, 2)))
	_check("and from the terrace itself",
		BoardModel.can_climb(Vector2i(3, 2), Vector2i(4, 2)))
	_check("stepping DOWN off it is free from anywhere",
		BoardModel.can_climb(top, Vector2i(0, 1))
		and BoardModel.can_climb(Vector2i(3, 2), Vector2i(3, 3)))

	# And it holds in the sim: a melee unit told to reach something on the
	# terrace has to find the stairs, and it does.
	var climber := UnitInstance.create(
		BoardModel.at_tier(_must_find("reaver"), 3), BoardModel.TEAM_B)
	b.force_place(climber, Vector2i(4, 8))
	var quarry := UnitInstance.create(
		BoardModel.at_tier(_must_find("spire"), 6), BoardModel.TEAM_A)
	b.force_place(quarry, top)
	var sim: CombatSim = stage.sim
	sim.setup(b, 99)
	sim.crit_chance = 0.0
	var used_stairs := false
	var got_up := false
	for i in 400:
		sim.step()
		if BoardModel.is_stairs(climber.cell):
			used_stairs = true
		if BoardModel.is_high(climber.cell):
			got_up = true
			break
		if sim.is_finished():
			break
	_check("a melee unit finds its way onto the terrace", got_up,
		"it got as far as %s" % climber.cell)
	_check("and it went up the stairs to do it", used_stairs)
	BoardModel.reset_map()


func _test_every_plateau_has_stairs() -> void:
	_section("Every plateau on every map has a way up")
	# High ground is a second layer everywhere now, with no per-map exemption, so
	# a plateau with no staircase touching it would be a place nothing can stand,
	# nothing can reach, and no melee unit could ever attack into. The builder
	# refuses to produce one; this is the check on what actually shipped.
	var dir := DirAccess.open("res://data/maps")
	_check("the map folder opens", dir != null)
	if dir == null:
		return
	var checked := 0
	var stranded: Array[String] = []
	for file_name in dir.get_files():
		if not file_name.ends_with(".tres"):
			continue
		var m: MapData = load("res://data/maps/%s" % file_name)
		if m == null:
			continue
		checked += 1
		var seen := {}
		for y in m.height:
			for x in m.width:
				var c := Vector2i(x, y)
				if not m.is_high(c) or seen.has(c):
					continue
				var open_list: Array[Vector2i] = [c]
				seen[c] = true
				var reachable := false
				while not open_list.is_empty():
					var here: Vector2i = open_list.pop_back()
					for dy in [-1, 0, 1]:
						for dx in [-1, 0, 1]:
							var n := here + Vector2i(dx, dy)
							if n.x < 0 or n.y < 0 or n.x >= m.width or n.y >= m.height:
								continue
							if m.is_stairs(n):
								reachable = true
							elif m.is_high(n) and not seen.has(n):
								seen[n] = true
								open_list.append(n)
				if not reachable:
					stranded.append("%s at %s" % [file_name, c])
	_check("every map on disk was checked", checked >= 30, "%d maps" % checked)
	_check("and not one plateau is stranded", stranded.is_empty(),
		"; ".join(stranded))


func _timeout_board(a_units: int, b_units: int) -> CombatSim:
	# Rooted, harmless bodies on both sides so nothing can ever kill anything and
	# the round is guaranteed to reach the clock. The only thing that differs is
	# how many are standing.
	BoardModel.reset_map()
	var b := BoardModel.new()
	for i in a_units:
		b.force_place(UnitInstance.create(
			BoardModel.at_tier(_must_find("spire"), 1), BoardModel.TEAM_A),
			Vector2i(i % BoardModel.WIDTH, 0))
	for i in b_units:
		b.force_place(UnitInstance.create(
			BoardModel.at_tier(_must_find("spire"), 1), BoardModel.TEAM_B),
			Vector2i(i % BoardModel.WIDTH, BoardModel.HEIGHT - 1))
	var sim := CombatSim.new()
	sim.setup(b, 103)
	return sim


func _test_the_round_clock() -> void:
	_section("The round clock")
	_check("a round runs two minutes", is_equal_approx(CombatSim.DEFAULT_TIMEOUT, 120.0),
		"%.0fs" % CombatSim.DEFAULT_TIMEOUT)
	# Escalation is the backstop, not the rule. If it started early enough to
	# finish most fights the clock would never decide anything.
	_check("and hits only start escalating in the last thirty seconds",
		is_equal_approx(CombatSim.DEFAULT_TIMEOUT - CombatSim.SUDDEN_DEATH, 30.0),
		"escalation begins at %.0fs of %.0f" % [
			CombatSim.SUDDEN_DEATH, CombatSim.DEFAULT_TIMEOUT])

	# Decided on BODIES, not health. Both sides here are at full health, so a
	# health-based rule would call every one of these a draw.
	var ahead := _timeout_board(4, 2)
	_check("more units alive takes the round",
		ahead.run() == BoardModel.TEAM_A, "result %d" % ahead.result())
	var behind := _timeout_board(2, 5)
	_check("and it works the other way round too",
		behind.run() == BoardModel.TEAM_B, "result %d" % behind.result())
	_check("the clock really did run out",
		behind.elapsed >= CombatSim.DEFAULT_TIMEOUT - 1.0,
		"%.0fs elapsed" % behind.elapsed)
	var level := _timeout_board(3, 3)
	_check("equal numbers is a draw",
		level.run() == CombatSim.RESULT_DRAW, "result %d" % level.result())

	# The discriminating case, and it has to be built carefully: the OLD rule
	# summed each unit's health as a FRACTION of its own maximum, so a full-health
	# tier 6 counted for exactly as much as a full-health tier 1 and every board
	# above would score identically under both rules. Two healthy units against
	# three badly hurt ones is the case that separates them — 2.0 against 1.2 on
	# fractions, two bodies against three on bodies.
	var sim := _timeout_board(2, 3)
	for u in sim.board.units_of(BoardModel.TEAM_B):
		u.current_hp = u.stat(StatModifier.Stat.MAX_HP) * 0.4
	var whole := 0.0
	var hurt := 0.0
	for u in sim.board.units_of(BoardModel.TEAM_A):
		whole += u.current_hp / u.stat(StatModifier.Stat.MAX_HP)
	for u in sim.board.units_of(BoardModel.TEAM_B):
		hurt += u.current_hp / u.stat(StatModifier.Stat.MAX_HP)
	_check("the smaller side is ahead on health", whole > hurt,
		"%.1f against %.1f" % [whole, hurt])
	_check("but the bigger side wins the round anyway, because bodies decide it",
		sim.run() == BoardModel.TEAM_B, "result %d" % sim.result())


func _test_breakable_stone() -> void:
	_section("Stone that can be knocked down")
	var three: MapData = load("res://data/maps/three_roads.tres")
	_check("Three Roads still loads", three != null and three.is_valid(),
		"" if three == null else three.invalid_reason())
	if three == null:
		return
	var soft := 0
	var hard := 0
	for y in three.height:
		for x in three.width:
			var c := Vector2i(x, y)
			if not three.is_wall(c):
				continue
			if three.is_breakable(c):
				soft += 1
			else:
				hard += 1
	_check("its dividing walls are part breakable, part not",
		soft > 0 and hard > 0, "%d breakable, %d permanent" % [soft, hard])
	# The permanent stone must be the stone nearest the bases, or a Sapper digs
	# straight into someone's back line on the first cast.
	var mid := three.height / 2
	for y in three.height:
		for x in three.width:
			var c := Vector2i(x, y)
			if three.is_breakable(c):
				_check_once("the breakable stone is all in the middle of the board",
					absi(y - mid) <= 3, "breakable at %s on a %d-tall board" % [c, three.height])

	BoardModel.use_map(three)
	var wall := Vector2i(-1, -1)
	for y in three.height:
		for x in three.width:
			if three.is_breakable(Vector2i(x, y)):
				wall = Vector2i(x, y)
				break
		if wall.x >= 0:
			break
	_check("the live board agrees it is a wall", BoardModel.is_wall(wall))
	_check("and that it can be broken", BoardModel.is_breakable(wall))
	_check("it blocks movement while it stands", BoardModel.is_blocked(wall))
	_check("and it blocks a shot", BoardModel.blocks_sight(wall))
	_check("knocking it down reports success", BoardModel.break_wall(wall))
	_check("after which it is not a wall", not BoardModel.is_wall(wall))
	_check("nothing is standing in the way any more",
		not BoardModel.is_blocked(wall))
	_check("and a shot goes through", not BoardModel.blocks_sight(wall))
	_check("it cannot be broken twice", not BoardModel.break_wall(wall))

	# Permanent stone is beyond a Sapper, whatever it does.
	var solid := Vector2i(-1, -1)
	for y in three.height:
		for x in three.width:
			var c := Vector2i(x, y)
			if three.is_wall(c) and not three.is_breakable(c):
				solid = c
				break
		if solid.x >= 0:
			break
	_check("permanent stone is not breakable", not BoardModel.is_breakable(solid))
	_check("and refuses to come down", not BoardModel.break_wall(solid))

	# The round boundary puts the map back. This is the rule that keeps a map a
	# static, shareable resource rather than something a battle edits.
	BoardModel.clear_changes()
	_check("a new round restores the wall", BoardModel.is_wall(wall))
	BoardModel.reset_map()


func _test_a_mason_wall_is_a_real_wall() -> void:
	_section("Raising stone")
	BoardModel.reset_map()
	var spot := Vector2i(2, 5)
	_check("the tile starts open", not BoardModel.is_wall(spot))
	_check("raising one reports success", BoardModel.raise_wall(spot))
	_check("it is now a wall", BoardModel.is_wall(spot))
	_check("it blocks movement", BoardModel.is_blocked(spot))
	# This is the one that would silently fail: line_of_fire has an early-out on
	# an empty wall table, and on a map with no drawn walls a raised one has to
	# beat it.
	_check("and it blocks a shot on an otherwise open board",
		not BoardModel.line_of_fire(Vector2i(2, 3), Vector2i(2, 7)),
		"the shot went through")
	_check("a raised wall can be knocked back down again",
		BoardModel.is_breakable(spot) and BoardModel.break_wall(spot))
	_check("after which the board is open again", not BoardModel.is_wall(spot))
	_check("nothing can be built on a tile that is not there",
		not BoardModel.raise_wall(Vector2i(-1, -1)))
	BoardModel.clear_changes()


func _test_sapper_and_mason_in_battle() -> void:
	_section("The Sapper and the Mason at work")
	var sap := _must_find("sapper")
	var mas := _must_find("mason")
	_check("the Sapper breaks", sap.ability != null
		and sap.ability.kind == AbilityData.Kind.SAP)
	_check("the Mason builds", mas.ability != null
		and mas.ability.kind == AbilityData.Kind.BUILD)
	_check("both charge on a timer rather than by swinging",
		sap.mana_per_attack == 0.0 and sap.mana_per_charge > 0.0
			and mas.mana_per_attack == 0.0 and mas.mana_per_charge > 0.0)

	var three: MapData = load("res://data/maps/three_roads.tres")
	BoardModel.use_map(three)
	# Stand a Sapper against a breakable wall and let it cast.
	var target := Vector2i(3, 6)
	_check("there is breakable stone at %s" % target,
		BoardModel.is_breakable(target))
	var b := BoardModel.new()
	var digger := UnitInstance.create(sap, BoardModel.TEAM_A)
	b.force_place(digger, Vector2i(2, 6))
	b.force_place(UnitInstance.create(
		BoardModel.at_tier(_must_find("warden"), 1), BoardModel.TEAM_B),
		Vector2i(2, 11))
	var sim := CombatSim.new()
	sim.setup(b, 41)
	sim._resolve_ability(digger)
	_check("one cast opens a hole in the wall beside it",
		not BoardModel.is_wall(target), "the stone is still there")

	# A Mason on a clear board puts one up, and never on top of anybody.
	BoardModel.reset_map()
	var b2 := BoardModel.new()
	var builder := UnitInstance.create(mas, BoardModel.TEAM_A)
	b2.force_place(builder, Vector2i(2, 4))
	# Fill every tile it would build on, forward and level, so the only answer is
	# to waste the cast rather than to bury a unit in stone.
	for c in [Vector2i(1, 4), Vector2i(3, 4), Vector2i(1, 5), Vector2i(2, 5),
			Vector2i(3, 5)]:
		b2.force_place(UnitInstance.create(
			BoardModel.at_tier(_must_find("warden"), 1), BoardModel.TEAM_A), c)
	b2.force_place(UnitInstance.create(
		BoardModel.at_tier(_must_find("warden"), 1), BoardModel.TEAM_B),
		Vector2i(2, 9))
	var sim2 := CombatSim.new()
	sim2.setup(b2, 43)
	sim2._resolve_ability(builder)
	for c in [Vector2i(1, 4), Vector2i(3, 4), Vector2i(1, 5), Vector2i(2, 5),
			Vector2i(3, 5)]:
		_check_once("it never builds on top of a unit", not BoardModel.is_wall(c),
			"it walled in %s" % c)
	BoardModel.clear_changes()
	BoardModel.reset_map()


func _test_walls_have_health() -> void:
	_section("Stone that takes more than one blow")
	BoardModel.reset_map()
	var c := Vector2i(2, 5)
	_check("a raised wall starts at full health", BoardModel.raise_wall(c)
		and is_equal_approx(BoardModel.wall_hp(c), BoardModel.WALL_HP),
		"%.0f health" % BoardModel.wall_hp(c))
	_check("chipping it does not bring it down",
		not BoardModel.damage_wall(c, BoardModel.WALL_HP * 0.4))
	_check("it is still standing", BoardModel.is_wall(c))
	_check("and it remembers the damage",
		BoardModel.wall_hp(c) < BoardModel.WALL_HP,
		"%.0f left" % BoardModel.wall_hp(c))
	_check("the view can read how much is left",
		BoardModel.wall_fraction(c) > 0.0 and BoardModel.wall_fraction(c) < 1.0,
		"%.2f" % BoardModel.wall_fraction(c))
	_check("the blow that finishes it says so",
		BoardModel.damage_wall(c, BoardModel.WALL_HP))
	_check("after which it is gone", not BoardModel.is_wall(c))
	_check("and hitting the hole does nothing",
		not BoardModel.damage_wall(c, 999.0))

	# A Mason's wall carries the toughness it was built with, which is what the
	# buff buys — the same tile, harder.
	var d := Vector2i(3, 5)
	_check("a wall can be built tougher than standard",
		BoardModel.raise_wall(d, BoardModel.WALL_HP * 3.0)
			and BoardModel.wall_hp(d) > BoardModel.WALL_HP * 2.9,
		"%.0f health" % BoardModel.wall_hp(d))
	BoardModel.clear_changes()


func _test_units_walk_round_stone() -> void:
	_section("Going round beats going through")
	BoardModel.reset_map()
	var b := BoardModel.new()
	var walker := UnitInstance.create(_must_find("warden"), BoardModel.TEAM_A)
	b.force_place(walker, Vector2i(2, 4))
	var mark := UnitInstance.create(
		BoardModel.at_tier(_must_find("spire"), 1), BoardModel.TEAM_B)
	b.force_place(mark, Vector2i(2, 8))
	# One wall directly in the way, with the whole board open around it.
	BoardModel.raise_wall(Vector2i(2, 5))
	var sim := CombatSim.new()
	sim.setup(b, 51)
	# setup() wipes terrain damage, so the wall has to go up after it.
	BoardModel.raise_wall(Vector2i(2, 5))
	sim._decide(walker)
	_check("it steps aside rather than swinging at the stone",
		walker.state != UnitInstance.State.ATTACKING,
		"it is state %d" % walker.state)
	_check("and the wall is untouched",
		is_equal_approx(BoardModel.wall_hp(Vector2i(2, 5)), BoardModel.WALL_HP),
		"%.0f left" % BoardModel.wall_hp(Vector2i(2, 5)))
	BoardModel.clear_changes()


func _test_a_sealed_unit_digs_out() -> void:
	_section("Walled in, so it digs")
	BoardModel.reset_map()
	var b := BoardModel.new()
	var walker := UnitInstance.create(_must_find("warden"), BoardModel.TEAM_A)
	b.force_place(walker, Vector2i(2, 4))
	var mark := UnitInstance.create(
		BoardModel.at_tier(_must_find("spire"), 1), BoardModel.TEAM_B)
	b.force_place(mark, Vector2i(2, 8))
	var sim := CombatSim.new()
	sim.setup(b, 53)
	# Sealed on all four sides after setup, so nothing can be walked around.
	for c in [Vector2i(1, 4), Vector2i(3, 4), Vector2i(2, 3), Vector2i(2, 5)]:
		BoardModel.raise_wall(c)
	sim._decide(walker)
	_check("with no way round at all it starts breaking stone",
		walker.state == UnitInstance.State.ATTACKING,
		"it is state %d" % walker.state)
	var chewed := 0
	for c in [Vector2i(1, 4), Vector2i(3, 4), Vector2i(2, 3), Vector2i(2, 5)]:
		if BoardModel.wall_hp(c) < BoardModel.WALL_HP:
			chewed += 1
	_check("and exactly one of the four walls took the blow", chewed == 1,
		"%d walls were hit" % chewed)
	# It must be slow at it. A Warden should need many swings, or "break out" is
	# just "walk through" with extra steps.
	var warden := _must_find("warden")
	var swings := ceili(BoardModel.WALL_HP / maxf(warden.wall_damage(), 0.01))
	_check("a Warden needs a great many swings to get through", swings >= 20,
		"%d swings" % swings)
	BoardModel.clear_changes()


func _test_the_sapper_prefers_the_wall() -> void:
	_section("The Sapper would rather dig")
	var sap := _must_find("sapper")
	var warden := _must_find("warden")
	_check("it does far more to stone than anyone else",
		sap.wall_damage_mult > warden.wall_damage_mult * 10.0,
		"x%.2f against x%.2f" % [sap.wall_damage_mult, warden.wall_damage_mult])
	_check("and the game counts it as a wall-breaker",
		sap.breaks_walls() and not warden.breaks_walls())

	# Digging speed scales with tier, because it is a multiple of attack damage
	# rather than a flat number.
	var t1 := BoardModel.at_tier(sap, 1)
	var t6 := BoardModel.at_tier(sap, 6)
	_check("a tier 6 Sapper digs 32 times faster than a tier 1",
		absf(t6.wall_damage() / maxf(t1.wall_damage(), 0.01) - 32.0) < 0.5,
		"%.0f vs %.0f a swing" % [t6.wall_damage(), t1.wall_damage()])
	_check("even a tier 1 charge opens a map wall",
		t1.wall_damage() * 4.0 >= BoardModel.WALL_HP,
		"%.0f against %.0f" % [t1.wall_damage() * 4.0, BoardModel.WALL_HP])

	# The pathing preference is one number apart, and it must be the right way up.
	BoardModel.reset_map()
	var b := BoardModel.new()
	var digger := UnitInstance.create(sap, BoardModel.TEAM_A)
	b.force_place(digger, Vector2i(2, 4))
	var walker := UnitInstance.create(warden, BoardModel.TEAM_A)
	b.force_place(walker, Vector2i(4, 4))
	var sim := CombatSim.new()
	sim.setup(b, 55)
	_check("a Sapper treats stone as nearly free",
		sim.wall_cost_for(digger) < sim.wall_cost_for(walker) / 5,
		"%d against %d" % [sim.wall_cost_for(digger), sim.wall_cost_for(walker)])

	# Same board, same wall, opposite behaviour: the Sapper goes through it while
	# the Warden goes round.
	var b2 := BoardModel.new()
	var dig2 := UnitInstance.create(sap, BoardModel.TEAM_A)
	b2.force_place(dig2, Vector2i(2, 4))
	var mark := UnitInstance.create(
		BoardModel.at_tier(_must_find("spire"), 1), BoardModel.TEAM_B)
	b2.force_place(mark, Vector2i(2, 8))
	var sim2 := CombatSim.new()
	sim2.setup(b2, 57)
	BoardModel.raise_wall(Vector2i(2, 5))
	sim2._decide(dig2)
	_check("so on the board where a Warden walked round, the Sapper digs",
		dig2.state == UnitInstance.State.ATTACKING,
		"it is state %d" % dig2.state)
	_check("and the stone felt it",
		BoardModel.wall_hp(Vector2i(2, 5)) < BoardModel.WALL_HP,
		"%.0f left" % BoardModel.wall_hp(Vector2i(2, 5)))
	BoardModel.clear_changes()


func _three_roads_board(dry: float) -> Dictionary:
	# The real case, on the real map. Three Roads is three lanes divided by long
	# walls; a unit in the left lane whose target is in the middle lane has to
	# walk the whole length of the board and back round the end of the wall. That
	# detour is what "waiting too long to attack" actually looks like in this
	# game, and a synthetic six-wide board cannot produce one long enough to be
	# worth modelling.
	var three: MapData = load("res://data/maps/three_roads.tres")
	BoardModel.use_map(three)
	var b := BoardModel.new()
	var walker := UnitInstance.create(
		BoardModel.at_tier(_must_find("warden"), 1), BoardModel.TEAM_A)
	# Against the breakable middle of the lane wall, and deliberately not at its
	# top edge: Three Roads is only breakable across its middle five rows, so a
	# unit that starts at the edge takes one step and is beside permanent stone,
	# which tests the map's layout rather than the rule.
	b.force_place(walker, Vector2i(2, 5))
	var mark := UnitInstance.create(
		BoardModel.at_tier(_must_find("spire"), 6), BoardModel.TEAM_B)
	# The FAR lane, not the middle one. Movement is diagonal, so rounding the end
	# of a single wall is barely longer than going through it and the two routes
	# genuinely tie — that is the pathing being right, not the quirk being wrong.
	# Two lanes over is where the detour becomes the miserable one this exists for.
	b.force_place(mark, Vector2i(9, 8))
	var sim := CombatSim.new()
	sim.setup(b, 61)
	walker.dry_spell = dry
	return {sim = sim, walker = walker}


func _lane_wall_is_damaged() -> bool:
	for y in BoardModel.HEIGHT:
		for x in BoardModel.WIDTH:
			var c := Vector2i(x, y)
			if BoardModel.is_breakable(c) and BoardModel.wall_hp(c) < BoardModel.WALL_HP:
				return true
	return false


func _test_a_unit_kept_waiting_digs() -> void:
	_section("A unit kept waiting long enough stops going round")
	var warden := BoardModel.at_tier(_must_find("warden"), 1)
	BoardModel.reset_map()
	var plain := BoardModel.new()
	var fresh := UnitInstance.create(warden, BoardModel.TEAM_A)
	plain.force_place(fresh, Vector2i(2, 4))
	var sim := CombatSim.new()
	sim.setup(plain, 59)
	_check("a unit that is fighting prices stone as a last resort",
		sim.wall_cost_for(fresh) == CombatSim.WALL_COST,
		"%d" % sim.wall_cost_for(fresh))
	_check("and pricing does not change when it gets bored — this is not a pathing rule",
		sim.wall_cost_for(fresh) == CombatSim.WALL_COST)
	var patient_dig := sim.wall_damage_of(fresh)
	fresh.dry_spell = CombatSim.IMPATIENT_AFTER
	_check("and it counts as impatient once the clock runs out",
		sim.is_impatient(fresh) and not sim.is_impatient(
			UnitInstance.create(warden, BoardModel.TEAM_A)))
	# Wanting through the wall is worthless without being able to get through it.
	# An ordinary unit digs at 0.15x its attack damage, which does not open a map
	# wall inside a round — choosing to dig at that rate would be strictly worse
	# than walking.
	var fed_dig := sim.wall_damage_of(fresh)
	_check("and it hits the stone far harder than it otherwise would",
		fed_dig > patient_dig * 5.0, "%.1f against %.1f a swing" % [fed_dig, patient_dig])
	_check("hard enough to open a map wall in a handful of swings",
		fed_dig * 10.0 >= BoardModel.WALL_HP,
		"%.0f in ten swings against %.0f of stone" % [
			fed_dig * 10.0, BoardModel.WALL_HP])
	var sapper := UnitInstance.create(
		BoardModel.at_tier(_must_find("sapper"), 1), BoardModel.TEAM_A)
	_check("but a Sapper still digs several times faster",
		sim.wall_damage_of(sapper) > fed_dig * 2.0,
		"%.1f against %.1f" % [sim.wall_damage_of(sapper), fed_dig])
	sapper.dry_spell = CombatSim.IMPATIENT_AFTER
	_check("and keeping a Sapper waiting does not speed it up",
		is_equal_approx(sim.wall_damage_of(sapper),
			sapper.stat(StatModifier.Stat.ATTACK_DAMAGE) * sapper.data.wall_damage_mult))

	# Same map, same placement, twice. The only difference is how long the unit
	# has already been walking.
	var patient := _three_roads_board(0.0)
	patient.sim._decide(patient.walker)
	_check("a patient unit takes the long way round",
		patient.walker.state == UnitInstance.State.MOVING,
		"it is state %d" % patient.walker.state)
	_check("and the lane wall is untouched", not _lane_wall_is_damaged())
	BoardModel.clear_changes()

	var fed_up := _three_roads_board(CombatSim.IMPATIENT_AFTER)
	fed_up.sim._decide(fed_up.walker)
	_check("the same unit, kept waiting, digs into the lane wall instead",
		fed_up.walker.state == UnitInstance.State.ATTACKING,
		"it is state %d" % fed_up.walker.state)
	_check("and the stone felt it", _lane_wall_is_damaged())

	# Self-clearing: the moment it reaches something it goes back to being
	# patient, or one slow opening would leave it demolishing the map all round.
	var quarry := UnitInstance.create(
		BoardModel.at_tier(_must_find("spire"), 6), BoardModel.TEAM_B)
	fed_up.walker.target = quarry
	fed_up.walker.state = UnitInstance.State.IDLE
	fed_up.sim._begin_attack(fed_up.walker)
	_check("and swinging at something resets the clock",
		is_zero_approx(fed_up.walker.dry_spell),
		"%.1fs" % fed_up.walker.dry_spell)
	_check("so it is patient about walls again",
		fed_up.sim.wall_cost_for(fed_up.walker) == CombatSim.WALL_COST)
	BoardModel.clear_changes()

	# Everything above sets dry_spell past the line by hand, which tests the RULE
	# but never the clock feeding it — a ticker that never ticked would pass all
	# of it. This one starts the unit just SHORT of the threshold and then lets
	# the battle run untouched, so the sim has to count the last tick itself
	# before anything can happen.
	#
	# One tick short rather than several, and that is worth saying out loud: the
	# breakable stretch of a Three Roads lane wall is only the middle five rows,
	# and a unit that spends a few seconds walking is out of reach of any
	# breakable stone by the time it gets bored. That is the quirk's real
	# limitation — it fires for a unit stuck NEXT to breakable stone, not for one
	# already committed to the long way round.
	var live := _three_roads_board(CombatSim.IMPATIENT_AFTER - CombatSim.TICK)
	var waited := -1.0
	for i in 600:
		live.sim.step()
		if _lane_wall_is_damaged():
			waited = live.walker.dry_spell
			break
		if live.sim.is_finished():
			break
	_check("left to itself, a walled-off unit starts digging once the clock runs out",
		waited >= 0.0,
		"%.1fs of walking and the lane wall is untouched" % live.walker.dry_spell)
	_check("and not one tick before the threshold",
		waited >= CombatSim.IMPATIENT_AFTER, "%.1fs" % waited)
	_check("the sim counted the last half second itself",
		waited < CombatSim.IMPATIENT_AFTER + 2.0, "%.1fs" % waited)
	BoardModel.clear_changes()
	BoardModel.reset_map()


func _test_mason_opens_with_a_wall() -> void:
	_section("The Mason builds before anyone moves")
	var mas := _must_find("mason")
	_check("it casts at the opening bell", mas.casts_at_battle_start)
	BoardModel.reset_map()
	var b := BoardModel.new()
	var builder := UnitInstance.create(mas, BoardModel.TEAM_A)
	b.force_place(builder, Vector2i(2, 4))
	b.force_place(UnitInstance.create(
		BoardModel.at_tier(_must_find("spire"), 1), BoardModel.TEAM_B),
		Vector2i(2, 9))
	var sim := CombatSim.new()
	sim.setup(b, 59)
	var up := 0
	for y in BoardModel.HEIGHT:
		for x in BoardModel.WIDTH:
			if BoardModel.is_wall(Vector2i(x, y)):
				up += 1
	_check("a wall is standing before the first tick", up >= 1,
		"%d walls on an empty map" % up)
	BoardModel.clear_changes()


func _test_the_terrain_buffs() -> void:
	_section("Demolition and Bastion")
	var pool := _pool()
	var demo: BuffData = null
	var bast: BuffData = null
	for x in pool.buffs:
		if x.id == &"demolition":
			demo = x
		elif x.id == &"bastion":
			bast = x
	_check("the Sapper has its own buff", demo != null)
	_check("and so does the Mason", bast != null)
	if demo == null or bast == null:
		return
	_check("Demolition is attack speed at 15 / 30 / 45%",
		is_equal_approx(demo.bronze.x, 0.15) and is_equal_approx(demo.silver.x, 0.30)
			and is_equal_approx(demo.gold.x, 0.45),
		"%.2f / %.2f / %.2f" % [demo.bronze.x, demo.silver.x, demo.gold.x])
	_check("and attack at 75 / 150 / 225%",
		demo.uses_second_stat and is_equal_approx(demo.bronze.y, 0.75)
			and is_equal_approx(demo.silver.y, 1.50)
			and is_equal_approx(demo.gold.y, 2.25),
		"%.2f / %.2f / %.2f" % [demo.bronze.y, demo.silver.y, demo.gold.y])
	_check("Bastion is max health at 50 / 100 / 150%",
		is_equal_approx(bast.bronze.x, 0.50) and is_equal_approx(bast.silver.x, 1.00)
			and is_equal_approx(bast.gold.x, 1.50),
		"%.2f / %.2f / %.2f" % [bast.bronze.x, bast.silver.x, bast.gold.x])
	_check("and wall toughness at 100 / 200 / 300%",
		is_equal_approx(bast.wall_toughness_at(BuffData.Rarity.BRONZE), 1.0)
			and is_equal_approx(bast.wall_toughness_at(BuffData.Rarity.SILVER), 2.0)
			and is_equal_approx(bast.wall_toughness_at(BuffData.Rarity.GOLD), 3.0))

	# Demolition reaches the stone, because wall damage is a multiple of attack.
	BoardModel.reset_map()
	var b := BoardModel.new()
	var plain := UnitInstance.create(_must_find("sapper"), BoardModel.TEAM_A)
	b.force_place(plain, Vector2i(1, 4))
	var buffed := UnitInstance.create(_must_find("sapper"), BoardModel.TEAM_A)
	b.force_place(buffed, Vector2i(3, 4))
	var tb := TeamBuffs.new()
	tb.add(demo, BuffData.Rarity.GOLD)
	tb.apply_to(buffed)
	var sim := CombatSim.new()
	sim.setup(b, 61)
	_check("a Sapper with Demolition hits stone harder too",
		sim.wall_damage_of(buffed) > sim.wall_damage_of(plain) * 3.0,
		"%.0f against %.0f" % [sim.wall_damage_of(buffed), sim.wall_damage_of(plain)])

	# Bastion reaches the Mason's walls and nobody else's.
	var b2 := BoardModel.new()
	var mason := UnitInstance.create(_must_find("mason"), BoardModel.TEAM_A)
	b2.force_place(mason, Vector2i(2, 4))
	var sim2 := CombatSim.new()
	sim2.setup(b2, 63)
	var bare := sim2.wall_toughness_for(mason, mason.data.ability)
	var tb2 := TeamBuffs.new()
	tb2.add(bast, BuffData.Rarity.GOLD)
	sim2.team_buffs[BoardModel.TEAM_A] = tb2
	var strong := sim2.wall_toughness_for(mason, mason.data.ability)
	_check("a gold Bastion makes its walls four times as tough",
		absf(strong / maxf(bare, 0.01) - 4.0) < 0.01,
		"%.0f against %.0f" % [strong, bare])
	_check("and Bastion does not follow the Sapper around",
		tb2.wall_toughness_for(plain) == 0.0)
	BoardModel.clear_changes()


func _test_the_shell_takes_time() -> void:
	_section("The Culverin's shell is a thing in flight")
	var gun := _must_find("culverin")
	var ab: AbilityData = gun.ability
	_check("Bombardment is a shell", ab != null and ab.kind == AbilityData.Kind.SHELL)
	_check("it takes real time to arrive", ab.shell_flight >= 1.0,
		"%.2fs" % ab.shell_flight)
	_check("the tile it lands on takes 150%%",
		is_equal_approx(ab.shell_direct, 1.5))
	_check("and each arm of the cross takes 100%%",
		is_equal_approx(ab.shell_splash, 1.0))
	_check("its damage is a multiple of its attack, so it scales with tier",
		ab.shell_attack_multiple > 0.0)

	# The cross is a plus sign, not a box: the corners must be untouched or it is
	# just a splash radius with extra words.
	var arms := CombatSim.cross_cells(Vector2i(3, 5), 1)
	_check("the cross is five tiles", arms.size() == 5, "%d tiles" % arms.size())
	_check("and it does not include the corners",
		not arms.has(Vector2i(2, 4)) and not arms.has(Vector2i(4, 6)))

	BoardModel.reset_map()
	var b := BoardModel.new()
	var g := UnitInstance.create(BoardModel.at_tier(gun, 3), BoardModel.TEAM_A)
	b.force_place(g, Vector2i(0, 0))
	# A clump: one in the middle with two arms of the cross filled.
	var centre := UnitInstance.create(
		BoardModel.at_tier(_must_find("spire"), 6), BoardModel.TEAM_B)
	b.force_place(centre, Vector2i(3, 7))
	var arm_a := UnitInstance.create(
		BoardModel.at_tier(_must_find("spire"), 6), BoardModel.TEAM_B)
	b.force_place(arm_a, Vector2i(2, 7))
	var arm_b := UnitInstance.create(
		BoardModel.at_tier(_must_find("spire"), 6), BoardModel.TEAM_B)
	b.force_place(arm_b, Vector2i(3, 8))
	# And a lone one further out. The gun must prefer the clump.
	var lone := UnitInstance.create(
		BoardModel.at_tier(_must_find("spire"), 6), BoardModel.TEAM_B)
	b.force_place(lone, Vector2i(0, 6))
	var sim := CombatSim.new()
	sim.setup(b, 71)
	# Assert the AIM, not the lone unit's health. Once the Culverin sits at Sniper
	# it can auto-attack the lone one while it walks, so "the lone one is
	# untouched" stopped meaning "the shell ignored it" and the check failed for
	# the wrong reason.
	_check("it aims at the clump rather than the lone unit",
		sim._thickest_cluster(g, 1) == centre,
		"it aimed at %s" % ("nothing" if sim._thickest_cluster(g, 1) == null
			else str(sim._thickest_cluster(g, 1).cell)))
	var before := centre.current_hp
	sim._resolve_ability(g)
	_check("nothing is hurt the instant it fires", is_equal_approx(centre.current_hp, before),
		"it took %.0f already" % (before - centre.current_hp))
	# Count the ticks until it lands. Asserting merely "it did not land
	# instantly" is not enough — a one-tick flight passes that too, and the first
	# version of this test did exactly that. The flight time has to be measured.
	var ticks := 0
	for i in 60:
		sim.step()
		ticks += 1
		if centre.current_hp < before:
			break
	_check("the shell lands a moment later", centre.current_hp < before,
		"nothing was hit in 6 seconds")
	var flew := float(ticks) * CombatSim.TICK
	_check("and it was in the air for about as long as the ability says",
		absf(flew - ab.shell_flight) <= 0.25,
		"%.2fs in the air against a stated %.2fs" % [flew, ab.shell_flight])
	var mid := before - centre.current_hp
	var side := arm_a.stat(StatModifier.Stat.MAX_HP) - arm_a.current_hp
	_check("the arm of the cross was hit too", side > 0.0)
	_check("and the centre took half again what the arm did",
		absf(mid / maxf(side, 0.01) - 1.5) < 0.15,
		"%.0f against %.0f" % [mid, side])


func _test_the_ground_keeps_burning() -> void:
	_section("What the shell leaves behind")
	var gun := _must_find("culverin")
	var ab: AbilityData = gun.ability
	_check("the ground burns for several seconds", ab.field_seconds >= 3.0,
		"%.1fs" % ab.field_seconds)

	BoardModel.reset_map()
	var b := BoardModel.new()
	var g := UnitInstance.create(BoardModel.at_tier(gun, 3), BoardModel.TEAM_A)
	b.force_place(g, Vector2i(0, 0))
	var mark := UnitInstance.create(
		BoardModel.at_tier(_must_find("spire"), 6), BoardModel.TEAM_B)
	b.force_place(mark, Vector2i(3, 7))
	# A friendly standing in the blast: it must take nothing from the fire.
	var friend := UnitInstance.create(
		BoardModel.at_tier(_must_find("spire"), 6), BoardModel.TEAM_A)
	b.force_place(friend, Vector2i(2, 7))
	var sim := CombatSim.new()
	sim.setup(b, 73)
	sim._resolve_ability(g)
	for i in 40:
		sim.step()
		if sim.field_at(Vector2i(3, 7), BoardModel.TEAM_B) > 0.0:
			break
	_check("the tile is burning after the shell lands",
		sim.field_at(Vector2i(3, 7), BoardModel.TEAM_B) > 0.0)
	_check("but not for the side that fired it",
		is_zero_approx(sim.field_at(Vector2i(3, 7), BoardModel.TEAM_A)))

	var friend_hp := friend.current_hp
	var mark_hp := mark.current_hp
	for i in 25:
		sim.step()
	_check("an enemy standing in it keeps taking damage", mark.current_hp < mark_hp,
		"it lost nothing over 2.5s of fire")
	_check("and its own side walks through its own fire untouched",
		is_equal_approx(friend.current_hp, friend_hp),
		"the friendly lost %.0f" % (friend_hp - friend.current_hp))

	# It burns out rather than lasting the round.
	for i in 120:
		sim.step()
	_check("the fire goes out on its own",
		is_zero_approx(sim.field_at(Vector2i(3, 7), BoardModel.TEAM_B)))


func _test_siphon_answers_the_biggest_thing() -> void:
	_section("The Parasite against something enormous")
	var para := _must_find("parasite")
	var ab: AbilityData = para.ability
	_check("Siphon is a drain", ab != null and ab.kind == AbilityData.Kind.DRAIN)
	_check("it takes 2.5% of max health a second",
		is_equal_approx(ab.drain_percent, 0.025),
		"%.3f" % ab.drain_percent)
	_check("the Parasite has innate lifesteal", para.lifesteal > 0.0,
		"%.2f" % para.lifesteal)

	BoardModel.reset_map()
	var b := BoardModel.new()
	var p := UnitInstance.create(para, BoardModel.TEAM_A)
	b.force_place(p, Vector2i(0, 0))
	# The thing it is meant to answer. A tier 6 SPIRE, not a Transcendence: the
	# first version of this used a Transcendence and its unlimited-range beam
	# killed the Parasite two seconds in, so the drain ended and the test measured
	# nothing. The Spire is rooted, harmless and enormous, which is exactly the
	# shape being tested without the shooting back.
	var whale := UnitInstance.create(
		BoardModel.at_tier(_must_find("spire"), 6), BoardModel.TEAM_B)
	b.force_place(whale, Vector2i(5, 10))
	# And a small one much closer. Siphon must ignore it.
	var minnow := UnitInstance.create(
		BoardModel.at_tier(_must_find("spire"), 1), BoardModel.TEAM_B)
	b.force_place(minnow, Vector2i(1, 1))
	var sim := CombatSim.new()
	sim.setup(b, 75)
	var far := BoardModel.tile_distance(p.cell, whale.cell)
	_check("the whale is far outside the Parasite's reach",
		far > p.attack_reach(), "%d tiles against a reach of %d" % [far, p.attack_reach()])
	sim._resolve_ability(p)
	_check("it fastened onto the biggest thing anyway", sim.drains_on(whale) == 1,
		"%d drains on it" % sim.drains_on(whale))
	_check("and ignored the nearer small one", sim.drains_on(minnow) == 0)

	var full := whale.stat(StatModifier.Stat.MAX_HP)
	var start := whale.current_hp
	var heal_from := p.current_hp
	p.current_hp = maxf(p.current_hp - 40.0, 1.0)
	heal_from = p.current_hp
	for i in 20:
		sim.step()
	var taken := start - whale.current_hp
	_check("it loses a fixed slice of its maximum every second",
		absf(taken - full * 0.025 * 2.0) < full * 0.02,
		"%.0f gone from %.0f over 2s" % [taken, full])
	_check("and the Parasite heals off it", p.current_hp > heal_from,
		"it is still on %.0f" % p.current_hp)

	# Stacking: a second cast doubles the rate rather than refreshing it.
	sim._resolve_ability(p)
	_check("a second cast stacks rather than replacing", sim.drains_on(whale) == 2,
		"%d drains" % sim.drains_on(whale))
	var before_two := whale.current_hp
	for i in 20:
		sim.step()
	var two_rate := before_two - whale.current_hp
	_check("two drains take about twice as much",
		two_rate > taken * 1.6, "%.0f against %.0f" % [two_rate, taken])

	# MAX health, not current — and the only way to see the difference is on a
	# victim that is already badly hurt. At full health the two readings are within
	# a rounding error of each other, which is why the first version of this test
	# passed just as happily with the wrong one.
	var b2 := BoardModel.new()
	var p2 := UnitInstance.create(_must_find("parasite"), BoardModel.TEAM_A)
	b2.force_place(p2, Vector2i(0, 0))
	var hurt := UnitInstance.create(
		BoardModel.at_tier(_must_find("spire"), 6), BoardModel.TEAM_B)
	b2.force_place(hurt, Vector2i(5, 10))
	var sim2 := CombatSim.new()
	sim2.setup(b2, 81)
	var cap := hurt.stat(StatModifier.Stat.MAX_HP)
	hurt.current_hp = cap * 0.2
	sim2._resolve_ability(p2)
	var was := hurt.current_hp
	for i in 20:
		sim2.step()
	var off := was - hurt.current_hp
	_check("a victim on its last legs still loses a slice of its FULL health",
		absf(off - cap * 0.025 * 2.0) < cap * 0.015,
		"%.0f gone; 2.5%% of max would be %.0f, of current %.0f" % [
			off, cap * 0.05, was * 0.05])

	# And the number that matters for why this unit exists: what one Siphon does
	# to the biggest thing in the game. Computed rather than simulated, because a
	# tier 6 Transcendence shoots back and the point here is the arithmetic.
	var apex := BoardModel.at_tier(_must_find("transcendence"), 6)
	var bite := apex.max_hp * 0.025
	_check("one Siphon takes a real bite out of a tier 6 Transcendence",
		bite > 400.0, "%.0f a second from %.0f health" % [bite, apex.max_hp])
	var seconds := apex.max_hp / maxf(bite, 0.01)
	_check("and it would kill one on its own inside a round",
		seconds <= 40.0, "%.0f seconds" % seconds)


func _test_siphon_ignores_shields() -> void:
	_section("Nothing hides behind a shield")
	BoardModel.reset_map()
	var b := BoardModel.new()
	var p := UnitInstance.create(_must_find("parasite"), BoardModel.TEAM_A)
	b.force_place(p, Vector2i(0, 0))
	var warden := UnitInstance.create(
		BoardModel.at_tier(_must_find("warden"), 4), BoardModel.TEAM_B)
	b.force_place(warden, Vector2i(5, 9))
	var sim := CombatSim.new()
	sim.setup(b, 77)
	var pool := warden.stat(StatModifier.Stat.MAX_HP)
	# A shield worth more than its whole health. The drain must be sized off max
	# health regardless — if it counted the shield it would suddenly bite twice as
	# hard, and the Warden would be the thing it is BEST against instead of merely
	# another big body.
	warden.add_shield(pool, pool * 2.0)
	sim._resolve_ability(p)
	var before := warden.effective_hp()
	for i in 20:
		sim.step()
	var taken := before - warden.effective_hp()
	_check("the bite is sized off health, not health plus shield",
		absf(taken - pool * 0.025 * 2.0) < pool * 0.02,
		"%.0f taken against a pool of %.0f and a shield of %.0f" % [
			taken, pool, pool])


func _test_the_new_ranged_buffs() -> void:
	_section("Enfilade and Hunger")
	var pool := _pool()
	var enf: BuffData = null
	var hun: BuffData = null
	for x in pool.buffs:
		if x.id == &"enfilade":
			enf = x
		elif x.id == &"hunger":
			hun = x
	_check("the Culverin has its own buff", enf != null)
	_check("and so does the Parasite", hun != null)
	if enf == null or hun == null:
		return
	_check("Enfilade is attack speed at 20 / 40 / 60%",
		is_equal_approx(enf.bronze.x, 0.20) and is_equal_approx(enf.silver.x, 0.40)
			and is_equal_approx(enf.gold.x, 0.60),
		"%.2f / %.2f / %.2f" % [enf.bronze.x, enf.silver.x, enf.gold.x])
	_check("and attack at 75 / 150 / 225%",
		enf.uses_second_stat and is_equal_approx(enf.bronze.y, 0.75)
			and is_equal_approx(enf.gold.y, 2.25),
		"%.2f / %.2f / %.2f" % [enf.bronze.y, enf.silver.y, enf.gold.y])
	_check("Hunger is attack speed at 25 / 50 / 75%",
		is_equal_approx(hun.bronze.x, 0.25) and is_equal_approx(hun.silver.x, 0.50)
			and is_equal_approx(hun.gold.x, 0.75),
		"%.2f / %.2f / %.2f" % [hun.bronze.x, hun.silver.x, hun.gold.x])
	_check("and adds whole range bands, flat rather than by percentage",
		hun.uses_second_stat and hun.flat_b
			and is_equal_approx(hun.bronze.y, 1.0)
			and is_equal_approx(hun.gold.y, 3.0),
		"%.1f / %.1f / %.1f flat=%s" % [
			hun.bronze.y, hun.silver.y, hun.gold.y, hun.flat_b])

	# The range bonus has to actually reach further on the board.
	var plain := UnitInstance.create(_must_find("parasite"), BoardModel.TEAM_A)
	var buffed := UnitInstance.create(_must_find("parasite"), BoardModel.TEAM_A)
	var tb := TeamBuffs.new()
	tb.add(hun, BuffData.Rarity.BRONZE)
	tb.apply_to(buffed)
	_check("a bronze Hunger is worth a whole band",
		buffed.attack_reach() > plain.attack_reach(),
		"%d against %d tiles" % [buffed.attack_reach(), plain.attack_reach()])
	# Enfilade reaches the shell, because shell damage is a multiple of attack.
	var b := BoardModel.new()
	var bare := UnitInstance.create(_must_find("culverin"), BoardModel.TEAM_A)
	b.force_place(bare, Vector2i(1, 1))
	var loud := UnitInstance.create(_must_find("culverin"), BoardModel.TEAM_A)
	b.force_place(loud, Vector2i(3, 1))
	var tb2 := TeamBuffs.new()
	tb2.add(enf, BuffData.Rarity.GOLD)
	tb2.apply_to(loud)
	var sim := CombatSim.new()
	sim.setup(b, 79)
	var ab: AbilityData = bare.data.ability
	_check("a buffed Culverin throws a heavier shell",
		sim.shell_damage_of(loud, ab) > sim.shell_damage_of(bare, ab) * 3.0,
		"%.0f against %.0f" % [
			sim.shell_damage_of(loud, ab), sim.shell_damage_of(bare, ab)])


func _test_the_mason_wall_is_a_firing_slit() -> void:
	_section("Shooting through your own wall")
	BoardModel.reset_map()
	var wall := Vector2i(2, 5)
	_check("a wall raised by team A goes up",
		BoardModel.raise_wall(wall, BoardModel.WALL_HP, BoardModel.TEAM_A))
	_check("it does not block its own side's shot",
		not BoardModel.blocks_sight(wall, BoardModel.TEAM_A))
	_check("but it blocks the other side's",
		BoardModel.blocks_sight(wall, BoardModel.TEAM_B))
	_check("and it blocks anyone with no side at all",
		BoardModel.blocks_sight(wall))
	# Movement is unchanged. A firing slit, not a door — is_blocked() takes no
	# team on purpose, so neither army walks through it.
	_check("neither side can walk through it", BoardModel.is_blocked(wall))

	var from := Vector2i(2, 3)
	var to := Vector2i(2, 7)
	_check("the builder shoots straight over it",
		BoardModel.line_of_fire(from, to, BoardModel.TEAM_A))
	_check("the enemy shooting back is stopped",
		not BoardModel.line_of_fire(to, from, BoardModel.TEAM_B))
	# The one place the usual symmetry rule is deliberately broken: across a
	# membrane the two directions are SUPPOSED to disagree.
	_check("so the line is not symmetric across a membrane, on purpose",
		BoardModel.line_of_fire(from, to, BoardModel.TEAM_A)
			!= BoardModel.line_of_fire(from, to, BoardModel.TEAM_B))

	# Map stone is not a membrane. Nobody owns it and it stops everybody.
	var three: MapData = load("res://data/maps/three_roads.tres")
	BoardModel.use_map(three)
	var stone := Vector2i(-1, -1)
	for y in three.height:
		for x in three.width:
			if three.is_wall(Vector2i(x, y)):
				stone = Vector2i(x, y)
				break
		if stone.x >= 0:
			break
	_check("map stone blocks both sides regardless",
		BoardModel.blocks_sight(stone, BoardModel.TEAM_A)
			and BoardModel.blocks_sight(stone, BoardModel.TEAM_B))
	BoardModel.reset_map()

	# And in the sim: an Archer behind its own Mason's wall must have a shot.
	var b := BoardModel.new()
	var archer := UnitInstance.create(
		BoardModel.at_tier(_must_find("archer"), 1), BoardModel.TEAM_A)
	b.force_place(archer, Vector2i(2, 2))
	var mark := UnitInstance.create(
		BoardModel.at_tier(_must_find("spire"), 1), BoardModel.TEAM_B)
	b.force_place(mark, Vector2i(2, 4))
	var sim := CombatSim.new()
	sim.setup(b, 91)
	BoardModel.raise_wall(Vector2i(2, 3), BoardModel.WALL_HP, BoardModel.TEAM_A)
	_check("they are two apart with the wall between them",
		BoardModel.tile_distance(archer.cell, mark.cell) == 2
			and BoardModel.is_wall(Vector2i(2, 3)))
	_check("the Archer has a shot over its own side's wall",
		sim._has_shot(archer, mark))
	# And the same wall built by the other side stops it.
	BoardModel.clear_changes()
	BoardModel.raise_wall(Vector2i(2, 3), BoardModel.WALL_HP, BoardModel.TEAM_B)
	_check("the very same wall, built by the enemy, stops that shot",
		not sim._has_shot(archer, mark))
	BoardModel.clear_changes()


func _test_the_mason_owns_its_walls() -> void:
	_section("The Mason's walls know whose they are")
	BoardModel.reset_map()
	var b := BoardModel.new()
	var mason := UnitInstance.create(_must_find("mason"), BoardModel.TEAM_A)
	b.force_place(mason, Vector2i(2, 4))
	b.force_place(UnitInstance.create(
		BoardModel.at_tier(_must_find("spire"), 1), BoardModel.TEAM_B),
		Vector2i(2, 9))
	var sim := CombatSim.new()
	sim.setup(b, 93)
	var built: Array[Vector2i] = []
	for y in BoardModel.HEIGHT:
		for x in BoardModel.WIDTH:
			var c := Vector2i(x, y)
			if BoardModel.is_wall(c):
				built.append(c)
	_check("it built something at the opening bell", not built.is_empty())
	if built.is_empty():
		return
	for c in built:
		_check_once("and every wall it built is transparent to its own side",
			not BoardModel.blocks_sight(c, BoardModel.TEAM_A),
			"%s blocks its builder" % c)
		_check_once("while stopping the other side",
			BoardModel.blocks_sight(c, BoardModel.TEAM_B),
			"%s does not stop the enemy" % c)
	BoardModel.clear_changes()


func _test_the_mason_builds_underfoot() -> void:
	_section("The Mason builds where it stands")
	var mas := _must_find("mason")
	_check("Emplace builds under the caster",
		mas.ability != null and mas.ability.terrain_at_caster)

	BoardModel.reset_map()
	var b := BoardModel.new()
	var m := UnitInstance.create(mas, BoardModel.TEAM_A)
	var stood := Vector2i(2, 4)
	b.force_place(m, stood)
	b.force_place(UnitInstance.create(
		BoardModel.at_tier(_must_find("spire"), 1), BoardModel.TEAM_B),
		Vector2i(2, 9))
	var sim := CombatSim.new()
	sim.setup(b, 95)
	_check("the wall went up on the tile it was standing on",
		BoardModel.is_wall(stood), "nothing at %s" % stood)
	_check("and the Mason stepped off it", m.cell != stood,
		"it is still on %s" % m.cell)
	_check("it did not walk into its own stone",
		not BoardModel.is_wall(m.cell))
	_check("the wall is its own, so it can still shoot over it",
		not BoardModel.blocks_sight(stood, BoardModel.TEAM_A))

	# Boxed in with nowhere to step, it must build beside itself rather than burn
	# the whole bar. Being unable to move is not a reason to produce nothing.
	BoardModel.clear_changes()
	var b2 := BoardModel.new()
	var m2 := UnitInstance.create(mas, BoardModel.TEAM_A)
	b2.force_place(m2, Vector2i(2, 4))
	for c in [Vector2i(1, 4), Vector2i(3, 4), Vector2i(2, 3), Vector2i(2, 5)]:
		b2.force_place(UnitInstance.create(
			BoardModel.at_tier(_must_find("warden"), 1), BoardModel.TEAM_A), c)
	b2.force_place(UnitInstance.create(
		BoardModel.at_tier(_must_find("spire"), 1), BoardModel.TEAM_B),
		Vector2i(0, 9))
	var sim2 := CombatSim.new()
	sim2.setup(b2, 97)
	_check("boxed in, it did not build under itself", not BoardModel.is_wall(Vector2i(2, 4)))
	var built := 0
	for y in BoardModel.HEIGHT:
		for x in BoardModel.WIDTH:
			if BoardModel.is_wall(Vector2i(x, y)):
				built += 1
	_check("but it still got a wall up somewhere", built >= 1,
		"nothing was built at all")
	_check("and it never built on top of a unit",
		not BoardModel.is_wall(Vector2i(1, 4))
			and not BoardModel.is_wall(Vector2i(3, 4))
			and not BoardModel.is_wall(Vector2i(2, 4)))
	BoardModel.clear_changes()


func _test_builders_step_off_their_own_work() -> void:
	_section("What gets built takes the builder's tile")
	# Two units follow this rule and one deliberately does not. Asserting all
	# three here keeps the exemption visible instead of it looking like an
	# oversight in the Conjurer's data.
	var eng := _must_find("engineer")
	var mas := _must_find("mason")
	var con := _must_find("conjurer")
	_check("the Engineer builds under itself", eng.ability.summon_at_caster)
	_check("the Mason does too", mas.ability.terrain_at_caster)
	_check("and the Conjurer does neither — its wisps arrive around it",
		not con.ability.summon_at_caster and not con.ability.terrain_at_caster)

	# Engineer: the Sentry ends up exactly where the Engineer was standing.
	BoardModel.reset_map()
	var b := BoardModel.new()
	var e := UnitInstance.create(eng, BoardModel.TEAM_A)
	var stood := Vector2i(2, 4)
	b.force_place(e, stood)
	b.force_place(UnitInstance.create(
		BoardModel.at_tier(_must_find("spire"), 1), BoardModel.TEAM_B),
		Vector2i(2, 9))
	var sim := CombatSim.new()
	sim.setup(b, 101)
	for i in 200:
		sim.step()
	var turret: UnitInstance = null
	for u in b.all_units():
		if u.data.id == &"sentry":
			turret = u
	_check("a Sentry was built", turret != null)
	if turret != null:
		_check("and it stands exactly where the Engineer did",
			turret.cell == stood, "the Sentry is at %s, not %s" % [turret.cell, stood])
		_check("it is the builder that moved, not the turret",
			e.cell != stood, "the Engineer never left %s" % stood)

	# Conjurer: it must NOT be displaced by its own wisps.
	BoardModel.reset_map()
	var b2 := BoardModel.new()
	var c := UnitInstance.create(BoardModel.at_tier(con, 3), BoardModel.TEAM_A)
	var seat := Vector2i(2, 4)
	b2.force_place(c, seat)
	b2.force_place(UnitInstance.create(
		BoardModel.at_tier(_must_find("spire"), 1), BoardModel.TEAM_B),
		Vector2i(2, 9))
	var sim2 := CombatSim.new()
	sim2.setup(b2, 103)
	var wisps := 0
	for u in b2.all_units():
		if u.data.id == &"wisp":
			wisps += 1
	_check("the Conjurer opened with wisps", wisps > 0, "%d wisps" % wisps)
	_check("and it did not move to make room for them", c.cell == seat,
		"it was pushed to %s" % c.cell)


func _test_walls_do_not_outlive_the_round() -> void:
	_section("Stone is battle state")
	BoardModel.reset_map()
	# Deliberately in team B's half rather than on the neutral row — row 5 of the
	# default board is the divider nobody may deploy into, so a wall there would
	# have proved nothing about deployment.
	var spot := Vector2i(2, 7)
	BoardModel.raise_wall(spot, BoardModel.WALL_HP, BoardModel.TEAM_A)
	_check("a wall is standing", BoardModel.is_wall(spot))
	_check("and the tile is not deployable while it is",
		not BoardModel.new().can_deploy(BoardModel.TEAM_B, spot))
	# The round boundary. main.gd calls this from _restore_roster() before it
	# works out deploy cells, which is the part that matters — otherwise last
	# round's stone eats tiles you are trying to place into and the usable board
	# shrinks a little every round.
	BoardModel.clear_changes()
	_check("the next round starts from the map as drawn",
		not BoardModel.is_wall(spot))
	_check("and the tile is deployable again",
		BoardModel.new().can_deploy(BoardModel.TEAM_B, spot))

	# Broken stone comes back too, not just raised stone.
	var three: MapData = load("res://data/maps/three_roads.tres")
	BoardModel.use_map(three)
	var soft := Vector2i(-1, -1)
	for y in three.height:
		for x in three.width:
			if three.is_breakable(Vector2i(x, y)):
				soft = Vector2i(x, y)
				break
		if soft.x >= 0:
			break
	_check("there is breakable stone to knock down", soft.x >= 0)
	BoardModel.break_wall(soft)
	_check("the hole is open", not BoardModel.is_wall(soft))
	BoardModel.clear_changes()
	_check("and the next round has the wall back", BoardModel.is_wall(soft))
	_check("at full health, not the sliver it was left on",
		is_equal_approx(BoardModel.wall_hp(soft), BoardModel.WALL_HP),
		"%.0f health" % BoardModel.wall_hp(soft))
	BoardModel.reset_map()


func _pariah_stage(friend_cell: Vector2i, tier := 1) -> Dictionary:
	# One Pariah, one inert ally, one enormous inert enemy to swing at. Only the
	# ally's CELL ever changes between calls, so any difference in what the Pariah
	# does is the difference in where the ally was standing and nothing else. The
	# Spire is the right body for both jobs: rooted, harmless, and it does not
	# take a turn to do anything unless the clock is running.
	BoardModel.reset_map()
	var b := BoardModel.new()
	var p := UnitInstance.create(
		BoardModel.at_tier(_must_find("pariah"), tier), BoardModel.TEAM_A)
	b.force_place(p, Vector2i(2, 4))
	var friend := UnitInstance.create(
		BoardModel.at_tier(_must_find("spire"), 1), BoardModel.TEAM_A)
	b.force_place(friend, friend_cell)
	var whale := UnitInstance.create(
		BoardModel.at_tier(_must_find("spire"), 6), BoardModel.TEAM_B)
	b.force_place(whale, Vector2i(2, 5))
	var sim := CombatSim.new()
	sim.setup(b, 111)
	# The whole test is an exact damage figure, so the 5% doubling has to be off.
	sim.crit_chance = 0.0
	return {sim = sim, pariah = p, friend = friend, whale = whale}


func _pariah_swing(stage: Dictionary) -> float:
	var whale: UnitInstance = stage.whale
	var before := whale.current_hp
	stage.pariah.target = whale
	stage.sim._begin_attack(stage.pariah)
	return before - whale.current_hp


func _test_the_pariah_is_nothing_without_elbow_room() -> void:
	_section("The Pariah")
	var par := _must_find("pariah")
	_check("it hits for almost nothing", par.attack_damage <= 8.0,
		"%.0f a swing" % par.attack_damage)
	_check("but it is thick", par.max_hp >= 150.0, "%.0f health" % par.max_hp)
	_check("it has no ability and no bar",
		par.ability == null and par.mana_per_attack == 0.0)
	_check("and it takes a slice of max health while isolated",
		par.alone_hp_damage > 0.0, "%.3f" % par.alone_hp_damage)
	# Nobody else has this. If a second unit ever wants it, that should be a
	# deliberate change rather than a quiet one.
	var loners: Array[String] = []
	for u in _roster().units:
		if u.alone_hp_damage > 0.0:
			loners.append(String(u.id))
	_check("and it is the only unit that does", loners == ["pariah"],
		", ".join(loners))

	# Both boards have exactly one living ally. The ONLY difference is which tile
	# it stands on, which is what makes this a test of the 3x3 and not a test of
	# "is anyone else alive" — the old rule would call both of these crowded.
	var crowded := _pariah_stage(Vector2i(1, 4))
	var clear := _pariah_stage(Vector2i(0, 0))
	var pool: float = crowded.whale.stat(StatModifier.Stat.MAX_HP)

	_check("an ally in the next tile spoils it",
		not crowded.sim.is_isolated(crowded.pariah))
	_check("so it gets no share of max health",
		is_zero_approx(crowded.sim.last_stand_share(crowded.pariah)))
	var weak := _pariah_swing(crowded)
	_check("and its swing really is pitiful", weak < pool * 0.01,
		"%.0f out of %.0f" % [weak, pool])

	_check("the same ally four tiles away does not",
		clear.sim.is_isolated(clear.pariah))
	_check("and that arms it", clear.sim.last_stand_share(clear.pariah) > 0.0)
	var strong := _pariah_swing(clear)
	_check("its swing now tears out a slice of the target's maximum",
		strong > pool * par.alone_hp_damage * 0.9,
		"%.0f out of %.0f" % [strong, pool])
	_check("which is enormously more than the crowded one managed",
		strong > weak * 10.0, "%.0f against %.0f" % [strong, weak])
	_check("and the ally is alive in both cases, so this is about the tile",
		crowded.friend.is_alive() and clear.friend.is_alive())


func _test_pariah_isolation_is_fixed_at_the_bell() -> void:
	_section("The Pariah's room is measured once, at placement")
	# Diagonals count. This is the check that separates a 3x3 from a plus-shape,
	# and it is the one a player will test first by tucking an ally in the corner.
	var corner := _pariah_stage(Vector2i(1, 3))
	_check("an ally on the diagonal spoils it too",
		not corner.sim.is_isolated(corner.pariah))

	# Two tiles orthogonally is outside the square, so it is fine. Together with
	# the diagonal check above this pins the radius at exactly one.
	var two_away := _pariah_stage(Vector2i(2, 2))
	_check("but two tiles straight up is outside the square",
		two_away.sim.is_isolated(two_away.pariah))

	# The Paragon's rule, now the Pariah's: answered at the bell and then left
	# alone. Under the old live check, killing the neighbour armed it mid-battle;
	# now a placement you got wrong stays wrong for the round.
	var stage := _pariah_stage(Vector2i(1, 4))
	_check("it starts the round disarmed", not stage.sim.is_isolated(stage.pariah))
	stage.sim._damage(stage.friend, 99999.0, stage.whale)
	_check("the crowding ally is down", not stage.friend.is_alive())
	_check("and the Pariah is STILL disarmed — losing them does not free up the tile",
		not stage.sim.is_isolated(stage.pariah)
		and is_zero_approx(stage.sim.last_stand_share(stage.pariah)))
	var after := _pariah_swing(stage)
	_check("so its swing is still pitiful", after < stage.whale.stat(
		StatModifier.Stat.MAX_HP) * 0.01, "%.0f" % after)

	# Now the part that actually separates "decided once" from "asked every hit":
	# move the neighbour, and check the answer does NOT move with it. Both
	# directions, because both happen in a real fight — your line advances past a
	# Pariah you tucked in a corner, or the ally crowding it walks off to chase
	# something. Neither may change a verdict the player already paid for.
	var left := _pariah_stage(Vector2i(1, 4))
	_check("crowded at the bell", not left.sim.is_isolated(left.pariah))
	left.friend.cell = Vector2i(0, 0)
	_check("the neighbour walks off and it stays disarmed anyway",
		not left.sim.is_isolated(left.pariah))

	var joined := _pariah_stage(Vector2i(0, 0))
	_check("clear at the bell", joined.sim.is_isolated(joined.pariah))
	joined.friend.cell = Vector2i(1, 4)
	_check("an ally crowds it later and it stays armed",
		joined.sim.is_isolated(joined.pariah)
		and joined.sim.last_stand_share(joined.pariah) > 0.0)

	# The flag is battle state, so next round re-decides from the new placement
	# rather than inheriting this one.
	stage.pariah.isolated = true
	stage.pariah.reset_for_battle()
	_check("and the round boundary clears it", not stage.pariah.isolated)


func _test_the_pariah_share_climbs_with_tier() -> void:
	_section("The Pariah's share climbs with tier")
	var ladder: Array[float] = []
	for t in range(1, 7):
		ladder.append(BoardModel.at_tier(_must_find("pariah"), t).alone_hp_damage)
	var climbs := true
	for i in range(1, ladder.size()):
		if ladder[i] <= ladder[i - 1]:
			climbs = false
	_check("every tier takes a bigger slice than the one below", climbs,
		", ".join(ladder.map(func(x): return "%.1f%%" % (x * 100.0))))

	# A flat step, not the doubling every other stat gets. The share is already a
	# fraction of the victim's MAXIMUM health, so the damage it deals doubles per
	# tier on its own; doubling the fraction as well would compound back into the
	# four-swings-kills-anything version this was tuned away from.
	var steps: Array[float] = []
	for i in range(1, ladder.size()):
		steps.append(ladder[i] - ladder[i - 1])
	var even := true
	for s in steps:
		if not is_equal_approx(s, steps[0]):
			even = false
	_check("and the step between tiers is the same all the way up", even,
		", ".join(steps.map(func(x): return "%.3f" % x)))
	_check("so tier 6 is under three times tier 1, not thirty-two times",
		ladder[5] < ladder[0] * 3.0,
		"%.1f%% against %.1f%%" % [ladder[5] * 100.0, ladder[0] * 100.0])
	_check("and tier 3 is still the tuned 12%", is_equal_approx(ladder[2], 0.12),
		"%.3f" % ladder[2])

	# And it lands: the same isolated Pariah against the same body takes a bigger
	# BITE at tier 6, over and above its base damage growing.
	var low := _pariah_stage(Vector2i(0, 0))
	var pool: float = low.whale.stat(StatModifier.Stat.MAX_HP)
	var bite_low := _pariah_swing(low) / pool
	var high := _pariah_stage(Vector2i(0, 0), 6)
	var high_pool: float = high.whale.stat(StatModifier.Stat.MAX_HP)
	var bite_high := _pariah_swing(high) / high_pool
	_check("a tier 6 tears out a bigger share than a tier 1",
		bite_high > bite_low * 2.0,
		"%.1f%% against %.1f%%" % [bite_high * 100.0, bite_low * 100.0])


func _test_blight_opens_the_target_up() -> void:
	_section("Blight, and taking more from everything")
	var blight := BoardModel.at_tier(_must_find("vexer"), 1).ability
	_check("Blight carries a vulnerability", blight != null
		and blight.dot_vulnerability_per_tier > 0.0,
		"%.3f" % (0.0 if blight == null else blight.dot_vulnerability_per_tier))

	# The damage that tests the effect comes from a THIRD unit that has nothing to
	# do with the Vexer, because "from all sources" is the actual claim. If this
	# only measured the poison's own ticks it would pass for a plain damage buff.
	var clean := _blight_stage(0)
	var poisoned := _blight_stage(1)
	_check("one target is poisoned and the other is not",
		poisoned.victim.dots.size() == 1 and clean.victim.dots.is_empty())
	_check("an unpoisoned target has no vulnerability",
		is_equal_approx(clean.victim.vulnerability(), 1.0))

	var plain := _third_party_hit(clean)
	var amplified := _third_party_hit(poisoned)
	_check("a poisoned target takes more from an unrelated attacker",
		amplified > plain, "%.1f against %.1f" % [amplified, plain])
	var vex1 := BoardModel.at_tier(_must_find("vexer"), 1)
	_check("and it takes exactly the advertised share more",
		is_equal_approx(amplified, plain * (1.0 + vex1.ability.dot_vulnerability_per_tier)),
		"%.2f against %.2f expected" % [amplified,
			plain * (1.0 + vex1.ability.dot_vulnerability_per_tier)])

	# Tier is read off the CASTER at the moment of the cast, which is the whole
	# reason this exists — an AbilityData is one resource shared by all six tiers,
	# so a value that does not multiply by the caster's tier cannot scale at all.
	var big := _blight_stage(1, 6)
	var by_six := _third_party_hit(big)
	_check("a tier 6 Vexer opens the target up six times as far",
		by_six > amplified, "%.1f against %.1f" % [by_six, amplified])
	_check("and the share is the per-tier number times the caster's tier",
		is_equal_approx(big.victim.vulnerability(),
			1.0 + vex1.ability.dot_vulnerability_per_tier * 6.0),
		"%.2f" % big.victim.vulnerability())

	# Two Vexers stack, and they stack by ADDING. Multiplying would make the
	# second Vexer worth more than the first, which is not what a player reading
	# "+15% damage taken" expects to happen when they field a second one.
	var pair := _blight_stage(2, 3)
	_check("two poisons stack additively",
		is_equal_approx(pair.victim.vulnerability(),
			1.0 + vex1.ability.dot_vulnerability_per_tier * 3.0 * 2.0),
		"%.2f" % pair.victim.vulnerability())

	# And it is the POISON's lifetime, with nothing separate to expire.
	poisoned.victim.dots.clear()
	_check("when the poison ends so does the vulnerability",
		is_equal_approx(poisoned.victim.vulnerability(), 1.0))

	# Everything above builds its poison by hand, which tests the effect but not
	# the WIRING. These two go through the real cast, because the multiply-by-tier
	# lives in _resolve_dot and a test that never calls it would pass just as
	# happily with a flat value.
	for tier in [1, 6]:
		BoardModel.reset_map()
		var b := BoardModel.new()
		var vexer := UnitInstance.create(
			BoardModel.at_tier(_must_find("vexer"), tier), BoardModel.TEAM_A)
		b.force_place(vexer, Vector2i(2, 4))
		var mark := UnitInstance.create(
			BoardModel.at_tier(_must_find("spire"), 6), BoardModel.TEAM_B)
		b.force_place(mark, Vector2i(2, 6))
		var sim := CombatSim.new()
		sim.setup(b, 79)
		sim._resolve_dot(vexer, vexer.data.ability, mark)
		_check("a real tier %d cast leaves the advertised vulnerability" % tier,
			is_equal_approx(mark.vulnerability(),
				1.0 + vex1.ability.dot_vulnerability_per_tier * float(tier)),
			"%.2f, wanted %.2f" % [mark.vulnerability(),
				1.0 + vex1.ability.dot_vulnerability_per_tier * float(tier)])


func _test_blight_bites_current_health() -> void:
	_section("Blight takes a share of what is left, and front-loads it")
	var ab := BoardModel.at_tier(_must_find("vexer"), 1).ability
	_check("its damage is a share of the victim's CURRENT health",
		ab.dot_current_hp_percent > 0.0,
		"%.0f%% on the first tick" % (ab.dot_current_hp_percent * 100.0))
	_check("and there is no flat number left on it at all",
		is_zero_approx(ab.dot_damage), "%.1f flat" % ab.dot_damage)
	_check("the share decays with every tick", ab.dot_falloff < 1.0,
		"x%.2f a tick" % ab.dot_falloff)
	_check("and the opening bite is a big one", ab.dot_current_hp_percent >= 0.15,
		"%.0f%%" % (ab.dot_current_hp_percent * 100.0))

	var ticks := _poison_ticks()
	_check("it ticks the advertised number of times", ticks.size() == ab.dot_ticks,
		"%d of %d" % [ticks.size(), ab.dot_ticks])
	if ticks.size() < 2:
		return

	# The shape of the thing: cripple, then peter out. Every tick strictly smaller
	# than the last, and the first one worth more than everything after it put
	# together — which is what "cripples before petering out" has to mean if it
	# means anything measurable.
	var falls := true
	for i in range(1, ticks.size()):
		if ticks[i] >= ticks[i - 1]:
			falls = false
	_check("every tick takes less than the one before it", falls,
		", ".join(ticks.map(func(x): return "%.0f" % x)))
	var rest := 0.0
	for i in range(1, ticks.size()):
		rest += ticks[i]
	_check("and the first tick alone outweighs all the rest together",
		ticks[0] > rest, "%.0f against %.0f" % [ticks[0], rest])
	_check("the last tick is a rounding error next to the first",
		ticks[ticks.size() - 1] < ticks[0] * 0.1,
		"%.0f against %.0f" % [ticks[ticks.size() - 1], ticks[0]])

	# A share of what REMAINS can never reach zero, which is the whole identity:
	# the Vexer opens things up and cannot close them, at any tier.
	var left := _poison_survivor()
	_check("a poison on its own never kills, however long it runs", left > 0.0,
		"%.1f health left" % left)


func _poison_ticks() -> Array[float]:
	# One poison on a rooted harmless body, recording what each tick cost.
	BoardModel.reset_map()
	var b := BoardModel.new()
	var victim := UnitInstance.create(
		BoardModel.at_tier(_must_find("spire"), 6), BoardModel.TEAM_B)
	b.force_place(victim, Vector2i(2, 8))
	var vexer := UnitInstance.create(
		BoardModel.at_tier(_must_find("vexer"), 1), BoardModel.TEAM_A)
	b.force_place(vexer, Vector2i(2, 1))
	var sim := CombatSim.new()
	sim.setup(b, 87)
	# Crits off: this compares tick against tick and one 5% doubling would invert
	# the very comparison being made.
	sim.crit_chance = 0.0
	sim._resolve_dot(vexer, vexer.data.ability, victim)
	var out: Array[float] = []
	var last := victim.current_hp
	var ab := vexer.data.ability
	for i in int(ab.dot_ticks * ab.dot_interval / CombatSim.TICK) + 4:
		sim._tick_dots()
		if victim.current_hp < last:
			out.append(last - victim.current_hp)
			last = victim.current_hp
	return out


func _poison_survivor() -> float:
	# Poison re-applied over and over, forever, with nothing else touching it.
	BoardModel.reset_map()
	var b := BoardModel.new()
	var victim := UnitInstance.create(
		BoardModel.at_tier(_must_find("spire"), 6), BoardModel.TEAM_B)
	b.force_place(victim, Vector2i(2, 8))
	var vexer := UnitInstance.create(
		BoardModel.at_tier(_must_find("vexer"), 6), BoardModel.TEAM_A)
	b.force_place(vexer, Vector2i(2, 1))
	var sim := CombatSim.new()
	sim.setup(b, 89)
	sim.crit_chance = 0.0
	for i in 60:
		sim._resolve_dot(vexer, vexer.data.ability, victim)
		for j in 40:
			sim._tick_dots()
	return victim.current_hp


func _test_blight_shuts_the_target_down() -> void:
	_section("Blight shuts the target down")
	var ab := BoardModel.at_tier(_must_find("vexer"), 1).ability
	_check("Blight suppresses", ab.dot_suppresses)

	BoardModel.reset_map()
	var b := BoardModel.new()
	var mark := UnitInstance.create(
		BoardModel.at_tier(_must_find("warden"), 3), BoardModel.TEAM_B)
	b.force_place(mark, Vector2i(2, 8))
	var clean := UnitInstance.create(
		BoardModel.at_tier(_must_find("warden"), 3), BoardModel.TEAM_B)
	b.force_place(clean, Vector2i(4, 8))
	var sim := CombatSim.new()
	sim.setup(b, 85)
	var pool: float = mark.stat(StatModifier.Stat.MAX_HP)

	# Hurt both equally, then poison one of them.
	for u in [mark, clean]:
		u.shield = 0.0
		u.current_hp = pool * 0.5
	_check("nothing is suppressed to begin with",
		not mark.is_suppressed() and not clean.is_suppressed())
	mark.apply_dot(0.0, 6, 0.5, 999, 0.0, 0.0, 1.0, true)
	_check("the poisoned one is", mark.is_suppressed() and not clean.is_suppressed())

	mark.heal(100.0)
	clean.heal(100.0)
	_check("it cannot be healed while the other can",
		is_equal_approx(mark.current_hp, pool * 0.5) and clean.current_hp > pool * 0.5,
		"%.0f against %.0f" % [mark.current_hp, clean.current_hp])

	mark.add_shield(50.0, 999.0)
	clean.add_shield(50.0, 999.0)
	_check("and it cannot gain a shield while the other can",
		is_zero_approx(mark.shield) and clean.shield > 0.0,
		"%.0f against %.0f" % [mark.shield, clean.shield])

	# The shield it ALREADY had is not stripped. The poison stops it getting
	# better; it does not undo what it already is.
	mark.dots.clear()
	mark.add_shield(50.0, 999.0)
	mark.apply_dot(0.0, 6, 0.5, 999, 0.0, 0.0, 1.0, true)
	_check("a shield it already had is left alone", mark.shield > 0.0,
		"%.0f" % mark.shield)
	mark.add_shield(50.0, 999.0)
	_check("it just cannot be topped up", is_equal_approx(mark.shield, 50.0),
		"%.0f" % mark.shield)

	# Haste stacks are a gain too, and the ones already earned stay.
	var archer := UnitInstance.create(
		BoardModel.at_tier(_must_find("archer"), 3), BoardModel.TEAM_B)
	var quick := archer.data.ability
	sim._resolve_haste(archer, quick)
	var earned := archer.haste_stacks
	_check("an archer stacks haste normally", earned > 0, "%d" % earned)
	archer.apply_dot(0.0, 6, 0.5, 999, 0.0, 0.0, 1.0, true)
	sim._resolve_haste(archer, quick)
	_check("but not while poisoned", archer.haste_stacks == earned,
		"%d, was %d" % [archer.haste_stacks, earned])
	_check("and it keeps the stacks it already had", archer.haste_stacks == earned)

	# It ends with the poison, with nothing separate to expire.
	archer.dots.clear()
	_check("when the poison ends the suppression does too",
		not archer.is_suppressed())
	sim._resolve_haste(archer, quick)
	_check("and it can stack again", archer.haste_stacks > earned,
		"%d" % archer.haste_stacks)


func _freeze_stage(tier: int) -> Dictionary:
	# One Stasis, one thing to freeze. The mark is a Revenant because its revive
	# is the on-death effect the ability is built to deny, and a Spire is parked
	# in the corner so the round never ends underneath the test.
	BoardModel.reset_map()
	var b := BoardModel.new()
	var caster := UnitInstance.create(
		BoardModel.at_tier(_must_find("stasis"), tier), BoardModel.TEAM_A)
	b.force_place(caster, Vector2i(2, 3))
	var mark := UnitInstance.create(
		BoardModel.at_tier(_must_find("revenant"), 3), BoardModel.TEAM_B)
	b.force_place(mark, Vector2i(2, 8))
	var anchor := UnitInstance.create(
		BoardModel.at_tier(_must_find("spire"), 1), BoardModel.TEAM_A)
	b.force_place(anchor, Vector2i(0, 0))
	var sim := CombatSim.new()
	sim.setup(b, 91)
	# Crits off: several of these compare exact damage figures.
	sim.crit_chance = 0.0
	caster.target = mark
	return {sim = sim, caster = caster, mark = mark}


func _test_stasis_freezes() -> void:
	_section("Stasis, and a unit that does not get a turn")
	var unit := _must_find("stasis")
	var ab := unit.ability
	_check("it has a freeze ability", ab != null
		and ab.kind == AbilityData.Kind.FREEZE)
	if ab == null:
		return
	_check("it hits for very little", unit.attack_damage <= 9.0,
		"%.0f a swing" % unit.attack_damage)
	_check("and fills its bar quickly", unit.mana_per_attack >= 12.0,
		"%.0f a hit" % unit.mana_per_attack)
	_check("both halves of the freeze are written per tier",
		ab.freeze_seconds_per_tier > 0.0 and ab.freeze_amp_per_tier > 0.0,
		"%.2fs and %.0f%% a tier" % [
			ab.freeze_seconds_per_tier, ab.freeze_amp_per_tier * 100.0])

	var low := _freeze_stage(1)
	_check("nothing is frozen to begin with", not low.mark.is_frozen())
	low.sim._resolve_freeze(low.caster, ab)
	_check("a cast freezes the thing it was aiming at", low.mark.is_frozen())
	_check("for the advertised time",
		is_equal_approx(low.mark.frozen_left, ab.freeze_seconds_per_tier * 1.0),
		"%.2fs" % low.mark.frozen_left)

	# A frozen unit does not get a turn at all, which is the difference between
	# this and a slow: not "acts less often" but "does not act".
	low.mark.mana = UnitInstance.MANA_MAX
	var before_state: int = low.mark.state
	low.sim._decide(low.mark)
	_check("it cannot move", not low.mark.can_move_now())
	_check("it cannot swing", not low.mark.can_attack_now())
	_check("and a full bar does not get spent while it is frozen",
		is_equal_approx(low.mark.mana, UnitInstance.MANA_MAX)
		and low.mark.state == before_state,
		"%.0f mana, state %d" % [low.mark.mana, low.mark.state])

	# The amp, measured rather than read off the field.
	var frozen_hit := _stasis_hit(low)
	low.mark.frozen_left = 0.0
	low.mark.frozen_amp = 1.0
	var plain_hit := _stasis_hit(low)
	_check("and everything hits it harder while it stands there",
		frozen_hit > plain_hit, "%.1f against %.1f" % [frozen_hit, plain_hit])
	_check("by exactly the advertised share",
		is_equal_approx(frozen_hit, plain_hit * (1.0 + ab.freeze_amp_per_tier)),
		"%.2f, wanted %.2f" % [frozen_hit,
			plain_hit * (1.0 + ab.freeze_amp_per_tier)])

	# Tier is the whole scaling story for both halves.
	var high := _freeze_stage(6)
	high.sim._resolve_freeze(high.caster, ab)
	_check("a tier 6 freezes six times as long",
		is_equal_approx(high.mark.frozen_left, ab.freeze_seconds_per_tier * 6.0),
		"%.2fs" % high.mark.frozen_left)
	_check("and amps six times as hard",
		is_equal_approx(high.mark.frozen_amp, 1.0 + ab.freeze_amp_per_tier * 6.0),
		"x%.2f" % high.mark.frozen_amp)

	# It thaws on its own, and takes the amp with it.
	var ticks := int(high.mark.frozen_left / CombatSim.TICK) + 2
	for i in ticks:
		high.sim._tick_freezes()
	_check("it thaws when the time is up", not high.mark.is_frozen())
	_check("and stops taking extra damage the moment it does",
		is_equal_approx(high.mark.frozen_damage_taken(), 1.0))


func _stasis_hit(stage: Dictionary) -> float:
	var mark: UnitInstance = stage.mark
	mark.shield = 0.0
	mark.current_hp = mark.stat(StatModifier.Stat.MAX_HP)
	stage.sim._damage(mark, 100.0, stage.caster)
	return mark.stat(StatModifier.Stat.MAX_HP) - mark.current_hp


func _test_a_frozen_death_leaves_nothing() -> void:
	_section("Dying frozen leaves nothing behind")
	var ab := _must_find("stasis").ability

	# Killed warm: the Revenant gets its revive roll and the body joins the pile
	# a Vigil could raise from.
	var warm := _freeze_stage(3)
	warm.sim._damage(warm.mark, 999999.0, warm.caster)
	_check("killed warm, it is down", not warm.mark.is_alive())
	var warm_pending: int = warm.sim.pending_respawns(BoardModel.TEAM_B)
	_check("and it is either getting back up or lying in the pile",
		warm_pending > 0 or warm.sim._fallen.size() > 0,
		"%d reviving, %d fallen" % [warm_pending, warm.sim._fallen.size()])

	# Killed frozen: neither.
	var cold := _freeze_stage(3)
	cold.sim._resolve_freeze(cold.caster, ab)
	_check("frozen first", cold.mark.is_frozen())
	cold.sim._damage(cold.mark, 999999.0, cold.caster)
	_check("killed frozen, it is down", not cold.mark.is_alive())
	_check("nothing is getting back up",
		cold.sim.pending_respawns(BoardModel.TEAM_B) == 0,
		"%d reviving" % cold.sim.pending_respawns(BoardModel.TEAM_B))
	_check("and there is no body to raise either",
		cold.sim._fallen.is_empty(), "%d fallen" % cold.sim._fallen.size())

	# And its own side's scavengers get nothing for it. A Vigil charges off ally
	# deaths, so this is the third on-death effect the freeze denies.
	BoardModel.reset_map()
	var b := BoardModel.new()
	var caster := UnitInstance.create(
		BoardModel.at_tier(_must_find("stasis"), 3), BoardModel.TEAM_A)
	b.force_place(caster, Vector2i(2, 3))
	var mourner := UnitInstance.create(
		BoardModel.at_tier(_must_find("vigil"), 3), BoardModel.TEAM_B)
	b.force_place(mourner, Vector2i(4, 8))
	var doomed := UnitInstance.create(
		BoardModel.at_tier(_must_find("warden"), 1), BoardModel.TEAM_B)
	b.force_place(doomed, Vector2i(2, 8))
	var sim := CombatSim.new()
	sim.setup(b, 93)
	sim.crit_chance = 0.0
	mourner.mana = 0.0
	caster.target = doomed
	sim._resolve_freeze(caster, ab)
	sim._damage(doomed, 999999.0, caster)
	_check("the doomed one died frozen", not doomed.is_alive())
	_check("and its Vigil got no charge out of it",
		is_zero_approx(mourner.mana), "%.0f mana" % mourner.mana)


func _test_permafrost() -> void:
	_section("Permafrost")
	var pool := _pool()
	var buff: BuffData = null
	for x in pool.buffs:
		if x.id == &"permafrost":
			buff = x
	_check("Stasis has its own buff", buff != null)
	if buff == null:
		return
	_check("and it is the Stasis's alone",
		buff.unit_id == &"stasis" and not buff.is_global())
	_check("it scales freeze time and the amp, and nothing else",
		buff.stat_a == StatModifier.Stat.FREEZE_POWER
		and buff.stat_b == StatModifier.Stat.FREEZE_AMP)
	# Both halves climb, but not at the same rate — the amp is deliberately
	# behind at bronze and catches all the way up at gold.
	var rungs := [BuffData.Rarity.BRONZE, BuffData.Rarity.SILVER, BuffData.Rarity.GOLD]
	var climbs := true
	for i in range(1, rungs.size()):
		var lo: Vector2 = buff.magnitude(rungs[i - 1])
		var hi: Vector2 = buff.magnitude(rungs[i])
		if hi.x <= lo.x or hi.y <= lo.y:
			climbs = false
	_check("every rung is better than the one below on both halves", climbs,
		"%s / %s / %s" % [buff.magnitude(rungs[0]), buff.magnitude(rungs[1]),
			buff.magnitude(rungs[2])])

	# And it lands: a buffed Stasis freezes longer and harder than a bare one.
	var ab := _must_find("stasis").ability
	var bare := _freeze_stage(3)
	bare.sim._resolve_freeze(bare.caster, ab)
	var iced := _freeze_stage(3)
	var tb := TeamBuffs.new()
	tb.add(buff, BuffData.Rarity.GOLD)
	tb.apply_to(iced.caster)
	iced.sim._resolve_freeze(iced.caster, ab)
	_check("a gold Permafrost freezes for longer",
		iced.mark.frozen_left > bare.mark.frozen_left,
		"%.2fs against %.2fs" % [iced.mark.frozen_left, bare.mark.frozen_left])
	_check("and amps harder", iced.mark.frozen_amp > bare.mark.frozen_amp,
		"x%.2f against x%.2f" % [iced.mark.frozen_amp, bare.mark.frozen_amp])
	var want := buff.magnitude(BuffData.Rarity.GOLD)
	_check("by exactly what the buff says on the time",
		is_equal_approx(iced.mark.frozen_left,
			bare.mark.frozen_left * (1.0 + want.x)),
		"%.2fs, wanted %.2fs" % [iced.mark.frozen_left,
			bare.mark.frozen_left * (1.0 + want.x)])
	# The amp is 1 + share, so the buff scales the SHARE and not the whole
	# multiplier — doubling x1.24 has to give x1.48, not x2.48.
	_check("and on the amp, which scales the share rather than the multiplier",
		is_equal_approx(iced.mark.frozen_amp - 1.0,
			(bare.mark.frozen_amp - 1.0) * (1.0 + want.y)),
		"x%.3f, wanted x%.3f" % [iced.mark.frozen_amp,
			1.0 + (bare.mark.frozen_amp - 1.0) * (1.0 + want.y)])


func _blight_stage(poisons: int, tier := 1) -> Dictionary:
	BoardModel.reset_map()
	var b := BoardModel.new()
	# A Spire: rooted and harmless, so nothing happens to it that this test did
	# not ask for. Tier 6 so it survives everything being measured.
	var victim := UnitInstance.create(
		BoardModel.at_tier(_must_find("spire"), 6), BoardModel.TEAM_B)
	b.force_place(victim, Vector2i(2, 6))
	var hitter := UnitInstance.create(
		BoardModel.at_tier(_must_find("reaver"), 1), BoardModel.TEAM_A)
	b.force_place(hitter, Vector2i(2, 4))
	var sim := CombatSim.new()
	sim.setup(b, 77)
	sim.crit_chance = 0.0
	var vex := BoardModel.at_tier(_must_find("vexer"), tier)
	for i in poisons:
		victim.apply_dot(vex.ability.dot_damage, vex.ability.dot_ticks,
			vex.ability.dot_interval, 999,
			vex.ability.dot_vulnerability_per_tier * float(tier))
	return {sim = sim, victim = victim, hitter = hitter}


func _third_party_hit(stage: Dictionary) -> float:
	var victim: UnitInstance = stage.victim
	var before := victim.current_hp
	stage.sim._damage(victim, 100.0, stage.hitter)
	return before - victim.current_hp


func _test_spite() -> void:
	_section("Spite")
	var pool := _pool()
	var buff: BuffData = null
	for x in pool.buffs:
		if x.id == &"spite":
			buff = x
	_check("the Pariah has its own buff", buff != null)
	if buff == null:
		return
	_check("attack speed at 25 / 50 / 75%",
		is_equal_approx(buff.bronze.x, 0.25) and is_equal_approx(buff.silver.x, 0.50)
			and is_equal_approx(buff.gold.x, 0.75),
		"%.2f / %.2f / %.2f" % [buff.bronze.x, buff.silver.x, buff.gold.x])
	_check("and max health at 50 / 100 / 150%",
		buff.uses_second_stat and is_equal_approx(buff.bronze.y, 0.50)
			and is_equal_approx(buff.silver.y, 1.00)
			and is_equal_approx(buff.gold.y, 1.50),
		"%.2f / %.2f / %.2f" % [buff.bronze.y, buff.silver.y, buff.gold.y])
	_check("and it is the Pariah's alone",
		buff.unit_id == &"pariah" and not buff.is_global())
	# Attack speed is the right stat to give it: the share is per HIT, so swinging
	# faster is the only thing that makes the slice come off quicker. An attack
	# DAMAGE buff would do almost nothing, which is why it does not have one.
	var plain := UnitInstance.create(_must_find("pariah"), BoardModel.TEAM_A)
	var buffed := UnitInstance.create(_must_find("pariah"), BoardModel.TEAM_A)
	var tb := TeamBuffs.new()
	tb.add(buff, BuffData.Rarity.GOLD)
	tb.apply_to(buffed)
	_check("a gold Spite makes it swing far faster",
		buffed.attack_interval() < plain.attack_interval() * 0.6,
		"%.2fs against %.2fs" % [
			buffed.attack_interval(), plain.attack_interval()])
	_check("and much harder to finish off",
		buffed.stat(StatModifier.Stat.MAX_HP)
			> plain.stat(StatModifier.Stat.MAX_HP) * 2.4)


func _test_the_colossus_hardens_when_struck() -> void:
	_section("The Colossus")
	var col := _must_find("colossus")
	_check("it swings very rarely", col.attack_speed <= 0.30,
		"%.2f a second" % col.attack_speed)
	_check("and very hard — harder than anything else on the roster",
		col.attack_damage >= 90.0, "%.0f a swing" % col.attack_damage)
	var slowest := true
	for u in _roster().units:
		if u.id != &"colossus" and u.move_time > col.move_time:
			slowest = false
	_check("nothing walks slower", slowest, "%.2fs a tile" % col.move_time)
	_check("it plates up when struck", col.shield_on_hit > 0.0,
		"%.3f of max health a hit" % col.shield_on_hit)
	var platers: Array[String] = []
	for u in _roster().units:
		if u.shield_on_hit > 0.0:
			platers.append(String(u.id))
	_check("and it is the only unit that does", platers == ["colossus"],
		", ".join(platers))

	BoardModel.reset_map()
	var b := BoardModel.new()
	var c := UnitInstance.create(BoardModel.at_tier(col, 3), BoardModel.TEAM_A)
	b.force_place(c, Vector2i(2, 4))
	var jab := UnitInstance.create(
		BoardModel.at_tier(_must_find("spire"), 1), BoardModel.TEAM_B)
	b.force_place(jab, Vector2i(2, 5))
	var sim := CombatSim.new()
	sim.setup(b, 121)
	var pool := c.stat(StatModifier.Stat.MAX_HP)
	_check("it starts with no shield", is_zero_approx(c.shield))

	# The first hit is NOT free: it lands, and THEN the plating goes up.
	var hp_before := c.current_hp
	sim._damage(c, 10.0, jab)
	_check("the first blow still hurts it", c.current_hp < hp_before,
		"it took nothing")
	_check("and afterwards it is plated",
		absf(c.shield - pool * col.shield_on_hit) < 1.0,
		"%.0f shield off a pool of %.0f" % [c.shield, pool])

	# Per HIT, not per damage. Ten pinpricks arm it ten times over; one huge blow
	# arms it once. That asymmetry is the entire unit.
	c.shield = 0.0
	c.current_hp = pool
	for i in 10:
		sim._damage(c, 1.0, jab)
	var many := c.shield
	c.shield = 0.0
	c.current_hp = pool
	sim._damage(c, 10.0, jab)
	var once := c.shield
	_check("ten small hits plate it far more than one hit for the same total",
		many > once * 5.0, "%.0f against %.0f" % [many, once])

	# And it cannot armour up forever.
	c.shield = 0.0
	c.current_hp = pool
	for i in 200:
		sim._damage(c, 0.5, jab)
		if not c.is_alive():
			break
	_check("the shield is capped rather than growing without limit",
		c.shield <= pool * col.shield_cap + 1.0,
		"%.0f shield against a cap of %.0f" % [c.shield, pool * col.shield_cap])


func _test_rapid_weak_fire_cannot_break_it() -> void:
	_section("What it is actually for")
	# The stated job: eat rapid feeble attacks. The Vexer is the fastest, weakest
	# attacker in the game, which makes it the honest test.
	BoardModel.reset_map()
	var b := BoardModel.new()
	var c := UnitInstance.create(
		BoardModel.at_tier(_must_find("colossus"), 3), BoardModel.TEAM_A)
	b.force_place(c, Vector2i(2, 4))
	var vex := UnitInstance.create(
		BoardModel.at_tier(_must_find("vexer"), 3), BoardModel.TEAM_B)
	b.force_place(vex, Vector2i(2, 6))
	var sim := CombatSim.new()
	sim.setup(b, 123)
	for i in 200:
		sim.step()
		if not c.is_alive() or not vex.is_alive():
			break
	_check("twenty seconds of the fastest weakest attacker leaves it standing",
		c.is_alive(), "the Colossus died")

	# The counter-case, which matters just as much: one enormous blow arms it
	# once and takes a huge bite regardless. It is not a general-purpose tank.
	BoardModel.reset_map()
	var b2 := BoardModel.new()
	var c2 := UnitInstance.create(
		BoardModel.at_tier(_must_find("colossus"), 3), BoardModel.TEAM_A)
	b2.force_place(c2, Vector2i(2, 4))
	var gun := UnitInstance.create(
		BoardModel.at_tier(_must_find("culverin"), 3), BoardModel.TEAM_B)
	b2.force_place(gun, Vector2i(2, 6))
	var sim2 := CombatSim.new()
	sim2.setup(b2, 125)
	var pool := c2.stat(StatModifier.Stat.MAX_HP)
	sim2._damage(c2, pool * 0.5, gun)
	_check("one huge hit takes a huge bite whatever the plating",
		c2.effective_hp() < pool * 0.65,
		"%.0f effective left out of %.0f" % [c2.effective_hp(), pool])


func _test_tempering() -> void:
	_section("Tempering")
	var pool := _pool()
	var buff: BuffData = null
	for x in pool.buffs:
		if x.id == &"tempering":
			buff = x
	_check("the Colossus has its own buff", buff != null)
	if buff == null:
		return
	_check("max health at 75 / 150 / 225%",
		is_equal_approx(buff.bronze.x, 0.75) and is_equal_approx(buff.silver.x, 1.50)
			and is_equal_approx(buff.gold.x, 2.25),
		"%.2f / %.2f / %.2f" % [buff.bronze.x, buff.silver.x, buff.gold.x])
	_check("and 2.5 / 5 / 7.5% more of max health into the shield per hit",
		is_equal_approx(buff.shield_on_hit_at(BuffData.Rarity.BRONZE), 0.025)
			and is_equal_approx(buff.shield_on_hit_at(BuffData.Rarity.SILVER), 0.05)
			and is_equal_approx(buff.shield_on_hit_at(BuffData.Rarity.GOLD), 0.075))

	# Both halves compound: more max health makes each plate bigger AND the share
	# itself goes up, so the buff is worth much more than the sum reads.
	BoardModel.reset_map()
	var b := BoardModel.new()
	# On the OTHER team on purpose. Both on team A would both pick the buff up —
	# it covers the unit type, not the individual — and the comparison would be a
	# unit against itself, which is exactly how the first version of this passed
	# nothing while looking fine.
	var plain := UnitInstance.create(_must_find("colossus"), BoardModel.TEAM_B)
	b.force_place(plain, Vector2i(1, 8))
	var hard := UnitInstance.create(_must_find("colossus"), BoardModel.TEAM_A)
	b.force_place(hard, Vector2i(3, 4))
	var tb := TeamBuffs.new()
	tb.add(buff, BuffData.Rarity.GOLD)
	tb.apply_to(hard)
	var sim := CombatSim.new()
	sim.setup(b, 127)
	sim.team_buffs[BoardModel.TEAM_A] = tb
	_check("a gold Tempering more than triples its share per hit",
		sim.shield_gain_for(hard) > sim.shield_gain_for(plain) * 3.0,
		"%.3f against %.3f" % [
			sim.shield_gain_for(hard), sim.shield_gain_for(plain)])
	_check("and it does not follow anyone else around",
		tb.shield_on_hit_for(UnitInstance.create(
			_must_find("warden"), BoardModel.TEAM_A)) == 0.0)


func _test_critical_hits() -> void:
	_section("Criticals")
	_check("the rate is 5%", is_equal_approx(CombatSim.CRIT_CHANCE, 0.05),
		"%.3f" % CombatSim.CRIT_CHANCE)
	_check("and a crit is double", is_equal_approx(CombatSim.CRIT_MULT, 2.0))

	BoardModel.reset_map()
	var b := BoardModel.new()
	var hitter := UnitInstance.create(
		BoardModel.at_tier(_must_find("warden"), 1), BoardModel.TEAM_A)
	b.force_place(hitter, Vector2i(2, 4))
	var sack := UnitInstance.create(
		BoardModel.at_tier(_must_find("spire"), 6), BoardModel.TEAM_B)
	b.force_place(sack, Vector2i(2, 5))
	var sim := CombatSim.new()
	sim.setup(b, 131)
	_check("the live rate starts at the constant",
		is_equal_approx(sim.crit_chance, CombatSim.CRIT_CHANCE))

	# Rate: over a couple of thousand hits, 5% should show up as roughly 5%. Wide
	# bounds on purpose — this is asserting the dice are the right dice, not that
	# a particular seed came up a particular way.
	var crits := 0
	var swings := 2000
	for i in swings:
		sack.current_hp = sack.stat(StatModifier.Stat.MAX_HP)
		var before := sim.events.size()
		sim._damage(sack, 1.0, hitter)
		for j in range(before, sim.events.size()):
			var e: Dictionary = sim.events[j]
			if e.kind == "damage" and bool(e.get("crit", false)):
				crits += 1
	var rate := float(crits) / float(swings)
	_check("about one hit in twenty crits", rate > 0.03 and rate < 0.075,
		"%d of %d, or %.1f%%" % [crits, swings, rate * 100.0])

	# Every damage event carries the flag, so the view can always tell.
	var flagged := 0
	for e in sim.events:
		if e.kind == "damage" and e.has("crit"):
			flagged += 1
	_check("every damage event says whether it crit", flagged == swings,
		"%d of %d carried the flag" % [flagged, swings])


func _test_a_crit_actually_doubles() -> void:
	_section("A crit is worth exactly double")
	BoardModel.reset_map()
	var b := BoardModel.new()
	var hitter := UnitInstance.create(
		BoardModel.at_tier(_must_find("warden"), 1), BoardModel.TEAM_A)
	b.force_place(hitter, Vector2i(2, 4))
	var sack := UnitInstance.create(
		BoardModel.at_tier(_must_find("spire"), 6), BoardModel.TEAM_B)
	b.force_place(sack, Vector2i(2, 5))
	var sim := CombatSim.new()
	sim.setup(b, 133)

	var plain := 0.0
	var doubled := 0.0
	for i in 400:
		var before := sim.events.size()
		sim._damage(sack, 10.0, hitter)
		sack.current_hp = sack.stat(StatModifier.Stat.MAX_HP)
		for j in range(before, sim.events.size()):
			var e: Dictionary = sim.events[j]
			if e.kind != "damage":
				continue
			if bool(e.get("crit", false)):
				doubled = float(e.amount)
			else:
				plain = float(e.amount)
	_check("both a plain hit and a crit happened in 400 swings",
		plain > 0.0 and doubled > 0.0,
		"plain %.1f, crit %.1f" % [plain, doubled])
	if plain > 0.0 and doubled > 0.0:
		_check("and the crit is exactly twice the plain hit",
			absf(doubled - plain * 2.0) < 0.01,
			"%.2f against %.2f" % [doubled, plain])

	# Turning the dial off has to actually silence it, since two damage tests
	# depend on that to measure exact figures.
	sim.crit_chance = 0.0
	var any := false
	for i in 500:
		var before := sim.events.size()
		sim._damage(sack, 10.0, hitter)
		sack.current_hp = sack.stat(StatModifier.Stat.MAX_HP)
		for j in range(before, sim.events.size()):
			if sim.events[j].kind == "damage" and bool(sim.events[j].get("crit", false)):
				any = true
	_check("at zero it never crits", not any)


func _test_every_kind_of_damage_can_crit() -> void:
	_section("All damage can be critical")
	# The claim is that the roll lives in _damage rather than in _begin_attack, so
	# a poison tick and a burning tile can crit as readily as a swing. Anything
	# that routes damage a different way would quietly not.
	BoardModel.reset_map()
	var b := BoardModel.new()
	var vexer := UnitInstance.create(
		BoardModel.at_tier(_must_find("vexer"), 1), BoardModel.TEAM_A)
	b.force_place(vexer, Vector2i(2, 4))
	var sack := UnitInstance.create(
		BoardModel.at_tier(_must_find("spire"), 6), BoardModel.TEAM_B)
	b.force_place(sack, Vector2i(2, 5))
	var sim := CombatSim.new()
	sim.setup(b, 137)
	# Crits certain, so one tick of poison is enough to prove the path.
	sim.crit_chance = 1.0
	sack.apply_dot(10.0, 4, 0.5, vexer.uid)
	var seen := false
	var before := sim.events.size()
	for i in 12:
		sim.step()
	for j in range(before, sim.events.size()):
		var e: Dictionary = sim.events[j]
		if e.kind == "damage" and bool(e.get("crit", false)):
			seen = true
	_check("a damage-over-time tick can crit", seen)


func _test_portraits_are_wired() -> void:
	_section("Portraits")
	var missing: PackedStringArray = []
	var tiers_missing := 0
	for u in _roster().units:
		var cur: UnitData = u
		while cur != null:
			if cur.sprite == null:
				tiers_missing += 1
				if not missing.has(String(cur.id)):
					missing.append(String(cur.id))
			cur = cur.next_tier
	_check("every unit has a portrait at every tier",
		tiers_missing == 0,
		"%d tiers missing across %s" % [tiers_missing, ", ".join(missing)])
	# The Warden has its own art; everything else falls back to the placeholder.
	# That fallback is the whole point of the pipeline — adding art for a unit is
	# dropping a PNG at assets/portraits/<id>.png with no code change at all.
	var warden := _must_find("warden")
	_check("the Warden has a portrait", warden.sprite != null)
	_check("and it is square", warden.sprite == null
		or is_equal_approx(warden.sprite.get_size().x, warden.sprite.get_size().y),
		"" if warden.sprite == null else str(warden.sprite.get_size()))


func _test_audio_files_are_present() -> void:
	_section("Audio")
	_check("the menu theme exists",
		ResourceLoader.exists("res://assets/music/menu_theme.ogg"))
	# The battle playlist is found by counting upward from battle_1.ogg, so the
	# thing worth asserting is that the count is not zero and that it stops where
	# the files stop — an off-by-one here is a menu button for a track that does
	# not exist, and silence when it is rolled.
	var tracks := 0
	while ResourceLoader.exists("res://assets/music/battle_%d.ogg" % (tracks + 1)):
		tracks += 1
	_check("there is at least one battle track", tracks > 0, "%d found" % tracks)
	_check("and every track the menu will offer is on disk", tracks >= 2,
		"only %d — the playlist needs more than one to be a playlist" % tracks)
	# Tracks are numbered, not named — the menu suite checks the labels, since
	# Audio is an autoload and autoloads do not exist in --script mode.
	_check("the old single battle_theme.ogg is gone",
		not ResourceLoader.exists("res://assets/music/battle_theme.ogg"))
	# Music that has not been told to loop simply stops: Godot's importer defaults
	# to loop=false and every track has to override it.
	for i in range(1, tracks + 1):
		var text := FileAccess.get_file_as_string(
			"res://assets/music/battle_%d.ogg.import" % i)
		_check_once("every battle track is set to loop", text.contains("loop=true"),
			"battle_%d.ogg is not looping" % i)
	for i in range(1, 7):
		_check_once("six melee sounds are on disk",
			ResourceLoader.exists("res://assets/sfx/melee_%d.wav" % i),
			"melee_%d.wav is missing" % i)
	for i in range(1, 3):
		_check_once("two ranged sounds are on disk",
			ResourceLoader.exists("res://assets/sfx/ranged_%d.wav" % i),
			"ranged_%d.wav is missing" % i)
	_check("the laser sound is on disk",
		ResourceLoader.exists("res://assets/sfx/laser.wav"))
	# The laser belongs to Transcendence alone, so the flag that selects it had
	# better be set on exactly one unit. If a second one ever gets it, this fails
	# and the decision gets made on purpose instead of by accident.
	var beamers: Array[String] = []
	for u in _roster().units:
		if u.tier == 1 and u.beam_attack:
			beamers.append(String(u.id))
	_check("and exactly one unit fires a beam", beamers == ["transcendence"],
		", ".join(beamers))
	for name in ["critical", "death", "merge", "promotion", "windfall", "confirm",
			"round_start", "select", "pickup"]:
		_check("the %s sound is on disk" % name,
			ResourceLoader.exists("res://assets/sfx/%s.wav" % name))
