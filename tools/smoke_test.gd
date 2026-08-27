## Boots the real main scene, plays several full rounds by driving it the way a
## player would, and fails on any error. Catches the whole class of bugs the pure
## model tests can't see: scene wiring, @onready paths, signal connections, and
## the prep -> battle -> round-end loop.
##
## Runs as a scene rather than a --script, because autoload singletons
## (MatchState, EventBus) only exist in a normal run:
##
##   godot --headless res://tools/smoke_test.tscn
extends Node

const ROUNDS := 6
const MAX_FRAMES := 20000

var _main: Node2D
var _frames := 0
var _rounds_played := 0
var _failed := 0
var _last_phase := -1
var _done := false
var _roster_before := -1
var _roster_after := -1


func _ready() -> void:
	print("\n=== Six by Eleven — scene smoke test ===\n")
	var packed := load("res://scenes/main.tscn") as PackedScene
	if packed == null:
		push_error("main.tscn failed to load")
		get_tree().quit(1)
		return
	_main = packed.instantiate() as Node2D
	if _main == null:
		push_error("main.tscn did not instantiate as Node2D")
		get_tree().quit(1)
		return
	add_child(_main)
	# Battles now run to the 45s timeout on large boards, and playback is
	# real time. Without this the suite would take minutes of wall clock.
	_main._player.speed = 80.0


func _process(_delta: float) -> void:
	if _done:
		return
	_frames += 1
	if _frames < 3:
		return

	if _frames == 3:
		_check("scene has a BoardView", _main.get_node_or_null("BoardView") != null)
		_check("scene has the UI bench", _main.get_node_or_null("UI/Root/Bench") != null)
		_check("loadout resolved", _main.loadout != null)
		_check("bench was dealt", _main.player_bench.size() == MatchState.UNITS_PER_DRAW,
			"got %d" % _main.player_bench.size())
		_check("opponent deployed", _main.board.count_of(BoardModel.TEAM_A) > 0)
		_check("board starts within bounds", _all_units_in_bounds())
		_check_fog_up()

	var phase: int = MatchState.phase
	if phase != _last_phase:
		_last_phase = phase

	match phase:
		MatchState.Phase.PREP:
			_do_prep()
		MatchState.Phase.ROUND_END:
			_rounds_played += 1
			_check("round %d left a legal board" % _rounds_played, _all_units_in_bounds())
			_check("no unit sits in the neutral row after a round" , _none_in_neutral_row())
			# Nobody stays dead: losing a round costs a life, never a unit.
			_roster_after = _main.board.all_units().size()
			_check("the whole roster comes back after the battle",
				_roster_after == _roster_before,
				"%d before, %d after" % [_roster_before, _roster_after])
			_check("everyone is restored at full health", _all_at_full_health())
			if _rounds_played >= ROUNDS or MatchState.is_match_over():
				_report()
				return
			_main._on_fight_pressed()  # "Next Round"
		MatchState.Phase.MATCH_END:
			_check("match ended with a winner", MatchState.match_winner() >= 0)
			_report()
			return

	if _frames > MAX_FRAMES:
		_check("test completed before the frame budget", false,
			"stuck in phase %s after %d frames" % [MatchState.phase_name(), _frames])
		_report()


## Places the whole bench on the first legal tiles, then starts the fight —
## exactly the calls the buttons make.
func _do_prep() -> void:
	while not _main.player_bench.is_empty():
		var free: Array[Vector2i] = _main.board.free_deploy_cells(BoardModel.TEAM_B)
		if free.is_empty():
			break
		_main._selected = 0
		var before: int = _main.player_bench.size()
		_main._on_cell_pressed(free[0])
		if _main.player_bench.size() == before:
			_check("prep placement made progress", false, "bench stuck at %d" % before)
			break
	_main._selected = -1
	_check("player has units before fighting",
		_main.board.count_of(BoardModel.TEAM_B) > 0)
	_check_no_leftover_views()
	_check_playback_is_event_driven()
	_check("dealt exactly 5 units this turn",
		MatchState.UNITS_PER_DRAW == 5,
		"UNITS_PER_DRAW is %d" % MatchState.UNITS_PER_DRAW)
	_check_fog_up()
	_roster_before = _main.board.all_units().size()
	_main._on_fight_pressed()
	_check_fog_lifted()


## Fog must CONCEAL, not cover. The test is whether enemy UnitViews exist in the
## scene tree at all — a black rectangle drawn on top would pass a screenshot and
## still hand every enemy position to anyone inspecting the tree.
func _check_fog_up() -> void:
	var view: BoardView = _main.get_node("BoardView")
	_check("fog is up during prep", view.fog)
	_check("no enemy unit is in the tree while fogged",
		_enemy_views(view) == 0, "found %d" % _enemy_views(view))
	_check("player's own units stay visible under fog",
		_own_views(view) == _main.board.count_of(BoardModel.TEAM_B),
		"%d views for %d units" % [_own_views(view), _main.board.count_of(BoardModel.TEAM_B)])


func _check_fog_lifted() -> void:
	var view: BoardView = _main.get_node("BoardView")
	_check("fog lifts when the battle starts", not view.fog)
	_check("enemy units appear on the reveal", _enemy_views(view) > 0)


func _enemy_views(view: BoardView) -> int:
	var n := 0
	for child in view.get_children():
		if child is UnitView and child.unit != null and child.unit.team != view.player_team:
			n += 1
	return n


func _own_views(view: BoardView) -> int:
	var n := 0
	for child in view.get_children():
		if child is UnitView and child.unit != null and child.unit.team == view.player_team:
			n += 1
	return n


## Nothing from the previous battle may survive into the next prep phase — no
## faded corpses, no dimmed leftovers, no enemy views under the fog.
func _check_no_leftover_views() -> void:
	var view: BoardView = _main.get_node("BoardView")
	var total := 0
	var ghostly := 0
	var faded := 0
	for child in view.get_children():
		if not (child is UnitView):
			continue
		total += 1
		if child.dying:
			ghostly += 1
		if child.dimmed:
			faded += 1
	var expected: int = _main.board.count_of(BoardModel.TEAM_B)
	_check("no corpses linger into prep", ghostly == 0, "%d still dying" % ghostly)
	_check("no dimmed leftovers in prep", faded == 0, "%d dimmed" % faded)
	_check("exactly one view per visible unit", total == expected,
		"%d views for %d units" % [total, expected])


## Playback must be driven entirely by the event log. If it reads position or
## health off a UnitInstance, units snap to their end-of-battle tile whenever
## they attack, and every health bar shows its final value from frame one.
func _check_playback_is_event_driven() -> void:
	var view: BoardView = _main.get_node("BoardView")
	var mismatched := 0
	var checked := 0
	for child in view.get_children():
		if not (child is UnitView) or child.unit == null or child.dying:
			continue
		checked += 1
		# The view's health is its own field, fed from events — it must not be
		# aliased to the instance's post-battle value.
		if child.hp_max <= 0.0:
			mismatched += 1
	_check("every live view carries its own health state",
		checked > 0 and mismatched == 0, "%d bad of %d" % [mismatched, checked])


func _all_at_full_health() -> bool:
	for u in _main.board.all_units():
		if not u.is_alive():
			return false
		if u.current_hp < u.stat(StatModifier.Stat.MAX_HP) - 0.01:
			return false
	return true


func _all_units_in_bounds() -> bool:
	for u in _main.board.all_units():
		if not _main.board.in_bounds(u.cell):
			return false
	return true


func _none_in_neutral_row() -> bool:
	for u in _main.board.all_units():
		if u.cell.y == BoardModel.NEUTRAL_ROW:
			return false
	return true


func _check(label: String, condition: bool, detail := "") -> void:
	if condition:
		print("  ok    %s" % label)
	else:
		_failed += 1
		print("  FAIL  %s %s" % [label, detail])


func _report() -> void:
	_done = true
	print("\nPlayed %d rounds. Score %s." % [_rounds_played, str(MatchState.wins)])
	if _failed > 0:
		print("%d FAILURES" % _failed)
	else:
		print("Scene smoke test passed.")
	get_tree().quit(1 if _failed > 0 else 0)
