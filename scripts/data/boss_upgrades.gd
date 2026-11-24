class_name BossUpgrades
extends Resource

## Boss defence unit upgrades: what each level does to each unit TYPE's own ability.
##
## `levels` maps a unit id to five Dictionaries, Lv1 to Lv5. Each Dictionary is the
## whole state at that level, not a change from the last one, so reading a single
## level tells you exactly what the unit is like there. Keys name a field:
##
##   "a.field"   set the field on the unit's AbilityData to this value
##   "u.field"   set the field on the UnitData to this value
##   "u.field*"  multiply the UnitData's own value — for fields that already differ
##               by tier (repair, a share of health), so a tier 3 keeps its lead
##
## Anything not named keeps the unit's own value. On top of the table every level
## adds BossData.upgrade_stat_per_level to health and attack.

@export var levels: Dictionary = {}

const MAX_LEVEL := 5


func has_unit(id: StringName) -> bool:
	return levels.has(id)


func level_values(id: StringName, level: int) -> Dictionary:
	if level <= 0 or not levels.has(id):
		return {}
	var rows: Array = levels[id]
	if rows.is_empty():
		return {}
	return rows[clampi(level, 1, rows.size()) - 1]


func describe(id: StringName, level: int) -> String:
	## One line of what a level changes, for the upgrade bar's tooltip.
	var parts: PackedStringArray = []
	var vals := level_values(id, level)
	for key in vals:
		var name := String(key).substr(2).trim_suffix("*").replace("_", " ")
		var v = vals[key]
		if String(key).ends_with("*"):
			parts.append("%s x%.2f" % [name, float(v)])
		else:
			parts.append("%s %s" % [name, str(v)])
	return ", ".join(parts)
