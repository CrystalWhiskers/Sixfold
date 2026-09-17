extends SceneTree

## What the global walking pace costs in CLOCK. The ceiling on MOVE_SCALE is not
## taste, it is sudden death at 105 seconds and the timeout at 120: a pace that
## pushes ordinary rounds past the first turns a last-ditch rule into the normal
## state of every fight.

const RUNS := 200

var _roster: LoadoutData = null


func _pick(id: String) -> UnitData:
	for u in _roster.units:
		if String(u.id) == id:
			return u
	return null


func _line(board: BoardModel, team: int, spec: Array) -> void:
	# TEAM_B's cells are TEAM_A's MIRRORED, not TEAM_B's own deploy order. Taking
	# each side's list independently does not produce a mirror image unless the two
	# orderings happen to agree, and they do not — which showed up as a twelve-point
	# lean in a "mirror" matchup that was never actually mirrored.
	var cells := board.deploy_cells(BoardModel.TEAM_A)
	if team == BoardModel.TEAM_B:
		var flipped: Array[Vector2i] = []
		for c in cells:
			flipped.append(BoardModel.mirror(c))
		cells = flipped
	var i := 0
	for row in spec:
		board.force_place(UnitInstance.create(
			BoardModel.at_tier(_pick(row[0]), row[1]), team), cells[i])
		i += 1


func _run(a: Array, bspec: Array, buff: StringName = &"",
		rarity: BuffData.Rarity = BuffData.Rarity.GOLD) -> Dictionary:
	var wins := [0, 0]
	var total := 0.0
	var worst := 0.0
	var late := 0
	var timeouts := 0
	var pool := BuffPool.new()
	pool.load_all()
	var b_data: BuffData = null if buff == &"" else pool.by_id(buff)
	for i in RUNS:
		BoardModel.reset_map()
		var board := BoardModel.new()
		_line(board, BoardModel.TEAM_A, a)
		_line(board, BoardModel.TEAM_B, bspec)
		var sim := CombatSim.new()
		if b_data != null:
			var tb := TeamBuffs.new()
			tb.add(b_data, rarity)
			# BOTH halves, and this is the trap. Handing the sim a TeamBuffs only
			# covers what the sim reads for itself: round shields, regen, the
			# full-roster bonus and the riders. An ORDINARY unit stat buff is applied
			# by the flow layer, one unit at a time, and a harness that skips this
			# line measures the buff doing nothing and reports it as a finding.
			sim.team_buffs[BoardModel.TEAM_A] = tb
			for u in board.units_of(BoardModel.TEAM_A):
				tb.apply_to(u)
		sim.setup(board, i * 37 + 11)
		var w := sim.run()
		if w >= 0:
			wins[w] += 1
		var d := sim.duration()
		total += d
		worst = maxf(worst, d)
		if d >= CombatSim.SUDDEN_DEATH:
			late += 1
		if d >= CombatSim.DEFAULT_TIMEOUT - 0.2:
			timeouts += 1
	return {rate = float(wins[0]) / maxf(float(wins[0] + wins[1]), 1.0) * 100.0,
		mean = total / float(RUNS), worst = worst, late = late,
		timeouts = timeouts}


func _say(label: String, r: Dictionary) -> void:
	print("  %-40s %5.1f%%   mean %5.1fs  worst %5.1fs  past sudden death %3d/%d  timed out %d" % [
		label, r.rate, r.mean, r.worst, r.late, RUNS, r.timeouts])


func _initialize() -> void:
	_roster = load("res://data/loadouts/roster.tres") as LoadoutData
	var stock := [["warden", 2], ["archer", 2], ["warden", 1], ["archer", 1], ["seraph", 1]]
	print("\nMOVE_SCALE as built (move_time of a tier 1 Warden: %.2fs a tile)"
		% _pick("warden").move_time)
	_say("mirror", _run(stock, stock))
	_say("mirror + gold Forced March", _run(stock, stock, &"forced_march"))
	_say("mirror + bronze Forced March", _run(stock, stock, &"forced_march", BuffData.Rarity.BRONZE))
	var bows := [["archer", 2], ["archer", 2], ["archer", 1], ["archer", 1], ["archer", 1]]
	var blades := [["warden", 2], ["warden", 2], ["warden", 1], ["warden", 1], ["warden", 1]]
	_say("all bows v all blades", _run(bows, blades))
	var vexer := [["vexer", 2], ["archer", 2], ["warden", 1], ["archer", 1], ["seraph", 1]]
	_say("one Vexer in the line", _run(vexer, stock))
	var pyre := [["pyre", 2], ["archer", 2], ["warden", 1], ["archer", 1], ["seraph", 1]]
	_say("one Pyre in the line", _run(pyre, stock))
	var leech := [["leech", 2], ["archer", 2], ["warden", 1], ["archer", 1], ["seraph", 1]]
	_say("one Leech in the line", _run(leech, stock))
	var usurper := [["usurper", 2], ["archer", 2], ["warden", 1], ["archer", 1], ["seraph", 1]]
	_say("one Usurper T2 (grip 5.0s)", _run(usurper, stock))
	var u6 := [["usurper", 6], ["archer", 2], ["warden", 1], ["archer", 1], ["seraph", 1]]
	_say("one Usurper T6 (grip 15.0s)", _run(u6, stock))
	quit()
