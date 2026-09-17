class_name BuffPool
extends RefCounted

const BUFF_DIR := "res://data/buffs"
const INDEX_NAME := "index"
const OPTIONS := 3

var buffs: Array[BuffData] = []


func load_all(dir_path := BUFF_DIR) -> int:
	## The index decides what is in the game; the folder is only where the files live.
	##
	## This used to read the folder and take every .tres in it, which was a live bug for
	## months. The data builder deletes orphans in the copy it is RUN against, so any
	## machine that had ever held an older build still had the cut buffs sitting on disk
	## — and its game went on offering them. Seven of them on one copy. Nothing caught
	## it, because the folder the tests run against is the folder the builder just
	## cleaned; the bug could only exist somewhere the tests never looked.
	##
	## Units were never exposed to this: a unit is in the game because roster.tres names
	## it, so a stale unit file is inert. This is the same contract for buffs.
	buffs.clear()
	if _load_from_index(dir_path):
		return buffs.size()
	return _load_by_scanning(dir_path)


func _load_from_index(dir_path: String) -> bool:
	## Returns false if there is no usable index, so the caller can fall back. An index
	## that exists but names nothing counts as unusable rather than as "no buffs" —
	## an empty pool is indistinguishable from a broken build at the call site, and
	## degrading to the old behaviour is better than shipping a game with no buffs.
	var path := "%s/%s.tres" % [dir_path, INDEX_NAME]
	if not ResourceLoader.exists(path):
		return false
	var index := load(path) as BuffIndex
	if index == null or index.ids.is_empty():
		return false
	for id in index.ids:
		var res := load("%s/%s.tres" % [dir_path, id])
		if res is BuffData and _is_live(res as BuffData):
			buffs.append(res as BuffData)
		else:
			# Named but missing or empty. Worth saying out loud rather than silently
			# shipping a shorter pool, because the index is generated and the file it
			# names should always be generated beside it.
			push_warning("Buff index names '%s', which did not load." % id)
	return true


func _load_by_scanning(dir_path: String) -> int:
	## The fallback, and deliberately second. It is here so that a project with no index
	## yet — a half-finished data regeneration, an older checkout — still runs, rather
	## than starting with no buffs at all. It is also what the stale-buff bug above was,
	## so nothing should rely on it.
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
	## A buff with nothing in it is a data mistake and is dropped rather than
	## offered. "Nothing in it" used to mean only that the stat magnitudes were
	## zero — which quietly binned the first buff written entirely out of RIDERS.
	## Avalanche is stun seconds and charge damage and no stat at all; it loaded,
	## sat in data/buffs, and never appeared in a single pick.
	##
	## So the question is now "does this buff do anything", asked of every field
	## that can make it do something.
	if b.id == &"":
		return false
	if not (b.bronze.is_zero_approx() and b.silver.is_zero_approx()
			and b.gold.is_zero_approx()):
		return true
	if b.empowered_cap_at_gold > 0:
		return true
	for rider in [b.extra_raises, b.wall_toughness, b.shield_on_hit,
			b.extra_summons, b.stun_bonus, b.charge_bonus, b.third,
			b.host_move, b.host_power]:
		if not (rider as Vector3).is_zero_approx():
			return true
	return false


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
