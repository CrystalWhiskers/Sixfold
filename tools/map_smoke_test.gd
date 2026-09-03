extends Node

# Plays a round on a board that is NOT the default: different dimensions, no
# neutral row, and terrain on it. That is the combination the whole flow was
# written around, so it gets its own run rather than riding on the standard map.

# No divider, solid walls and high ground in one board — the whole terrain
# system through the real UI in a single run.
const WANT_MAP := &"the_highlands"
const MAZE_MAP := &"the_labyrinth"
const MAX_FRAMES := 40000

var _main: Node2D
var _failed := 0
var _passed := 0
var _frames := 0
var _done := false
var _prep_checked := false
var _battle_checked := false


func _check(label: String, condition: bool, detail := "") -> void:
	if condition:
		_passed += 1
		print("  ok    %s" % label)
	else:
		_failed += 1
		print("  FAIL  %s %s" % [label, detail])


func _ready() -> void:
	print("\n=== Six by Eleven — undivided map test ===\n")
	GameSetup.reload_catalogue()
	GameSetup.mode = GameSetup.Mode.VS_COMPUTER

	var found := -1
	for i in GameSetup.maps.size():
		if GameSetup.maps[i].id == WANT_MAP:
			found = i
	_check("the undivided map is on disk", found >= 0,
		"no map called '%s'" % WANT_MAP)
	if found < 0:
		_report()
		return
	GameSetup.map_index = found
	GameSetup.apply_map()

	var m := GameSetup.current_map()
	_check("it really has no divider", not m.has_neutral)
	_check("and it is not the default shape",
		m.width != BoardModel.DEFAULT_WIDTH or m.height != BoardModel.DEFAULT_HEIGHT,
		m.shape())

	var packed := load("res://scenes/main.tscn") as PackedScene
	_check("main.tscn loads", packed != null)
	if packed == null:
		_report()
		return
	_main = packed.instantiate() as Node2D
	add_child(_main)
	_main._player.speed = 80.0
	_main.round_end_hold = 0.2
	_main.battle_start_hold = 0.15


func _process(_delta: float) -> void:
	if _done:
		return
	_frames += 1
	if _frames < 3:
		return

	match MatchState.phase:
		MatchState.Phase.PREP:
			_check_prep()
			_main._on_fight_pressed()
		MatchState.Phase.ROUND_END, MatchState.Phase.MATCH_END:
			_check_after_battle()
			_report()
			return

	if _frames > MAX_FRAMES:
		_check("the round finished inside the frame budget", false)
		_report()


func _check_prep() -> void:
	if _prep_checked:
		return
	_prep_checked = true

	var m := GameSetup.current_map()
	_check("the board took the map's shape",
		BoardModel.WIDTH == m.width and BoardModel.HEIGHT == m.height,
		"%dx%d against %s" % [BoardModel.WIDTH, BoardModel.HEIGHT, m.shape()])
	_check("no tile on it is neutral",
		not _main.board.is_neutral(Vector2i(0, m.half_rows())))
	_check("the two halves touch",
		_main.board.can_deploy(BoardModel.TEAM_A, Vector2i(0, m.half_rows() - 1))
		and _main.board.can_deploy(BoardModel.TEAM_B, Vector2i(0, m.half_rows())))

	var view: BoardView = _main._board_view
	var area: Rect2 = _main.BOARD_AREA
	# Whichever axis is tighter decides the tile size, so the board should fill
	# its slot in at least one direction — another tile would not fit.
	var span := view.board_size()
	_check("the board is scaled to fill its slot as far as it can",
		span.x > area.size.x - view.tile_size
		or span.y > area.size.y - view.tile_size,
		"%s in %s at %.0f px tiles" % [span, area.size, view.tile_size])
	_check("and the tiles stay big enough to play on",
		view.tile_size >= BoardView.MIN_TILE, "%.0f px" % view.tile_size)
	_check("a board that fits is centred in the window, not scrolled",
		view.overflows()
		or area.encloses(Rect2(view.position, view.board_size())),
		"board at %s sized %s" % [view.position, view.board_size()])

	_check("both sides drew onto it",
		_main.board.count_of(BoardModel.TEAM_B) > 0
		and _main.board.count_of(BoardModel.TEAM_A) > 0,
		"%d against %d" % [_main.board.count_of(BoardModel.TEAM_B),
			_main.board.count_of(BoardModel.TEAM_A)])
	var stray := 0
	for u in _main.board.all_units():
		if not _main.board.can_deploy(u.team, u.cell):
			stray += 1
	_check("everyone landed on their own half", stray == 0, "%d strays" % stray)

	var in_stone := 0
	for u in _main.board.all_units():
		if BoardModel.is_blocked(u.cell):
			in_stone += 1
	_check("and nobody was dealt into a wall", in_stone == 0,
		"%d inside terrain" % in_stone)
	_check("the map really has terrain on it", BoardModel.has_terrain())
	_check("its walls are where the map says",
		BoardModel.is_wall(Vector2i(2, 2)) and BoardModel.is_wall(Vector2i(3, 5)),
		"walls missing from the loaded board")
	_check("its high ground is too", BoardModel.is_high(Vector2i(2, 0)))
	_check("a wall is not a tile you can deploy onto",
		not _main.board.can_deploy(BoardModel.TEAM_A, Vector2i(2, 2)))
	_check("and it stops a shot as well as a step",
		not BoardModel.line_of_fire(Vector2i(2, 1), Vector2i(2, 3)),
		"the boulder is see-through")
	_check_maze()
	_check_camera()

	var hud: Label = _main._hud
	_check("the HUD is not clipped by the new layout",
		hud.get_visible_line_count() >= hud.get_line_count())
	var mine: RosterBar = _main._rosters[BoardModel.TEAM_B]
	var screen := Rect2(Vector2.ZERO, _main.get_viewport_rect().size)
	_check("the roster strips still sit on screen",
		screen.encloses(Rect2(mine.position, mine.size)),
		"strip at %s" % mine.position)
	_check("so does the force bar",
		screen.encloses(Rect2(_main._force.position, _main._force.size)),
		"bar at %s sized %s" % [_main._force.position, _main._force.size])


func _check_after_battle() -> void:
	if _battle_checked:
		return
	_battle_checked = true
	_check("a battle resolved on the undivided board",
		MatchState.round_index >= 1)
	var stray := 0
	for u in _main.board.all_units():
		if not _main.board.in_bounds(u.cell):
			stray += 1
	_check("nothing ended up off the board", stray == 0, "%d strays" % stray)
	_check("the whole roster came back", _main.board.all_units().size() > 0)
	var buried := 0
	for u in _main.board.all_units():
		if BoardModel.is_blocked(u.cell):
			buried += 1
	_check("and none of it came back inside a wall", buried == 0,
		"%d buried" % buried)


func _check_maze() -> void:
	# The labyrinth is the hardest board in the game to path across, so it gets
	# checked here rather than only in the model suite.
	var maze: MapData = null
	for candidate in GameSetup.maps:
		if candidate.id == MAZE_MAP:
			maze = candidate
	_check("the labyrinth is on disk", maze != null)
	if maze == null:
		return
	_check("and it is a legal board", maze.is_valid(), maze.invalid_reason())

	BoardModel.use_map(maze)
	var board := BoardModel.new()
	var open := board.playable_cells()
	var seen := {open[0]: true}
	var queue: Array[Vector2i] = [open[0]]
	var head := 0
	while head < queue.size():
		var c: Vector2i = queue[head]
		head += 1
		for off in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			var n: Vector2i = c + off
			if seen.has(n) or not BoardModel.is_playable(n):
				continue
			seen[n] = true
			queue.append(n)
	_check("every corridor in it is reachable", seen.size() == open.size(),
		"%d of %d" % [seen.size(), open.size()])

	var far := Vector2i(0, BoardModel.HEIGHT - 1)
	_check("its walls genuinely block sight across the board",
		not BoardModel.line_of_fire(Vector2i(0, 0), far),
		"a shot runs clean from one back rank to the other")
	_check("it is walled enough to be a maze",
		open.size() < BoardModel.WIDTH * BoardModel.HEIGHT * 0.65,
		"%d of %d tiles are open" % [
			open.size(), BoardModel.WIDTH * BoardModel.HEIGHT])

	# Corridors: almost nothing in the maze proper should be open on 3+ sides.
	var stage := 3
	var junctions := 0
	var inner := 0
	for c in open:
		if c.y < stage or c.y >= BoardModel.HEIGHT - stage:
			continue
		inner += 1
		var ways := 0
		for off in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			if BoardModel.is_playable(c + off):
				ways += 1
		if ways >= 3:
			junctions += 1
	_check("it is corridors, not rooms",
		inner > 0 and float(junctions) / float(inner) < 0.20,
		"%d junctions in %d maze tiles" % [junctions, inner])

	# Muster ground: the far end of each half is open, so you can actually deploy.
	var top_open := 0
	var bottom_open := 0
	for x in BoardModel.WIDTH:
		if BoardModel.is_playable(Vector2i(x, 0)):
			top_open += 1
		if BoardModel.is_playable(Vector2i(x, BoardModel.HEIGHT - 1)):
			bottom_open += 1
	_check("each side musters on open ground at its own end",
		top_open == BoardModel.WIDTH and bottom_open == BoardModel.WIDTH,
		"%d open at the top, %d at the bottom" % [top_open, bottom_open])
	GameSetup.apply_map()


func _check_camera() -> void:
	var view: BoardView = _main._board_view
	var maze: MapData = null
	for candidate in GameSetup.maps:
		if candidate.id == MAZE_MAP:
			maze = candidate
	if maze == null:
		return
	BoardModel.use_map(maze)
	view.fit_to(_main.BOARD_AREA)
	_check("the maze is too big for the window, so the camera matters",
		view.overflows(), "%s fits %s" % [view.board_size(), _main.BOARD_AREA.size])
	_check("its tiles are not shrunk below the floor to force a fit",
		view.tile_size >= BoardView.MIN_TILE, "%.0f px" % view.tile_size)

	var start := view.position
	view.pan_by(Vector2(0.0, -400.0))
	_check("the camera moves when you drag it", view.position != start,
		"still at %s" % view.position)

	view.pan_by(Vector2(0.0, -9000.0))
	var span := view.board_size()
	var area: Rect2 = _main.BOARD_AREA
	_check("and it cannot be pushed past the bottom edge",
		view.position.y + span.y >= area.end.y - 0.5,
		"board ends at %.0f, window at %.0f" % [
			view.position.y + span.y, area.end.y])
	view.pan_by(Vector2(0.0, 9000.0))
	_check("or past the top edge", view.position.y <= area.position.y + 0.5,
		"board starts at %.0f, window at %.0f" % [
			view.position.y, area.position.y])

	view.centre_on(Vector2i(4, BoardModel.HEIGHT - 2))
	_check("centring on a cell brings it into the window",
		Rect2(area.position, area.size).has_point(
			view.position + view.cell_to_pos(Vector2i(4, BoardModel.HEIGHT - 2))),
		"cell landed at %s" % (view.position
			+ view.cell_to_pos(Vector2i(4, BoardModel.HEIGHT - 2))))

	_check("the window has a mask over everything outside it",
		_main._mask != null and _main._mask.window == area)

	GameSetup.apply_map()
	view.fit_to(_main.BOARD_AREA)


func _report() -> void:
	_done = true
	BoardModel.reset_map()
	if _failed > 0:
		print("\n%d FAILURES" % _failed)
	else:
		print("\nUndivided map test passed. %d checks." % _passed)
	get_tree().quit(1 if _failed > 0 else 0)
