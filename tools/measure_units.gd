extends SceneTree

## Same-tier controls throughout. An earlier pass compared a tier 5 unit against a
## line topping out at tier 2 and got 100% for everything, which measured the tier
## ladder and not the unit.

const RUNS := 300
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
		var d: UnitData = row[0] if row[0] is UnitData else BoardModel.at_tier(_pick(row[0]), row[1])
		board.force_place(UnitInstance.create(d, team), cells[i])
		i += 1

func _run(a: Array, bspec: Array) -> float:
	var wins := [0, 0]
	for i in RUNS:
		BoardModel.reset_map()
		var board := BoardModel.new()
		_line(board, BoardModel.TEAM_A, a)
		_line(board, BoardModel.TEAM_B, bspec)
		var sim := CombatSim.new()
		sim.setup(board, i * 37 + 11)
		var w := sim.run()
		if w >= 0:
			wins[w] += 1
	return float(wins[0]) / maxf(float(wins[0] + wins[1]), 1.0) * 100.0

func _at(slot, tier: int) -> Array:
	## The line with `slot` in the front position and everything else held still.
	return [[slot, tier], ["archer", 2], ["warden", 1], ["archer", 1], ["seraph", 1]]

func _pair(who: String, tier: int) -> void:
	## The unit against a line whose matching slot holds a Warden AT THE SAME TIER,
	## so the tier ladder cancels out and what is left is the unit.
	var mine := _at(who, tier)
	var theirs := _at("warden", tier)
	print("  %-10s T%d  %5.1f%%   (control: Warden T%d in the same slot)" % [
		who, tier, _run(mine, theirs), tier])

func _initialize() -> void:
	_roster = load("res://data/loadouts/roster.tres") as LoadoutData
	print("\nSame-tier swap: 50%% means the unit is exactly as good as a Warden.")
	for t in [2, 5]:
		for who in ["pyre", "leech", "vexer"]:
			_pair(who, t)
	print("")
	for t in [1, 2, 3, 4, 5, 6]:
		_pair("usurper", t)

	# What the Vexer's body is worth, holding its ability and the pace still.
	print("\nThe Vexer's body, tier 2, against a tier 2 Warden:")
	var base := BoardModel.at_tier(_pick("vexer"), 2)
	var control := _at("warden", 2)
	for hp in [170.0, 200.0, 340.0, 440.0]:
		var v := base.duplicate() as UnitData
		v.max_hp = hp
		print("    %6.0f hp (%.2fx)  %5.1f%%" % [
			hp, hp / base.max_hp, _run(_at(v, 2), control)])
	print("    %6.0f hp (as built) is the row above at 1.00x" % base.max_hp)
	quit()
