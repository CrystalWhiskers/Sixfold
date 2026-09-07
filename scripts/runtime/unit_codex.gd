class_name UnitCodex
extends RefCounted


static func headline(d: UnitData) -> String:
	return "%s  ·  T%d  ·  %s  ·  %s" % [
		d.display_name, d.tier, d.range_name(), d.chassis_name()]


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
	if d.ability != null and d.ability.requires_empowered:
		out.append("Its ability only works while it is empowered.")
	if d.ability != null and d.ability.exposes_caster > 0.0:
		out.append("Takes %d%% more damage while it is casting." % roundi(
			d.ability.exposes_caster * 100.0))
	if d.is_mechanical():
		out.append("Mechanical — an Engineer beside it will repair it.")
	if d.repair_per_second > 0.0:
		out.append("Repairs %s health a second to each adjacent friendly Mechanical unit, and stays with them rather than advancing."
			% _num(d.repair_per_second))
	if d.solo_empower:
		out.append("Field exactly one and it starts the round **empowered**: %d%% health, %d%% damage, and its swing lands on the whole square around what it hits. Field two and neither is."
			% [roundi(d.empower_hp_mult * 100.0),
				roundi(d.empower_damage_mult * 100.0)])
		out.append("Nothing summoned, raised or merged into one after the opening bell is ever empowered.")
	if d.burden_radius > 0 and d.burden_percent > 0.0:
		out.append("Your own units within %d tiles take %d%% more damage. Theirs do not."
			% [d.burden_radius, roundi(d.burden_percent * 100.0)])
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
