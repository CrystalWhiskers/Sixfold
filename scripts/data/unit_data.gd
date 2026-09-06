class_name UnitData
extends Resource

enum AttackType {
	MELEE,
	RANGED,
	SPELL,
}

enum RangeBand {
	MELEE = 1,
	MEDIUM = 2,
	LONG = 3,
	SNIPER = 4,
	UNLIMITED = 5,
}

const RANGE_NAMES := {
	RangeBand.MELEE: "Melee",
	RangeBand.MEDIUM: "Medium",
	RangeBand.LONG: "Long",
	RangeBand.SNIPER: "Sniper",
	RangeBand.UNLIMITED: "Unlimited",
}

const UNLIMITED_TILES := 100

@export var id: StringName = &""
@export var display_name: String = "Unit"
@export var tier: int = 1

@export_group("Combat")
@export var max_hp: float = 100.0
@export var attack_damage: float = 10.0
@export var attack_speed: float = 1.0
@export var move_time: float = 0.45
@export_range(1, 5) var attack_range: int = RangeBand.MELEE
@export var sight_range: int = 4
@export var attack_type: AttackType = AttackType.MELEE

@export_group("Ability")
@export var ability: AbilityData = null
@export var mana_per_attack: float = 25.0
@export var mana_per_charge: float = 0.0
@export var mana_charge_time: float = 1.0
@export var keeps_mana: bool = false
@export var casts_at_battle_start: bool = false

## What a unit is made of. It exists so the Engineer has something to repair:
## nothing else in the game reads it, and a unit's chassis never changes.
enum Chassis {
	BIOLOGICAL,
	MECHANICAL,
}

const CHASSIS_NAMES := {
	Chassis.BIOLOGICAL: "Biological",
	Chassis.MECHANICAL: "Mechanical",
}

@export_group("Passive")
@export var chassis: Chassis = Chassis.BIOLOGICAL

## Health restored every second to each adjacent friendly MECHANICAL unit. This
## is a trait rather than an ability, because the unit that has it already spends
## its ability slot on building the thing it repairs.
@export var repair_per_second: float = 0.0

## Every friendly unit within this many tiles takes `burden_percent` more damage.
## A cost the unit imposes on its own side, not a debuff on the enemy.
@export var burden_radius: int = 0
@export var burden_percent: float = 0.0

@export var pierce_targets: int = 1
@export var merge_magnet: bool = false
@export var beam_attack: bool = false
@export var beam_splash: float = 0.0
@export var beam_endless: bool = false
@export var wild_merge: bool = false
@export var can_move: bool = true
@export var can_attack: bool = true

@export_group("Progression")
@export var next_tier: UnitData = null

@export_group("Presentation")
@export_multiline var note: String = ""
@export var sprite: Texture2D = null
@export var view_scene: PackedScene = null
@export var accent: Color = Color(0.62, 0.45, 0.22)


static func clamp_band(band: int) -> RangeBand:
	return clampi(band, RangeBand.MELEE, RangeBand.UNLIMITED) as RangeBand


static func band_tiles(band: int) -> int:
	var b := clamp_band(band)
	return UNLIMITED_TILES if b == RangeBand.UNLIMITED else int(b)


static func band_name(band: int) -> String:
	return RANGE_NAMES[clamp_band(band)]


func range_band() -> RangeBand:
	return clamp_band(attack_range)


func range_name() -> String:
	return band_name(attack_range)


func reach_tiles() -> int:
	return band_tiles(attack_range)


func is_max_tier() -> bool:
	return next_tier == null


func chain_length() -> int:
	var n := 1
	var cur: UnitData = self
	while cur.next_tier != null:
		cur = cur.next_tier
		n += 1
		if n > 16:
			push_error("Merge chain for '%s' looks circular." % id)
			break
	return n


func chassis_name() -> String:
	return CHASSIS_NAMES[chassis]


func is_mechanical() -> bool:
	return chassis == Chassis.MECHANICAL
