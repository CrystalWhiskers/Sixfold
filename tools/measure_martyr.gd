extends SceneTree

## Tuning the Martyr's body. The first pass measured 85% at tier 3 against a 49.5%
## baseline, and 66.7% with the rage slope switched off entirely — which says the BODY
## is the problem before the ability is. Everything below is at tier 3, so a tier 1
## figure of h is written here as h * 4.

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
		var d: UnitData = row[0] if row[0] is UnitData else BoardModel.at_tier(_pick(row[0]), row[1])
		board.force_place(UnitInstance.create(d, team), cells[i])
		i += 1

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
		var w := sim.run()
		if w >= 0:
			wins[w] += 1
	return float(wins[0]) / maxf(float(wins[0] + wins[1]), 1.0) * 100.0

func _at(slot, tier: int) -> Array:
	return [[slot, tier], ["archer", 2], ["warden", 1], ["archer", 1], ["seraph", 1]]

func _body(hp1: float, dmg1: float, spd: float) -> UnitData:
	## A tier 3 Martyr built from TIER ONE figures, so the numbers here read the way
	## the data table does. Tier 3 is four times tier 1 on both hp and damage.
	var v := BoardModel.at_tier(_pick("martyr"), 3).duplicate() as UnitData
	v.max_hp = hp1 * 4.0
	v.attack_damage = dmg1 * 4.0
	v.attack_speed = spd
	return v

func _initialize() -> void:
	_roster = load("res://data/loadouts/roster.tres") as LoadoutData
	var control := _at("warden", 3)
	# The record for the unit AS BUILT: 130 / 6 / 0.85, rage 1.0, threshold 50%,
	# bleed 0.025/s, window 2.5s, pierce 3. Kept in the harness rather than only in the
	# notes, so any later change to the global pace or the tier scaling reproduces the
	# same table and says whether it moved.
	print("\nThe Martyr as built. Same-tier swaps; 49.5%% is the honest baseline.")
	var line := "    "
	for t in [1, 2, 3, 4, 5, 6]:
		line += "  T%d %5.1f%%" % [t, _run(_at("martyr", t), _at("warden", t))]
	print(line)
	print("\n  Controls in the same slot at tier 3:")
	for who in ["reaver", "warden", "revenant", "lancer"]:
		print("    %-10s %5.1f%%" % [who, _run(_at(who, 3), _at("warden", 3))])
	var rapture := load("res://data/buffs/rapture.tres") as BuffData
	print("\n  Rapture on a tier 3 Martyr. Other gold unit-buffs in this fixture are")
	print("  worth +37 to +48 points (Undying +48, Vigor +43, Ironwall +37), so a big")
	print("  number here is the house rate and not a Martyr problem.")
	var bare := _run(_at("martyr", 3), _at("warden", 3))
	print("    no buff        %5.1f%%" % bare)
	for r in [BuffData.Rarity.BRONZE, BuffData.Rarity.SILVER, BuffData.Rarity.GOLD]:
		var g := _run(_at("martyr", 3), _at("warden", 3), rapture, r)
		print("    %-14s %5.1f%%  (+%4.1f)" % [BuffData.rarity_name(r), g, g - bare])
	quit()
