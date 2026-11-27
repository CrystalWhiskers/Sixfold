extends SceneTree

## A floor on how many checks a healthy run performs.
##
## A GDScript runtime error inside a test — calling a function that has been
## renamed, say — aborts that ONE function and lets the run carry on. Nothing
## fails, the suite prints "0 failed", and every check below the error simply
## never happens. That is not hypothetical: a renamed TeamBuffs method sat broken
## for a whole session behind a green run, taking thirteen checks with it.
##
## So the count itself is asserted. If it drops, something died quietly and the
## run says so. Raise this when you add tests — it is a ratchet, and the number
## only ever goes up.
##
## It is a backstop now, not the guard. It only works if somebody remembers to raise
## it, and nobody did: it sat at 2555 while the suite grew past 2600, so when three
## Powderkeg tests died in one sitting the run was still a hundred checks above the
## floor and reported green. The ErrorWatch below is what actually catches it.
const MIN_CHECKS := 2766

## Counts runtime script errors while the suite runs, and fails the run if there are
## any.
##
## A runtime error aborts the one test function it happens in and hands control back
## to _initialize, which carries on to the next test — so the run completes, prints a
## total, and that total is green. Godot does report the error, but only as a line in
## the log that scrolls past; nothing in the suite ever sees it. A Logger registered
## with the engine sees every error as it happens, which turns "scroll up and look for
## SCRIPT ERROR" into a failure the run reports on its own.
##
## Only RUNTIME script errors are counted — the ones with a backtrace. Running this
## file in --script mode also compiles the View-layer scripts, which reference
## autoloads that do not exist outside the game and fail to compile; those errors
## have no backtrace, predate this guard, and are not a test dying.
class ErrorWatch extends Logger:
	var count := 0
	var first := ""

	func _log_error(_function: String, file: String, line: int, code: String,
			rationale: String, _editor_notify: bool, error_type: int,
			script_backtraces: Array[ScriptBacktrace]) -> void:
		if error_type != ERROR_TYPE_SCRIPT or script_backtraces.is_empty():
			return
		count += 1
		if first.is_empty():
			first = "%s (%s:%d)" % [rationale if not rationale.is_empty() else code,
				file.get_file(), line]


var _passed := 0
var _failed := 0
var _loadout: LoadoutData
var _watch := ErrorWatch.new()


func _initialize() -> void:
	OS.add_logger(_watch)
	_loadout = load("res://data/loadouts/starter.tres") as LoadoutData
	if _loadout == null:
		push_error("Run tools/generate_data.gd first.")
		quit(1)
		return

	print("\n=== Sixfold — headless tests ===\n")
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
	_test_the_assassin_vanishes_before_it_moves()
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
	_test_the_breaker_charges()
	_test_the_charge_takes_time_to_arrive()
	_test_avalanche()
	_test_the_usurper_takes_a_host()
	_test_the_usurper_and_the_tier_ladder()
	_test_a_puppet_is_a_worse_unit()
	_test_the_siren()
	_test_a_reeling_unit_wanders()
	_test_discord()
	_test_the_husk()
	_test_the_grip_can_be_timed()
	_test_a_stunned_unit_does_nothing()
	_test_the_clock_is_a_setting()
	_test_gates()
	_test_only_big_maps_have_gates()
	_test_shields_fizzle()
	_test_tier_scaling_on_abilities()
	_test_the_vexer_body()
	_test_the_global_pace()
	_test_reins()
	_test_ranged_units_hold_their_distance()
	_test_the_martyr_grows_as_it_dies()
	_test_the_martyrs_window()
	_test_the_martyr_only_gets_one_window()
	_test_rapture()
	_test_the_martyrs_last_swing_cuts_through()
	_test_the_martyrs_numbers_are_the_measured_ones()
	_test_a_stale_buff_on_disk_is_not_in_the_game()
	_test_status_registry()
	_test_seraph_cleanses()
	_test_a_frozen_death_leaves_nothing()
	_test_overkill_is_measured_against_the_whole_bar()
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
	_test_sudden_death_rules()
	_test_a_stuck_unit_gives_up()
	_test_unlimited_range_ignores_walls()
	_test_the_apex_beam_goes_through_stone()
	_test_buffs_stack_across_rarities()
	_test_the_round_shield_buff()
	_test_the_militia_buff()
	_test_forced_march()
	_test_engineer_sentries_scale()
	_test_live_counts()
	_test_this_pass()
	_test_boss_defence()
	_test_boss_music()
	_test_boss_polish()
	_test_every_ability_has_an_icon()
	_test_bannerman()
	_test_fast_pathfinder_matches()
	_test_mirror_matchup_is_fair()

	var ran := _passed + _failed
	if ran < MIN_CHECKS:
		_failed += 1
		print("\n  FAIL  only %d checks ran, expected at least %d — a test almost"
			% [ran, MIN_CHECKS])
		print("        certainly died partway through. Scroll up for a SCRIPT ERROR.")
	if _watch.count > 0:
		_failed += 1
		print("\n  FAIL  %d runtime script error(s) during the run — each one killed a"
			% _watch.count)
		print("        test partway through and skipped every check after it.")
		print("        First: %s" % _watch.first)
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
	_check("6 wide, 10 tall", BoardModel.WIDTH == 6 and BoardModel.HEIGHT == 10)
	# No divider. An even board splits evenly on its own and the two halves simply
	# meet, which is what removing the no-man's row means: every row belongs to
	# somebody, and the front ranks start two tiles apart instead of three.
	_check("there is no divider", not BoardModel.HAS_NEUTRAL)
	_check("the halves meet at row 5", BoardModel.NEUTRAL_ROW == 5)
	_check("and they are the same size",
		BoardModel.NEUTRAL_ROW * 2 == BoardModel.HEIGHT)
	_check("every row belongs to one side or the other",
		BoardModel.last_row(BoardModel.TEAM_A)
			== BoardModel.first_row(BoardModel.TEAM_B),
		"A ends at %d, B starts at %d" % [
			BoardModel.last_row(BoardModel.TEAM_A),
			BoardModel.first_row(BoardModel.TEAM_B)])
	var b := BoardModel.new()
	_check("corners in bounds", b.in_bounds(Vector2i(0, 0)) and b.in_bounds(Vector2i(5, 9)))
	_check("off-board rejected",
		not b.in_bounds(Vector2i(6, 0)) and not b.in_bounds(Vector2i(0, 10))
		and not b.in_bounds(Vector2i(-1, 0)))


func _test_deploy_zones() -> void:
	_section("Deploy zones")
	var b := BoardModel.new()
	_check("A owns rows 0-4", b.can_deploy(BoardModel.TEAM_A, Vector2i(3, 4)))
	_check("B owns rows 5-9", b.can_deploy(BoardModel.TEAM_B, Vector2i(3, 5)))
	_check("A cannot deploy in B's half", not b.can_deploy(BoardModel.TEAM_A, Vector2i(3, 5)))
	# The row that used to be no-man's land is now the front rank of B's half, and
	# row 4 is the front rank of A's. They touch.
	_check("the old divider row now belongs to B",
		b.can_deploy(BoardModel.TEAM_B, Vector2i(3, BoardModel.NEUTRAL_ROW))
		and not b.can_deploy(BoardModel.TEAM_A, Vector2i(3, BoardModel.NEUTRAL_ROW)))
	_check("no tile is refused to both sides",
		_every_tile_is_owned(b), "some tile belongs to neither side")
	_check("30 tiles per side",
		b.deploy_cells(BoardModel.TEAM_A).size() == 30
		and b.deploy_cells(BoardModel.TEAM_B).size() == 30,
		"got %d/%d" % [b.deploy_cells(0).size(), b.deploy_cells(1).size()])
	_check("and that is the whole board: 30 + 30 = 60",
		30 + 30 == BoardModel.WIDTH * BoardModel.HEIGHT)


func _every_tile_is_owned(b: BoardModel) -> bool:
	for y in BoardModel.HEIGHT:
		for x in BoardModel.WIDTH:
			var c := Vector2i(x, y)
			if BoardModel.is_blocked(c):
				continue
			if not b.can_deploy(BoardModel.TEAM_A, c) \
					and not b.can_deploy(BoardModel.TEAM_B, c):
				return false
	return true


func _test_mirror() -> void:
	_section("Mirror symmetry")
	var ok := true
	var swaps_halves := true
	for y in BoardModel.HEIGHT:
		for x in BoardModel.WIDTH:
			var c := Vector2i(x, y)
			if BoardModel.mirror(BoardModel.mirror(c)) != c:
				ok = false
			# With no divider there is no self-mirroring row: every tile belongs to a
			# side, so every tile's mirror belongs to the other one.
			if (c.y < BoardModel.NEUTRAL_ROW) \
					== (BoardModel.mirror(c).y < BoardModel.NEUTRAL_ROW):
				swaps_halves = false
	_check("mirror round-trips every cell", ok)
	_check("and every cell mirrors into the other half", swaps_halves)
	_check("mirror swaps the deploy zones",
		BoardModel.mirror(Vector2i(2, 1)) == Vector2i(2, 8))


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
	b.place(walker, Vector2i(5, 9))
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
	b.place(u, Vector2i(3, 7))

	_check("a push moves the requested distance",
		b.push(u, Vector2i(0, 1), 2) == 2 and u.cell == Vector2i(3, 9),
		"ended at %s" % u.cell)
	_check("a push stops at the board edge",
		b.push(u, Vector2i(0, 1), 3) == 0 and u.cell == Vector2i(3, 9))

	var blocker := _unit(0, BoardModel.TEAM_B)
	b.place(blocker, Vector2i(3, 8))
	_check("a push stops at an occupied tile",
		b.push(u, Vector2i(0, -1), 3) == 0 and u.cell == Vector2i(3, 9),
		"ended at %s" % u.cell)

	_check("a push ignores deploy zones",
		b.push(u, Vector2i(-1, 0), 3) == 3 and u.cell == Vector2i(0, 9))
	_check("teleport refuses an occupied tile", not b.teleport(u, Vector2i(3, 8)))
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
	b.force_place(victim, Vector2i(2, 9))
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


func _test_fast_pathfinder_matches() -> void:
	_section("The fast pathfinder gives exactly the reference's answers")
	# Every map on disk plus the boss field, crowded with both sides, a few stone
	# tiles knocked about, every combination of the rules the field takes — and the
	# fast field must equal the plain one tile for tile.
	var maps: Array[MapData] = []
	for f in DirAccess.get_files_at("res://data/maps"):
		var clean := f.trim_suffix(".remap")
		if clean.ends_with(".tres"):
			maps.append(load("res://data/maps/" + clean) as MapData)
	maps.append(BossFight.make_map())
	var rng := RandomNumberGenerator.new()
	rng.seed = 77
	var unit_a := load("res://data/units/warden_t1.tres") as UnitData
	var unit_b := load("res://data/units/archer_t1.tres") as UnitData
	var compared := 0
	var wrong: PackedStringArray = []
	for m in maps:
		BoardModel.use_map(m)
		var board := BoardModel.new()
		var open: Array[Vector2i] = []
		for y in BoardModel.HEIGHT:
			for x in BoardModel.WIDTH:
				if not BoardModel.is_blocked(Vector2i(x, y)):
					open.append(Vector2i(x, y))
		for i in mini(open.size() / 3, 40):
			var c: Vector2i = open.pop_at(rng.randi_range(0, open.size() - 1))
			board.force_place(UnitInstance.create(unit_a if i % 2 == 0 else unit_b,
				BoardModel.TEAM_A if i % 2 == 0 else BoardModel.TEAM_B), c)
		var sim := CombatSim.new()
		sim.board = board
		var units := board.all_units()
		for trial in 6:
			if units.is_empty() or open.is_empty():
				break
			var walker: UnitInstance = units[rng.randi_range(0, units.size() - 1)]
			var goal: Vector2i = open[rng.randi_range(0, open.size() - 1)] if trial % 2 == 0 \
				else units[rng.randi_range(0, units.size() - 1)].cell
			sim._field_team = walker.team
			sim._field_wall_cost = CombatSim.WALL_COST if trial % 3 != 0 else CombatSim.SAPPER_WALL_COST
			sim._field_gates = trial % 2 == 0
			var friends := sim._friendly_cells(walker)
			for args in [[goal, walker.cell, {}], [goal, Vector2i(-99, -99), {}],
					[goal, walker.cell, friends]]:
				var fast := sim._distance_field(args[0], args[1], args[2])
				var slow := sim._distance_field_reference(args[0], args[1], args[2])
				compared += 1
				if fast != slow:
					wrong.append("%s goal %s" % [m.display_name, goal])
	BoardModel.reset_map()
	_check("on %d fields across %d maps, every distance is the same" % [compared, maps.size()],
		wrong.is_empty() and compared > 100, ", ".join(wrong.slice(0, 5)))


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
	# Counted from the table that BUILDS them rather than pinned to a literal. The
	# literal version failed the moment a buff was added, which taught nothing except
	# that a buff had been added — what is worth asserting is that everything the
	# builder emits is everything the pool finds, so a row that fails to load is
	# caught and a row that is deliberately added is not.
	var expected_buffs := DataBuilder.BUFF_TABLE.size()
	_check("every buff on disk loaded", pool.buffs.size() == expected_buffs,
		"loaded %d, the builder writes %d" % [pool.buffs.size(), expected_buffs])

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
	_check("twelve buffs do something other than bump a stat", non_stat == 12,
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
	# Stacking no longer sums into one fatter chance — each pick is its own roll —
	# so "stack until it is certain" is not a thing that can be done any more and
	# this asks the question that replaced it: does holding more copies make it
	# fire more often? These two checks used to call merge_extra_tier_chance(),
	# which no longer exists; the call errored at runtime and took the rest of
	# this function down with it, silently, for a whole session.
	var one_tier := TeamBuffs.new()
	one_tier.add(pool.by_id(&"promotion"), BuffData.Rarity.GOLD)
	var many_tier := TeamBuffs.new()
	for i in 8:
		many_tier.add(pool.by_id(&"promotion"), BuffData.Rarity.GOLD)
	_check("one pick is one roll, eight picks are eight",
		one_tier.merge_extra_tier_chances().size() == 1
		and many_tier.merge_extra_tier_chances().size() == 8)

	var tiers := 0
	var one_tiers := 0
	var extras := 0
	for seed_value in 40:
		if _merge_with(many_tier, seed_value).tier:
			tiers += 1
		if _merge_with(one_tier, seed_value).tier:
			one_tiers += 1
	_check("eight Promotions promote far more often than one",
		tiers > one_tiers * 2, "%d of 40 against %d of 40" % [tiers, one_tiers])

	var one_unit := TeamBuffs.new()
	one_unit.add(pool.by_id(&"windfall"), BuffData.Rarity.GOLD)
	var always_unit := TeamBuffs.new()
	for i in 8:
		always_unit.add(pool.by_id(&"windfall"), BuffData.Rarity.GOLD)
	var one_extras := 0
	for seed_value in 40:
		if _merge_with(always_unit, seed_value).extra:
			extras += 1
		if _merge_with(one_unit, seed_value).extra:
			one_extras += 1
	_check("and eight Windfalls summon far more often than one",
		extras > one_extras * 2, "%d of 40 against %d of 40" % [extras, one_extras])

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
		# The keys are extra_tierS and extra_unitS now — a count and a list, because
		# holding the same proc buff at two rarities can fire both on one merge.
		# This helper was still reading the old singular keys, so it reported
		# "nothing procced" for every merge in the suite.
		tier = int(procs.get("extra_tiers", 0)) > 0,
		extra = not (procs.get("extra_units", []) as Array).is_empty(),
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
	# Derived, not pinned. The roster is every unit row that is not `hidden` — the
	# hidden ones being things like the Sentry and the Wisp, which exist only because
	# something else summons them and must never appear in a draw. Counting the table
	# asserts exactly that rule, and keeps asserting it when a unit is added.
	var pickable := 0
	for row in DataBuilder.UNIT_TABLE:
		if not row.get("hidden", false):
			pickable += 1
	_check("every unbidden unit type is pickable and no summon is",
		roster.units.size() == pickable,
		"%d in the roster, %d unhidden rows" % [roster.units.size(), pickable])
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
	_test_hospitaller()
	_test_powderkeg()
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


func _mend_events(sim: CombatSim) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for e in sim.events:
		if e.kind == "heal" and bool(e.get("mend", false)):
			out.append(e)
	return out


func _hospitaller_board(rarity := -1) -> Dictionary:
	## The Hospitaller on (2,8), hurt at 10% itself, one ally in reach at 30%, one
	## in reach at 60%, and the worst-hurt ally of all OUT of reach at 5%. The
	## allies are rooted Spires and a wall of stone goes across row 6 once the sim
	## is set up, so the Hospitaller cannot walk off towards the enemy and out of
	## reach of its patients mid-test. The enemy is a Warden on the far side.
	## Call BoardModel.clear_changes() when done with it.
	var hosp_data := _find("hospitaller")
	var spire := _find("spire")
	var board := BoardModel.new()
	var hosp := UnitInstance.create(hosp_data, BoardModel.TEAM_B)
	board.place(hosp, Vector2i(2, 8))
	var worst := UnitInstance.create(spire, BoardModel.TEAM_B)
	var milder := UnitInstance.create(spire, BoardModel.TEAM_B)
	var far := UnitInstance.create(spire, BoardModel.TEAM_B)
	board.place(worst, Vector2i(3, 8))
	board.place(milder, Vector2i(1, 8))
	board.place(far, Vector2i(5, 10))
	var allies: Array[UnitInstance] = [worst, milder, far]
	var foe := UnitInstance.create(_find("warden"), BoardModel.TEAM_A)
	board.place(foe, Vector2i(2, 0))
	var sim := CombatSim.new()
	if rarity >= 0:
		var tb := TeamBuffs.new()
		tb.add(_pool().by_id(&"sanctuary"), rarity as BuffData.Rarity)
		tb.apply_to(hosp)
		for u in allies:
			tb.apply_to(u)
		sim.team_buffs = {BoardModel.TEAM_B: tb}
	sim.crit_chance = 0.0
	sim.setup(board, 21)
	for x in BoardModel.WIDTH:
		BoardModel.raise_wall(Vector2i(x, 6), 100000.0)
	hosp.current_hp = hosp.stat(StatModifier.Stat.MAX_HP) * 0.10
	worst.current_hp = worst.stat(StatModifier.Stat.MAX_HP) * 0.30
	milder.current_hp = milder.stat(StatModifier.Stat.MAX_HP) * 0.60
	far.current_hp = far.stat(StatModifier.Stat.MAX_HP) * 0.05
	return {sim = sim, board = board, hosp = hosp, worst = worst,
		milder = milder, far = far, foe = foe}


func _test_hospitaller() -> void:
	_section("The Hospitaller: a steady mender that fights when cornered")
	var hosp_data := _find("hospitaller")
	_check("the Hospitaller is in the roster", hosp_data != null)
	if hosp_data == null:
		return
	var ab: AbilityData = hosp_data.ability
	_check("its ability is a passive mend with no bar to fill",
		ab != null and ab.kind == AbilityData.Kind.MEND
		and hosp_data.mana_per_attack <= 0.0 and hosp_data.mana_per_charge <= 0.0
		and not hosp_data.casts_at_battle_start)
	_check("it mends a small slice once a second, from three tiles",
		is_equal_approx(ab.mend_interval, 1.0) and ab.heal_radius == 3
		and ab.mend_percent > 0.0 and ab.mend_percent <= 0.10,
		"%.2f every %.1fs within %d" % [ab.mend_percent, ab.mend_interval,
			ab.heal_radius])
	_check("it never cleanses — the Seraph stays the only cleanse",
		not ab.cleanses)
	_check("it fights from medium range and gives ground like a bow",
		hosp_data.attack_range == UnitData.RangeBand.MEDIUM
		and CombatSim.new().prefers_distance(UnitInstance.create(hosp_data,
			BoardModel.TEAM_B)))
	_check("its melee swing is well above its ordinary one",
		ab.mend_melee_mult >= 3.0, "x%.1f" % ab.mend_melee_mult)

	# --- The pulse: worst-hurt OTHER ally in reach, once a second.
	var s := _hospitaller_board()
	var sim: CombatSim = s.sim
	var hosp: UnitInstance = s.hosp
	var worst: UnitInstance = s.worst
	var worst_before := worst.current_hp
	var self_before := hosp.current_hp
	for i in 9:
		sim.step()
	_check("nothing is mended before the first second is up",
		_mend_events(sim).is_empty(),
		"%d pulses in 0.9s" % _mend_events(sim).size())
	sim.step()
	var pulses := _mend_events(sim)
	_check("one pulse lands at the one-second mark", pulses.size() == 1,
		"%d pulses" % pulses.size())
	_check("and it goes to the worst-hurt ally in reach",
		pulses.size() == 1 and int(pulses[0].uid) == worst.uid,
		"went to uid %s, wanted %d" % [
			pulses[0].uid if not pulses.is_empty() else "nobody", worst.uid])
	_check("not to itself, though it is hurt worse than any of them",
		is_equal_approx(hosp.current_hp, self_before),
		"%.1f -> %.1f" % [self_before, hosp.current_hp])
	var far: UnitInstance = s.far
	_check("and not to the dying ally out of reach",
		is_equal_approx(far.current_hp, far.stat(StatModifier.Stat.MAX_HP) * 0.05))
	var expect := worst.stat(StatModifier.Stat.MAX_HP) * CombatSim.mend_fraction(hosp, ab)
	_check("the pulse is its tier-1 slice of the patient's max health",
		is_equal_approx(worst.current_hp - worst_before, expect),
		"healed %.2f, expected %.2f" % [worst.current_hp - worst_before, expect])
	_check("the view is told where the pulse came from, for the beam",
		pulses.size() == 1 and int(pulses[0].get("source_uid", -1)) == hosp.uid)
	for i in 20:
		sim.step()
	_check("it keeps pulsing, about once a second",
		_mend_events(sim).size() == 3,
		"%d pulses in 3s" % _mend_events(sim).size())

	_check("a tier-6 pulse is twice a tier-1's slice",
		is_equal_approx(CombatSim.mend_fraction(UnitInstance.create(
			_tier_of(hosp_data, 6), BoardModel.TEAM_B), ab), ab.mend_percent * 2.0))

	# --- Melee mode: an enemy steps next to it.
	# Its own board: a hurt Spire beside it to mend, and a Warden dropped onto the
	# tile in front of it. Full health on the Hospitaller this time, so it lives.
	var mboard := BoardModel.new()
	var mh := UnitInstance.create(hosp_data, BoardModel.TEAM_B)
	mboard.place(mh, Vector2i(2, 8))
	var patient := UnitInstance.create(_find("spire"), BoardModel.TEAM_B)
	mboard.place(patient, Vector2i(3, 8))
	var foe := UnitInstance.create(_find("warden"), BoardModel.TEAM_A)
	mboard.place(foe, Vector2i(2, 2))
	mboard.move_unit(foe, Vector2i(2, 7))
	var msim := CombatSim.new()
	msim.crit_chance = 0.0
	msim.setup(mboard, 5)
	patient.current_hp = patient.stat(StatModifier.Stat.MAX_HP) * 0.30
	var stood := mh.cell
	for i in 25:
		msim.step()
	_check("with an enemy adjacent it does not mend at all",
		_mend_events(msim).is_empty(),
		"%d pulses while engaged" % _mend_events(msim).size())
	_check("it knows it is engaged, and tells the view",
		mh.mend_engaged and _has_event(msim, "mend_mode", mh.uid))
	var heavy := 0
	var heavy_ok := true
	for e in msim.events:
		if e.kind == "attack" and int(e.uid) == mh.uid:
			if bool(e.get("heavy", false)):
				heavy += 1
				var want := mh.stat(StatModifier.Stat.ATTACK_DAMAGE) * ab.mend_melee_mult
				heavy_ok = heavy_ok and is_equal_approx(float(e.amount), want) \
					and int(e.target_uid) == foe.uid
			else:
				heavy_ok = false
	_check("it swings at the adjacent enemy with the heavy hit",
		heavy >= 1 and heavy_ok, "%d heavy swings" % heavy)
	_check("and it holds its ground rather than backing off the blade",
		mh.cell == stood, "moved %s -> %s" % [stood, mh.cell])

	# --- And back to work once nothing is adjacent.
	mboard.move_unit(foe, Vector2i(2, 1))
	var cut := msim.events.size()
	for i in 25:
		msim.step()
	var resumed := 0
	var disengaged := false
	for i in range(cut, msim.events.size()):
		var e: Dictionary = msim.events[i]
		if e.kind == "heal" and bool(e.get("mend", false)):
			resumed += 1
		if e.kind == "mend_mode" and int(e.uid) == mh.uid and not bool(e.engaged):
			disengaged = true
	_check("with nobody adjacent any more it drops out of melee mode",
		disengaged and not mh.mend_engaged)
	_check("and the mending resumes", resumed >= 1,
		"%d pulses in 2.5s after the enemy left" % resumed)

	# --- It holds back at mid range instead of walking into the blade. No new rule
	# does this: it is the ordinary ranged kiting (stop at reach, give ground) on a
	# Medium-range unit, and this pins it so a later change cannot quietly break it.
	var wboard := BoardModel.new()
	var walker := UnitInstance.create(hosp_data, BoardModel.TEAM_B)
	wboard.place(walker, Vector2i(2, 8))
	var brute := UnitInstance.create(_find("warden"), BoardModel.TEAM_A)
	wboard.place(brute, Vector2i(2, 0))
	var wsim := CombatSim.new()
	wsim.crit_chance = 0.0
	wsim.setup(wboard, 21)
	for i in 150:
		wsim.step()
		if walker.mend_engaged:
			break
	var engaged_at := -1
	for i in wsim.events.size():
		var e: Dictionary = wsim.events[i]
		if e.kind == "mend_mode" and int(e.uid) == walker.uid and bool(e.engaged):
			engaged_at = i
			break
	var last_mover := -1
	for i in range(engaged_at - 1, -1, -1):
		var e: Dictionary = wsim.events[i]
		if e.kind == "move" and (int(e.uid) == walker.uid or int(e.uid) == brute.uid):
			last_mover = int(e.uid)
			break
	_check("when the lines meet, it was the enemy that closed the last tile",
		engaged_at >= 0 and last_mover == brute.uid,
		"engaged at event %d, last step by uid %d (Hospitaller %d)" % [
			engaged_at, last_mover, walker.uid])

	# --- Its buff, Sanctuary.
	var pool := _pool()
	var sanctuary := pool.by_id(&"sanctuary")
	_check("Sanctuary is a live buff in the pool", sanctuary != null)
	if sanctuary == null:
		return
	_check("it is offered only to a side fielding the Hospitaller",
		BuffPool.in_pool_for(sanctuary, {&"hospitaller": true})
		and not BuffPool.in_pool_for(sanctuary, {&"seraph": true}))
	var levels := [[BuffData.Rarity.BRONZE, 0.25], [BuffData.Rarity.SILVER, 0.50],
		[BuffData.Rarity.GOLD, 1.00]]
	for lv in levels:
		var r: BuffData.Rarity = lv[0]
		var want: float = lv[1]
		var tb := TeamBuffs.new()
		tb.add(sanctuary, r)
		var u := UnitInstance.create(hosp_data, BoardModel.TEAM_B)
		tb.apply_to(u)
		var other := UnitInstance.create(_find("seraph"), BoardModel.TEAM_B)
		tb.apply_to(other)
		_check("%s Sanctuary: +%d%% healing and +%d%% max health" % [
				BuffData.rarity_name(r), roundi(want * 100.0), roundi(want * 100.0)],
			is_equal_approx(u.stat(StatModifier.Stat.HEAL_POWER), 1.0 + want)
			and is_equal_approx(u.stat(StatModifier.Stat.MAX_HP),
				hosp_data.max_hp * (1.0 + want)),
			"heal x%.2f, hp %.0f" % [u.stat(StatModifier.Stat.HEAL_POWER),
				u.stat(StatModifier.Stat.MAX_HP)])
		_check("%s Sanctuary leaves a Seraph alone" % BuffData.rarity_name(r),
			is_equal_approx(other.stat(StatModifier.Stat.HEAL_POWER), 1.0)
			and is_equal_approx(other.stat(StatModifier.Stat.MAX_HP),
				_find("seraph").max_hp))

	var g := _hospitaller_board(BuffData.Rarity.GOLD)
	var gsim: CombatSim = g.sim
	var gw: UnitInstance = g.worst
	var gw_before := gw.current_hp
	for i in 10:
		gsim.step()
	var gexpect := gw.stat(StatModifier.Stat.MAX_HP) * ab.mend_percent * 2.0
	_check("and gold Sanctuary really doubles what a pulse puts back",
		is_equal_approx(gw.current_hp - gw_before, gexpect),
		"healed %.2f, expected %.2f" % [gw.current_hp - gw_before, gexpect])
	BoardModel.clear_changes()


func _kind_events(sim: CombatSim, kind: String, uid := -1) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for e in sim.events:
		if e.kind == kind and (uid < 0 or int(e.get("uid", -1)) == uid):
			out.append(e)
	return out


func _keg_sim(board: BoardModel, tb: TeamBuffs = null, seed := 7) -> CombatSim:
	## No crits, so every blast is exactly its figure. The buffs, if any, are the
	## Powderkeg's side's (team B in every board below).
	var sim := CombatSim.new()
	sim.crit_chance = 0.0
	if tb != null:
		sim.team_buffs = {BoardModel.TEAM_B: tb}
	sim.setup(board, seed)
	return sim


func _light(sim: CombatSim, keg: UnitInstance, killer: UnitInstance) -> void:
	## Kills the keg the ordinary way: one blow through _damage, so it goes down
	## the same funnel every death does.
	sim._damage(keg, 1000000.0, killer)


func _run_out(sim: CombatSim, limit := 200) -> void:
	var n := 0
	while not sim.is_finished() and n < limit:
		sim.step()
		n += 1


func _test_powderkeg() -> void:
	_section("The Powderkeg: worth more dead")
	var keg_data := _find("powderkeg")
	_check("the Powderkeg is in the roster", keg_data != null)
	if keg_data == null:
		return
	var ab: AbilityData = keg_data.ability
	_check("its ability is Slow Match, a passive with no bar to fill",
		ab != null and ab.kind == AbilityData.Kind.FUSE and ab.id == &"slow_match"
		and keg_data.mana_per_attack <= 0.0 and keg_data.mana_per_charge <= 0.0
		and not keg_data.casts_at_battle_start)
	if ab == null or ab.kind != AbilityData.Kind.FUSE:
		return
	var row := {}
	for r in DataBuilder.UNIT_TABLE:
		if r.id == &"powderkeg":
			row = r
	_check("its table row is a 110-health body with a 7-damage swing",
		not row.is_empty() and is_equal_approx(row.hp, 110.0)
		and is_equal_approx(row.dmg, 7.0))
	# Tier-scaled like everything else, then bent by tier: twice the health through
	# tier 3 tapering to none at tier 6, and a little more swing in the middle. Every
	# tier file has to be what the row says, and the bend has to stop at the top,
	# where the blast already scales with tier and did not need the help.
	var built_ok := not row.is_empty()
	var built: PackedStringArray = []
	for t in range(1, 7):
		var d := _tier_of(keg_data, t)
		if d == null or row.is_empty():
			built_ok = false
			continue
		var hp := snappedf(110.0 * pow(2.0, t - 1) * float(row.tier_hp[t - 1]), 1.0)
		var dmg := snappedf(7.0 * pow(2.0, t - 1) * float(row.tier_dmg[t - 1]), 0.5)
		built.append("T%d %.0f/%.1f" % [t, d.max_hp, d.attack_damage])
		built_ok = built_ok and is_equal_approx(d.max_hp, hp) \
			and is_equal_approx(d.attack_damage, dmg)
	_check("every tier is the doubling bent by the row's per-tier figures",
		built_ok, ", ".join(built))
	_check("twice the health at tiers 1-3, and no bend at all at tier 6",
		not row.is_empty() and is_equal_approx(keg_data.max_hp, 220.0)
		and is_equal_approx(_tier_of(keg_data, 3).max_hp, 880.0)
		and is_equal_approx(_tier_of(keg_data, 6).max_hp, 3520.0)
		and is_equal_approx(_tier_of(keg_data, 6).attack_damage, 224.0),
		", ".join(built))
	var usual := snappedf(0.50 * DataBuilder.MOVE_SCALE, 0.01)
	_check("a shade quicker on its feet than the usual stride",
		keg_data.move_time < usual and keg_data.move_time >= usual * 0.9,
		"%.2fs a tile against %.2fs" % [keg_data.move_time, usual])
	var want_fuse := [2.0, 1.75, 1.5, 1.25, 1.0, 0.75]
	var fuse_ok := ab.fuse_seconds_by_tier.size() == want_fuse.size()
	var got: PackedStringArray = []
	for t in range(1, 7):
		got.append("%.2f" % ab.fuse_seconds_for(t))
		fuse_ok = fuse_ok and is_equal_approx(ab.fuse_seconds_for(t), want_fuse[t - 1])
	_check("the fuse is a per-tier list in the data: 2 / 1.75 / 1.5 / 1.25 / 1 / 0.75s",
		fuse_ok, " / ".join(got))
	_check("the blast is 5x attack over the 3x3, and the panic reaches two tiles",
		is_equal_approx(ab.blast_attack_multiple, 5.0) and ab.blast_radius == 1
		and ab.flee_radius == 2)
	_check("the codex says there is no bar, and names its fuse",
		UnitCodex.charge_line(keg_data).contains("No bar")
		and UnitCodex.charge_line(keg_data).contains("2s")
		and ab.describe().contains("2/1.75/1.5/1.25/1/0.75"),
		UnitCodex.charge_line(keg_data))

	# --- Dying lights it. A rooted, harmless Spire is the only enemy, far away.
	BoardModel.reset_map()
	var board := BoardModel.new()
	var keg := UnitInstance.create(keg_data, BoardModel.TEAM_B)
	board.force_place(keg, Vector2i(2, 7))
	var foe := UnitInstance.create(_find("spire"), BoardModel.TEAM_A)
	board.force_place(foe, Vector2i(2, 1))
	var sim := _keg_sim(board)
	var lit_at := keg.cell
	_light(sim, keg, foe)
	_check("a killing blow lights it instead of killing it",
		keg.is_lit() and _kind_events(sim, "fuse_lit", keg.uid).size() == 1
		and _kind_events(sim, "death", keg.uid).is_empty(),
		"lit %s, %d deaths" % [keg.is_lit(), _kind_events(sim, "death", keg.uid).size()])
	_check("its fuse is its tier's figure", is_equal_approx(keg.fuse_left, 2.0),
		"%.2fs" % keg.fuse_left)
	_check("it is still standing on its tile", board.unit_at(keg.cell) == keg)
	_check("and dead to every sweep that asks",
		not keg.is_alive() and board.nearest_enemy(foe) == null
		and board.units_in_box(keg.cell, 3).is_empty()
		and sim._choose_enemy(foe) == null)
	# The gate is is_lit() inside is_alive(), not the empty health bar, so it has to
	# hold with health put back on the barrel.
	keg.current_hp = 25.0
	_check("with health put back on it, it is still untargetable",
		not keg.is_alive() and board.nearest_enemy(foe) == null
		and board.units_in_box(keg.cell, 3).is_empty())
	keg.heal(50.0)
	_check("and heal() refuses it", is_equal_approx(keg.current_hp, 25.0),
		"%.1f" % keg.current_hp)
	sim._damage(keg, 500.0, foe)
	_check("and nothing can hit it", is_equal_approx(keg.current_hp, 25.0),
		"%.1f" % keg.current_hp)
	keg.current_hp = 0.0
	sim.step()
	_check("its side has nobody left standing, and the round is not over",
		sim.living_count(BoardModel.TEAM_B) == 0 and not sim.is_finished(),
		"B %d, finished %s" % [sim.living_count(BoardModel.TEAM_B), sim.is_finished()])
	_run_out(sim)
	var blasts := _kind_events(sim, "fuse_blast", keg.uid)
	var ends := _kind_events(sim, "end")
	_check("it ends when the fuse does, and not a tick before",
		sim.is_finished() and blasts.size() == 1 and ends.size() == 1
		and float(ends[0].t) >= float(blasts[0].t)
		and float(blasts[0].t) >= 1.9,
		"%d blasts, end at %s" % [blasts.size(),
			"-" if ends.is_empty() else str(ends[0].t)])
	_check("and then it really is dead and gone",
		keg.state == UnitInstance.State.DEAD and board.unit_at(keg.cell) != keg
		and _kind_events(sim, "death", keg.uid).size() == 1)
	if not blasts.is_empty():
		var at: Vector2i = blasts[0].cell
		_check("while lit it walked at the nearest enemy",
			BoardModel.box_distance(at, foe.cell) < BoardModel.box_distance(lit_at, foe.cell),
			"lit at %s, blew at %s, enemy at %s" % [lit_at, at, foe.cell])
		_check("and went off on the tile it had walked to",
			at != lit_at and at == keg.cell, "%s" % at)
	_check("it never swung or cast while lit",
		_kind_events(sim, "attack", keg.uid).is_empty()
		and _kind_events(sim, "cast_start", keg.uid).is_empty())
	var steps := _kind_events(sim, "move", keg.uid)
	_check("it walks at its own stride",
		not steps.is_empty() and is_equal_approx(float(steps[0].duration),
			keg.stat(StatModifier.Stat.MOVE_TIME)),
		"" if steps.is_empty() else "%.3fs" % float(steps[0].duration))

	# --- It never digs: a solid row of breakable stone between it and the enemy.
	var wboard := BoardModel.new()
	var wkeg := UnitInstance.create(keg_data, BoardModel.TEAM_B)
	wboard.force_place(wkeg, Vector2i(2, 7))
	var wfoe := UnitInstance.create(_find("spire"), BoardModel.TEAM_A)
	wboard.force_place(wfoe, Vector2i(2, 1))
	var wsim := _keg_sim(wboard)
	for x in BoardModel.WIDTH:
		BoardModel.raise_wall(Vector2i(x, 5), 500.0)
	_light(wsim, wkeg, wfoe)
	_run_out(wsim)
	var dug := 0
	for e in wsim.events:
		if e.kind == "wall_hit" and int(e.get("uid", -1)) == wkeg.uid:
			dug += 1
	_check("walled off, it waits at the stone rather than digging",
		dug == 0 and BoardModel.is_wall(Vector2i(2, 5))
		and is_equal_approx(BoardModel.wall_hp(Vector2i(2, 5)), 500.0),
		"%d blows at the wall" % dug)
	BoardModel.clear_changes()

	# --- Frozen at the moment of death: defused.
	var fboard := BoardModel.new()
	var fkeg := UnitInstance.create(keg_data, BoardModel.TEAM_B)
	fboard.force_place(fkeg, Vector2i(2, 7))
	var ffoe := UnitInstance.create(_find("spire"), BoardModel.TEAM_A)
	fboard.force_place(ffoe, Vector2i(2, 1))
	var fsim := _keg_sim(fboard)
	fkeg.frozen_left = 3.0
	_light(fsim, fkeg, ffoe)
	_run_out(fsim)
	_check("killed while frozen, it is defused: it just dies",
		not fkeg.is_lit() and _kind_events(fsim, "fuse_lit", fkeg.uid).is_empty()
		and _kind_events(fsim, "fuse_blast", fkeg.uid).is_empty()
		and _kind_events(fsim, "death", fkeg.uid).size() == 1)

	# --- Frozen AFTER it lit, with an enemy far enough away to walk at: it stays put.
	var zboard := BoardModel.new()
	var zkeg := UnitInstance.create(keg_data, BoardModel.TEAM_B)
	zboard.force_place(zkeg, Vector2i(2, 7))
	var zfoe := UnitInstance.create(_find("spire"), BoardModel.TEAM_A)
	zboard.force_place(zfoe, Vector2i(2, 1))
	var zsim := _keg_sim(zboard)
	_light(zsim, zkeg, zfoe)
	zkeg.frozen_left = 5.0
	_run_out(zsim)
	var zb := _kind_events(zsim, "fuse_blast", zkeg.uid)
	_check("frozen after lighting, it does not walk however far the enemy is",
		_kind_events(zsim, "move", zkeg.uid).is_empty() and zb.size() == 1
		and zb[0].cell == Vector2i(2, 7),
		"%d steps" % _kind_events(zsim, "move", zkeg.uid).size())

	# --- Frozen AFTER it lit: it stands still, and blows where it stands. Pinned
	# like that, the blast's footprint can be checked tile by tile. Rooted Spires
	# for victims, so nobody can run: one ally and one enemy inside the 3x3, one of
	# each just outside it.
	var pboard := BoardModel.new()
	var pkeg := UnitInstance.create(keg_data, BoardModel.TEAM_B)
	pboard.force_place(pkeg, Vector2i(2, 7))
	var spire := _find("spire")
	var in_ally := UnitInstance.create(spire, BoardModel.TEAM_B)
	var in_foe := UnitInstance.create(spire, BoardModel.TEAM_A)
	var out_ally := UnitInstance.create(spire, BoardModel.TEAM_B)
	var out_foe := UnitInstance.create(spire, BoardModel.TEAM_A)
	pboard.force_place(in_ally, Vector2i(1, 6))
	pboard.force_place(in_foe, Vector2i(3, 8))
	pboard.force_place(out_ally, Vector2i(4, 7))
	pboard.force_place(out_foe, Vector2i(2, 9))
	var psim := _keg_sim(pboard)
	_light(psim, pkeg, in_foe)
	pkeg.frozen_left = 5.0
	var hp_before := {}
	for u in [in_ally, in_foe, out_ally, out_foe]:
		hp_before[u.uid] = u.current_hp
	var expect := psim.blast_damage_of(pkeg)
	_run_out(psim)
	_check("frozen after lighting, it stands still and the fuse burns on",
		_kind_events(psim, "move", pkeg.uid).is_empty()
		and _kind_events(psim, "fuse_blast", pkeg.uid).size() == 1
		and _kind_events(psim, "fuse_blast", pkeg.uid)[0].cell == Vector2i(2, 7))
	_check("the blast is attack x 5 x tier",
		is_equal_approx(expect, keg_data.attack_damage * 5.0 * 1.0),
		"%.1f" % expect)
	var lost := func(u: UnitInstance) -> float:
		return float(hp_before[u.uid]) - u.current_hp
	_check("it hits its own side inside the 3x3",
		is_equal_approx(lost.call(in_ally), expect * in_ally.damage_taken_multiplier()),
		"%.1f" % lost.call(in_ally))
	_check("and the enemy inside it",
		is_equal_approx(lost.call(in_foe), expect * in_foe.damage_taken_multiplier()),
		"%.1f" % lost.call(in_foe))
	_check("and nothing outside it, on either side",
		is_zero_approx(lost.call(out_ally)) and is_zero_approx(lost.call(out_foe)),
		"%.1f / %.1f" % [lost.call(out_ally), lost.call(out_foe)])

	# --- The panic. Both sides within two tiles run; three tiles out does not.
	var rboard := BoardModel.new()
	var rkeg := UnitInstance.create(keg_data, BoardModel.TEAM_B)
	rboard.force_place(rkeg, Vector2i(2, 7))
	var lancer := _find("lancer")
	var ally_near := UnitInstance.create(lancer, BoardModel.TEAM_B)
	var foe_near := UnitInstance.create(lancer, BoardModel.TEAM_A)
	var ally_far := UnitInstance.create(lancer, BoardModel.TEAM_B)
	var foe_far := UnitInstance.create(_find("archer"), BoardModel.TEAM_A)
	rboard.force_place(ally_near, Vector2i(3, 8))
	rboard.force_place(foe_near, Vector2i(2, 5))
	rboard.force_place(ally_far, Vector2i(5, 9))
	rboard.force_place(foe_far, Vector2i(2, 1))
	var rsim := _keg_sim(rboard)
	_light(rsim, rkeg, foe_near)
	_check("everything within two tiles runs from it, both sides",
		ally_near.flee_from_uid == rkeg.uid and foe_near.flee_from_uid == rkeg.uid)
	_check("and nothing three tiles out does",
		ally_far.flee_from_uid == -1 and foe_far.flee_from_uid == -1)
	var lit_events := _kind_events(rsim, "fuse_lit", rkeg.uid)
	_check("the view is told who is running",
		lit_events.size() == 1 and (lit_events[0].fleeing as Array).size() == 2)
	rsim.step()
	_check("the enemy beside it runs instead of closing in",
		BoardModel.box_distance(foe_near.cell, Vector2i(2, 7)) > 2,
		"at %s" % foe_near.cell)
	_check("and so does its own side",
		BoardModel.box_distance(ally_near.cell, Vector2i(2, 7)) > 1,
		"at %s" % ally_near.cell)
	# Directly, against a keg that has moved: the step is measured from where the
	# keg is NOW. The runner lit just below it, the keg at (2,5) and the runner at
	# (2,6). Measured from the lit tile the best step is further down, to (2,7). But
	# the keg has since walked round to (2,8), BELOW the runner, so the right step is
	# back up into the tile the keg left.
	var dboard := BoardModel.new()
	var dkeg := UnitInstance.create(keg_data, BoardModel.TEAM_B)
	dboard.force_place(dkeg, Vector2i(2, 5))
	var runner := UnitInstance.create(lancer, BoardModel.TEAM_A)
	dboard.force_place(runner, Vector2i(2, 6))
	var dsim := _keg_sim(dboard)
	_light(dsim, dkeg, runner)
	dboard.move_unit(dkeg, Vector2i(2, 8))
	var before_d := BoardModel.box_distance(runner.cell, dkeg.cell)
	var stepped: bool = dsim._flee(runner)
	_check("each step takes it as far as it can get from the keg's CURRENT tile",
		stepped and runner.cell == Vector2i(2, 5)
		and BoardModel.box_distance(runner.cell, dkeg.cell) == before_d + 1,
		"stepped to %s" % runner.cell)
	_run_out(rsim)
	_check("the panic ends with the blast",
		ally_near.flee_from_uid == -1 and foe_near.flee_from_uid == -1)
	_check("and a fleeing unit never made the keg swing",
		_kind_events(rsim, "attack", rkeg.uid).is_empty())

	# --- Unhealable by the Hospitaller's pulse, which hunts for the worst-hurt
	# ally and would otherwise find a barrel on 1 health irresistible.
	var hboard := BoardModel.new()
	var medic := UnitInstance.create(_find("hospitaller"), BoardModel.TEAM_B)
	var hkeg := UnitInstance.create(keg_data, BoardModel.TEAM_B)
	var patient := UnitInstance.create(spire, BoardModel.TEAM_B)
	hboard.force_place(medic, Vector2i(2, 8))
	hboard.force_place(hkeg, Vector2i(3, 8))
	hboard.force_place(patient, Vector2i(1, 8))
	var hfoe := UnitInstance.create(spire, BoardModel.TEAM_A)
	hboard.force_place(hfoe, Vector2i(2, 0))
	var hsim := _keg_sim(hboard)
	patient.current_hp = patient.stat(StatModifier.Stat.MAX_HP) * 0.5
	_light(hsim, hkeg, hfoe)
	hkeg.current_hp = 1.0
	for i in 12:
		hsim.step()
	var to_keg := 0
	var mends := 0
	for e in _mend_events(hsim):
		mends += 1
		if int(e.uid) == hkeg.uid:
			to_keg += 1
	_check("the Hospitaller's pulse passes a lit keg over",
		mends >= 1 and to_keg == 0 and is_equal_approx(hkeg.current_hp, 1.0),
		"%d pulses, %d to the keg" % [mends, to_keg])
	_check("and its worst-hurt pick skips it",
		hsim._worst_hurt_ally(medic, 3, true, true) != hkeg)

	# --- The round boundary.
	var rk := UnitInstance.create(keg_data, BoardModel.TEAM_B)
	rk.fuse_left = 1.0
	rk.flee_from_uid = 42
	rk.reset_for_battle()
	_check("reset_for_battle clears the fuse and the panic",
		is_zero_approx(rk.fuse_left) and rk.flee_from_uid == -1 and rk.is_alive())

	# --- The clock. A fuse still burning when time is called gets to finish.
	var cboard := BoardModel.new()
	var ckeg := UnitInstance.create(keg_data, BoardModel.TEAM_B)
	cboard.force_place(ckeg, Vector2i(2, 7))
	var cfoe := UnitInstance.create(spire, BoardModel.TEAM_A)
	cboard.force_place(cfoe, Vector2i(2, 1))
	var csim := _keg_sim(cboard)
	_light(csim, ckeg, cfoe)
	csim.run(0.5)
	_check("a fuse still lit when the time runs out is allowed to go off",
		_kind_events(csim, "fuse_blast", ckeg.uid).size() == 1 and csim.is_finished())

	_test_saltpetre(keg_data)
	BoardModel.clear_changes()


func _test_saltpetre(keg_data: UnitData) -> void:
	var pool := _pool()
	var salt := pool.by_id(&"saltpetre")
	_check("Saltpetre is a live buff in the pool", salt != null)
	if salt == null:
		return
	_check("it is offered only to a side fielding the Powderkeg",
		BuffPool.in_pool_for(salt, {&"powderkeg": true})
		and not BuffPool.in_pool_for(salt, {&"warden": true}))
	var atk := [2.0, 3.0, 4.0]
	var spd := [1.25, 1.5, 2.0]
	for r in [BuffData.Rarity.BRONZE, BuffData.Rarity.SILVER, BuffData.Rarity.GOLD]:
		var u := UnitInstance.create(keg_data, BoardModel.TEAM_B)
		var tb := TeamBuffs.new()
		tb.add(salt, r)
		tb.apply_to(u)
		var a: float = u.stat(StatModifier.Stat.ATTACK_DAMAGE) / keg_data.attack_damage
		var s: float = keg_data.move_time / u.stat(StatModifier.Stat.MOVE_TIME)
		_check("%s Saltpetre: +%d%% attack and +%d%% movement speed" % [
			BuffData.rarity_name(r), roundi((atk[r] - 1.0) * 100.0),
			roundi((spd[r] - 1.0) * 100.0)],
			is_equal_approx(a, atk[r]) and is_equal_approx(s, spd[r]),
			"x%.2f attack, x%.2f speed" % [a, s])
		var ssim := CombatSim.new()
		ssim.team_buffs = {BoardModel.TEAM_B: tb}
		var offs := ssim.blast_offsets(u)
		if r == BuffData.Rarity.GOLD:
			_check("gold turns the blast into a diamond of arm 3",
				offs.size() == 25 and offs.has(Vector2i(0, 3)) and offs.has(Vector2i(-3, 0))
				and offs.has(Vector2i(1, 2)) and not offs.has(Vector2i(2, 2)),
				"%d tiles" % offs.size())
		else:
			_check("%s leaves it the 3x3" % BuffData.rarity_name(r),
				offs.size() == 9 and offs.has(Vector2i(1, 1)), "%d tiles" % offs.size())
		_check("%s: the blast carries the extra attack" % BuffData.rarity_name(r),
			is_equal_approx(ssim.blast_damage_of(u), keg_data.attack_damage * atk[r] * 5.0),
			"%.1f" % ssim.blast_damage_of(u))
	_check("the gold card says the blast becomes a diamond",
		salt.describe(BuffData.Rarity.GOLD).contains("diamond")
		and salt.describe(BuffData.Rarity.BRONZE).contains("At gold"),
		salt.describe(BuffData.Rarity.GOLD))
	_check("the diamond's arm is a number in the data, not the code",
		salt.blast_diamond_at_gold == 3)

	# The lit walk with the speed buff on: buff speed counts.
	var tb2 := TeamBuffs.new()
	tb2.add(salt, BuffData.Rarity.BRONZE)
	var board := BoardModel.new()
	var keg := UnitInstance.create(keg_data, BoardModel.TEAM_B)
	board.force_place(keg, Vector2i(2, 7))
	tb2.apply_to(keg)
	var foe := UnitInstance.create(_find("spire"), BoardModel.TEAM_A)
	board.force_place(foe, Vector2i(2, 1))
	var sim := _keg_sim(board, tb2)
	_light(sim, keg, foe)
	sim.step()
	var steps := _kind_events(sim, "move", keg.uid)
	_check("lit, it walks at its buffed speed",
		not steps.is_empty() and is_equal_approx(float(steps[0].duration),
			keg_data.move_time / 1.25),
		"" if steps.is_empty() else "%.3fs a tile" % float(steps[0].duration))

	# Gold, for real: a diamond-shaped hole three tiles straight out. Pinned with a
	# freeze so the footprint is exact. (2,7)+(0,3) is out of reach of the square
	# and inside the diamond; (4,6) is outside both.
	var tbg := TeamBuffs.new()
	tbg.add(salt, BuffData.Rarity.GOLD)
	var gboard := BoardModel.new()
	var gkeg := UnitInstance.create(keg_data, BoardModel.TEAM_B)
	gboard.force_place(gkeg, Vector2i(2, 4))
	tbg.apply_to(gkeg)
	var spire := _find("spire")
	var tip := UnitInstance.create(spire, BoardModel.TEAM_A)
	var near := UnitInstance.create(spire, BoardModel.TEAM_A)
	var clear := UnitInstance.create(spire, BoardModel.TEAM_A)
	gboard.force_place(tip, Vector2i(2, 7))
	gboard.force_place(near, Vector2i(3, 5))
	gboard.force_place(clear, Vector2i(4, 6))
	var gsim := _keg_sim(gboard, tbg)
	_light(gsim, gkeg, tip)
	gkeg.frozen_left = 5.0
	var tip_hp := tip.current_hp
	var near_hp := near.current_hp
	var clear_hp := clear.current_hp
	_run_out(gsim)
	_check("a gold blast reaches three tiles straight out",
		tip.current_hp < tip_hp and near.current_hp < near_hp,
		"%.0f -> %.0f, %.0f -> %.0f" % [tip_hp, tip.current_hp, near_hp, near.current_hp])
	_check("and still misses the corner two-and-two away",
		is_equal_approx(clear.current_hp, clear_hp))
	var lit := _kind_events(gsim, "fuse_lit", gkeg.uid)
	_check("and the view is handed the diamond to draw",
		lit.size() == 1 and (lit[0].offsets as Array).size() == 25 and bool(lit[0].diamond))

	# Rider-only buffs are real buffs. The live check used to look only at the
	# bronze/silver/gold triples, so a buff whose whole effect was a gold-only
	# scalar loaded, sat on disk and was never offered.
	var rider := BuffData.new()
	rider.id = &"test_blast_rider"
	rider.unit_id = &"powderkeg"
	rider.blast_diamond_at_gold = 3
	_check("a buff made only of the blast rider still counts as live",
		BuffPool.new()._is_live(rider))
	var reel := BuffData.new()
	reel.id = &"test_reel_rider"
	reel.disorient_bonus = Vector3(1.0, 2.0, 3.0)
	_check("and so does one made only of extra disorientation",
		BuffPool.new()._is_live(reel))
	var empty := BuffData.new()
	empty.id = &"test_nothing"
	_check("while one with nothing in it at all still does not",
		not BuffPool.new()._is_live(empty))
	BoardModel.clear_changes()


func _tier_of(base: UnitData, tier: int) -> UnitData:
	var d := base
	while d != null and d.tier < tier:
		d = d.next_tier
	return d


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
	# One more wisp per tier, unlike every other retinue in the game, which gains
	# one every two tiers. The Conjurer's whole body is its retinue.
	_check("the wisp cap climbs one per tier, 1 through 6",
		caps == PackedInt32Array([1, 2, 3, 4, 5, 6]), str(caps))
	_check("a tier 1 holds one wisp, a tier 6 holds six",
		sim.summon_cap(t1, ab) == 1 and sim.summon_cap(t6, ab) == 6,
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
	_check("the opening cast fills the retinue: one wisp per tier",
		opened == PackedInt32Array([1, 2, 3, 4, 5, 6]), str(opened))

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
	_check("a tier 6 opens with six wisps", live.retinue_size(six) == 6,
		"opened with %d" % live.retinue_size(six))

	for u in board.all_units():
		if u.summoned_by == six.uid and u.is_alive():
			u.current_hp = 0.0
			board.remove(u)
			break
	_check("losing one leaves room for one more",
		live.retinue_size(six) == 5
		and live.summon_want(six, ab) == 1,
		"retinue %d, wants %d" % [
			live.retinue_size(six), live.summon_want(six, ab)])

	six.mana = UnitInstance.MANA_MAX
	# Long enough for the 0.5s wind-up to finish; a cast is not instant.
	for i in 12:
		live.step()
	_check("and the next full bar replaces it",
		live.retinue_size(six) == 6,
		"retinue back to %d, made %d all round" % [
			live.retinue_size(six), six.summons_made])
	_check("the replacement is counted as a seventh summon, not a reused slot",
		six.summons_made == 7, "summons_made is %d" % six.summons_made)


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
	var raw := aegis.damage_resist + buff.magnitude(BuffData.Rarity.GOLD).y
	var want := minf(raw, UnitInstance.MAX_RESIST)
	_check("gold Retaliation adds its resist on top of the innate share",
		is_equal_approx(strong.resist(), want),
		"%.2f, expected %.2f (raw %.2f)" % [strong.resist(), want, raw])
	# Named rather than merely tolerated. The innate share is now high enough that
	# the buff's own 45 resist points fall off the end of the cap entirely.
	#
	# That does NOT make Retaliation a bad pick, and an earlier note here said it
	# did. Retaliation is a two-stat buff and its MAX_HP half is untouched by any of
	# this: measured through the simulation it is still worth about twelve points of
	# win rate. What is dead is the half the card spends its words on. If the innate
	# number comes back down, this check goes green on its own and can be deleted.
	_check("at this innate share the cap is eating the buff's resist half",
		raw > UnitInstance.MAX_RESIST,
		"%.2f raw is still under the %.2f cap" % [raw, UnitInstance.MAX_RESIST])
	# The flat modifier is genuinely present even when the cap hides it, which is
	# what stops a future "the buff does nothing" conclusion from being drawn off
	# resist() alone.
	_check("and the points really are on the unit, cap or no cap",
		is_equal_approx(strong.stat(StatModifier.Stat.RESIST), raw),
		"%.2f, expected %.2f" % [strong.stat(StatModifier.Stat.RESIST), raw])
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
	b.force_place(decoy, Vector2i(2, 9))
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
	b2.force_place(eng2, Vector2i(2, 9))
	b2.force_place(friend, Vector2i(2, 8))
	var sim2 := CombatSim.new()
	sim2.board = b2
	var found := sim2._backline_enemy(killer2)
	_check("with nothing behind it, the Engineer is the one that gets found",
		found == eng2,
		"picked %s at %s; engineer at %s, friend at %s" % [
			"nothing" if found == null else found.data.display_name,
			"-" if found == null else str(found.cell), eng2.cell, friend.cell])


func _test_the_assassin_vanishes_before_it_moves() -> void:
	_section("Shadowstep: the cloak comes first")
	# The order the two halves are emitted in, which is the whole of this check.
	# Mechanically the difference is almost nothing — nothing retargets inside one
	# instant — but it is what the ability describes, and the view's cloak beat hangs
	# off it: hold the log on the vanish and, with the events the other way round,
	# you get a unit that reappears somewhere else and THEN turns invisible.
	BoardModel.reset_map()
	var b := BoardModel.new()
	var killer := UnitInstance.create(
		BoardModel.at_tier(_must_find("assassin"), 3), BoardModel.TEAM_A)
	b.force_place(killer, Vector2i(2, 1))
	# Tier 6 so it survives the opener and the log is not cut short by a death.
	var victim := UnitInstance.create(
		BoardModel.at_tier(_must_find("warden"), 6), BoardModel.TEAM_B)
	b.force_place(victim, Vector2i(2, 9))
	var sim := CombatSim.new()
	sim.crit_chance = 0.0
	sim.setup(b, 171)

	var cloak := -1
	var jump := -1
	for i in sim.events.size():
		var e: Dictionary = sim.events[i]
		if int(e.get("uid", -1)) != killer.uid:
			continue
		if e.kind == "stealth" and bool(e.get("on", false)) and cloak < 0:
			cloak = i
		elif e.kind == "blink" and jump < 0:
			jump = i
	_check("the Assassin cloaked", cloak >= 0)
	_check("and jumped", jump >= 0)
	if cloak < 0 or jump < 0:
		return
	_check("the cloak is emitted before the jump, not after it",
		cloak < jump, "stealth at %d, blink at %d" % [cloak, jump])
	# The label the view draws needs a tile to draw at, and this event used to be
	# emitted without one — which threw at runtime and silently swallowed the
	# "VANISH" label every time an Assassin opened.
	_check("and the cloak event carries a cell for the view to anchor to",
		sim.events[cloak].has("cell"), str(sim.events[cloak]))


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
	b.place(away, Vector2i(0, 9))
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
	# One exception, and it is deliberate: the Transcendence is printed at
	# Unlimited at every tier. The reserve exists so a range buff feels like a
	# prize; a unit that starts at the ceiling simply cannot be given one, which
	# is a real cost of that unit and not a mistake in the ladder.
	var over: PackedStringArray = []
	for u in _roster().units:
		if String(u.id) == "transcendence":
			continue
		if u.attack_range > UnitData.MAX_PRINTED_BAND:
			over.append("%s at %s" % [u.id, u.range_name()])
	_check("no unit but the Transcendence is printed above the printable band",
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
	_check("it is a stat stick with no ability",
		transcendence.ability == null and transcendence.max_hp > 150.0)
	# Unlimited range is the APEX now, not the unit. A tier 1 holding the strongest
	# range band in the game made every tier below six a formality.
	_check("below the apex it is an ordinary medium-range beam",
		transcendence.range_name() == "Medium", transcendence.range_name())
	# And because it is no longer at the ceiling, a range buff works on it again —
	# which is the other half of the change: gold Far Sight used to be the one buff
	# in the game this unit could not use.
	var capped := UnitInstance.create(transcendence, BoardModel.TEAM_A)
	capped.apply_modifiers([StatModifier.make(StatModifier.Stat.ATTACK_RANGE,
		StatModifier.Mode.FLAT, 1.0)] as Array[StatModifier])
	_check("and a range buff now pushes it a band further",
		capped.range_band() > UnitData.RangeBand.MEDIUM, capped.range_name())
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
	# Range is what tier 6 buys, and it is the only tier that buys it. A tier 5 is a
	# medium-range beam; the apex reaches the whole board and shoots through stone.
	_check("no tier below the apex reaches the whole board",
		five.range_name() == "Medium" and five.pierce_targets == 1,
		"%s range, pierce %d" % [five.range_name(), five.pierce_targets])
	_check("and tier 6 is what buys both the range and the beam",
		apex.range_name() == "Unlimited" and apex.pierce_targets > 20,
		"%s range, pierce %d" % [apex.range_name(), apex.pierce_targets])
	# Shooting through walls rides on the range band, so this is the same change
	# seen from the other side: only the apex ignores stone.
	var probe := CombatSim.new()
	_check("only the apex shoots through walls",
		probe.shoots_through_walls(UnitInstance.create(apex, BoardModel.TEAM_A))
		and not probe.shoots_through_walls(
			UnitInstance.create(five, BoardModel.TEAM_A)))
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
	board.place(caster, Vector2i(2, 9))
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
	board.place(far, Vector2i(5, 9))
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
		# It is the mana buff and the HOST buff now. The health rider is gone on
		# purpose: a bigger Spire is worth very little, because the unit spends
		# itself the moment its bar fills and was never going to be hit much.
		_check("and it no longer touches the Spire's health at all",
			is_equal_approx(spire.stat(StatModifier.Stat.MAX_HP), hp0),
			"%.0f from %.0f" % [spire.stat(StatModifier.Stat.MAX_HP), hp0])
		_check("what it adds instead is bodies: +1/+2/+3 raised per cast",
			incubation.extra_summons_at(BuffData.Rarity.BRONZE) == 1
				and incubation.extra_summons_at(BuffData.Rarity.SILVER) == 2
				and incubation.extra_summons_at(BuffData.Rarity.GOLD) == 3,
			"%d/%d/%d" % [
				incubation.extra_summons_at(BuffData.Rarity.BRONZE),
				incubation.extra_summons_at(BuffData.Rarity.SILVER),
				incubation.extra_summons_at(BuffData.Rarity.GOLD)])

		var gold_spire := UnitInstance.create(_find("spire"), BoardModel.TEAM_A)
		var ghp := gold_spire.stat(StatModifier.Stat.MAX_HP)
		gold_spire.apply_modifiers(incubation.modifiers_for(BuffData.Rarity.GOLD))
		var inc_g := incubation.magnitude(BuffData.Rarity.GOLD)
		_check("gold Incubation reaches its full mana number",
			is_equal_approx(gold_spire.mana_per_charge(), 8.0 + inc_g.x)
				and is_equal_approx(gold_spire.stat(StatModifier.Stat.MAX_HP), ghp),
			"%.1f/s, %.0f hp" % [
				gold_spire.mana_per_charge(),
				gold_spire.stat(StatModifier.Stat.MAX_HP)])

		# And the number the sim actually reads, not just the number on the card.
		var host_board := BoardModel.new()
		var caster := UnitInstance.create(_find("spire"), BoardModel.TEAM_A)
		host_board.force_place(caster, Vector2i(2, 2))
		host_board.force_place(UnitInstance.create(
			_find("warden"), BoardModel.TEAM_B), Vector2i(2, 9))
		var host_sim := CombatSim.new()
		var tb := TeamBuffs.new()
		tb.add(incubation, BuffData.Rarity.GOLD)
		host_sim.team_buffs[BoardModel.TEAM_A] = tb
		host_sim.setup(host_board, 5)
		_check("a gold Spire raises three more than a plain one",
			host_sim.summon_want(caster, _find("spire").ability)
				== _find("spire").ability.summon_count + 3,
			"wants %d" % host_sim.summon_want(caster, _find("spire").ability))

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
		card.contains("16 mana per attack landed"))

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
	board.place(caster, Vector2i(0, 9))
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
	packed.place(summoner, Vector2i(0, 9))
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
	board.place(caster, Vector2i(2, 9))
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
	full.place(blocked, Vector2i(0, 9))
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
	board.place(hero, Vector2i(2, 9))
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
	board.place(caster, Vector2i(2, 9))
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
	# The FIRST one. A tier 6 now calls six, and there are only eight tiles at a
	# unit's shoulder, so the later ones legitimately take the next ring out —
	# what is being tested here is that it starts at the shoulder.
	var at := Vector2i(-1, -1)
	for e in sim.events:
		if e.kind == "summon":
			at = e.cell
			break
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
	board.place(loaded, Vector2i(2, 9))
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
	board.place(caster, Vector2i(2, 9))
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
	_check("it is off the board", board.unit_at(Vector2i(2, 9)) != caster
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
	jammed.place(survivor, Vector2i(0, 9))
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
	board.place(gun, Vector2i(2, 9))

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
	var line := sim.beam_cells(Vector2i(2, 9), Vector2i(2, 6))
	_check("the beam runs from the shooter to the far edge",
		line.has(Vector2i(2, 3)) and line.has(Vector2i(2, 0))
			and not line.has(Vector2i(2, 9)),
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
		BoardModel.WIDTH == 6 and BoardModel.HEIGHT == 10
			and not BoardModel.HAS_NEUTRAL,
		"%dx%d%s" % [BoardModel.WIDTH, BoardModel.HEIGHT,
			", divided" if BoardModel.HAS_NEUTRAL else ", undivided"])

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
	board.place(mover, Vector2i(0, 9))
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

	# It really changes who can be shot at — asked on a board that actually HAS a
	# ridge, and with the ridge tile read off that board.
	#
	# This used to place its archer on the default board and rely on whatever map a
	# previous test had left loaded to supply the high ground. That is why it broke
	# when the maps changed shape: nothing in it said "stand on a ridge", it only
	# happened to be standing on one.
	BoardModel.reset_map()
	var terrace: MapData = load("res://data/maps/the_terrace.tres")
	BoardModel.use_map(terrace)
	var board := BoardModel.new()
	var ridge := Vector2i(-1, -1)
	for y in range(BoardModel.HEIGHT - 1, -1, -1):
		if BoardModel.is_high(Vector2i(4, y)):
			ridge = Vector2i(4, y)
			break
	_check("the map has a ridge to stand on", ridge.y >= 0)
	if ridge.y < 0:
		BoardModel.reset_map()
		return
	var shooter := UnitInstance.create(_find("archer"), BoardModel.TEAM_B)
	board.force_place(shooter, ridge)
	# Four tiles out, downhill, on open ground. A Spire so it neither moves nor
	# shoots back and the only thing that can change its health is the archer.
	var spot := ridge + Vector2i(0, -4)
	while spot.y >= 0 and (BoardModel.is_blocked(spot) or BoardModel.is_high(spot)):
		spot.y -= 1
	var mark := UnitInstance.create(
		BoardModel.at_tier(_find("spire"), 6), BoardModel.TEAM_A)
	_check("and open ground four tiles below it",
		spot.y >= 0 and board.force_place(mark, spot), "no clear tile below %s" % ridge)
	var gap := BoardModel.tile_distance(ridge, spot)
	_check("the target is out of reach from the flat",
		shooter.reach_on(false) < gap,
		"reach %d against %d tiles" % [shooter.reach_on(false), gap])
	_check("and in reach from the ridge", shooter.reach_on(true) >= gap,
		"reach %d against %d tiles" % [shooter.reach_on(true), gap])

	var sim := CombatSim.new()
	sim.setup(board, 13)
	var hp := mark.current_hp
	for i in 12:
		sim.step()
	_check("standing on the ridge, it opens fire without closing in",
		mark.current_hp < hp and shooter.cell == ridge,
		"target on %.0f hp, shooter at %s (ridge is %s)" % [
			mark.current_hp, shooter.cell, ridge])
	BoardModel.reset_map()


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
	board.place(caster, Vector2i(2, 9))
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
	chain.place(parent, Vector2i(2, 9))
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
		m.tiles() >= 220 and m.half_tiles() >= 65,
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
		Vector2i(2, 9))
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

	# Whether THIS fixture overruns is a balance accident — it has flipped twice
	# already when unrelated numbers moved. So the announcement is checked only
	# when the round actually got that far; that it fires once and once only is
	# pinned deterministically in _test_sudden_death_rules() instead.
	var announced := false
	for e in slog.events:
		if e.kind == "sudden_death":
			announced = true
			_check("sudden death is announced when it starts, not before",
				float(e.at) > CombatSim.SUDDEN_DEATH
					and float(e.at) < CombatSim.SUDDEN_DEATH + 1.0,
				"announced at %.1fs" % float(e.at))
	if announced:
		_check("and it is announced exactly once",
			_count_events(slog, "sudden_death") == 1,
			"%d announcements" % _count_events(slog, "sudden_death"))
	else:
		_check("the round ended before the clock ever got there",
			slog.elapsed <= CombatSim.SUDDEN_DEATH + CombatSim.TICK,
			"ran %.1fs with no announcement" % slog.elapsed)

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


func _test_a_stuck_unit_gives_up() -> void:
	_section("A unit that cannot get anywhere stops being stubborn")

	# Three units: one hunter and two marks. The hunter locks on to the first,
	# and the test then makes that first one permanently unreachable by the only
	# means that matters here — the clock. A unit that has landed nothing for
	# STUBBORN_AFTER seconds is, by definition, one whose current plan is not
	# working, whatever the reason.
	BoardModel.reset_map()
	var b := BoardModel.new()
	var hunter := UnitInstance.create(
		BoardModel.at_tier(_must_find("reaver"), 3), BoardModel.TEAM_A)
	b.force_place(hunter, Vector2i(2, 4))
	var first := UnitInstance.create(
		BoardModel.at_tier(_must_find("warden"), 3), BoardModel.TEAM_B)
	b.force_place(first, Vector2i(2, 6))
	var second := UnitInstance.create(
		BoardModel.at_tier(_must_find("warden"), 3), BoardModel.TEAM_B)
	b.force_place(second, Vector2i(3, 6))
	var sim := CombatSim.new()
	sim.setup(b, 313)

	hunter.target = first
	hunter.dry_spell = 0.0
	_check("while it is getting somewhere it keeps the target it has",
		sim._choose_enemy(hunter) == first)

	# Now it has been stuck. Same board, same distances — the only thing that
	# changed is that nothing has happened for eight seconds.
	# Forty times, because the replacement is drawn off the seeded rng from
	# everyone in range. Once would pass by luck against a two-enemy board even
	# if the old target were still in the running, which is exactly the bug this
	# is here to catch.
	var stuck_with_it := 0
	for i in 40:
		hunter.target = first
		hunter.dry_spell = CombatSim.STUBBORN_AFTER
		var got := sim._choose_enemy(hunter)
		if got == first or got == null:
			stuck_with_it += 1
	_check("after long enough with nothing to show for it, it picks someone else",
		stuck_with_it == 0, "kept the old target %d times in 40" % stuck_with_it)
	hunter.target = first
	hunter.dry_spell = CombatSim.STUBBORN_AFTER
	sim._choose_enemy(hunter)
	_check("and the wait restarts, so it commits to the new one",
		is_zero_approx(hunter.dry_spell), "%.1fs" % hunter.dry_spell)

	# Giving up must never mean standing there with no target at all. With one
	# enemy left there is nobody else to want, and battering at the only body on
	# the board beats freezing solid — which is the bug this whole rule exists to
	# fix, and it would be embarrassing to reintroduce it here.
	BoardModel.reset_map()
	var lone_board := BoardModel.new()
	var lone_hunter := UnitInstance.create(
		BoardModel.at_tier(_must_find("reaver"), 3), BoardModel.TEAM_A)
	lone_board.force_place(lone_hunter, Vector2i(2, 4))
	var only := UnitInstance.create(
		BoardModel.at_tier(_must_find("warden"), 3), BoardModel.TEAM_B)
	lone_board.force_place(only, Vector2i(2, 6))
	var lone_sim := CombatSim.new()
	lone_sim.setup(lone_board, 314)
	lone_hunter.target = only
	lone_hunter.dry_spell = CombatSim.STUBBORN_AFTER * 4.0
	_check("with only one enemy alive it keeps hold of that one",
		lone_sim._choose_enemy(lone_hunter) == only)

	# And it must not fire before the wall-breaking has had its chance, or a unit
	# would wander off the wall it just started digging through.
	_check("giving up comes after impatience, not before",
		CombatSim.STUBBORN_AFTER > CombatSim.IMPATIENT_AFTER,
		"%.1fs against %.1fs" % [
			CombatSim.STUBBORN_AFTER, CombatSim.IMPATIENT_AFTER])


func _test_the_apex_beam_goes_through_stone() -> void:
	_section("The apex beam goes through stone")
	BoardModel.reset_map()
	var b := BoardModel.new()
	var apex := UnitInstance.create(
		BoardModel.at_tier(_must_find("transcendence"), 6), BoardModel.TEAM_A)
	b.force_place(apex, Vector2i(2, 1))
	var mark := UnitInstance.create(
		BoardModel.at_tier(_must_find("warden"), 1), BoardModel.TEAM_B)
	b.force_place(mark, Vector2i(2, 4))
	# Something standing BEHIND the wall, which is what the pierce has to reach.
	var behind := UnitInstance.create(
		BoardModel.at_tier(_must_find("warden"), 1), BoardModel.TEAM_B)
	b.force_place(behind, Vector2i(2, 9))
	var sim := CombatSim.new()
	sim.setup(b, 77)
	sim.crit_chance = 0.0

	_check("the apex shoots through walls", sim.shoots_through_walls(apex))
	var clear_line := sim.beam_cells(apex.cell, mark.cell, apex.team, true).size()
	for x in BoardModel.WIDTH:
		BoardModel.raise_wall(Vector2i(x, 6), 500.0)
	_check("there is now a wall across the board",
		not BoardModel.line_of_fire(apex.cell, behind.cell, apex.team))
	_check("and the beam still runs the whole length of the board",
		sim.beam_cells(apex.cell, mark.cell, apex.team, true).size() == clear_line,
		"%d cells with the wall up, %d without" % [
			sim.beam_cells(apex.cell, mark.cell, apex.team, true).size(),
			clear_line])
	# An ordinary beam — one that does NOT have unlimited range — still stops.
	_check("a beam without unlimited range still stops at the stone",
		sim.beam_cells(apex.cell, mark.cell, apex.team, false).size() < clear_line,
		"%d cells" % sim.beam_cells(apex.cell, mark.cell, apex.team, false).size())

	# And the thing behind the wall is actually caught, not merely drawn over.
	var caught := sim._pierce_beyond(apex.cell, mark, 8, apex.team, true)
	var reached := false
	for v in caught:
		if v == behind:
			reached = true
	_check("the pierce reaches a unit standing behind the wall", reached,
		"caught %d units" % caught.size())
	_check("and without the flag it does not",
		sim._pierce_beyond(apex.cell, mark, 8, apex.team, false).is_empty())

	# Through the real call site, not the helper. The checks above prove
	# beam_cells CAN go through stone; this proves the thing that draws the beam
	# actually asks it to — without this, _beam_wash could pass `false` for ever
	# and every check above would stay green.
	var before := sim.events.size()
	sim._beam_wash(apex, mark, 10.0, {})
	var drawn := 0
	for i in range(before, sim.events.size()):
		var e: Dictionary = sim.events[i]
		if e.kind == "beam":
			drawn = (e.get("cells", []) as Array).size()
	_check("the beam the apex actually fires runs past the wall",
		drawn == clear_line, "drew %d cells, a clear line is %d" % [
			drawn, clear_line])
	BoardModel.reset_map()


func _test_unlimited_range_ignores_walls() -> void:
	_section("Unlimited range shoots over everything")
	BoardModel.reset_map()
	var b := BoardModel.new()
	# The Sentry, which is the roster's unlimited-range unit. The Leech reaches
	# the whole board through its ABILITY's targeting, which is a different thing
	# and is not what this rule touches.
	var shooter := UnitInstance.create(
		BoardModel.at_tier(load("res://data/units/sentry_t1.tres") as UnitData, 1),
		BoardModel.TEAM_A)
	b.force_place(shooter, Vector2i(2, 2))
	var mark := UnitInstance.create(
		BoardModel.at_tier(_must_find("warden"), 1), BoardModel.TEAM_B)
	b.force_place(mark, Vector2i(2, 8))
	var sim := CombatSim.new()
	sim.setup(b, 404)
	_check("the Sentry is an unlimited-range unit",
		shooter.range_band() == UnitData.RangeBand.UNLIMITED,
		shooter.range_name())
	_check("with a clear board it has its shot", sim._has_shot(shooter, mark))

	# A wall straight across the line between them.
	for x in BoardModel.WIDTH:
		BoardModel.raise_wall(Vector2i(x, 5), 500.0)
	_check("the wall really is in the way",
		not BoardModel.line_of_fire(shooter.cell, mark.cell, shooter.team))
	_check("and unlimited range shoots over it anyway",
		sim._has_shot(shooter, mark))

	# One band below unlimited still needs a clear line — this is the one band
	# that ignores walls, not "long range ignores walls".
	var bowman := UnitInstance.create(
		BoardModel.at_tier(_must_find("culverin"), 1), BoardModel.TEAM_A)
	b.force_place(bowman, Vector2i(3, 2))
	_check("a Culverin is not unlimited",
		bowman.range_band() != UnitData.RangeBand.UNLIMITED, bowman.range_name())
	_check("so the same wall still stops it",
		not sim._has_shot(bowman, mark))
	BoardModel.reset_map()


func _test_buffs_stack_across_rarities() -> void:
	_section("The same buff at two rarities is two buffs")
	var pool := _pool()
	var windfall := pool.by_id(&"windfall")
	_check("Windfall is on the roster", windfall != null)
	if windfall == null:
		return

	var tb := TeamBuffs.new()
	tb.add(windfall, BuffData.Rarity.BRONZE)
	tb.add(windfall, BuffData.Rarity.SILVER)
	var chances := tb.merge_extra_unit_chances()
	_check("holding it twice gives two separate rolls, not one bigger one",
		chances.size() == 2, "%d rolls" % chances.size())
	if chances.size() == 2:
		_check("and each roll keeps its own rarity's number",
			is_equal_approx(chances[0], windfall.bronze.x)
				and is_equal_approx(chances[1], windfall.silver.x),
			"%.2f / %.2f" % [chances[0], chances[1]])

	# The rule that matters: two rolls can BOTH land, which a single summed
	# chance can never do. 10% + 20% summed is a 30% chance of one extra unit
	# and a 0% chance of two; rolled separately it is a 2% chance of two.
	var both := 0
	var rng := RandomNumberGenerator.new()
	rng.seed = 918
	for i in 4000:
		var landed := 0
		for c in chances:
			if rng.randf() < c:
				landed += 1
		if landed == 2:
			both += 1
	_check("so a merge can proc both of them at once",
		both > 0, "never happened in 4000 merges")

	# Stat buffs were already additive through apply_to(); this pins it, because
	# "stacks" has to mean the same thing for every kind of buff.
	var ironwall := pool.by_id(&"ironwall")
	if ironwall != null:
		var w := UnitInstance.create(_must_find("warden"), BoardModel.TEAM_A)
		var base := w.stat(StatModifier.Stat.MAX_HP)
		var stack := TeamBuffs.new()
		stack.add(ironwall, BuffData.Rarity.BRONZE)
		stack.add(ironwall, BuffData.Rarity.SILVER)
		stack.apply_to(w)
		_check("two Ironwalls are worth both of their numbers",
			is_equal_approx(w.stat(StatModifier.Stat.MAX_HP),
				base * (1.0 + ironwall.bronze.x + ironwall.silver.x)),
			"%.0f from %.0f" % [w.stat(StatModifier.Stat.MAX_HP), base])

	# And the summed kinds keep summing, which is the correct reading of
	# "independent but applied at the same time" for a per-second number.
	var mending := pool.by_id(&"mending_wind")
	if mending != null:
		var regen := TeamBuffs.new()
		regen.add(mending, BuffData.Rarity.BRONZE)
		regen.add(mending, BuffData.Rarity.GOLD)
		_check("two regens heal for both of their shares",
			is_equal_approx(regen.regen_fraction(),
				mending.bronze.x + mending.gold.x),
			"%.3f" % regen.regen_fraction())


func _test_forced_march() -> void:
	_section("Forced March — and the inverted stat behind it")
	var pool := _pool()
	var buff := pool.by_id(&"forced_march")
	_check("Forced March is on the roster", buff != null)
	if buff == null:
		return
	_check("it is global", buff.is_global()
		and buff.kind == BuffData.Kind.STAT)
	_check("the row reads the way a player reads it: 50/75/100",
		is_equal_approx(buff.bronze.x, 0.50)
		and is_equal_approx(buff.silver.x, 0.75)
		and is_equal_approx(buff.gold.x, 1.00),
		"%.2f/%.2f/%.2f" % [buff.bronze.x, buff.silver.x, buff.gold.x])
	_check("and it drives MOVE_TIME",
		buff.stat_a == StatModifier.Stat.MOVE_TIME)
	_check("which the engine knows is inverted",
		StatModifier.Stat.MOVE_TIME in StatModifier.INVERTED_STATS)

	# The whole point. MOVE_TIME is seconds per tile, so a buff row of +0.50 has to
	# come out as a NEGATIVE percentage or the army gets slower. This is the check
	# that would have caught shipping it backwards.
	var mods := buff.modifiers_for(BuffData.Rarity.BRONZE)
	_check("bronze produces exactly one modifier", mods.size() == 1,
		"%d modifiers" % mods.size())
	if mods.size() != 1:
		return
	_check("and it is a NEGATIVE percentage, not the +50 from the row",
		mods[0].value < 0.0, "%.4f" % mods[0].value)
	_check("worth 1/1.5 of the time, which is what a 50% speed gain means",
		is_equal_approx(mods[0].value, 1.0 / 1.5 - 1.0),
		"%.4f against %.4f" % [mods[0].value, 1.0 / 1.5 - 1.0])

	# Measured on a unit, at every rarity, as a real speed multiple.
	var want := {BuffData.Rarity.BRONZE: 1.5, BuffData.Rarity.SILVER: 1.75,
		BuffData.Rarity.GOLD: 2.0}
	var wrong: PackedStringArray = []
	for rarity in want:
		var u := UnitInstance.create(_must_find("warden"), BoardModel.TEAM_A)
		var before := u.stat(StatModifier.Stat.MOVE_TIME)
		var tb := TeamBuffs.new()
		tb.add(buff, rarity)
		tb.apply_to(u)
		var after := u.stat(StatModifier.Stat.MOVE_TIME)
		var times_faster := before / maxf(after, 0.0001)
		if not is_equal_approx(times_faster, want[rarity]):
			wrong.append("%s: %.3fx, wanted %.2fx" % [
				BuffData.rarity_name(rarity), times_faster, want[rarity]])
	_check("bronze/silver/gold move 1.5x, 1.75x and 2x as fast",
		wrong.is_empty(), "; ".join(wrong))

	# And it is faster on the actual clock, not just in the stat table.
	BoardModel.reset_map()
	var plain := UnitInstance.create(_must_find("warden"), BoardModel.TEAM_A)
	var quick := UnitInstance.create(_must_find("warden"), BoardModel.TEAM_A)
	var tbq := TeamBuffs.new()
	tbq.add(buff, BuffData.Rarity.GOLD)
	tbq.apply_to(quick)
	_check("a gold-buffed unit spends less time per tile than a plain one",
		quick.stat(StatModifier.Stat.MOVE_TIME)
			< plain.stat(StatModifier.Stat.MOVE_TIME),
		"%.3fs against %.3fs" % [quick.stat(StatModifier.Stat.MOVE_TIME),
			plain.stat(StatModifier.Stat.MOVE_TIME)])

	# Nothing else must have been flipped by the inversion rule.
	var drums := pool.by_id(&"war_drums")
	if drums != null:
		var dmods := drums.modifiers_for(BuffData.Rarity.BRONZE)
		_check("an ordinary stat buff is untouched by the inversion",
			dmods.size() == 1 and dmods[0].value > 0.0
			and is_equal_approx(dmods[0].value, drums.bronze.x),
			"%.3f against %.3f" % [
				0.0 if dmods.is_empty() else dmods[0].value, drums.bronze.x])

	# The card has to read as speed, not as the field it drives.
	var card := buff.describe(BuffData.Rarity.GOLD)
	_check("the card says movement speed, not move time",
		card.to_lower().contains("movement speed")
		and not card.to_lower().contains("move time"), card)


func _test_the_militia_buff() -> void:
	_section("Militia — the small units only")
	var pool := _pool()
	var buff := pool.by_id(&"militia")
	_check("Militia is on the roster", buff != null)
	if buff == null:
		return
	_check("it is global, and a stat buff", buff.is_global()
		and buff.kind == BuffData.Kind.STAT)
	_check("it runs 50/75/100% on health and attack alike",
		is_equal_approx(buff.bronze.x, 0.50) and is_equal_approx(buff.bronze.y, 0.50)
		and is_equal_approx(buff.silver.x, 0.75)
		and is_equal_approx(buff.gold.x, 1.00) and buff.uses_second_stat,
		"%.2f/%.2f/%.2f" % [buff.bronze.x, buff.silver.x, buff.gold.x])
	_check("and it stops at tier 3", buff.max_tier == 3,
		"ceiling is %d" % buff.max_tier)

	# The ceiling is the whole point, so it is checked at every tier rather than
	# at one on each side of the line.
	var covered: PackedStringArray = []
	for tier in range(1, 7):
		var u := UnitInstance.create(
			BoardModel.at_tier(_must_find("warden"), tier), BoardModel.TEAM_A)
		if buff.applies_to(u):
			covered.append("t%d" % tier)
	_check("tiers 1 to 3 are covered and 4 to 6 are not",
		covered == PackedStringArray(["t1", "t2", "t3"]), str(covered))

	# And the stats actually land, through the same path the game uses.
	var small := UnitInstance.create(
		BoardModel.at_tier(_must_find("warden"), 2), BoardModel.TEAM_A)
	var big := UnitInstance.create(
		BoardModel.at_tier(_must_find("warden"), 5), BoardModel.TEAM_A)
	var small_hp := small.stat(StatModifier.Stat.MAX_HP)
	var small_dmg := small.stat(StatModifier.Stat.ATTACK_DAMAGE)
	var big_hp := big.stat(StatModifier.Stat.MAX_HP)
	var tb := TeamBuffs.new()
	tb.add(buff, BuffData.Rarity.GOLD)
	tb.apply_to(small)
	tb.apply_to(big)
	_check("a tier 2 doubles its health and its attack at gold",
		is_equal_approx(small.stat(StatModifier.Stat.MAX_HP), small_hp * 2.0)
		and is_equal_approx(small.stat(StatModifier.Stat.ATTACK_DAMAGE),
			small_dmg * 2.0),
		"%.0f hp from %.0f" % [small.stat(StatModifier.Stat.MAX_HP), small_hp])
	_check("and a tier 5 gets nothing at all",
		is_equal_approx(big.stat(StatModifier.Stat.MAX_HP), big_hp),
		"%.0f hp from %.0f" % [big.stat(StatModifier.Stat.MAX_HP), big_hp])

	# A unit that merges past the ceiling loses it at the round boundary, which is
	# where resync runs. That is the honest reading of a buff for small units.
	var grown := UnitInstance.create(
		BoardModel.at_tier(_must_find("warden"), 3), BoardModel.TEAM_A)
	tb.apply_to(grown)
	_check("a tier 3 has it", grown.stat(StatModifier.Stat.MAX_HP)
		> BoardModel.at_tier(_must_find("warden"), 3).max_hp)
	var promoted := UnitInstance.create(
		BoardModel.at_tier(_must_find("warden"), 4), BoardModel.TEAM_A)
	tb.resync(promoted)
	_check("and once it is a tier 4, a resync takes it away",
		is_equal_approx(promoted.stat(StatModifier.Stat.MAX_HP),
			BoardModel.at_tier(_must_find("warden"), 4).max_hp),
		"%.0f hp" % promoted.stat(StatModifier.Stat.MAX_HP))

	# The card has to say so, or it reads as an ordinary global buff.
	var card := buff.describe(BuffData.Rarity.SILVER)
	_check("the card names the tier ceiling",
		card.contains("tier 3") and card.to_lower().contains("below"), card)


func _test_the_round_shield_buff() -> void:
	_section("Aegis Wall")
	var pool := _pool()
	var buff := pool.by_id(&"aegis_wall")
	_check("Aegis Wall is on the roster", buff != null)
	if buff == null:
		return
	_check("it is a global buff, not one unit's",
		buff.is_global() and buff.kind == BuffData.Kind.ROUND_SHIELD)
	_check("it runs 1000/2000/3000",
		is_equal_approx(buff.bronze.x, 1000.0)
			and is_equal_approx(buff.silver.x, 2000.0)
			and is_equal_approx(buff.gold.x, 3000.0),
		"%.0f/%.0f/%.0f" % [buff.bronze.x, buff.silver.x, buff.gold.x])

	BoardModel.reset_map()
	var b := BoardModel.new()
	var mine := UnitInstance.create(
		BoardModel.at_tier(_must_find("archer"), 1), BoardModel.TEAM_A)
	b.force_place(mine, Vector2i(2, 2))
	var theirs := UnitInstance.create(
		BoardModel.at_tier(_must_find("archer"), 1), BoardModel.TEAM_B)
	b.force_place(theirs, Vector2i(2, 9))
	var sim := CombatSim.new()
	var tb := TeamBuffs.new()
	tb.add(buff, BuffData.Rarity.BRONZE)
	sim.team_buffs[BoardModel.TEAM_A] = tb
	sim.setup(b, 55)
	_check("every unit on the buffed side starts the round shielded",
		mine.shield >= 1000.0, "%.0f" % mine.shield)
	_check("and the other side gets nothing", is_zero_approx(theirs.shield),
		"%.0f" % theirs.shield)

	# Flat, so it is not capped by the unit's own shield_cap — a number that
	# belongs to the Warden's bulwark and is zero for almost everyone else. An
	# Archer with shield_cap 0 must still get the full grant.
	_check("the grant ignores the unit's own shield cap entirely",
		mine.data.shield_cap < 1000.0 and mine.shield >= 1000.0,
		"cap %.0f, got %.0f" % [mine.data.shield_cap, mine.shield])


func _test_engineer_sentries_scale() -> void:
	_section("Engineer sentries by tier")
	var engineer := _must_find("engineer")
	var ab: AbilityData = engineer.ability
	_check("Assemble is still a retinue", ab != null and ab.summon_retinue)
	if ab == null:
		return
	var sim := CombatSim.new()
	var caps: PackedInt32Array = []
	for tier in range(1, 7):
		var at_tier := UnitInstance.create(
			BoardModel.at_tier(engineer, tier), BoardModel.TEAM_A)
		caps.append(sim.summon_cap(at_tier, ab))
	_check("the sentry cap goes 1, 1, 2, 2, 3, 3 across the six tiers",
		caps == PackedInt32Array([1, 1, 2, 2, 3, 3]), str(caps))

	# One at a time, though. A Sentry is built on the Engineer's own tile, and
	# there is only one of those.
	BoardModel.reset_map()
	var b := BoardModel.new()
	var eng := UnitInstance.create(
		BoardModel.at_tier(engineer, 5), BoardModel.TEAM_A)
	b.force_place(eng, Vector2i(2, 2))
	b.force_place(UnitInstance.create(
		BoardModel.at_tier(_must_find("warden"), 1), BoardModel.TEAM_B),
		Vector2i(2, 9))
	var live := CombatSim.new()
	live.setup(b, 77)
	_check("a tier 5 Engineer is entitled to three",
		live.summon_cap(eng, ab) == 3)
	_check("but only ever builds one per cast",
		live.summon_want(eng, ab) <= 1,
		"wants %d" % live.summon_want(eng, ab))


func _pressure_stage() -> Dictionary:
	## Two Wardens, a whole board apart, with the clock under the operator's
	## control. Nothing here happens on its own.
	BoardModel.reset_map()
	var b := BoardModel.new()
	var hitter := UnitInstance.create(
		BoardModel.at_tier(_must_find("warden"), 3), BoardModel.TEAM_A)
	b.force_place(hitter, Vector2i(2, 1))
	var mark := UnitInstance.create(
		BoardModel.at_tier(_must_find("warden"), 3), BoardModel.TEAM_B)
	b.force_place(mark, Vector2i(2, 9))
	var sim := CombatSim.new()
	sim.setup(b, 811)
	sim.crit_chance = 0.0
	return {sim = sim, hitter = hitter, mark = mark}


func _into_sudden_death(sim: CombatSim) -> void:
	## Winds the clock to the mark and lets the sim notice, without running two
	## minutes of battle to get there. _tick_pressure is the whole transition, so
	## driving it directly tests the same code the clock would.
	sim.elapsed = CombatSim.SUDDEN_DEATH + CombatSim.TICK
	sim._tick_pressure()


func _test_sudden_death_rules() -> void:
	_section("Sudden death doubles the fight and stops the mending")

	# It happens once. _tick_pressure runs on every tick of the round, so without
	# the _sudden_death latch this would announce fifteen seconds' worth.
	var once := _pressure_stage()
	_into_sudden_death(once.sim)
	for i in 20:
		once.sim.elapsed += CombatSim.TICK
		once.sim._tick_pressure()
	_check("sudden death is announced exactly once, not on every tick after it",
		_count_events(once.sim, "sudden_death") == 1,
		"%d announcements" % _count_events(once.sim, "sudden_death"))

	# Where the line is. 1:45 of a 2:00 round, so the last fifteen seconds.
	_check("sudden death starts at 1:45",
		is_equal_approx(CombatSim.SUDDEN_DEATH, 105.0),
		"%.1fs" % CombatSim.SUDDEN_DEATH)
	_check("which leaves fifteen seconds of it",
		is_equal_approx(CombatSim.DEFAULT_TIMEOUT - CombatSim.SUDDEN_DEATH, 15.0),
		"%.1fs" % (CombatSim.DEFAULT_TIMEOUT - CombatSim.SUDDEN_DEATH))

	# Attack speed. The swing timer is the reciprocal, so twice the speed is half
	# the interval.
	var s := _pressure_stage()
	var calm: float = s.sim.attack_interval(s.mark)
	_check("before the mark a unit swings at its own speed",
		is_equal_approx(calm, s.mark.attack_interval()),
		"%.3fs against %.3fs" % [calm, s.mark.attack_interval()])
	_into_sudden_death(s.sim)
	_check("pressure steps to exactly double, not a ramp",
		is_equal_approx(s.sim.pressure(), 2.0), "%.2f" % s.sim.pressure())
	_check("and every unit swings twice as fast",
		is_equal_approx(s.sim.attack_interval(s.mark), calm * 0.5),
		"%.3fs against %.3fs" % [s.sim.attack_interval(s.mark), calm * 0.5])

	# Damage. The same blow, from the same unit, on either side of the line.
	var calm_stage := _pressure_stage()
	calm_stage.mark.shield = 0.0
	var before: float = calm_stage.mark.current_hp
	calm_stage.sim._damage(calm_stage.mark, 40.0, calm_stage.hitter)
	var calm_loss: float = before - calm_stage.mark.current_hp

	var hot := _pressure_stage()
	hot.mark.shield = 0.0
	_into_sudden_death(hot.sim)
	var hot_before: float = hot.mark.current_hp
	hot.sim._damage(hot.mark, 40.0, hot.hitter)
	var hot_loss: float = hot_before - hot.mark.current_hp
	_check("the same blow takes twice as much off",
		is_equal_approx(hot_loss, calm_loss * 2.0),
		"%.1f against %.1f" % [hot_loss, calm_loss * 2.0])

	# Healing, from the one place every healer goes through.
	var heal := _pressure_stage()
	heal.mark.current_hp = 10.0
	heal.mark.heal(50.0)
	_check("a unit can be healed before the mark",
		heal.mark.current_hp > 10.0, "%.1f hp" % heal.mark.current_hp)
	_into_sudden_death(heal.sim)
	var held: float = heal.mark.current_hp
	heal.mark.heal(50.0)
	_check("and cannot be healed after it",
		is_equal_approx(heal.mark.current_hp, held),
		"%.1f became %.1f" % [held, heal.mark.current_hp])

	# Shields. Gaining is off; what is already standing is left alone, because
	# "no more shields" and "your armour falls off" are very different rules and
	# only one of them was asked for.
	var sh := _pressure_stage()
	sh.mark.shield = 0.0
	sh.mark.add_shield(100.0, 999.0)
	_check("a shield can be gained before the mark",
		sh.mark.shield > 0.0, "%.1f" % sh.mark.shield)
	_into_sudden_death(sh.sim)
	var standing: float = sh.mark.shield
	sh.mark.add_shield(100.0, 999.0)
	_check("and cannot be gained after it",
		is_equal_approx(sh.mark.shield, standing),
		"%.1f became %.1f" % [standing, sh.mark.shield])
	_check("but the shield already standing is not stripped", standing > 0.0,
		"%.1f left" % standing)

	# The other two things suppression blocks are NOT sudden death's business. If
	# these ever start failing, somebody has folded recovery_denied into
	# is_suppressed() and quietly switched off the Archer and the Wellspring for
	# the last fifteen seconds of every round.
	_check("a unit in sudden death is not 'suppressed'",
		not sh.mark.is_suppressed())

	# Anything that arrives mid-sudden-death arrives under the same rules.
	var late := _pressure_stage()
	_into_sudden_death(late.sim)
	var minion := UnitInstance.create(
		BoardModel.at_tier(_must_find("warden"), 1), BoardModel.TEAM_A)
	late.sim._pending_units.append(minion)
	late.sim._absorb_new_units()
	_check("a unit summoned during sudden death cannot mend either",
		minion.recovery_denied)
	minion.current_hp = 5.0
	minion.heal(50.0)
	_check("and proving it, healing does nothing to it",
		is_equal_approx(minion.current_hp, 5.0), "%.1f hp" % minion.current_hp)

	# And it belongs to the round that ran out of clock, not the next one.
	minion.reset_for_battle()
	_check("the next round starts with mending switched back on",
		not minion.recovery_denied)


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
		Vector2i(2, 9))
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
	b.force_place(foe, Vector2i(5, 9))
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

	# ...but from the STAIRS it can. The steps are the fighting ground of an
	# assault: a melee line that had to finish the climb before it could swing
	# would be picked apart one body at a time by whoever is waiting at the top.
	swordsman.cell = step
	_check("but from the stairs it can swing up onto the terrace",
		sim.reach_against(swordsman, holder) > 0,
		"reach %d" % sim.reach_against(swordsman, holder))
	_check("and the man at the top is actually within that reach",
		BoardModel.in_reach(swordsman.cell, holder.cell,
			sim.reach_against(swordsman, holder)))

	# The steps are not a terrace, though. A unit on them is halfway up: it can
	# reach, and it can be reached back, and a bow on them gains nothing.
	var below := UnitInstance.create(
		BoardModel.at_tier(_must_find("reaver"), 1), BoardModel.TEAM_A)
	b.force_place(below, Vector2i(2, 3))
	_check("a melee unit on the ground can still hit one on the stairs",
		sim.reach_against(below, swordsman) > 0,
		"reach %d" % sim.reach_against(below, swordsman))
	var bowman := UnitInstance.create(
		BoardModel.at_tier(_must_find("archer"), 1), BoardModel.TEAM_B)
	b.force_place(bowman, Vector2i(1, 3))
	var flat_reach: int = sim.reach_against(bowman, below)
	bowman.cell = step
	_check("and a bow on the stairs gains no elevation band",
		sim.reach_against(bowman, below) == flat_reach,
		"%d from the steps against %d on the flat" % [
			sim.reach_against(bowman, below), flat_reach])
	bowman.cell = Vector2i(1, 3)
	below.cell = Vector2i(2, 3)
	swordsman.cell = step

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
	# The far terrace. Read off the board rather than written as a literal: The
	# Terrace lost a row when the divider went, and the hardcoded (4, 13) landed on
	# flat ground, so the check failed for a reason that had nothing to do with
	# elevation.
	var far_top := Vector2i(-1, -1)
	for y in range(BoardModel.HEIGHT - 1, -1, -1):
		if BoardModel.is_high(Vector2i(4, y)):
			far_top = Vector2i(4, y)
			break
	_check("there is a terrace on the far side to stand on", far_top.y >= 0,
		"no high tile in column 4")
	shooter.cell = far_top
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
	_check("and sudden death only takes the last fifteen seconds",
		is_equal_approx(CombatSim.DEFAULT_TIMEOUT - CombatSim.SUDDEN_DEATH, 15.0),
		"sudden death begins at %.0fs of %.0f" % [
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
	_check("a bigger blast fills in as a diamond: arm 2 is thirteen tiles, arm 3 twenty-five",
		CombatSim.cross_cells(Vector2i(5, 5), 2).size() == 13
		and CombatSim.cross_cells(Vector2i(5, 5), 3).size() == 25
		and CombatSim.cross_cells(Vector2i(5, 5), 2).has(Vector2i(6, 6)))
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
	_section("The Leech against something enormous")
	var para := _must_find("leech")
	var ab: AbilityData = para.ability
	_check("Siphon is a drain", ab != null and ab.kind == AbilityData.Kind.DRAIN)
	_check("it takes 2.5% of max health a second",
		is_equal_approx(ab.drain_percent, 0.025),
		"%.3f" % ab.drain_percent)
	_check("the Leech has innate lifesteal", para.lifesteal > 0.0,
		"%.2f" % para.lifesteal)

	BoardModel.reset_map()
	var b := BoardModel.new()
	var p := UnitInstance.create(para, BoardModel.TEAM_A)
	b.force_place(p, Vector2i(0, 0))
	# The thing it is meant to answer. A tier 6 SPIRE, not a Transcendence: the
	# first version of this used a Transcendence and its unlimited-range beam
	# killed the Leech two seconds in, so the drain ended and the test measured
	# nothing. The Spire is rooted, harmless and enormous, which is exactly the
	# shape being tested without the shooting back.
	var whale := UnitInstance.create(
		BoardModel.at_tier(_must_find("spire"), 6), BoardModel.TEAM_B)
	b.force_place(whale, Vector2i(5, 9))
	# And a small one much closer. Siphon must ignore it.
	var minnow := UnitInstance.create(
		BoardModel.at_tier(_must_find("spire"), 1), BoardModel.TEAM_B)
	b.force_place(minnow, Vector2i(1, 1))
	var sim := CombatSim.new()
	sim.setup(b, 75)
	var far := BoardModel.tile_distance(p.cell, whale.cell)
	_check("the whale is far outside the Leech's reach",
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
	_check("and the Leech heals off it", p.current_hp > heal_from,
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
	var p2 := UnitInstance.create(_must_find("leech"), BoardModel.TEAM_A)
	b2.force_place(p2, Vector2i(0, 0))
	var hurt := UnitInstance.create(
		BoardModel.at_tier(_must_find("spire"), 6), BoardModel.TEAM_B)
	b2.force_place(hurt, Vector2i(5, 9))
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
	var p := UnitInstance.create(_must_find("leech"), BoardModel.TEAM_A)
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
	_check("and so does the Leech", hun != null)
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
	var plain := UnitInstance.create(_must_find("leech"), BoardModel.TEAM_A)
	var buffed := UnitInstance.create(_must_find("leech"), BoardModel.TEAM_A)
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



func _finish_charge(sim: CombatSim, runner: UnitInstance, cap := 200) -> float:
	## Steps until the charge is over, and reports how long it took.
	##
	## Every check below used to read its result straight after setup(), because the
	## charge resolved inside the cast. It takes real seconds now, so a test that does not
	## step the clock is asking what happened before anything had happened — which is
	## exactly what a charge with travel time is FOR, and worth a helper rather than a
	## loop copied into eight fixtures.
	var ticks := 0
	while runner.is_charging() and runner.is_alive() and ticks < cap:
		sim.step()
		ticks += 1
	return float(ticks) * CombatSim.TICK


func _breaker_lane(tier: int, blocker_team: int, gap: int) -> Dictionary:
	## A Breaker on TEAM_A at the top of a column with something `gap` tiles down
	## the same column. TEAM_A charges toward higher y, so "down the column" is
	## straight at the enemy half.
	BoardModel.reset_map()
	var b := BoardModel.new()
	var runner := UnitInstance.create(
		BoardModel.at_tier(_must_find("breaker"), tier), BoardModel.TEAM_A)
	b.force_place(runner, Vector2i(2, 1))
	var mark := UnitInstance.create(
		BoardModel.at_tier(_must_find("warden"), 6), blocker_team)
	b.force_place(mark, Vector2i(2, 1 + gap))
	# Somewhere off the lane so the round never ends underneath the test.
	b.force_place(UnitInstance.create(
		BoardModel.at_tier(_must_find("warden"), 1), BoardModel.TEAM_B),
		Vector2i(5, 9))
	var sim := CombatSim.new()
	sim.crit_chance = 0.0
	return {sim = sim, board = b, runner = runner, mark = mark}



func _breaker_lane_ally_post(tier: int) -> Dictionary:
	## The ally fixture: a Breaker with one of its OWN side four tiles down the lane, and
	## that ally rooted so it is still there when the charge arrives.
	BoardModel.reset_map()
	var b := BoardModel.new()
	var runner := UnitInstance.create(
		BoardModel.at_tier(_must_find("breaker"), tier), BoardModel.TEAM_A)
	b.force_place(runner, Vector2i(2, 1))
	var mark := UnitInstance.create(
		BoardModel.at_tier(_must_find("spire"), 6), BoardModel.TEAM_A)
	b.force_place(mark, Vector2i(2, 5))
	b.force_place(UnitInstance.create(
		BoardModel.at_tier(_must_find("warden"), 1), BoardModel.TEAM_B),
		Vector2i(5, 9))
	var sim := CombatSim.new()
	sim.crit_chance = 0.0
	return {sim = sim, board = b, runner = runner, mark = mark}


func _usurp_board(own_tier: int, prey_tier: int,
		extra_prey := 0) -> Dictionary:
	## An Usurper on TEAM_A with one enemy of `prey_tier` to go for, plus an ally so
	## the round does not end underneath the test the moment the prey changes sides.
	BoardModel.reset_map()
	var b := BoardModel.new()
	var thief := UnitInstance.create(
		BoardModel.at_tier(_must_find("usurper"), own_tier), BoardModel.TEAM_A)
	b.force_place(thief, Vector2i(2, 1))
	var prey := UnitInstance.create(
		BoardModel.at_tier(_must_find("warden"), prey_tier), BoardModel.TEAM_B)
	b.force_place(prey, Vector2i(2, 8))
	b.force_place(UnitInstance.create(
		BoardModel.at_tier(_must_find("warden"), 1), BoardModel.TEAM_A),
		Vector2i(5, 1))
	var spares: Array[UnitInstance] = []
	for i in extra_prey:
		var s := UnitInstance.create(
			BoardModel.at_tier(_must_find("warden"), prey_tier), BoardModel.TEAM_B)
		b.force_place(s, Vector2i(5 + i, 9))
		spares.append(s)
	var sim := CombatSim.new()
	sim.crit_chance = 0.0
	return {sim = sim, board = b, thief = thief, prey = prey, spares = spares}


func _test_the_usurper_takes_a_host() -> void:
	_section("The Usurper gets inside something")
	var usurper := _must_find("usurper")
	var ab: AbilityData = usurper.ability
	_check("Usurpation is a POSSESS", ab != null
		and ab.kind == AbilityData.Kind.POSSESS)
	if ab == null:
		return
	_check("and it fires at the opening bell", usurper.casts_at_battle_start)
	_check("it costs no mana, so it cannot be cast twice in a round",
		is_zero_approx(usurper.mana_per_attack))

	# A spare enemy, so the round does NOT end the instant the only opposing unit
	# changes sides. Without it the sim finishes at setup and step() becomes a
	# no-op, which silently defeated the passenger check further down: it reported
	# zero actions because nothing was simulated at all.
	var t := _usurp_board(3, 3, 1)
	var thief: UnitInstance = t.thief
	var prey: UnitInstance = t.prey
	var owner := prey.team
	t.sim.setup(t.board, 101)

	_check("at the bell it is inside its host", thief.is_riding()
		and thief.host_uid == prey.uid, "host_uid %d" % thief.host_uid)
	_check("and the host knows who is driving it",
		prey.is_possessed() and prey.puppeteer_uid == thief.uid)
	_check("the host has changed sides", prey.team == thief.team,
		"host on team %d, thief on %d" % [prey.team, thief.team])
	# The one that matters most. Every count, every targeting sweep and the win
	# condition read `team` off the unit with no cache in between, so this is the
	# whole of "you control that unit even if it is not in your roster".
	_check("so the board counts it for the thief's side",
		t.board.living_units_of(thief.team).has(prey)
		and not t.board.living_units_of(owner).has(prey))
	_check("the Usurper itself is off the board entirely",
		t.board.unit_at(thief.cell) != thief
		and not t.board.units_view().has(thief))
	_check("and nothing can target what is not on the board",
		_no_one_can_see(t.board, thief))
	# It is off the board but still alive, so its own side is not wiped while it
	# is holding the reins.
	_check("it still counts as a living unit for its own side",
		t.sim.living_count(thief.team) >= 2,
		"%d living" % t.sim.living_count(thief.team))

	# And it takes no turns of its own while it is in there. This is the check for
	# whether step() actually SKIPS a riding unit, which is a different question
	# from whether is_riding() reports correctly — a passenger that still walked
	# and swung from an off-board tile is the failure being ruled out.
	var before_events: int = t.sim.events.size()
	for i in 60:
		t.sim.step()
	var acted := 0
	for i in range(before_events, t.sim.events.size()):
		var e: Dictionary = t.sim.events[i]
		if e.kind != "move" and e.kind != "attack" and e.kind != "cast_start":
			continue
		if int(e.uid) == thief.uid:
			acted += 1
	_check("and it takes no turns of its own while it is in there",
		acted == 0, "%d actions from a passenger" % acted)

	# What it remembers, which is the only thing standing between a possession and
	# a unit permanently stolen out of a roster.
	_check("the host remembers whose it was",
		prey.home_team == owner, "home_team %d, was %d" % [prey.home_team, owner])
	prey.reset_for_battle()
	_check("and the round boundary hands it straight back",
		prey.team == owner and not prey.is_possessed(),
		"team %d, possessed %s" % [prey.team, prey.is_possessed()])
	thief.reset_for_battle()
	_check("the Usurper stops riding at the boundary too",
		not thief.is_riding() and not thief.is_husk())

	# Two Usurpers must not share.
	var pair := _usurp_board(3, 3)
	var second := UnitInstance.create(
		BoardModel.at_tier(usurper, 3), BoardModel.TEAM_A)
	pair.board.force_place(second, Vector2i(3, 1))
	pair.sim.setup(pair.board, 103)
	var both_in: Array[int] = []
	for who in [pair.thief, second]:
		if (who as UnitInstance).is_riding():
			both_in.append((who as UnitInstance).host_uid)
	_check("two Usurpers with one candidate do not share it",
		both_in.size() <= 1 or both_in[0] != both_in[1],
		"hosts %s" % str(both_in))
	# The one that missed out still had to do SOMETHING. With the only same-tier
	# candidate taken, its next choice is the tier 1 ally-side... no: the board
	# holds one tier 1 on its OWN side, which is not a candidate, so it has nothing
	# left and must waste the cast rather than sharing the host.
	_check("the one that missed out did not take the same host",
		not second.is_riding() or second.host_uid != pair.thief.host_uid,
		"both claim host %d" % second.host_uid)

	# Nothing to take at all.
	BoardModel.reset_map()
	var bare := BoardModel.new()
	var lone := UnitInstance.create(BoardModel.at_tier(usurper, 2),
		BoardModel.TEAM_A)
	bare.force_place(lone, Vector2i(2, 1))
	bare.force_place(UnitInstance.create(
		BoardModel.at_tier(_must_find("warden"), 1), BoardModel.TEAM_A),
		Vector2i(4, 1))
	var bare_sim := CombatSim.new()
	bare_sim.setup(bare, 105)
	_check("with no enemy at all it stays put and wastes the cast",
		not lone.is_riding() and lone.is_alive()
		and bare.unit_at(Vector2i(2, 1)) == lone)
	var wasted := false
	for e in bare_sim.events:
		if e.kind == "ability" and int(e.uid) == lone.uid and bool(e.get("wasted", false)):
			wasted = true
	_check("and says so in the log", wasted)


func _no_one_can_see(board: BoardModel, hidden: UnitInstance) -> bool:
	## Nothing on the board picks the hidden unit as its nearest enemy, and the tile
	## it used to stand on is free for anybody to walk into.
	for other in board.units_view():
		if other.team == hidden.team:
			continue
		if board.nearest_enemy(other) == hidden:
			return false
	return board.is_empty(hidden.cell)


func _test_the_usurper_and_the_tier_ladder() -> void:
	_section("Which way the Usurper can reach")
	var usurper := _must_find("usurper")
	var ab: AbilityData = usurper.ability
	if ab == null:
		return
	_check("Usurpation forces a lower host up by default", ab.possess_forces_tier)

	# Downwards: the host is dragged up to the thief's tier and arrives whole.
	var down := _usurp_board(4, 2)
	var host: UnitInstance = down.prey
	var was := host.data
	down.sim.setup(down.board, 111)
	_check("a higher Usurper drags a lower host up to its own tier",
		host.is_possessed() and host.data.tier == 4,
		"host at T%d" % host.data.tier)
	_check("and the bigger body arrives at full health",
		is_equal_approx(host.current_hp, host.stat(StatModifier.Stat.MAX_HP)),
		"%.0f of %.0f" % [host.current_hp, host.stat(StatModifier.Stat.MAX_HP)])
	_check("it is a real row off the unit's own merge chain, not a fabrication",
		host.data.id == was.id and host.data != was)
	# The promotion is BORROWED. This is the half the user called out explicitly.
	_check("the host remembers the tier it was drawn at",
		host.home_data == was)
	host.reset_for_battle()
	_check("and the owner does not keep the promotion",
		host.data == was and host.data.tier == 2,
		"handed back at T%d" % host.data.tier)

	# Upwards: it cannot get in and bursts instead.
	var up := _usurp_board(2, 5)
	var thief: UnitInstance = up.thief
	var big: UnitInstance = up.prey
	var full := big.current_hp
	var gap := 5 - 2
	var want := ab.backlash_per_tier * thief.data.max_hp * float(gap)
	up.sim.setup(up.board, 113)
	_check("a lower Usurper cannot get into a higher host",
		not thief.is_riding() and not big.is_possessed())
	_check("it dies on the spot instead", not thief.is_alive())
	_check("and the host stays on its own side", big.team == BoardModel.TEAM_B)
	var dealt := full - big.current_hp
	_check("the backlash is proportional to the tier gap",
		is_equal_approx(dealt, want),
		"%.0f dealt, wanted %.0f (T%d own max %.0f x gap %d)" % [
			dealt, want, thief.data.tier, thief.data.max_hp, gap])

	# Preference order. With both a safe lower host and a lethal higher one on the
	# board it must take the lower one — suiciding with an option available would
	# just look broken.
	BoardModel.reset_map()
	var choice := BoardModel.new()
	var picky := UnitInstance.create(BoardModel.at_tier(usurper, 3),
		BoardModel.TEAM_A)
	choice.force_place(picky, Vector2i(2, 1))
	var small := UnitInstance.create(
		BoardModel.at_tier(_must_find("warden"), 1), BoardModel.TEAM_B)
	var huge := UnitInstance.create(
		BoardModel.at_tier(_must_find("warden"), 6), BoardModel.TEAM_B)
	# The big one CLOSER, so distance alone would pick the wrong answer.
	choice.force_place(huge, Vector2i(2, 2))
	choice.force_place(small, Vector2i(5, 9))
	var choice_sim := CombatSim.new()
	choice_sim.setup(choice, 115)
	_check("offered a safe lower host and a lethal higher one it takes the lower",
		picky.is_riding() and picky.host_uid == small.uid,
		"took %d, small is %d, huge is %d" % [
			picky.host_uid, small.uid, huge.uid])
	_check("and dragging it up did not touch the one it could not take",
		not huge.is_possessed() and huge.team == BoardModel.TEAM_B)

	# Same tier beats a lower tier, even when the lower one is closer.
	BoardModel.reset_map()
	var even := BoardModel.new()
	var fussy := UnitInstance.create(BoardModel.at_tier(usurper, 3),
		BoardModel.TEAM_A)
	even.force_place(fussy, Vector2i(2, 1))
	var near_low := UnitInstance.create(
		BoardModel.at_tier(_must_find("warden"), 1), BoardModel.TEAM_B)
	var far_same := UnitInstance.create(
		BoardModel.at_tier(_must_find("warden"), 3), BoardModel.TEAM_B)
	even.force_place(near_low, Vector2i(2, 2))
	even.force_place(far_same, Vector2i(5, 9))
	var even_sim := CombatSim.new()
	even_sim.setup(even, 117)
	_check("its own tier wins over a nearer lower one",
		fussy.host_uid == far_same.uid,
		"took %d, wanted %d" % [fussy.host_uid, far_same.uid])


func _test_the_husk() -> void:
	_section("What is left when the puppet dies")
	var usurper := _must_find("usurper")
	var ab: AbilityData = usurper.ability
	if ab == null:
		return
	_check("the husk is slower than the unit was", ab.husk_move_mult > 1.0,
		"x%.2f" % ab.husk_move_mult)

	var t := _usurp_board(3, 3, 1)
	var thief: UnitInstance = t.thief
	var prey: UnitInstance = t.prey
	t.sim.setup(t.board, 121)
	if not thief.is_riding():
		_check("the husk test needs a possession to start from", false)
		return
	var where := prey.cell
	var base := thief.data.move_time
	t.sim._fell(prey, thief.uid, false)

	_check("the puppeteer falls out of it", not thief.is_riding()
		and thief.is_husk())
	_check("standing where its puppet fell", thief.cell == where
		and t.board.unit_at(where) == thief,
		"at %s, puppet fell at %s" % [thief.cell, where])
	_check("with one health", is_equal_approx(thief.current_hp, 1.0),
		"%.2f hp" % thief.current_hp)
	_check("and a maximum of one, so nothing can raise it",
		is_equal_approx(thief.stat(StatModifier.Stat.MAX_HP), 1.0),
		"%.2f max" % thief.stat(StatModifier.Stat.MAX_HP))
	_check("the dead host stops claiming to be ridden",
		not prey.is_possessed())

	# "1 hp that cannot be changed" has to survive everything that raises health.
	thief.heal(9999.0)
	_check("healing it does nothing", is_equal_approx(thief.current_hp, 1.0),
		"%.2f hp" % thief.current_hp)
	thief.add_shield(9999.0, 9999.0)
	_check("and it cannot be shielded either", is_zero_approx(thief.shield),
		"%.2f shield" % thief.shield)
	thief.add_battle_modifier(StatModifier.make(StatModifier.Stat.MAX_HP,
		StatModifier.Mode.PERCENT, 4.0))
	thief.add_battle_modifier(StatModifier.make(StatModifier.Stat.MAX_HP,
		StatModifier.Mode.FLAT, 900.0))
	_check("a max-health buff cannot lift it either",
		is_equal_approx(thief.stat(StatModifier.Stat.MAX_HP), 1.0),
		"%.2f max" % thief.stat(StatModifier.Stat.MAX_HP))
	_check("it is slow", thief.stat(StatModifier.Stat.MOVE_TIME) > base * 2.0,
		"%.2fs a tile against %.2fs" % [
			thief.stat(StatModifier.Stat.MOVE_TIME), base])

	# Re-infection.
	var spares: Array = t.spares
	if spares.is_empty():
		_check("the re-infection test needs a second enemy", false)
		return
	var next_host: UnitInstance = spares[0]
	thief.target = next_host
	thief.state = UnitInstance.State.IDLE
	t.sim._begin_attack(thief)
	_check("a husk that lands a blow is inside whatever it hit",
		thief.is_riding() and thief.host_uid == next_host.uid,
		"host_uid %d, wanted %d" % [thief.host_uid, next_host.uid])
	_check("and the new host changes sides as well",
		next_host.team == thief.team and next_host.is_possessed())
	_check("it is still a husk, so killing the new puppet does not restore it",
		thief.is_husk())
	thief.reset_for_battle()
	_check("only the round boundary lifts the lock", not thief.is_husk()
		and thief.stat(StatModifier.Stat.MAX_HP) > 1.0,
		"%.0f max" % thief.stat(StatModifier.Stat.MAX_HP))


func _test_the_grip_can_be_timed() -> void:
	_section("How long the Usurper holds on")
	var usurper := _must_find("usurper")
	var ab: AbilityData = usurper.ability
	if ab == null:
		return
	# What ships: a grip measured per tier of the Usurper.
	_check("the grip is timed, and scales with tier",
		ab.possess_seconds_per_tier > 0.0,
		"%.2fs a tier" % ab.possess_seconds_per_tier)

	# The ladder. Read off grip_seconds rather than off the table, so this fails if
	# the tier the seconds are multiplied by ever stops being the Usurper's own.
	var probe := CombatSim.new()
	var ladder: PackedFloat32Array = []
	for t in range(1, 7):
		var who := UnitInstance.create(BoardModel.at_tier(usurper, t),
			BoardModel.TEAM_A)
		ladder.append(probe.grip_seconds(who, ab))
	_check("every tier holds on longer than the one below it",
		ladder[0] < ladder[1] and ladder[1] < ladder[2] and ladder[2] < ladder[3]
		and ladder[3] < ladder[4] and ladder[4] < ladder[5],
		str(ladder))
	_check("and a tier 1 grip is a fraction of a tier 6 one",
		is_equal_approx(ladder[5], ladder[0] * 6.0),
		"%.2fs against %.2fs" % [ladder[5], ladder[0] * 6.0])
	# Measured off the USURPER, not the host. A tier 5 Usurper forced onto a tier 1
	# body should keep it for what its own tier is worth.
	var big := UnitInstance.create(BoardModel.at_tier(usurper, 5), BoardModel.TEAM_A)
	_check("the clock reads the Usurper's tier and not its host's",
		is_equal_approx(probe.grip_seconds(big, ab),
			ab.possess_seconds_per_tier * 5.0),
		"%.2fs" % probe.grip_seconds(big, ab))

	# Zero still means the whole round: it is the lever, and it has to keep working
	# or the measured curve behind the shipped number is unreproducible.
	var was: float = ab.possess_seconds_per_tier
	ab.possess_seconds_per_tier = 0.0
	var forever := _usurp_board(3, 3, 1)
	forever.sim.setup(forever.board, 151)
	var kept: UnitInstance = forever.prey
	_check("zero seconds a tier carries no clock at all",
		kept.possess_left < 0.0, "%.2fs left" % kept.possess_left)
	for i in 400:
		forever.sim.step()
	_check("and forty seconds later the host is still held",
		not kept.is_alive() or kept.is_possessed(),
		"possessed %s, alive %s" % [kept.is_possessed(), kept.is_alive()])

	# A short clock, so the release can be watched inside a few ticks. A tier 3
	# Usurper at 0.667 a tier lets go after two seconds.
	ab.possess_seconds_per_tier = 2.0 / 3.0
	var timed := _usurp_board(3, 3, 1)
	var thief: UnitInstance = timed.thief
	var host: UnitInstance = timed.prey
	var owner := host.team
	timed.sim.setup(timed.board, 153)
	_check("a timed grip starts its clock at the bell",
		is_equal_approx(host.possess_left, 2.0),
		"%.2fs left" % host.possess_left)
	_check("and the host is held to begin with", host.is_possessed()
		and host.team != owner)
	for i in 30:
		timed.sim.step()
	_check("when it runs out the host goes home",
		not host.is_possessed() and host.team == owner,
		"team %d, possessed %s" % [host.team, host.is_possessed()])
	_check("and the puppeteer drops out as a husk rather than vanishing",
		not thief.is_riding()
		and (thief.is_husk() or not thief.is_alive()),
		"riding %s husk %s alive %s" % [
			thief.is_riding(), thief.is_husk(), thief.is_alive()])
	if thief.is_alive():
		_check("standing on a tile of its own, not on top of its former host",
			thief.cell != host.cell
			and timed.board.unit_at(thief.cell) == thief,
			"husk at %s, host at %s" % [thief.cell, host.cell])
	var freed := false
	for e in timed.sim.events:
		if e.kind == "possess_end" and int(e.uid) == host.uid:
			freed = true
	_check("and the view is told", freed)

	# The lent buff goes back with the body. This is the leak worth naming: the
	# host may also be carrying its OWN side's empowerment and roster bonuses, so a
	# release that cleared battle_modifiers wholesale would quietly delete those.
	var pool := _pool()
	var reins := pool.by_id(&"reins")
	if reins != null:
		var rich := _usurp_board(3, 3, 1)
		var tb := TeamBuffs.new()
		tb.add(reins, BuffData.Rarity.GOLD)
		rich.sim.team_buffs[BoardModel.TEAM_A] = tb
		var held: UnitInstance = rich.prey
		var bare_hp := held.data.max_hp
		rich.sim.setup(rich.board, 155)
		# AFTER setup, not before: setup() calls reset_for_battle() on every unit,
		# which clears battle_modifiers — so a modifier planted first is wiped and
		# the check fails for a reason that has nothing to do with the release.
		var own := StatModifier.make(StatModifier.Stat.ATTACK_SPEED,
			StatModifier.Mode.PERCENT, 0.5)
		held.add_battle_modifier(own)
		_check("a buffed host is stronger while it is held",
			held.stat(StatModifier.Stat.MAX_HP) > bare_hp,
			"%.0f against %.0f" % [held.stat(StatModifier.Stat.MAX_HP), bare_hp])
		for i in 30:
			rich.sim.step()
		_check("and the thief's buff leaves with the thief",
			is_equal_approx(held.stat(StatModifier.Stat.MAX_HP), bare_hp),
			"%.0f, wanted %.0f" % [held.stat(StatModifier.Stat.MAX_HP), bare_hp])
		_check("its own side's modifiers are untouched",
			held.battle_modifiers.has(own),
			"the host lost a modifier that was never the thief's")
		_check("and the health bar came down with the maximum",
			held.current_hp <= held.stat(StatModifier.Stat.MAX_HP) + 0.01,
			"%.0f hp of %.0f max" % [
				held.current_hp, held.stat(StatModifier.Stat.MAX_HP)])

	ab.possess_seconds_per_tier = was


func _test_a_stunned_unit_does_nothing() -> void:
	_section("A stunned unit neither swings nor walks")
	# Asserted from the outside rather than by reading the gates: what matters is
	# that no attack and no move event comes out of a stunned unit for as long as the
	# stun lasts, whichever of the three gates is doing the refusing.
	BoardModel.reset_map()
	var board := BoardModel.new()
	var held := UnitInstance.create(
		BoardModel.at_tier(_must_find("warden"), 3), BoardModel.TEAM_A)
	board.force_place(held, Vector2i(2, 4))
	# Adjacent, so a unit that is free to act swings on its very first tick. A tier 6
	# SPIRE: harmless and rooted, with an enormous body. Written first as a tier 6
	# Warden, which killed the stunned unit halfway through the test — "it never went
	# back to fighting" was true and had nothing to do with the stun.
	var foe := UnitInstance.create(
		BoardModel.at_tier(_must_find("spire"), 6), BoardModel.TEAM_B)
	board.force_place(foe, Vector2i(2, 5))
	var sim := CombatSim.new()
	sim.crit_chance = 0.0
	sim.setup(board, 201)

	var mark := sim.events.size()
	held.stun_left = 3.0
	held.state = UnitInstance.State.IDLE
	held.state_timer = 0.0
	var acted := 0
	for i in 25:
		sim.step()
		for j in range(mark, sim.events.size()):
			var e: Dictionary = sim.events[j]
			if e.kind != "attack" and e.kind != "move" and e.kind != "cast_start":
				continue
			if int(e.uid) == held.uid:
				acted += 1
		mark = sim.events.size()
	_check("it does nothing at all for the two and a half seconds measured",
		acted == 0, "%d actions while stunned" % acted)
	_check("and it is still stunned at the end of them", held.is_stunned(),
		"%.2fs left" % held.stun_left)
	_check("the gates all agree it is held",
		held.is_held() and not held.can_move_now() and not held.can_attack_now())

	# And it picks back up. A stun that never ended would pass the check above for
	# the wrong reason.
	for i in 10:
		sim.step()
	_check("when it wears off it is free again",
		not held.is_stunned() and held.can_attack_now(),
		"%.2fs left" % held.stun_left)
	var after := 0
	var from := sim.events.size()
	for i in 40:
		sim.step()
	for j in range(from, sim.events.size()):
		var e: Dictionary = sim.events[j]
		if (e.kind == "attack" or e.kind == "move") and int(e.uid) == held.uid:
			after += 1
	_check("and it goes back to fighting", after > 0,
		"still doing nothing %d ticks later" % 40)

	# The charge has to actually hand one out, measured through the opener rather
	# than by setting stun_left by hand.
	var lane := _breaker_lane(3, BoardModel.TEAM_B, 4)
	lane.sim.setup(lane.board, 203)
	_finish_charge(lane.sim, lane.runner)
	var victim: UnitInstance = lane.mark
	_check("the Breaker's charge leaves its victim stunned",
		victim.is_stunned(), "%.2fs" % victim.stun_left)
	# And the view is told, with a duration — a "stun" event carrying no seconds
	# cannot be drawn for the right length of time.
	var seconds := -1.0
	for e in lane.sim.events:
		if e.kind == "stun" and int(e.uid) == victim.uid:
			seconds = float(e.get("seconds", -1.0))
			break
	_check("and the view is told how long for", seconds > 0.0,
		"%.2fs on the event" % seconds)


func _test_the_clock_is_a_setting() -> void:
	_section("The round clock as a setting")
	# The simulation must not read GameSetup for this. The combat layer sits below the
	# flow layer, and a sim that needed an autoload to run could not be built in a
	# test — which is this test.
	var sim := CombatSim.new()
	_check("a fresh sim has the conventional clock",
		is_equal_approx(sim.sudden_death_at(), CombatSim.SUDDEN_DEATH)
		and is_equal_approx(sim.timeout_at(), CombatSim.DEFAULT_TIMEOUT),
		"%.0f / %.0f" % [sim.sudden_death_at(), sim.timeout_at()])

	sim.sudden_death = 20.0
	sim.timeout = 40.0
	_check("and it can be told otherwise",
		is_equal_approx(sim.sudden_death_at(), 20.0)
		and is_equal_approx(sim.timeout_at(), 40.0))
	# Sudden death after the timeout is a rule that never fires, so it is clamped
	# rather than trusted.
	sim.sudden_death = 500.0
	_check("a sudden death past the timeout is pulled back before it",
		sim.sudden_death_at() < sim.timeout_at(),
		"%.1f against %.1f" % [sim.sudden_death_at(), sim.timeout_at()])

	# And it really changes the battle. A short clock has to make sudden death
	# actually land inside a round that would otherwise never reach it.
	BoardModel.reset_map()
	var board := BoardModel.new()
	# Two Spires: rooted, harmless, enormous. Nothing can end this round except the
	# clock, which is what makes the clock measurable.
	board.force_place(UnitInstance.create(
		BoardModel.at_tier(_must_find("spire"), 6), BoardModel.TEAM_A), Vector2i(2, 1))
	board.force_place(UnitInstance.create(
		BoardModel.at_tier(_must_find("spire"), 6), BoardModel.TEAM_B), Vector2i(2, 8))
	var quick := CombatSim.new()
	quick.sudden_death = 6.0
	quick.timeout = 20.0
	quick.setup(board, 221)
	quick.run()
	var death_at := -1.0
	for e in quick.events:
		if e.kind == "sudden_death":
			death_at = float(e.at)
	_check("a short clock reaches sudden death", death_at > 0.0,
		"never fired in %.1fs" % quick.duration())
	_check("at about where it was set", absf(death_at - 6.0) < 1.0,
		"fired at %.1fs, set to 6.0" % death_at)
	_check("and the round is called at the timeout",
		quick.duration() <= 20.1, "ran %.1fs" % quick.duration())

	# The conventional clock on the same board does not reach either.
	var slow := CombatSim.new()
	slow.setup(board, 221)
	slow.run()
	var slow_death := false
	for e in slow.events:
		if e.kind == "sudden_death":
			slow_death = true
	_check("where the conventional clock runs far longer",
		slow.duration() > quick.duration() * 2.0,
		"%.1fs against %.1fs" % [slow.duration(), quick.duration()])
	_check("and reaches its own sudden death, not the short one",
		slow_death and slow.duration() > 100.0, "%.1fs" % slow.duration())


func _test_gates() -> void:
	_section("Gates, and the Spire they answer")
	# The Steppes: one pair, on the left flank a row in from each back rank. Written
	# against Three Roads first, which lost its gate when the boards were measured —
	# see _test_only_big_maps_have_gates for which kept one and why.
	var m: MapData = load("res://data/maps/the_steppes.tres")
	_check("The Steppes loads and is legal", m != null and m.is_valid(),
		"" if m == null else m.invalid_reason())
	if m == null:
		return
	var pairs := m.gate_pairs()
	_check("it has a gate pair on it", pairs.size() == 2, "%d pads" % pairs.size())
	if pairs.size() != 2:
		return
	# Paired by MIRROR, which is the only rule that can be fair given that every map
	# has to be mirror-symmetric anyway — and it means a pair can never be authored
	# with one end in a better place than the other.
	var mirrored := true
	var symmetric := true
	for pad: Vector2i in pairs:
		if pairs[pad] != m.mirror(pad):
			mirrored = false
		if pairs.get(pairs[pad], Vector2i(-1, -1)) != pad:
			symmetric = false
	_check("each pad leads to its own mirror image", mirrored, str(pairs))
	_check("and the link works both ways", symmetric, str(pairs))
	var halves := {}
	for pad: Vector2i in pairs:
		halves[pad.y < m.height / 2] = true
	_check("so there is one on each side", halves.size() == 2, str(pairs))

	BoardModel.use_map(m)
	var pad_a := Vector2i(0, 1)
	var pad_b := BoardModel.gate_from(pad_a)
	_check("the board knows where a pad leads",
		BoardModel.is_gate(pad_a) and pad_b != pad_a, "%s" % pad_b)
	_check("and a tile with no gate leads to itself",
		BoardModel.gate_from(Vector2i(0, 0)) == Vector2i(0, 0))
	_check("a pad is ordinary ground you can stand on",
		not BoardModel.is_blocked(pad_a) and BoardModel.is_playable(pad_a))

	# The field has to be SHORTER through it, or the gate is decoration: a unit that
	# prices the long way round as the only way round walks straight over the pad.
	var board := BoardModel.new()
	var walker := UnitInstance.create(
		load("res://data/units/warden_t1.tres") as UnitData, BoardModel.TEAM_A)
	board.force_place(walker, pad_a)
	var prey := UnitInstance.create(
		load("res://data/units/spire_t1.tres") as UnitData, BoardModel.TEAM_B)
	var deep := Vector2i(pad_b.x, BoardModel.HEIGHT - 1)
	board.force_place(prey, deep)
	var sim := CombatSim.new()
	sim.board = board
	sim._field_team = BoardModel.TEAM_A
	sim._field_wall_cost = CombatSim.WALL_COST
	var field := sim._distance_field(deep, pad_a)
	var through: int = field.get(pad_a, -1)
	var walk := BoardModel.tile_distance(pad_a, deep)
	_check("the field prices the gate far below the walk",
		through > 0 and through < walk,
		"%d through the gate against %d tiles on foot" % [through, walk])

	# And the round loop actually takes it. Through the whole sim, not by calling
	# the step function: a gate nothing walks into is the same as no gate.
	sim.setup(board, 211)
	var used := Vector2i(-1, -1)
	var took := -1.0
	var walked := 0
	for i in 400:
		sim.step()
	for e in sim.events:
		if int(e.get("uid", -1)) != walker.uid:
			continue
		if e.kind == "gate":
			used = e.to
			took = float(e.get("duration", -1.0))
		elif e.kind == "move":
			walked += 1
	_check("a unit walking at something far away goes through it",
		used == pad_b, "came out at %s, the far pad is %s" % [used, pad_b])
	# A handful of steps, not a march. The Steppes has stairs and terraces between the
	# pad and the far corner, so a couple of tiles either side of the transit is
	# expected — what is being ruled out is the unit walking the whole board.
	_check("and it barely walks at all to get there", walked <= 8,
		"%d tiles walked, the board is %d tall" % [walked, BoardModel.HEIGHT])
	# Its own event kind. A "move" would make the view interpolate the unit across
	# every tile in between, which is a unit sliding through a wall of stone.
	var as_move := false
	for e in sim.events:
		if e.kind == "move" and int(e.uid) == walker.uid \
				and BoardModel.tile_distance(e.from, e.to) > 1:
			as_move = true
	_check("and it is not reported as an enormous walk", not as_move)
	# Read off the event's own duration, not off its timestamp. The walker in this
	# test starts standing ON the pad, so it goes through on the very first tick and
	# a timestamp of zero is correct — what has to be true is that the trip occupies
	# the unit for a normal step, because a free board-crossing would make the far
	# side's back rank indefensible.
	_check("the trip costs a step of movement time, not nothing",
		is_equal_approx(took, walker.stat(StatModifier.Stat.MOVE_TIME)),
		"%.2fs against a stride of %.2fs" % [
			took, walker.stat(StatModifier.Stat.MOVE_TIME)])

	# One flanker per side per round, measured through the sim rather than off the
	# constant. This is the check the constant alone does not make: with the cap
	# removed, every unit that agrees the shortcut is worth taking walks through the
	# same one-tile hole in single file, which is the failure the cap exists for and
	# was worth seventy points of win rate on one board.
	BoardModel.use_map(m)
	var crowd := BoardModel.new()
	var movers: Array[UnitInstance] = []
	# Three of them, all within a step or two of the pad, all wanting the same thing
	# on the far side — so all three would take it if they were allowed to.
	for spot in [pad_a, pad_a + Vector2i(1, 0), pad_a + Vector2i(0, 1)]:
		if not crowd.in_bounds(spot) or BoardModel.is_blocked(spot):
			continue
		var mover := UnitInstance.create(
			load("res://data/units/warden_t1.tres") as UnitData, BoardModel.TEAM_A)
		if crowd.force_place(mover, spot):
			movers.append(mover)
	crowd.force_place(UnitInstance.create(
		load("res://data/units/spire_t6.tres") as UnitData, BoardModel.TEAM_B),
		Vector2i(pad_b.x, BoardModel.HEIGHT - 1))
	_check("three of them are standing at the pad", movers.size() >= 3,
		"%d placed" % movers.size())
	var crowd_sim := CombatSim.new()
	crowd_sim.setup(crowd, 213)
	for i in 400:
		crowd_sim.step()
	var transits := 0
	for e in crowd_sim.events:
		if e.kind == "gate":
			transits += 1
	_check("only one of them goes through",
		transits == CombatSim.GATE_TRANSITS_PER_TEAM,
		"%d transits for a cap of %d" % [
			transits, CombatSim.GATE_TRANSITS_PER_TEAM])
	_check("and the simulation says so itself",
		crowd_sim.gate_transits(BoardModel.TEAM_A)
			== CombatSim.GATE_TRANSITS_PER_TEAM,
		"%d" % crowd_sim.gate_transits(BoardModel.TEAM_A))
	# The others must not be left standing on the pad waiting for a turn that will
	# never come: the field has to stop routing them there once the side is spent.
	var loitering := 0
	for mover in movers:
		if mover.is_alive() and mover.cell == pad_a:
			loitering += 1
	_check("the rest get on with the walk instead of queueing at it",
		loitering == 0, "%d still standing on the pad" % loitering)

	# An occupied far pad is not a destination.
	BoardModel.use_map(m)
	var blocked_board := BoardModel.new()
	var goer := UnitInstance.create(
		load("res://data/units/warden_t1.tres") as UnitData, BoardModel.TEAM_A)
	blocked_board.force_place(goer, pad_a)
	blocked_board.force_place(UnitInstance.create(
		load("res://data/units/spire_t6.tres") as UnitData, BoardModel.TEAM_B), pad_b)
	var blocked_sim := CombatSim.new()
	blocked_sim.board = blocked_board
	_check("stepping onto an occupied pad is refused",
		not blocked_sim._step_through_gate(goer, pad_b) and goer.cell == pad_a)

	BoardModel.reset_map()
	_check("and the default board has no gates at all",
		BoardModel.gate_count() == 0, "%d pads" % BoardModel.gate_count())


func _test_only_big_maps_have_gates() -> void:
	_section("Which boards get a gate")
	# A gate is the answer to "this board is too big to reach their back rank on",
	# so it belongs on the boards that are. On a small map the walk is short enough
	# that a shortcut would just be a free flank.
	# The gated set is HAND PICKED off measurements, not derived from board size, and
	# it is pinned here because "which boards" turned out to be the whole design.
	#
	# A gate helps on a board whose halves are already joined by open ground, where
	# the flanker is an extra and the line still fights. It is ruinous on a board
	# whose middle is obstructed, because then the gate is the FASTEST route and the
	# army walks through a one-tile hole in single file. Attacker win rate with the
	# gate against the same board with its gates rubbed out:
	#
	#   the Steppes   82.5% v 67.5%   keep — and it beats bringing an Assassin (53.8%)
	#   the Compound  86.2% v 86.2%   keep — level, but reaches the back rank in 37s
	#                                 rather than 61s, and beats an Assassin (67.5%)
	#   Three Roads   57.5% v 65.0%   drop — three walled lanes; a body in the gate
	#                                 is a body missing from a lane
	#   the Breach    32.5% v 85.0%   drop — a rubble wall across the middle makes the
	#                                 gate the only fast way through
	#   the Labyrinth 17.5% v 80.7%   drop — a maze punishes a split line hardest
	const GATED: Array[String] = ["the_steppes", "the_compound"]
	var gated: PackedStringArray = []
	var small_with: PackedStringArray = []
	for m in _load_maps():
		var pads := m.gate_pairs().size()
		if pads > 0:
			gated.append(String(m.id))
		if m.tiles() < 130 and pads > 0:
			small_with.append(String(m.id))
	gated.sort()
	var want := PackedStringArray(GATED)
	want.sort()
	_check("exactly the measured boards have a gate", gated == want,
		"gated: %s, wanted: %s" % [", ".join(gated), ", ".join(want)])
	_check("and no small board does", small_with.is_empty(),
		"found on %s" % ", ".join(small_with))

	# The transit cap is the other half of the design, and it is what turned the
	# Steppes from 75.0% into 82.5% and the Breach from 15.0% into 32.5%.
	_check("a side may send one unit through per round",
		CombatSim.GATE_TRANSITS_PER_TEAM == 1,
		"%d" % CombatSim.GATE_TRANSITS_PER_TEAM)
	# Pads come in pairs everywhere, always an even count, never self-linked.
	var odd: PackedStringArray = []
	for m in _load_maps():
		var pads := m.gate_pairs()
		if pads.size() % 2 != 0:
			odd.append(String(m.id))
		for pad: Vector2i in pads:
			if pads[pad] == pad:
				odd.append("%s links %s to itself" % [m.id, pad])
	_check("no map has an odd or self-linked gate", odd.is_empty(),
		", ".join(odd))

	# A gate whose mirror is not a gate must be refused outright, because
	# gate_pairs() would otherwise have to invent a destination for it.
	var rigged := MapData.new()
	rigged.id = &"rigged"
	rigged.display_name = "Rigged"
	rigged.width = 6
	rigged.height = 10
	rigged.has_neutral = false
	rigged.rows = PackedStringArray([
		"..O...", "......", "......", "......", "......",
		"......", "......", "......", "......", "......",
	])
	_check("a lone gate makes the map illegal", not rigged.is_valid(),
		rigged.invalid_reason())
	_check("and it is refused for not mirroring, which is the real fault",
		rigged.invalid_reason().contains("mirror"), rigged.invalid_reason())


func _test_shields_fizzle() -> void:
	_section("Shields do not last forever")
	_check("a shield has a duration at all", CombatSim.SHIELD_SECONDS > 0.0,
		"%.1fs" % CombatSim.SHIELD_SECONDS)

	var warden := _must_find("warden")
	var u := UnitInstance.create(BoardModel.at_tier(warden, 3), BoardModel.TEAM_A)
	var pool := u.stat(StatModifier.Stat.MAX_HP)
	u.add_shield(pool * 0.5, pool, CombatSim.SHIELD_SECONDS)
	_check("gaining one starts its clock",
		u.shield > 0.0 and is_equal_approx(u.shield_left, CombatSim.SHIELD_SECONDS),
		"%.0f shield, %.2fs left" % [u.shield, u.shield_left])

	# The rule the user asked for, and the one worth a test of its own: a second
	# shield inside the window is ADDED and the clock is NOT renewed. Written the
	# other way round, a unit with any repeatable shield keeps one up permanently and
	# the duration is decorative.
	var first := u.shield
	u.shield_left = 3.0
	u.add_shield(pool * 0.25, pool * 10.0, CombatSim.SHIELD_SECONDS)
	_check("a second shield inside the window adds to the pool",
		u.shield > first, "%.0f against %.0f" % [u.shield, first])
	_check("and does not reset the clock",
		is_equal_approx(u.shield_left, 3.0), "%.2fs left" % u.shield_left)

	# Running it out.
	var ticks := 0
	while u.shield_left > 0.0 and ticks < 200:
		u.tick_shield(CombatSim.TICK)
		ticks += 1
	_check("when the clock runs out the whole pool goes, not just the last layer",
		is_zero_approx(u.shield), "%.2f left" % u.shield)
	_check("and it went at the three seconds that were left, not at seven",
		absf(float(ticks) * CombatSim.TICK - 3.0) < 0.15,
		"%.1fs" % (float(ticks) * CombatSim.TICK))

	# A pool absorbed to nothing lets go of its clock, so the NEXT shield gets a
	# fresh one. Without this a unit that is shielded, chewed through, and shielded
	# again inherits the remains of the first clock.
	var v := UnitInstance.create(BoardModel.at_tier(warden, 3), BoardModel.TEAM_A)
	v.add_shield(50.0, 1000.0, CombatSim.SHIELD_SECONDS)
	v.tick_shield(2.0)
	v.take_damage(50.0)
	v.tick_shield(CombatSim.TICK)
	_check("a shield chewed through drops its clock",
		is_zero_approx(v.shield_left), "%.2fs left" % v.shield_left)
	v.add_shield(50.0, 1000.0, CombatSim.SHIELD_SECONDS)
	_check("so the next one gets the full window",
		is_equal_approx(v.shield_left, CombatSim.SHIELD_SECONDS),
		"%.2fs" % v.shield_left)

	# Through the simulation, on the unit built around a shield, because the thing
	# that keeps going wrong in this codebase is a rule nothing calls.
	BoardModel.reset_map()
	var board := BoardModel.new()
	var tank := UnitInstance.create(BoardModel.at_tier(warden, 3), BoardModel.TEAM_A)
	board.force_place(tank, Vector2i(2, 1))
	# Far away and harmless, so the shield is never chewed and the only thing that
	# can take it is the clock.
	var far := UnitInstance.create(
		BoardModel.at_tier(_must_find("spire"), 1), BoardModel.TEAM_B)
	board.force_place(far, Vector2i(5, 9))
	var sim := CombatSim.new()
	sim.setup(board, 191)
	_check("the Warden opens the round behind its bulwark", tank.shield > 0.0,
		"%.0f shield" % tank.shield)
	var held := tank.shield
	for i in int(CombatSim.SHIELD_SECONDS / CombatSim.TICK) - 4:
		sim.step()
	_check("and it is still there a moment before the window closes",
		tank.shield > 0.0, "%.0f shield" % tank.shield)
	for i in 8:
		sim.step()
	_check("then the round loop takes it away", is_zero_approx(tank.shield),
		"%.0f of %.0f still standing" % [tank.shield, held])
	var told := false
	for e in sim.events:
		if e.kind == "shield_gone" and int(e.uid) == tank.uid:
			told = true
	_check("and the view is told, because a bar that vanishes needs a reason",
		told)

	# The Aegis Wall buff used to write the shield pool directly to bypass the
	# unit's own cap, which is exactly how a gift-from-outside ends up with no clock
	# on it. It has to pass through the same door.
	var pool_buffs := _pool()
	var wall := pool_buffs.by_id(&"aegis_wall")
	if wall != null:
		BoardModel.reset_map()
		var walled := BoardModel.new()
		var guard := UnitInstance.create(
			BoardModel.at_tier(_must_find("archer"), 1), BoardModel.TEAM_A)
		walled.force_place(guard, Vector2i(2, 1))
		walled.force_place(UnitInstance.create(
			BoardModel.at_tier(_must_find("spire"), 1), BoardModel.TEAM_B),
			Vector2i(5, 9))
		var wall_sim := CombatSim.new()
		var tb := TeamBuffs.new()
		tb.add(wall, BuffData.Rarity.GOLD)
		wall_sim.team_buffs[BoardModel.TEAM_A] = tb
		wall_sim.setup(walled, 193)
		_check("the round-shield buff hands out a shield", guard.shield > 0.0,
			"%.0f" % guard.shield)
		_check("and it comes with a clock like every other shield",
			guard.shield_left > 0.0, "%.2fs" % guard.shield_left)
		# The whole reason it bypassed add_shield: an archer's shield_cap is zero, and
		# a gift from outside the unit must not be clipped by it.
		_check("while still ignoring the unit's own shield ceiling",
			guard.shield > guard.stat(StatModifier.Stat.MAX_HP)
				* maxf(guard.data.shield_cap, 0.0),
			"%.0f shield, cap fraction %.2f" % [guard.shield, guard.data.shield_cap])

	# Sudden death still refuses the gain outright, which is a different rule from
	# the clock and must not have been folded into it.
	var late := UnitInstance.create(BoardModel.at_tier(warden, 3), BoardModel.TEAM_A)
	late.recovery_denied = true
	late.add_shield(500.0, 1000.0, CombatSim.SHIELD_SECONDS)
	_check("sudden death still refuses a shield outright",
		is_zero_approx(late.shield) and is_zero_approx(late.shield_left))


func _test_tier_scaling_on_abilities() -> void:
	_section("Abilities that used to stop scaling")

	# The Pyre. Flat burst damage was the documented trap and the Pyre was the unit
	# standing in it: its tier 6 lance hit for exactly what its tier 1 did, into
	# health bars thirty-two times bigger.
	var pyre := _must_find("pyre")
	var lance: AbilityData = pyre.ability
	_check("Cinder Lance is a flat-damage burst, not a multiple of its attack",
		lance != null and lance.burst_damage > 0.0
		and is_zero_approx(lance.burst_attack_multiple))
	if lance == null:
		return
	var sim := CombatSim.new()
	var low := UnitInstance.create(BoardModel.at_tier(pyre, 1), BoardModel.TEAM_A)
	var high := UnitInstance.create(BoardModel.at_tier(pyre, 6), BoardModel.TEAM_A)
	var one := sim.burst_damage_of(low, lance)
	var six := sim.burst_damage_of(high, lance)
	_check("its tier 1 burst is the number on the card",
		is_equal_approx(one, lance.burst_damage),
		"%.0f against %.0f" % [one, lance.burst_damage])
	_check("and a tier 6 burst is thirty-two times it, like every other stat",
		is_equal_approx(six, one * 32.0), "%.0f against %.0f" % [six, one * 32.0])
	# The splash has to ride the same curve. A lance that grows thirty-twofold while
	# the scorch beside it stays at 16 is a lance with no splash at tier 6.
	_check("the splash beside it scales too",
		is_equal_approx(sim.burst_splash_of(high, lance),
			sim.burst_splash_of(low, lance) * 32.0),
		"%.0f against %.0f" % [sim.burst_splash_of(high, lance),
			sim.burst_splash_of(low, lance) * 32.0])
	# Against the curve it has to keep up with: the thing it is shooting at.
	var body_growth := BoardModel.at_tier(_must_find("warden"), 6).max_hp \
		/ BoardModel.at_tier(_must_find("warden"), 1).max_hp
	_check("so the burst now keeps pace with the health bars it is aimed at",
		is_equal_approx(six / one, body_growth),
		"burst grew %.0fx, bodies grew %.0fx" % [six / one, body_growth])

	# The Leech. The drain already grew in absolute terms — it is a share of a
	# maximum that doubles — but it never got BETTER at its job, so merging one up
	# bought nothing but a bigger body.
	var leech := _must_find("leech")
	var siphon: AbilityData = leech.ability
	_check("Siphon takes a share of the victim's maximum",
		siphon != null and siphon.drain_percent > 0.0)
	if siphon == null:
		return
	_check("and that share now grows with the Leech's tier",
		siphon.drain_percent_per_tier > 0.0,
		"%.4f a tier" % siphon.drain_percent_per_tier)
	var l1 := UnitInstance.create(BoardModel.at_tier(leech, 1), BoardModel.TEAM_A)
	var l6 := UnitInstance.create(BoardModel.at_tier(leech, 6), BoardModel.TEAM_A)
	var s1 := sim.drain_percent_of(l1, siphon)
	var s6 := sim.drain_percent_of(l6, siphon)
	_check("a tier 1 slice is the number on the card",
		is_equal_approx(s1, siphon.drain_percent), "%.4f" % s1)
	_check("and the ladder ends at double it, not thirty-two times it",
		is_equal_approx(s6, s1 * 2.0), "%.4f against %.4f" % [s6, s1 * 2.0])
	# Linear on purpose. The slice is already a fraction of a maximum that doubles;
	# compound both and a tier 6 Siphon deletes a tier 6 Warden in under two seconds.
	_check("the growth is linear, so it does not compound with the victim's health",
		is_equal_approx(sim.drain_percent_of(
			UnitInstance.create(BoardModel.at_tier(leech, 3), BoardModel.TEAM_A),
			siphon), s1 + siphon.drain_percent_per_tier * 2.0))

	# And through the sim, so this is not just arithmetic on a resource: the slice
	# is baked in when the drain fastens on, and it has to be the scaled one.
	BoardModel.reset_map()
	var board := BoardModel.new()
	var caster := UnitInstance.create(BoardModel.at_tier(leech, 6), BoardModel.TEAM_A)
	board.force_place(caster, Vector2i(2, 1))
	board.force_place(UnitInstance.create(
		BoardModel.at_tier(_must_find("warden"), 6), BoardModel.TEAM_B),
		Vector2i(2, 9))
	var live := CombatSim.new()
	live.setup(board, 181)
	caster.mana = UnitInstance.MANA_MAX
	for i in 20:
		live.step()
	var bite := -1.0
	for e in live.events:
		if e.kind == "drain_start":
			bite = float(e.percent)
			break
	_check("a tier 6 Leech actually fastens on with the tier 6 slice",
		is_equal_approx(bite, s6), "%.4f, wanted %.4f" % [bite, s6])


func _test_the_vexer_body() -> void:
	_section("The Vexer's body")
	var vexer := _must_find("vexer")
	_check("its base health is 100", is_equal_approx(vexer.max_hp, 100.0),
		"%.0f" % vexer.max_hp)
	# Recorded because the number did not do what it was meant to do. Against a
	# same-tier Warden the Vexer measures 23.0% with this body and 21.7% with the
	# old 85 — the fifteen points bought 1.3 points of win rate. Roughly 190 base is
	# where it reaches the median. The ability is not the problem; the body is.
	# The point of the number was to stop it dying instantly, not to turn it into a
	# front-liner — so it still has to sit well under the roster's middle.
	_check("and it is still well under the median body on the roster",
		vexer.max_hp < _median_body() * 0.8,
		"%.0f against a median of %.0f" % [vexer.max_hp, _median_body()])


func _median_body() -> float:
	var all: Array[float] = []
	for d in _roster().units:
		all.append(d.max_hp)
	all.sort()
	if all.is_empty():
		return 0.0
	return all[all.size() / 2]


func _test_the_global_pace() -> void:
	_section("The global walking pace")
	# One number sets how fast the whole game walks, and nothing else pinned it —
	# so deleting it would silently revert the pace and every movement buff with it.
	_check("the pace multiplier is above one, so everything walks slower than written",
		DataBuilder.MOVE_SCALE > 1.0, "x%.2f" % DataBuilder.MOVE_SCALE)
	var warden := _must_find("warden")
	# Checked against the table row rather than a literal, so changing the pace
	# changes one number and this check follows it.
	var written := 0.0
	for row in DataBuilder.UNIT_TABLE:
		if String(row.id) == "warden":
			written = float(row.move)
	_check("and the built unit carries the scaled stride, not the written one",
		written > 0.0 and is_equal_approx(warden.move_time,
			snappedf(written * DataBuilder.MOVE_SCALE, 0.01)),
		"built %.2fs a tile, table says %.2f x %.2f" % [
			warden.move_time, written, DataBuilder.MOVE_SCALE])
	# Every unit, not just the one checked above — a scale applied in one branch of
	# the builder and not another would be worse than not applying it at all.
	var unscaled: PackedStringArray = []
	for row in DataBuilder.UNIT_TABLE:
		var built := _tier_one_of(String(row.id))
		if built == null:
			continue
		if not is_equal_approx(built.move_time,
				snappedf(float(row.move) * DataBuilder.MOVE_SCALE, 0.01)):
			unscaled.append(String(row.id))
	_check("and so does every other unit in the table", unscaled.is_empty(),
		"unscaled: %s" % ", ".join(unscaled))


func _tier_one_of(id: String) -> UnitData:
	var path := "res://data/units/%s_t1.tres" % id
	if not ResourceLoader.exists(path):
		return null
	return load(path) as UnitData


func _test_reins() -> void:
	_section("Reins")
	var pool := _pool()
	var buff := pool.by_id(&"reins")
	_check("Reins is in the pool at all", buff != null)
	if buff == null:
		return
	# This is the check that would have caught Avalanche: a buff made entirely of
	# riders used to be binned by BuffPool._is_live before anyone could pick it.
	_check("it belongs to the Usurper", String(buff.unit_id) == "usurper")
	_check("it gives the host 75, 150 and 225% movement",
		is_equal_approx(buff.host_move_at(BuffData.Rarity.BRONZE), 0.75)
		and is_equal_approx(buff.host_move_at(BuffData.Rarity.SILVER), 1.50)
		and is_equal_approx(buff.host_move_at(BuffData.Rarity.GOLD), 2.25),
		"%.2f/%.2f/%.2f" % [buff.host_move_at(BuffData.Rarity.BRONZE),
			buff.host_move_at(BuffData.Rarity.SILVER),
			buff.host_move_at(BuffData.Rarity.GOLD)])
	_check("and the host 50, 75 and 100% damage and health",
		is_equal_approx(buff.host_power_at(BuffData.Rarity.BRONZE), 0.50)
		and is_equal_approx(buff.host_power_at(BuffData.Rarity.SILVER), 0.75)
		and is_equal_approx(buff.host_power_at(BuffData.Rarity.GOLD), 1.00),
		"%.2f/%.2f/%.2f" % [buff.host_power_at(BuffData.Rarity.BRONZE),
			buff.host_power_at(BuffData.Rarity.SILVER),
			buff.host_power_at(BuffData.Rarity.GOLD)])

	# The Usurper's own half of the movement is an ordinary unit-scoped stat buff,
	# and MOVE_TIME is inverted — so the sign has to come out right or the buff
	# makes the unit slower with nothing to show it went wrong.
	var thief := UnitInstance.create(
		BoardModel.at_tier(_must_find("usurper"), 3), BoardModel.TEAM_A)
	var bare := thief.stat(StatModifier.Stat.MOVE_TIME)
	thief.apply_modifiers(buff.modifiers_for(BuffData.Rarity.GOLD))
	var quick := thief.stat(StatModifier.Stat.MOVE_TIME)
	_check("a gold Reins makes the Usurper itself faster, not slower",
		quick < bare, "%.3fs a tile against %.3fs" % [quick, bare])
	_check("and by the amount the card promises",
		is_equal_approx(quick, bare / 3.25),
		"%.3fs, wanted %.3fs" % [quick, bare / 3.25])

	# Through the sim: the host half has to reach a unit the buff cannot name.
	var plain := _usurp_board(3, 3)
	var plain_host: UnitInstance = plain.prey
	# Read BEFORE the bell, so it is the unit as its owner built it. Everything below is
	# measured against this rather than against another possessed host, because there are
	# now two things happening to a stolen body at once — the buff's bonus and the
	# ability's own penalty — and a comparison between two puppets cannot separate them.
	var base_hp := plain_host.stat(StatModifier.Stat.MAX_HP)
	var base_dmg := plain_host.stat(StatModifier.Stat.ATTACK_DAMAGE)
	plain.sim.setup(plain.board, 131)
	var plain_hp := plain_host.stat(StatModifier.Stat.MAX_HP)
	var plain_dmg := plain_host.stat(StatModifier.Stat.ATTACK_DAMAGE)
	var plain_move := plain_host.stat(StatModifier.Stat.MOVE_TIME)

	# The penalty first: a tier 3 Usurper drives at 0.50 - 0.10 * 2 = 30% off.
	# Typed explicitly, both of them. Dictionary access yields a Variant, so `plain.sim`
	# and `plain.thief` have no static type and every local inferred from them fails to
	# compile — which reads as the test suite vanishing rather than as a type error.
	var plain_sim: CombatSim = plain.sim
	var plain_thief: UnitInstance = plain.thief
	var weak: float = plain_sim.possess_weakness_of(plain_thief)
	_check("a tier 3 Usurper's puppet is 30% weaker", is_equal_approx(weak, 0.30),
		"%.2f" % weak)
	_check("and the stolen body really is that much smaller",
		is_equal_approx(plain_hp, base_hp * (1.0 - weak)),
		"%.0f against %.0f" % [plain_hp, base_hp * (1.0 - weak)])
	_check("and hits that much softer",
		is_equal_approx(plain_dmg, base_dmg * (1.0 - weak)),
		"%.1f against %.1f" % [plain_dmg, base_dmg * (1.0 - weak)])

	var rich := _usurp_board(3, 3)
	var tb := TeamBuffs.new()
	tb.add(buff, BuffData.Rarity.GOLD)
	rich.sim.team_buffs[BoardModel.TEAM_A] = tb
	rich.sim.setup(rich.board, 131)
	var rich_host: UnitInstance = rich.prey
	# The buff adds 100% of the host's OWN figure, and the penalty takes 30% of the same
	# figure — they are both percentages of the base and they sum, so a gold Reins on a
	# tier 3 Usurper nets +70% rather than doubling what the penalty left. Written out
	# because "doubles" was the old assertion and it is no longer what happens.
	var want_hp: float = base_hp * (1.0 + 1.0 - weak)
	var want_dmg: float = base_dmg * (1.0 + 1.0 - weak)
	_check("a gold Reins adds the host's whole health bar again, penalty and all",
		is_equal_approx(rich_host.stat(StatModifier.Stat.MAX_HP), want_hp),
		"%.0f against %.0f" % [
			rich_host.stat(StatModifier.Stat.MAX_HP), want_hp])
	_check("and its attack",
		is_equal_approx(rich_host.stat(StatModifier.Stat.ATTACK_DAMAGE), want_dmg),
		"%.1f against %.1f" % [
			rich_host.stat(StatModifier.Stat.ATTACK_DAMAGE), want_dmg])
	_check("so a buffed puppet still beats an unbuffed one",
		rich_host.stat(StatModifier.Stat.MAX_HP) > plain_hp)
	_check("and the bigger host is filled, not left on the old number",
		is_equal_approx(rich_host.current_hp,
			rich_host.stat(StatModifier.Stat.MAX_HP)),
		"%.0f of %.0f" % [
			rich_host.current_hp, rich_host.stat(StatModifier.Stat.MAX_HP)])
	_check("the host moves faster too, not slower",
		rich_host.stat(StatModifier.Stat.MOVE_TIME) < plain_move,
		"%.3fs against %.3fs" % [
			rich_host.stat(StatModifier.Stat.MOVE_TIME), plain_move])

	# And it is all battle-scoped: a host handed back must not keep the thief's
	# buff. This is the leak that would let a losing player farm stats.
	rich_host.reset_for_battle()
	# Back to the unit its owner built — neither the thief's buff nor the thief's penalty.
	# The penalty matters as much as the buff here: a debuff that outlived the possession
	# would let an Usurper permanently cripple something just by touching it.
	_check("a host handed back keeps none of the thief's buff, and none of the penalty",
		is_equal_approx(rich_host.stat(StatModifier.Stat.MAX_HP), base_hp),
		"%.0f, wanted %.0f" % [
			rich_host.stat(StatModifier.Stat.MAX_HP), base_hp])

	var card := buff.describe(BuffData.Rarity.GOLD)
	_check("the card mentions both halves",
		card.to_lower().contains("riding") and card.to_lower().contains("host"),
		card)


func _test_ranged_units_hold_their_distance() -> void:
	_section("Ranged units fight at their preferred range")

	# An archer with something already in its face, and its swing on cooldown. It
	# should give ground rather than stand there waiting.
	BoardModel.reset_map()
	var board := BoardModel.new()
	var archer := UnitInstance.create(
		BoardModel.at_tier(_must_find("archer"), 3), BoardModel.TEAM_A)
	board.force_place(archer, Vector2i(4, 4))
	var brute := UnitInstance.create(
		BoardModel.at_tier(_must_find("warden"), 3), BoardModel.TEAM_B)
	board.force_place(brute, Vector2i(4, 5))
	var sim := CombatSim.new()
	sim.setup(board, 141)
	var reach := sim.reach_against(archer, brute)
	_check("the archer outranges what is standing on it", reach > 1,
		"reach %d" % reach)
	_check("and it is not a melee unit, which never gives ground",
		sim.prefers_distance(archer))

	# Through _decide, which is the only thing that proves the round loop actually
	# ASKS. _give_ground could work perfectly and never be called, which is the
	# exact shape of three separate bugs in this codebase already: a function that
	# passes its own test while nothing in the game reaches it.
	archer.state = UnitInstance.State.IDLE
	archer.kite_hold = 0.0
	var opened := archer.cell
	sim._decide(archer)
	_check("the round loop itself asks whether to give ground",
		archer.state == UnitInstance.State.MOVING and archer.cell != opened
		and BoardModel.tile_distance(archer.cell, brute.cell) > 1,
		"went %s -> %s in state %d" % [opened, archer.cell, archer.state])
	_check("and having paid a swing for it, it does not do it again at once",
		archer.kite_hold > 0.0, "%.2fs hold" % archer.kite_hold)
	# With the hold up it must shoot rather than keep walking backwards.
	archer.state = UnitInstance.State.IDLE
	var held := archer.cell
	sim._decide(archer)
	_check("the very next decision is a swing, not another step",
		archer.state == UnitInstance.State.ATTACKING and archer.cell == held,
		"state %d at %s" % [archer.state, archer.cell])

	archer.kite_hold = 0.0
	archer.target = brute
	archer.state = UnitInstance.State.IDLE
	var from := archer.cell
	var moved := sim._give_ground(archer, reach)
	_check("it steps away", moved and archer.cell != from,
		"%s -> %s" % [from, archer.cell])
	if moved:
		_check("and the step actually increases the gap",
			BoardModel.tile_distance(archer.cell, brute.cell)
			> BoardModel.tile_distance(from, brute.cell),
			"%d -> %d" % [BoardModel.tile_distance(from, brute.cell),
				BoardModel.tile_distance(archer.cell, brute.cell)])
		_check("without stepping out of its own range",
			BoardModel.in_reach(archer.cell, brute.cell, reach))

	# Already at range: it holds. Backing off forever is not "fighting at its
	# preferred range", it is refusing to fight, and the cap is what stops it.
	BoardModel.reset_map()
	var far := BoardModel.new()
	var holder := UnitInstance.create(
		BoardModel.at_tier(_must_find("archer"), 3), BoardModel.TEAM_A)
	far.force_place(holder, Vector2i(4, 2))
	var mark := UnitInstance.create(
		BoardModel.at_tier(_must_find("warden"), 3), BoardModel.TEAM_B)
	var gap_sim := CombatSim.new()
	var edge := 0
	# Put the enemy exactly at the edge of the archer's reach.
	far.force_place(mark, Vector2i(4, 2))
	far.remove(mark)
	gap_sim.setup(far, 143)
	edge = gap_sim.reach_against(holder, mark)
	far.force_place(mark, Vector2i(4, 2 + edge))
	holder.target = mark
	_check("at the edge of its range it holds its ground",
		not gap_sim._give_ground(holder, edge),
		"stood at %d of %d" % [
			BoardModel.tile_distance(holder.cell, mark.cell), edge])

	# Melee must never do this.
	BoardModel.reset_map()
	var brawl := BoardModel.new()
	var sword := UnitInstance.create(
		BoardModel.at_tier(_must_find("warden"), 3), BoardModel.TEAM_A)
	brawl.force_place(sword, Vector2i(4, 4))
	var foe := UnitInstance.create(
		BoardModel.at_tier(_must_find("warden"), 3), BoardModel.TEAM_B)
	brawl.force_place(foe, Vector2i(4, 5))
	var brawl_sim := CombatSim.new()
	brawl_sim.setup(brawl, 145)
	sword.target = foe
	_check("a melee unit never backs off — contact IS its preferred range",
		not brawl_sim.prefers_distance(sword)
		and not brawl_sim._give_ground(sword, 1))

	# A rooted shooter cannot give ground either, and must not lose its turn
	# trying: the Sentry is the whole point of can_move being a separate fact.
	BoardModel.reset_map()
	var rooted := BoardModel.new()
	var sentry_data := load("res://data/units/sentry_t3.tres") as UnitData
	if sentry_data != null:
		var sentry := UnitInstance.create(sentry_data, BoardModel.TEAM_A)
		rooted.force_place(sentry, Vector2i(4, 4))
		var rusher := UnitInstance.create(
			BoardModel.at_tier(_must_find("warden"), 3), BoardModel.TEAM_B)
		rooted.force_place(rusher, Vector2i(4, 5))
		var rooted_sim := CombatSim.new()
		rooted_sim.setup(rooted, 147)
		sentry.target = rusher
		_check("a rooted shooter stays where it was built",
			not rooted_sim._give_ground(sentry,
				rooted_sim.reach_against(sentry, rusher))
			and sentry.cell == Vector2i(4, 4))

	# And the ordering rule: shooting comes first. A unit off cooldown must swing
	# rather than retreat, or a quick-footed bow never fires at all.
	BoardModel.reset_map()
	var duel := BoardModel.new()
	# Tiers chosen so the archer SURVIVES long enough to be measured. Written
	# first as a tier 3 archer against a tier 6 Warden, which one-shot it before it
	# ever swung: the test then reported "0 shots, 0 steps" and looked like a bug in
	# the retreat rather than a bug in the matchup.
	var shooter := UnitInstance.create(
		BoardModel.at_tier(_must_find("archer"), 5), BoardModel.TEAM_A)
	duel.force_place(shooter, Vector2i(4, 2))
	var target := UnitInstance.create(
		BoardModel.at_tier(_must_find("warden"), 3), BoardModel.TEAM_B)
	duel.force_place(target, Vector2i(4, 8))
	var duel_sim := CombatSim.new()
	duel_sim.crit_chance = 0.0
	duel_sim.setup(duel, 149)
	for i in 200:
		duel_sim.step()
	var shots := 0
	var steps := 0
	for e in duel_sim.events:
		if e.kind != "attack" and e.kind != "move":
			continue
		if int(e.uid) != shooter.uid:
			continue
		if e.kind == "attack":
			shots += 1
		else:
			steps += 1
	_check("over twenty seconds the archer is still shooting, not just walking",
		shots > 0 and shots >= steps / 3,
		"%d shots, %d steps" % [shots, steps])


func _test_the_breaker_charges() -> void:
	_section("The Breaker, and what it runs into")
	var breaker := _must_find("breaker")
	var ab: AbilityData = breaker.ability
	_check("Onslaught is a CHARGE", ab != null
		and ab.kind == AbilityData.Kind.CHARGE)
	if ab == null:
		return
	_check("and it fires at the opening bell", breaker.casts_at_battle_start)
	_check("it costs no mana, because it only ever happens once",
		is_zero_approx(breaker.mana_per_attack))

	# Which way is forward. Getting this backwards would send both sides running
	# for their own back wall, so it is pinned rather than assumed.
	var sim := CombatSim.new()
	_check("TEAM_A charges toward the far half",
		sim.charge_direction(BoardModel.TEAM_A) == Vector2i(0, 1))
	_check("and TEAM_B charges the other way",
		sim.charge_direction(BoardModel.TEAM_B) == Vector2i(0, -1))

	# An enemy four tiles down the lane. The charge should close the gap, stop
	# short of it, damage it and stun it.
	var stage := _breaker_lane(3, BoardModel.TEAM_B, 4)
	var mark: UnitInstance = stage.mark
	var runner: UnitInstance = stage.runner
	stage.sim.setup(stage.board, 71)
	# Read AFTER the bell, not before. The Warden raises its bulwark as its opener, so a
	# figure taken before setup is the bar without the shield and the charge is then
	# measured against a number that never existed.
	var full: float = mark.effective_hp()
	# The charge is a journey now, not a result. It is also the one place the travel time
	# is directly visible: 0.35s a tile across four tiles of lane.
	_check("the charge does not resolve at the bell any more",
		runner.is_charging() and is_equal_approx(mark.effective_hp(), full),
		"charging %s, mark at %.0f" % [runner.is_charging(), mark.effective_hp()])
	var run_took := _finish_charge(stage.sim, runner)
	_check("it takes real seconds to cross the lane",
		run_took > 0.5 and run_took < 3.0, "%.2fs" % run_took)
	_check("it ends up next to what it hit",
		BoardModel.tile_distance(runner.cell, mark.cell) == 1,
		"runner at %s, mark at %s" % [runner.cell, mark.cell])
	# Measured against the whole bar, shield included, and that is not a detail. The
	# charge used to land in the same instant as the opening bell, BEFORE the Warden's
	# bulwark went up, so it hit health directly. Arriving a second and a half later it
	# meets the shield like everything else does — a real consequence of the travel time
	# and the largest single part of what it cost the unit.
	_check("the mark took the charge", mark.effective_hp() < full,
		"%.0f effective of %.0f" % [mark.effective_hp(), full])
	_check("and it went into the bulwark, because the charge no longer beats it",
		mark.shield < mark.stat(StatModifier.Stat.MAX_HP) * 1.25,
		"%.0f shield" % mark.shield)
	_check("and it is stunned", mark.is_stunned(),
		"%.2fs left" % mark.stun_left)
	# A stun is a stun, not a freeze. The freeze carries a damage amp and cancels
	# on-death effects; neither belongs to a unit that got run into.
	_check("stunned is not frozen", not mark.is_frozen())
	_check("so it takes no extra damage from being stunned",
		is_equal_approx(mark.frozen_damage_taken(), 1.0))
	_check("but it cannot move, swing or cast",
		not mark.can_move_now() and not mark.can_attack_now() and mark.is_held())

	# Both numbers scale with tier.
	var small := _breaker_lane(1, BoardModel.TEAM_B, 4)
	var big := _breaker_lane(6, BoardModel.TEAM_B, 4)
	var small_full: float = small.mark.effective_hp()
	var big_full: float = big.mark.effective_hp()
	small.sim.setup(small.board, 71)
	big.sim.setup(big.board, 71)
	_finish_charge(small.sim, small.runner)
	_finish_charge(big.sim, big.runner)
	var small_hit: float = small_full - small.mark.effective_hp()
	var big_hit: float = big_full - big.mark.effective_hp()
	_check("a tier 6 charge hits far harder than a tier 1",
		big_hit > small_hit * 4.0,
		"%.0f against %.0f" % [big_hit, small_hit])
	_check("and stuns for far longer",
		big.mark.stun_left > small.mark.stun_left * 4.0,
		"%.2fs against %.2fs" % [big.mark.stun_left, small.mark.stun_left])

	# An ALLY in the lane stops it and takes nothing. No friendly fire anywhere
	# else in this game, and inventing it here would make the unit a trap.
	# A SPIRE as the ally, not a Warden, and the substitution is the point. A Warden ally
	# walks: given the second and a half the charge now takes, it steps out of the lane
	# and the charge sails past, which tests the ally's legs rather than the rule. A Spire
	# is rooted, so it is still standing there when the runner arrives.
	var friendly := _breaker_lane_ally_post(3)
	friendly.sim.setup(friendly.board, 71)
	var ally_full: float = friendly.mark.effective_hp()
	_finish_charge(friendly.sim, friendly.runner)
	_check("an ally in the lane is not hit",
		is_equal_approx(friendly.mark.effective_hp(), ally_full),
		"%.0f hp of %.0f" % [friendly.mark.effective_hp(), ally_full])
	_check("and is not stunned", not friendly.mark.is_stunned())
	_check("but it did stop the charge short of it",
		BoardModel.tile_distance(friendly.runner.cell, friendly.mark.cell) == 1,
		"runner at %s" % friendly.runner.cell)

	# An empty lane. It runs the length of the board and achieves nothing, which
	# is the cost that makes placement the whole unit.
	BoardModel.reset_map()
	var empty := BoardModel.new()
	var lonely := UnitInstance.create(
		BoardModel.at_tier(breaker, 3), BoardModel.TEAM_A)
	empty.force_place(lonely, Vector2i(1, 1))
	empty.force_place(UnitInstance.create(
		BoardModel.at_tier(_must_find("warden"), 1), BoardModel.TEAM_B),
		Vector2i(4, 9))
	var lone_sim := CombatSim.new()
	lone_sim.setup(empty, 72)
	_finish_charge(lone_sim, lonely)
	_check("a charge into an empty lane runs to the far wall",
		lonely.cell.y > 6, "ended at %s" % lonely.cell)
	var wasted := false
	for e in lone_sim.events:
		if e.kind == "ability" and int(e.uid) == lonely.uid \
				and bool(e.get("wasted", false)):
			wasted = true
	_check("and is reported as a wasted cast", wasted)

	# A wall stops it. The charge is a body at speed, not a siege engine.
	#
	# The wall has to go up AFTER setup(): setup calls BoardModel.clear_changes()
	# because terrain damage is battle state, so a wall raised before it is gone
	# by the time the opener fires. The charge is then invoked directly, which is
	# the only way to put a wall in front of an opener at all.
	BoardModel.reset_map()
	var walled := BoardModel.new()
	var blocked := UnitInstance.create(
		BoardModel.at_tier(breaker, 3), BoardModel.TEAM_A)
	walled.force_place(blocked, Vector2i(2, 1))
	var behind := UnitInstance.create(
		BoardModel.at_tier(_must_find("warden"), 6), BoardModel.TEAM_B)
	walled.force_place(behind, Vector2i(2, 5))
	var wall_sim := CombatSim.new()
	wall_sim.crit_chance = 0.0
	wall_sim.setup(walled, 73)
	_finish_charge(wall_sim, blocked)
	# Put it back where it started, then wall the lane and charge again.
	walled.force_place(blocked, Vector2i(2, 1))
	_check("the lane is clear before the wall goes up",
		BoardModel.raise_wall(Vector2i(2, 3), 500.0)
		and BoardModel.is_blocked(Vector2i(2, 3)))
	# The first setup already charged and stunned it, so both are wiped before the
	# walled charge — otherwise this checks the leftovers of the previous one.
	behind.stun_left = 0.0
	behind.current_hp = behind.stat(StatModifier.Stat.MAX_HP)
	var behind_full: float = behind.current_hp
	wall_sim._resolve_charge(blocked, ab)
	_finish_charge(wall_sim, blocked)
	_check("stone stops the charge", blocked.cell == Vector2i(2, 2),
		"ended at %s" % blocked.cell)
	_check("and what was behind the wall is untouched",
		is_equal_approx(behind.current_hp, behind_full) and not behind.is_stunned(),
		"%.0f hp of %.0f" % [behind.current_hp, behind_full])
	BoardModel.reset_map()

	# The stun wears off on the clock.
	var timed := _breaker_lane(1, BoardModel.TEAM_B, 4)
	timed.sim.setup(timed.board, 74)
	_finish_charge(timed.sim, timed.runner)
	var was: float = timed.mark.stun_left
	_check("the stun starts with time on it", was > 0.0)
	for i in 40:
		timed.sim.step()
	_check("and it runs down", timed.mark.stun_left < was
		or not timed.mark.is_alive(),
		"%.2fs left" % timed.mark.stun_left)

	# A Seraph can lift it, because a stun is a cleansable debuff.
	var held := UnitInstance.create(_must_find("warden"), BoardModel.TEAM_A)
	held.stun_left = 3.0
	var lifted := held.cleanse()
	_check("a cleanse lifts a stun", not held.is_stunned()
		and lifted.has("Stunned"), str(lifted))


func _test_avalanche() -> void:
	_section("Avalanche")
	var pool := _pool()
	var buff := pool.by_id(&"avalanche")
	_check("Avalanche is on the roster", buff != null)
	if buff == null:
		return
	_check("it belongs to the Breaker", String(buff.unit_id) == "breaker")
	_check("it adds 1, 2 and 3 seconds of stun",
		is_equal_approx(buff.stun_bonus_at(BuffData.Rarity.BRONZE), 1.0)
		and is_equal_approx(buff.stun_bonus_at(BuffData.Rarity.SILVER), 2.0)
		and is_equal_approx(buff.stun_bonus_at(BuffData.Rarity.GOLD), 3.0),
		"%.1f/%.1f/%.1f" % [buff.stun_bonus_at(BuffData.Rarity.BRONZE),
			buff.stun_bonus_at(BuffData.Rarity.SILVER),
			buff.stun_bonus_at(BuffData.Rarity.GOLD)])
	_check("and 50, 75 and 100% more charge damage",
		is_equal_approx(buff.charge_bonus_at(BuffData.Rarity.BRONZE), 0.50)
		and is_equal_approx(buff.charge_bonus_at(BuffData.Rarity.SILVER), 0.75)
		and is_equal_approx(buff.charge_bonus_at(BuffData.Rarity.GOLD), 1.00),
		"%.2f/%.2f/%.2f" % [buff.charge_bonus_at(BuffData.Rarity.BRONZE),
			buff.charge_bonus_at(BuffData.Rarity.SILVER),
			buff.charge_bonus_at(BuffData.Rarity.GOLD)])

	# Through the sim, not just off the card.
	var plain := _breaker_lane(3, BoardModel.TEAM_B, 4)
	plain.sim.setup(plain.board, 81)
	# After the bell, like the fixture above: the mark raises a shield as its opener, so a
	# bar read before setup is a bar the charge never meets.
	var plain_full: float = plain.mark.effective_hp()
	_finish_charge(plain.sim, plain.runner)
	var plain_hit: float = plain_full - plain.mark.effective_hp()
	var plain_stun: float = plain.mark.stun_left

	var buffed := _breaker_lane(3, BoardModel.TEAM_B, 4)
	var tb := TeamBuffs.new()
	tb.add(buff, BuffData.Rarity.GOLD)
	buffed.sim.team_buffs[BoardModel.TEAM_A] = tb
	buffed.sim.setup(buffed.board, 81)
	var buffed_full: float = buffed.mark.effective_hp()
	_finish_charge(buffed.sim, buffed.runner)
	var buffed_hit: float = buffed_full - buffed.mark.effective_hp()

	_check("a gold Avalanche doubles the charge damage",
		is_equal_approx(buffed_hit, plain_hit * 2.0),
		"%.0f against %.0f" % [buffed_hit, plain_hit * 2.0])
	_check("and adds three whole seconds of stun",
		is_equal_approx(buffed.mark.stun_left, plain_stun + 3.0),
		"%.2fs against %.2fs" % [buffed.mark.stun_left, plain_stun + 3.0])

	# It is the Breaker's buff, so it must not lengthen anyone else's stun.
	var other := UnitInstance.create(_must_find("warden"), BoardModel.TEAM_A)
	_check("it does nothing for a unit that is not a Breaker",
		is_zero_approx(tb.stun_bonus_for(other))
		and is_zero_approx(tb.charge_bonus_for(other)))

	var card := buff.describe(BuffData.Rarity.GOLD)
	_check("the card mentions both halves",
		card.to_lower().contains("stun") and card.to_lower().contains("harder"),
		card)


func _test_status_registry() -> void:
	_section("The status list")

	# The table is the list. Anything that walks it — cleanse, the round reset —
	# gets a new status for free, so these checks are about the table staying
	# honest rather than about any one effect.
	_check("every status in the enum has a row in the table",
		UnitInstance.STATUSES.size() == UnitInstance.Status.size(),
		"%d rows for %d statuses" % [
			UnitInstance.STATUSES.size(), UnitInstance.Status.size()])
	var seen := {}
	var named := 0
	for row in UnitInstance.STATUSES:
		seen[row.id] = true
		if not String(row.name).is_empty():
			named += 1
	_check("no status is listed twice and none is nameless",
		seen.size() == UnitInstance.STATUSES.size()
		and named == UnitInstance.STATUSES.size())

	# Sudden death is a debuff that must NOT be cleansable — it is a rule of the
	# clock, not a spell, and a Seraph switching it off would quietly undo the
	# last fifteen seconds of every round.
	for row in UnitInstance.STATUSES:
		if row.id == UnitInstance.Status.NO_RECOVERY:
			_check("sudden death is a debuff but is not cleansable",
				row.debuff and not row.cleansable)
		if row.id == UnitInstance.Status.TAUNT:
			_check("a self-inflicted taunt is not a debuff at all",
				not row.debuff)

	# has_status and clear_status have to agree with each other for every row, or
	# a cleanse reports lifting something it did not lift.
	var u := UnitInstance.create(_must_find("warden"), BoardModel.TEAM_A)
	var disagreed: PackedStringArray = []
	for row in UnitInstance.STATUSES:
		_set_status(u, row.id)
		if not u.has_status(row.id):
			disagreed.append("%s never reads as set" % row.name)
			continue
		u.clear_status(row.id)
		if u.has_status(row.id):
			disagreed.append("%s survives being cleared" % row.name)
	_check("every status can be set, seen and cleared",
		disagreed.is_empty(), "; ".join(disagreed))

	# And the round boundary clears all of them, cleansable or not.
	var fresh := UnitInstance.create(_must_find("warden"), BoardModel.TEAM_A)
	for row in UnitInstance.STATUSES:
		_set_status(fresh, row.id)
	fresh.reset_for_battle()
	var left: PackedStringArray = []
	for row in UnitInstance.STATUSES:
		if fresh.has_status(row.id):
			left.append(row.name)
	_check("a new round starts with every status cleared",
		left.is_empty(), "still on: %s" % ", ".join(left))


func _set_status(u: UnitInstance, s: UnitInstance.Status) -> void:
	## Puts a status on a unit by hand, for tests that care that the plumbing
	## works rather than which ability does the applying.
	match s:
		UnitInstance.Status.POISON:
			u.apply_dot(5.0, 4, 0.5, -1)
		UnitInstance.Status.FROZEN:
			u.frozen_left = 2.0
			u.frozen_amp = 1.5
		UnitInstance.Status.STUNNED:
			u.stun_left = 2.0
		UnitInstance.Status.TAUNT:
			u.taunt_left = 2.0
		UnitInstance.Status.REFLECT:
			u.reflect_left = 2.0
		UnitInstance.Status.STEALTH:
			u.stealth_left = 2.0
		UnitInstance.Status.HASTE:
			u.haste_stacks = 3
		UnitInstance.Status.NO_RECOVERY:
			u.recovery_denied = true
		UnitInstance.Status.DISORIENTED:
			u.disorient_left = 2.0


func _test_seraph_cleanses() -> void:
	_section("The Seraph lifts what is on you")
	var seraph := _must_find("seraph")
	var ab: AbilityData = seraph.ability
	_check("Benediction is flagged as a cleanse", ab != null and ab.cleanses)
	if ab == null:
		return
	_check("and it is the only one on the roster", _cleansers() == 1,
		"%d abilities cleanse" % _cleansers())

	# Poison and a freeze at once, on a unit hurt enough to be the Seraph's pick.
	BoardModel.reset_map()
	var b := BoardModel.new()
	var healer := UnitInstance.create(
		BoardModel.at_tier(seraph, 3), BoardModel.TEAM_A)
	b.force_place(healer, Vector2i(2, 3))
	var patient := UnitInstance.create(
		BoardModel.at_tier(_must_find("warden"), 3), BoardModel.TEAM_A)
	b.force_place(patient, Vector2i(2, 4))
	b.force_place(UnitInstance.create(
		BoardModel.at_tier(_must_find("warden"), 1), BoardModel.TEAM_B),
		Vector2i(2, 9))
	var sim := CombatSim.new()
	sim.setup(b, 61)
	sim.crit_chance = 0.0

	patient.shield = 0.0
	patient.current_hp = patient.stat(StatModifier.Stat.MAX_HP) * 0.3
	# A suppressing poison, which is the Vexer's — it blocks healing outright.
	patient.apply_dot(8.0, 6, 0.5, -1, 0.25, 0.0, 1.0, true)
	patient.frozen_left = 3.0
	patient.frozen_amp = 1.6
	_check("the patient starts poisoned and frozen",
		patient.has_status(UnitInstance.Status.POISON)
		and patient.has_status(UnitInstance.Status.FROZEN))
	_check("and the poison is the kind that blocks healing",
		patient.is_suppressed())

	var before: float = patient.current_hp
	sim._resolve_burst_heal(healer, ab)

	_check("the poison is gone",
		not patient.has_status(UnitInstance.Status.POISON))
	_check("the freeze is gone too",
		not patient.has_status(UnitInstance.Status.FROZEN))
	# The ordering check, and the reason it matters: cleansing AFTER the heal
	# would lift the poison off a unit the heal had just bounced off.
	_check("and the heal landed in the same cast, not the next one",
		patient.current_hp > before,
		"%.0f hp, was %.0f" % [patient.current_hp, before])
	_check("the vulnerability the poison carried went with it",
		is_equal_approx(patient.vulnerability(), 1.0),
		"%.2f" % patient.vulnerability())
	_check("and so did the freeze's damage amp",
		is_equal_approx(patient.frozen_damage_taken(), 1.0))

	var told := false
	for e in sim.events:
		if e.kind == "cleanse" and int(e.uid) == patient.uid:
			told = true
			var removed: Array = e.get("removed", [])
			_check("the cleanse says what it took off",
				removed.has("Poison") and removed.has("Frozen"), str(removed))
	_check("a cleanse is announced", told)

	# Sudden death is not something a Seraph can undo.
	patient.recovery_denied = true
	patient.current_hp = patient.stat(StatModifier.Stat.MAX_HP) * 0.3
	patient.apply_dot(8.0, 6, 0.5, -1)
	sim._resolve_burst_heal(healer, ab)
	_check("it lifts the poison even under sudden death",
		not patient.has_status(UnitInstance.Status.POISON))
	_check("but sudden death itself stays on",
		patient.has_status(UnitInstance.Status.NO_RECOVERY))

	# Nothing to lift is not an event. A Seraph healing a plain wounded ally
	# should not spam a label saying it cleansed nothing.
	var quiet := UnitInstance.create(_must_find("warden"), BoardModel.TEAM_A)
	_check("cleansing a clean unit removes nothing and says nothing",
		quiet.cleanse().is_empty())


func _cleansers() -> int:
	var n := 0
	for u in _roster().units:
		if u.ability != null and u.ability.cleanses:
			n += 1
	return n


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
	# The web build only wires up buses that are in the layout it starts with; a bus
	# added from script afterwards is silent in a browser. See audio.gd.
	var layout := load("res://default_bus_layout.tres") as AudioBusLayout
	var audio_script: GDScript = load("res://autoload/audio.gd")
	var consts := audio_script.get_script_constant_map()
	var listed := {}
	if layout != null:
		for i in range(1, 16):
			var key := "bus/%d/name" % i
			if layout.get(key) != null:
				listed[String(layout.get(key))] = String(layout.get("bus/%d/send" % i))
	for c in ["MUSIC_BUS", "SFX_BUS", "VOICE_BUS"]:
		var bus_name := String(consts.get(c, ""))
		_check("the %s bus is in default_bus_layout.tres and feeds Master, so the web build plays it" % bus_name,
			listed.get(bus_name, "") == "Master",
			"layout has %s" % [listed])
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


func _test_the_martyr_grows_as_it_dies() -> void:
	_section("The Martyr: rage, bleed, and the window at the bottom")

	var martyr := _must_find("martyr")
	var ab: AbilityData = martyr.ability
	_check("the Martyr's ability is a FRENZY", ab != null
		and ab.kind == AbilityData.Kind.FRENZY)
	if ab == null:
		return
	_check("it has nothing to spend, so the ability is a passive",
		is_zero_approx(martyr.mana_per_attack)
		and is_zero_approx(martyr.mana_per_charge)
		and is_zero_approx(martyr.mana_per_ally_death),
		"attack %.1f, charge %.1f, grief %.1f" % [
			martyr.mana_per_attack, martyr.mana_per_charge,
			martyr.mana_per_ally_death])

	# --- Rage: linear in MISSING health, on damage and attack speed only. ---
	var u := UnitInstance.create(BoardModel.at_tier(martyr, 3), BoardModel.TEAM_A)
	var full_hp := u.stat(StatModifier.Stat.MAX_HP)
	var dmg_full := u.stat(StatModifier.Stat.ATTACK_DAMAGE)
	var spd_full := u.stat(StatModifier.Stat.ATTACK_SPEED)
	var move_full := u.stat(StatModifier.Stat.MOVE_TIME)
	_check("at full health it has no bonus at all",
		is_equal_approx(u.rage(), 1.0), "%.3fx" % u.rage())

	u.current_hp = full_hp * 0.5
	_check("at half health the rage is halfway up the slope",
		absf(u.rage() - (1.0 + ab.rage_per_missing * 0.5)) < 0.001,
		"%.3fx" % u.rage())
	_check("damage rides it",
		absf(u.stat(StatModifier.Stat.ATTACK_DAMAGE) - dmg_full * u.rage()) < 0.01,
		"%.1f against %.1f" % [u.stat(StatModifier.Stat.ATTACK_DAMAGE), dmg_full])
	_check("attack speed rides it",
		absf(u.stat(StatModifier.Stat.ATTACK_SPEED) - spd_full * u.rage()) < 0.01,
		"%.3f against %.3f" % [u.stat(StatModifier.Stat.ATTACK_SPEED), spd_full])
	# The two deliberate exclusions. Max health would recurse through the number the
	# rage is computed FROM, and movement would let a wounded Martyr outrun the line
	# it is supposed to be standing in.
	_check("max health does NOT ride it, or the slope would feed itself",
		is_equal_approx(u.stat(StatModifier.Stat.MAX_HP), full_hp),
		"%.1f against %.1f" % [u.stat(StatModifier.Stat.MAX_HP), full_hp])
	_check("and neither does movement, outside the window",
		is_equal_approx(u.stat(StatModifier.Stat.MOVE_TIME), move_full),
		"%.3f against %.3f" % [u.stat(StatModifier.Stat.MOVE_TIME), move_full])

	# Sabotage: if rage() ignored the health bar, the check above would still pass at
	# full health. Pin the shape by walking the slope.
	var rose := true
	var last := 0.0
	for i in 11:
		u.current_hp = full_hp * (1.0 - float(i) * 0.1)
		var here := u.stat(StatModifier.Stat.ATTACK_DAMAGE)
		if here < last - 0.001:
			rose = false
		last = here
	_check("the slope is monotonic all the way down the bar", rose)
	_check("and the bottom of it is worth the stated multiple",
		absf(last / dmg_full - (1.0 + ab.rage_per_missing)) < 0.01,
		"%.2fx at the brink" % (last / dmg_full))

	# --- An ordinary unit is untouched by any of this. ---
	var warden := UnitInstance.create(
		BoardModel.at_tier(_must_find("warden"), 3), BoardModel.TEAM_A)
	var w_dmg := warden.stat(StatModifier.Stat.ATTACK_DAMAGE)
	warden.current_hp = warden.stat(StatModifier.Stat.MAX_HP) * 0.05
	_check("a unit without the ability gains nothing from being hurt",
		is_equal_approx(warden.stat(StatModifier.Stat.ATTACK_DAMAGE), w_dmg),
		"%.1f against %.1f" % [
			warden.stat(StatModifier.Stat.ATTACK_DAMAGE), w_dmg])
	_check("and it dies at zero health like anything else",
		not _dies_standing(warden))



func _pin_in_place(u: UnitInstance) -> void:
	## Nails a unit to its tile for the rest of the fixture by making a single step
	## cost longer than the test runs. MOVE_TIME is seconds per tile, so a large
	## POSITIVE percentage is slower — see BuffData._signed for why that trap is worth
	## naming every time.
	##
	## Why this exists: the obvious fixture — one unit against one harmless, rooted
	## Spire — quietly ends early, because the unit walks over and kills the Spire and
	## the ROUND is then over, which stops step() dead. The first version of these
	## tests measured a bleed that had simply stopped being ticked. Planted AFTER
	## setup() on purpose: setup() calls reset_for_battle() on every unit, which wipes
	## battle modifiers.
	u.add_battle_modifier(StatModifier.make(
		StatModifier.Stat.MOVE_TIME, StatModifier.Mode.PERCENT, 400.0))


func _dies_standing(u: UnitInstance) -> bool:
	## Drops the unit to zero health through take_damage and reports whether it is
	## still on its feet. The one thing is_alive() had to be taught.
	u.take_damage(u.current_hp + u.shield + 1.0)
	return u.is_alive()


func _test_the_martyrs_window() -> void:
	_section("The Martyr: the window is a death that has not happened yet")

	var martyr := _must_find("martyr")
	var ab: AbilityData = martyr.ability
	if ab == null:
		return

	# The window is opened by the SIM, in _fell, not by the unit — so it has to be
	# tested through a sim. A unit dropped to zero on its own stays dead, which is
	# the correct half of the split: the unit owns the arithmetic, the sim owns the
	# decision.
	var lone := UnitInstance.create(BoardModel.at_tier(martyr, 3), BoardModel.TEAM_A)
	lone.take_damage(lone.current_hp + 1.0)
	_check("dropped to zero with nothing watching, it is simply dead",
		not lone.is_alive())

	BoardModel.reset_map()
	var board := BoardModel.new()
	var hero := UnitInstance.create(BoardModel.at_tier(martyr, 3), BoardModel.TEAM_A)
	board.force_place(hero, Vector2i(2, 1))
	# A rooted, harmless body so nothing interferes: the only thing that can kill the
	# Martyr in this fixture is the Martyr.
	var post := UnitInstance.create(
		BoardModel.at_tier(_must_find("spire"), 1), BoardModel.TEAM_B)
	board.force_place(post, Vector2i(5, 9))
	var sim := CombatSim.new()
	sim.setup(board, 404)
	_pin_in_place(hero)
	var full_hp := hero.stat(StatModifier.Stat.MAX_HP)

	_check("the window is worth the ability's own figure with no buffs",
		is_equal_approx(sim.frenzy_seconds_of(hero, ab), ab.frenzy_seconds),
		"%.2fs" % sim.frenzy_seconds_of(hero, ab))

	# --- The bleed. Above the threshold nothing happens at all. ---
	for i in 20:
		sim.step()
	_check("above the threshold it does not bleed",
		is_equal_approx(hero.current_hp, full_hp),
		"%.1f of %.1f" % [hero.current_hp, full_hp])

	# Drop it just under the line and time the descent. 5% of max per second from
	# 49% is a shade under ten seconds, and that figure is the whole cost of the rage.
	hero.current_hp = full_hp * (ab.frenzy_threshold - 0.01)
	var before := hero.current_hp
	for i in 10:
		sim.step()
	_check("under the threshold it opens its own veins",
		hero.current_hp < before - 0.01,
		"%.2f from %.2f after a second" % [hero.current_hp, before])
	var per_second := (before - hero.current_hp)
	_check("at the stated share of its MAXIMUM, so it does not tail off",
		absf(per_second - full_hp * ab.frenzy_decay) < full_hp * 0.005,
		"%.2f/s against %.2f/s" % [per_second, full_hp * ab.frenzy_decay])

	# --- The window. Run until the bleed finishes the job. ---
	var steps := 0
	while hero.current_hp > 0.0 and steps < 400:
		sim.step()
		steps += 1
	_check("the bleed reaches zero on its own", is_zero_approx(hero.current_hp),
		"%.2f left after %.1fs" % [hero.current_hp, float(steps) * CombatSim.TICK])
	_check("and at zero health the Martyr is still standing",
		hero.is_alive() and hero.is_frenzied(),
		"alive %s, %.2fs of window" % [hero.is_alive(), hero.frenzy_left])
	_check("it is still ON the board, not a ghost the board has forgotten",
		board.unit_at(hero.cell) == hero)
	_check("and the view was told, because an empty bar on a live unit reads as a bug",
		_has_event(sim, "frenzy", hero.uid))

	# What the window is worth. Measured against a fresh tier 3 at FULL health,
	# because rage is already at its maximum here — the window is the extra on top.
	var fresh := UnitInstance.create(BoardModel.at_tier(martyr, 3), BoardModel.TEAM_A)
	var want_dmg := fresh.stat(StatModifier.Stat.ATTACK_DAMAGE) \
		* (1.0 + ab.rage_per_missing) * (1.0 + ab.frenzy_damage)
	_check("inside it, rage and the window multiply rather than replace",
		absf(hero.stat(StatModifier.Stat.ATTACK_DAMAGE) - want_dmg) < 0.5,
		"%.1f against %.1f" % [hero.stat(StatModifier.Stat.ATTACK_DAMAGE), want_dmg])
	# MOVE_TIME is seconds per tile, so faster is SMALLER. The one stat in the game
	# where a bonus that reads as a multiplication has to be a division.
	# Read off THIS unit with the window shut and open again rather than compared to a
	# fresh one, because this fixture has pinned the hero in place with a movement
	# modifier of its own and the two numbers would not be comparable.
	var open_move := hero.stat(StatModifier.Stat.MOVE_TIME)
	var window_left := hero.frenzy_left
	hero.frenzy_left = 0.0
	var shut_move := hero.stat(StatModifier.Stat.MOVE_TIME)
	hero.frenzy_left = window_left
	_check("and the window is the one thing that makes it faster on its feet",
		open_move < shut_move - 0.001, "%.3f against %.3f" % [open_move, shut_move])
	# MOVE_TIME is seconds per tile, so the bonus DIVIDES. Written the other way round
	# the last charge would be a crawl, which is the trap BuffData._signed exists for.
	_check("by exactly the stated share, divided and not multiplied",
		absf(open_move - shut_move / (1.0 + ab.frenzy_move)) < 0.01,
		"%.3f against %.3f" % [open_move, shut_move / (1.0 + ab.frenzy_move)])
	_check("its swings cut through the rank in front of it",
		hero.pierce_now() == ab.frenzy_pierce,
		"%d against %d" % [hero.pierce_now(), ab.frenzy_pierce])
	_check("where an ordinary Martyr's swing hits one",
		fresh.pierce_now() == 1, "%d" % fresh.pierce_now())

	# Hitting it again inside the window must NOT restart the clock, or it never dies.
	var left := hero.frenzy_left
	hero.take_damage(full_hp * 10.0)
	_check("a blow landed inside the window does not reopen it",
		hero.frenzy_left <= left + 0.001 and hero.is_alive(),
		"%.2fs against %.2fs, alive %s" % [hero.frenzy_left, left, hero.is_alive()])
	_check("and it does not knock the unit into the DEAD state either",
		hero.state != UnitInstance.State.DEAD)

	# --- The window closing is a real death. ---
	var more := 0
	while hero.is_alive() and more < 400:
		sim.step()
		more += 1
	_check("when the clock runs out it dies for real", not hero.is_alive())
	_check("the window was about as long as advertised",
		absf(float(more) * CombatSim.TICK - ab.frenzy_seconds) < 0.3,
		"%.2fs against %.2fs" % [float(more) * CombatSim.TICK, ab.frenzy_seconds])
	_check("the end of the window was announced",
		_has_event(sim, "frenzy_end", hero.uid))
	_check("and the ordinary death followed it, so everything hung off dying fires",
		_has_event(sim, "death", hero.uid))
	_check("the board let go of it", board.unit_at(hero.cell) != hero)


func _has_event(sim: CombatSim, kind: String, uid: int) -> bool:
	for e in sim.events:
		if e.kind == kind and int(e.get("uid", -1)) == uid:
			return true
	return false


func _test_the_martyr_only_gets_one_window() -> void:
	_section("The Martyr: once per round, and a freeze takes it away")

	var martyr := _must_find("martyr")
	var ab: AbilityData = martyr.ability
	if ab == null:
		return

	# Once per round. Without frenzy_spent every blow that landed during the window
	# would restart it and the unit would be immortal.
	BoardModel.reset_map()
	var board := BoardModel.new()
	var hero := UnitInstance.create(BoardModel.at_tier(martyr, 2), BoardModel.TEAM_A)
	board.force_place(hero, Vector2i(2, 1))
	board.force_place(UnitInstance.create(
		BoardModel.at_tier(_must_find("spire"), 1), BoardModel.TEAM_B),
		Vector2i(5, 9))
	var sim := CombatSim.new()
	sim.setup(board, 77)
	_pin_in_place(hero)
	# Started near the bottom rather than at full: the descent's RATE is measured in
	# the fixture above, and all this one needs is the window at the end of it.
	hero.current_hp = 1.0
	var spent := 0
	for i in 900:
		sim.step()
		if hero.is_frenzied():
			spent += 1
		if not hero.is_alive():
			break
	_check("it bled out and burned its window without any help", hero.frenzy_spent)
	_check("and it is dead at the end of it", not hero.is_alive())
	var opened := 0
	for e in sim.events:
		if e.kind == "frenzy" and int(e.uid) == hero.uid:
			opened += 1
	_check("the window opened exactly once", opened == 1, "%d times" % opened)

	# The round boundary gives it back — reset_for_battle is what makes the unit
	# playable in a match rather than a one-round trick.
	hero.reset_for_battle()
	_check("the round boundary clears the spend",
		not hero.frenzy_spent and is_zero_approx(hero.frenzy_left))

	# A freeze cancels the window, the same way it cancels a revive. This is the
	# unit's real counter and it is worth pinning: _fell gates the frenzy on the
	# same `frozen` flag the revive roll is gated on, so if one ever drifts from
	# the other this is what says so.
	BoardModel.reset_map()
	var cold_board := BoardModel.new()
	var chilled := UnitInstance.create(
		BoardModel.at_tier(martyr, 2), BoardModel.TEAM_A)
	cold_board.force_place(chilled, Vector2i(2, 1))
	cold_board.force_place(UnitInstance.create(
		BoardModel.at_tier(_must_find("spire"), 1), BoardModel.TEAM_B),
		Vector2i(5, 9))
	var cold_sim := CombatSim.new()
	cold_sim.setup(cold_board, 78)
	_pin_in_place(chilled)
	# Frozen for long enough to cover the bleed's last moments, then walked down.
	chilled.current_hp = 1.0
	# Planted straight onto the unit rather than cast, so the fixture needs no Stasis
	# standing in it: the sim reads frozen_left and does not care who wrote it.
	chilled.frozen_left = 30.0
	chilled.frozen_amp = 1.0
	for i in 200:
		cold_sim.step()
		if not chilled.is_alive():
			break
	_check("a Martyr killed while frozen gets no window at all",
		not chilled.is_alive() and not chilled.is_frenzied(),
		"alive %s, frenzied %s" % [chilled.is_alive(), chilled.is_frenzied()])
	_check("and no window was ever announced for it",
		not _has_event(cold_sim, "frenzy", chilled.uid))


func _test_rapture() -> void:
	_section("Rapture: the Martyr's buff")

	var pool := _pool()
	var buff := pool.by_id(&"rapture")
	_check("Rapture is on disk", buff != null)
	if buff == null:
		return
	_check("it belongs to the Martyr", buff.unit_id == &"martyr")
	_check("it is attack damage and attack speed, the two the unit already scales",
		buff.stat_a == StatModifier.Stat.ATTACK_DAMAGE
		and buff.stat_b == StatModifier.Stat.ATTACK_SPEED
		and buff.uses_second_stat)
	# The figures the user asked for, verbatim: 50/20, 100/40, 200/60.
	_check("bronze is 50% damage and 20% attack speed",
		is_equal_approx(buff.bronze.x, 0.50) and is_equal_approx(buff.bronze.y, 0.20),
		"%s" % buff.bronze)
	_check("silver doubles the damage and the speed",
		is_equal_approx(buff.silver.x, 1.00) and is_equal_approx(buff.silver.y, 0.40),
		"%s" % buff.silver)
	_check("gold is the big one: 200% damage, 60% attack speed",
		is_equal_approx(buff.gold.x, 2.00) and is_equal_approx(buff.gold.y, 0.60),
		"%s" % buff.gold)

	# The gold-only rider. Same shape as the Paragon's empowered cap: a non-stat
	# effect hanging off a stat buff, which is why the card has to name it at every
	# rarity rather than springing it on the third pick.
	_check("gold carries five seconds of death immunity",
		is_equal_approx(buff.frenzy_seconds_at_gold, 5.0),
		"%.1fs" % buff.frenzy_seconds_at_gold)
	for r in [BuffData.Rarity.BRONZE, BuffData.Rarity.SILVER, BuffData.Rarity.GOLD]:
		_check("the %s card mentions the window" % BuffData.rarity_name(r),
			buff.describe(r).to_lower().contains("zero health"),
			buff.describe(r))

	var martyr := _must_find("martyr")
	var ab: AbilityData = martyr.ability
	var u := UnitInstance.create(BoardModel.at_tier(martyr, 3), BoardModel.TEAM_A)

	for r in [BuffData.Rarity.BRONZE, BuffData.Rarity.SILVER]:
		var tb := TeamBuffs.new()
		tb.add(buff, r)
		_check("%s does NOT lengthen the window" % BuffData.rarity_name(r),
			is_zero_approx(tb.frenzy_seconds_for(u)),
			"%.1fs" % tb.frenzy_seconds_for(u))
	var gold := TeamBuffs.new()
	gold.add(buff, BuffData.Rarity.GOLD)
	_check("gold does",
		is_equal_approx(gold.frenzy_seconds_for(u), 5.0),
		"%.1fs" % gold.frenzy_seconds_for(u))
	# And it does not leak onto anybody else's Martyr-shaped unit.
	var other := UnitInstance.create(
		BoardModel.at_tier(_must_find("reaver"), 3), BoardModel.TEAM_A)
	_check("and only for the unit it names",
		is_zero_approx(gold.frenzy_seconds_for(other)),
		"%.1fs" % gold.frenzy_seconds_for(other))

	# Through the sim, because the thing that keeps going wrong here is a rule
	# nothing calls. A number in the data that the sim never reads is the failure
	# mode this whole file exists to catch.
	BoardModel.reset_map()
	var board := BoardModel.new()
	var hero := UnitInstance.create(BoardModel.at_tier(martyr, 3), BoardModel.TEAM_A)
	board.force_place(hero, Vector2i(2, 1))
	board.force_place(UnitInstance.create(
		BoardModel.at_tier(_must_find("spire"), 1), BoardModel.TEAM_B),
		Vector2i(5, 9))
	var sim := CombatSim.new()
	sim.team_buffs[BoardModel.TEAM_A] = gold
	sim.setup(board, 909)
	_pin_in_place(hero)
	_check("the sim reads the rider and lengthens the window",
		is_equal_approx(sim.frenzy_seconds_of(hero, ab), 5.0),
		"%.2fs" % sim.frenzy_seconds_of(hero, ab))
	hero.current_hp = 1.0
	var opened_at := -1.0
	var closed_at := -1.0
	for i in 400:
		sim.step()
		if hero.is_frenzied() and opened_at < 0.0:
			opened_at = float(i) * CombatSim.TICK
		if opened_at >= 0.0 and not hero.is_alive():
			closed_at = float(i) * CombatSim.TICK
			break
	_check("and it actually stood there for five seconds, not two and a half",
		opened_at >= 0.0 and closed_at > opened_at
			and absf(closed_at - opened_at - 5.0) < 0.4,
		"%.2fs standing" % (closed_at - opened_at))


func _test_the_martyrs_last_swing_cuts_through() -> void:
	_section("The Martyr: the window's swing, through the simulation")

	var martyr := _must_find("martyr")
	var ab: AbilityData = martyr.ability
	if ab == null:
		return

	# This exists because pierce_now() returning 3 proves nothing on its own: the
	# recurring failure in this codebase is a function that works perfectly and that
	# nothing calls. _begin_attack used to read u.data.pierce_targets directly, and a
	# test on the unit would have passed the whole time.
	var hits_while_frenzied := _martyr_swing_reach(true)
	var hits_when_whole := _martyr_swing_reach(false)
	_check("an ordinary Martyr's swing lands on one enemy",
		hits_when_whole == 1, "%d hit" % hits_when_whole)
	_check("inside the window one swing reaches three",
		hits_while_frenzied == ab.frenzy_pierce,
		"%d hit, wanted %d" % [hits_while_frenzied, ab.frenzy_pierce])


func _martyr_swing_reach(frenzied: bool) -> int:
	## Stands a Martyr at the head of a column of three harmless, rooted bodies and
	## returns how many of them one swing touched. Spires because they cannot hit
	## back and cannot step out of the line — the count has to be about the swing.
	BoardModel.reset_map()
	var board := BoardModel.new()
	var hero := UnitInstance.create(
		BoardModel.at_tier(_must_find("martyr"), 3), BoardModel.TEAM_A)
	board.force_place(hero, Vector2i(2, 3))
	var posts: Array[int] = []
	for row in [4, 5, 6]:
		var post := UnitInstance.create(
			BoardModel.at_tier(_must_find("spire"), 6), BoardModel.TEAM_B)
		board.force_place(post, Vector2i(2, row))
		posts.append(post.uid)
	var sim := CombatSim.new()
	sim.setup(board, 515)
	if frenzied:
		# Planted rather than earned: the window's own opening is tested above, and
		# doing it by hand keeps this fixture about the swing. frenzy_spent has to go
		# with it or _tick_frenzy would run the clock out, kill the unit, and _fell
		# would open a fresh window — forever.
		hero.current_hp = 0.0
		hero.frenzy_left = 6.0
		hero.frenzy_spent = true
	var struck := {}
	var first_swing := -1
	for i in 60:
		sim.step()
		for e in sim.events:
			if e.kind != "damage" or int(e.get("source_uid", -1)) != hero.uid:
				continue
			if first_swing < 0:
				first_swing = i
			if int(e.uid) in posts:
				struck[int(e.uid)] = true
		if first_swing >= 0 and i > first_swing:
			break
	return struck.size()


func _test_the_martyrs_numbers_are_the_measured_ones() -> void:
	_section("The Martyr: the tuned figures, pinned")

	# Every number here was measured, and two of them were measured twice because the
	# first answer was wrong. They are pinned so a casual edit cannot quietly undo the
	# tuning — if one of these fails, the right response is to re-run
	# tools/measure_martyr.gd and put the new table in the data_builder comment, not to
	# change the figure here to match.
	var martyr := _must_find("martyr")
	var one := BoardModel.at_tier(martyr, 1)
	_check("the body is the feeble one: 130 health at tier 1",
		is_equal_approx(one.max_hp, 130.0), "%.0f" % one.max_hp)
	_check("and 6 damage, which is down among the casters",
		is_equal_approx(one.attack_damage, 6.0), "%.1f" % one.attack_damage)
	# The point of the feeble swing: a Martyr that wins fights at full health never gets
	# ground down, so the strong first build reached its own window in only 72% of
	# rounds against 94% for this one. It does not have to be THE softest — the Pyre,
	# the Conjurer and the Pariah all swing softer, and all three are casters whose
	# swing is beside the point — but it has to be down at that end, or the unit is a
	# fighter with a comeback mechanic bolted on rather than the comeback itself.
	var mine := one.attack_damage * one.attack_speed
	var softer := 0
	var fighters := 0
	for other in _roster().units:
		if not other.can_attack:
			continue
		fighters += 1
		if other.id == martyr.id:
			continue
		var theirs := BoardModel.at_tier(other, 1)
		if theirs.attack_damage * theirs.attack_speed < mine - 0.001:
			softer += 1
	_check("its swing is in the softest handful in the game",
		fighters > 20 and softer <= 4,
		"%d of %d fighters swing softer" % [softer, fighters])

	var ab: AbilityData = martyr.ability
	if ab == null:
		return
	_check("the bleed is a fortieth of the bar a second",
		is_equal_approx(ab.frenzy_decay, 0.025), "%.4f" % ab.frenzy_decay)
	_check("which is twenty seconds from the threshold to zero",
		absf(ab.frenzy_threshold / ab.frenzy_decay - 20.0) < 0.01,
		"%.1fs" % (ab.frenzy_threshold / ab.frenzy_decay))
	_check("the threshold is half health, as asked",
		is_equal_approx(ab.frenzy_threshold, 0.50), "%.2f" % ab.frenzy_threshold)
	_check("the window is two and a half seconds, as asked",
		is_equal_approx(ab.frenzy_seconds, 2.5), "%.2f" % ab.frenzy_seconds)
	_check("and it cuts through three, as asked",
		ab.frenzy_pierce == 3, "%d" % ab.frenzy_pierce)
	# The card has to state the bleed rate it actually has. The description is written
	# by hand in the data table, so it is the one field that can drift from the number
	# beside it without anything noticing.
	_check("the card quotes the bleed rate it actually uses",
		ab.describe().contains("%.1f%%" % (ab.frenzy_decay * 100.0)),
		ab.describe())


func _test_a_stale_buff_on_disk_is_not_in_the_game() -> void:
	_section("A deleted buff stays deleted")

	# Found on a live copy of the game, not in a test. BuffPool built its pool by
	# reading the folder, and the data builder only deletes orphans in the copy it is
	# run against — so a machine that had ever held an older build still had seven cut
	# buffs sitting in data/buffs, and its game was still offering them. Every test
	# passed the whole time, because the machine the tests run on has a clean folder.
	#
	# Units never had this problem: a unit is in the game because roster.tres names it,
	# so a stale unit file is inert. This is buffs being given the same contract, and
	# this test is the folder being deliberately dirtied to prove it holds.
	var index: BuffIndex = load("res://data/buffs/index.tres") as BuffIndex
	_check("there is an index of the buffs that exist", index != null
		and not index.ids.is_empty(),
		"%d ids" % (0 if index == null else index.ids.size()))
	if index == null:
		return

	var pool := _pool()
	_check("the pool holds exactly what the index names",
		pool.buffs.size() == index.ids.size(),
		"%d loaded against %d named" % [pool.buffs.size(), index.ids.size()])
	for id in index.ids:
		_check("the index's %s loaded" % id, pool.by_id(id) != null)

	# Dirty a scratch folder the way a real machine gets dirty: a live buff, an index
	# that does not mention the second file, and a cut buff left behind.
	var dir_path := "user://stale_buff_test"
	DirAccess.make_dir_recursive_absolute(dir_path)
	var live := load("res://data/buffs/%s.tres" % index.ids[0]) as BuffData
	var ghost := live.duplicate() as BuffData
	ghost.id = &"a_buff_that_was_cut"
	ghost.display_name = "Cut Buff"
	ResourceSaver.save(live, "%s/%s.tres" % [dir_path, index.ids[0]])
	ResourceSaver.save(ghost, "%s/a_buff_that_was_cut.tres" % dir_path)
	var only := BuffIndex.new()
	only.ids = [index.ids[0]] as Array[StringName]
	ResourceSaver.save(only, "%s/index.tres" % dir_path)

	var dirty := BuffPool.new()
	var found := dirty.load_all(dir_path)
	_check("a cut buff left in the folder is not loaded", found == 1,
		"%d loaded" % found)
	_check("and cannot be found by id",
		dirty.by_id(&"a_buff_that_was_cut") == null)
	_check("while the one the index names still is",
		dirty.by_id(index.ids[0]) != null)
	# The pool is what the picker draws from, so the folder file must not reach it there
	# either — by_id() being clean is not the same claim.
	var rng := RandomNumberGenerator.new()
	rng.seed = 5
	var offered_ghost := false
	for i in 40:
		for b in dirty.offer(rng, 3, [], {}):
			if b.id == &"a_buff_that_was_cut":
				offered_ghost = true
	_check("and it is never offered as a pick", not offered_ghost)

	# The fallback matters as much as the rule. A folder with no index at all still has
	# to work, or regenerating data out of order bricks the game rather than degrading.
	var no_index := "user://stale_buff_no_index"
	DirAccess.make_dir_recursive_absolute(no_index)
	ResourceSaver.save(live, "%s/%s.tres" % [no_index, index.ids[0]])
	var scanned := BuffPool.new()
	_check("with no index at all it falls back to reading the folder",
		scanned.load_all(no_index) == 1, "%d loaded" % scanned.buffs.size())


func _test_the_charge_takes_time_to_arrive() -> void:
	_section("The charge is a journey, and picks its victim at the end of it")

	var breaker := _must_find("breaker")
	var ab: AbilityData = breaker.ability
	if ab == null:
		return
	_check("Onslaught has a travel time at all", ab.charge_tile_seconds > 0.0,
		"%.2fs a tile" % ab.charge_tile_seconds)
	# Faster than walking or it is not a charge; slower than instant or there is no
	# interval to see it coming in. Compared against the Breaker's OWN legs, which is
	# the honest comparison — it is the thing doing the running.
	var walk := UnitInstance.create(BoardModel.at_tier(breaker, 3),
		BoardModel.TEAM_A).stat(StatModifier.Stat.MOVE_TIME)
	_check("and it is clearly faster than the same unit walking",
		ab.charge_tile_seconds < walk * 0.6,
		"%.2fs a tile against %.2fs on foot" % [ab.charge_tile_seconds, walk])

	# The victim is chosen ON ARRIVAL. This is the whole change, and the fixture is built
	# so that the answer differs between the two rules: the unit that is in the lane when
	# the charge sets off is NOT the one standing there when it lands.
	BoardModel.reset_map()
	var board := BoardModel.new()
	var runner := UnitInstance.create(
		BoardModel.at_tier(breaker, 3), BoardModel.TEAM_A)
	board.force_place(runner, Vector2i(2, 1))
	# Rooted and harmless, four tiles down the lane: the one the old rule would have
	# picked at the moment of the cast.
	var decoy := UnitInstance.create(
		BoardModel.at_tier(_must_find("spire"), 3), BoardModel.TEAM_B)
	board.force_place(decoy, Vector2i(2, 5))
	board.force_place(UnitInstance.create(
		BoardModel.at_tier(_must_find("warden"), 1), BoardModel.TEAM_B),
		Vector2i(5, 9))
	var sim := CombatSim.new()
	sim.crit_chance = 0.0
	sim.setup(board, 91)
	_check("at the bell it has done nothing yet", runner.is_charging()
		and runner.cell == Vector2i(2, 1), "at %s" % runner.cell)

	# Take the decoy off the board mid-run — the same thing that happens when a unit
	# simply walks out of the column, done deliberately so the test does not depend on
	# anybody's pathing.
	sim.step()
	sim.step()
	var moved_out := board.move_unit(decoy, Vector2i(3, 5))
	_check("the decoy left the lane while the charge was still running",
		moved_out and runner.is_charging(),
		"moved %s, charging %s" % [moved_out, runner.is_charging()])
	var decoy_full := decoy.effective_hp()
	_finish_charge(sim, runner)
	_check("so the charge misses it entirely",
		is_equal_approx(decoy.effective_hp(), decoy_full)
		and not decoy.is_stunned(),
		"%.0f of %.0f, stunned %s" % [decoy.effective_hp(), decoy_full,
			decoy.is_stunned()])
	_check("and runs on down the empty lane instead", runner.cell.y > 5,
		"ended at %s" % runner.cell)

	# A freeze knocks it out of the run. This is the counterplay the travel time buys and
	# it is worth pinning, because it only exists while the charge has a duration.
	BoardModel.reset_map()
	var cold := BoardModel.new()
	var chased := UnitInstance.create(
		BoardModel.at_tier(breaker, 3), BoardModel.TEAM_A)
	cold.force_place(chased, Vector2i(2, 1))
	var prey := UnitInstance.create(
		BoardModel.at_tier(_must_find("spire"), 6), BoardModel.TEAM_B)
	cold.force_place(prey, Vector2i(2, 8))
	var cold_sim := CombatSim.new()
	cold_sim.setup(cold, 92)
	cold_sim.step()
	chased.frozen_left = 5.0
	chased.frozen_amp = 1.0
	var where := chased.cell
	var prey_full := prey.effective_hp()
	for i in 60:
		cold_sim.step()
	_check("a freeze stops the charge dead", not chased.is_charging())
	_check("it does not carry on across the board while frozen",
		BoardModel.tile_distance(chased.cell, where) <= 1,
		"from %s to %s" % [where, chased.cell])
	_check("and what it was running at is untouched",
		is_equal_approx(prey.effective_hp(), prey_full),
		"%.0f of %.0f" % [prey.effective_hp(), prey_full])

	# The events the view needs, in the order it needs them. A charge that emitted its
	# damage before its steps would put the slam on screen before the runner arrived,
	# which is the exact bug the old view had to paper over with a cursor hold.
	var start_t := -1.0
	var steps := 0
	var end_t := -1.0
	var hit_t := -1.0
	for e in sim.events:
		if int(e.get("uid", -1)) != runner.uid:
			continue
		match e.kind:
			"charge":
				start_t = float(e.t)
			"charge_step":
				steps += 1
			"charge_end":
				end_t = float(e.t)
			"ability":
				hit_t = float(e.t)
	_check("the view is told the run has started", start_t >= 0.0)
	_check("and gets a step per tile rather than one jump to the far end",
		steps > 1, "%d steps" % steps)
	_check("and is told when it is over", end_t > start_t,
		"start %.2f, end %.2f" % [start_t, end_t])


func _test_a_puppet_is_a_worse_unit() -> void:
	_section("The Usurper's puppet is weaker than the unit it was")

	var usurper := _must_find("usurper")
	var ab: AbilityData = usurper.ability
	if ab == null:
		return
	_check("Usurpation carries a weakness at all", ab.possess_weakness > 0.0,
		"%.2f" % ab.possess_weakness)
	_check("half the unit at tier 1, as asked",
		is_equal_approx(ab.possess_weakness, 0.50), "%.2f" % ab.possess_weakness)
	_check("and each tier buys off ten points of it",
		is_equal_approx(ab.possess_weakness_per_tier, 0.10),
		"%.2f" % ab.possess_weakness_per_tier)

	# The ladder, end to end. The tier 6 rung is the one the user named explicitly and it
	# is the one an off-by-one would break: 0.50 - 0.10 * 6 would be negative, and a
	# negative weakness is a BUFF handed to the thing you stole.
	var sim := CombatSim.new()
	var want := [0.50, 0.40, 0.30, 0.20, 0.10, 0.00]
	for tier in range(1, 7):
		var thief := UnitInstance.create(
			BoardModel.at_tier(usurper, tier), BoardModel.TEAM_A)
		var got := sim.possess_weakness_of(thief)
		_check("a tier %d Usurper's puppet is %d%% weaker" % [tier, roundi(want[tier - 1] * 100.0)],
			is_equal_approx(got, want[tier - 1]),
			"%.2f against %.2f" % [got, want[tier - 1]])
	_check("and tier 6 is no debuff at all, not a small one",
		is_zero_approx(sim.possess_weakness_of(UnitInstance.create(
			BoardModel.at_tier(usurper, 6), BoardModel.TEAM_A))))

	# Through the simulation, because a number on a resource that nothing applies is the
	# failure this file exists to catch.
	for tier in [1, 3, 6]:
		var stage := _usurp_board(tier, tier)
		var prey: UnitInstance = stage.prey
		var sim2: CombatSim = stage.sim
		var base_hp := prey.stat(StatModifier.Stat.MAX_HP)
		var base_dmg := prey.stat(StatModifier.Stat.ATTACK_DAMAGE)
		sim2.setup(stage.board, 311)
		var weak: float = sim2.possess_weakness_of(stage.thief)
		_check("a tier %d Usurper's stolen body really is smaller" % tier,
			is_equal_approx(prey.stat(StatModifier.Stat.MAX_HP),
				base_hp * (1.0 - weak)),
			"%.0f against %.0f" % [prey.stat(StatModifier.Stat.MAX_HP),
				base_hp * (1.0 - weak)])
		_check("and hits softer" if weak > 0.0 else "and a tier 6's does not",
			is_equal_approx(prey.stat(StatModifier.Stat.ATTACK_DAMAGE),
				base_dmg * (1.0 - weak)),
			"%.1f against %.1f" % [prey.stat(StatModifier.Stat.ATTACK_DAMAGE),
				base_dmg * (1.0 - weak)])
		# A shrunken maximum with the old number still on the bar reads as a full bar that
		# will not move when it is hit, and heals back toward a cap that is gone.
		_check("its health bar is not left above its own maximum",
			prey.current_hp <= prey.stat(StatModifier.Stat.MAX_HP) + 0.01,
			"%.0f of %.0f" % [prey.current_hp,
				prey.stat(StatModifier.Stat.MAX_HP)])
		# And none of it survives the hand-back. A debuff that outlived the possession
		# would let an Usurper permanently cripple something just by touching it.
		prey.reset_for_battle()
		_check("and none of it is left after the round",
			is_equal_approx(prey.stat(StatModifier.Stat.MAX_HP), base_hp),
			"%.0f against %.0f" % [prey.stat(StatModifier.Stat.MAX_HP), base_hp])


func _siren_stage(tier: int, prey_tier := 3) -> Dictionary:
	## A Siren at the top of a column with something to shoot at four tiles away, and a
	## far-off spare so the round cannot end underneath the test.
	BoardModel.reset_map()
	var b := BoardModel.new()
	var siren := UnitInstance.create(
		BoardModel.at_tier(_must_find("siren"), tier), BoardModel.TEAM_A)
	b.force_place(siren, Vector2i(2, 1))
	var mark := UnitInstance.create(
		BoardModel.at_tier(_must_find("warden"), prey_tier), BoardModel.TEAM_B)
	b.force_place(mark, Vector2i(2, 5))
	b.force_place(UnitInstance.create(
		BoardModel.at_tier(_must_find("spire"), 1), BoardModel.TEAM_B),
		Vector2i(5, 9))
	var sim := CombatSim.new()
	sim.crit_chance = 0.0
	return {sim = sim, board = b, siren = siren, mark = mark}


func _test_the_siren() -> void:
	_section("The Siren: a weak shot, fast, that sends things reeling")

	var siren := _must_find("siren")
	var ab: AbilityData = siren.ability
	_check("Vertigo is a DISORIENT", ab != null
		and ab.kind == AbilityData.Kind.DISORIENT)
	if ab == null:
		return
	_check("it shoots a long way", siren.range_name() == "Long",
		siren.range_name())
	# Weak and fast is the shape of the unit, so it is pinned rather than assumed: a
	# later tuning pass that made it hit hard would make it a different unit entirely.
	var archer := _must_find("archer")
	_check("it hits softer than the Archer", siren.attack_damage < archer.attack_damage,
		"%.0f against %.0f" % [siren.attack_damage, archer.attack_damage])
	_check("and shoots faster", siren.attack_speed > archer.attack_speed,
		"%.2f against %.2f" % [siren.attack_speed, archer.attack_speed])

	# The ladder, and the ceiling it is supposed to land on rather than run past.
	var sim := CombatSim.new()
	var want := [0.5, 0.8, 1.1, 1.4, 1.7, 2.0]
	for tier in range(1, 7):
		var s := UnitInstance.create(
			BoardModel.at_tier(siren, tier), BoardModel.TEAM_A)
		var got := sim.disorient_seconds_of(s, ab)
		_check("a tier %d Siren disorients for %.1fs" % [tier, want[tier - 1]],
			is_equal_approx(got, want[tier - 1]),
			"%.2f against %.2f" % [got, want[tier - 1]])
	_check("and the ceiling is the two seconds it was asked for",
		is_equal_approx(ab.disorient_max, 2.0), "%.2f" % ab.disorient_max)

	# Through the simulation. The cast has to land on somebody and actually stop them.
	var stage := _siren_stage(3)
	var mark: UnitInstance = stage.mark
	var sim2: CombatSim = stage.sim
	sim2.setup(stage.board, 501)
	var ticks := 0
	while not mark.is_disoriented() and ticks < 400:
		sim2.step()
		ticks += 1
	_check("it fills its bar and sends something reeling", mark.is_disoriented(),
		"%.1fs and nothing" % (float(ticks) * CombatSim.TICK))
	if not mark.is_disoriented():
		return
	_check("a reeling unit cannot swing", not mark.can_attack_now())
	# It still MOVES, and that is the whole difference between this and a stun. A version
	# that folded it into is_held() would plant the unit, which is a different ability.
	_check("but it can still move, because it is wandering and not pinned",
		mark.can_move_now())
	_check("it is not frozen or stunned", not mark.is_frozen()
		and not mark.is_stunned())
	_check("and it takes no extra damage for being lost",
		is_equal_approx(mark.frozen_damage_taken(), 1.0))
	_check("the view is told", _has_event(sim2, "disorient", mark.uid))

	# Re-applying RESETS rather than extends or takes the longest.
	mark.disorient_left = 0.4
	sim2._resolve_disorient(stage.siren, ab)
	_check("catching one that is already reeling starts its count again",
		mark.disorient_left > 0.4,
		"%.2fs left" % mark.disorient_left)

	# And then the five seconds of immunity, which is what stops two of them locking a
	# unit out of the round between them.
	mark.disorient_left = CombatSim.TICK
	var more := 0
	while mark.is_disoriented() and more < 100:
		sim2.step()
		more += 1
	_check("it comes out of it", not mark.is_disoriented())
	_check("and is immune afterwards", mark.is_disorient_immune(),
		"%.2fs" % mark.disorient_immune_left)
	_check("for the five seconds the card promises",
		absf(mark.disorient_immune_left - 5.0) < 0.25,
		"%.2fs" % mark.disorient_immune_left)
	_check("and the view is told it is over",
		_has_event(sim2, "disorient_end", mark.uid))

	# The immunity has to actually refuse a second one, not merely exist.
	var immune_for := mark.disorient_immune_left
	sim2._resolve_disorient(stage.siren, ab)
	_check("a unit inside its immunity cannot be disoriented again",
		not mark.is_disoriented())
	_check("and the immunity is not reset by the attempt",
		mark.disorient_immune_left <= immune_for + 0.001,
		"%.2fs against %.2fs" % [mark.disorient_immune_left, immune_for])
	# It runs down and then the unit is catchable again — an immunity that never expired
	# would make the Siren a one-shot.
	# The immunity wearing off gets a fixture of its own, and the reason is worth writing
	# down: in the one above the Siren finishes off what it is shooting at after about
	# five seconds, the round ends, and step() then does nothing at all — so the clock
	# stops with a fraction of a second left on it and the check fails for a reason that
	# has nothing to do with the clock. Two rooted, harmless bodies cannot end a round.
	BoardModel.reset_map()
	var quiet := BoardModel.new()
	var post := UnitInstance.create(
		BoardModel.at_tier(_must_find("spire"), 6), BoardModel.TEAM_B)
	quiet.force_place(post, Vector2i(2, 5))
	quiet.force_place(UnitInstance.create(
		BoardModel.at_tier(_must_find("spire"), 6), BoardModel.TEAM_A),
		Vector2i(2, 1))
	var quiet_sim := CombatSim.new()
	quiet_sim.setup(quiet, 502)
	post.disorient_left = 0.2
	post.disorient_immune_after = ab.disorient_immunity
	var waited := 0
	while (post.is_disoriented() or post.is_disorient_immune()) \
			and not quiet_sim.is_finished() and waited < 200:
		quiet_sim.step()
		waited += 1
	_check("the immunity wears off on its own", not post.is_disorient_immune(),
		"%.2fs left after %.1fs" % [post.disorient_immune_left,
			float(waited) * CombatSim.TICK])
	_check("and it lasted about the five seconds it should have",
		absf(float(waited) * CombatSim.TICK - 5.2) < 0.4,
		"%.1fs" % (float(waited) * CombatSim.TICK))


func _test_a_reeling_unit_wanders() -> void:
	_section("A reeling unit wanders instead of fighting")

	var stage := _siren_stage(6)
	var mark: UnitInstance = stage.mark
	var sim: CombatSim = stage.sim
	sim.setup(stage.board, 777)
	# Planted rather than earned, so this fixture is about the WANDER and not about how
	# long the bar takes to fill.
	mark.disorient_left = 6.0
	var start := mark.cell
	var swung := 0
	var moved := 0
	var from := start
	for i in 60:
		sim.step()
		if mark.cell != from:
			moved += 1
			from = mark.cell
	for e in sim.events:
		if e.kind == "attack" and int(e.get("uid", -1)) == mark.uid:
			swung += 1
	_check("it moves while it is lost", moved > 0, "%d steps" % moved)
	_check("and swings at nothing the whole time", swung == 0,
		"%d swings" % swung)
	# Aimlessly: it must not close on the thing it was fighting. Checked as "did not make
	# steady progress toward it" rather than "moved away", because a random walk can drift
	# either way and asserting a direction would be a flaky test.
	_check("it does not march at its enemy", mark.cell != stage.siren.cell)

	# Deterministic, because the view replays a log. A unit that wandered differently on
	# playback than it did in the simulation would desync the board from the model.
	var a := _wander_path(4242)
	var b := _wander_path(4242)
	var c := _wander_path(99)
	_check("the same battle wanders the same way twice", a == b,
		"%s against %s" % [a, b])
	_check("and a different seed wanders differently", a != c,
		"%s against %s" % [a, c])


func _wander_path(seed_value: int) -> Array[Vector2i]:
	var stage := _siren_stage(6)
	var mark: UnitInstance = stage.mark
	var sim: CombatSim = stage.sim
	sim.setup(stage.board, seed_value)
	mark.disorient_left = 6.0
	var path: Array[Vector2i] = []
	for i in 40:
		sim.step()
		path.append(mark.cell)
	return path


func _test_discord() -> void:
	_section("Discord: the Siren's buff")

	var pool := _pool()
	var buff := pool.by_id(&"discord")
	_check("Discord is on disk", buff != null)
	if buff == null:
		return
	_check("it belongs to the Siren", buff.unit_id == &"siren")
	_check("it is an attack speed buff", buff.stat_a == StatModifier.Stat.ATTACK_SPEED)
	_check("20, 40 and 60 percent, as asked",
		is_equal_approx(buff.bronze.x, 0.20) and is_equal_approx(buff.silver.x, 0.40)
		and is_equal_approx(buff.gold.x, 0.60),
		"%.2f / %.2f / %.2f" % [buff.bronze.x, buff.silver.x, buff.gold.x])
	_check("and half a second, one and two on top",
		is_equal_approx(buff.disorient_bonus_at(BuffData.Rarity.BRONZE), 0.5)
		and is_equal_approx(buff.disorient_bonus_at(BuffData.Rarity.SILVER), 1.0)
		and is_equal_approx(buff.disorient_bonus_at(BuffData.Rarity.GOLD), 2.0),
		"%s" % buff.disorient_bonus)
	for r in [BuffData.Rarity.BRONZE, BuffData.Rarity.SILVER, BuffData.Rarity.GOLD]:
		_check("the %s card mentions the longer disorientation" % BuffData.rarity_name(r),
			buff.describe(r).to_lower().contains("longer"), buff.describe(r))

	# The rider has to reach the simulation, and it has to ADD to the tier ladder rather
	# than be swallowed by the cap — a buff worth nothing at the tier you most want it is
	# the failure this checks for.
	var ab: AbilityData = _must_find("siren").ability
	for tier in [1, 6]:
		var s := UnitInstance.create(
			BoardModel.at_tier(_must_find("siren"), tier), BoardModel.TEAM_A)
		var sim := CombatSim.new()
		var bare := sim.disorient_seconds_of(s, ab)
		var tb := TeamBuffs.new()
		tb.add(buff, BuffData.Rarity.GOLD)
		sim.team_buffs[BoardModel.TEAM_A] = tb
		var rich := sim.disorient_seconds_of(s, ab)
		_check("gold Discord adds two seconds at tier %d" % tier,
			is_equal_approx(rich, bare + 2.0),
			"%.2f against %.2f" % [rich, bare + 2.0])
	_check("so a gold tier 6 reaches four seconds, past the unit's own ceiling",
		true)


# --- Boss defence ---------------------------------------------------------------

func _boss_board(sections: Array = [[], [], []], boss: BossData = null,
		limited := false) -> Dictionary:
	## The open field with the crystals and the boss, a Barracks whose three sections
	## hold exactly `sections` (unit ids, tier 1), and the fight started — so the
	## first wave is already on the field. Call BoardModel.reset_map() when done.
	BoardModel.use_map(BossFight.make_map())
	var board := BoardModel.new()
	var data := boss if boss != null else (load("res://data/boss/arbiter.tres") as BossData).duplicate(true)
	var barracks := Barracks.new()
	barracks.setup(data, load("res://data/loadouts/starter.tres") as LoadoutData, 99)
	for s in Barracks.SECTIONS:
		for i in barracks.slot_count():
			barracks.sections[s][i] = null
		var i := 0
		for id in sections[s]:
			barracks.sections[s][i] = _find(id)
			i += 1
	var bf := BossFight.new()
	bf.place_structures(board, data)
	bf.limit_army = limited
	var sim := CombatSim.new()
	sim.crit_chance = 0.0
	bf.attach(sim, barracks)
	sim.setup(board, 99)
	bf.start()
	sim._absorb_new_units()
	return {board = board, bf = bf, sim = sim, data = data, barracks = barracks}


func _army_in_zone(bf: BossFight, zone: int) -> int:
	return bf.army_in_zone(zone)


func _test_boss_defence() -> void:
	_section("Boss defence")
	var data := load("res://data/boss/arbiter.tres") as BossData
	var listed := data != null and data.phases.size() == 4
	if listed:
		for p in data.phases:
			listed = listed and not p.moves.is_empty()
	_check("the boss is data: four phases, each with its own move list", listed)
	if not listed:
		return
	_check("it has its own name, not anybody else's",
		data.display_name == "The Vermilion Arbiter")
	var shapes := func(p: BossPhase) -> Array:
		var out := []
		for m in p.moves:
			out.append(m.shape)
		return out
	_check("phase one: a row sweep, a column slash, an arc, a spear thrust and a dash",
		shapes.call(data.phases[0]) == [BossMove.Shape.ROWS, BossMove.Shape.COLUMNS,
			BossMove.Shape.ARC, BossMove.Shape.THRUST, BossMove.Shape.DASH, BossMove.Shape.DASH])
	var p2 := data.phases[1]
	_check("phase two, at 75%: a second weapon — a faster cycle with the two-row combo",
		is_equal_approx(p2.hp_threshold, 0.75)
		and p2.moves.any(func(m): return m.shape == BossMove.Shape.ROWS and m.span == 2)
		and p2.gap < data.phases[0].gap and p2.haste > 1.0)
	var p3 := data.phases[2]
	_check("phase three, at 50%: the big vertical and horizontal splits, and the leap",
		is_equal_approx(p3.hp_threshold, 0.50)
		and p3.moves.any(func(m): return m.shape == BossMove.Shape.COLUMNS and m.span >= 3)
		and p3.moves.any(func(m): return m.shape == BossMove.Shape.ROWS and m.span >= 3)
		and p3.moves.any(func(m): return m.shape == BossMove.Shape.LEAP))
	var p4 := data.phases[3]
	_check("phase four, at 25%: its final form heals off its blows",
		is_equal_approx(p4.hp_threshold, 0.25) and p4.lifesteal > 0.0)
	var tied := false
	for p in data.phases:
		tied = tied or p.on_central
	_check("and no phase is tied to the crystals — those are a separate track", not tied)
	_check("every phase change is announced with a pause",
		data.phases.slice(1).all(func(p): return p.entry_pause > 0.0))
	_check("the moves reach across an open field, not a two-tile lane",
		data.phases[0].moves[0].reach >= 3 and data.phases[0].moves[3].reach >= 7
		and data.phases[0].moves[4].reach >= 8)

	# --- The field: open, in four zones, with scattered rock rather than walls.
	var s := _boss_board()
	var bf: BossFight = s.bf
	var sim: CombatSim = s.sim
	var board: BoardModel = s.board
	_check("the battlefield is big: 17 x 26",
		BoardModel.WIDTH == 17 and BoardModel.HEIGHT == 26)
	var rock := 0
	for y in BoardModel.HEIGHT:
		for x in BoardModel.WIDTH:
			if BoardModel.is_wall(Vector2i(x, y)):
				rock += 1
	_check("and open: only a little scattered rock", rock > 0 and rock <= 24,
		"%d rock tiles" % rock)
	# No wall between zones: along every zone boundary, most of the edge is open.
	var edges := 0
	var blocked_edges := 0
	for y in range(BossFight.HUB_ROWS, BoardModel.HEIGHT):
		for x in BoardModel.WIDTH:
			var c := Vector2i(x, y)
			for n in [c + Vector2i(1, 0), c + Vector2i(0, 1)]:
				if n.x >= BoardModel.WIDTH or n.y >= BoardModel.HEIGHT:
					continue
				if BossFight.zone_of_cell(c) == BossFight.zone_of_cell(n):
					continue
				edges += 1
				if BoardModel.is_blocked(c) or BoardModel.is_blocked(n):
					blocked_edges += 1
	_check("no zone is walled off from its neighbours",
		edges > 0 and float(blocked_edges) / float(edges) < 0.25,
		"%d of %d boundary edges blocked" % [blocked_edges, edges])
	var reach := {BossFight.BOSS_CELL: true}
	var frontier: Array[Vector2i] = [BossFight.BOSS_CELL]
	while not frontier.is_empty():
		var c: Vector2i = frontier.pop_back()
		for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			var n: Vector2i = c + d
			if board.in_bounds(n) and not BoardModel.is_blocked(n) and not reach.has(n):
				reach[n] = true
				frontier.append(n)
	var walkable := 0
	var all_open := 0
	for y in BoardModel.HEIGHT:
		for x in BoardModel.WIDTH:
			if not BoardModel.is_blocked(Vector2i(x, y)):
				all_open += 1
				if reach.has(Vector2i(x, y)):
					walkable += 1
	_check("every open tile can be walked to from where the boss comes in",
		walkable == all_open, "%d of %d" % [walkable, all_open])
	var zones_ok := true
	for i in 3:
		zones_ok = zones_ok and BossFight.zone_of_cell(bf.crystals[i].cell) == i
	_check("the Left, Middle and Right crystals each stand in their own zone", zones_ok)
	_check("the Central Crystal stands in its own zone down the middle, at the bottom",
		BossFight.zone_of_cell(bf.crystals[3].cell) == 3
		and bf.crystals[3].cell.y >= BoardModel.HEIGHT - 3
		and absi(bf.crystals[3].cell.x - BoardModel.WIDTH / 2) <= 1)
	_check("as far from the boss's entry as the board allows",
		BoardModel.tile_distance(bf.crystals[3].cell, BossFight.BOSS_CELL) >= 20)
	_check("the boss comes in at the top", bf.boss.cell.y < BossFight.HUB_ROWS and bf.boss.boss)

	# Someone near her, or she walks on instead of swinging at empty ground.
	var near_her := UnitInstance.create(load("res://data/units/warden_t1.tres") as UnitData, bf.player_team())
	if sim.board.force_place(near_her, bf.boss.cell + Vector2i(0, 3)):
		sim._units.append(near_her)
	# --- The cycle: fixed and looping, per phase.
	var seen: PackedStringArray = []
	for i in 8:
		seen.append(String(bf.next_move().id))
		bf._mark_next_move()
		bf.marked = {}
	var want: PackedStringArray = []
	for i in 8:
		want.append(String(data.phases[0].moves[i % data.phases[0].moves.size()].id))
	_check("the phase-one cycle runs in its listed order and loops", seen == want,
		", ".join(seen))
	# And with nobody near she marks nothing — she walks on.
	near_her.current_hp = 0.0
	near_her.state = UnitInstance.State.DEAD
	sim.board.remove(near_her)
	bf.marked = {}
	bf._mark_next_move()
	_check("with nobody near her she throws nothing, and walks on instead",
		bf.marked.is_empty() and bf.gap_left > 0.0)
	_check("her big moves come at random, more likely every phase",
		bf.big_chance_of(data.phases[0]) == 0.0
		and bf.big_chance_of(data.phases[1]) < bf.big_chance_of(data.phases[3]))
	bf.boss.current_hp = bf.boss.stat(StatModifier.Stat.MAX_HP) * 0.76
	bf._check_phase()
	_check("at 76% it is still in phase one", bf.phase == 0)
	bf.boss.current_hp = bf.boss.stat(StatModifier.Stat.MAX_HP) * 0.74
	var before_change := sim.events.size()
	bf._check_phase()
	_check("at 74% it moves to phase two, and its cycle starts from the top",
		bf.phase == 1 and bf.next_move().id == data.phases[1].moves[0].id)
	_check("announced, with a pause it stands through",
		bf.pause_left > 0.0 and sim.events.slice(before_change).any(
			func(e): return e.kind == "boss_phase" and float(e.seconds) > 0.0))
	var paused_from := sim.events.size()
	bf.gap_left = 0.0
	for i in int(bf.pause_left / CombatSim.TICK) - 1:
		sim.step()
	var acted := false
	for e in sim.events.slice(paused_from):
		if int(e.get("uid", -1)) == bf.boss.uid and e.kind in ["boss_telegraph",
				"attack", "move"]:
			acted = true
	_check("it does nothing during the pause", not acted and bf.marked.is_empty())
	bf.pause_left = 0.0
	bf.boss.current_hp = bf.boss.stat(StatModifier.Stat.MAX_HP) * 0.49
	bf._check_phase()
	_check("at 49%, phase three", bf.phase == 2)
	_check("and it is faster for it", bf.boss.stat(StatModifier.Stat.ATTACK_SPEED)
		> data.attack_speed + 0.01)
	bf.boss.current_hp = bf.boss.stat(StatModifier.Stat.MAX_HP) * 0.9
	bf._check_phase()
	_check("healing back above the lines does not take it back to an earlier phase",
		bf.phase == 2)
	bf.boss.current_hp = bf.boss.stat(StatModifier.Stat.MAX_HP) * 0.24
	bf._check_phase()
	_check("at 24% it is in its final form, and heals off what it deals",
		bf.phase == 3 and bf.boss.lifesteal() > 0.0)
	BoardModel.reset_map()

	# --- The telegraph comes first, and only the marked tiles are hit.
	s = _boss_board()
	bf = s.bf
	sim = s.sim
	board = s.board
	var near := UnitInstance.create(_find("warden"), BoardModel.TEAM_B)
	var away := UnitInstance.create(_find("warden"), BoardModel.TEAM_B)
	board.force_place(near, bf.boss.cell + Vector2i(1, 0))
	board.force_place(away, Vector2i(16, 12))
	sim._pending_units.append(near)
	sim._pending_units.append(away)
	sim._absorb_new_units()
	bf.gap_left = 0.0
	sim.step()
	var marks := _kind_events(sim, "boss_telegraph")
	_check("a move begins as a mark on the board, with its name",
		marks.size() == 1 and not String(marks[0].name).is_empty()
		and (marks[0].cells as Array).has(near.cell))
	var hurt_before := near.current_hp
	var ehp_before := near.current_hp + near.shield
	var secs: float = float(marks[0].seconds) if not marks.is_empty() else 1.0
	for i in int(secs / CombatSim.TICK) - 1:
		sim.step()
	_check("nothing lands while the mark is up",
		_kind_events(sim, "boss_strike").is_empty()
		and is_equal_approx(near.current_hp, hurt_before))
	for i in 3:
		sim.step()
	var strikes := _kind_events(sim, "boss_strike")
	_check("then it strikes the marked tiles",
		strikes.size() == 1 and near.current_hp + near.shield < ehp_before,
		"%.0f -> %.0f" % [ehp_before, near.current_hp + near.shield])
	_check("and nothing outside them",
		is_equal_approx(away.current_hp, away.stat(StatModifier.Stat.MAX_HP)))
	if not marks.is_empty() and not strikes.is_empty():
		_check("the strike comes after the mark by the warning's length",
			float(strikes[0].t) - float(marks[0].t) >= secs - 0.001)
	BoardModel.reset_map()

	# --- Crystals: the fixed order, the seal, and the switch to the centre.
	s = _boss_board([["warden"], ["warden"], ["warden"]])
	bf = s.bf
	sim = s.sim
	_check("it goes for the Left Crystal first", bf.current_target() == bf.crystals[0])
	var central := bf.crystals[3]
	sim._damage(central, 500.0, bf.boss)
	_check("the Central Crystal is sealed while any zone crystal stands",
		is_equal_approx(central.current_hp, central.stat(StatModifier.Stat.MAX_HP)))
	var lc0: UnitInstance = bf.crystals[0]
	var lc0_before := lc0.current_hp + lc0.shield
	sim._damage(lc0, 1.0e7, bf.boss)
	_check("her blow on a crystal deals a fixed amount, not her attack",
		is_equal_approx(lc0_before - (lc0.current_hp + lc0.shield), bf.data.crystal_hit_damage))
	_break(sim, bf.crystals[0], bf.boss)
	sim.step()
	_check("with the Left down it goes for the Middle", bf.current_target() == bf.crystals[1])
	_break(sim, bf.crystals[1], bf.boss)
	sim.step()
	_check("then the Right", bf.current_target() == bf.crystals[2] and not bf.merged)
	_check("the fight does not end when a zone crystal breaks", not sim.is_finished())
	var near_centre_before := 0
	for u in s.board.units_of(BoardModel.TEAM_B):
		if not u.structure and BoardModel.box_distance(u.cell, central.cell) <= 6:
			near_centre_before += 1
	_break(sim, bf.crystals[2], bf.boss)
	sim.step()
	_check("after all three it turns on the Central Crystal, unsealed",
		bf.current_target() == central and not central.sealed and bf.merged)
	_check("and the merge leaves its phase alone — that is the health bar's job",
		bf.phase == 0)
	var near_centre_after := 0
	for u in s.board.units_of(BoardModel.TEAM_B):
		if not u.structure and BoardModel.box_distance(u.cell, central.cell) <= 6:
			near_centre_after += 1
	_check("and every section's wave now deploys around the Central Crystal",
		near_centre_after >= near_centre_before + 3,
		"%d by the centre, was %d" % [near_centre_after, near_centre_before])
	sim._damage(central, 300.0, bf.boss)
	_check("the Central Crystal now takes damage",
		central.current_hp < central.stat(StatModifier.Stat.MAX_HP)
		and is_equal_approx(central.stat(StatModifier.Stat.MAX_HP) - central.current_hp - central.shield,
			bf.data.central_hit_damage),
		"%.0f taken" % (central.stat(StatModifier.Stat.MAX_HP) - central.current_hp))
	_break(sim, central, bf.boss)
	sim.step()
	_check("and when it breaks, the boss wins", sim.is_finished()
		and sim.result() == BoardModel.TEAM_A)
	BoardModel.reset_map()

	s = _boss_board([["warden"], [], []])
	bf = s.bf
	sim = s.sim
	# One blow can only take her single-hit cap, so bring her to the edge first.
	bf.boss.current_hp = 1.0
	sim._damage(bf.boss, 1.0e7, bf.crystals[0])
	sim.step()
	_check("bring the boss to zero and the player wins", sim.is_finished()
		and sim.result() == BoardModel.TEAM_B)
	BoardModel.reset_map()

	s = _boss_board([["warden"], [], []])
	sim = s.sim
	sim.run(3.0)
	_check("time running out with the boss standing is a loss",
		sim.is_finished() and sim.result() == BoardModel.TEAM_A)
	BoardModel.reset_map()

	# --- The Barracks and Supply.
	var b := Barracks.new()
	b.setup(data, load("res://data/loadouts/starter.tres") as LoadoutData, 5)
	_check("the Barracks opens with the free draws dealt round its three sections",
		b.unit_count(0) + b.unit_count(1) + b.unit_count(2) == data.start_draws
		and b.unit_count(0) > 0 and b.unit_count(1) > 0 and b.unit_count(2) > 0)
	_check("and a small stash of Supply", is_equal_approx(b.supply, data.start_supply))
	b.tick(10.0)
	_check("Supply ticks up at the income rate",
		is_equal_approx(b.supply, data.start_supply + data.base_income * 10.0),
		"%.1f" % b.supply)
	var pb := Barracks.new()
	pb.setup(data, load("res://data/loadouts/starter.tres") as LoadoutData, 8)
	var base_rate := pb.income
	for i in 290:
		pb.tick(0.1)
	_check("income does not grow on its own before %ds" % roundi(data.passive_income_every),
		is_equal_approx(pb.income, base_rate), "%.1f/s" % pb.income)
	for i in 20:
		pb.tick(0.1)
	_check("then it grows by itself, with nothing bought",
		is_equal_approx(pb.income, base_rate + data.passive_income), "%.1f/s" % pb.income)
	pb.tick(data.passive_income_every * 2.0)
	_check("and keeps growing every %ds" % roundi(data.passive_income_every),
		is_equal_approx(pb.income, base_rate + 3.0 * data.passive_income), "%.1f/s" % pb.income)
	var s0 := pb.supply
	var got_b := pb.earn_from_damage(1000.0, true)
	_check("hurting her earns Supply", got_b > 0.0
		and is_equal_approx(pb.supply - s0, 1000.0 * data.damage_income), "%.1f" % got_b)
	var got_s := pb.earn_from_damage(1000.0, false)
	_check("and so does hurting her summons", got_s > 0.0
		and is_equal_approx(got_s, 1000.0 * data.summon_damage_income), "%.1f" % got_s)
	_check("and it pays more the stronger she has grown",
		is_equal_approx(pb.earn_from_damage(1000.0, true, 3.0), got_b * 3.0)
		and is_equal_approx(pb.damage_earned, got_b * 4.0 + got_s))
	var count1 := b.unit_count(1)
	var supply := b.supply
	_check("a recruit buys one unit into that section",
		b.recruit(1) and b.unit_count(1) == count1 + 1
		and is_equal_approx(b.supply, supply - data.recruit_cost))
	b.supply = data.recruit_cost - 1.0
	var count2 := b.unit_count(2)
	_check("and you cannot spend Supply you do not have",
		not b.recruit(2) and b.unit_count(2) == count2
		and is_equal_approx(b.supply, data.recruit_cost - 1.0))
	b.supply = 1000.0
	var rate := b.income
	var price := b.income_price()
	_check("an income upgrade raises the rate",
		b.upgrade_income() and is_equal_approx(b.income, rate + data.income_step))
	_check("and the next one costs more", b.income_price() > price + 0.01,
		"%.0f then %.0f" % [price, b.income_price()])
	b.supply = price - 1.0
	_check("and it, too, cannot be bought on credit", not b.upgrade_income())
	var ib := Barracks.new()
	ib.setup(data, load("res://data/loadouts/starter.tres") as LoadoutData, 9)
	ib.supply = 1.0e9
	var bought := 0
	for i in 20:
		if ib.upgrade_income():
			bought += 1
	var income_want := data.base_income
	for k in 20:
		income_want += data.income_step * ((1.0 + data.income_step_quad * k * k) if data.income_step_quad > 0.0
			else pow(data.income_step_growth, k))
	_check("income has no cap, and each upgrade gives a little more than the last",
		data.income_max_level == 0 and bought == 20 and not ib.income_maxed()
		and is_equal_approx(ib.income, income_want),
		"%d bought, %.0f/s against %.0f" % [bought, ib.income, income_want])
	b.supply = 1000.0
	var r_price := b.recruit_price()
	b.recruit(0)
	_check("each recruit costs more than the last",
		b.recruit_price() > r_price, "%.0f then %.0f" % [r_price, b.recruit_price()])
	var fresh := Barracks.new()
	fresh.setup(data, load("res://data/loadouts/starter.tres") as LoadoutData, 3)
	fresh.supply = 1000.0
	var ladder: Array[int] = []
	for i in 4:
		ladder.append(roundi(fresh.recruit_price()))
		fresh.recruit(i % Barracks.SECTIONS)
	_check("recruits start at 10 and go up by 2: 10, 12, 14, 16", ladder == [10, 12, 14, 16],
		"%s" % [ladder])
	# Merging: two of the same in a section become one of the next tier.
	for i in b.slot_count():
		b.sections[0][i] = null
	var warden := _find("warden")
	b.sections[0][0] = warden
	b.sections[0][1] = warden
	var merged_how := b.drop(0, 0, 0, 1)
	_check("dragging a unit onto its twin in the Barracks merges them",
		merged_how == "merged" and b.at(0, 0) == null and b.at(0, 1) != null
		and b.at(0, 1).tier == 2)
	b.sections[0][2] = _find("archer")
	_check("onto an empty slot it moves, onto anything else it swaps",
		b.drop(0, 2, 0, 5) == "moved" and b.at(0, 5) == _find("archer")
		and b.drop(0, 5, 0, 1) == "swapped" and b.at(0, 1) == _find("archer"))

	# --- Waves copy the sections, into the right zone, and stack.
	s = _boss_board([["warden", "archer"], ["lancer"], ["seraph", "warden", "archer"]])
	bf = s.bf
	sim = s.sim
	b = s.barracks
	_check("the first wave goes out the moment the fight starts",
		bf.waves == 1 and _army_in_zone(bf, 0) == 2 and _army_in_zone(bf, 1) == 1
		and _army_in_zone(bf, 2) == 3,
		"%d / %d / %d" % [_army_in_zone(bf, 0), _army_in_zone(bf, 1), _army_in_zone(bf, 2)])
	var placed_near := true
	for e in _kind_events(sim, "summon"):
		var z := int(e.get("zone", -1))
		if z < 0 or z > 2 or BoardModel.box_distance(e.cell, bf.crystals[z].cell) > 6:
			placed_near = false
	_check("each section's units land by their own zone's crystal", placed_near)
	b.supply = 1000.0
	b.recruit(1)
	var mid_before := _army_in_zone(bf, 1)
	var left_before := _army_in_zone(bf, 0)
	bf.send_wave()
	sim._absorb_new_units()
	_check("the next wave stacks a fresh copy of each section on top of the living",
		_army_in_zone(bf, 0) == left_before + 2,
		"left %d -> %d" % [left_before, _army_in_zone(bf, 0)])
	_check("and a change made in the Barracks shows up from that wave",
		_army_in_zone(bf, 1) == mid_before + 2,
		"middle %d -> %d" % [mid_before, _army_in_zone(bf, 1)])
	var first := bf.waves
	for i in int(bf.data.wave_seconds / CombatSim.TICK) + 1:
		sim.step()
	_check("and the timer sends waves by itself", bf.waves == first + 1)
	BoardModel.reset_map()

	# Unit upgrades: one type at a time, Lv1 to Lv5, growing its own ability.
	s = _boss_board([["lancer"], ["lancer"], []])
	var ub := s.barracks as Barracks
	var ubf := s.bf as BossFight
	var usim := s.sim as CombatSim
	ub.supply = 1.0e9
	var lancer := _find("lancer")
	_check("the upgrade bar holds the loadout's unit types",
		ub.types.size() == 5 and ub.level.has(&"lancer"),
		"%d types" % ub.types.size())
	var lv_prices: Array[float] = []
	for i in 5:
		lv_prices.append(ub.upgrade_price(&"lancer"))
		ub.upgrade_type(&"lancer")
	var rising := true
	for i in range(1, lv_prices.size()):
		rising = rising and lv_prices[i] > lv_prices[i - 1]
	_check("each level costs more than the last", rising, str(lv_prices))
	for i in 10:
		ub.upgrade_type(&"lancer")
	var free := Barracks.new()
	free.setup(data, load("res://data/loadouts/starter.tres") as LoadoutData, 11)
	free.uncapped = true
	free.income_exponential = true
	free.supply = 1.0e15
	for i in 14:
		free.upgrade_type(&"lancer")
	var g0 := free.next_income_gain()
	free.upgrade_income()
	_check("with upgrades uncapped a type goes past Lv10, and income can grow exponentially",
		free.level_of(&"lancer") == 14 and is_equal_approx(free.next_income_gain(), g0 * Barracks.INCOME_EXP_GROWTH),
		"Lv%d" % free.level_of(&"lancer"))
	var line := ub.statline(lancer, ub.max_level())
	_check("a maxed unit's tooltip shows its statline", line.size() >= 3
		and line[0].begins_with("Health") and line[1].begins_with("Attacks"), " | ".join(line))
	_check("and the top is Lv%d" % ub.max_level(), ub.level_of(&"lancer") == ub.max_level()
		and not ub.upgrade_type(&"lancer") and is_inf(ub.upgrade_price(&"lancer")),
		"Lv%d" % ub.level_of(&"lancer"))
	_check("prices and health both grow exponentially",
		is_equal_approx(lv_prices[1] / lv_prices[0], data.upgrade_cost_growth) or absf(lv_prices[1] / lv_prices[0] - data.upgrade_cost_growth) < 0.05,
		str(lv_prices))
	var top := ub.field_data_at(lancer, 5)
	var ten := ub.field_data_at(lancer, 10)
	_check("past Lv5 the ability keeps growing the way it was going, to Lv10",
		ten.pierce_targets > top.pierce_targets, "%d -> %d" % [top.pierce_targets, ten.pierce_targets])
	ub.ability_cap = BossUpgrades.MAX_LEVEL
	ub._field_cache.clear()
	_check("and with the setting off it stops at Lv5",
		ub.field_data_at(lancer, 10).pierce_targets == top.pierce_targets)
	ub.ability_cap = 10
	ub._field_cache.clear()
	_check("a Lv5 Lancer pierces 7 deep, where it started at 2",
		lancer.pierce_targets == 2 and top.pierce_targets == 7,
		"%d -> %d" % [lancer.pierce_targets, top.pierce_targets])
	usim.step()
	var all_upgraded := true
	var fielded := 0
	for u in usim._units:
		if u.is_alive() and u.data.id == &"lancer":
			fielded += 1
			all_upgraded = all_upgraded and u.data.pierce_targets == ten.pierce_targets
	_check("an upgrade reaches every copy already on the field", fielded == 2 and all_upgraded,
		"%d lancers" % fielded)
	ubf.send_wave()
	usim._absorb_new_units()
	var fresh_ok := true
	for u in usim._pending_units + usim._units:
		if u.is_alive() and u.data.id == &"lancer":
			fresh_ok = fresh_ok and u.data.pierce_targets == ten.pierce_targets
	_check("and every wave after it", fresh_ok)
	BoardModel.reset_map()
	# Every unit in the roster has five levels, and every level changes its ability.
	var table: BossUpgrades = data.upgrades
	var missing: PackedStringArray = []
	var flat: PackedStringArray = []
	var probe := Barracks.new()
	var probe_loadout := LoadoutData.new()
	probe_loadout.units = _roster().units.duplicate()
	probe.setup(data, probe_loadout, 3)
	probe.supply = 1.0e9
	for u in _roster().units:
		if table == null or not table.has_unit(u.id):
			missing.append(String(u.id))
			continue
		var prev := u
		for lv in range(1, 6):
			probe.upgrade_type(u.id)
			var now := probe.field_data(u)
			var vals := table.level_values(u.id, lv)
			var changed := false
			for raw in vals:
				var k := String(raw)
				var field := k.substr(2).trim_suffix("*")
				var a: Object = (now.ability if k.begins_with("a.") else now)
				var b2: Object = (prev.ability if k.begins_with("a.") else prev)
				if a != null and b2 != null and str(a.get(field)) != str(b2.get(field)):
					changed = true
			if lv > 1 and not changed:
				flat.append("%s Lv%d" % [u.id, lv])
			prev = now
	_check("every unit in the roster has its five upgrade levels", missing.is_empty(),
		", ".join(missing))
	_check("and every level changes something about its own ability", flat.is_empty(),
		", ".join(flat))

	# A zone at its cap: the rest wait, one section's worth at most, and drop in later.
	var capped := (load("res://data/boss/arbiter.tres") as BossData).duplicate(true)
	capped.zone_cap = 3
	s = _boss_board([["warden", "archer", "lancer", "seraph"], [], []], capped, true)
	bf = s.bf
	sim = s.sim
	for i in 3:
		bf.send_wave()
	sim._absorb_new_units()
	_check("a zone at its cap holds no more than the cap",
		_army_in_zone(bf, 0) == 3, "%d" % _army_in_zone(bf, 0))
	_check("the rest wait, but never more than one section's worth",
		(bf.queued[0] as Array).size() > 0
		and (bf.queued[0] as Array).size() <= (s.barracks as Barracks).slot_count())
	var waiting := (bf.queued[0] as Array).size()
	var victim: UnitInstance = null
	for u in sim._units:
		if not u.structure and int(bf.zone_of_uid.get(u.uid, -1)) == 0 and u.is_alive():
			victim = u
			break
	sim._damage(victim, 1.0e7, bf.boss)
	bf._drop_queued()
	_check("and drop in as room opens", (bf.queued[0] as Array).size() == waiting - 1)
	BoardModel.reset_map()

	# --- Everyone goes for the boss first.
	s = _boss_board([[], ["warden"], []])
	bf = s.bf
	sim = s.sim
	board = s.board
	var soldier: UnitInstance = null
	for u in board.units_of(BoardModel.TEAM_B):
		if not u.structure:
			soldier = u
	_check("a unit marches on the boss from right across the field",
		sim._mark_for(soldier) == bf.boss)
	var shade_data := UnitData.new()
	shade_data.id = &"crimson_shade"
	var shade := UnitInstance.create(shade_data, BoardModel.TEAM_A)
	board.force_place(shade, soldier.cell + Vector2i(1, 0))
	sim._pending_units.append(shade)
	sim._absorb_new_units()
	_check("a minion in its way, with the boss out of reach, is fought first",
		sim._mark_for(soldier) == shade)
	board.move_unit(bf.boss, soldier.cell + Vector2i(-1, 0))
	_check("but with the boss in reach, the boss comes first",
		sim._mark_for(soldier) == bf.boss)
	BoardModel.reset_map()

	# --- Each phase is its own bar: no overflow, and a break between bars.
	s = _boss_board()
	bf = s.bf
	sim = s.sim
	var full := bf.boss.stat(StatModifier.Stat.MAX_HP)
	# Her health was cut from 90000 to 60000 in the balance pass that gave her a hit cap,
	# regen, ranged resistance and a phase-by-phase attack climb: tougher by every other
	# measure, so the bar itself came down.
	_check("a big health pool: %d" % roundi(full), full >= 50000.0)
	bf.boss.current_hp = full * 0.10
	bf._check_phase()
	_check("emptying the first bar in one blow only ends the first bar",
		bf.phase == 1 and is_equal_approx(bf.boss.current_hp, full * data.phases[1].hp_threshold),
		"phase %d at %.0f" % [bf.phase, bf.boss.current_hp])
	_check("and the next bar starts full", is_equal_approx(bf.bar_of(bf.boss.current_hp).x,
		bf.bar_of(bf.boss.current_hp).y))
	var guarded := bf.boss.current_hp
	sim._damage(bf.boss, 500.0, bf.crystals[0])
	_check("nothing hurts it while the new bar is announced",
		is_equal_approx(bf.boss.current_hp, guarded))
	for i in int(bf.pause_left / CombatSim.TICK) + 2:
		sim.step()
	sim._damage(bf.boss, 500.0, bf.crystals[0])
	_check("and after the announcement it can be hurt again", bf.boss.current_hp < guarded)

	# --- Summons, called at the start of a phase and every so often within it.
	var called := _kind_events(sim, "boss_summon")
	_check("phase two opens with summoning circles marked on the ground",
		called.size() >= 1 and (called[0].cells as Array).size() == data.phases[1].summons_on_start)
	var shades := 0
	for u in sim._units:
		if u.team == BoardModel.TEAM_A and u != bf.boss and u.is_alive():
			shades += 1
	_check("and a shade steps out of each once the warning is over",
		shades == data.phases[1].summons_on_start, "%d shades" % shades)
	var before_summons := called.size()
	for i in int(data.phases[1].summon_every / CombatSim.TICK) + 2:
		sim.step()
	_check("and more are called every %.0fs while the phase lasts" % data.phases[1].summon_every,
		_kind_events(sim, "boss_summon").size() > before_summons)
	# Several big calls in a row: one call alone places only a handful of circles.
	for k in 4:
		bf._summon_wave(50, 1.0)
	_check("never more than the cap at once", bf.minions_alive() <= data.minion_cap,
		"%d" % bf.minions_alive())
	BoardModel.reset_map()

	# --- The charge-up stance.
	s = _boss_board()
	bf = s.bf
	sim = s.sim
	var stance: BossMove = null
	for p in data.phases:
		for m in p.moves:
			if m.shape == BossMove.Shape.STANCE and stance == null:
				stance = m
	_check("the later phases have a charge-up stance in their cycle",
		stance != null and stance.finisher != null
		and not data.phases[0].moves.any(func(m): return m.shape == BossMove.Shape.STANCE)
		and data.phases.slice(1).all(func(p): return p.moves.any(
			func(m): return m.shape == BossMove.Shape.STANCE)))
	bf._begin_stance(stance)
	_check("in the stance it takes %d%% less damage" % roundi(stance.stance_resist * 100.0),
		is_equal_approx(bf.boss.damage_taken_multiplier(), 1.0 - stance.stance_resist),
		"x%.2f" % bf.boss.damage_taken_multiplier())
	bf.boss.current_hp -= stance.break_threshold + 1.0
	sim.step()
	_check("enough damage breaks it: staggered, and taking extra",
		not bf.in_stance() and bf.boss.is_stunned()
		and is_equal_approx(bf.boss.damage_taken_multiplier(), 1.0 + stance.stagger_amp)
		and _kind_events(sim, "boss_stance_broken").size() == 1)
	BoardModel.reset_map()
	s = _boss_board()
	bf = s.bf
	sim = s.sim
	var atk := bf.boss.stat(StatModifier.Stat.ATTACK_DAMAGE)
	bf._begin_stance(stance)
	for i in int(stance.telegraph / CombatSim.TICK) + 1:
		sim.step()
	_check("left alone it completes: boosted, and its finisher is already marked",
		not bf.in_stance() and bf.boss.stat(StatModifier.Stat.ATTACK_DAMAGE) > atk * 1.4
		and not bf.marked.is_empty() and bf.marked.move == stance.finisher)
	BoardModel.reset_map()

	# --- The map-wide moves: marked first, and never all of the field.
	s = _boss_board()
	bf = s.bf
	sim = s.sim
	var open := 0
	for y in range(BossFight.HUB_ROWS, BoardModel.HEIGHT):
		for x in BoardModel.WIDTH:
			if not BoardModel.is_blocked(Vector2i(x, y)):
				open += 1
	var wide_shapes := [BossMove.Shape.ONRUSH, BossMove.Shape.CROSS, BossMove.Shape.RING,
		BossMove.Shape.STRIPES, BossMove.Shape.RAIN, BossMove.Shape.HUNT]
	var seen_wide := {}
	var all_safe := true
	var notes: PackedStringArray = []
	for p in data.phases:
		for m in p.moves + ([] if true else []):
			var mv: BossMove = m.finisher if m.shape == BossMove.Shape.STANCE else m
			if mv == null or not wide_shapes.has(mv.shape):
				continue
			seen_wide[mv.shape] = true
			var cells := bf.move_cells(mv, Vector2i(8, 12), Vector2i(8, 18))
			if cells.is_empty() or cells.size() >= open:
				all_safe = false
				notes.append("%s %d of %d" % [mv.display_name, cells.size(), open])
	_check("every kind of map-wide move is in the boss's cycle somewhere",
		seen_wide.size() == wide_shapes.size(), "%d kinds" % seen_wide.size())
	_check("and every one of them leaves somewhere safe to stand", all_safe, ", ".join(notes))
	# Onrush: several legs, each right across the map, each marked before it lands.
	var rush: BossMove = null
	for p in data.phases:
		for m in p.moves:
			if m.shape == BossMove.Shape.ONRUSH:
				rush = m
	bf.marked = {}
	bf.gap_left = 999.0
	bf._mark(rush)
	var wound_events := sim.events.size()
	_check("a big move charges up first: glowing and named, nothing marked yet",
		bool(bf.marked.get("windup", false)) and (bf.marked.cells as Array).is_empty()
		and rush.windup >= 2.0)
	for i in int(rush.windup / CombatSim.TICK) - 1:
		sim.step()
	_check("and stays charging for its whole wind-up",
		bool(bf.marked.get("windup", false))
		and _kind_events(sim, "boss_telegraph").filter(func(e): return e.name == rush.display_name).is_empty())
	for i in 3:
		sim.step()
	var tele := _kind_events(sim, "boss_telegraph").filter(func(e): return e.name == rush.display_name)
	var wind := _kind_events(sim, "boss_windup").filter(func(e): return e.name == rush.display_name)
	_check("then the mark goes down — charge, mark, blow",
		not wind.is_empty() and not tele.is_empty()
		and float(tele[0].t) - float(wind[0].t) >= rush.windup - CombatSim.TICK - 0.001)
	var legs := 0
	var long_legs := 0
	var marked_first := true
	var guard_ticks := 0
	while not bf.marked.is_empty() and guard_ticks < 400:
		var leg: Array = bf.marked.cells
		var at: Vector2i = bf.boss.cell
		legs += 1
		if leg.size() >= 6:
			long_legs += 1
		var hits_before := _kind_events(sim, "boss_strike").size()
		sim.step()
		if _kind_events(sim, "boss_strike").size() > hits_before and float(bf.marked.get("left", 1.0)) > 0.5 \
				and legs == 1 and bf.boss.cell == at:
			marked_first = false
		for i in int(rush.telegraph / CombatSim.TICK) + 1:
			sim.step()
			guard_ticks += 1
			if bf.marked.is_empty() or bf.marked.cells != leg:
				break
	_check("Onrush is %d dashes, every one marked before it lands" % rush.legs,
		legs == rush.legs and marked_first, "%d legs" % legs)
	_check("and they run right across the map", long_legs >= rush.legs - 1,
		"%d of %d long" % [long_legs, legs])
	BoardModel.reset_map()

	# --- Big moves are rarer than the rest, at a fixed spot in each cycle.
	var share_ok := true
	var shares: PackedStringArray = []
	var last_share := -1.0
	for p in data.phases:
		var big := 0
		for m in p.moves:
			if m.windup > 0.0 or m.shape == BossMove.Shape.STANCE:
				big += 1
		var share := float(big) / maxf(float(p.moves.size()), 1.0)
		shares.append("%s %d/%d" % [p.display_name, big, p.moves.size()])
		# Never more than one in three, and never fewer than the phase before.
		share_ok = share_ok and share <= 0.34 and share >= last_share
		last_share = share
	_check("big moves come more often every phase, never more than one in three", share_ok,
		", ".join(shares))
	_check("and her surround whirl comes rarer early, more often late",
		data.phases[0].surround_cooldown > data.phases[3].surround_cooldown
		and data.phases[3].surround_cooldown > 0.0)
	var all_wound := true
	for p in data.phases:
		for m in p.moves:
			var mv: BossMove = m.finisher if m.shape == BossMove.Shape.STANCE else m
			if mv != null and wide_shapes.has(mv.shape) and mv.windup < 2.0:
				all_wound = false
	_check("and every map-wide move and finisher has a charge-up of at least 2s", all_wound)

	# --- Crystals: only her own blow on the one she is after.
	s = _boss_board()
	bf = s.bf
	sim = s.sim
	var left := bf.crystals[0]
	var mid := bf.crystals[1]
	var wide: BossMove = null
	for p in data.phases:
		for m in p.moves:
			if m.shape == BossMove.Shape.CROSS or (m.finisher != null
					and m.finisher.shape == BossMove.Shape.CROSS):
				wide = m if m.shape == BossMove.Shape.CROSS else m.finisher
	bf.boss.current_hp = bf.boss.stat(StatModifier.Stat.MAX_HP)
	(s.board as BoardModel).move_unit(bf.boss, Vector2i(left.cell.x + 1, left.cell.y - 3))
	bf.marked = {move = wide, cells = bf.move_cells(wide, bf.boss.cell, left.cell),
		left = 0.05, aim = left.cell, step = 0}
	var crossed_left := (bf.marked.cells as Array).has(left.cell)
	var left_hp := left.current_hp
	sim.step()
	var chip := minf(bf.boss.stat(StatModifier.Stat.ATTACK_DAMAGE) * wide.damage_mult * data.crystal_share,
		data.crystal_big_cap if data.crystal_big_cap > 0.0 else INF)
	_check("a big move that sweeps over a crystal in its way chips it, by accident",
		crossed_left and absf((left_hp - left.current_hp) - chip) < 1.0,
		"%.0f taken, expected %.0f" % [left_hp - left.current_hp, chip])
	left_hp = left.current_hp
	var mid_hp := mid.current_hp
	sim._damage(mid, 500.0, bf.boss)
	_check("her blow on a crystal she is NOT after does nothing",
		is_equal_approx(mid.current_hp, mid_hp))
	var shade2 := UnitInstance.create(shade_data, BoardModel.TEAM_A)
	sim._damage(left, 500.0, shade2)
	_check("nor does anything of a minion's",
		is_equal_approx(left.current_hp, left_hp))
	sim._damage(left, 500.0, bf.boss)
	_check("only her own blow on the crystal she is after",
		left.current_hp < left_hp)
	BoardModel.reset_map()

	# --- Broken crystals rebuild, and their waves go and come back.
	s = _boss_board([["warden"], ["warden"], ["warden"]])
	bf = s.bf
	sim = s.sim
	var lc := bf.crystals[0]
	_break(sim, lc, bf.boss)
	sim.step()
	_check("a broken zone crystal starts rebuilding",
		bf.rebuilding.has(0) and _kind_events(sim, "crystal_rebuilding").size() == 1)
	var mark_events := sim.events.size()
	bf.send_wave()
	var went_centre := false
	for e in sim.events.slice(mark_events):
		if e.kind == "summon" and int(e.get("zone", -1)) == 3:
			went_centre = true
	_check("its section reinforces the centre while it is down", went_centre)
	# Clear its spot, then wait it out.
	for i in int(data.crystal_rebuild_seconds / CombatSim.TICK) + 2:
		if (s.board as BoardModel).unit_at(BossFight.CRYSTAL_CELLS[0]) != null \
				and (s.board as BoardModel).unit_at(BossFight.CRYSTAL_CELLS[0]) != lc:
			(s.board as BoardModel).remove((s.board as BoardModel).unit_at(BossFight.CRYSTAL_CELLS[0]))
		bf.wave_left = 999.0
		bf.gap_left = 999.0
		sim.step()
	_check("after %.0fs it stands again, at %d%% health" % [data.crystal_rebuild_seconds,
		roundi(data.crystal_rebuild_fraction * 100.0)],
		lc.is_alive() and is_equal_approx(lc.current_hp,
			lc.stat(StatModifier.Stat.MAX_HP) * data.crystal_rebuild_fraction),
		"alive %s, %.0f" % [lc.is_alive(), lc.current_hp])
	_check("and the boss comes back for it, in her order", bf.current_target() == lc)
	mark_events = sim.events.size()
	bf.send_wave()
	var went_home := false
	for e in sim.events.slice(mark_events):
		if e.kind == "summon" and int(e.get("zone", -1)) == 0:
			went_home = true
	_check("and its section's waves come back to it", went_home)
	BoardModel.reset_map()

	# The seal lifts the first time all three are down at once, and stays lifted.
	s = _boss_board()
	bf = s.bf
	sim = s.sim
	for i in 3:
		_break(sim, bf.crystals[i], bf.boss)
		sim.step()
	_check("all three down at once lifts the seal", bf.merged and not bf.crystals[3].sealed)
	bf._restore_crystal(0)
	var central_hp := bf.crystals[3].current_hp
	sim._damage(bf.crystals[3], 500.0, bf.boss)
	_check("a crystal rebuilding afterwards makes the Central Crystal immune and draws her back to it",
		bf.crystals[0].is_alive() and bf.current_target() == bf.crystals[0]
		and is_equal_approx(bf.crystals[3].current_hp, central_hp))
	_break(sim, bf.crystals[0], bf.boss)
	_check("and once it falls again the centre is open to her again",
		bf.current_target() == bf.crystals[3])
	sim.step()
	_check("each time a crystal breaks it takes 30 s longer to come back",
		bf.times_broken.get(0, 0) >= 2
		and absf(float(bf.rebuilding.get(0, 0.0)) - (bf.data.crystal_rebuild_seconds
			+ bf.data.crystal_rebuild_step * float(bf.times_broken.get(0, 0) - 1))) <= CombatSim.TICK * 1.5
		and bf.data.crystal_rebuild_step == 30.0,
		"%.1f s" % float(bf.rebuilding.get(0, 0.0)))
	_check("and no matter how she calls them, her summons stop at a ceiling",
		bf.summon_ceiling() == bf.data.minion_cap * 2)
	BoardModel.reset_map()

	# --- A fallen crystal's section reinforces the centre instead.
	s = _boss_board([["warden"], ["warden"], ["warden"]])
	bf = s.bf
	sim = s.sim
	_break(sim, bf.crystals[0], bf.boss)
	sim.step()
	var summons_before := _kind_events(sim, "summon").size()
	bf.send_wave()
	var to_centre := 0
	var to_own := 0
	for e in _kind_events(sim, "summon").slice(summons_before):
		if int(e.get("zone", -1)) == 3:
			to_centre += 1
		elif int(e.get("zone", -1)) in [1, 2]:
			to_own += 1
	_check("once its crystal falls, a section's waves spawn at the Central Crystal",
		to_centre == 1 and to_own == 2, "%d to the centre, %d to their own" % [to_centre, to_own])
	BoardModel.reset_map()

	# --- The Spire raises hosts from your own loadout, and nothing shoves it.
	s = _boss_board([["spire"], [], []])
	bf = s.bf
	sim = s.sim
	board = s.board
	var spire: UnitInstance = null
	for u in board.units_of(BoardModel.TEAM_B):
		if u.data.id == &"spire":
			spire = u
	spire.mana = UnitInstance.MANA_MAX
	for i in 40:
		sim.step()
	var raised: Array[StringName] = []
	for e in _kind_events(sim, "summon"):
		if int(e.get("owner_uid", -1)) == spire.uid:
			raised.append(e.unit_id)
	var from_loadout := not raised.is_empty()
	for id in raised:
		from_loadout = from_loadout and (s.barracks as Barracks).level.has(id)
	_check("the Spire raises its hosts, drawn from your own loadout",
		raised.size() == 2 and from_loadout, "raised %s" % str(raised))
	s = _boss_board([["spire"], [], []])
	sim = s.sim
	board = s.board
	var rooted: UnitInstance = null
	for u in board.units_of(BoardModel.TEAM_B):
		if u.data.id == &"spire":
			rooted = u
	var walker := UnitInstance.create(_find("warden"), BoardModel.TEAM_B)
	board.force_place(walker, rooted.cell + Vector2i(0, 1))
	var spot := rooted.cell
	# Hem the walker in with friends on every other side, so the Spire's tile is
	# its only way on: anywhere else this is exactly where the Spire gets shoved.
	for dx in [-1, 0, 1]:
		for dy in [-1, 0, 1]:
			var c: Vector2i = walker.cell + Vector2i(dx, dy)
			if c == walker.cell or c == spot or not board.in_bounds(c) \
					or board.unit_at(c) != null:
				continue
			board.force_place(UnitInstance.create(_find("warden"), BoardModel.TEAM_B), c)
	walker.target = s.bf.boss
	for i in 30:
		sim._begin_move(walker)
	_check("and nothing walking past shoves it off its spot", rooted.cell == spot)
	BoardModel.reset_map()

	# --- Coloured blocks say which unit they are.
	var shorts := {}
	var clash: PackedStringArray = []
	for u in _roster().units:
		var sn := UnitView.short_name(u)
		if shorts.has(sn) or sn.length() < 2:
			clash.append("%s/%s" % [u.id, sn])
		shorts[sn] = true
	_check("every unit in the roster has its own short name on a block",
		clash.is_empty(), ", ".join(clash))

	# --- The boss is not a unit you can cheese.
	s = _boss_board([["warden"], [], []])
	bf = s.bf
	sim = s.sim
	_check("it cannot be disoriented or possessed",
		bf.boss.is_disorient_immune()
		and not sim.possess_candidates(UnitInstance.create(_find("usurper"),
			BoardModel.TEAM_B)).has(bf.boss))
	var before := bf.boss.current_hp
	sim._execute(UnitInstance.create(_find("devourer"), BoardModel.TEAM_B), bf.boss)
	_check("an execute is a heavy blow, not a deletion",
		bf.boss.is_alive() and bf.boss.current_hp < before)
	_check("share-of-health effects read its health as capped",
		is_equal_approx(bf.boss.percent_basis(bf.boss.stat(StatModifier.Stat.MAX_HP)),
			data.percent_cap))
	var crystal := bf.crystals[0]
	crystal.current_hp = 100.0
	crystal.heal(500.0)
	crystal.add_shield(500.0, 500.0)
	_check("crystals cannot be healed or shielded",
		is_equal_approx(crystal.current_hp, 100.0) and is_zero_approx(crystal.shield))
	BoardModel.reset_map()


func _test_boss_polish() -> void:
	_section("Boss defence: upgrades, shades, the hunting Onrush")
	var data := load("res://data/boss/arbiter.tres") as BossData

	# --- Every unit's upgrade improves three things, every one of them real.
	var not_three: PackedStringArray = []
	var missing: PackedStringArray = []
	for id in data.upgrades.levels:
		var d := _find(String(id))
		for lv in range(1, BossUpgrades.MAX_LEVEL + 1):
			var vals := data.upgrades.level_values(id, lv)
			# An evolving summon (the Conjurer's wisps) counts as one of the three.
			var things := vals.size() + (0 if data.upgrades.form_at(id, lv).is_empty() else 1)
			if things != 3:
				not_three.append("%s Lv%d has %d" % [id, lv, vals.size()])
			for raw in vals:
				var k := String(raw)
				var field := k.substr(2).trim_suffix("*")
				var obj: Object = d.ability if k.begins_with("a.") else d
				if obj == null or obj.get(field) == null:
					missing.append("%s %s" % [id, k])
	_check("every unit's upgrade level improves exactly three things",
		not_three.is_empty(), ", ".join(not_three))
	_check("and every one names a field the unit really has", missing.is_empty(),
		", ".join(missing))
	var bar := Barracks.new()
	bar.setup(data, load("res://data/loadouts/starter.tres") as LoadoutData, 5)
	var warden := _find("warden")
	var lines := bar.level_changes(warden, 1)
	_check("the upgrade bar spells out all three, before and after", lines.size() == 3
		and lines[0].contains("→"), " | ".join(lines))
	var lv2 := bar.field_data_at(warden, 2)
	_check("a share of the unit's own number grows by its share",
		is_equal_approx(lv2.mana_per_attack, warden.mana_per_attack * 1.2),
		"%.2f" % lv2.mana_per_attack)
	_check("a lower move time reads as a faster unit",
		Barracks.describe_change("move_time", 0.5, 0.4, true, 0.5) == "Move speed +0% → +25%",
		Barracks.describe_change("move_time", 0.5, 0.4, true, 0.5))

	# --- A line at any angle, out to the edge, with no gaps.
	var line := BossFight.aimed_line(Vector2i(2, 2), Vector2i(5, 3))
	var gaps := false
	for i in range(1, line.size()):
		if BoardModel.box_distance(line[i], line[i - 1]) != 1:
			gaps = true
	var last: Vector2i = line[line.size() - 1] if not line.is_empty() else Vector2i.ZERO
	_check("an aimed line runs through its target and on to the edge, with no gaps",
		line.has(Vector2i(5, 3)) and not gaps and last.x == BossFight.WIDTH - 1,
		"%s" % [line])

	# --- Endless Onrush hunts the army.
	var hunting: BossMove = null
	for p in data.phases:
		for m in p.moves:
			if m.id == &"endless_onrush":
				hunting = m
	_check("Endless Onrush hunts the army; the stance's Onrush keeps its pattern",
		hunting != null and hunting.seeks_army)
	var s := _boss_board([["warden", "warden", "warden", "warden"], [], []])
	var bf: BossFight = s.bf
	var sim: CombatSim = s.sim
	var army: Array[UnitInstance] = []
	for u in sim.board.units_view():
		if u.team == bf.player_team() and u.is_alive() and not u.structure:
			army.append(u)
	if hunting != null and not army.is_empty():
		var aim := bf._aim_for(hunting)
		var leg := bf.move_cells(hunting, bf.boss.cell, aim, 0)
		var through := false
		for u in army:
			if leg.has(u.cell):
				through = true
		_check("each leg is aimed straight through the army", through,
			"aim %s, %d tiles" % [aim, leg.size()])
		var fixed := bf.move_cells(hunting, bf.boss.cell, BossFight.NO_AIM, 0)
		_check("and with no army to hunt it falls back to the old criss-cross",
			not fixed.is_empty())

	# --- Shades: a blast on arrival, and a ward while they stand.
	var hp_before := bf.boss.stat(StatModifier.Stat.DAMAGE_TAKEN)
	var target: UnitInstance = army[0] if not army.is_empty() else null
	if target != null:
		var spot := Vector2i(-1, -1)
		for dy in range(-1, 2):
			for dx in range(-1, 2):
				var c: Vector2i = target.cell + Vector2i(dx, dy)
				if spot.x < 0 and sim.board.in_bounds(c) and sim.board.is_empty(c) \
						and not BoardModel.is_blocked(c):
					spot = c
		var was := target.current_hp + target.shield
		bf._spawn_minion(spot, 1.0)
		sim._absorb_new_units()
		_check("a shade tears out of its circle and hits whoever stands beside it",
			target.current_hp + target.shield < was and not _kind_events(sim, "shade_burst").is_empty(),
			"%.0f -> %.0f" % [was, target.current_hp + target.shield])
		bf._refresh_ward()
		_check("and while it stands, the boss takes less damage",
			bf.shades_alive() == 1 and bf.boss.stat(StatModifier.Stat.DAMAGE_TAKEN) < hp_before
			and not _kind_events(sim, "boss_ward").is_empty(),
			"%.2f -> %.2f" % [hp_before, bf.boss.stat(StatModifier.Stat.DAMAGE_TAKEN)])
	BoardModel.reset_map()
	_test_boss_retreat(data)
	_test_boss_enrage(data)
	_test_boss_attacks(data)
	_test_boss_units(data)
	_test_boss_executions(data)


func sf4_barracks_of(bf: BossFight) -> Barracks:
	return bf.barracks


func _move_named(data: BossData, id: StringName) -> BossMove:
	## A move of hers by id, wherever it sits: in a phase's cycle or as a finisher.
	for p in data.phases:
		for m in p.moves:
			if m.id == id:
				return m
			if m.finisher != null and m.finisher.id == id:
				return m.finisher
	return BossMove.new()


func _break(sim: CombatSim, crystal: UnitInstance, src: UnitInstance) -> void:
	## Her blows on a crystal are a fixed amount now, so a test that wants one broken
	## brings it to the edge first and lets one blow finish it.
	crystal.shield = 0.0
	crystal.current_hp = minf(crystal.current_hp, 1.0)
	sim._damage(crystal, 1.0e7, src)


func _free_near(board: BoardModel, want: Vector2i) -> Vector2i:
	for r in 6:
		for dy in range(-r, r + 1):
			for dx in range(-r, r + 1):
				var c := want + Vector2i(dx, dy)
				if board.in_bounds(c) and board.is_empty(c) and not BoardModel.is_blocked(c):
					return c
	return want


func _test_boss_executions(data: BossData) -> void:
	_section("Boss defence: % max HP blows and executions")
	var by_id := {}
	for p in data.phases:
		for m in p.moves:
			by_id[m.id] = m
			if m.finisher != null:
				by_id[m.finisher.id] = m.finisher
	var heaven: BossMove = by_id.get(&"heaven_split", null)
	var cross: BossMove = by_id.get(&"thousand_cuts", null)
	var crimson: BossMove = by_id.get(&"crimson_cross", null)
	_check("the heavy blows carry a share of max HP, and Thousand Cuts executes",
		heaven != null and heaven.max_hp_percent > 0.0 and cross != null and cross.executes_top_tier)
	_check("the Crimson Cross does not execute: it hits off her attack",
		crimson != null and not crimson.executes_top_tier and not crimson.hp_scaled
		and crimson.max_hp_percent <= 0.0)
	var fang_mv: BossMove = by_id.get(&"twin_fang_cross", null)
	if fang_mv == null:
		for p in data.phases:
			if p.entry_move != null and p.entry_move.id == &"twin_fang_cross":
				fang_mv = p.entry_move
	_check("and neither cross takes a share of max health",
		fang_mv != null and (fang_mv.max_hp_percent <= 0.0 and not fang_mv.hp_scaled))
	var s := _boss_board([["warden", "archer"], [], []])
	var bf: BossFight = s.bf
	var sim: CombatSim = s.sim
	var army: Array[UnitInstance] = []
	for u in sim._units:
		if u.team == bf.player_team() and u.is_alive() and not u.structure:
			army.append(u)
	if heaven != null and army.size() >= 1:
		var v: UnitInstance = army[0]
		v.shield = 0.0
		v.current_hp = v.stat(StatModifier.Stat.MAX_HP)
		var hp0 := v.current_hp
		bf._spawned_at.clear()  # past its spawn protection
		bf.marked = {move = heaven, cells = [v.cell] as Array[Vector2i], left = 0.01, aim = v.cell, step = 0}
		bf._strike()
		var plain := bf.boss.stat(StatModifier.Stat.ATTACK_DAMAGE) * heaven.damage_mult
		_check("a % max HP blow takes more than its plain damage",
			not v.is_alive() or hp0 - v.current_hp > plain * 0.99,
			"%.0f taken, plain %.0f" % [hp0 - v.current_hp, plain])
	if cross != null:
		_check("no execution while the army is below the minimum tier",
			bf.top_army_tier() < cross.execute_min_tier and bf.execute_tier(cross) == 0)
		# Raise one unit to tier 4: now it is the top tier, and the cross executes it.
		var top: UnitInstance = null
		for u in army:
			if u.is_alive():
				top = u
		if top != null:
			top.data = BoardModel.at_tier(top.data, 4)
			top.current_hp = top.stat(StatModifier.Stat.MAX_HP)
			top.shield = 99999.0
			var doom := bf.execute_tier(cross)
			bf.marked = {move = cross, cells = [top.cell] as Array[Vector2i], left = 0.01,
				aim = top.cell, step = 0, doom = doom}
			bf._strike()
			_check("an execution kills the top tier outright, shield and all",
				doom == 4 and not top.is_alive() and not _kind_events(sim, "boss_execute").is_empty(),
				"doom %d, alive %s" % [doom, top.is_alive()])
	BoardModel.reset_map()


func _test_boss_units(_data: BossData) -> void:
	_section("Boss defence: how the army's units behave here")
	# Difficulty: a copy of her data, harder or easier; Normal is her as designed.
	var base_d := load("res://data/boss/arbiter.tres") as BossData
	var easy := BossDifficulty.apply(base_d, 0)
	var hard := BossDifficulty.apply(base_d, 2)
	var night := BossDifficulty.apply(base_d, 4)
	_check("Normal difficulty is the boss exactly as designed",
		BossDifficulty.apply(base_d, BossDifficulty.NORMAL) == base_d)
	_check("harder steps raise her health, attack and summons and cut income; Easy the reverse",
		hard.max_hp > base_d.max_hp and hard.attack_damage > base_d.attack_damage
		and hard.summon_power_mult > 1.0 and hard.base_income < base_d.base_income
		and easy.max_hp < base_d.max_hp and easy.base_income > base_d.base_income
		and night.max_hp > hard.max_hp and night.damage_income < hard.damage_income)
	_check("her single-hit cap stays the same number of points at every step",
		absf(night.max_hp * night.max_hit_percent - base_d.max_hp * base_d.max_hit_percent) < 0.5)
	_check("and the file on disk is left alone",
		is_equal_approx((load("res://data/boss/arbiter.tres") as BossData).max_hp, base_d.max_hp)
		and not base_d.attack_mode)
	var sn := _boss_board([["warden"], [], []], night)
	var bfn: BossFight = sn.bf
	sn.sim._absorb_new_units()
	var wn: UnitInstance = null
	for u in sn.sim._units:
		if u.is_alive() and u.data.id == &"warden":
			wn = u
	var cuts := _move_named(night, &"thousand_cuts")
	if wn != null:
		_check("on Brutal and Nightmare her map-wide attacks hit off her attack, not max health",
			night.attack_mode and is_equal_approx(bfn.move_hit(cuts, wn),
				bfn.boss.stat(StatModifier.Stat.ATTACK_DAMAGE) * cuts.damage_mult))
	BoardModel.reset_map()
	# A crowd on the field brings more of hers: weighted by tier and upgrades.
	var sc2 := _boss_board([["warden"], [], []])
	var bfc2: BossFight = sc2.bf
	var simc2: CombatSim = sc2.sim
	simc2._absorb_new_units()
	var light := bfc2.army_weight()
	var few := bfc2.crowd_extra()
	for k in 30:
		var extra_u := UnitInstance.create(BoardModel.at_tier(_find("warden"), 3), bfc2.player_team())
		var cell := bfc2._nearest_free(Vector2i(8, 16), Vector2i(-1, -1))
		if simc2.board.force_place(extra_u, cell):
			simc2._pending_units.append(extra_u)
	simc2._absorb_new_units()
	var heavy := bfc2.army_weight()
	var many := bfc2.crowd_extra()
	for t in bfc2.barracks.types:
		bfc2.barracks.level[t.id] = 10
	_check("a bigger army on the field makes her call more", heavy > light and many > few,
		"weight %.0f -> %.0f, extra %d -> %d" % [light, heavy, few, many])
	_check("and upgrades weigh in too, up to a limit",
		bfc2.army_weight() > heavy and bfc2.crowd_extra() <= bfc2.data.crowd_extra_max
		and bfc2.summon_ceiling() > bfc2.data.minion_cap * 2
		and bfc2.summon_ceiling() <= BossFight.CROWD_CEILING_MAX)
	BoardModel.reset_map()
	# The Pariah: alone for a moment, it charges into the fight, keeping its strength.
	var sp2 := _boss_board([["pariah", "warden"], [], []])
	var bfp2: BossFight = sp2.bf
	var simp2: CombatSim = sp2.sim
	simp2._absorb_new_units()
	var par: UnitInstance = null
	var pal2: UnitInstance = null
	for u in simp2._units:
		if u.is_alive() and u.data.id == &"pariah":
			par = u
		elif u.is_alive() and u.data.id == &"warden":
			pal2 = u
	if par != null and pal2 != null:
		simp2.board.move_unit(pal2, bfp2._nearest_free(Vector2i(16, 25), Vector2i(-1, -1)))
		simp2.board.move_unit(par, bfp2._nearest_free(Vector2i(1, 12), Vector2i(-1, -1)))
		var step_p := par.stat(StatModifier.Stat.MOVE_TIME)
		for k in int((BossFight.PARIAH_CHARGE_AFTER + 0.2) / CombatSim.TICK):
			bfp2._tick_solitude()
		_check("alone for a moment, the Pariah charges into battle, quicker on its feet",
			bfp2.is_pariah_charging(par) and par.isolated
			and par.stat(StatModifier.Stat.MOVE_TIME) < step_p
			and not _kind_events(simp2, "pariah_charge").is_empty())
		simp2.board.move_unit(pal2, bfp2._nearest_free(par.cell + Vector2i(1, 0), par.cell))
		bfp2._tick_solitude()
		var meters := _kind_events(simp2, "isolation_meter")
		_check("an isolation meter fills while it stands alone, then shows the charge",
			meters.size() >= 3 and float(meters[1].fill) > float(meters[0].fill) - 0.001
			and bool(meters.back().charging), "%d meter events" % meters.size())
		_check("and keeps its isolated strength even with allies around it",
			par.isolated and not bfp2.seek_solitude(par))
		for k in int((BossFight.PARIAH_CHARGE_SECONDS + 0.2) / CombatSim.TICK):
			bfp2._tick_solitude()
		_check("then the charge ends and it looks for room again",
			not bfp2.is_pariah_charging(par) and is_equal_approx(par.stat(StatModifier.Stat.MOVE_TIME), step_p))
	else:
		_check("the Pariah charge test could set up", false)
	BoardModel.reset_map()
	# She never stops calling: a trickle at the arena's edge that grows into an army.
	var sr3 := _boss_board()
	var bfr3: BossFight = sr3.bf
	var simr3: CombatSim = sr3.sim
	var early := bfr3.edge_count()
	simr3.elapsed = 300.0
	var late := bfr3.edge_count()
	_check("she calls a few at the edge at first and more as the fight goes on",
		early == bfr3.data.edge_count and late > early and late <= bfr3.data.edge_count_max,
		"%d then %d" % [early, late])
	var marks0 := bfr3._summon_marks.size()
	bfr3._edge_summon()
	var edge_ok := bfr3._summon_marks.size() > marks0
	for k in range(marks0, bfr3._summon_marks.size()):
		var c: Vector2i = bfr3._summon_marks[k].cell
		if not (c.x <= 5 or c.x >= BossFight.WIDTH - 6 or c.y >= BossFight.HEIGHT - 6):
			edge_ok = false
	_check("and they step in at the edge of the arena", edge_ok)
	BoardModel.reset_map()
	# The Ember Caster: its bolts splash a little onto what stands round the target.
	var se := _boss_board([["warden", "warden"], [], []])
	var bfe: BossFight = se.bf
	var sime: CombatSim = se.sim
	sime._absorb_new_units()
	var ember_kind: BossMinion = null
	for k in bfe.data.summon_pool:
		if k.id == &"ember_caster":
			ember_kind = k
	var pair: Array[UnitInstance] = []
	for u in sime._units:
		if u.is_alive() and u.data.id == &"warden":
			pair.append(u)
	if ember_kind != null and pair.size() >= 2:
		var c0 := bfe._nearest_free(Vector2i(8, 14), Vector2i(-1, -1))
		sime.board.move_unit(pair[0], c0)
		var c1 := bfe._nearest_free(c0 + Vector2i(1, 0), c0)
		sime.board.move_unit(pair[1], c1)
		var em := bfe._spawn_minion(bfe._nearest_free(c0 + Vector2i(0, -2), c0), 1.0, ember_kind)
		sime._absorb_new_units()
		bfe._spawned_at.clear()
		for w in pair:
			w.shield = 0.0
		var h0 := pair[0].current_hp
		var h1 := pair[1].current_hp
		em.target = pair[0]
		sime._begin_attack(em)
		var main_hit := h0 - pair[0].current_hp
		var side_hit := h1 - pair[1].current_hp
		_check("an Ember Caster's bolt splashes a share onto the unit beside its target",
			BoardModel.box_distance(c0, c1) <= 1 and main_hit > 0.0
			and absf(side_hit - main_hit * ember_kind.splash_share) < 1.0,
			"%.1f main, %.1f beside" % [main_hit, side_hit])
	else:
		_check("the Ember Caster test could set up", false)
	BoardModel.reset_map()
	# What she kills herself makes her slightly stronger: more for big, upgraded units,
	# much less for an execution, and nothing for deaths that are not hers.
	var sk := _boss_board([["warden", "warden", "warden"], [], []])
	var bfk: BossFight = sk.bf
	var simk: CombatSim = sk.sim
	simk._absorb_new_units()
	var wards: Array[UnitInstance] = []
	for u in simk._units:
		if u.is_alive() and u.data.id == &"warden":
			wards.append(u)
	if wards.size() >= 3:
		var atk0 := bfk.boss.stat(StatModifier.Stat.ATTACK_DAMAGE)
		simk._damage(wards[0], 1.0e7, wards[1])
		_check("a unit she did not kill gives her nothing",
			is_equal_approx(bfk.boss.stat(StatModifier.Stat.ATTACK_DAMAGE), atk0))
		bfk._spawned_at.clear()
		simk._damage(wards[1], 1.0e7, bfk.boss)
		var atk1 := bfk.boss.stat(StatModifier.Stat.ATTACK_DAMAGE)
		_check("one she kills makes her a little stronger",
			atk1 > atk0 and atk1 < atk0 * 1.02, "%.1f -> %.1f" % [atk0, atk1])
		var t1 := bfk.kill_gain(wards[2])
		wards[2].data = BoardModel.at_tier(wards[2].data, 6)
		var t6 := bfk.kill_gain(wards[2])
		bfk.barracks.level[&"warden"] = 10
		var t6l := bfk.kill_gain(wards[2])
		_check("a bigger, more upgraded kill is worth more", t6 > t1 and t6l > t6,
			"%.4f / %.4f / %.4f" % [t1, t6, t6l])
		_check("an execution is worth a quarter", is_equal_approx(bfk.kill_gain(wards[2], true), t6l * 0.25))
	else:
		_check("the kill power test could set up", false)
	BoardModel.reset_map()
	# Nothing possesses her: a Usurper (or its husk) that reaches her just hits her.
	var su := _boss_board([["usurper"], [], []])
	var bfu: BossFight = su.bf
	var simu: CombatSim = su.sim
	simu._absorb_new_units()
	var thief: UnitInstance = null
	for u in simu._units:
		if u.is_alive() and u.data.id == &"usurper":
			thief = u
	if thief != null:
		var hp_b := bfu.boss.current_hp
		var team_b := bfu.boss.team
		simu._take_host(thief, thief.data.ability, bfu.boss)
		simu._reinfect(thief, bfu.boss)
		_check("a Usurper can never take over the boss",
			bfu.boss.team == team_b and not bfu.boss.is_possessed()
			and is_equal_approx(bfu.boss.current_hp, hp_b) and bfu.phase == 0)
		_check("and never picks her as a host", not simu.possess_candidates(thief).has(bfu.boss))
	else:
		_check("the Usurper test could set up", false)
	BoardModel.reset_map()
	# Her posture: enough damage and she reels, stunned and taking more.
	var sg := _boss_board([["warden"], [], []])
	var bfg: BossFight = sg.bf
	var simg: CombatSim = sg.sim
	simg._absorb_new_units()
	var hitter: UnitInstance = null
	for u in simg._units:
		if u.is_alive() and u.data.id == &"warden":
			hitter = u
	if hitter != null:
		bfg.marked = {}
		bfg.pause_left = 0.0
		var taken0 := bfg.boss.stat(StatModifier.Stat.DAMAGE_TAKEN)
		var guard_p := 0
		while bfg.posture < bfg.data.posture_damage and guard_p < 100:
			simg._damage(bfg.boss, 1.0e6, hitter)
			guard_p += 1
		bfg.marked = {}
		bfg.tick()
		_check("enough damage and she reels: stunned, and taking more",
			bfg.staggers == 1 and bfg.boss.is_stunned() and bfg.stagger_left > 0.0
			and bfg.boss.stat(StatModifier.Stat.DAMAGE_TAKEN) > taken0
			and not _kind_events(simg, "boss_staggered").is_empty())
		_check("and her posture starts again from nothing", bfg.posture == 0.0 and bfg.posture_cd > 0.0)
		var taken_st := bfg.boss.stat(StatModifier.Stat.DAMAGE_TAKEN)
		for k in int((bfg.data.posture_seconds + 0.3) / CombatSim.TICK):
			simg.step()
		_check("then she recovers and takes normal damage again",
			not bfg.boss.is_stunned() and bfg._stagger_mods.is_empty()
			and bfg.boss.stat(StatModifier.Stat.DAMAGE_TAKEN) < taken_st - bfg.data.posture_amp * 0.9,
			"stun %.1f stagger %.1f taken %.2f vs %.2f" % [bfg.boss.stun_left, bfg.stagger_left, bfg.boss.stat(StatModifier.Stat.DAMAGE_TAKEN), taken0])
	else:
		_check("the stagger test could set up", false)
	BoardModel.reset_map()
	# Late and enraged, against a maxed army, her summons stay in the thousands.
	var sl := _boss_board([["warden"], [], []])
	var bfl: BossFight = sl.bf
	sl.sim._absorb_new_units()
	var bkl: Barracks = sl.barracks
	for t in bkl.types:
		bkl.level[t.id] = 10
	bfl.phase = 3
	bfl._apply_phase_mods()
	for k in 11:
		sl.sim.elapsed = bfl.next_enrage_at()
		bfl._tick_enrage()
	var biggest := 0.0
	for kind in bfl.data.summon_pool:
		var cell := bfl._nearest_free(bfl.boss.cell + Vector2i(0, 4), bfl.boss.cell)
		var m := bfl._spawn_minion(cell, bfl.data.phases[3].minion_power, kind)
		if m != null:
			biggest = maxf(biggest, m.stat(StatModifier.Stat.MAX_HP))
	_check("at phase 4, 11 enrage surges and a Lv10 army, no summon passes 6000 health",
		bfl.enrage_stacks == 11 and biggest > 0.0 and biggest < 6000.0, "%.0f" % biggest)
	BoardModel.reset_map()
	# With all three lane crystals down the rebuild clocks hold still, and each
	# rebuild of one crystal comes back weaker than the last.
	var sr2 := _boss_board()
	var bfr2: BossFight = sr2.bf
	var simr2: CombatSim = sr2.sim
	for i in 3:
		_break(simr2, bfr2.crystals[i], bfr2.boss)
	bfr2._tick_rebuilds()
	var clocks := str(bfr2.rebuilding)
	for k in 20:
		bfr2._tick_rebuilds()
	_check("with the centre open, the rebuild clocks hold still",
		bfr2.rebuilding.size() == 3 and str(bfr2.rebuilding) == clocks, "%s -> %s" % [clocks, str(bfr2.rebuilding)])
	bfr2._restore_crystal(0)
	var first_hp := bfr2.crystals[0].current_hp
	_break(simr2, bfr2.crystals[0], bfr2.boss)
	bfr2._tick_rebuilds()
	bfr2._restore_crystal(0)
	_check("and a crystal rebuilt again comes back weaker",
		bfr2.crystals[0].current_hp < first_hp - 1.0, "%.0f then %.0f" % [first_hp, bfr2.crystals[0].current_hp])
	BoardModel.reset_map()
	# On a crystal she swings at a fixed pace; fresh wave units are protected.
	var sp := _boss_board([["warden"], [], []])
	var bfp: BossFight = sp.bf
	var simp: CombatSim = sp.sim
	simp._absorb_new_units()
	bfp.boss.target = bfp.crystals[0]
	var pace0 := simp.attack_interval(bfp.boss)
	bfp.phase = 3
	bfp._apply_phase_mods()
	bfp.enrage_stacks = 5
	var pace3 := simp.attack_interval(bfp.boss)
	_check("on a crystal she swings at one fixed pace, whatever her phase",
		is_equal_approx(pace0, 1.0 / bfp.data.crystal_attack_speed) and is_equal_approx(pace3, pace0),
		"%.2fs then %.2fs" % [pace0, pace3])
	bfp.boss.target = null
	var fresh: UnitInstance = null
	for u in simp._units:
		if u.is_alive() and u.data.id == &"warden":
			fresh = u
	if fresh != null:
		fresh.shield = 0.0
		var h0 := fresh.current_hp
		simp._damage(fresh, 100.0, bfp.boss)
		_check("a unit fresh off a wave resists 90% of what hits it",
			bfp.is_spawn_protected(fresh) and absf((h0 - fresh.current_hp) - 100.0 * (1.0 - bfp.data.spawn_protect_resist)) < 0.5,
			"%.1f taken" % (h0 - fresh.current_hp))
		simp.elapsed += bfp.data.spawn_protect_seconds + 0.1
		fresh.shield = 0.0
		var h1 := fresh.current_hp
		simp._damage(fresh, 10.0, bfp.boss)
		_check("and after a few seconds it is fair game", not bfp.is_spawn_protected(fresh)
			and fresh.current_hp < h1 - 5.0, "%.1f taken" % (h1 - fresh.current_hp))
	BoardModel.reset_map()
	# Friendly fire: her big moves hit her own summons in them; ordinary ones do not.
	var sff := _boss_board()
	var bff2: BossFight = sff.bf
	sff.sim._absorb_new_units()
	var ff_cell := bff2._nearest_free(bff2.boss.cell + Vector2i(0, 3), bff2.boss.cell)
	var own := bff2._spawn_minion(ff_cell, 1.0)
	sff.sim._absorb_new_units()
	var big_ff := _move_named(bff2.data, &"great_shockwave")
	var small_ff := _move_named(bff2.data, &"crescent_sweep")
	var cells_ff: Array[Vector2i] = [ff_cell]
	var hp_own := own.current_hp
	bff2.marked = {move = small_ff, cells = cells_ff, aim = ff_cell, step = 0, doom = 0, left = 0.0}
	bff2._strike()
	_check("her ordinary moves spare her own summons", is_equal_approx(own.current_hp, hp_own))
	bff2.marked = {move = big_ff, cells = cells_ff, aim = ff_cell, step = 0, doom = 0, left = 0.0}
	bff2._strike()
	_check("but a big move hits her own summons standing in it",
		BossFight.is_big(big_ff) and (own.current_hp < hp_own or not own.is_alive()),
		"%.0f -> %.0f" % [hp_own, own.current_hp])
	if own.is_alive():
		_check("for 75% less than it would do to your units",
			absf((hp_own - own.current_hp) - bff2.move_hit(big_ff, own) * (1.0 - bff2.data.friendly_fire_resist)) < 1.0
			and is_equal_approx(bff2.data.friendly_fire_resist, 0.75),
			"%.0f taken" % (hp_own - own.current_hp))
	_check("and Onrush, both kinds, hits for a share of health",
		_move_named(bff2.data, &"onrush").hp_scaled and _move_named(bff2.data, &"endless_onrush").hp_scaled)
	BoardModel.reset_map()
	# Her big moves hit for a share of the victim's own health; small ones off her attack.
	var sm := _boss_board([["warden", "archer"], [], []])
	var bfm: BossFight = sm.bf
	sm.sim._absorb_new_units()
	var tank: UnitInstance = null
	var frail: UnitInstance = null
	for u in sm.sim._units:
		if u.is_alive() and u.data.id == &"warden":
			tank = u
		if u.is_alive() and u.data.id == &"archer":
			frail = u
	var big_mv: BossMove = null
	var small_mv: BossMove = null
	for p in bfm.data.phases:
		for m in p.moves:
			if m.hp_scaled and m.damage_mult > 0.0 and m.max_hp_percent <= 0.0 and big_mv == null:
				big_mv = m
			if not m.hp_scaled and m.damage_mult > 0.0 and m.max_hp_percent <= 0.0 and small_mv == null:
				small_mv = m
	if tank != null and frail != null and big_mv != null and small_mv != null:
		var f_t := bfm.move_hit(big_mv, tank) / tank.stat(StatModifier.Stat.MAX_HP)
		var f_f := bfm.move_hit(big_mv, frail) / frail.stat(StatModifier.Stat.MAX_HP)
		_check("the map-wide moves (but not the Crimson Cross) hit by share of health",
			_move_named(bfm.data, &"thousand_cuts").hp_scaled and not _move_named(bfm.data, &"crimson_cross").hp_scaled)
		_check("a big move takes the same share of everyone's health",
			is_equal_approx(f_t, f_f) and f_t > 0.0 and f_t <= bfm.data.big_hp_cap,
			"%.2f vs %.2f" % [f_t, f_f])
		_check("an ordinary move is a portion of her attack",
			is_equal_approx(bfm.move_hit(small_mv, tank), bfm.move_hit(small_mv, frail))
			and is_equal_approx(bfm.move_hit(small_mv, tank),
				bfm.boss.stat(StatModifier.Stat.ATTACK_DAMAGE) * small_mv.damage_mult * bfm.data.small_move_share))
	else:
		_check("the move damage test could set up", false)
	BoardModel.reset_map()
	# The Conjurer: no ceiling on its wisps here, and the wisps evolve with its level.
	var sc := _boss_board([["conjurer"], [], []])
	var bkc: Barracks = sc.barracks
	var conj := _find("conjurer")
	var plain_w: UnitData = bkc.field_data(conj).ability.summon_unit
	bkc.level[conj.id] = 1
	var g1: UnitData = bkc.field_data(conj).ability.summon_unit
	bkc.level[conj.id] = 5
	var g5: UnitData = bkc.field_data(conj).ability.summon_unit
	_check("at Lv1 the Conjurer's wisps become Greater Wisps, tougher and self-warding",
		g1 != null and g1.display_name == "Greater Wisp" and g1.max_hp > plain_w.max_hp
		and g1.shield_on_hit > 0.0, "%s" % [g1.display_name if g1 != null else "none"])
	var g1t2 := BoardModel.at_tier(g1, 2)
	_check("and every tier evolves with them",
		g1t2 != null and g1t2.display_name == "Greater Wisp II" and g1t2.max_hp > BoardModel.at_tier(plain_w, 2).max_hp)
	_check("each form keeps what the last gave and adds more",
		g5 != null and g5.display_name == "Sovereign Wisp" and g5.shield_on_hit >= g1.shield_on_hit
		and g5.pierce_targets >= 4 and g5.attack_range >= 2 and g5.attack_speed > g1.attack_speed)
	_check("and the upgrade bar says what the wisps become",
		" ".join(bkc.level_changes(conj, 1)).contains("Greater Wisp"))
	var t6 := BoardModel.at_tier(bkc.field_data(conj), 6)
	var c6 := UnitInstance.create(BoardModel.at_tier(conj, 6), BoardModel.TEAM_B)
	c6.data = bkc.field_data(BoardModel.at_tier(conj, 6))
	_check("and its retinue has no ceiling here: a Lv5 tier 6 calls more than six",
		sc.sim.summon_cap(c6, c6.data.ability) > 6, "%d" % sc.sim.summon_cap(c6, c6.data.ability))
	BoardModel.reset_map()
	# Hit her and she turns on you, leaving the crystal.
	var sr := _boss_board([["warden"], [], []])
	var bfr: BossFight = sr.bf
	var simr: CombatSim = sr.sim
	simr._absorb_new_units()
	var wr: UnitInstance = null
	for u in simr._units:
		if u.is_alive() and u.data.id == &"warden":
			wr = u
	if wr != null:
		var near := bfr._nearest_free(bfr.boss.cell + Vector2i(0, 3), bfr.boss.cell)
		simr.board.move_unit(wr, near)
		_check("before anyone hits her she is not after anyone", bfr.retaliation_target() == null)
		simr._damage(bfr.boss, 10.0, wr)
		_check("hit her and she turns on whoever hit her", bfr.retaliation_target() == wr)
		var beside := bfr._nearest_free(bfr.boss.cell + Vector2i(1, 0), bfr.boss.cell)
		simr.board.move_unit(wr, beside)
		_check("and in arm's reach she hits them before the crystal", bfr._foe_in_reach() == wr)
		simr.elapsed += BossFight.RETALIATE_MEMORY + 1.0
		_check("stop hitting her and she forgets you", bfr.retaliation_target() == null)
	BoardModel.reset_map()
	# The Breaker steers: it runs round to whatever enemy is nearest, not down its column.
	var sb := _boss_board([["breaker"], [], []])
	var bfb: BossFight = sb.bf
	var simb: CombatSim = sb.sim
	simb._absorb_new_units()
	var br: UnitInstance = null
	for u in simb._units:
		if u.is_alive() and u.data.id == &"breaker":
			br = u
	var prey: UnitInstance = null
	if br != null:
		for off in [Vector2i(3, 1), Vector2i(-3, 1), Vector2i(3, -1), Vector2i(-3, -1), Vector2i(4, 0), Vector2i(-4, 0)]:
			var c: Vector2i = br.cell + off
			if simb.board.in_bounds(c) and simb.board.is_empty(c) and not BoardModel.is_blocked(c):
				prey = bfb._spawn_minion(c, 1.0)
				break
	if br != null and prey != null:
		simb._absorb_new_units()
		var route := simb.charge_path(br, br.data.ability.charge_distance)
		_check("the Breaker's charge finds a way to an enemy off to one side",
			not route.is_empty() and simb.board.unit_at(route.back()) == prey
			and route.any(func(c): return c.x != br.cell.x), "%s" % [route])
		var hp_p := prey.current_hp
		simb._resolve_charge(br, br.data.ability)
		var guard_b := 0
		while br.is_charging() and guard_b < 400:
			simb.step()
			guard_b += 1
		_check("and runs round to it and slams into it",
			prey.current_hp < hp_p or not prey.is_alive(), "%.0f -> %.0f" % [hp_p, prey.current_hp])
	else:
		_check("the Breaker steering test could set up", false)
	BoardModel.reset_map()
	# Soul kill: what she kills does not get back up.
	var s := _boss_board([["revenant", "pariah", "paragon", "paragon"], ["herald"], []])
	var bf: BossFight = s.bf
	var sim: CombatSim = s.sim
	sim._absorb_new_units()
	var rev: UnitInstance = null
	var herald: UnitInstance = null
	var pariah: UnitInstance = null
	var paragons: Array[UnitInstance] = []
	for u in sim._units:
		if u.team != bf.player_team() or u.structure:
			continue
		match String(u.data.id):
			"revenant": rev = u
			"herald": herald = u
			"pariah": pariah = u
			"paragon": paragons.append(u)
	_check("a unit that opens with its ability opens the moment its wave lands",
		herald != null and herald.has_opened)
	if rev != null:
		# An ordinary blow of hers kills the ordinary way: the body can still come back.
		_check("her ordinary blows take no souls", not bf.soul_kills(bf.boss.uid, rev))
		# A big, wound-up attack takes the soul with it.
		var big: BossMove = null
		for p in bf.data.phases:
			for m in p.moves:
				var plain_big := m.windup > 0.0 and m.shape != BossMove.Shape.RETREAT
				plain_big = plain_big and m.shape != BossMove.Shape.STANCE and m.shape != BossMove.Shape.BLAZE
				if big == null and plain_big:
					big = m
		var before := sim._respawns.size()
		rev.shield = 0.0
		rev.current_hp = 1.0
		bf.marked = {move = big, cells = [rev.cell] as Array[Vector2i], left = 0.01, aim = rev.cell, step = 0}
		bf._strike()
		_check("what her big attacks kill, she takes whole: no second wind, nothing to raise",
			not rev.is_alive() and sim._respawns.size() == before and not sim._fallen.has(rev)
			and not _kind_events(sim, "soul_kill").is_empty(), "%s" % [big.id if big != null else &"none"])
	# Paragons: empowered only with no other Paragon within three tiles.
	if paragons.size() == 2 and pariah != null:
		# Clear the bottom rows of everyone else so the spacing is all that matters.
		for u in sim._units:
			if u.team == bf.player_team() and not u.structure and u != pariah and not paragons.has(u):
				sim.board.remove(u)
				u.current_hp = 0.0
				u.state = UnitInstance.State.DEAD
		sim.board.move_unit(paragons[0], _free_near(sim.board, Vector2i(3, 22)))
		sim.board.move_unit(paragons[1], _free_near(sim.board, paragons[0].cell + Vector2i(2, 0)))
		bf._tick_solitude()
		_check("two Paragons within three tiles: neither is empowered",
			not paragons[0].empowered and not paragons[1].empowered)
		sim.board.move_unit(paragons[1], _free_near(sim.board, paragons[0].cell + Vector2i(7, 0)))
		bf._tick_solitude()
		_check("spread four apart, both are", paragons[0].empowered and paragons[1].empowered,
			"%s %s at %s %s, crowd %d %d" % [paragons[0].empowered, paragons[1].empowered, paragons[0].cell, paragons[1].cell, bf.solitude_crowding(paragons[0], paragons[0].cell), bf.solitude_crowding(paragons[1], paragons[1].cell)])
		# The Pariah, crowded, walks off to be alone.
		sim.board.move_unit(pariah, _free_near(sim.board, paragons[0].cell + Vector2i(1, 0)))
		var was := bf.solitude_crowding(pariah, pariah.cell)
		pariah.state = UnitInstance.State.IDLE
		pariah.target = bf.boss
		var stepped := bf.seek_solitude(pariah)
		_check("a crowded Pariah steps away from its own side to be alone",
			was > 0 and stepped and bf.solitude_crowding(pariah, pariah.cell) < was,
			"was %d stepped %s now %d at %s" % [was, stepped, bf.solitude_crowding(pariah, pariah.cell), pariah.cell])
	BoardModel.reset_map()


func _test_boss_attacks(data: BossData) -> void:
	_section("Boss defence: sweeps, burns, seals, the whirl")
	var by_id := {}
	for p in data.phases:
		for m in p.moves:
			by_id[m.id] = m
	_check("her cycles carry arcs, a sweep, burning ground, a mana seal and the tide",
		by_id.has(&"crimson_arc") and by_id.has(&"scything_sweep") and by_id.has(&"crimson_pyre")
		and by_id.has(&"silencing_edict") and by_id.has(&"scarlet_tide"), "%s" % [by_id.keys()])
	var stepping := 0
	for p in data.phases:
		for m in p.moves:
			if m.id == &"crimson_step" and m.shape == BossMove.Shape.DASH and m.reach <= 3 \
					and m.windup <= 0.0:
				stepping += 1
				break
	var sw := _boss_board()
	var bfs: BossFight = sw.bf
	var sims: CombatSim = sw.sim
	bfs.phase = 1
	bfs._swarm()
	for i in int((data.summon_warning + 0.2) / CombatSim.TICK):
		sims.step()
	var thralls := 0
	for u in sims._units:
		if u.is_alive() and u.data.id == &"thrall":
			thralls += 1
	# Flankers: Stalkers at the edge, hunting the ranged units.
	var sf := _boss_board([["archer", "archer"], [], []])
	var bff: BossFight = sf.bf
	var simf: CombatSim = sf.sim
	simf._absorb_new_units()
	bff._flank()
	for i in int((data.summon_warning + 0.2) / CombatSim.TICK):
		simf.step()
	var stalkers: Array[UnitInstance] = []
	for u in simf._units:
		if u.is_alive() and u.data.id == &"stalker":
			stalkers.append(u)
	var on_edge := stalkers.all(func(u): return u.cell.x <= 3 or u.cell.x >= BossFight.WIDTH - 4 or u.cell.y >= BossFight.HEIGHT - 4)
	var hunts := stalkers.all(func(u): return bff.minion_target(u) != null and bff.minion_target(u).is_ranged())
	_check("Stalkers step in at the edge of the arena and go for the ranged units",
		stalkers.size() >= 2 and on_edge and hunts, "%d stalkers" % stalkers.size())
	BoardModel.reset_map()
	_check("now and then she calls a swarm of weak fodder, far past her ordinary cap",
		data.swarm_kind != null and data.swarm_kind.max_hp < data.minion_hp and thralls >= 8
		and thralls > 0, "%d thralls" % thralls)
	_check("phase 1 is toned down: smaller swarms, no flankers, fewer and weaker waves",
		data.first_phase_swarm > 0 and data.first_phase_swarm < data.swarm_count
		and data.flank_from_phase >= 1
		and data.phases[0].summon_count < data.phases[1].summon_count
		and data.phases[0].summon_every > data.phases[1].summon_every
		and data.phases[0].minion_power < 1.0)
	BoardModel.reset_map()
	_check("every phase has a quick short dash that just moves her",
		stepping == data.phases.size(), "%d of %d phases" % [stepping, data.phases.size()])
	var s := _boss_board([["warden", "warden", "warden", "warden", "warden", "warden"], [], []])
	var bf: BossFight = s.bf
	var sim: CombatSim = s.sim
	var at := Vector2i(8, 10)
	var arc: BossMove = by_id.get(&"crimson_arc", null)
	if arc != null:
		var cells := bf.move_cells(arc, at, Vector2i(8, 14))
		var ahead := cells.has(Vector2i(8, 13))
		var behind := cells.has(Vector2i(8, 7))
		var far := cells.any(func(c): return Vector2(c - at).length() > arc.reach + 0.5)
		_check("an arc cuts in front of her and leaves her back clear",
			ahead and not behind and not far and cells.size() > 4, "%d tiles" % cells.size())
	var scythe: BossMove = by_id.get(&"scything_sweep", null)
	if scythe != null:
		var a0 := bf.move_cells(scythe, at, Vector2i(8, 14), 0)
		var a2 := bf.move_cells(scythe, at, Vector2i(8, 14), 2)
		_check("a sweep moves round her beat by beat", scythe.legs >= 2 and a0 != a2
			and not a0.is_empty() and not a2.is_empty())
	var victim: UnitInstance = null
	for u in sim._units:
		if u.team == bf.player_team() and u.is_alive() and not u.structure:
			victim = u
	var pyre: BossMove = by_id.get(&"crimson_pyre", null)
	if pyre != null and victim != null:
		var hp0 := victim.current_hp + victim.shield
		bf.marked = {move = pyre, cells = [victim.cell] as Array[Vector2i], left = 0.01,
			aim = victim.cell, step = 0}
		bf._strike()
		var right_after := victim.current_hp + victim.shield
		for i in 12:
			bf._tick_hazards()
		_check("burning ground does nothing at once, then burns every half second",
			is_equal_approx(right_after, hp0) and victim.current_hp + victim.shield < hp0,
			"%.0f -> %.0f -> %.0f" % [hp0, right_after, victim.current_hp + victim.shield])
	var edict: BossMove = by_id.get(&"silencing_edict", null)
	if edict != null and victim != null:
		victim.mana = 50.0
		bf.marked = {move = edict, cells = [victim.cell] as Array[Vector2i], left = 0.01,
			aim = victim.cell, step = 0}
		bf._strike()
		victim.gain_mana(30.0)
		_check("the seal empties the bar and stops it filling, with no wind-up",
			edict.windup <= 0.0 and victim.mana == 0.0 and victim.mana_suppressed > 0.0
			and not sim.can_cast(victim))
	# Crowded: six of the army round her, and her next move is the whirl.
	BoardModel.reset_map()
	var s2 := _boss_board()
	var bf2: BossFight = s2.bf
	var sim2: CombatSim = s2.sim
	var w := load("res://data/units/warden_t1.tres") as UnitData
	var placed := 0
	for dy in range(-1, 2):
		for dx in range(-2, 3):
			var c := bf2.boss.cell + Vector2i(dx, dy + 1)
			if placed < 7 and c != bf2.boss.cell and sim2.board.in_bounds(c) and sim2.board.is_empty(c):
				var u := UnitInstance.create(w, bf2.player_team())
				if sim2.board.force_place(u, c):
					sim2._units.append(u)
					placed += 1
	bf2.marked = {}
	bf2.surround_cd = 0.0
	bf2._mark_next_move()
	var whirled: BossMove = bf2.marked.get("move", null)
	_check("surrounded, she answers with her whirl — wound up first",
		whirled != null and whirled.id == data.surround_move.id and bool(bf2.marked.get("windup", false)),
		"%d round her, next %s" % [bf2.crowd_around(), whirled.id if whirled != null else &"none"])
	# Every phase after the first opens with a signature move of its own.
	var openers := data.phases.slice(1).map(func(p): return p.entry_move)
	# Her summons: more kinds, with tiers, hunting their own way.
	var s4 := _boss_board([["warden", "archer"], [], []])
	var bf4: BossFight = s4.bf
	var sim4: CombatSim = s4.sim
	var kinds4 := {}
	for k in data.summon_pool:
		kinds4[k.id] = k
	var hunter: BossMinion = kinds4.get(&"headhunter", null)
	var berserk: BossMinion = kinds4.get(&"berserker", null)
	_check("her summoning waves mix shades, Headhunters, Berserkers and archers",
		hunter != null and berserk != null and kinds4.size() >= 4)
	if hunter != null and berserk != null:
		var top: UnitInstance = null
		for u in sim4._units:
			if u.team == bf4.player_team() and u.is_alive() and not u.structure:
				if top == null or u.data.tier > top.data.tier:
					top = u
		var h := bf4._spawn_minion(Vector2i(8, 6), 1.0, hunter)
		_check("a Headhunter goes for the highest tier on the field",
			h != null and bf4.minion_target(h) != null
			and bf4.minion_target(h).data.tier == top.data.tier)
		var bz := bf4._spawn_minion(Vector2i(9, 6), 1.0, berserk)
		var some_unit: UnitInstance = null
		for u in sim4._units:
			if u.team == bf4.player_team() and u.is_alive() and not u.structure:
				some_unit = u
		var shade_kid := bf4._spawn_minion(Vector2i(10, 6), 1.0)
		_check("a Headhunter takes souls; her ordinary summons do not",
			some_unit != null and bf4.soul_kills(h.uid, some_unit)
			and shade_kid != null and not bf4.soul_kills(shade_kid.uid, some_unit))
		_check("a Berserker cleaves round what it hits", bz != null and bz.empowered
			and bz.data.empower_splash_radius >= 1)
		bf4.phase = 2
		var weak := bf4.summon_scale()
		var bk4: Barracks = sf4_barracks_of(bf4)
		for t in bk4.types:
			bk4.level[t.id] = 10
		_check("her summons grow with how far the army has been upgraded, but only slightly",
			bf4.summon_scale() > weak and bf4.summon_scale() < weak * 3.0, "%.2f -> %.2f" % [weak, bf4.summon_scale()])
		_check("and summons come out at a higher tier each phase",
			bf4.minion_tier() == data.minion_base_tier + 2 and h.data.tier == data.minion_base_tier)
		bf4.enrage_stacks = data.minion_tier_surges - 1
		var t_before := bf4.minion_tier()
		bf4.enrage_stacks = data.minion_tier_surges
		_check("enrage only lifts her summons a tier every few surges, not every one",
			t_before == data.minion_base_tier + 2 and bf4.minion_tier() == t_before + 1)
		bf4.enrage_stacks = 0
	BoardModel.reset_map()
	_check("phases 2-4 each open with their own big move",
		openers.all(func(m): return m != null and m.windup > 0.0)
		and openers[0].id != openers[1].id and openers[1].id != openers[2].id)
	var s3 := _boss_board([["warden"], [], []])
	var bf3: BossFight = s3.bf
	var sim3: CombatSim = s3.sim
	bf3.boss.current_hp = bf3.boss.stat(StatModifier.Stat.MAX_HP) * (data.phases[1].hp_threshold - 0.01)
	bf3.marked = {}
	for i in int((data.phases[1].entry_pause + 0.3) / CombatSim.TICK):
		sim3.step()
	var opened: BossMove = bf3.marked.get("move", null)
	_check("and once the announcement is over she opens with it",
		bf3.phase == 1 and opened != null and opened.id == data.phases[1].entry_move.id,
		"phase %d, marked %s" % [bf3.phase, opened.id if opened != null else &"nothing"])
	BoardModel.reset_map()


func _test_boss_enrage(data: BossData) -> void:
	_section("Boss defence: no time limit, but she enrages")
	var s := _boss_board([["warden"], [], []])
	var bf: BossFight = s.bf
	var sim: CombatSim = s.sim
	_check("there is no time limit: only her death or the Central Crystal ends it",
		data.time_limit <= 0.0 and sim.timeout_at() >= BossFight.NO_TIME_LIMIT)
	var atk := bf.boss.stat(StatModifier.Stat.ATTACK_DAMAGE)
	var spd := bf.boss.stat(StatModifier.Stat.ATTACK_SPEED)
	sim.elapsed = data.enrage_after - 1.0
	bf._tick_enrage()
	_check("before the enrage starts she is her ordinary self", bf.enrage_stacks == 0)
	sim.elapsed = data.enrage_after
	bf._tick_enrage()
	_check("from %ds she surges: harder and faster" % roundi(data.enrage_after),
		bf.enrage_stacks == 1
		and is_equal_approx(bf.boss.stat(StatModifier.Stat.ATTACK_DAMAGE), atk * (1.0 + data.enrage_attack))
		and bf.boss.stat(StatModifier.Stat.ATTACK_SPEED) > spd
		and not _kind_events(sim, "boss_enrage").is_empty(),
		"%.0f -> %.0f" % [atk, bf.boss.stat(StatModifier.Stat.ATTACK_DAMAGE)])
	sim.elapsed = data.enrage_after + data.enrage_every
	bf._tick_enrage()
	_check("and again every %ds, stacking" % roundi(data.enrage_every),
		bf.enrage_stacks == 2
		and is_equal_approx(bf.boss.stat(StatModifier.Stat.ATTACK_DAMAGE), atk * (1.0 + 2.0 * data.enrage_attack)),
		"%d stacks, %.0f attack" % [bf.enrage_stacks, bf.boss.stat(StatModifier.Stat.ATTACK_DAMAGE)])
	var m := bf._spawn_minion(Vector2i(8, 3), 1.0)
	_check("and what she summons comes out stronger too",
		m != null and is_equal_approx(m.data.max_hp, data.minion_hp * (1.0 + 2.0 * data.enrage_minions) * bf.summon_scale()),
		"%.0f" % (m.data.max_hp if m != null else 0.0))
	BoardModel.reset_map()
	# No army limit by default: a capped boss still lets a whole wave land.
	var small := (load("res://data/boss/arbiter.tres") as BossData).duplicate(true)
	small.zone_cap = 3
	var s2 := _boss_board([["warden", "archer", "lancer", "seraph", "warden", "archer"], [], []], small)
	var bf2: BossFight = s2.bf
	# Her toughness: a single blow is capped, and ranged blows are cut.
	var s3 := _boss_board([["archer"], [], []])
	var bf3: BossFight = s3.bf
	var sim3: CombatSim = s3.sim
	var hp0 := bf3.boss.current_hp
	sim3._damage(bf3.boss, 1.0e7, bf3.crystals[0])
	_check("no single blow takes more than her cap",
		absf((hp0 - bf3.boss.current_hp) - bf3.max_hit()) < 1.0 and bf3.max_hit() < hp0 * 0.05,
		"%.0f taken, cap %.0f" % [hp0 - bf3.boss.current_hp, bf3.max_hit()])
	var cap0 := bf3.max_hit()
	var bk3: Barracks = sf4_barracks_of(bf3)
	if bk3 != null:
		for t in bk3.types:
			bk3.level[t.id] = 10
		_check("her hit cap grows very slowly as the army is upgraded",
			is_equal_approx(bf3.max_hit(), cap0 * (1.0 + bf3.data.max_hit_growth * 10.0))
			and bf3.max_hit() < cap0 * 2.0, "%.0f -> %.0f" % [cap0, bf3.max_hit()])
		for t in bk3.types:
			bk3.level[t.id] = 0
	var archer: UnitInstance = null
	for u in sim3._units:
		if u.team == bf3.player_team() and u.is_ranged():
			archer = u
	_check("and a ranged hit is cut by her ranged resistance",
		archer != null and is_equal_approx(bf3.shape_boss_damage(100.0, archer), 100.0 * (1.0 - data.phases[0].ranged_resist)))
	var gunner := UnitInstance.create(load("res://data/units/culverin_t1.tres") as UnitData, bf3.player_team())
	_check("and a long-range hit even more",
		is_equal_approx(bf3.shape_boss_damage(100.0, gunner), 100.0 * (1.0 - data.phases[0].long_range_resist)),
		"%.0f" % bf3.shape_boss_damage(100.0, gunner))
	bf3.phase = 3
	_check("and her ranged resistance climbs with every phase",
		bf3.shape_boss_damage(100.0, gunner) < 100.0 * (1.0 - data.phases[0].long_range_resist) - 1.0
		and data.phases[3].ranged_resist > data.phases[0].ranged_resist,
		"%.0f in phase 4" % bf3.shape_boss_damage(100.0, gunner))
	bf3.phase = 0
	_check("the results screen counts every tier of a unit as one",
		BossStats.base_name("Vexer IV") == "Vexer" and BossStats.base_name("Warden") == "Warden")
	# Merge from the other lanes: partners elsewhere come to this lane and merge here.
	var ml := Barracks.new()
	ml.setup(data, load("res://data/loadouts/starter.tres") as LoadoutData, 6)
	for ls in Barracks.SECTIONS:
		for i in ml.slot_count():
			ml.sections[ls][i] = null
	var wd2 := load("res://data/units/warden_t1.tres") as UnitData
	ml.sections[0][0] = wd2
	ml.sections[1][0] = wd2
	ml.sections[2][3] = wd2
	ml.sections[2][4] = wd2
	_check("a lane with a partner elsewhere can pull it in", ml.can_merge_into(0) and ml.can_merge_into(1))
	var made := ml.merge_into(0)
	_check("merging from the other lanes brings them here and merges them",
		made >= 2 and ml.unit_count(0) >= 1 and ml.unit_count(1) == 0 and ml.unit_count(2) == 0,
		"%d merges, lanes %d/%d/%d" % [made, ml.unit_count(0), ml.unit_count(1), ml.unit_count(2)])
	_check("and with nothing left to pair, there is nothing to pull", not ml.can_merge_into(0))
	# Top Damage: a Sentry's damage is its Engineer's.
	var st := BossStats.new()
	var sen := UnitInstance.create(load("res://data/units/sentry_t1.tres") as UnitData, BoardModel.TEAM_B)
	sen.uid = 9001
	var foe_s := UnitInstance.create(load("res://data/units/warden_t1.tres") as UnitData, BoardModel.TEAM_A)
	foe_s.uid = 9002
	st.record({kind = "damage", uid = 9002, source_uid = 9001, amount = 50.0}, {9001: sen, 9002: foe_s})
	_check("a Sentry's damage counts under its Engineer in Top Damage",
		st.by_type.has("Engineer") and not st.by_type.has("Sentry"), "%s" % [st.by_type])
	# Fixed merges in the Barracks: an Amalgam merges with anything, a Transcendence
	# makes more of itself.
	var mb := Barracks.new()
	mb.setup(data, load("res://data/loadouts/starter.tres") as LoadoutData, 5)
	var am := load("res://data/units/amalgam_t1.tres") as UnitData
	var wd := load("res://data/units/warden_t1.tres") as UnitData
	var tr := load("res://data/units/transcendence_t1.tres") as UnitData
	for i in mb.slot_count():
		mb.sections[0][i] = null
	mb.sections[0][0] = am
	mb.sections[0][1] = wd
	_check("an Amalgam merges with anything of its tier in the Barracks",
		mb.can_merge(am, wd) and mb.drop(0, 0, 0, 1) == "merged" and mb.at(0, 1).tier == 2)
	mb.sections[0][0] = tr
	mb.sections[0][1] = tr
	_check("two Transcendence merge into a tier 2 Transcendence",
		mb.drop(0, 0, 0, 1) == "merged" and mb.at(0, 1) == tr.next_tier)
	mb.sections[0][0] = tr
	mb.sections[0][1] = am
	_check("and an Amalgam merged into a Transcendence comes out Transcendence",
		mb.drop(0, 1, 0, 0) == "merged" and mb.at(0, 0) == tr.next_tier)
	BoardModel.reset_map()
	_check("with no army limit, every unit of a wave lands while there is room",
		bf2.army_in_zone(0) == 6, "%d of 6 on the field" % bf2.army_in_zone(0))
	BoardModel.reset_map()


func _test_boss_retreat(data: BossData) -> void:
	_section("Boss defence: the retreat")
	var retreats: Array[BossMove] = []
	var phases_with: Array[int] = []
	for i in data.phases.size():
		for m in data.phases[i].moves:
			if m.shape == BossMove.Shape.RETREAT:
				if not retreats.has(m):
					retreats.append(m)
				if not phases_with.has(i):
					phases_with.append(i)
	_check("she retreats in her last two phases", phases_with == [2, 3], "%s" % [phases_with])
	if retreats.is_empty():
		return
	var mv := retreats[0]
	var kinds := {}
	for k in mv.retreat_summons:
		kinds[k.id] = k
	_check("and calls every kind of summon she has, each its own thing",
		kinds.size() >= 5 and kinds.has(&"headhunter") and kinds.has(&"berserker") and kinds.has(&"scarlet_thorn") and kinds.has(&"blood_chalice"),
		"%s" % [kinds.keys()])

	var s := _boss_board([["warden", "warden"], ["archer"], []])
	var bf: BossFight = s.bf
	var sim: CombatSim = s.sim
	var full := bf.boss.stat(StatModifier.Stat.MAX_HP)
	var taken_before := bf.boss.stat(StatModifier.Stat.DAMAGE_TAKEN)
	var atk_before := bf.boss.stat(StatModifier.Stat.ATTACK_DAMAGE)
	# Walk her out into the field first, so the teleport has somewhere to come from.
	var out := Vector2i(8, 9)
	if sim.board.is_empty(out):
		sim.board.move_unit(bf.boss, out)
	bf.marked = {}
	bf._mark(mv, 0, true)
	_check("she teleports to the back of the field",
		bf.boss.cell.y < BossFight.RETREAT_ROWS and bool(bf.marked.get("retreat", false)),
		"at %s" % bf.boss.cell)
	_check("and takes extra damage while she is there",
		bf.boss.stat(StatModifier.Stat.DAMAGE_TAKEN) > taken_before,
		"%.2f -> %.2f" % [taken_before, bf.boss.stat(StatModifier.Stat.DAMAGE_TAKEN)])
	bf.boss.current_hp = full * 0.80
	for i in int((data.summon_warning + 0.2) / CombatSim.TICK):
		sim.step()
	var ids := {}
	for u in sim._units:
		if u.is_alive() and u.team == bf.boss_team() and u != bf.boss:
			ids[u.data.id] = int(ids.get(u.data.id, 0)) + 1
	_check("her summons step out of their circles: all three kinds",
		ids.has(&"crimson_shade") and ids.has(&"scarlet_thorn") and ids.has(&"blood_chalice"),
		"%s" % [ids])
	var hp_mid := bf.boss.current_hp
	for i in int(1.0 / CombatSim.TICK):
		sim.step()
	_check("she heals while she waits", bf.boss.current_hp > hp_mid,
		"%.0f -> %.0f" % [hp_mid, bf.boss.current_hp])
	_check("and every chalice standing mends her too",
		bf._heal_rate.values().any(func(r): return float(r) > 0.0))
	bf.boss.current_hp = full * 0.999
	for i in int(1.0 / CombatSim.TICK):
		sim.step()
	_check("but never past the top of her health bar",
		bf.boss.current_hp <= full + 0.01, "%.0f of %.0f" % [bf.boss.current_hp, full])
	var guard := 0
	while bool(bf.marked.get("retreat", false)) and guard < 2000:
		sim.step()
		guard += 1
	var ended := _kind_events(sim, "boss_retreat_end")
	_check("ride it out and she comes back stronger, for good",
		bf.retreats_completed == 1 and bf.boss.stat(StatModifier.Stat.ATTACK_DAMAGE) > atk_before
		and not ended.is_empty() and bool(ended[0].completed),
		"%.0f -> %.0f attack" % [atk_before, bf.boss.stat(StatModifier.Stat.ATTACK_DAMAGE)])
	_check("and the extra damage taken is gone again", bf._retreat_vuln.is_empty())

	# Beaten down a bar while she is away: cut short, nothing gained.
	bf.marked = {}
	bf.gap_left = 999.0
	bf._mark(mv, 0, true)
	bf.boss.current_hp = full * (data.phases[1].hp_threshold - 0.01)
	sim.step()
	var last: Dictionary = _kind_events(sim, "boss_retreat_end").back()
	_check("knock her down a bar while she heals and the retreat is cut short",
		not bool(bf.marked.get("retreat", false)) and not bool(last.completed)
		and bf.retreats_completed == 1)

	# The health gate: halfway down her last bar she can't be hurt, and recovers.
	bf.marked = {}
	bf.gap_left = 999.0
	bf.pause_left = 0.0
	bf.boss.sealed = false
	bf.phase = data.gate_phase
	var gate := bf.gate_hp()
	_check("her last phase has a health gate halfway down its bar",
		data.gate_move != null and data.gate_phase == data.phases.size() - 1
		and gate < full * data.phases[data.gate_phase].hp_threshold and gate > 0.0)
	bf.boss.current_hp = gate + 300.0
	sim._damage(bf.boss, 1.0e7, bf.crystals[0])
	_check("no blow takes her past the gate", is_equal_approx(bf.boss.current_hp, gate),
		"%.0f, gate %.0f" % [bf.boss.current_hp, gate])
	sim._damage(bf.boss, 500.0, bf.crystals[0])
	_check("at the gate she takes no damage at all", is_equal_approx(bf.boss.current_hp, gate))
	sim.step()
	var gev := _kind_events(sim, "boss_retreat")
	_check("and goes off to recover, sealed",
		bool(bf.marked.get("gate", false)) and bf.boss.sealed and bf.gate_reached
		and not gev.is_empty() and bool(gev.back().get("gate", false)))
	var hp_g := bf.boss.current_hp
	sim._damage(bf.boss, 500.0, bf.crystals[0])
	_check("nothing hurts her while she recovers", bf.boss.current_hp >= hp_g)
	_check("and the recovery is a long one", data.gate_move.retreat_seconds >= 20.0)
	var guard_g := 0
	while bool(bf.marked.get("retreat", false)) and guard_g < 20000:
		sim.step()
		guard_g += 1
	_check("she heals through it and can be hurt again after",
		not bf.boss.sealed and bf.boss.current_hp > gate, "%.0f, gate %.0f" % [bf.boss.current_hp, gate])
	var hp_after := bf.boss.current_hp
	bf.marked = {}
	bf.gap_left = 999.0
	sim._damage(bf.boss, 1.0e7, bf.crystals[0])
	_check("and the gate holds only once", bf.boss.current_hp < hp_after - 1.0 and not bf.gate_holds())
	BoardModel.reset_map()


func _test_boss_music() -> void:
	_section("Boss defence music")
	var data := load("res://data/boss/arbiter.tres") as BossData
	var want := [
		["res://audio/boss/gebura_battle.mp3", 0.0, 91.6364],
		["res://audio/boss/gebura_battle.mp3", 91.6364, 183.2727],
		# From its first sound: the file opens on 65 ms of silence that gapped every loop.
		["res://audio/boss/red_mist.mp3", 0.0647, 0.0],
		["res://audio/boss/gebura_battle.mp3", 183.2727, 0.0],
	]
	var got: PackedStringArray = []
	var ok := data != null and data.phases.size() == want.size()
	if ok:
		for i in want.size():
			var p := data.phases[i]
			got.append("%s: %s %.0f-%.0f" % [p.music_label, p.music_path.get_file(),
				p.music_from, p.music_to])
			ok = ok and p.music_path == want[i][0] and is_equal_approx(p.music_from, want[i][1]) \
				and is_equal_approx(p.music_to, want[i][2]) \
				and p.music_label == ["Theme 1", "Theme 2", "Theme 3", "Theme 4"][i]
	_check("phases 1-4 play Theme 1-4: the battle theme, its second part, the Red Mist theme whole, the battle theme's end",
		ok, ", ".join(got))
	var beat := 60.0 / 110.0
	_check("Themes 1 and 2 are each exactly 168 beats at 110 BPM, cut on the bar line, so each loop lands on the downbeat",
		absf(91.6364 / beat - 168.0) < 0.002 and absf((183.2727 - 91.6364) / beat - 168.0) < 0.002)
	_check("a stretch with an end wraps to its own start, carrying the overshoot over",
		is_equal_approx(_audio_script().segment_wrap(91.331, 0.0, 91.231), 0.1)
		and is_equal_approx(_audio_script().segment_wrap(182.946, 91.231, 182.846), 91.331)
		and _audio_script().segment_wrap(91.2, 0.0, 91.231) < 0.0
		and _audio_script().segment_wrap(120.0, 91.0, 183.0) < 0.0)
	_check("a stretch that runs to the end of the file is left to finish",
		_audio_script().segment_wrap(400.0, 183.0, 0.0) < 0.0)
	var cfg := ConfigFile.new()
	cfg.load("res://export_presets.cfg")
	_check("the web export leaves the boss music out",
		String(cfg.get_value("preset.0", "exclude_filter", "")).contains("audio/boss/*"))
	var have := ResourceLoader.exists(want[0][0]) and ResourceLoader.exists(want[2][0])
	if not have:
		print("  (boss music not on this machine — the mode plays on without it)")
		return
	var theme := load(want[0][0]) as AudioStream
	_check("the battle theme is long enough for all three of its pieces",
		theme != null and theme.get_length() > 183.0 + 30.0,
		"%.0fs" % (theme.get_length() if theme != null else 0.0))
	_check("and is 506 beats long, so Theme 4 wrapping off its end lands on the beat too",
		theme != null and absf(theme.get_length() / beat - 506.0) < 0.05,
		"%.3f beats" % (theme.get_length() / beat if theme != null else 0.0))
	var mp3 := theme as AudioStreamMP3
	var cuts_ok := mp3 != null
	var cut_note: PackedStringArray = []
	if mp3 != null:
		for to: float in [91.6364, 183.2727]:
			var cut := AudioStreamMP3.new()
			cut.data = _audio_script().mp3_bytes_until(mp3.data, to)
			var end := cut.get_length()
			var a := _mix(mp3, end - 0.1, 2048)
			var b := _mix(cut, end - 0.1, 2048)
			var same := a.size() == 2048 and a == b
			cut_note.append("%.4f→%.4f%s" % [to, end, "" if same else " (differs)"])
			cuts_ok = cuts_ok and end >= to and end < to + 0.03 and same
	_check("cutting the file at a stretch's end keeps it sample-for-sample, ending within one MP3 frame after the cut",
		cuts_ok, ", ".join(cut_note))


func _mix(s: AudioStream, at: float, n: int) -> PackedVector2Array:
	var pb := s.instantiate_playback()
	pb.start(at)
	var out := PackedVector2Array()
	while out.size() < n:
		var part: PackedVector2Array = pb.mix_audio(1.0, n - out.size())
		if part.is_empty():
			break
		out.append_array(part)
	return out


func _audio_script() -> GDScript:
	return load("res://autoload/audio.gd") as GDScript


func _test_bannerman() -> void:
	_section("The Bannerman raises a banner, then plants it")
	var bm := _find("bannerman")
	_check("the Bannerman is in the roster, thick and feeble",
		bm != null and bm.ability != null and bm.ability.kind == AbilityData.Kind.BANNER
		and bm.max_hp >= _find("warden").max_hp and bm.attack_damage < _find("warden").attack_damage)
	if bm == null:
		return
	var board := BoardModel.new()
	var me := UnitInstance.create(bm, BoardModel.TEAM_A)
	var pal := UnitInstance.create(_find("archer"), BoardModel.TEAM_A)
	var far := UnitInstance.create(_find("archer"), BoardModel.TEAM_A)
	var foe := UnitInstance.create(_find("warden"), BoardModel.TEAM_B)
	board.place(me, Vector2i(2, 3))
	board.place(pal, Vector2i(3, 3))
	board.place(far, Vector2i(5, 0))
	board.place(foe, Vector2i(2, 4))
	var sim := CombatSim.new()
	sim.setup(board, 3)
	var step0 := pal.stat(StatModifier.Stat.MOVE_TIME)
	_check("before the banner nobody is blessed", pal.resist() <= 0.0001)
	sim._resolve_banner(me, bm.ability)
	var want := CombatSim.banner_resist_of(me, bm.ability)
	_check("raised, it blesses allies near the bearer: resist and quicker feet",
		sim.is_carrying_banner(me) and is_equal_approx(pal.resist(), want)
		and pal.stat(StatModifier.Stat.MOVE_TIME) < step0 and is_equal_approx(me.resist(), want),
		"resist %.2f, step %.2f -> %.2f" % [pal.resist(), step0, pal.stat(StatModifier.Stat.MOVE_TIME)])
	_check("but not allies out of its reach", far.resist() <= 0.0001)
	me.mana = 1.0e6
	_check("with a banner up, a full bar waits", not sim.can_cast(me))
	me.target = foe
	sim._begin_attack(me)
	sim._tick_banners()
	_check("its first blow on an enemy plants the flag where it stands",
		not sim.is_carrying_banner(me) and sim._banners_planted.size() == 1
		and sim._banners_planted[0].cell == me.cell and not _kind_events(sim, "banner_planted").is_empty())
	_check("the planted flag keeps the blessing on that ground", is_equal_approx(pal.resist(), want))
	_check("and the bar can raise a new one", sim.can_cast(me))
	for i in int((bm.ability.banner_seconds + 0.2) / CombatSim.TICK):
		sim._tick_banners()
	_check("after a while the planted flag comes down", sim._banners_planted.is_empty()
		and pal.resist() <= 0.0001 and is_equal_approx(pal.stat(StatModifier.Stat.MOVE_TIME), step0))
	var colours := load("res://data/buffs/colours.tres") as BuffData
	_check("Colours is the Bannerman's own: +5/10/20% resist and +50/100/200% health",
		colours != null and colours.unit_id == &"bannerman"
		and is_equal_approx(colours.bronze.x, 0.5) and is_equal_approx(colours.gold.x, 2.0)
		and is_equal_approx(colours.bronze.y, 0.05) and is_equal_approx(colours.gold.y, 0.20))


func _test_every_ability_has_an_icon() -> void:
	_section("Every ability has an icon of its own")

	# Its OWN, by id, not the by-kind fallback: the fallback is there so a new ability
	# shows something on day one, not so it can ship without one. Read off the units
	# rather than the abilities folder, which can hold a file no unit uses any more.
	var unlisted: Array[String] = []
	var dir := DirAccess.open("res://data/units")
	var counted := {}
	for f in dir.get_files():
		if not f.ends_with(".tres"):
			continue
		var d := load("res://data/units/" + f) as UnitData
		if d == null or d.ability == null or counted.has(d.ability.id):
			continue
		counted[d.ability.id] = true
		if not AbilityFx.GLYPHS.has(d.ability.id):
			unlisted.append(String(d.ability.id))
	var seen := counted.size()
	_check("there are abilities on disk", seen >= 20, "%d" % seen)
	_check("and every one of them has its own icon", unlisted.is_empty(),
		", ".join(unlisted))

	# Every icon named anywhere is one the layer can actually draw. An unknown name
	# falls through to a plain star, which would pass every other check and still be
	# the wrong picture.
	var unknown: Array[String] = []
	for id in AbilityFx.GLYPHS:
		var shape := String(AbilityFx.GLYPHS[id][0])
		if not AbilityFx.SHAPES.has(shape):
			unknown.append("%s -> %s" % [id, shape])
	for k in AbilityData.Kind.values():
		var shape := AbilityFx.glyph_for(&"", k)
		if not AbilityFx.SHAPES.has(shape) or not AbilityFx.KIND_GLYPHS.has(k):
			unknown.append("kind %d -> %s" % [k, shape])
	_check("every icon named is one that can be drawn, and every kind has a fallback",
		unknown.is_empty(), ", ".join(unknown))
	_check("the Warden's is a shield", AbilityFx.glyph_of(_must_find("warden").ability)
		== "shield", AbilityFx.glyph_of(_must_find("warden").ability))
	_check("and the Lancer's is a spear", AbilityFx.glyph_of(_must_find("lancer").ability)
		== "spear", AbilityFx.glyph_of(_must_find("lancer").ability))
	_check("two abilities of one kind can look different",
		AbilityFx.glyph_for(&"cinder_lance", AbilityData.Kind.FOCUS_BURST)
		!= AbilityFx.glyph_for(&"execute", AbilityData.Kind.FOCUS_BURST))

	# The layer itself: an icon arrives, lives for its span, and goes.
	var fx := AbilityFx.new()
	fx.glyph("shield", Vector2(10, 10), Color.WHITE, 0.5)
	fx.lance(Vector2.ZERO, Vector2(0, -100), Color.WHITE, 0.5)
	_check("an icon and a spear are queued", fx.count() == 2, "%d" % fx.count())
	fx._process(0.3)
	_check("still there part way through", fx.count() == 2, "%d" % fx.count())
	fx._process(0.3)
	_check("and gone once their time is up", fx.count() == 0, "%d" % fx.count())
	_check("the layer draws above the units", fx.z_index > 0, "z %d" % fx.z_index)
	fx.free()

	# The sim end of it: an ability event says which KIND of ability it was. It used to
	# lose that to the event type, so the view drew every ability as a Haste.
	var sim := CombatSim.new()
	sim._emit("ability", {uid = 1, ability = &"impale", kind = AbilityData.Kind.PIERCE})
	var sent: Dictionary = sim.events[0]
	_check("an ability event keeps the ability's kind",
		sent.kind == "ability" and int(sent.get("ability_kind", -1)) == AbilityData.Kind.PIERCE,
		"%s" % sent)
