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
@export var crystal_rebuild_seconds: float = 90.0
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
## The most income upgrades that can be bought. 0 for no limit.
@export var income_max_level: int = 0
## Each income upgrade gives `income_step_growth` times what the last one gave: +2,
## +3, +4.5, +6.75... Its price climbs faster (income_growth), so every next one is
## still worth less per Supply spent. 1 for a flat `income_step` every time.
@export var income_step_growth: float = 1.5
## Or a quadratic climb: the n-th upgrade (from 0) gives `income_step` times
## (1 + `income_step_quad` x n squared) — +2, +3, +6, +11, +18, +27... at 0.5. It still
## falls behind the price, which climbs exponentially. 0 to leave it off.
@export var income_step_quad: float = 0.0
## Passive growth: every `passive_income_every` seconds of the fight, income rises by
## `passive_income` on its own, with nothing bought — so the longer you hold, the more
## you have to answer her enrage with. 0 for none.
@export var passive_income: float = 1.0
@export var passive_income_every: float = 30.0
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
## Exponential upgrades. With `upgrade_cost_growth` above 0 a level costs
## `upgrade_cost_base` times it to the power of the level already held, up to
## `upgrade_max_level` (the ability table tops out at Lv5; past it the stat growth
## carries on), and `upgrade_costs` is not used. With `upgrade_stat_growth` above 0
## every level multiplies health and attack by it instead of adding
## `upgrade_stat_per_level`.
@export var upgrade_cost_base: float = 30.0
@export var upgrade_cost_growth: float = 0.0
@export var upgrade_max_level: int = 5
@export var upgrade_stat_growth: float = 0.0

@export_group("Summons")
## The boss's adds: one original minion shape, scaled per phase by the phase's
## `minion_power`. At most `minion_cap` of them on the field at once.
@export var minion_name: String = "Crimson Shade"
@export var minion_hp: float = 300.0
@export var minion_attack: float = 25.0
@export var minion_attack_speed: float = 1.0
@export var minion_move_time: float = 0.8
@export var minion_cap: int = 8
## What her ordinary summoning waves call, taken in turn (shades when empty), and the
## tier they come out at by phase: phase 1 at `minion_base_tier`, one higher each
## phase after, and one more for every two enrage surges — up to tier 6.
@export var summon_pool: Array[BossMinion] = []
@export var minion_base_tier: int = 1
## Fodder: every `swarm_every` seconds she calls `swarm_count` of `swarm_kind` at once —
## weak bodies in a crowd, to soak blows and clog the field. Not held to the ordinary
## cap. 0 seconds for none.
@export var swarm_kind: BossMinion = null
@export var swarm_every: float = 0.0
@export var swarm_count: int = 12
## Flankers: every `flank_every` seconds, `flank_count` (plus one per phase) of
## `flank_kind` step in at the edge of the arena nearest the army's ranged units,
## and go for them. 0 seconds for none.
@export var flank_kind: BossMinion = null
@export var flank_every: float = 0.0
@export var flank_count: int = 2
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
## Toughness. No single blow takes more than `max_hit_percent` of her full health
## (0 for no cap); ranged hits are cut by `ranged_resist` (0.3 = 30% less); and every
## one of the army that dies makes her `death_power` stronger (attack, for good).
@export var max_hit_percent: float = 0.0
@export var ranged_resist: float = 0.0
## Long-range units get through even less: `long_range_resist` instead, for anything
## whose reach is `long_range_tiles` or more.
@export var long_range_resist: float = 0.0
@export var long_range_tiles: int = 4
@export var death_power: float = 0.0
## What she does when the army crowds her: with `surround_count` or more of it within
## two tiles, her next move is `surround_move` (a big one, with a wind-up), at most
## once every `surround_cooldown` seconds.
@export var surround_move: BossMove = null
@export var surround_count: int = 6
@export var surround_cooldown: float = 10.0
## A big move (one with a wind-up) that sweeps over a crystal standing in the way
## hurts it by this share of the blow. Only by accident: she never aims at them.
@export var crystal_share: float = 0.5
## And never more than this from any one such blow. 0 for no cap.
@export var crystal_big_cap: float = 0.0
## Her own blow on the crystal she is after deals exactly this, however strong she has
## grown — her damage to the army can climb as high as it likes without the crystals
## melting. 0 to let it scale with her attack.
@export var crystal_hit_damage: float = 0.0


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
