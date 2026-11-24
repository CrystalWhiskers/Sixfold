class_name BossMinion
extends Resource

## One kind of thing a boss can summon, beyond her ordinary shades: the summons she
## calls during a Retreat. Every one is scaled by the phase's `minion_power`.
##
## `id` also picks the minion's icon on the board (UnitView._draw_minion), so a new
## kind wants a drawing there too — without one it falls back to letters.

@export var id: StringName = &""
@export var display_name: String = "Minion"
@export var max_hp: float = 300.0
@export var attack_damage: float = 25.0
@export var attack_speed: float = 1.0
@export var move_time: float = 0.8
@export_range(1, 7) var attack_range: int = 1
@export var ranged: bool = false
@export var can_move: bool = true
@export var can_attack: bool = true
## While it stands, it mends the boss by this share of her full health every second
## (0.003 = 0.3%) — never past the top of her current health bar.
@export var heal_boss: float = 0.0
## Hits everything of the army beside its circle as it arrives, this many of its own
## blows. 0 for none.
@export var burst_mult: float = 0.0
## Who it hunts. NEAREST: whatever of the army is closest (the default). TOP_TIER:
## the highest-tier unit on the field, wherever it is — a Headhunter. CROWD: the
## thickest knot of the army — a Berserker, whose swings land on everything round
## its target (`cleave_radius`).
enum Targeting { NEAREST, TOP_TIER, CROWD }
@export var targeting: Targeting = Targeting.NEAREST
@export var cleave_radius: int = 0
## Whether what it kills stays dead — no second wind, no raise. Only a few have it
## (the Headhunter); her ordinary summons kill the ordinary way.
@export var soul_taker: bool = false
@export var accent: Color = Color(0.85, 0.25, 0.30)
