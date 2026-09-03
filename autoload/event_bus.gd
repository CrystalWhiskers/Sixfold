extends Node

signal draw_offered(units: Array)
signal unit_placed(uid: int, cell: Vector2i)
signal unit_merged(uid: int, tier: int, cell: Vector2i)
signal placement_rejected(reason: String)

signal battle_started(seed_value: int)
signal battle_event(event: Dictionary)
signal battle_finished(winner: int, duration: float)

signal phase_changed(phase: int)
signal round_started(round_index: int)
signal round_ended(winner: int, wins: Array)
signal match_ended(winner: int)
