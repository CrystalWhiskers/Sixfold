## Headless test suite for the board model and the combat sim.
##
##   godot --headless --script res://tools/run_tests.gd
##
## These run without a window, a scene, or any art. Keep them passing and the
## visual layer can only ever be wrong about pixels, never about rules.
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
	_test_merging()
	_test_merge_lottery()
	_test_stat_modifiers()
	_test_draw_determinism()
	_test_combat_runs()
	_test_combat_determinism()
	_test_move_lockout()
	_test_abilities()
	_test_mirror_matchup_is_fair()

	print("\n%d passed, %d failed" % [_passed, _failed])
	if _failed > 0:
		print("FAILURES PRESENT")
	quit(1 if _failed > 0 else 0)


# ---------------------------------------------------------------- harness

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


## Fills both sides with an exactly mirrored line-up.
##
## Both teams derive from TEAM_A's cells: team B's are those mirrored. Taking
## B's own deploy cells and mirroring them would land back in A's half and every
## placement would silently fail — which is precisely the bug this helper had.
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


# ---------------------------------------------------------------- tests

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

	# Walk to the top of the chain and confirm it refuses to go further.
	var t2a := _unit(0, BoardModel.TEAM_A)
	var t2b := _unit(0, BoardModel.TEAM_A)
	var b2 := BoardModel.new()
	b2.place(t2a, Vector2i(0, 0))
	b2.place(t2b, Vector2i(1, 0))
	var m2 := b2.merge(t2a, t2b, Vector2i(1, 0))
	var t3a := _unit(0, BoardModel.TEAM_A)
	var t3b := _unit(0, BoardModel.TEAM_A)
	b2.place(t3a, Vector2i(2, 0))
	b2.place(t3b, Vector2i(3, 0))
	var m3 := b2.merge(t3a, t3b, Vector2i(3, 0))
	var top := b2.merge(m2, m3, Vector2i(3, 0))
	_check("two tier-2s make a tier-3", top != null and top.data.tier == 3)
	_check("tier 3 is the top", top != null and top.data.is_max_tier())
	var x1 := _unit(0, BoardModel.TEAM_A)
	x1.data = top.data
	_check("merging at max tier refused", not b2.can_merge(top, x1))


## Merging is a gamble: two identical units yield a RANDOM type one tier up.
func _test_merge_lottery() -> void:
	_section("Merge lottery")
	var b := BoardModel.new()
	b.configure_merges(_loadout.units, 31337)

	var seen := {}
	var tiers_ok := true
	for i in 200:
		var a := _unit(0, BoardModel.TEAM_A)   # always two Wardens
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

	# Same seed, same sequence of rolls — otherwise a replay would diverge.
	var first := _roll_sequence(9001)
	var again := _roll_sequence(9001)
	var other := _roll_sequence(4242)
	_check("same seed rolls the same merges", first == again, "%s vs %s" % [first, again])
	_check("a different seed rolls differently", first != other)

	# With no pool configured, merging falls back to straight promotion.
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
		StatModifier.Stat.ATTACK_COOLDOWN, StatModifier.Mode.PERCENT, -5.0)])
	_check("cooldown clamped above zero",
		fast.stat(StatModifier.Stat.ATTACK_COOLDOWN) >= UnitInstance.MIN_TIME,
		"an unclamped -500% buff would hang the sim")


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
	_check("battle took a sensible time", sim.duration() > 0.5 and sim.duration() < 45.0,
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


## The mechanic the whole design rests on: a unit locked in MOVING cannot answer.
##
## Deliberately controlled — the SAME two units, the SAME distance, the SAME seed,
## with move_time as the only variable. That isolates the lockout from whatever
## the shipped stat table happens to say this week, so this test keeps meaning
## something after you retune everything.
func _test_move_lockout() -> void:
	_section("Movement lockout")

	var slow := _run_crossing(4.0)   # walker 5x slower
	var fast := _run_crossing(-0.75) # walker 75% faster

	_check("a slow walker dies crossing the board", slow == BoardModel.TEAM_A,
		"the archer should shoot it down during the committed moves")
	_check("a fast walker survives the crossing and wins", fast == BoardModel.TEAM_B,
		"move_time is the lever; if this doesn't flip, the lockout isn't biting")
	_check("move_time alone flips the outcome", slow != fast)


## An archer against one melee unit that has to close on it.
## `move_pct` scales the walker's move_time; everything else is held constant.
##
## They start exactly the archer's attack_range apart, so the archer is in range
## from tick one and never advances. That makes the walker's crossing the only
## thing happening, which is what we want to measure.
func _run_crossing(move_pct: float) -> int:
	var b := BoardModel.new()
	var archer := _unit(2, BoardModel.TEAM_A)   # ranged
	var walker := _unit(1, BoardModel.TEAM_B)   # melee, must close
	walker.apply_modifiers([StatModifier.make(
		StatModifier.Stat.MOVE_TIME, StatModifier.Mode.PERCENT, move_pct)])
	var gap := archer.stat_int(StatModifier.Stat.ATTACK_RANGE)
	b.place(archer, Vector2i(2, BoardModel.NEUTRAL_ROW - 2))
	b.place(walker, Vector2i(2, BoardModel.NEUTRAL_ROW - 2 + gap))
	var sim := CombatSim.new()
	sim.setup(b, 5)
	return sim.run()


## Every unit has a mana ability. These fights are deliberately tiny and lopsided
## so the ability is the only interesting thing happening.
func _test_abilities() -> void:
	_section("Abilities")

	var by_id := {}
	for u in _loadout.units:
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


## Warden opens with its shield already up, and the shield eats damage before
## health does — and can never be healed back.
func _test_shield(by_id: Dictionary) -> void:
	var warden: UnitData = by_id["warden"]
	var b := BoardModel.new()
	var w := _make(warden, BoardModel.TEAM_A)
	var foe := _make(by_id["lancer"], BoardModel.TEAM_B)
	b.place(w, Vector2i(2, 4))
	b.place(foe, Vector2i(2, 6))
	var sim := CombatSim.new()
	sim.setup(b, 11)
	_check("shield starts empty before the first tick", is_zero_approx(w.shield))
	for i in 6:
		sim.step()
	_check("Warden opens the battle with a shield up", w.shield > 0.0,
		"shield is %.0f" % w.shield)

	# Shield absorbs first.
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

	# Recasting tops up but does not stack past the cap.
	s2.add_shield(70.0, 70.0)
	s2.add_shield(70.0, 70.0)
	_check("shield tops up to the cap, never past it", is_equal_approx(s2.shield, 70.0),
		"shield is %.0f" % s2.shield)


## Archer's haste is permanent and stacking, but must not leak into later rounds.
func _test_haste(by_id: Dictionary) -> void:
	var archer: UnitData = by_id["archer"]
	var a := _make(archer, BoardModel.TEAM_A)
	var base := a.stat(StatModifier.Stat.ATTACK_COOLDOWN)
	var ab: AbilityData = archer.ability

	for i in 3:
		a.haste_stacks += 1
		a.add_battle_modifier(StatModifier.make(
			StatModifier.Stat.ATTACK_COOLDOWN, StatModifier.Mode.PERCENT, -ab.haste_percent))
	var hasted := a.stat(StatModifier.Stat.ATTACK_COOLDOWN)
	_check("haste stacks shorten the cooldown", hasted < base,
		"%.3f -> %.3f" % [base, hasted])

	a.reset_for_battle()
	_check("haste does not survive into the next round",
		is_equal_approx(a.stat(StatModifier.Stat.ATTACK_COOLDOWN), base)
		and a.haste_stacks == 0,
		"cooldown came back as %.3f" % a.stat(StatModifier.Stat.ATTACK_COOLDOWN))

	# And it actually fires in a real fight.
	_check("Archer casts during a battle", _ability_fires(by_id, "archer", "warden"))


## Vexer's poison keeps working after the Vexer has moved on.
func _test_dot(by_id: Dictionary) -> void:
	# NOT a Warden: it opens with a 70-point shield that would swallow the whole
	# poison and make this look like a broken dot.
	var victim := _make(by_id["lancer"], BoardModel.TEAM_B)
	var hp0 := victim.current_hp
	victim.apply_dot(10.0, 3, 0.5, 999)
	_check("a dot is recorded", victim.dots.size() == 1)

	# A battle with an empty side ends on tick one, and dots would never tick.
	# The bystander sits far enough away that it can't interfere in 2 seconds.
	var b := BoardModel.new()
	b.force_place(victim, Vector2i(2, 10))
	b.force_place(_make(by_id["warden"], BoardModel.TEAM_A), Vector2i(5, 0))
	var sim := CombatSim.new()
	sim.setup(b, 3)
	victim.apply_dot(10.0, 3, 0.5, 999)   # setup() cleared it
	for i in 20:
		sim.step()
	_check("the dot ticked for its full duration",
		is_equal_approx(victim.current_hp, hp0 - 30.0),
		"lost %.0f, expected 30" % (hp0 - victim.current_hp))
	_check("the dot expires", victim.dots.is_empty())
	_check("Vexer casts during a battle", _ability_fires(by_id, "vexer", "warden"))


## Pyre's burst is front-loaded on the main target, not spread evenly.
func _test_burst(by_id: Dictionary) -> void:
	var pyre: UnitData = by_id["pyre"]
	var ab: AbilityData = pyre.ability
	_check("burst hurts the main target far more than its neighbours",
		ab.burst_damage > ab.splash_damage * 3.0,
		"%.0f vs %.0f" % [ab.burst_damage, ab.splash_damage])
	_check("Pyre casts during a battle", _ability_fires(by_id, "pyre", "warden"))


## Lancer pierces two by default and three with the ability.
func _test_pierce(by_id: Dictionary) -> void:
	var lancer: UnitData = by_id["lancer"]
	_check("Lancer's passive pierces two", lancer.pierce_targets == 2)
	_check("everyone else pierces one",
		by_id["archer"].pierce_targets == 1 and by_id["warden"].pierce_targets == 1)
	_check("the ability pierces more than the passive",
		lancer.ability.pierce_targets > lancer.pierce_targets)

	# Two enemies in a column: one swing should hit both.
	var b := BoardModel.new()
	var l := _make(lancer, BoardModel.TEAM_A)
	var front := _make(by_id["warden"], BoardModel.TEAM_B)
	var back := _make(by_id["warden"], BoardModel.TEAM_B)
	b.place(l, Vector2i(2, 4))
	b.force_place(front, Vector2i(2, 5))
	b.force_place(back, Vector2i(2, 6))
	var back_hp := back.current_hp
	var sim := CombatSim.new()
	sim.setup(b, 7)
	var back_start := back.current_hp
	for i in 12:
		sim.step()
	_check("a passive swing reaches the unit behind", back.current_hp < back_start,
		"the back rank took no damage")
	_check("Lancer casts during a battle", _ability_fires(by_id, "lancer", "warden"))


## Does `caster` get its ability off at all?
##
## The caster is given an absurd health pool on purpose. Without it these fights
## measure whether the unit SURVIVES long enough to cast, which is a balance
## question and would make this test fail every time the stat table moves. What
## we want to know is narrower: given the chance to attack, does the bar fill and
## does the ability fire.
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


## The balance canary. An exactly symmetric board should be a coin flip.
## A consistent lean means a bug — a team index leaking somewhere, or an
## ordering bias in targeting — not a balance problem.
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
