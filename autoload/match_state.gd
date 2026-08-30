## Round counter, lives, and the phase machine.
##
## Order per round is BUFF_PICK (when due) -> PREP -> BATTLE -> ROUND_END.
## First side to WINS_NEEDED round wins takes the match.
extends Node

enum Phase { BUFF_PICK, PREP, BATTLE, ROUND_END, MATCH_END }

const WINS_NEEDED := 4      ## Each player effectively has 4 lives.
## How many units you are dealt at the start of each prep phase.
##
## This is the knob for pace: it sets how fast your board fills and therefore how
## quickly you can reach the higher merge tiers. Raising it does NOT change how
## many unit TYPES exist — that's the roster in tools/generate_data.gd.
const UNITS_PER_DRAW := 5

var round_index := 1
var wins: Array[int] = [0, 0]
var phase: Phase = Phase.PREP
var match_seed := 0
var loadouts: Array[LoadoutData] = []

var _rng := RandomNumberGenerator.new()


func start_match(p_seed: int, p_loadouts: Array[LoadoutData]) -> void:
	match_seed = p_seed
	loadouts = p_loadouts
	round_index = 1
	wins = [0, 0]
	_rng.seed = p_seed
	set_phase(Phase.PREP)
	EventBus.round_started.emit(round_index)


## Buff picks open rounds 2, 4, 6, 8 — i.e. after rounds 1, 3, 5.
## This is the cadence knob you'll turn most while playtesting; it lives here
## and nowhere else on purpose.
func buff_pick_due() -> bool:
	return round_index > 1 and round_index % 2 == 0


func set_phase(p: Phase) -> void:
	phase = p
	EventBus.phase_changed.emit(p)


func phase_name() -> String:
	return String(Phase.keys()[phase]).capitalize()


## Per-round seed, derived from the match seed. Keeps every round reproducible
## while still differing from each other.
func round_seed(salt: int = 0) -> int:
	return match_seed + round_index * 1013 + salt


## Banks the result and STOPS at ROUND_END.
##
## Deliberately does not roll straight into the next round: the player has to be
## able to see who won before anything moves. advance_round() is the separate
## step the "Next Round" button drives.
func record_round(winner: int) -> void:
	if winner >= 0:
		wins[winner] += 1
	EventBus.round_ended.emit(winner, wins)
	if is_match_over():
		set_phase(Phase.MATCH_END)
		EventBus.match_ended.emit(match_winner())
	else:
		set_phase(Phase.ROUND_END)


## Moves on to the next round. Opens with a buff pick when one is due.
func advance_round() -> void:
	if is_match_over():
		return
	round_index += 1
	set_phase(Phase.BUFF_PICK if buff_pick_due() else Phase.PREP)
	EventBus.round_started.emit(round_index)


func is_match_over() -> bool:
	return wins[0] >= WINS_NEEDED or wins[1] >= WINS_NEEDED


func match_winner() -> int:
	if wins[0] >= WINS_NEEDED:
		return 0
	if wins[1] >= WINS_NEEDED:
		return 1
	return -1


func lives_left(team: int) -> int:
	return WINS_NEEDED - wins[1 - team]
