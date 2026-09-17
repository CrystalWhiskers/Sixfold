extends SceneTree

## Does a gate actually answer a Spire? That is the whole reason it exists, so it is
## the thing to measure — not whether the pathing uses it, which the suite proves.
##
## The comparison is the SAME map with and without its gates: the ungated copy is
## made at runtime by rubbing the glyphs out, so nothing else about the board differs.

const RUNS := 80

var _roster: LoadoutData = null


func _pick(id: String) -> UnitData:
	for u in _roster.units:
		if String(u.id) == id:
			return u
	return null


func _ungated(m: MapData) -> MapData:
	var copy := m.duplicate() as MapData
	var rows: PackedStringArray = []
	for r in m.rows:
		rows.append(String(r).replace(MapData.GATE, MapData.OPEN))
	copy.rows = rows
	return copy


func _line(board: BoardModel, team: int, spec: Array) -> void:
	var cells := board.deploy_cells(BoardModel.TEAM_A)
	if team == BoardModel.TEAM_B:
		var flipped: Array[Vector2i] = []
		for c in cells:
			flipped.append(BoardModel.mirror(c))
		cells = flipped
	var i := 0
	for row in spec:
		if i >= cells.size():
			break
		board.force_place(UnitInstance.create(
			BoardModel.at_tier(_pick(row[0]), row[1]), team), cells[i])
		i += 1


func _run(m: MapData, a: Array, b: Array) -> Dictionary:
	var wins := [0, 0]
	var total := 0.0
	for i in RUNS:
		BoardModel.use_map(m)
		var board := BoardModel.new()
		_line(board, BoardModel.TEAM_A, a)
		_line(board, BoardModel.TEAM_B, b)
		var sim := CombatSim.new()
		sim.setup(board, i * 37 + 11)
		var w := sim.run()
		if w >= 0:
			wins[w] += 1
		total += sim.duration()
	return {rate = float(wins[0]) / maxf(float(wins[0] + wins[1]), 1.0) * 100.0,
		mean = total / float(RUNS)}


func _say(label: String, r: Dictionary) -> void:
	print("  %-34s %5.1f%%   mean %5.1fs" % [label, r.rate, r.mean])


func _initialize() -> void:
	_roster = load("res://data/loadouts/roster.tres") as LoadoutData
	# The attacker: an ordinary melee-led line with NO Assassin, which is the case the
	# gate is meant to be the other answer to.
	var attackers := [["warden", 3], ["warden", 2], ["reaver", 2],
		["archer", 2], ["lancer", 2]]
	# The defender: a Spire at the back with bodies in front of it.
	var turtle := [["spire", 3], ["warden", 3], ["warden", 2],
		["warden", 2], ["archer", 2]]
	# And the same attacker with an Assassin instead of its Lancer, which is the
	# answer that already existed.
	var with_killer := [["warden", 3], ["warden", 2], ["reaver", 2],
		["archer", 2], ["assassin", 3]]

	for id in ["three_roads", "the_compound"]:
		var m: MapData = load("res://data/maps/%s.tres" % id)
		if m == null:
			continue
		print("\n%s (%s, %d gate pads)" % [
			m.display_name, m.shape(), m.gate_pairs().size()])
		_say("no Assassin, gates open", _run(m, attackers, turtle))
		_say("no Assassin, gates rubbed out", _run(_ungated(m), attackers, turtle))
		_say("Assassin instead, no gates", _run(_ungated(m), with_killer, turtle))
	BoardModel.reset_map()
	quit()
