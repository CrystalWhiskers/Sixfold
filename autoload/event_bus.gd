## Decoupled signals, so the view can react to game events without the model
## holding references to nodes.
##
## Rule of thumb: if a layer wants to reach *down* the stack, it calls a method.
## If it wants to reach *up*, it emits here.
extends Node

## Prep phase
signal draw_offered(units: Array)
signal unit_placed(uid: int, cell: Vector2i)
signal unit_merged(uid: int, tier: int, cell: Vector2i)
signal placement_rejected(reason: String)

## Battle
signal battle_started(seed_value: int)
signal battle_event(event: Dictionary)
signal battle_finished(winner: int, duration: float)

## Match flow
signal phase_changed(phase: int)
signal round_started(round_index: int)
signal round_ended(winner: int, wins: Array)
signal match_ended(winner: int)
