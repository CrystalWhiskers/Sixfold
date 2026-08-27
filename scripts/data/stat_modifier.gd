## A single stat change. Buffs are just lists of these.
##
## Keeping modifiers as data (rather than baked-in numbers) is what lets a buff
## picked in round 4 still apply correctly in round 7, survive a merge, and show
## up in a tooltip without you writing the text by hand.
class_name StatModifier
extends Resource

enum Stat {
	MAX_HP,
	ATTACK_DAMAGE,
	ATTACK_COOLDOWN,
	MOVE_TIME,
	ATTACK_RANGE,
	SIGHT_RANGE,
}

enum Mode {
	FLAT,     ## Added before percentages.
	PERCENT,  ## 0.25 means +25%. Use -0.25 for -25%.
}

## Lower-is-better stats. Buffs to these should use negative values.
const INVERTED_STATS: Array[Stat] = [Stat.ATTACK_COOLDOWN, Stat.MOVE_TIME]

@export var stat: Stat = Stat.ATTACK_DAMAGE
@export var mode: Mode = Mode.FLAT
@export var value: float = 0.0


static func make(p_stat: Stat, p_mode: Mode, p_value: float) -> StatModifier:
	var m := StatModifier.new()
	m.stat = p_stat
	m.mode = p_mode
	m.value = p_value
	return m


## Human-readable, for buff tooltips. "Attack Damage +5" / "Move Time -15%".
func describe() -> String:
	var label: String = String(Stat.keys()[stat]).capitalize()
	if mode == Mode.PERCENT:
		return "%s %+d%%" % [label, roundi(value * 100.0)]
	return "%s %+.4g" % [label, value]
