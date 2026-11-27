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

## Evolving summons: a unit id (the summoner) to a list of forms its summon takes,
## form 1 at Lv1 and so on, the last held past the end. Each form is the WHOLE state
## (so later ones keep what earlier ones gave): "name" and "desc", then "u.field"
## set or "u.field*" multiplied on every tier of the summoned unit.
@export var forms: Dictionary = {}

const MAX_LEVEL := 5
## Ceilings for values carried on past Lv5, where an unbounded step would get silly:
## the Culverin's blast diamond and anyone's attack range.
const LV10_CAPS := {"a.shell_arm": 5, "u.attack_range": 7, "a.banner_radius": 5,
	"a.banner_resist": 0.6}


## The upgrade level at which each form arrives, in order (form 1 at the first number,
## and so on); empty for one form per level.
@export var form_levels: Array[int] = []


func form_at(id: StringName, level: int) -> Dictionary:
	## The form a summoner's summon takes at `level`, or {} for its own.
	if level <= 0 or not forms.has(id):
		return {}
	var list: Array = forms[id]
	if list.is_empty():
		return {}
	var n := mini(level, list.size())
	if not form_levels.is_empty():
		n = 0
		for at in form_levels:
			if level >= at:
				n += 1
		n = mini(n, list.size())
	if n <= 0:
		return {}
	return list[n - 1]


func has_unit(id: StringName) -> bool:
	return levels.has(id)


func level_values(id: StringName, level: int, cap := MAX_LEVEL) -> Dictionary:
	## A level's values. Past the written table (Lv5) and up to `cap`, each number
	## carries on the way it was going from Lv4 to Lv5, one step per level — so Lv10 is
	## five more of the last step. A number that was falling is not let below half its
	## Lv5 value, and a chance never above 1.
	if level <= 0 or not levels.has(id):
		return {}
	var rows: Array = levels[id]
	if rows.is_empty():
		return {}
	if level <= rows.size() or cap <= rows.size() or rows.size() < 2:
		return rows[clampi(level, 1, rows.size()) - 1]
	var past := mini(level, cap) - rows.size()
	var last: Dictionary = rows[rows.size() - 1]
	var before: Dictionary = rows[rows.size() - 2]
	var out := {}
	for key in last:
		var v = last[key]
		var step := float(v) - float(before.get(key, v))
		var x := float(v) + step * float(past)
		if step < 0.0:
			x = maxf(x, float(v) * 0.5)
		if String(key).contains("chance"):
			x = minf(x, 1.0)
		if LV10_CAPS.has(key):
			x = minf(x, float(LV10_CAPS[key]))
		out[key] = roundi(x) if v is int else x
	return out


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
