class_name UnitData
extends Resource

enum AttackType {
	MELEE,
	RANGED,
	SPELL,
}

## The value IS the tile count, which is why new bands are only ever appended at
## the top. Inserting one in the middle would silently re-reach every unit above
## it — MEDIUM becoming 3 would hand a tile to the Vexer, the Pyre, the Seraph,
## the Conjurer and the Wellspring at once.
enum RangeBand {
	MELEE = 1,
	MEDIUM = 2,
	LONG = 3,
	SNIPER = 4,
	SIEGE = 5,
	HORIZON = 6,
	UNLIMITED = 7,
}

const RANGE_NAMES := {
	RangeBand.MELEE: "Melee",
	RangeBand.MEDIUM: "Medium",
	RangeBand.LONG: "Long",
	RangeBand.SNIPER: "Sniper",
	RangeBand.SIEGE: "Siege",
	RangeBand.HORIZON: "Horizon",
	RangeBand.UNLIMITED: "Unlimited",
}

## The highest band a unit may be *printed* at. Everything above it exists to be
## reached through buffs, which is what keeps a range bonus feeling like a real
## prize rather than a rounding error.
const MAX_PRINTED_BAND := RangeBand.SNIPER

const UNLIMITED_TILES := 100

@export var id: StringName = &""
@export var display_name: String = "Unit"
@export var tier: int = 1

@export_group("Combat")
@export var max_hp: float = 100.0
@export var attack_damage: float = 10.0
@export var attack_speed: float = 1.0
@export var move_time: float = 0.45
@export_range(1, 7) var attack_range: int = RangeBand.MELEE
@export var sight_range: int = 4
@export var attack_type: AttackType = AttackType.MELEE

@export_group("Ability")
@export var ability: AbilityData = null
@export var mana_per_attack: float = 25.0
@export var mana_per_charge: float = 0.0
@export var mana_charge_time: float = 1.0
@export var keeps_mana: bool = false
@export var casts_at_battle_start: bool = false

## Mana gained every time one of its own side falls, anywhere on the board. It is
## the one mana source you cannot farm on purpose: the bar only moves while your
## army is losing people, so a unit built on this is strongest in the fight you
## are already losing and does nothing in the fight you are winning.
@export var mana_per_ally_death: float = 0.0

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

## Fraction of incoming damage this unit shrugs off before anything else is
## applied. 0.15 is 15% off every hit, all the time, with no upkeep.
@export_range(0.0, 0.9) var damage_resist: float = 0.0

## Fraction of the damage it deals that comes back as health, always, with no
## upkeep. The Bloodletting buff adds to this rather than replacing it — same
## shape as damage_resist and the RESIST stat.
@export_range(0.0, 1.0) var lifesteal: float = 0.0

## Health restored every second to each adjacent friendly MECHANICAL unit. This
## is a trait rather than an ability, because the unit that has it already spends
## its ability slot on building the thing it repairs.
@export var repair_per_second: float = 0.0

## Fights better alone. If your side starts the battle with no more than the
## empowered cap of this unit type on the board, each of them is empowered for
## the round: bigger, harder, and its ordinary swing splashes. Decided once, at
## the opening bell — anything that arrives later stays in its small form,
## because empowerment is a reward for how you built the board, not a thing you
## can summon your way into.
@export var solo_empower: bool = false
@export var empower_hp_mult: float = 1.0
@export var empower_damage_mult: float = 1.0

## Attack speed once empowered. Unlike the other two this is meant to go BELOW
## 1.0: the empowered form is a siege piece, not a faster version of the small
## one. Everything it is worth arrives in one swing, rarely.
@export var empower_attack_speed_mult: float = 1.0

## The radius its ordinary attack splashes over once empowered. 1 is a 3x3.
@export var empower_splash_radius: int = 0

## What fraction of its attack damage a swing does to stone. Everyone can chew
## through a wall eventually — that is what stops an army being sealed in
## permanently — but at 0.15 an ordinary unit needs a very long time and would
## much rather walk round. A Sapper is set far above 1.0, and because this is a
## multiple of attack damage rather than a flat number, its digging speed doubles
## with every tier for free.
@export var wall_damage_mult: float = 0.15

## Shield gained every time this unit is HIT, as a fraction of its max health.
## Per hit, deliberately — not per point of damage taken — which is the whole
## unit: a dozen small attacks feed it far more than one enormous one, so it eats
## a Vexer alive and folds to a Culverin.
##
## The shield goes up AFTER the blow that caused it lands, so there is no free
## first hit; what it buys is the next one.
@export var shield_on_hit: float = 0.0

## How much shield it may hold at once, as a fraction of max health. Without a cap
## a slow attacker could never out-pace the gain and the unit would simply stop
## dying. It still can stop dying against genuinely feeble attacks — that is what
## it is FOR — and sudden death is what eventually breaks the lock.
@export var shield_cap: float = 1.0

## While this unit is the LAST ONE ALIVE on its side, every hit it lands also
## takes this fraction of the target's maximum health. Its ordinary attack is
## deliberately pitiful, so this is not a bonus on top of a real unit — it is the
## entire unit, and it does nothing at all until its army is gone.
##
## Not the same thing as `solo_empower`, which asks "am I the only one of my
## KIND" and is decided once at the opening bell. This asks "is anyone else of
## mine still standing" and is asked live, on every single hit, so it switches on
## the moment the last ally falls and switches off again if one gets back up.
@export var alone_hp_damage: float = 0.0

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


func breaks_walls() -> bool:
	# "This unit is in the demolition business", which decides how eagerly it
	# paths into stone. Above 1.0 means one swing is worth more than an ordinary
	# swing at flesh, which nothing but a Sapper has any business being.
	return wall_damage_mult >= 1.0


func wall_damage() -> float:
	return attack_damage * maxf(wall_damage_mult, 0.0)
