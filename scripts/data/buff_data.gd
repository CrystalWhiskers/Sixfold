class_name BuffData
extends Resource

enum Rarity {
	BRONZE,
	SILVER,
	GOLD,
}

enum Kind {
	STAT,
	REGEN,
	PERCENT_HP_DAMAGE,
	MERGE_EXTRA_UNIT,
	MERGE_EXTRA_TIER,
	FULL_ROSTER,
	EXTRA_DRAW,
	BOARD_FILL,
	WILD_MERGE,
	TIER_GIFT,
	SACRIFICE,
	MIMIC,
}

const ONE_SHOT_KINDS := [Kind.BOARD_FILL, Kind.TIER_GIFT, Kind.SACRIFICE,
	Kind.MIMIC]

const RARITY_NAMES := ["Bronze", "Silver", "Gold"]
const RARITY_COLORS := [
	Color(0.72, 0.47, 0.30),
	Color(0.75, 0.78, 0.82),
	Color(0.92, 0.76, 0.32),
]

@export var id: StringName = &""
@export var display_name: String = "Buff"
@export_multiline var description: String = ""
@export var kind: Kind = Kind.STAT
@export var unit_id: StringName = &""
@export var also_units: Array[StringName] = []

## Gold only, and only on the buff belonging to a unit that empowers: raises how
## many of that unit may be empowered at the opening bell. Zero means the buff
## does not touch it. This is the one buff effect that is not a stat.
@export var empowered_cap_at_gold: int = 0

## Extra units raised per cast by whatever this buff covers, bronze/silver/gold.
## Like `empowered_cap_at_gold` this is a rider on a stat buff rather than a stat
## of its own — the buff is still a max-health buff, this is what makes it the
## Vigil's max-health buff rather than anyone's.
@export var extra_raises: Vector3 = Vector3.ZERO

## Extra toughness on walls raised by whatever this buff covers, bronze/silver/
## gold, as a fraction. 1.0 is "twice as hard to knock down". Another rider on a
## stat buff, like extra_raises — the buff is still a max-health buff, this is
## what makes it the Mason's.
@export var wall_toughness: Vector3 = Vector3.ZERO

## Extra shield-per-hit for whatever this buff covers, bronze/silver/gold, as a
## fraction of max health. Another rider on a stat buff, like extra_raises and
## wall_toughness — the buff is still a max-health buff, this is what makes it the
## Colossus's.
@export var shield_on_hit: Vector3 = Vector3.ZERO
@export var weight: float = 1.0
@export var exclusive_rarity: int = -1

@export_group("Magnitude")
@export var bronze: Vector2 = Vector2.ZERO
@export var silver: Vector2 = Vector2.ZERO
@export var gold: Vector2 = Vector2.ZERO

@export_group("Stats")
@export var stat_a: StatModifier.Stat = StatModifier.Stat.ATTACK_DAMAGE
@export var stat_b: StatModifier.Stat = StatModifier.Stat.ATTACK_DAMAGE
@export var uses_second_stat: bool = false
@export var stat_c: StatModifier.Stat = StatModifier.Stat.AURA_POWER
@export var uses_third_stat: bool = false
@export var flat: bool = false
@export var flat_b: bool = false
@export var third: Vector3 = Vector3.ZERO


static func rarity_name(r: Rarity) -> String:
	return RARITY_NAMES[clampi(int(r), 0, 2)]


static func rarity_color(r: Rarity) -> Color:
	return RARITY_COLORS[clampi(int(r), 0, 2)]


func magnitude(r: Rarity) -> Vector2:
	match r:
		Rarity.BRONZE:
			return bronze
		Rarity.SILVER:
			return silver
	return gold


func applies_to(u: UnitInstance) -> bool:
	if unit_id == &"":
		return true
	if u == null or u.data == null:
		return false
	return u.data.id == unit_id or also_units.has(u.data.id)


func covers() -> Array[StringName]:
	var out: Array[StringName] = []
	if unit_id != &"":
		out.append(unit_id)
		out.append_array(also_units)
	return out


func is_global() -> bool:
	return unit_id == &""


func is_exclusive() -> bool:
	return exclusive_rarity >= 0


func available_at(r: Rarity) -> bool:
	return not is_exclusive() or int(r) == exclusive_rarity


func is_one_shot() -> bool:
	return ONE_SHOT_KINDS.has(kind)


func exclusive_label() -> String:
	if not is_exclusive():
		return ""
	return "%s exclusive" % rarity_name(clampi(exclusive_rarity, 0, 2) as Rarity)


func modifiers_for(r: Rarity) -> Array[StatModifier]:
	var out: Array[StatModifier] = []
	if kind != Kind.STAT and kind != Kind.FULL_ROSTER:
		return out
	var m := magnitude(r)
	var mode := StatModifier.Mode.FLAT if flat else StatModifier.Mode.PERCENT
	var mode_b := StatModifier.Mode.FLAT if flat_b else StatModifier.Mode.PERCENT
	if not is_zero_approx(m.x):
		out.append(StatModifier.make(stat_a, mode, m.x))
	if uses_second_stat and not is_zero_approx(m.y):
		out.append(StatModifier.make(stat_b, mode_b, m.y))
	var extra := third_magnitude(r)
	if uses_third_stat and not is_zero_approx(extra):
		out.append(StatModifier.make(stat_c, StatModifier.Mode.PERCENT, extra))
	return out


func extra_raises_at(r: Rarity) -> int:
	match r:
		Rarity.BRONZE:
			return roundi(extra_raises.x)
		Rarity.SILVER:
			return roundi(extra_raises.y)
	return roundi(extra_raises.z)


func shield_on_hit_at(r: Rarity) -> float:
	match r:
		Rarity.BRONZE:
			return shield_on_hit.x
		Rarity.SILVER:
			return shield_on_hit.y
	return shield_on_hit.z


func wall_toughness_at(r: Rarity) -> float:
	match r:
		Rarity.BRONZE:
			return wall_toughness.x
		Rarity.SILVER:
			return wall_toughness.y
	return wall_toughness.z


func third_magnitude(r: Rarity) -> float:
	match r:
		Rarity.BRONZE:
			return third.x
		Rarity.SILVER:
			return third.y
	return third.z


func describe(r: Rarity) -> String:
	if not description.is_empty():
		return description % _numbers(r)
	var m := magnitude(r)
	var who := "All units" if is_global() else _who()
	match kind:
		Kind.STAT:
			var line := "%s: %s" % [who, _stat_phrase_with_extra(m, r)]
			# The one non-stat rider in the game, and it only exists at gold, so
			# the card has to say so at every rarity or it reads as a surprise.
			if empowered_cap_at_gold > 0:
				line += ("  At gold, %d of them may be empowered at the opening bell instead of one."
					% empowered_cap_at_gold) if r == Rarity.GOLD else \
					("  At gold this also lets %d of them be empowered at once."
					% empowered_cap_at_gold)
			var raises := extra_raises_at(r)
			if raises > 0:
				line += "  Each of them calls back %d more of the fallen per cast." % raises
			var tough := wall_toughness_at(r)
			if tough > 0.0:
				line += "  The walls it raises are %s harder to bring down." % _bare(tough)
			var plate := shield_on_hit_at(r)
			if plate > 0.0:
				line += "  Every hit it takes also adds %s of its max health to its shield." % _bare(plate)
			return line
		Kind.REGEN:
			return "Allies heal %s of max health every second." % _bare(m.x)
		Kind.PERCENT_HP_DAMAGE:
			return "Attacks deal an extra %s of the target's max health." % _bare(m.x)
		Kind.MERGE_EXTRA_UNIT:
			return "%s chance on merge to summon one extra random unit." % _bare(m.x)
		Kind.MERGE_EXTRA_TIER:
			return "%s chance on merge for the result to gain a tier." % _bare(m.x)
		Kind.FULL_ROSTER:
			return "While all five unit types are on the board: %s" % _stat_phrase(m)
		Kind.EXTRA_DRAW:
			return "Draw %d more unit(s) every turn from now on." % roundi(m.x)
		Kind.BOARD_FILL:
			return "Right now: draw tier 1 units until you have %d on the board. Worth most when you are behind." % roundi(m.x)
		Kind.WILD_MERGE:
			return "Any two of your units of the same tier can merge, whatever they are."
		Kind.TIER_GIFT:
			return "Right now: %d tier %d units. You draw nothing next round." % [
				roundi(m.x), roundi(m.y)]
		Kind.SACRIFICE:
			return "Right now: your highest-tier unit is consumed and every other unit gains tiers — 1 for a tier 1-2, 2 for a tier 3-4, 3 for a tier 5-6."
		Kind.MIMIC:
			return "Right now: %d copy of your highest-tier unit, at its tier, placed on your half." % roundi(m.x) if roundi(m.x) == 1 else "Right now: %d copies of your highest-tier unit, at its tier, placed on your half." % roundi(m.x)
	return ""


func _who() -> String:
	var names: PackedStringArray = [String(unit_id).capitalize() + "s"]
	for extra in also_units:
		names.append(String(extra).capitalize() + "s")
	return " and ".join(names)


func _numbers(r: Rarity) -> Array:
	var m := magnitude(r)
	return [_bare(m.x), _bare(m.y)]


func _stat_phrase(m: Vector2) -> String:
	var parts: PackedStringArray = []
	parts.append(_one_stat(stat_a, m.x, flat))
	if uses_second_stat:
		parts.append(_one_stat(stat_b, m.y, flat_b))
	return " and ".join(parts) + "."


static func _one_stat(s: StatModifier.Stat, v: float, is_flat: bool) -> String:
	if is_flat:
		return "%s +%s" % [_stat_name(s), _flat_value(s, v)]
	return "%s %s" % [_stat_name(s), _pct(v)]


func _stat_phrase_with_extra(m: Vector2, r: Rarity) -> String:
	var text := _stat_phrase(m)
	if not uses_third_stat or is_zero_approx(third_magnitude(r)):
		return text
	return "%s Its own buff is %s stronger." % [
		text, _bare(third_magnitude(r))]


static func _stat_name(s: StatModifier.Stat) -> String:
	match s:
		StatModifier.Stat.MAX_HP:
			return "max health"
		StatModifier.Stat.ATTACK_DAMAGE:
			return "attack"
		StatModifier.Stat.ATTACK_SPEED:
			return "attack speed"
		StatModifier.Stat.MOVE_TIME:
			return "move time"
		StatModifier.Stat.ATTACK_RANGE:
			return "range band"
		StatModifier.Stat.SIGHT_RANGE:
			return "sight"
		StatModifier.Stat.HEAL_POWER:
			return "healing"
		StatModifier.Stat.AURA_POWER:
			return "aura strength"
		StatModifier.Stat.DAMAGE_TAKEN:
			return "damage taken"
		StatModifier.Stat.LIFESTEAL:
			return "lifesteal"
		StatModifier.Stat.MANA_REGEN:
			return "mana a charge"
	return "stat"


static func _bare(v: float) -> String:
	var n := v * 100.0
	if is_equal_approx(n, roundf(n)):
		return "%d%%" % roundi(n)
	return "%.1f%%" % n


static func _pct(v: float) -> String:
	return "+%d%%" % roundi(v * 100.0) if v >= 0.0 else "%d%%" % roundi(v * 100.0)


static func _flat_value(s: StatModifier.Stat, v: float) -> String:
	if s == StatModifier.Stat.LIFESTEAL:
		return _bare(v)
	return "%d" % roundi(v)
