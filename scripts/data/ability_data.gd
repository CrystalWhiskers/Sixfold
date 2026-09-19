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
	SAP,
	BUILD,
	SHELL,
	DRAIN,
	FREEZE,
	CHARGE,
	POSSESS,
	FRENZY,
	DISORIENT,
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

## Extra damage the poisoned unit takes from EVERY source while the dot is on it,
## per tier of the caster: 0.05 on a tier 3 Vexer is +15%. Read off the caster at
## the moment of the cast and then frozen into that dot, so the number is the one
## the Vexer had when it poisoned you — killing the Vexer afterwards does not
## un-poison the target, and buffing it mid-round does not retroactively deepen a
## poison already ticking.
##
## Per tier rather than flat because an AbilityData is ONE resource shared by all
## six tiers of a unit (which is why `dot_damage` does not scale and
## `burst_attack_multiple` exists). Multiplying by the caster's tier here is the
## cheap version of that fix, for a value that is a percentage to begin with.
@export var dot_vulnerability_per_tier: float = 0.0

## The FIRST tick's damage as a fraction of the victim's CURRENT health, on top
## of the flat `dot_damage`. Blight is written entirely this way — `dot_damage` is
## zero on it.
##
## Current health, not maximum, and the difference is the whole character of the
## unit. A share of what is left can never actually kill: sixty percent of sixty
## percent of sixty percent approaches zero and never reaches it. So the Vexer
## cannot finish anything, at any tier, ever — it takes a great bite out of
## whatever is healthiest and hands it to somebody else to put down. It also
## scales for free, the same way a share of maximum did.
@export var dot_current_hp_percent: float = 0.0

## What the share is multiplied by after every tick. 0.5 halves it each time, so
## a poison that opens at 25% goes 25, 12.5, 6.25, 3.1... — it cripples on landing
## and is nearly spent by the end. 1.0 would make every tick equal.
@export var dot_falloff: float = 1.0

## While this dot is on a unit, the unit gains NOTHING: no healing, no shields, no
## new haste stacks, no aura from an ally, no mana from a Wellspring. It is the
## other half of what makes the poison worth casting on the thing that is winning.
@export var dot_suppresses: bool = false

@export_group("Freeze")
## Seconds of freeze per tier of the caster, so a tier 1 lands a moment and a
## tier 6 lands six times that. Per tier for the same reason
## `dot_vulnerability_per_tier` is: an AbilityData is ONE resource shared by all
## six tiers, so a flat number here would not scale at all.
@export var freeze_seconds_per_tier: float = 0.0

## Extra damage the frozen unit takes, per tier of the caster. 0.10 on a tier 3
## is +30%. Added, not multiplied, so reading the number off the card and
## multiplying by the tier gives you the real figure.
@export var freeze_amp_per_tier: float = 0.0

@export_group("Focus burst")
## When above zero, the burst is this many times the caster's *current* attack
## damage instead of the flat `burst_damage`. Flat burst damage does not scale
## with tier or with any buff, so a unit whose ability is meant to be a big
## version of its own swing has to be written this way or its tier 6 hits for
## the same as its tier 1.
@export var burst_attack_multiple: float = 0.0
## Read at TIER ONE. CombatSim.burst_damage_of doubles it per tier, the same way
## the blink's base damage is doubled and the same way every stat on the unit table
## is — so this number is the tier 1 figure and not the figure.
##
## It used to be taken flat, which is the trap the comment above warns about and
## which the Pyre walked straight into: its tier 6 lance hit for exactly what its
## tier 1 did, against health bars thirty-two times bigger.
@export var burst_damage: float = 58.0
## Scaled per tier alongside burst_damage. A splash that stayed flat while the
## direct hit grew would quietly turn into nothing.
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

## Whether the heal also lifts the target's debuffs. Kept as a flag on the
## ability rather than baked into BURST_HEAL, so a second healer can exist that
## only heals — cleansing is a thing an ability does, not a thing healing is.
@export var cleanses: bool = false

@export_group("Charge")
## A multiple of the caster's own attack damage, per tier. A charge at 1.5 on a
## tier 3 hits for 4.5x its attack — off attack rather than a flat number, so it
## rides every buff that sharpens the unit and needs no separate tier table.
@export var charge_damage_per_tier: float = 0.0

## Seconds of stun, per tier. A tier 3 charger at 0.4 stuns for 1.2s.
@export var stun_seconds_per_tier: float = 0.0

## How far it will run before giving up. The board is eleven tall, so anything at
## or above that is "the whole board".
@export var charge_distance: int = 11

## Seconds the charge spends crossing ONE tile, and the whole reason a charge can be
## dodged at all.
##
## This used to not exist: the charge resolved in a single tick, so the unit at the far
## end of the lane was hit in the same instant the Breaker decided to run, and the run
## you saw on screen was an animation played after the fact. Nothing could get out of
## the way, because there was no "way" — there was a cast and a result.
##
## Now the charge advances a tile at a time and picks its victim ON ARRIVAL, so anything
## that leaves the lane before it gets there is missed and anything that walks INTO the
## lane is hit instead. That makes the number below the unit's whole character: at zero
## it is the old instant slam, at a walking pace it is just a unit that walks. It wants
## to be clearly faster than a unit on foot and slow enough to be seen coming.
@export var charge_tile_seconds: float = 0.0

@export_group("Possess")
## A higher-tier Usurper drags its host up to its own tier for the round. The
## owner does not keep it: release_possession() puts the original row back at the
## round boundary.
@export var possess_forces_tier: bool = true

## What the husk's move time is multiplied by once its host dies. Above 1.0 is
## slower, because MOVE_TIME is seconds per tile.
@export var husk_move_mult: float = 2.6

## Damage dealt when it tries to take something ABOVE its own tier, as a multiple
## of its own max health per tier of the gap. It dies doing it.
@export var backlash_per_tier: float = 1.0

## How long the grip holds, in seconds PER TIER of the Usurper. Zero means "the
## whole round", which is what the unit was asked for first and is no longer the
## default — see below.
##
## Per tier rather than flat because a bigger Usurper should hold on longer, and
## because the whole-round version is decisive: a single Usurper in a five-unit
## line wins 100% of measured matches, since it opens the fight six against four
## and never gives the body back. The curve from there is steep and worth having
## written down —
##
##     whole round  100%  ·  10s  85%  ·  5s  50%  ·  3s  31.5%
##
## against a 49.8% baseline for an ordinary unit in the same slot. At 2.5 seconds a
## tier the ladder runs 2.5 / 5 / 7.5 / 10 / 12.5 / 15, which puts a tier 2 exactly
## on the median and lets the top of the ladder keep a body for most of a round.
##
## Halving the host's damage instead does nothing at all (still 100%): the value is
## in the body count, not in what the body hits for, which is the same lesson the
## six-wisp Conjurer taught.
@export var possess_seconds_per_tier: float = 0.0

## How much weaker a stolen body is while it is being driven, as a fraction taken off its
## attack damage and its maximum health. 0.5 is "half the unit it was".
##
## The point is that a puppet is not the same as the real thing. Without it the Usurper
## hands you a fully effective enemy unit AND takes one off their board, which measured
## out at 95-100% win rates at the top of the tier ladder — it was not that the unit hit
## too hard, it was that body count beats power and the swing was two bodies wide.
@export var possess_weakness: float = 0.0

## How much of that weakness is bought off by each tier above the first. At 0.10 against a
## 0.50 base the ladder runs 50 / 40 / 30 / 20 / 10 / 0 — so a tier 6 Usurper drives a
## stolen body at full strength and every tier below it is a compromise.
##
## This is the merge incentive for a unit that had none worth the name. Its old reward for
## merging was a longer grip and a higher forced tier on the host; now the difference
## between a tier 1 and a tier 6 is whether the thing you stole actually fights.
@export var possess_weakness_per_tier: float = 0.0

@export_group("Summon")
@export var summon_unit: UnitData = null
@export var summon_max: int = 3
@export var summon_count: int = 1
@export var summon_random: bool = false
@export var summon_cap_by_tier: bool = true

## How fast the cap climbs with tier, when summon_cap_by_tier is on. 0.5 is one
## more every two tiers — 1 at tiers 1-2, 2 at 3-4, 3 at 5-6 — which is what the
## Engineer's sentries and most retinues want. 1.0 is one more every tier, which
## is the Conjurer: six wisps at tier 6. The cap is always clamped to summon_max,
## so that number is still the real ceiling.
@export var summon_per_tier: float = 0.5
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

@export_group("Terrain")
## How far from the caster it will reach to break or raise. 1 is the eight tiles
## around it — the same reach a melee unit swings at.
@export var terrain_reach: int = 1
## How many tiles one cast changes.
@export var terrain_tiles: int = 1
## A sapping charge is worth this many of the caster's ordinary wall swings. It
## multiplies attack damage rather than being a flat number, so a tier 6 charge
## is 32 times a tier 1 one and the unit's attack buff reaches it.
@export var sap_burst_multiple: float = 4.0
## How tough a raised wall is before any buff. Map stone is BoardModel.WALL_HP.
@export var wall_hp: float = 240.0
## Build on the tile the caster is standing on and step it aside, the way the
## Engineer bolts its Sentry together underfoot. It puts the wall exactly where
## the builder chose to stand, which makes placing the Mason the decision rather
## than guessing which way it happens to be facing.
@export var terrain_at_caster: bool = false

@export_group("Shell")
## The shell's damage, as a multiple of the caster's attack. Written this way for
## the same reason as Execute: a flat number would not scale with tier and no buff
## would ever reach it.
@export var shell_attack_multiple: float = 3.0
## What the tile it lands on takes, as a fraction of the shell. 1.5 is 150%.
@export var shell_direct: float = 1.5
## What each arm of the cross takes. 1.0 is 100%.
@export var shell_splash: float = 1.0
## Seconds between firing and impact. The whole character of the unit: long
## enough that the shell can be seen coming and walked out from under.
@export var shell_flight: float = 1.6
## How many tiles out each arm of the cross reaches. 1 is a five-tile plus sign.
@export var shell_arm: int = 1
## Damage a second to enemies standing in what it leaves behind, as a fraction of
## the shell, and how long the ground burns for.
@export var field_damage: float = 0.35
@export var field_seconds: float = 5.0

@export_group("Drain")
## Fraction of the victim's MAX health taken every second. Max health, not
## current, so it does not tail off — and deliberately not counting shields, so
## a Warden cannot hide behind one.
@export var drain_percent: float = 0.025

## Added to drain_percent for every tier above the first. Deliberately small.
##
## The drain already grows in absolute terms without any help — it is a share of
## the victim's maximum health, and that doubles per tier — which is why it was
## written flat. What it did not do was get better at its job: a tier 6 Leech took
## the same 2.5% slice as a tier 1, so merging one up bought nothing but a bigger
## body. 0.005 takes it from 2.5% to 5% across the whole ladder, which is a real
## reason to merge and not a second damage curve on top of the first.
@export var drain_percent_per_tier: float = 0.0
@export var drain_interval: float = 1.0

@export_group("Disorient")
## Seconds of disorientation at tier 1, and how much each tier above it adds. A
## disoriented unit wanders and does not swing at anything.
##
## Two numbers rather than one per-tier figure because the ladder has to LAND on its cap
## rather than run past it: 0.5 + 0.3 per tier gives 0.5 / 0.8 / 1.1 / 1.4 / 1.7 / 2.0,
## so a tier 6 is exactly the two seconds the unit was specified to reach and every rung
## below it is worth climbing. A single per-tier figure either overshoots and wastes the
## top of the ladder against the cap, or undershoots and never gets there.
@export var disorient_seconds: float = 0.0
@export var disorient_seconds_per_tier: float = 0.0

## The ceiling on the TIER scaling, and only on that. A buff that lengthens the
## disorientation adds on top of this — the cap describes how far the unit itself gets,
## not how long anything can ever be disoriented for.
@export var disorient_max: float = 2.0

## Seconds a unit cannot be disoriented again for, once it has shaken one off.
##
## Without it two of these lock one target out of the round between them, and the
## counterplay — kill the caster — is not available to a unit that never acts. The
## immunity is the difference between a tempo tool and a disable.
@export var disorient_immunity: float = 5.0

@export_group("Mana aura")
@export var mana_aura_radius: int = 1

@export_group("Frenzy")
## How much damage and attack speed a FULL health bar's worth of missing health
## is worth, as a multiplier on top of 1.0. At 1.0 a unit on its last sliver hits
## roughly twice as hard and twice as fast as it did at full.
##
## This is deliberately linear in MISSING health rather than stepped at
## thresholds: a step means the unit is either enraged or not, which reads as a
## bug the first few times you watch it, while a slope is legible from the health
## bar itself. It is applied to damage and attack speed and nothing else — max
## health would recurse through the number it is computed from, and movement
## would let a wounded unit outrun the line it is supposed to be holding.
@export var rage_per_missing: float = 0.0

## Once below `frenzy_threshold` of its max health, the unit bleeds this fraction
## of its MAX health every second, of its own accord, until it hits zero.
##
## Max health rather than current, so it does not tail off into an asymptote and
## leave the unit alive at 0.4 health forever. This is the cost of the rage above:
## the unit is stronger the closer it is to dead, so something has to walk it
## there whether or not the enemy cooperates.
@export var frenzy_decay: float = 0.0
@export var frenzy_threshold: float = 0.0

## Seconds of death immunity once it reaches zero health: still standing, still
## swinging, with nothing left to lose. A gold pick of the unit's own buff can
## lengthen this — that figure lives on BuffData.frenzy_seconds_at_gold, next to
## the Sentinel's empowered_cap_at_gold, because it is the buff's effect and not
## the unit's.
@export var frenzy_seconds: float = 0.0

## What the window is worth while it is open. Movement is seconds per tile, so
## this is converted rather than multiplied — see UnitInstance.frenzy_bonus.
@export var frenzy_damage: float = 0.0
@export var frenzy_attack_speed: float = 0.0
@export var frenzy_move: float = 0.0

## How many enemies its swings cut through while the window is open. Three, so
## the last few seconds are spent hitting the whole front rank rather than one
## unlucky unit.
@export var frenzy_pierce: int = 1


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
		Kind.FREEZE:
			return "Freezes one enemy for %.1fs per tier. While it is frozen it cannot move, swing or cast, it takes %d%% more damage per tier from everything, and if it dies frozen nothing it would have done on death happens at all." % [
				freeze_seconds_per_tier, roundi(freeze_amp_per_tier * 100.0)]
		Kind.DOT:
			var line := ""
			if dot_current_hp_percent > 0.0:
				line = "Poisons one enemy. The first tick takes %.0f%% of the health it has left, and every %.1fs after that takes %.0f%% of what the last one did, %d ticks in all." % [
					dot_current_hp_percent * 100.0, dot_interval,
					dot_falloff * 100.0, dot_ticks]
			else:
				line = "Poisons one enemy for %d damage every %.1fs, %d times." % [
					roundi(dot_damage), dot_interval, dot_ticks]
			if dot_suppresses:
				line += " While it lasts the target cannot be healed, cannot gain shields, and gains nothing from allies."
			if dot_vulnerability_per_tier > 0.0:
				line += " While poisoned it takes %d%% more damage per tier from everything." % [
					roundi(dot_vulnerability_per_tier * 100.0)]
			return line
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
		Kind.SHELL:
			return "Lobs a shell worth %.0fx its own attack at the thickest cluster it can see. %.0f%% to the tile it lands on, %.0f%% to each arm of the cross, and the ground burns for %.0fs afterwards. It takes %.1fs to arrive." % [
				shell_attack_multiple, shell_direct * 100.0, shell_splash * 100.0,
				field_seconds, shell_flight]
		Kind.DRAIN:
			return "Attaches to the highest-health enemy anywhere on the board and takes %.1f%% of its maximum health every second until it dies. Shields do not count toward that maximum. Several of them stack." % [
				drain_percent * 100.0]
		Kind.SAP:
			return "A charge worth %.0f of its own swings against %d breakable wall(s) within %d tile(s). Scales with tier, so the higher it merges the fewer blows a wall survives." % [
				sap_burst_multiple, terrain_tiles, terrain_reach]
		Kind.BUILD:
			return "Raises %d wall(s) worth %d damage on empty ground within %d tile(s), for the rest of the round. It blocks both sides, and anything can chew through it eventually." % [
				terrain_tiles, roundi(wall_hp), terrain_reach]
		Kind.DISORIENT:
			return "Sends one enemy reeling for %.1fs, and %.1fs longer per tier after the first, up to %.1fs. A disoriented unit wanders where it likes and swings at nothing. Catching one that is already reeling starts its count again from the top — but once it comes out of it, nothing can disorient it for another %.0f seconds." % [
				disorient_seconds, disorient_seconds_per_tier, disorient_max,
				disorient_immunity]
		Kind.FRENZY:
			return "Every point of health it is missing is damage and attack speed: at the brink it hits %d%% harder and that much faster. Below %d%% it starts bleeding %.0f%% of its max health a second and nothing can stop it. At zero it keeps standing for %.1fs — %d%% damage, %d%% attack speed, %d%% faster on its feet, cutting through %d enemies at once — and then it goes." % [
				roundi(rage_per_missing * 100.0), roundi(frenzy_threshold * 100.0),
				frenzy_decay * 100.0, frenzy_seconds,
				roundi(frenzy_damage * 100.0), roundi(frenzy_attack_speed * 100.0),
				roundi(frenzy_move * 100.0), frenzy_pierce]
		Kind.ASCEND:
			return "The first full bar changes it: %.1fx health, %.0f%% faster swings, %.0f%% faster on its feet. Every bar after that arms the next swing to kill outright, whatever it hits." % [
				ascend_hp_mult,
				(ascend_attack_speed_mult - 1.0) * 100.0,
				(1.0 - ascend_move_mult) * 100.0]
	return ""
