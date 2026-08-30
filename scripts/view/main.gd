## Wires the prep phase and the battle together into a playable round loop.
##
## This is the only script that knows about both the model and the screen. It
## holds no rules of its own — every legality question goes to BoardModel, and
## every combat question is already answered by the time playback starts.
##
## Interaction: your units arrive on the board already. Drag one to move it, drop
## it on a twin to merge, or on another of yours to swap.
extends Node2D

const LOADOUT_PATH := "res://data/loadouts/starter.tres"
const PLAYER_TEAM := BoardModel.TEAM_B
const AI_TEAM := BoardModel.TEAM_A

@onready var _board_view: BoardView = $BoardView
@onready var _hud: Label = $UI/Root/Hud
@onready var _status: Label = $UI/Root/Status
@onready var _fight_btn: Button = $UI/Root/Buttons/Fight
@onready var _speed_btn: Button = $UI/Root/Buttons/Speed

var board := BoardModel.new()
var loadout: LoadoutData
var _player_rng := RandomNumberGenerator.new()
var _ai_rng := RandomNumberGenerator.new()
## The full pre-battle roster: [{unit, cell}, ...]. Everyone on it is restored
## afterwards, dead included.
var _roster: Array[Dictionary] = []
var _player: BattlePlayer
var _speeds: Array[float] = [1.0, 2.0, 4.0]
var _speed_idx := 1


func _ready() -> void:
	# Bind the view FIRST. Every early return below leaves the board unbound
	# otherwise, and BoardView._draw() then throws on every single frame — which
	# buries the one message that actually explains what went wrong.
	_board_view.player_team = PLAYER_TEAM
	_board_view.bind(board)

	# Say WHICH way it failed. "Missing or invalid" covers three very different
	# problems with three different fixes, and guessing between them wastes time.
	var raw := load(LOADOUT_PATH)
	if raw == null:
		_fail("Can't load %s at all — the file is missing, or its script failed to bind."
			% LOADOUT_PATH)
		return
	if not (raw is LoadoutData):
		_fail("%s loaded as %s, not a LoadoutData. Your .godot cache is probably stale: close Godot, delete the .godot folder, reopen."
			% [LOADOUT_PATH, raw.get_class()])
		return
	loadout = raw as LoadoutData
	if not loadout.is_valid():
		_fail("Loadout at %s is empty or has a null unit in it. Regenerate with tools/generate_data.gd."
			% LOADOUT_PATH)
		return

	_player = BattlePlayer.new()
	add_child(_player)
	_player.finished.connect(_on_playback_finished)
	_board_view.cell_pressed.connect(_on_cell_pressed)
	_board_view.drag_dropped.connect(_on_drag_dropped)

	_fight_btn.pressed.connect(_on_fight_pressed)
	_speed_btn.pressed.connect(_cycle_speed)
	_update_speed_label()

	var seed_value := int(Time.get_unix_time_from_system())
	# Merging is a lottery: two identical units produce a RANDOM type one tier up.
	# Two Wardens can hand you an Archer II.
	board.configure_merges(loadout.units, seed_value + 4242)
	MatchState.start_match(seed_value, [loadout, loadout] as Array[LoadoutData])
	_player_rng.seed = seed_value
	_ai_rng.seed = seed_value + 9001
	_begin_prep()


# ---------------------------------------------------------------- prep phase

func _begin_prep() -> void:
	MatchState.set_phase(MatchState.Phase.PREP)

	# New units each round, summoned straight onto the board. The board filling
	# up is the pressure that makes merging worth the loss of bodies.
	var summoned := _summon(PLAYER_TEAM, _player_rng)

	_deploy_ai()
	# Fog goes up for prep and comes down when the fight starts. You commit to an
	# arrangement without seeing theirs; after that everything is visible.
	#
	# Worth knowing: at the end of every round you saw their whole board, so from
	# round 2 on the fog only conceals what they CHANGED — their new draw and any
	# merges. The intel decays on its own, which is a nicer pressure than a
	# blackout would be.
	_board_view.set_fog(true)
	_board_view.interactive = true
	_board_view.sync_positions()
	_refresh_hud()
	_report_summon(summoned)


## Drops this round's draw onto free tiles in `team`'s half, at random.
##
## Returns how many actually landed. A full half takes fewer than it drew, and
## the difference is the player's problem to solve by merging — see
## _report_summon().
func _summon(team: int, rng: RandomNumberGenerator) -> int:
	var drawn := loadout.draw(rng, MatchState.UNITS_PER_DRAW)
	var placed := 0
	for d in drawn:
		var free := board.free_deploy_cells(team)
		if free.is_empty():
			break
		var cell: Vector2i = free[rng.randi_range(0, free.size() - 1)]
		if board.place(UnitInstance.create(d, team), cell):
			placed += 1
	return placed


## Units that couldn't fit are LOST, not held over. Saying so plainly matters —
## silently dropping them would read as a bug, and the whole point of the
## pressure is that you feel it.
func _report_summon(placed: int) -> void:
	var wanted := MatchState.UNITS_PER_DRAW
	if placed == wanted:
		_status.text = "%d units arrived. Arrange them, then Fight." % placed
	elif placed > 0:
		_status.text = "Only %d of %d fit — the rest were lost. Merge to make room." % [
			placed, wanted]
	else:
		_status.text = "Your half is full, so this round's draw was lost entirely. Merge."


## Stand-in opponent so there's something to play against. Replace this with a
## real second player or a proper AI once you've decided PvP vs PvE.
func _deploy_ai() -> void:
	_summon(AI_TEAM, _ai_rng)
	# Then merge opportunistically, so the AI board escalates the way yours would.
	for i in MatchState.UNITS_PER_DRAW:
		if not _ai_merge_once():
			break


## Merges the first matching pair it finds. Returns false when none is left.
func _ai_merge_once() -> bool:
	var mine := board.units_of(AI_TEAM)
	for a in mine:
		for b in mine:
			if board.can_merge(a, b):
				board.merge(a, b, b.cell)
				return true
	return false


## Nothing is placed by clicking any more — units arrive on the board and are
## rearranged by dragging. A tap just reads out what's on the tile.
func _on_cell_pressed(cell: Vector2i) -> void:
	if MatchState.phase != MatchState.Phase.PREP:
		return
	var u := board.unit_at(cell)
	if u == null or u.team != PLAYER_TEAM:
		return
	_status.text = "%s — %d hp, %d damage. Drag onto a twin to merge." % [
		u.data.display_name,
		roundi(u.stat(StatModifier.Stat.MAX_HP)),
		roundi(u.stat(StatModifier.Stat.ATTACK_DAMAGE)),
	]


func _on_drag_dropped(from: Vector2i, to: Vector2i) -> void:
	if MatchState.phase != MatchState.Phase.PREP:
		_board_view.sync_positions()
		return
	var mover := board.unit_at(from)
	var target := board.unit_at(to)
	if mover == null or mover.team != PLAYER_TEAM:
		_board_view.sync_positions()
		return

	if target == null:
		if board.can_deploy(PLAYER_TEAM, to):
			board.move_unit(mover, to)
			_after_board_change("Moved.")
		else:
			_after_board_change("You can't deploy there.")
		return

	if board.can_merge(mover, target):
		board.merge(mover, target, to)
		_after_board_change("Merged — rolled %s." % board.unit_at(to).data.display_name)
	elif target.team == PLAYER_TEAM:
		board.swap_cells(from, to)
		_after_board_change("Swapped.")
	else:
		_after_board_change("That's not your unit.")


func _after_board_change(message: String) -> void:
	_board_view.rebuild()
	_refresh_hud()
	_status.text = message


# ---------------------------------------------------------------- battle

func _on_fight_pressed() -> void:
	match MatchState.phase:
		MatchState.Phase.PREP:
			_start_battle()
		MatchState.Phase.ROUND_END, MatchState.Phase.BUFF_PICK:
			_next_round()
		MatchState.Phase.MATCH_END:
			get_tree().reload_current_scene()
		_:
			pass


func _next_round() -> void:
	MatchState.advance_round()
	if MatchState.phase == MatchState.Phase.BUFF_PICK:
		# Milestone 15 lands here: offer three weighted picks from res://data/buffs
		# and call apply_modifiers() on the chosen unit or the whole roster.
		# Until then the phase is real but passes straight through.
		_status.text = "A buff pick is due this round — not built yet, skipping."
	_begin_prep()


func _start_battle() -> void:
	if board.living_units_of(PLAYER_TEAM).is_empty():
		_status.text = "Place at least one unit first."
		return

	_board_view.interactive = false
	MatchState.set_phase(MatchState.Phase.BATTLE)
	_fight_btn.disabled = true

	# Everyone who is about to fight, and where they stood. The whole roster comes
	# back after the battle — see _restore_roster().
	_roster.clear()
	for u in board.all_units():
		_roster.append({unit = u, cell = u.cell})

	_last_sim = CombatSim.new()
	_last_sim.setup(board, MatchState.round_seed())
	EventBus.battle_started.emit(MatchState.round_seed())

	# Order matters here. setup() has reset everyone but killed nobody, so the
	# board still holds the FULL starting roster — build the views now.
	#
	# Rebuilding after run() instead would only ever create views for the
	# survivors, and every unit that died would simply never appear. The reveal
	# is also the moment the fog comes down.
	_board_view.set_fog(false)
	_board_view.rebuild()
	_board_view.flash_cells(board.deploy_cells(AI_TEAM),
		Color(0.55, 0.68, 0.80, 0.45), 0.55)

	_pending_winner = _last_sim.run()
	_pending_duration = _last_sim.duration()
	_player.speed = _speeds[_speed_idx]
	_player.play(_board_view, _last_sim.events)
	_refresh_hud()
	_status.text = "Fighting..."


## Held for the whole of playback: it owns the UnitInstances of the fallen,
## which the event log still refers to after the board has dropped them.
var _last_sim: CombatSim = null
var _pending_winner := CombatSim.RESULT_DRAW
var _pending_duration := 0.0


func _on_playback_finished(_winner: int) -> void:
	_restore_roster()
	EventBus.battle_finished.emit(_pending_winner, _pending_duration)

	var label := "Draw."
	if _pending_winner == PLAYER_TEAM:
		label = "You won the round."
	elif _pending_winner == AI_TEAM:
		label = "You lost the round."
	MatchState.record_round(_pending_winner)

	_board_view.rebuild()
	_refresh_hud()
	_fight_btn.disabled = false

	if MatchState.is_match_over():
		var champ := "You win the match." if MatchState.match_winner() == PLAYER_TEAM else "You lose the match."
		_status.text = "%s %s Click Restart." % [label, champ]
		_fight_btn.text = "Restart"
		MatchState.set_phase(MatchState.Phase.MATCH_END)
	else:
		_status.text = "%s Click Next Round." % label
		_fight_btn.text = "Next Round"


## Restores the ENTIRE pre-battle roster — the fallen included — healed and back
## on their own tiles.
##
## Losing a round therefore costs a life and nothing else. Letting the dead stay
## dead compounds: the side that loses round one fields fewer units in round two,
## loses harder, and the match is decided long before anyone runs out of lives.
## Every round now starts as a fresh test of the arrangement.
func _restore_roster() -> void:
	board.clear()
	for entry in _roster:
		var u: UnitInstance = entry.unit
		u.state = UnitInstance.State.IDLE
		u.state_timer = 0.0
		u.target = null
		u.heal_to_full()
		var home: Vector2i = entry.cell
		if board.in_bounds(home) and board.is_empty(home):
			board.force_place(u, home)
		else:
			var free := board.free_deploy_cells(u.team)
			if not free.is_empty():
				board.force_place(u, free[0])


# ---------------------------------------------------------------- chrome

func _cycle_speed() -> void:
	_speed_idx = (_speed_idx + 1) % _speeds.size()
	_player.speed = _speeds[_speed_idx]
	_update_speed_label()


func _update_speed_label() -> void:
	_speed_btn.text = "Speed x%d" % int(_speeds[_speed_idx])


func _refresh_hud() -> void:
	var you: int = MatchState.wins[PLAYER_TEAM]
	var them: int = MatchState.wins[AI_TEAM]
	# The enemy count is the one thing the fog is allowed to leak, and only when
	# FOG_SHOWS_COUNT says so. Everything else about their half stays unknown.
	var theirs := "?"
	if not _board_view.fog or BoardView.FOG_SHOWS_COUNT:
		theirs = str(board.living_units_of(AI_TEAM).size())
	_hud.text = "Round %d  ·  %s  ·  You %d – %d Opponent  ·  board %d v %s" % [
		MatchState.round_index, MatchState.phase_name(), you, them,
		board.living_units_of(PLAYER_TEAM).size(), theirs,
	]
	if MatchState.phase == MatchState.Phase.PREP:
		_fight_btn.text = "Fight"


## One place for setup failures: on screen where you'll see it, and in the
## Output panel where you can copy it.
func _fail(message: String) -> void:
	_status.text = message
	push_error(message)


func _unhandled_key_input(event: InputEvent) -> void:
	# Handy while testing: dump the board to the Output panel and trust it over
	# the screen. If the two disagree, the screen is the one that's wrong.
	if event is InputEventKey and event.pressed and event.keycode == KEY_F1:
		print(board.to_ascii())
