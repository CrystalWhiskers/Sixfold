class_name BossData
extends Resource

## A boss for the defence mode, end to end: its body, its phases and their moves,
## the crystals it is after and the rules of the fight. Everything a designer would
## want to retune lives here — reorder `phases[i].moves` to change the cycle.

@export var id: StringName = &""
@export var display_name: String = "Boss"
@export var title: String = ""
@export_multiline var note: String = ""

@export_group("Body")
@export var max_hp: float = 10000.0
@export var attack_damage: float = 40.0
@export var attack_speed: float = 0.8
## Seconds per tile, like UnitData.move_time.
@export var move_time: float = 0.9
@export var accent: Color = Color(0.78, 0.16, 0.16)

## Percentage-of-health effects (Rupture, the Leech's drain, the Vexer's poison, a
## lone unit's last stand) treat the boss as if this were its health. Without a cap
## a 2% rider would be worth as much as an army.
@export var percent_cap: float = 1500.0

## Freezes and stuns last this share as long on it.
@export var hold_scale: float = 0.5

@export_group("Phases")
@export var phases: Array[BossPhase] = []

@export_group("Crystals")
## Lane order the boss goes for them in: 0 = left, 1 = middle, 2 = right.
@export var crystal_order: PackedInt32Array = PackedInt32Array([0, 1, 2])
@export var lane_crystal_hp: float = 4000.0
@export var central_crystal_hp: float = 6000.0
## A broken zone crystal rebuilds itself after this long, at this share of its health.
## While it is down, its section's waves go to the Central Crystal instead.
@export var crystal_rebuild_seconds: float = 45.0
@export var crystal_rebuild_fraction: float = 0.5

@export_group("Economy")
## Supply: the Barracks' currency. It ticks up every second of the fight, and the
## player spends it on recruits, unit upgrades and more income.
@export var start_supply: float = 20.0
@export var base_income: float = 2.0
## Each income upgrade adds this much Supply per second, and costs `income_cost`
## times `income_growth` to the power of how many have been bought already.
@export var income_step: float = 1.0
@export var income_cost: float = 30.0
@export var income_growth: float = 1.6
## A recruit: one random draw from the player's loadout, at tier 1, into a section.
## The first costs `recruit_cost`; each after it costs `recruit_step` more (10, 12, 14...).
## `recruit_growth` can make it climb by a multiple instead (1 = flat steps only).
@export var recruit_cost: float = 10.0
@export var recruit_step: float = 2.0
@export var recruit_growth: float = 1.0
## Unit upgrades, per unit TYPE: what each level does to that unit's own ability
## lives in `upgrades`; these are the price of each level (index 0 buys Lv1) and the
## small stat bump every level adds on top.
@export var upgrades: BossUpgrades = null
@export var upgrade_costs: PackedFloat32Array = PackedFloat32Array([30, 50, 80, 120, 180])
@export var upgrade_stat_per_level: float = 0.08

@export_group("Summons")
## The boss's adds: one original minion shape, scaled per phase by the phase's
## `minion_power`. At most `minion_cap` of them on the field at once.
@export var minion_name: String = "Crimson Shade"
@export var minion_hp: float = 300.0
@export var minion_attack: float = 25.0
@export var minion_attack_speed: float = 1.0
@export var minion_move_time: float = 0.8
@export var minion_cap: int = 8
## A shade arrives with a blast: this many of its own hits to every one of the army
## standing within `minion_burst_radius` tiles of the circle. 0 for a quiet arrival.
@export var minion_burst_mult: float = 0.0
@export var minion_burst_radius: int = 1
## While shades stand, the boss takes this much less damage per shade (0.06 = 6%),
## so leaving them alive is a choice with a cost.
@export var minion_ward_per_shade: float = 0.0
## Seconds a summoning circle is marked on the ground before the minion steps out.
@export var summon_warning: float = 1.0
## Free tier-1 draws handed out across the sections before the fight.
@export var start_draws: int = 6
## Each section is a grid this big — the most one wave from it can be.
@export var section_cols: int = 3
@export var section_rows: int = 4
## The most of one zone's army that may be on the field at once. The rest of a
## wave waits, up to one section's worth, and drops in as space opens.
@export var zone_cap: int = 20

@export_group("Rules")
## Seconds between reinforcement waves.
@export var wave_seconds: float = 20.0
## The boss takes the field if nobody has won by then. 0 for no time limit: the
## fight is decided by her falling or the Central Crystal falling, and the enrage
## below is what stops it dragging on for ever.
@export var time_limit: float = 0.0
## Enrage: from `enrage_after` seconds she surges every `enrage_every` seconds, each
## surge adding `enrage_attack` to her attack, `enrage_speed` to her attack speed and
## `enrage_minions` to the power of everything she summons — stacking, without end.
@export var enrage_after: float = 300.0
@export var enrage_every: float = 30.0
@export var enrage_attack: float = 0.15
@export var enrage_speed: float = 0.08
@export var enrage_minions: float = 0.10


func phase_for(hp_fraction: float, central: bool) -> int:
	## The latest phase whose condition holds. Phases only move forward — the caller
	## keeps the highest it has reached — so healing back above a line does not
	## walk the boss back into an earlier one.
	var at := 0
	for i in phases.size():
		var p := phases[i]
		if hp_fraction <= p.hp_threshold or (central and p.on_central):
			at = i
	return at
