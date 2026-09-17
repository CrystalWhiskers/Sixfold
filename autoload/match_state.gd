extends Node

enum Phase { BUFF_PICK, PREP, BATTLE, ROUND_END, MATCH_END }

## The conventional match. A custom match overrides it — see GameSetup.wins_needed()
## — so everything below asks for the number rather than reading this const, and this
## stays the one place the conventional value is written down.
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


func wins_to_win() -> int:
	## How many rounds a side has to lose before the match is over. The conventional
	## four unless a custom match says otherwise.
	return GameSetup.wins_needed()


func buff_pick_due() -> bool:
	# Every `buff_every` rounds, and never on the first — the opening round is played
	# with the units you drew and nothing else.
	var every := GameSetup.buff_every()
	return round_index > 1 and round_index % every == 0


func buff_pick_number() -> int:
	# Which pick this is, counted from one. Drives the rarity odds, so it has to
	# advance with the cadence rather than with the round.
	return round_index / GameSetup.buff_every()


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
	else:
		# A drawn round costs BOTH sides a life. A life is spent by giving the
		# other player a win, so a draw gives one to each — which keeps the
		# scoreline honest and means a timeout neither side won is never a free
		# round for the player who was losing on the board.
		wins[0] += 1
		wins[1] += 1
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
	var need := wins_to_win()
	return wins[0] >= need or wins[1] >= need


func match_winner() -> int:
	# Both can cross the line at once now, because a drawn round advances both
	# scores. Whoever is ahead takes it; dead level is a drawn match, and -1 is
	# what the rest of the game already reads as "nobody".
	var need := wins_to_win()
	var over_a := wins[0] >= need
	var over_b := wins[1] >= need
	if over_a and over_b:
		return -1 if wins[0] == wins[1] else (0 if wins[0] > wins[1] else 1)
	if over_a:
		return 0
	if over_b:
		return 1
	return -1


func lives_left(team: int) -> int:
	return wins_to_win() - wins[1 - team]
