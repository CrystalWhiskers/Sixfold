class_name TeamBuffs
extends RefCounted

const FULL_ROSTER_TYPES := 5

var picks: Array[Dictionary] = []
var skip_draws: int = 0


func clear() -> void:
	picks.clear()
	skip_draws = 0


func size() -> int:
	return picks.size()


func add(buff: BuffData, rarity: BuffData.Rarity) -> void:
	if buff == null:
		return
	picks.append({buff = buff, rarity = rarity})


func apply_to(u: UnitInstance) -> void:
	if u == null:
		return
	for p in picks:
		_apply_one(u, p.buff, p.rarity)


func resync(u: UnitInstance) -> void:
	if u == null:
		return
	var hp_before := u.current_hp
	var max_before := u.stat(StatModifier.Stat.MAX_HP)
	u.modifiers.clear()
	for p in picks:
		_apply_one_silent(u, p.buff, p.rarity)
	var max_after := u.stat(StatModifier.Stat.MAX_HP)
	if max_before <= 0.0:
		u.current_hp = max_after
	else:
		u.current_hp = minf(hp_before * (max_after / max_before), max_after)


func _apply_one_silent(u: UnitInstance, buff: BuffData, rarity: BuffData.Rarity) -> void:
	if buff.kind != BuffData.Kind.STAT or not buff.applies_to(u):
		return
	for m in buff.modifiers_for(rarity):
		u.modifiers.append(m)


func apply_last_to(u: UnitInstance) -> void:
	if u == null or picks.is_empty():
		return
	var p: Dictionary = picks[picks.size() - 1]
	_apply_one(u, p.buff, p.rarity)


func _apply_one(u: UnitInstance, buff: BuffData, rarity: BuffData.Rarity) -> void:
	if buff.kind != BuffData.Kind.STAT:
		return
	if not buff.applies_to(u):
		return
	var mods := buff.modifiers_for(rarity)
	if not mods.is_empty():
		u.apply_modifiers(mods)


func _sum(kind: BuffData.Kind) -> float:
	var total := 0.0
	for p in picks:
		var buff: BuffData = p.buff
		if buff.kind == kind:
			total += buff.magnitude(p.rarity).x
	return total


func regen_fraction() -> float:
	return _sum(BuffData.Kind.REGEN)


func hp_damage_fraction() -> float:
	return _sum(BuffData.Kind.PERCENT_HP_DAMAGE)


func extra_draw() -> int:
	return roundi(_sum(BuffData.Kind.EXTRA_DRAW))


func empowered_cap() -> int:
	# One by default. A gold pick of a buff that says so raises it, which is the
	# only thing in the game that changes how many of a unit may be empowered.
	var cap := 1
	for p in picks:
		var buff: BuffData = p.buff
		if buff.empowered_cap_at_gold > 0 and p.rarity == BuffData.Rarity.GOLD:
			cap = maxi(cap, buff.empowered_cap_at_gold)
	return cap


func extra_raises_for(u: UnitInstance) -> int:
	# Summed, not maxed, unlike the empowered cap: two picks that both feed the
	# Vigil should both count. Nothing currently offers two, but the picker is
	# the only reason for that and it can change.
	var extra := 0
	for p in picks:
		var buff: BuffData = p.buff
		if buff.kind != BuffData.Kind.STAT or not buff.applies_to(u):
			continue
		extra += buff.extra_raises_at(p.rarity)
	return extra


func wall_toughness_for(u: UnitInstance) -> float:
	# Summed like extra_raises, and for the same reason: two picks that both feed
	# the Mason should both count.
	var extra := 0.0
	for p in picks:
		var buff: BuffData = p.buff
		if buff.kind != BuffData.Kind.STAT or not buff.applies_to(u):
			continue
		extra += buff.wall_toughness_at(p.rarity)
	return extra


func shield_on_hit_for(u: UnitInstance) -> float:
	var extra := 0.0
	for p in picks:
		var buff: BuffData = p.buff
		if buff.kind != BuffData.Kind.STAT or not buff.applies_to(u):
			continue
		extra += buff.shield_on_hit_at(p.rarity)
	return extra


func wild_merge() -> bool:
	for p in picks:
		if p.buff.kind == BuffData.Kind.WILD_MERGE:
			return true
	return false


func merge_extra_unit_chance() -> float:
	return clampf(_sum(BuffData.Kind.MERGE_EXTRA_UNIT), 0.0, 1.0)


func merge_extra_tier_chance() -> float:
	return clampf(_sum(BuffData.Kind.MERGE_EXTRA_TIER), 0.0, 1.0)


func full_roster_modifiers() -> Array[StatModifier]:
	var out: Array[StatModifier] = []
	for p in picks:
		var buff: BuffData = p.buff
		if buff.kind == BuffData.Kind.FULL_ROSTER:
			out.append_array(buff.modifiers_for(p.rarity))
	return out


static func is_live(buff: BuffData, present: Dictionary) -> bool:
	if buff == null or present.is_empty():
		return false
	if buff.kind == BuffData.Kind.FULL_ROSTER:
		return present.size() >= FULL_ROSTER_TYPES
	if not buff.is_global():
		for id in buff.covers():
			if present.has(id):
				return true
		return false
	return true


static func why_idle(buff: BuffData, present: Dictionary) -> String:
	if buff == null:
		return ""
	if present.is_empty():
		return "Inactive — no units on this side of the board."
	if buff.kind == BuffData.Kind.FULL_ROSTER:
		return "Inactive — needs all %d unit types on this side (%d there now)." % [
			FULL_ROSTER_TYPES, present.size()]
	if not buff.is_global():
		var names: PackedStringArray = []
		for id in buff.covers():
			names.append(String(id).capitalize())
		return "Inactive — no %s on this side of the board." % " or ".join(names)
	return ""


func active_flags(present: Dictionary) -> Array[bool]:
	var out: Array[bool] = []
	for p in picks:
		out.append(is_live(p.buff, present))
	return out


func has_id(id: StringName) -> bool:
	for p in picks:
		if p.buff.id == id:
			return true
	return false


func summary() -> String:
	if picks.is_empty():
		return "no buffs"
	var parts: PackedStringArray = []
	for p in picks:
		parts.append("%s %s" % [
			BuffData.rarity_name(p.rarity), p.buff.display_name])
	return ", ".join(parts)
