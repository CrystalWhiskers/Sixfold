extends SceneTree

## Does the travel time actually buy anything?
##
## The charge now takes real seconds to cross its lane and picks its victim on arrival.
## The question that decides whether that was worth doing is not the win rate — it is how
## often the charge now MISSES something it would previously have hit, because nothing in
## this game deliberately dodges. Units move for their own reasons; a dodge here is
## incidental. If the miss rate is zero, the travel time is a telegraph and nothing more,
## and that is worth saying out loud rather than assuming otherwise.

const RUNS := 300
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
		var d: UnitData = row[0] if row[0] is UnitData else BoardModel.at_tier(_pick(row[0]), row[1])
		board.force_place(UnitInstance.create(d, team), cells[i])
		i += 1

func _at(slot, tier: int) -> Array:
	return [[slot, tier], ["archer", 2], ["warden", 1], ["archer", 1], ["seraph", 1]]

var _damage_per_tier := -1.0

func _breaker(tier: int, per_tile: float) -> UnitData:
	var v := BoardModel.at_tier(_pick("breaker"), tier).duplicate() as UnitData
	var ab := v.ability.duplicate() as AbilityData
	ab.charge_tile_seconds = per_tile
	if _damage_per_tier > 0.0:
		ab.charge_damage_per_tier = _damage_per_tier
	v.ability = ab
	return v

func _trial(tier: int, per_tile: float) -> Dictionary:
	## Win rate, and what the charge actually did, over the same set of seeds.
	var wins := [0, 0]
	var hit := 0
	var missed := 0
	var stopped := 0
	var travel := 0.0
	var who := _breaker(tier, per_tile)
	for i in RUNS:
		BoardModel.reset_map()
		var board := BoardModel.new()
		_line(board, BoardModel.TEAM_A, _at(who, tier))
		_line(board, BoardModel.TEAM_B, _at("warden", tier))
		var sim := CombatSim.new()
		sim.setup(board, i * 37 + 11)
		var w := sim.run()
		if w >= 0:
			wins[w] += 1
		var start := -1.0
		for e in sim.events:
			match e.kind:
				"charge":
					start = float(e.t)
				"charge_end":
					if float(e.t) >= 0.0 and start >= 0.0:
						travel += float(e.t) - start
					if bool(e.get("hit", false)):
						hit += 1
					elif String(e.get("reason", "")) == "stopped":
						stopped += 1
					else:
						missed += 1
	var charges := maxi(hit + missed + stopped, 1)
	return {
		win = float(wins[0]) / maxf(float(wins[0] + wins[1]), 1.0) * 100.0,
		hit = float(hit) / float(charges) * 100.0,
		missed = float(missed) / float(charges) * 100.0,
		stopped = float(stopped) / float(charges) * 100.0,
		travel = travel / float(charges),
	}

var _warn := 2

func _initialize() -> void:
	_roster = load("res://data/loadouts/roster.tres") as LoadoutData
	print("\nThe Breaker's charge. 300 runs a cell; 49.5%% is the baseline for an")
	print("ordinary unit in the swapped slot. 0.00s/tile is the old instant charge.")
	print("\n  tier  s/tile    win     connected   missed   knocked out   mean run")
	print("\n  Charge damage per tier, at the shipped 0.35s travel time.")
	print("  As built is 1.2. Instant-charge baselines were T1 35.3, T3 39.3, T6 81.0.")
	for dmg in [1.2, 1.8, 2.4, 3.0, 3.6]:
		_damage_per_tier = dmg
		var line := "    x%.1f  " % dmg
		for tier in [1, 3, 6]:
			line += "  T%d %5.1f%%" % [tier, _trial(tier, 0.35).win]
		print(line)
	quit()
