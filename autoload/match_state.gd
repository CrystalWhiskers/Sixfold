extends Node

enum Phase { BUFF_PICK, PREP, BATTLE, ROUND_END, MATCH_END }

const WINS_NEEDED := 4
const UNITS_PER_DRAW := 6

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


func buff_pick_due() -> bool:
	return round_index > 1 and round_index % 2 == 0


func buff_pick_number() -> int:
	return round_index / 2


func rarity_odds(pick: int = -1) -> Array:
	return RarityTable.odds_for(buff_pick_number() if pick < 0 else pick)


func rarity_chance(rarity: BuffData.Rarity, pick: int = -1) -> float:
	return RarityTable.chance(rarity, buff_pick_number() if pick < 0 else pick)


func roll_rarity(rng: RandomNumberGenerator) -> BuffData.Rarity:
	return RarityTable.roll(rng, buff_pick_number())


func set_phase(p: Phase) -> void:
	phase = p
	EventBus.phase_changed.emit(p)


func phase_name() -> String:
	return String(Phase.keys()[phase]).capitalize()


func round_seed(salt: int = 0) -> int:
	return match_seed + round_index * 1013 + salt


func record_round(winner: int) -> void:
	if winner >= 0:
		wins[winner] += 1
	EventBus.round_ended.emit(winner, wins)
	if is_match_over():
		set_phase(Phase.MATCH_END)
		EventBus.match_ended.emit(match_winner())
	else:
		set_phase(Phase.ROUND_END)


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
