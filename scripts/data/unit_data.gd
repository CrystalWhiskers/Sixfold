## A unit's stat block. Authored in the inspector, saved as a .tres, and NEVER
## mutated at runtime.
##
## Two units of the same type share one UnitData object. Writing to it at runtime
## changes every unit of that type at once, and in the editor it edits the file on
## disk. All per-unit state lives on UnitInstance instead.
class_name UnitData
extends Resource

enum AttackType {
	MELEE,   ## Short range, usually 1.
	RANGED,  ## Attacks from a distance, fragile up close.
	SPELL,   ## Attacks normally but leans on its ability.
}

@export var id: StringName = &""
@export var display_name: String = "Unit"
## 1 = base. Two tier-1s merge into a tier-2, and so on.
@export var tier: int = 1

@export_group("Combat")
@export var max_hp: float = 100.0
@export var attack_damage: float = 10.0
## Seconds between attacks. Lower is faster.
@export var attack_cooldown: float = 1.0
## Seconds to cross ONE tile. Lower is faster.
##
## Stored as time-per-tile rather than tiles-per-second on purpose: a unit that
## commits to a move is locked for exactly this long and cannot attack during it.
## That single fact is the whole "died because it was caught walking" mechanic.
@export var move_time: float = 0.45
## In tiles, Chebyshev distance (diagonals count as 1).
@export var attack_range: int = 1
## Unused by the current fog rules, which conceal the opponent's whole half
## during prep and lift entirely once the battle starts — there is no
## per-unit vision to compute.
##
## Kept because it's the natural hook for a scout: a unit that reveals part of
## the enemy half during prep. Delete it if you decide against that.
@export var sight_range: int = 4
@export var attack_type: AttackType = AttackType.MELEE

@export_group("Ability")
@export var ability: AbilityData = null
## Mana gained per attack LANDED. The bar is 100 for everyone
## (UnitInstance.MANA_MAX); only this rate differs, so 25 means every 4th attack
## casts and 50 means every 2nd.
@export var mana_per_attack: float = 25.0
## Fires the ability once for free on the first tick of the battle, before any
## mana has been earned. Warden opens with its shield up.
@export var casts_at_battle_start: bool = false

@export_group("Passive")
## How many enemies an ORDINARY attack passes through. 1 is a normal single
## target; Lancer's 2 is its passive. The ability can raise this for one strike.
@export var pierce_targets: int = 1

@export_group("Progression")
## What two of these merge into. Leave null to mark the top of the chain.
@export var next_tier: UnitData = null

@export_group("Presentation")
## Drop your sprite here. UnitView falls back to a coloured block if it's null.
@export var sprite: Texture2D = null
## Optional: a whole scene per unit, if you want animation or particles.
@export var view_scene: PackedScene = null
## Used for the fallback block and for team-neutral UI accents.
@export var accent: Color = Color(0.62, 0.45, 0.22)


func is_max_tier() -> bool:
	return next_tier == null


## Walks the merge chain. Useful for tooltips and for the data generator's checks.
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
