## Wires the prep phase and the battle together into a playable round loop.
##
## This is the only script that knows about both the model and the screen. It
## holds no rules of its own — every legality question goes to BoardModel, and
## every combat question is already answered by the time playback starts.
##
## Interaction: click a bench card to pick it up, then click a tile to place it.
## On the board, drag a unit to move it, drop it on a twin to merge, or drop it
## on a different unit to swap.
extends Node2D

const LOADOUT_PATH := "res://data/loadouts/starter.tres"
const PLAYER_TEAM := BoardModel.TEAM_B
const AI_TEAM := BoardModel.TEAM_A

@onready var _board_view: BoardView = $BoardView
@onready var _hud: Label = $UI/Root/Hud
@onready var _status: Label = $UI/Root/Status
@onready var _bench_row: HBoxContainer = $UI/Root/Bench
@onready var _fight_btn: Button = $UI/Root/Buttons/Fight
@onready var _speed_btn: Button = $UI/Root/Buttons/Speed

var board := BoardModel.new()
var loadout: LoadoutData
var player_bench: Array[UnitInstance] = []
var _selected := -1
var _player_rng := RandomNumberGenerator.new()
var _ai_rng := RandomNumberGenerator.new()
## The full pre-battle roster: [{unit, cell}, ...]. Everyone on it is restored
## afterwards, dead included.
var _roster: Array[Dictionary] = []
var _player: BattlePlayer
var _speeds: Array[float] = [1.0, 2.0, 4.0]
var _speed_idx := 1


func _ready() -> void:
	loadout = load(LOADOUT_PATH) as LoadoutData
	if loadout == null or not loadout.is_valid():
		_status.text = "Missing or invalid loadout. Run tools/generate_data.gd first."
		return

	_player = BattlePlayer.new()
	add_child(_player)
	_player.finished.connect(_on_playback_finished)

	_board_view.player_team = PLAYER_TEAM
	_board_view.bind(board)
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
	_selected = -1

	# New units each round, on top of whatever survived. The board filling up is
	# the pressure that makes merging worth the loss of bodies.
	var drawn := loadout.draw(_player_rng, MatchState.UNITS_PER_DRAW)
	player_bench.clear()
	for d in drawn:
		player_bench.append(UnitInstance.create(d, PLAYER_TEAM))

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
	_rebuild_bench()
	_refresh_hud()
	if board.free_deploy_cells(PLAYER_TEAM).is_empty():
		_status.text = "Your half is full — merge to make room."
	else:
		_status.text = "Place your 5 units, then Fight. Their half is hidden."


## Stand-in opponent so there's something to play against. Replace this with a
## real second player or a proper AI once you've decided PvP vs PvE.
func _deploy_ai() -> void:
	var drawn := loadout.draw(_ai_rng, MatchState.UNITS_PER_DRAW)
	for d in drawn:
		var free := board.free_deploy_cells(AI_TEAM)
		if free.is_empty():
			break
		var u := UnitInstance.create(d, AI_TEAM)
		# Try a merge first, so the AI board escalates the way a player's would.
		var merged := false
		for other in board.units_of(AI_TEAM):
			if other.data == d and not d.is_max_tier():
				board.merge(other, u, other.cell)
				merged = true
				break
		if not merged:
			board.place(u, free[_ai_rng.randi_range(0, free.size() - 1)])


func _rebuild_bench() -> void:
	for c in _bench_row.get_children():
		c.queue_free()
	for i in player_bench.size():
		var u := player_bench[i]
		var b := Button.new()
		b.custom_minimum_size = Vector2(112, 66)
		b.text = "%s\n%d hp / %d dmg" % [
			u.data.display_name,
			roundi(u.stat(StatModifier.Stat.MAX_HP)),
			roundi(u.stat(StatModifier.Stat.ATTACK_DAMAGE)),
		]
		b.add_theme_font_size_override("font_size", 13)
		b.modulate = u.data.accent.lightened(0.25) if i != _selected else Color.WHITE
		b.toggle_mode = false
		b.pressed.connect(_on_bench_pressed.bind(i))
		_bench_row.add_child(b)


func _on_bench_pressed(idx: int) -> void:
	if MatchState.phase != MatchState.Phase.PREP:
		return
	_selected = -1 if _selected == idx else idx
	_rebuild_bench()
	if _selected >= 0:
		_status.text = "Placing %s — click a highlighted tile." % player_bench[_selected].data.display_name
	else:
		_status.text = "Place your units, then Fight."


func _on_cell_pressed(cell: Vector2i) -> void:
	if MatchState.phase != MatchState.Phase.PREP or _selected < 0:
		return
	var u := player_bench[_selected]
	var occupant := board.unit_at(cell)

	if occupant != null:
		if board.can_merge(occupant, u):
			board.merge(occupant, u, cell)
			player_bench.remove_at(_selected)
			_selected = -1
			_after_board_change("Merged — rolled %s." % board.unit_at(cell).data.display_name)
		else:
			_status.text = "That tile is taken."
		return

	if not board.can_deploy(PLAYER_TEAM, cell):
		_status.text = "You can only deploy in your own half — not the middle row."
		return

	board.place(u, cell)
	player_bench.remove_at(_selected)
	_selected = -1
	_after_board_change("Placed.")


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
	_rebuild_bench()
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

	_selected = -1
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


func _unhandled_key_input(event: InputEvent) -> void:
	# Handy while testing: dump the board to the Output panel and trust it over
	# the screen. If the two disagree, the screen is the one that's wrong.
	if event is InputEventKey and event.pressed and event.keycode == KEY_F1:
		print(board.to_ascii())
