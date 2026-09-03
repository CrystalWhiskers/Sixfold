class_name BuffPool
extends RefCounted

const BUFF_DIR := "res://data/buffs"
const OPTIONS := 3

var buffs: Array[BuffData] = []


func load_all(dir_path := BUFF_DIR) -> int:
	buffs.clear()
	var dir := DirAccess.open(dir_path)
	if dir == null:
		return 0
	var names := dir.get_files()
	names.sort()
	for file_name in names:
		var clean := file_name.trim_suffix(".remap")
		if not clean.ends_with(".tres"):
			continue
		var res := load("%s/%s" % [dir_path, clean])
		if res is BuffData and _is_live(res as BuffData):
			buffs.append(res as BuffData)
	return buffs.size()


func _is_live(b: BuffData) -> bool:
	if b.id == &"":
		return false
	return not (b.bronze.is_zero_approx() and b.silver.is_zero_approx()
		and b.gold.is_zero_approx())


func offer(rng: RandomNumberGenerator, count := OPTIONS, exclude: Array = [],
		fielded: Dictionary = {},
		rarity: BuffData.Rarity = BuffData.Rarity.GOLD) -> Array[BuffData]:
	var out: Array[BuffData] = []
	var remaining: Array[BuffData] = []
	for b in buffs:
		if exclude.has(b.id) or not in_pool_for(b, fielded, rarity):
			continue
		remaining.append(b)
	if remaining.is_empty():
		for b in buffs:
			if in_pool_for(b, fielded, rarity):
				remaining.append(b)
	while out.size() < count and not remaining.is_empty():
		var pick := _weighted_take(rng, remaining)
		if pick == null:
			break
		out.append(pick)
	return out


func _weighted_take(rng: RandomNumberGenerator, pool: Array[BuffData]) -> BuffData:
	var total := 0.0
	for b in pool:
		total += maxf(b.weight, 0.0)
	if total <= 0.0:
		var i := rng.randi_range(0, pool.size() - 1)
		var any: BuffData = pool[i]
		pool.remove_at(i)
		return any
	var roll := rng.randf() * total
	for i in pool.size():
		roll -= maxf(pool[i].weight, 0.0)
		if roll <= 0.0:
			var hit: BuffData = pool[i]
			pool.remove_at(i)
			return hit
	var last: BuffData = pool[pool.size() - 1]
	pool.remove_at(pool.size() - 1)
	return last


static func in_pool_for(b: BuffData, fielded: Dictionary,
		rarity: BuffData.Rarity = BuffData.Rarity.GOLD) -> bool:
	if b == null or not b.available_at(rarity):
		return false
	if b.is_global() or fielded.is_empty():
		return true
	return fielded.has(b.unit_id)


func pool_for(fielded: Dictionary,
		rarity: BuffData.Rarity = BuffData.Rarity.GOLD) -> Array[BuffData]:
	var out: Array[BuffData] = []
	for b in buffs:
		if in_pool_for(b, fielded, rarity):
			out.append(b)
	return out


func by_id(id: StringName) -> BuffData:
	for b in buffs:
		if b.id == id:
			return b
	return null
