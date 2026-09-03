extends Node

const ROUNDS := 4
const MAX_FRAMES := 40000

var _main: Node2D
var _frames := 0
var _rounds_played := 0
var _failed := 0
var _passed := 0
var _done := false
var _prep_seen: Array[int] = []
var _handovers := 0
var _blind_checked := false
var _picks_by_team := {}
var _turn_frames := 0
var _hud_overflow := ""
var _status_overflow := ""


func _ready() -> void:
	print("\n=== Six by Eleven — local PvP smoke test ===\n")
	GameSetup.reload_catalogue()
	GameSetup.mode = GameSetup.Mode.LOCAL_PVP
	GameSetup.set_slot(BoardModel.TEAM_B, 0, 0)
	GameSetup.set_slot(BoardModel.TEAM_B, 1, 0)
	GameSetup.set_slot(BoardModel.TEAM_A, 0, 2)

	_check("the two players can hold different loadouts",
		GameSetup.units_for(BoardModel.TEAM_A) != GameSetup.units_for(BoardModel.TEAM_B))
	_check("a repeated slot shows up in the summary",
		GameSetup.slot_summary(BoardModel.TEAM_B).contains("x"),
		GameSetup.slot_summary(BoardModel.TEAM_B))

	var packed := load("res://scenes/main.tscn") as PackedScene
	_main = packed.instantiate() as Node2D
	add_child(_main)
	_main._player.speed = 80.0
	_main.round_end_hold = 0.2
	_main.battle_start_hold = 0.15


func _check(label: String, condition: bool, detail := "") -> void:
	if condition:
		_passed += 1
		print("  ok    %s" % label)
	else:
		_failed += 1
		print("  FAIL  %s %s" % [label, detail])


func _process(_delta: float) -> void:
	if _done:
		return
	_frames += 1
	if _frames < 3:
		return

	if _frames == 3:
		_check("both sides get a draw before anyone arranges",
			_main.board.count_of(BoardModel.TEAM_A) > 0
			and _main.board.count_of(BoardModel.TEAM_B) > 0,
			"A %d, B %d" % [_main.board.count_of(BoardModel.TEAM_A),
				_main.board.count_of(BoardModel.TEAM_B)])
		_check("each side draws from its own loadout", _draws_match_loadouts())
		_check("the merge lottery is per player",
			_main.board.pool_for(BoardModel.TEAM_A)
				!= _main.board.pool_for(BoardModel.TEAM_B))

	_watch_labels()

	if _main._handover != null and _main._handover.visible:
		_watch_blind()
		return

	match MatchState.phase:
		MatchState.Phase.PREP:
			_do_prep()
		MatchState.Phase.BUFF_PICK:
			_do_pick()
		MatchState.Phase.ROUND_END:
			_rounds_played += 1
			if _rounds_played >= ROUNDS or MatchState.is_match_over():
				_report()
				return
			_main._on_fight_pressed()
		MatchState.Phase.MATCH_END:
			_report()
			return

	if _frames > MAX_FRAMES:
		_check("test finished inside the frame budget", false,
			"stuck in %s after %d frames" % [MatchState.phase_name(), _frames])
		_report()


func _watch_labels() -> void:
	if _hud_overflow.is_empty():
		var hud: Label = _main._hud
		if hud.get_visible_line_count() < hud.get_line_count():
			_hud_overflow = hud.text
	if _status_overflow.is_empty():
		var status: Label = _main._status
		if status.get_visible_line_count() < status.get_line_count():
			_status_overflow = status.text


func _check_turn_marker() -> void:
	var active: int = _main._active_team
	var idle := BoardModel.enemy_of(active)
	_check("the active player's strip is the highlighted one",
		_main._bars[active].active and not _main._bars[idle].active,
		"%s active=%s, %s active=%s" % [
			GameSetup.team_name(active), _main._bars[active].active,
			GameSetup.team_name(idle), _main._bars[idle].active])
	_check("the highlight marks the strip without moving it",
		_main._bars[active].label_text().contains(
			_main._bars[active].heading),
		_main._bars[active].label_text())
	_check("the HUD names whose turn it is",
		_main._hud.text.contains(GameSetup.team_name(active)),
		_main._hud.text)


func _draws_match_loadouts() -> bool:
	for team in [BoardModel.TEAM_A, BoardModel.TEAM_B]:
		var allowed := {}
		for u in GameSetup.units_for(team):
			allowed[u.id] = true
		for unit in _main.board.units_of(team):
			if not allowed.has(unit.data.id):
				return false
	return true


func _watch_blind() -> void:
	_turn_frames = 0
	if not _blind_checked:
		_blind_checked = true
		_check("the screen blinds between players", true)
		_check("nothing on the board is reachable while blinded",
			not _main._board_view.interactive)
		_check("the blind names who is up next",
			_main._handover._title.text.contains("Player"),
			_main._handover._title.text)
		_check("Ready is locked until the countdown runs out",
			_main._handover._button.disabled,
			"button already reads '%s'" % _main._handover._button.text)
	if not _main._handover._button.disabled:
		_handovers += 1
		_main._handover._on_ready()


func _do_prep() -> void:
	_turn_frames += 1
	if _turn_frames < 3:
		return
	_turn_frames = 0

	var active: int = _main._active_team
	if _prep_seen.is_empty():
		_check("Player 1 (the bottom half) always arranges first",
			active == BoardModel.TEAM_B,
			"first turn went to %s" % GameSetup.team_name(active))
	elif _prep_seen.size() == 1:
		_check("Player 2 (the top half) always goes second",
			active == BoardModel.TEAM_A,
			"second turn went to %s" % GameSetup.team_name(active))
	if not _prep_seen.has(active):
		_prep_seen.append(active)
		_check("%s arranges with the board shown from their side" % _label(active),
			_main._board_view.player_team == active
			and _main._board_view.fog)
		_check("%s can only move their own units" % _label(active),
			_only_own_units_movable(active))
		_check_turn_marker()
		_check("the button says Done for the first player, Fight for the last",
			_main._fight_btn.text == ("Done" if _main._prep_queue.size() > 1 else "Fight"),
			"button reads '%s' with %d left" % [
				_main._fight_btn.text, _main._prep_queue.size()])
	_main._on_fight_pressed()


func _only_own_units_movable(team: int) -> bool:
	for u in _main.board.all_units():
		if u.team == team:
			continue
		var before: Vector2i = u.cell
		_main._on_drag_dropped(u.cell, _free_cell(u.team))
		if u.cell != before:
			return false
	return true


func _free_cell(team: int) -> Vector2i:
	var free: Array[Vector2i] = _main.board.free_deploy_cells(team)
	return free[0] if not free.is_empty() else Vector2i(0, 0)


func _do_pick() -> void:
	if _main._picker == null or not _main._picker.visible:
		return
	var team: int = _main._pick_queue[0] if not _main._pick_queue.is_empty() else -1
	if _picks_by_team.is_empty():
		_check("Player 1 picks a buff before Player 2",
			team == BoardModel.TEAM_B,
			"first pick went to %s" % GameSetup.team_name(team))
	_check("the picker says whose choice it is",
		_main._picker._title.text.contains("Player"),
		_main._picker._title.text)
	_picks_by_team[team] = int(_main._picker._rarity)
	_main._picker._on_take(0)


func _label(team: int) -> String:
	return GameSetup.team_name(team)


func _report() -> void:
	_done = true
	_check("both players took a prep turn", _prep_seen.size() == 2,
		"saw %s" % str(_prep_seen))
	var want_order: Array[int] = [BoardModel.TEAM_B, BoardModel.TEAM_A]
	_check("the turn order never changed round to round",
		_prep_seen == want_order, "order was %s" % str(_prep_seen))
	_check("Player 1 is the bottom half and Player 2 the top",
		GameSetup.team_name(BoardModel.TEAM_B) == "Player 1"
		and GameSetup.team_name(BoardModel.TEAM_A) == "Player 2")
	_check("each buff strip is labelled with its owner, fixed to their half",
		_main._bars[BoardModel.TEAM_B].heading == "P1"
		and _main._bars[BoardModel.TEAM_A].heading == "P2",
		"bottom reads '%s', top reads '%s'" % [
			_main._bars[BoardModel.TEAM_B].heading,
			_main._bars[BoardModel.TEAM_A].heading])
	var force: ForceBar = _main._force
	_check("the force bar names both players, not You and Them",
		force != null and force.mine_name == "P1" and force.theirs_name == "P2",
		"reads '%s' v '%s'" % [
			"" if force == null else force.mine_name,
			"" if force == null else force.theirs_name])
	_check("the force bar stands beside the board, not over either half",
		force != null and force.vertical
		and force.position.x >= _main._board_view.position.x
			+ _main._board_view.board_size().x,
		"bar at %s, board ends at %.0f" % [
			Vector2.ZERO if force == null else force.position,
			_main._board_view.position.x + _main._board_view.board_size().x])
	_check("it runs the height of the board, so P1 fills from the bottom half",
		force != null
		and is_equal_approx(force.position.y, _main._board_view.position.y)
		and is_equal_approx(force.size.y, _main._board_view.board_size().y),
		"bar y %.0f h %.0f" % [
			0.0 if force == null else force.position.y,
			0.0 if force == null else force.size.y])

	var p1: RosterBar = _main._rosters[BoardModel.TEAM_B]
	var p2: RosterBar = _main._rosters[BoardModel.TEAM_A]
	_check("each roster strip is labelled with its owner, on their own half",
		p1.heading.begins_with("P1") and p2.heading.begins_with("P2")
		and p1.position.y > _main._board_view.position.y
		and p2.position.y < _main._board_view.position.y,
		"bottom reads '%s', top reads '%s'" % [p1.heading, p2.heading])

	_check("the screen blinded at least once between turns", _handovers > 0,
		"%d handovers" % _handovers)
	_check("neither player is the computer",
		GameSetup.is_human(BoardModel.TEAM_A) and GameSetup.is_human(BoardModel.TEAM_B))
	if _picks_by_team.size() == 2:
		var seen: Array = _picks_by_team.values()
		_check("both players pick at the same rarity", seen[0] == seen[1],
			str(_picks_by_team))
		_check("each player holds their own buff",
			_main._buffs_for(BoardModel.TEAM_A).size() > 0
			and _main._buffs_for(BoardModel.TEAM_B).size() > 0)

	_check("the HUD never gets cut off", _hud_overflow.is_empty(),
		"clipped: '%s'" % _hud_overflow.replace("\n", " | "))
	_check("the status line never gets cut off", _status_overflow.is_empty(),
		"clipped: '%s'" % _status_overflow)

	print("\nPlayed %d rounds. Score %s." % [_rounds_played, str(MatchState.wins)])
	if _failed > 0:
		print("%d FAILURES" % _failed)
	else:
		print("Local PvP smoke test passed. %d checks." % _passed)
	get_tree().quit(1 if _failed > 0 else 0)
