## A unit's mana ability.
##
## Every unit charges the same 100-point bar; only the gain rate differs
## (UnitData.mana_per_attack). Mana comes from LANDING ATTACKS, so a unit that
## can't reach anything never casts — that's deliberate, it makes protecting your
## damage dealers matter.
##
## Casting locks the unit in CASTING for cast_time: it can't attack or move. Same
## exposure rule as committing to a step. An ability that fires for free would
## undercut the whole positioning game.
##
## This is one resource with a `kind` switch and a field group per kind rather
## than a subclass per ability. With five abilities that's the honest trade —
## everything is visible in one inspector panel, and the sim switches on `kind`
## in exactly one place (CombatSim._resolve_ability).
class_name AbilityData
extends Resource

enum Kind {
	HASTE,        ## Permanent stacking attack-speed buff. (Archer)
	SHIELD,       ## Temporary hit points that healing can't restore. (Warden)
	DOT,          ## Damage over time on a single enemy. (Vexer)
	FOCUS_BURST,  ## Big damage to the main target, a little to its neighbours. (Pyre)
	PIERCE,       ## A strong strike through several enemies in a line. (Lancer)
}

@export var id: StringName = &""
@export var display_name: String = "Ability"
@export_multiline var description: String = ""
@export var kind: Kind = Kind.HASTE
## Locked, unable to attack or move, for this long while casting.
@export var cast_time: float = 0.5

@export_group("Haste")
## Attack-cooldown reduction per stack, as a fraction. 0.18 = 18% faster.
@export var haste_percent: float = 0.18
## Hard cap. Stacking is permanent for the battle, so without this a protected
## Archer's fire rate would run away entirely.
@export var haste_max_stacks: int = 5

@export_group("Shield")
@export var shield_amount: float = 55.0
## Recasting tops the shield back up to this, it doesn't stack past it.
@export var shield_cap: float = 55.0

@export_group("Damage over time")
@export var dot_damage: float = 9.0     ## Per tick.
@export var dot_ticks: int = 5
@export var dot_interval: float = 0.5

@export_group("Focus burst")
@export var burst_damage: float = 58.0  ## To the main target.
@export var splash_damage: float = 12.0 ## To everything else in radius.
@export var splash_radius: int = 1

@export_group("Pierce")
## How many enemies the empowered strike passes through.
@export var pierce_targets: int = 3
## Multiplier on the caster's attack damage.
@export var pierce_damage_mult: float = 2.0


## Tooltip text, generated from the numbers so it can't drift out of sync.
func describe() -> String:
	if not description.is_empty():
		return description
	match kind:
		Kind.HASTE:
			return "Attacks %d%% faster. Stacks up to %d times." % [
				roundi(haste_percent * 100.0), haste_max_stacks]
		Kind.SHIELD:
			return "Gains %d shield. Shield absorbs damage first and cannot be healed." % [
				roundi(shield_amount)]
		Kind.DOT:
			return "Poisons one enemy for %d damage every %.1fs, %d times." % [
				roundi(dot_damage), dot_interval, dot_ticks]
		Kind.FOCUS_BURST:
			return "%d damage to the target, %d to everything within %d tiles of it." % [
				roundi(burst_damage), roundi(splash_damage), splash_radius]
		Kind.PIERCE:
			return "A strike through up to %d enemies for %.0f%% damage." % [
				pierce_targets, pierce_damage_mult * 100.0]
	return ""
