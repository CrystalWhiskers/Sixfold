extends SceneTree

## The Powderkeg's numbers. Same harness as measure_hospitaller.gd and
## measure_martyr.gd: a five-unit line where the front slot is swapped and its
## control holds a Warden at the SAME tier, so the tier ladder cancels out and
## 49.5% is the honest baseline (see the control row).
##
##   godot --headless --script res://tools/measure_powderkeg.gd

const RUNS := 200
var _roster: LoadoutData = null

func _pick(id: String) -> UnitData:
	for u in _roster.units:
		if String(u.id) == id:
			return u
	return null

func _line(board: BoardModel, team: int, spec: Array) -> void:
	var cells := board.deploy_cells(BoardModel.TEAM_A)
	if team == BoardModel.TEAM_B:
		var flipped: Array[Vector2i] = []
		for c in cells:
			flipped.append(BoardModel.mirror(c))
		cells = flipped
	var i := 0
	for row in spec:
		var d: UnitData = BoardModel.at_tier(_pick(row[0]), row[1])
		board.force_place(UnitInstance.create(d, team), cells[i])
		i += 1

var _lit := 0
var _blasts := 0

func _run(a: Array, bspec: Array, buff: BuffData = null,
		rarity := BuffData.Rarity.GOLD) -> float:
	var wins := [0, 0]
	for i in RUNS:
		BoardModel.reset_map()
		var board := BoardModel.new()
		_line(board, BoardModel.TEAM_A, a)
		_line(board, BoardModel.TEAM_B, bspec)
		var sim := CombatSim.new()
		var tb := TeamBuffs.new()
		if buff != null:
			tb.add(buff, rarity)
			sim.team_buffs[BoardModel.TEAM_A] = tb
		sim.setup(board, i * 37 + 11)
		if buff != null:
			for u in board.units_of(BoardModel.TEAM_A):
				tb.apply_to(u)
				u.heal_to_full()
		var w := sim.run()
		for e in sim.events:
			if e.kind == "fuse_lit":
				_lit += 1
			elif e.kind == "fuse_blast":
				_blasts += 1
		if w >= 0:
			wins[w] += 1
	return float(wins[0]) / maxf(float(wins[0] + wins[1]), 1.0) * 100.0

func _at(slot: String, tier: int) -> Array:
	return [[slot, tier], ["archer", 2], ["warden", 1], ["archer", 1], ["seraph", 1]]

func _initialize() -> void:
	_roster = load("res://data/loadouts/roster.tres") as LoadoutData
	print("\nThe Powderkeg as built, front slot against a Warden at the same tier.")
	print("49.5% is the honest baseline.")
	var line := "  front-slot swap vs Warden:"
	for t in [1, 2, 3, 4, 5, 6]:
		_lit = 0
		_blasts = 0
		line += "  T%d %5.1f%%" % [t, _run(_at("powderkeg", t), _at("warden", t))]
	print(line)
	line = "  control, Warden vs Warden:"
	for t in [1, 3, 6]:
		line += "  T%d %5.1f%%" % [t, _run(_at("warden", t), _at("warden", t))]
	print(line)
	_lit = 0
	_blasts = 0
	_run(_at("powderkeg", 3), _at("warden", 3))
	print("  tier 3: lit in %d of %d rounds, went off %d times" % [_lit, RUNS, _blasts])

	var salt := load("res://data/buffs/saltpetre.tres") as BuffData
	print("\n  Saltpetre on a tier 3 Powderkeg, front slot. Other gold unit-buffs in")
	print("  this fixture are worth +37 to +48 points, per measure_martyr.gd.")
	var bare := _run(_at("powderkeg", 3), _at("warden", 3))
	print("    no buff        %5.1f%%" % bare)
	for r in [BuffData.Rarity.BRONZE, BuffData.Rarity.SILVER, BuffData.Rarity.GOLD]:
		var g := _run(_at("powderkeg", 3), _at("warden", 3), salt, r)
		print("    %-14s %5.1f%%  (%+5.1f)" % [BuffData.rarity_name(r), g, g - bare])
	quit()
