## The five units a player brings into a match. The per-turn draw pulls from here.
class_name LoadoutData
extends Resource

## How many unit types the generator builds a roster from.
##
## This is the size of your ROSTER — how many different units exist to draw
## from. It is NOT how many units you are dealt each turn; that knob is
## MatchState.UNITS_PER_DRAW, and it is almost certainly the one you want.
##
## Changing this alone does nothing useful: the roster comes from UNIT_TABLE in
## tools/generate_data.gd, so a bigger roster means adding entries there.
const DEFAULT_SIZE := 5

@export var id: StringName = &""
@export var display_name: String = "Loadout"
## The unit types this loadout draws from. Weights below are parallel to it.
@export var units: Array[UnitData] = []
## Relative draw chance per slot. Leave empty for a uniform draw.
@export var weights: Array[float] = []


## Any non-empty roster with no holes in it is playable.
##
## The count is deliberately NOT pinned to a constant. It used to be, and that
## turned a reasonable one-character edit into a game that refused to start with
## no explanation of why. Roster size should change the game, not break it.
func is_valid() -> bool:
	if units.is_empty():
		return false
	for u in units:
		if u == null:
			return false
	return weights.is_empty() or weights.size() == units.size()


func weight_at(i: int) -> float:
	if weights.is_empty():
		return 1.0
	return maxf(weights[i], 0.0)


## Deterministic given the rng you pass in. Never call randi() directly.
func draw_one(rng: RandomNumberGenerator) -> UnitData:
	if units.is_empty():
		return null
	var total := 0.0
	for i in units.size():
		total += weight_at(i)
	if total <= 0.0:
		return units[rng.randi_range(0, units.size() - 1)]
	var roll := rng.randf() * total
	for i in units.size():
		roll -= weight_at(i)
		if roll <= 0.0:
			return units[i]
	return units[units.size() - 1]


func draw(rng: RandomNumberGenerator, count: int) -> Array[UnitData]:
	var out: Array[UnitData] = []
	for i in count:
		out.append(draw_one(rng))
	return out
