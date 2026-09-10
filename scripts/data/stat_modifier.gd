class_name StatModifier
extends Resource

enum Stat {
	MAX_HP,
	ATTACK_DAMAGE,
	ATTACK_SPEED,
	MOVE_TIME,
	ATTACK_RANGE,
	SIGHT_RANGE,
	HEAL_POWER,
	AURA_POWER,
	DAMAGE_TAKEN,
	LIFESTEAL,
	MANA_REGEN,
	## Fraction of incoming damage shrugged off. Higher is better, unlike
	## DAMAGE_TAKEN, which is a multiplier — a buff that reads "+15% resist"
	## should not have to be written as a negative number to work.
	RESIST,
	## How long a freeze this unit lands, and how much extra the frozen thing
	## takes. Both are multipliers with a base of 1.0, exactly like HEAL_POWER and
	## AURA_POWER: the ability owns the real number and these scale it, so a buff
	## that wants "+50% freeze time" is an ordinary PERCENT modifier and needs no
	## machinery of its own.
	FREEZE_POWER,
	FREEZE_AMP,
}

enum Mode {
	FLAT,
	PERCENT,
}

const INVERTED_STATS: Array[Stat] = [Stat.MOVE_TIME]

@export var stat: Stat = Stat.ATTACK_DAMAGE
@export var mode: Mode = Mode.FLAT
@export var value: float = 0.0


static func make(p_stat: Stat, p_mode: Mode, p_value: float) -> StatModifier:
	var m := StatModifier.new()
	m.stat = p_stat
	m.mode = p_mode
	m.value = p_value
	return m


func describe() -> String:
	var label: String = String(Stat.keys()[stat]).capitalize()
	if mode == Mode.PERCENT:
		return "%s %+d%%" % [label, roundi(value * 100.0)]
	return "%s %+.4g" % [label, value]
