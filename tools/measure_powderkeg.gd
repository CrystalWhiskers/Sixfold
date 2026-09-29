extends SceneTree

## What does a bomb that everyone runs from actually do?
##
## Three questions, in the order they matter:
##
## 1. Is the unit worth a slot at all? Win rate with it in the swapped slot, against
##    the 49.5% baseline an ordinary unit posts there.
## 2. Does the blast ever land? The fuse is long enough that anything with open ground
##    walks clear, so the damage figure on the card may be almost entirely theoretical.
##    Casualties per detonation is the number that says which.
## 3. What does the gold diamond cost? "Like long range" means three tiles an arm,
##    which is twenty-five tiles on a six-wide board. That wants measuring before it
##    ships, not after.

## 300 a cell. The whole file runs about fifteen minutes at that — comment out the
## sections you are not asking about rather than lowering this, or the smaller effects
## disappear into the noise.
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


var _fuse := -1.0
var _blast := -1.0
var _radius := -1
## Cancels the per-tier factor in blast_damage_of() by dividing it back out, so the
## blast becomes a flat multiple of attack damage. Attack already doubles every tier,
## so the shipped formula multiplies tier in TWICE and the top of the ladder runs away.
var _flat := -1.0


func _keg(tier: int) -> UnitData:
	var v := BoardModel.at_tier(_pick("powderkeg"), tier).duplicate() as UnitData
	var ab := v.ability.duplicate() as AbilityData
	if _fuse >= 0.0:
		ab.fuse_seconds = _fuse
	if _blast >= 0.0:
		ab.blast_damage_per_tier = _blast
	if _flat >= 0.0:
		ab.blast_damage_per_tier = _flat / float(maxi(tier, 1))
	if _radius >= 0:
		ab.blast_radius = _radius
	v.ability = ab
	return v


func _trial(tier: int, gold: int) -> Dictionary:
	var wins := [0, 0]
	var blasts := 0
	var caught := 0
	var own := 0
	var fled := 0
	var lit := 0
	var who := _keg(tier)
	var buff: BuffData = null
	if gold > 0:
		var pool := BuffPool.new()
		pool.load_all()
		buff = pool.by_id(&"saltpetre").duplicate() as BuffData
		buff.blast_range_at_gold = gold
	for i in RUNS:
		BoardModel.reset_map()
		var board := BoardModel.new()
		_line(board, BoardModel.TEAM_A, _at(who, tier))
		_line(board, BoardModel.TEAM_B, _at("warden", tier))
		var sim := CombatSim.new()
		if buff != null:
			var tb := TeamBuffs.new()
			tb.add(buff, BuffData.Rarity.GOLD)
			sim.team_buffs[BoardModel.TEAM_A] = tb
			# The STAT half, which the flow layer normally applies. The first version
			# of this tool forgot it, so every gold row measured the radius alone and
			# left out the +300% attack — which feeds the blast and quadruples it.
			for u in board.all_units():
				if u.team == BoardModel.TEAM_A:
					tb.apply_to(u)
		sim.setup(board, i * 37 + 11)
		# Who is on which side, so a casualty can be attributed. Read before the run
		# because a unit that dies is gone from the board by the time it is counted.
		var side := {}
		for u in board.all_units():
			side[u.uid] = u.team
		var bombs := {}
		var w := sim.run()
		if w >= 0:
			wins[w] += 1
		for e in sim.events:
			match e.kind:
				"fuse":
					lit += 1
					bombs[int(e.uid)] = true
				"flee":
					fled += 1
				"detonate":
					blasts += 1
				"damage":
					var src := int(e.get("source_uid", -1))
					if bombs.has(src) and int(e.uid) != src:
						caught += 1
						if int(side.get(int(e.uid), -1)) == BoardModel.TEAM_A:
							own += 1
	return {
		win = float(wins[0]) / maxf(float(wins[0] + wins[1]), 1.0) * 100.0,
		lit = float(lit) / float(RUNS),
		blasts = float(blasts) / float(RUNS),
		caught = float(caught) / maxf(float(blasts), 1.0),
		own = float(own) / maxf(float(caught), 1.0) * 100.0,
		fled = float(fled) / maxf(float(lit), 1.0),
	}


func _row(label: String, r: Dictionary) -> String:
	return "  %-12s %5.1f%%   %4.2f    %4.2f      %4.2f        %4.1f%%     %4.1f" % [
		label, r.win, r.lit, r.blasts, r.caught, r.own, r.fled]


func _initialize() -> void:
	_roster = load("res://data/loadouts/roster.tres") as LoadoutData
	print("\nThe Powderkeg. %d runs a cell. 49.5%% is the baseline for an ordinary" % RUNS)
	print("unit in the swapped slot.")
	print("\n  caught  = units hit per detonation")
	print("  own     = share of those that were its OWN side")
	print("  fled    = units sent running per fuse lit")
	print("\n               win      lit   blasts   caught    own      fled")

	print("\n  As built: 1.5s fuse, x5.0 damage, 3x3.")
	for tier in [1, 2, 3, 4, 5, 6]:
		print(_row("tier %d" % tier, _trial(tier, 0)))

	print("\n  Fuse length at tier 3. The question is whether anything is ever caught.")
	for f in [0.3, 0.6, 0.9, 1.2, 1.5, 2.0]:
		_fuse = f
		print(_row("%.1fs" % f, _trial(3, 0)))
	_fuse = -1.0

	print("\n  Blast damage at tier 3, at the shipped 1.5s fuse.")
	for d in [2.5, 5.0, 7.5, 10.0]:
		_blast = d
		print(_row("x%.1f" % d, _trial(3, 0)))
	_blast = -1.0

	print("\n  The full ladder at x7.5, which is where tier 3 lands on baseline.")
	_blast = 7.5
	for tier in [1, 2, 3, 4, 5, 6]:
		print(_row("tier %d" % tier, _trial(tier, 0)))
	_blast = -1.0

	print("\n  Tier counted ONCE: blast is a flat multiple of attack, which already")
	print("  doubles every tier. The shipped formula multiplies tier in twice.")
	for k in [20.0, 30.0, 40.0]:
		_flat = k
		var line := "    x%.0f flat " % k
		for tier in [1, 3, 6]:
			line += " T%d %5.1f%%" % [tier, _trial(tier, 0).win]
		print(line)
	_flat = -1.0

	print("\n  Gold Saltpetre: +300%% attack, and the diamond at two and three tiles an arm.")
	for tier in [3, 6]:
		for reach in [2, 3]:
			print(_row("gold T%d arm %d" % [tier, reach], _trial(tier, reach)))

	quit()
