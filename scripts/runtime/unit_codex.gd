class_name UnitCodex
extends RefCounted


static func headline(d: UnitData) -> String:
	return "%s  ·  T%d  ·  %s" % [d.display_name, d.tier, d.range_name()]


static func stat_line(d: UnitData) -> String:
	return "%s hp  ·  %s damage  ·  %s attacks/s  ·  reaches %d" % [
		_num(d.max_hp), _num(d.attack_damage), _rate(d.attack_speed), d.reach_tiles()]


static func stat_line_of(u: UnitInstance) -> String:
	return "%s hp  ·  %s damage  ·  %s attacks/s  ·  reaches %d" % [
		_num(u.stat(StatModifier.Stat.MAX_HP)),
		_num(u.stat(StatModifier.Stat.ATTACK_DAMAGE)),
		_rate(u.stat(StatModifier.Stat.ATTACK_SPEED)),
		u.attack_reach()]


static func ability_name(d: UnitData) -> String:
	return "" if d.ability == null else d.ability.display_name


static func ability_block(d: UnitData) -> String:
	if d.ability == null:
		return "No ability. What you see on the tile is all of it."
	var title: String = d.ability.display_name
	if d.casts_at_battle_start:
		title += "  (casts on the opening bell)"
	elif d.mana_per_attack > 0.0:
		var swings := ceili(UnitInstance.MANA_MAX / maxf(d.mana_per_attack, 0.01))
		title += "  (every %s)" % ("attack" if swings <= 1 else "%d attacks" % swings)
	return "%s\n%s" % [title, d.ability.describe()]


static func charge_line(d: UnitData) -> String:
	if d.ability == null:
		return ""
	var parts: PackedStringArray = []
	if d.mana_per_attack > 0.0:
		parts.append("%d mana per attack landed" % roundi(d.mana_per_attack))
	if d.mana_per_charge > 0.0:
		parts.append("%d mana on its own every %s" % [
			roundi(d.mana_per_charge), _seconds(d.mana_charge_time)])
	if parts.is_empty():
		return "Charges only from outside help."
	return "Charges: %s." % " and ".join(parts)


static func traits(d: UnitData) -> PackedStringArray:
	var out: PackedStringArray = []
	if not d.can_move and not d.can_attack:
		out.append("Never moves and never swings — it only casts.")
	elif not d.can_move:
		out.append("Never moves.")
	elif not d.can_attack:
		out.append("Never swings.")
	if d.pierce_targets > 1:
		if d.pierce_targets >= UnitData.UNLIMITED_TILES:
			out.append("Ordinary swings cut through everything in line.")
		else:
			out.append("Ordinary swings already cut through %d." % d.pierce_targets)
	if d.merge_magnet:
		out.append("Any merge it touches comes out as this unit.")
	if d.wild_merge:
		out.append("Merges with any unit of the same tier, whatever it is.")
	if d.keeps_mana:
		out.append("Keeps whatever it has charged from one round to the next.")
	if d.ability != null and d.ability.consumes_caster:
		out.append("Using its ability spends it: it dies on the spot, for good.")
	return out


static func card(d: UnitData) -> String:
	var lines: PackedStringArray = [headline(d)]
	if not d.note.is_empty():
		lines.append(d.note)
	lines.append("")
	lines.append(stat_line(d))
	var extra := traits(d)
	if not extra.is_empty():
		lines.append("")
		for t in extra:
			lines.append("• %s" % t)
	lines.append("")
	lines.append(ability_block(d))
	var charge := charge_line(d)
	if not charge.is_empty():
		lines.append("")
		lines.append(charge)
	return "\n".join(lines)


static func card_of(u: UnitInstance) -> String:
	var d: UnitData = u.data
	var lines: PackedStringArray = [headline(d)]
	if not d.note.is_empty():
		lines.append(d.note)
	lines.append("")
	lines.append(stat_line_of(u))
	if _is_buffed(u):
		lines.append("(buffed — base is %s)" % stat_line(d))
	var extra := traits(d)
	if not extra.is_empty():
		lines.append("")
		for t in extra:
			lines.append("• %s" % t)
	lines.append("")
	lines.append(ability_block(d))
	var charge := charge_line(d)
	if not charge.is_empty():
		lines.append("")
		lines.append(charge)
	return "\n".join(lines)


static func one_line(d: UnitData) -> String:
	var tail := ability_name(d)
	if tail.is_empty():
		tail = "no ability"
	return "%s T%d — %s hp, %s damage, %s attacks/s, %s range. %s." % [
		d.display_name, d.tier, _num(d.max_hp), _num(d.attack_damage),
		_rate(d.attack_speed), d.range_name(), tail]


static func one_line_of(u: UnitInstance) -> String:
	var d: UnitData = u.data
	var tail := ability_name(d)
	if tail.is_empty():
		tail = "no ability"
	return "%s T%d — %s hp, %s damage, %s attacks/s, %s range. %s." % [
		d.display_name, d.tier,
		_num(u.stat(StatModifier.Stat.MAX_HP)),
		_num(u.stat(StatModifier.Stat.ATTACK_DAMAGE)),
		_rate(u.stat(StatModifier.Stat.ATTACK_SPEED)),
		u.range_name(), tail]


static func _is_buffed(u: UnitInstance) -> bool:
	return not u.modifiers.is_empty() or not u.battle_modifiers.is_empty()


static func _num(v: float) -> String:
	var n := maxf(v, 0.0)
	if n < 10000.0:
		return "%d" % roundi(n)
	if n < 1000000.0:
		return "%.1fk" % (n / 1000.0)
	return "%.1fM" % (n / 1000000.0)


static func _seconds(v: float) -> String:
	if is_equal_approx(v, 1.0):
		return "second"
	if is_equal_approx(v, roundf(v)):
		return "%d seconds" % roundi(v)
	return "%.1f seconds" % v


static func _rate(v: float) -> String:
	if is_equal_approx(v, roundf(v)):
		return "%d" % roundi(v)
	return "%.2f" % v
