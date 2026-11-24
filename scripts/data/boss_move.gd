class_name BossMove
extends Resource

## One move in a boss's fixed cycle. Every move is telegraphed: the tiles it will
## hit are marked for `telegraph` seconds, the boss stands still while they are,
## and only then does the blow land — on exactly the tiles that were marked. A
## unit that walks out of the mark in time is not hit; one that walks in is.
##
## The shape is chosen here and sized by `reach` and `span`. Everything is measured
## from the boss's own tile and pointed at its current aim (whatever it is fighting,
## or the crystal it is walking to) — see BossFight.move_cells().

enum Shape {
	## A band of rows across the board, centred on the boss's row: `span` rows tall
	## (1 = its own row), `reach` tiles either side of it.
	ROWS,
	## A band of columns running from the boss towards its aim: `span` columns wide,
	## `reach` tiles long.
	COLUMNS,
	## A single straight line towards its aim, `reach` tiles long, the eight-way
	## direction rounded from the aim. Goes through everything in it.
	THRUST,
	## A dash: the line as THRUST, and the boss ends the move standing at the far end
	## of it — or as far along it as it can stand.
	DASH,
	## A leap onto the thickest knot of enemies within `reach`: the box of radius
	## `span` around it, and the boss lands beside it.
	LEAP,
	## Not a blow but a stance. For `telegraph` seconds the boss plants itself and
	## gathers power, taking `stance_resist` less damage. Deal `break_threshold`
	## damage to it in that time and the charge breaks: it is staggered for
	## `stagger_seconds`, taking `stagger_amp` more. Fail, and it is boosted for
	## `boost_seconds` and unleashes `finisher` at once.
	STANCE,
	# --- Map-wide moves. Each is fair: every tile it will hit is marked first, and
	# it always leaves somewhere safe to stand.
	## A chain of `legs` dashes right across the map, bouncing between its edges. Each
	## leg is marked just before she takes it, and hits everything on its line.
	ONRUSH,
	## Her whole row and her whole column, `span` wide — a cross the length of the map.
	CROSS,
	## A shockwave: every tile between `reach` and `reach + span - 1` tiles out from
	## her. Inside and outside the ring are safe.
	RING,
	## Every other row of the field, then — `telegraph` later — the rows in between.
	## Two beats: where you stand safe for the first is struck by the second.
	STRIPES,
	## `count` single tiles struck at random across the field.
	RAIN,
	## A band of `span` rows the width of the map, centred on the biggest crowd.
	HUNT,
	## Not a blow: she teleports away to the back of the field, calls up
	## `retreat_summons` round her, and heals for `retreat_seconds` — taking
	## `retreat_vulnerability` MORE damage the whole time. Survive it and she comes
	## back permanently stronger (`retreat_attack`, `retreat_speed`, stacking).
	RETREAT,
}

@export var id: StringName = &""
@export var display_name: String = "Move"
@export var shape: Shape = Shape.ROWS
@export var reach: int = 2
@export var span: int = 1

## Damage to everything in the mark, as a multiple of the boss's attack damage.
@export var damage_mult: float = 2.0

## Seconds the mark is up before the blow lands.
@export var telegraph: float = 1.0

## Whether the blow also lands on crystals in the mark. A move aimed at the army
## should not quietly be the thing that breaks the crystal behind it.
@export var hits_crystals: bool = false

## Leave every Nth row of a ROWS band (or column of a COLUMNS band) clear — the
## safe gaps in a field-wide blow. 0 for a solid band.
@export var gap_every: int = 0

## Seconds of charge-up before the mark goes down: she glows and the move's name
## shows, then the tiles are marked, then it lands. For the big moves. 0 for none.
@export var windup: float = 0.0

## ONRUSH: how many map-crossing dashes. RAIN: how many tiles.
@export var legs: int = 6
## ONRUSH: each leg runs straight through the thickest knot of the army, wherever
## it is, and on to the edge of the map, instead of the fixed criss-cross pattern.
@export var seeks_army: bool = false

@export_group("Retreat")
@export var retreat_seconds: float = 8.0
## Her own healing, a share of her full health per second (0.006 = 0.6%). The
## summons that mend her (BossMinion.heal_boss) add to it while they stand.
@export var retreat_heal: float = 0.006
## Extra damage she takes while retreating: 0.5 = 50% more.
@export var retreat_vulnerability: float = 0.5
## What she gains, for the rest of the fight, each time a retreat runs its course.
@export var retreat_attack: float = 0.15
@export var retreat_speed: float = 0.10
@export var retreat_summons: Array[BossMinion] = []
@export var count: int = 24

@export_group("Stance")
@export var stance_resist: float = 0.6
@export var break_threshold: float = 3000.0
@export var stagger_seconds: float = 3.0
@export var stagger_amp: float = 0.5
@export var boost_attack: float = 0.5
@export var boost_speed: float = 0.3
@export var boost_seconds: float = 15.0
@export var finisher: BossMove = null


func describe() -> String:
	var what := ""
	match shape:
		Shape.ROWS:
			what = "%d row%s across, %d tiles each side" % [span, "" if span == 1 else "s", reach]
		Shape.COLUMNS:
			what = "%d column%s, %d tiles deep" % [span, "" if span == 1 else "s", reach]
		Shape.THRUST:
			what = "a straight line %d tiles long" % reach
		Shape.DASH:
			what = "a %d-tile dash that ends where it stops" % reach
		Shape.LEAP:
			what = "a leap onto the biggest crowd within %d, hitting the %dx%d" % [
				reach, span * 2 + 1, span * 2 + 1]
		Shape.ONRUSH:
			what = "%d dashes right across the map, each marked before it lands" % legs
		Shape.CROSS:
			what = "her whole row and column, %d wide" % span
		Shape.RING:
			what = "a shockwave ring %d to %d tiles out" % [reach, reach + span - 1]
		Shape.STRIPES:
			what = "every other row, then the rows between, in two beats"
		Shape.RAIN:
			what = "%d tiles struck at random" % count
		Shape.HUNT:
			what = "a %d-row sweep the width of the map, centred on the biggest crowd" % span
		Shape.STANCE:
			return "%s — a %.0fs charge at %d%% less damage; break it with %.0f damage or it unleashes %s" % [
				display_name, telegraph, roundi(stance_resist * 100.0), break_threshold,
				finisher.display_name if finisher != null else "nothing"]
	return "%s — %s, %.1fx attack, %.1fs warning" % [display_name, what, damage_mult, telegraph]
