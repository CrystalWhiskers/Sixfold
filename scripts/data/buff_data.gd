## A between-rounds buff. Either boosts one chosen unit or the whole roster.
class_name BuffData
extends Resource

enum Scope {
	SINGLE_UNIT,  ## Player picks which unit receives it.
	ALL_UNITS,    ## Applies to the entire roster, now and to units drawn later.
}

@export var id: StringName = &""
@export var display_name: String = "Buff"
@export_multiline var description: String = ""
@export var scope: Scope = Scope.ALL_UNITS
@export var modifiers: Array[StatModifier] = []
## Relative chance of being offered. 0 removes it from the pool.
@export var weight: float = 1.0


## Auto-generated tooltip body, so you never have to keep text in sync with numbers.
func describe() -> String:
	if not description.is_empty():
		return description
	var parts: PackedStringArray = []
	for m in modifiers:
		parts.append(m.describe())
	var target := "This unit" if scope == Scope.SINGLE_UNIT else "All units"
	return "%s: %s" % [target, ", ".join(parts)]


## Fresh copies, so two picks of the same buff don't share modifier objects.
func instantiate_modifiers() -> Array[StatModifier]:
	var out: Array[StatModifier] = []
	for m in modifiers:
		out.append(m.duplicate() as StatModifier)
	return out
