class_name AbilityData
extends Resource

enum Kind {
	HASTE,
	SHIELD,
	DOT,
	FOCUS_BURST,
	PIERCE,
	BLINK_STRIKE,
	SPEED_AURA,
	REVIVE,
	BURST_HEAL,
	SUMMON,
	MANA_AURA,
}

@export var id: StringName = &""
@export var display_name: String = "Ability"
@export_multiline var description: String = ""
@export var kind: Kind = Kind.HASTE
@export var cast_time: float = 0.5

@export_group("Haste")
@export var haste_percent: float = 0.18
@export var haste_max_stacks: int = 5

@export_group("Shield")
@export var shield_percent: float = 1.25
@export var shield_cap_percent: float = 1.25

@export_group("Damage over time")
@export var dot_damage: float = 9.0
@export var dot_ticks: int = 5
@export var dot_interval: float = 0.5

@export_group("Focus burst")
@export var burst_damage: float = 58.0
@export var splash_damage: float = 12.0
@export var splash_radius: int = 1

@export_group("Pierce")
@export var pierce_targets: int = 3
@export var pierce_damage_mult: float = 2.0

@export_group("Blink strike")
@export var blink_base_damage: float = 46.0
@export var stealth_time: float = 3.5

@export_group("Attack speed aura")
@export var aura_percent_per_tier: float = 0.12
@export var aura_radius: int = 1

@export_group("Revive")
@export var revive_chance: float = 0.5
@export var revive_delay: float = 1.0
@export var revive_hp_percent: float = 1.0

@export_group("Burst heal")
@export var heal_percent: float = 0.45
@export var heal_percent_per_tier: float = 0.20
@export var heal_radius: int = 3

@export_group("Summon")
@export var summon_unit: UnitData = null
@export var summon_max: int = 3
@export var summon_count: int = 1
@export var summon_random: bool = false
@export var summon_cap_by_tier: bool = true
@export var summon_persists: bool = false
@export var consumes_caster: bool = false
@export var summon_adjacent: bool = true
@export var summon_instacasts: bool = false

## The opener is normally instant — no wind-up in the simulation at all. This
## makes it take its real `cast_time` instead, so there is a window in which the
## caster is standing there doing it.
@export var opener_takes_time: bool = false

## The opposite of `guards_caster`: while casting, the caster takes this much
## more damage. 1.0 is double. The two are mutually exclusive by construction —
## a cast is either protected or exposed, never both.
@export var exposes_caster: float = 0.0

## Do not start a cast that cannot land. The Spire deliberately burns its bar
## when it has no room — that is the pressure to merge before it is ready. A
## builder standing exposed for two and a half seconds to produce nothing is not
## pressure, it is a trap, so it waits instead.
@export var holds_when_capped: bool = false

## Build it on the tile the caster is standing on, and step the caster aside.
## Falls back to ordinary adjacent placement if there is nowhere to step.
@export var summon_at_caster: bool = false

## A retinue rather than a one-off: the cap counts how many of this caster's
## summons are still standing, and a cast tops the retinue back up to it. Lose a
## wisp and the next full bar replaces it; a tier 6 Conjurer opens with three.
@export var summon_retinue: bool = false
@export var guards_caster: bool = false

@export_group("Mana aura")
@export var mana_aura_radius: int = 1


func describe() -> String:
	if not description.is_empty():
		return description
	match kind:
		Kind.HASTE:
			return "Attacks %d%% faster. Stacks up to %d times." % [
				roundi(haste_percent * 100.0), haste_max_stacks]
		Kind.SHIELD:
			return "Gains a shield worth %d%% of max health. It absorbs damage first and cannot be healed." % [
				roundi(shield_percent * 100.0)]
		Kind.DOT:
			return "Poisons one enemy for %d damage every %.1fs, %d times." % [
				roundi(dot_damage), dot_interval, dot_ticks]
		Kind.FOCUS_BURST:
			return "%d damage to the target, %d to everything within %d tiles of it." % [
				roundi(burst_damage), roundi(splash_damage), splash_radius]
		Kind.PIERCE:
			return "A strike through up to %d enemies for %.0f%% damage." % [
				pierce_targets, pierce_damage_mult * 100.0]
		Kind.BLINK_STRIKE:
			return "Blinks behind a target for %d damage, doubling every tier, then vanishes for %.1fs." % [
				roundi(blink_base_damage), stealth_time]
		Kind.SPEED_AURA:
			return "Allies within %d tile(s) gain %d%% attack speed per tier." % [
				aura_radius, roundi(aura_percent_per_tier * 100.0)]
		Kind.REVIVE:
			return "%d%% chance to get back up %.1fs after every death, at %d%% health." % [
				roundi(revive_chance * 100.0), revive_delay,
				roundi(revive_hp_percent * 100.0)]
		Kind.BURST_HEAL:
			return "Heals the worst-hurt ally within %d tiles for %d%% of their max health, +%d%% of that per tier." % [
				heal_radius, roundi(heal_percent * 100.0),
				roundi(heal_percent_per_tier * 100.0)]
		Kind.SUMMON:
			if summon_random:
				var tail := (" They stay with you for the rest of the match."
					if summon_persists else "")
				if summon_instacasts:
					tail += " They arrive mid-cast: each one uses its own ability the moment it lands."
				if consumes_caster:
					tail += " Raising them uses the caster up: it dies on the spot and does not come back."
				return "Summons %d random units at its own tier, right beside itself — or none at all, if there is no room for the whole set.%s" % [
					summon_count, tail]
			return "Summons a minion, up to %d at the highest tiers." % summon_max
		Kind.MANA_AURA:
			return "Opens a zone %d tile(s) around it. Allies inside gain extra mana every second." % mana_aura_radius
	return ""
