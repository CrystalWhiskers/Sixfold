class_name RarityTable
extends RefCounted

const ODDS := [
	[70.0, 25.0, 5.0],
	[40.0, 40.0, 20.0],
	[15.0, 45.0, 40.0],
	[5.0, 30.0, 65.0],
]


static func rows() -> int:
	return ODDS.size()


static func odds_for(pick: int) -> Array:
	return ODDS[clampi(pick - 1, 0, ODDS.size() - 1)]


static func chance(rarity: BuffData.Rarity, pick: int) -> float:
	var odds := odds_for(pick)
	var total := 0.0
	for w in odds:
		total += maxf(w, 0.0)
	if total <= 0.0:
		return 0.0
	return maxf(odds[int(rarity)], 0.0) / total


static func roll(rng: RandomNumberGenerator, pick: int) -> BuffData.Rarity:
	var odds := odds_for(pick)
	var total := 0.0
	for w in odds:
		total += maxf(w, 0.0)
	if total <= 0.0:
		return BuffData.Rarity.BRONZE
	var value := rng.randf() * total
	for i in odds.size():
		value -= maxf(odds[i], 0.0)
		if value <= 0.0:
			return i as BuffData.Rarity
	return BuffData.Rarity.GOLD


static func describe(pick: int) -> String:
	var parts: PackedStringArray = []
	for r in [BuffData.Rarity.BRONZE, BuffData.Rarity.SILVER, BuffData.Rarity.GOLD]:
		parts.append("%s %d%%" % [
			BuffData.rarity_name(r), roundi(chance(r, pick) * 100.0)])
	return "   ".join(parts)
