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
	TAUNT,
	REFLECT,
	RAISE,
	ASCEND,
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
## When above zero, the burst is this many times the caster's *current* attack
## damage instead of the flat `burst_damage`. Flat burst damage does not scale
## with tier or with any buff, so a unit whose ability is meant to be a big
## version of its own swing has to be written this way or its tier 6 hits for
## the same as its tier 1.
@export var burst_attack_multiple: float = 0.0
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

@export_group("Reflect")
## Extra resistance while the reflect is up, on top of whatever the unit already
## shrugs off innately.
@export var reflect_resist: float = 0.50
## What fraction of the damage it takes goes back at the attacker. 2.0 is 200%.
@export var reflect_percent: float = 2.0
@export var reflect_duration: float = 5.0

@export_group("Taunt")
## Enemies within this many tiles drop what they were doing and come for the
## caster, which is the point: it is not a damage ability, it is a way of
## choosing who the enemy army is fighting.
@export var taunt_radius: int = 3
@export var taunt_duration: float = 4.0
## What a fraction of the damage it takes while holding. 0.1 is 90% less.
@export var taunt_damage_taken: float = 0.10

## Only castable while the caster is empowered. A unit that never empowered has
## the ability on its card and greyed out, rather than a second hidden unit.
@export var requires_empowered: bool = false

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

@export_group("Raise")
## How many of the fallen come back per cast, per tier. At 1 a tier 1 raises one
## and a tier 6 raises six, which is the whole of how this unit scales — its own
## stats barely move.
@export var raise_per_tier: int = 1
## What health they get back at. Not full: the point is that a raised army is a
## second army worth less than the first.
@export var raise_hp_percent: float = 0.85

@export_group("Ascend")
## All three are multipliers on what the unit already has. `ascend_move_mult` is
## a multiplier on move *time*, so below 1.0 is faster — the same inversion that
## MOVE_TIME has everywhere else.
@export var ascend_hp_mult: float = 2.0
@export var ascend_attack_speed_mult: float = 1.6
@export var ascend_move_mult: float = 0.7
## Mana per swing, but only once it has changed. Before that the unit charges off
## its own side's deaths and nothing else, which is what makes the first
## transformation something the fight gives it rather than something it earns on
## its own — and what makes every execute after that its own work.
@export var ascend_mana_per_attack: float = 0.0

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
		Kind.REFLECT:
			return "For %.0f seconds it shrugs off a further %d%% of everything, and anything that hits it from an adjacent tile — a swing or an ability — takes %d%% of the damage straight back." % [
				reflect_duration, roundi(reflect_resist * 100.0),
				roundi(reflect_percent * 100.0)]
		Kind.TAUNT:
			return "Every enemy within %d tiles drops what it was doing and comes for it. For %.0f seconds it takes %d%% less damage, and it can neither move nor swing." % [
				taunt_radius, taunt_duration,
				roundi((1.0 - taunt_damage_taken) * 100.0)]
		Kind.MANA_AURA:
			return "Opens a zone %d tile(s) around it. Allies inside gain extra mana every second." % mana_aura_radius
		Kind.RAISE:
			return "Calls %d of your fallen back per tier, chosen at random, at %d%% health." % [
				raise_per_tier, roundi(raise_hp_percent * 100.0)]
		Kind.ASCEND:
			return "The first full bar changes it: %.1fx health, %.0f%% faster swings, %.0f%% faster on its feet. Every bar after that arms the next swing to kill outright, whatever it hits." % [
				ascend_hp_mult,
				(ascend_attack_speed_mult - 1.0) * 100.0,
				(1.0 - ascend_move_mult) * 100.0]
	return ""
