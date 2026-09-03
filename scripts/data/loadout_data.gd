class_name LoadoutData
extends Resource

const DEFAULT_SIZE := 5

@export var id: StringName = &""
@export var display_name: String = "Loadout"
@export var units: Array[UnitData] = []
@export var weights: Array[float] = []


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
