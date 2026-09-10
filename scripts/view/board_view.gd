class_name BoardView
extends Node2D

signal cell_pressed(cell: Vector2i)
signal drag_dropped(from: Vector2i, to: Vector2i)

const UNIT_VIEW := preload("res://scenes/units/unit_view.tscn")

const MIN_TILE := 56.0

# Zoom multiplies the fitted tile size. Out to 0.6 so the biggest maps can be
# seen whole — those hit the MIN_TILE floor and overflow even when fitted — and
# in to 3x so you can watch one corner of a fight properly.
const MIN_ZOOM := 0.6
const MAX_ZOOM := 3.0
const ZOOM_STEP := 1.15
# Below this a tile stops being a readable unit and becomes a coloured dot.
const FLOOR_TILE := 22.0
const KEY_PAN := 46.0

@export var tile_size := 84.0
@export var player_team := BoardModel.TEAM_B
@export var interactive := true

var fog := false

const FOG_SHOWS_COUNT := false

var board: BoardModel = null

var _views: Dictionary = {}
var _hover := Vector2i(-1, -1)
var _drag_uid := -1
var _drag_from := Vector2i(-1, -1)
var _drag_pos := Vector2.ZERO
var _flashes: Array[Dictionary] = []
## Persistent, unlike everything else in this file that is drawn over the board:
## a mana aura lasts from the cast until the caster dies, so it is keyed by uid
## and removed by name rather than counted down.
var _aura_zones: Dictionary = {}
var _floaters: Array[Dictionary] = []
var _shots: Array[Dictionary] = []
var _beams: Array[Dictionary] = []
var ghosts: Array[Dictionary] = []
var _merge_cells: Array[Vector2i] = []
var view_area := Rect2(0.0, 0.0, 504.0, 924.0)
var pan := Vector2.ZERO
var _panning := false
var _pan_from := Vector2.ZERO
var zoom := 1.0
var _fit_tile := MIN_TILE
var _dying: Array[UnitView] = []

const COL_TILE := Color(0.13, 0.16, 0.21)
const COL_TILE_ALT := Color(0.15, 0.18, 0.24)
const COL_DEPLOY := Color(0.18, 0.24, 0.28)
const COL_NEUTRAL := Color(0.24, 0.20, 0.14)
const COL_GRID := Color(0.28, 0.32, 0.40, 0.9)
const COL_HOVER := Color(1, 1, 1, 0.10)
const COL_LEGAL := Color(0.45, 0.75, 0.50, 0.18)
const COL_MERGE := Color(1.0, 0.85, 0.40, 0.26)
const COL_MERGE_EDGE := Color(1.0, 0.88, 0.48, 0.85)
const COL_SHOT := Color(0.93, 0.88, 0.66)
const COL_SHOT_SPELL := Color(0.98, 0.66, 0.30)
const COL_DMG := Color(0.97, 0.95, 0.90)
const COL_DMG_SPELL := Color(0.98, 0.72, 0.34)
const DMG_LIFE := 0.75
const COL_WALL := Color(0.30, 0.31, 0.36)
const COL_WALL_EDGE := Color(0.46, 0.48, 0.55)
const COL_HIGH := Color(0.26, 0.33, 0.28)
const COL_HIGH_MARK := Color(0.58, 0.78, 0.60, 0.85)
# Between the ground and the terrace, and it reads as both: the tint sits halfway
# to COL_HIGH so the eye follows a staircase up onto the plateau it serves.
# The Wellspring's reach. Barely-there fill with a readable edge: it is on screen
# for the whole battle once it is cast, so it has to be legible without ever
# competing with the units standing inside it.
const COL_AURA_FILL := Color(0.44, 0.72, 0.86, 0.10)
const COL_AURA_EDGE := Color(0.52, 0.82, 0.94, 0.55)

const COL_STAIRS := Color(0.24, 0.29, 0.27)
const COL_STAIRS_MARK := Color(0.62, 0.76, 0.66, 0.70)
const COL_BARRIER := Color(0.72, 0.66, 0.52)
const COL_FOG := Color(0.09, 0.10, 0.13)
const COL_FOG_HATCH := Color(0.20, 0.23, 0.29, 0.55)


static func _on_board(c: Vector2i) -> bool:
	return c.x >= 0 and c.x < BoardModel.WIDTH and c.y >= 0 and c.y < BoardModel.HEIGHT


func board_size() -> Vector2:
	return Vector2(BoardModel.WIDTH, BoardModel.HEIGHT) * tile_size


func fit_to(area: Rect2) -> void:
	# Shrink a big map to fit the slot, but never past MIN_TILE — below that the
	# tiles stop being readable. A board that will not fit at MIN_TILE overflows
	# on purpose, and you pan around it instead.
	view_area = area
	_fit_tile = maxf(floorf(minf(area.size.x / float(BoardModel.WIDTH),
		area.size.y / float(BoardModel.HEIGHT))), MIN_TILE)
	_apply_zoom()


func _apply_zoom() -> void:
	# One source of truth: the fitted size times the zoom. Recomputing the fit
	# from the window every time would mean a resize silently threw the player's
	# zoom away.
	zoom = clampf(zoom, MIN_ZOOM, MAX_ZOOM)
	tile_size = maxf(floorf(_fit_tile * zoom), FLOOR_TILE)
	for uid in _views:
		var v: UnitView = _views[uid]
		if is_instance_valid(v):
			v.tile_size = tile_size
	_apply_pan()
	sync_positions()
	queue_redraw()


func zoom_to(want: float, focus := Vector2.INF) -> void:
	# `focus` is a point in window space to hold still — the mouse, normally, so
	# the board grows toward the cursor rather than toward its own corner. Without
	# it, zooming in on a big map walks whatever you were looking at off-screen.
	var before := clampf(zoom, MIN_ZOOM, MAX_ZOOM)
	var after := clampf(want, MIN_ZOOM, MAX_ZOOM)
	if is_equal_approx(before, after):
		return
	var anchor := focus
	if anchor == Vector2.INF:
		anchor = view_area.position + view_area.size * 0.5
	# Where that point sits on the board right now, in tiles.
	var on_board := (anchor - position) / tile_size
	zoom = after
	_apply_zoom()
	# Put the same board point back under the same window point.
	pan += anchor - (position + on_board * tile_size)
	_apply_pan()
	sync_positions()
	queue_redraw()


func zoom_by(factor: float, focus := Vector2.INF) -> void:
	zoom_to(zoom * factor, focus)


func wheel_zoom(into: bool) -> void:
	# One step of wheel zoom, anchored on the cursor when the cursor is over the
	# board and on the middle of the window when it is not.
	#
	# The position MUST come from get_global_mouse_position(), not from the
	# event's own `global_position`. Those are different spaces — the event
	# carries viewport coordinates, this returns canvas coordinates — and
	# `view_area` is in canvas space, like every other mouse test in this file.
	# The first version of this compared the event's position against view_area,
	# the test failed silently on every scroll, and the whole feature did nothing
	# at all. If a mouse position is being compared to view_area, it comes from
	# here.
	var at := get_global_mouse_position()
	var anchor := at if view_area.has_point(at) else Vector2.INF
	zoom_by(ZOOM_STEP if into else 1.0 / ZOOM_STEP, anchor)


func reset_zoom() -> void:
	zoom = 1.0
	pan = Vector2.ZERO
	_apply_zoom()


func overflows() -> bool:
	var span := board_size()
	return span.x > view_area.size.x + 0.5 or span.y > view_area.size.y + 0.5


func pan_limits() -> Rect2:
	# The range `pan` may take: zero on an axis that fits, otherwise enough to
	# bring either edge of the board to the matching edge of the window.
	var span := board_size()
	var slack := (view_area.size - span).min(Vector2.ZERO)
	return Rect2(slack, -slack)


func pan_by(delta: Vector2) -> void:
	if not overflows():
		return
	pan += delta
	_apply_pan()
	sync_positions()
	queue_redraw()


func centre_on(cell: Vector2i) -> void:
	if not overflows():
		return
	pan = view_area.size * 0.5 - (Vector2(cell) + Vector2(0.5, 0.5)) * tile_size
	_apply_pan()
	sync_positions()
	queue_redraw()


func _apply_pan() -> void:
	var span := board_size()
	var limits := pan_limits()
	pan.x = clampf(pan.x, limits.position.x, limits.end.x)
	pan.y = clampf(pan.y, limits.position.y, limits.end.y)
	var centred := (view_area.size - span) * 0.5
	var offset := Vector2(
		pan.x if span.x > view_area.size.x else centred.x,
		pan.y if span.y > view_area.size.y else centred.y)
	position = (view_area.position + offset).round()


func cell_to_pos(cell: Vector2i) -> Vector2:
	return Vector2(cell.x + 0.5, cell.y + 0.5) * tile_size


func pos_to_cell(pos: Vector2) -> Vector2i:
	return Vector2i(floori(pos.x / tile_size), floori(pos.y / tile_size))


func bind(p_board: BoardModel) -> void:
	board = p_board
	rebuild()


func rebuild() -> void:
	for uid in _views.keys():
		var v: UnitView = _views[uid]
		remove_child(v)
		v.queue_free()
	_views.clear()
	for d in _dying:
		if is_instance_valid(d):
			remove_child(d)
			d.queue_free()
	_dying.clear()
	_floaters.clear()
	_shots.clear()
	_beams.clear()
	if board == null:
		return
	for u in board.all_units():
		if is_concealed(u):
			continue
		_add_view(u)
	queue_redraw()


func unit_at_point(local: Vector2) -> UnitInstance:
	var best: UnitInstance = null
	var best_d := tile_size * 0.5
	for uid in _views:
		var v: UnitView = _views[uid]
		if not is_instance_valid(v) or v.unit == null or v.dying:
			continue
		var d := local.distance_to(v.position)
		if d <= best_d:
			best_d = d
			best = v.unit
	return best


func is_concealed(u: UnitInstance) -> bool:
	return fog and u.team != player_team


func set_ghosts(seen: Array) -> void:
	# Last round's enemy formation. Drawn, never instantiated, so the "no enemy
	# unit in the tree while fogged" rule still holds.
	ghosts.clear()
	for g in seen:
		ghosts.append(g)
	queue_redraw()


func set_fog(enabled: bool) -> void:
	if fog == enabled:
		return
	fog = enabled
	rebuild()


func concealed_count() -> int:
	if board == null:
		return 0
	return board.living_units_of(BoardModel.enemy_of(player_team)).size()


func _add_view(u: UnitInstance) -> UnitView:
	var v: UnitView = UNIT_VIEW.instantiate()
	v.tile_size = tile_size
	v.player_team = player_team
	add_child(v)
	v.bind(u)
	v.position = cell_to_pos(u.cell)
	_views[u.uid] = v
	return v


func view_for(uid: int) -> UnitView:
	return _views.get(uid, null)


func ensure_view(u: UnitInstance) -> UnitView:
	if u == null:
		return null
	var existing: UnitView = _views.get(u.uid, null)
	if existing != null and is_instance_valid(existing):
		return existing
	if is_concealed(u):
		return null
	return _add_view(u)


func kill_view(uid: int) -> void:
	var v: UnitView = _views.get(uid, null)
	if v == null:
		return
	_views.erase(uid)
	v.die()
	_dying.append(v)
	set_process(true)


func drop_view(uid: int) -> void:
	var v: UnitView = _views.get(uid, null)
	if v != null:
		remove_child(v)
		v.queue_free()
		_views.erase(uid)


func sync_positions() -> void:
	if board == null:
		return
	for u in board.all_units():
		if is_concealed(u):
			continue
		var v: UnitView = _views.get(u.uid, null)
		if v == null:
			v = _add_view(u)
		v.position = cell_to_pos(u.cell)
		v.dimmed = false
	queue_redraw()


func set_dimmed(uid: int, value: bool) -> void:
	var v: UnitView = _views.get(uid, null)
	if v != null:
		v.dimmed = value
		v.queue_redraw()


func add_aura_zone(uid: int, radius: int, team: int) -> void:
	# Keyed by uid and idempotent, because the Wellspring emits this on its
	# opening instacast AND on every later cast — the zone is one thing that
	# exists from the first cast until the caster dies, not an effect per cast.
	_aura_zones[uid] = {radius = maxi(radius, 0), team = team}
	set_process(true)
	queue_redraw()


func clear_aura_zone(uid: int) -> void:
	if _aura_zones.erase(uid):
		queue_redraw()


func clear_aura_zones() -> void:
	_aura_zones.clear()
	queue_redraw()


func _draw_aura_zones() -> void:
	# Drawn from the unit VIEW's live position rather than its cell, so the zone
	# slides with the Wellspring while it walks instead of snapping a tile behind
	# it. The sim's own unit.cell is no use here: the battle finished resolving
	# before frame one, so every unit's cell is already its final one.
	for uid in _aura_zones:
		var z: Dictionary = _aura_zones[uid]
		var v: UnitView = _views.get(uid, null)
		if v == null or not is_instance_valid(v):
			continue
		var span := float(int(z.radius) * 2 + 1) * tile_size
		var box := Rect2(v.position + Vector2(tile_size, tile_size) * 0.5
			- Vector2(span, span) * 0.5, Vector2(span, span))
		draw_rect(box, COL_AURA_FILL, true)
		draw_rect(box, COL_AURA_EDGE, false, 2.0)


func flash_cells(cells: Array, color: Color, duration: float) -> void:
	_flashes.append({cells = cells.duplicate(), color = color,
		left = duration, total = maxf(duration, 0.01)})
	set_process(true)
	queue_redraw()


const COL_CRIT := Color(1.00, 0.84, 0.34)


func spawn_damage(world: Vector2, amount: float, spell: bool, crit := false) -> void:
	if amount <= 0.0:
		return
	# A crit is a doubled number with no other tell, so it needs one: bigger,
	# gold, and marked. Otherwise a 5% event is invisible in a wall of figures.
	_floaters.append({
		pos = world + Vector2(0, -tile_size * 0.30),
		text = ("%d!" % roundi(amount)) if crit else str(roundi(amount)),
		color = COL_CRIT if crit else (COL_DMG_SPELL if spell else COL_DMG),
		left = DMG_LIFE * (1.35 if crit else 1.0),
		drift = randf_range(-9.0, 9.0),
		big = crit,
	})
	set_process(true)
	queue_redraw()


func spawn_shot(from: Vector2, to: Vector2, flight: float, spell: bool) -> void:
	_shots.append({
		from = from, to = to,
		left = maxf(flight, 0.02), total = maxf(flight, 0.02),
		color = COL_SHOT_SPELL if spell else COL_SHOT,
	})
	set_process(true)
	queue_redraw()


func spawn_beam(from: Vector2, through: Vector2, color: Color,
		endless := true, life := 0.42) -> void:
	var dir := (through - from)
	if dir.length_squared() < 0.001:
		dir = Vector2(0.0, -1.0)
	# An endless beam runs off the board; a mini one stops just past its target.
	var span := (board_size().length() + tile_size * 2.0 if endless
		else from.distance_to(through) + tile_size * 0.35)
	_beams.append({
		from = from, dir = dir.normalized(), span = span,
		left = life, total = life, color = color,
		width = 1.0 if endless else 0.32,
	})
	set_process(true)
	queue_redraw()


func spawn_label(world: Vector2, text: String, color: Color) -> void:
	_floaters.append({
		pos = world + Vector2(0, -tile_size * 0.55),
		text = text, color = color,
		left = DMG_LIFE * 1.4, drift = 0.0,
	})
	set_process(true)
	queue_redraw()


func _process(delta: float) -> void:
	var busy := false

	var si := _shots.size() - 1
	while si >= 0:
		_shots[si].left -= delta
		if _shots[si].left <= 0.0:
			_shots.remove_at(si)
		si -= 1
	busy = busy or not _shots.is_empty()

	var bi := _beams.size() - 1
	while bi >= 0:
		_beams[bi].left -= delta
		if _beams[bi].left <= 0.0:
			_beams.remove_at(bi)
		bi -= 1
	busy = busy or not _beams.is_empty()

	var i := _flashes.size() - 1
	while i >= 0:
		_flashes[i].left -= delta
		if _flashes[i].left <= 0.0:
			_flashes.remove_at(i)
		i -= 1
	busy = busy or not _flashes.is_empty()

	i = _floaters.size() - 1
	while i >= 0:
		_floaters[i].left -= delta
		if _floaters[i].left <= 0.0:
			_floaters.remove_at(i)
		i -= 1
	busy = busy or not _floaters.is_empty()

	i = _dying.size() - 1
	while i >= 0:
		var v: UnitView = _dying[i]
		if not is_instance_valid(v) or v.is_gone():
			if is_instance_valid(v):
				remove_child(v)
				v.queue_free()
			_dying.remove_at(i)
		i -= 1
	busy = busy or not _dying.is_empty()
	# A zone follows a unit that is still walking, so as long as one exists the
	# view has to keep redrawing even when nothing else is animating.
	busy = busy or not _aura_zones.is_empty()

	if not busy:
		set_process(false)
	queue_redraw()


func _unhandled_input(event: InputEvent) -> void:
	if board == null:
		return

	# The camera is not part of playing your turn: a board too big for its window
	# has to be readable while the fighting happens, when `interactive` is off and
	# there is nothing to drag. Only picking units up is gated on the turn.
	if event is InputEventKey and event.pressed:
		var key := (event as InputEventKey).keycode
		# Both rows of the keyboard: the number-row pair and the keypad pair.
		# KEY_EQUAL is there because "+" is shift-equals and most people do not
		# hold shift to zoom.
		match key:
			KEY_EQUAL, KEY_PLUS, KEY_KP_ADD:
				zoom_by(ZOOM_STEP)
				get_viewport().set_input_as_handled()
				return
			KEY_MINUS, KEY_KP_SUBTRACT:
				zoom_by(1.0 / ZOOM_STEP)
				get_viewport().set_input_as_handled()
				return
			KEY_0, KEY_KP_0:
				reset_zoom()
				get_viewport().set_input_as_handled()
				return
		var step := Vector2.ZERO
		match key:
			KEY_LEFT: step = Vector2(KEY_PAN, 0.0)
			KEY_RIGHT: step = Vector2(-KEY_PAN, 0.0)
			KEY_UP: step = Vector2(0.0, KEY_PAN)
			KEY_DOWN: step = Vector2(0.0, -KEY_PAN)
		if step != Vector2.ZERO:
			pan_by(step)
			get_viewport().set_input_as_handled()
		return

	if event is InputEventMouseButton and event.pressed:
		var wheel := event as InputEventMouseButton
		if wheel.button_index == MOUSE_BUTTON_WHEEL_UP \
				or wheel.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			wheel_zoom(wheel.button_index == MOUSE_BUTTON_WHEEL_UP)
			get_viewport().set_input_as_handled()
			return

	if event is InputEventMouseMotion:
		if _panning:
			var now := get_global_mouse_position()
			pan_by(now - _pan_from)
			_pan_from = now
			return
		if not interactive:
			return
		var cell := pos_to_cell(to_local(get_global_mouse_position()))
		if _drag_uid >= 0:
			_drag_pos = to_local(get_global_mouse_position())
			queue_redraw()
		if cell != _hover:
			_hover = cell
			queue_redraw()
		return

	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		var at := get_global_mouse_position()
		if not event.pressed:
			_panning = false
			if interactive:
				_end_drag(pos_to_cell(to_local(at)))
			return
		if not view_area.has_point(at):
			return
		if interactive:
			_begin_drag(pos_to_cell(to_local(at)))
		elif overflows():
			# Nothing to pick up mid-battle, so a press anywhere on the board
			# window takes the camera.
			_begin_pan(at)


func _begin_drag(cell: Vector2i) -> void:
	if not board.in_bounds(cell):
		# Inside the window but off the edge of the board — still somewhere to
		# grab the camera by.
		_begin_pan(get_global_mouse_position())
		return
	var u := board.unit_at(cell)
	cell_pressed.emit(cell)
	if u == null or u.team != player_team:
		# Nothing of yours under the finger, so the drag moves the camera.
		_begin_pan(get_global_mouse_position())
		return
	_drag_uid = u.uid
	_drag_from = cell
	_drag_pos = cell_to_pos(cell)
	# On the PICK UP, not the drop. This is the moment the merge targets light up
	# and the board changes under your hand, and it is the one the sound is
	# feedback for; the drop already has its own answer, either the merge sound or
	# nothing.
	Audio.play_pickup()
	set_dimmed(u.uid, true)
	_mark_merge_targets(u)
	queue_redraw()


func _begin_pan(at: Vector2) -> void:
	if not overflows():
		return
	_panning = true
	_pan_from = at


func _end_drag(cell: Vector2i) -> void:
	_clear_merge_targets()
	if _drag_uid < 0:
		return
	var uid := _drag_uid
	var from := _drag_from
	_drag_uid = -1
	_drag_from = Vector2i(-1, -1)
	set_dimmed(uid, false)
	queue_redraw()
	if board.in_bounds(cell) and cell != from:
		drag_dropped.emit(from, cell)
	else:
		sync_positions()


func cancel_drag() -> void:
	_panning = false
	if _drag_uid >= 0:
		set_dimmed(_drag_uid, false)
	_clear_merge_targets()
	_drag_uid = -1
	sync_positions()


func _mark_merge_targets(held: UnitInstance) -> void:
	# Everything the held unit can merge into lights up; everything else fades,
	# so the one decision you are making is the only thing you can see clearly.
	_merge_cells.clear()
	for uid in _views:
		var v: UnitView = _views[uid]
		if not is_instance_valid(v) or v.unit == null or v.unit == held:
			continue
		var mergeable := board != null and board.can_merge(held, v.unit)
		v.merge_target = mergeable
		v.dimmed = not mergeable
		if mergeable:
			_merge_cells.append(v.unit.cell)
		v.queue_redraw()


func _clear_merge_targets() -> void:
	_merge_cells.clear()
	for uid in _views:
		var v: UnitView = _views[uid]
		if not is_instance_valid(v):
			continue
		v.merge_target = false
		v.dimmed = false
		v.queue_redraw()


func merge_targets() -> Array[Vector2i]:
	return _merge_cells


func is_dragging() -> bool:
	return _drag_uid >= 0


func _draw() -> void:
	var size := board_size()

	for y in BoardModel.HEIGHT:
		for x in BoardModel.WIDTH:
			var cell := Vector2i(x, y)
			# A void is not a tile at all — leaving it unpainted is what makes a
			# board stop being a rectangle.
			if BoardModel.is_void(cell):
				continue
			var r := Rect2(Vector2(x, y) * tile_size, Vector2(tile_size, tile_size))
			draw_rect(r, _tile_color(cell), true)
			if BoardModel.is_wall(cell):
				_draw_wall(r, BoardModel.is_breakable(cell),
					BoardModel.wall_fraction(cell))
			elif BoardModel.is_high(cell):
				_draw_high(r)
			elif BoardModel.is_stairs(cell):
				_draw_stairs(r)

	_draw_aura_zones()

	if _drag_uid >= 0 and board != null:
		for c in board.deploy_cells(player_team):
			draw_rect(Rect2(Vector2(c) * tile_size, Vector2(tile_size, tile_size)),
				COL_LEGAL, true)
		for c in _merge_cells:
			var mr := Rect2(Vector2(c) * tile_size, Vector2(tile_size, tile_size))
			draw_rect(mr, COL_MERGE, true)
			draw_rect(mr.grow(-2.0), COL_MERGE_EDGE, false, 2.5)

	for f in _flashes:
		var fade: float = clampf(f.left / f.total, 0.0, 1.0)
		var col: Color = f.color
		col.a *= fade
		for c in f.cells:
			if _on_board(c):
				draw_rect(Rect2(Vector2(c) * tile_size, Vector2(tile_size, tile_size)),
					col, true)

	if _on_board(_hover) and _drag_uid < 0:
		draw_rect(Rect2(Vector2(_hover) * tile_size, Vector2(tile_size, tile_size)),
			COL_HOVER, true)

	_draw_grid()
	_draw_barriers()

	# On a map with no divider the halves simply meet, so there is one line to
	# draw rather than the two edges of a neutral row.
	var ny := BoardModel.NEUTRAL_ROW * tile_size
	_draw_dashed(Vector2(0, ny), Vector2(size.x, ny))
	if BoardModel.HAS_NEUTRAL:
		_draw_dashed(Vector2(0, ny + tile_size), Vector2(size.x, ny + tile_size))

	if fog and board != null:
		_draw_fog()

	_draw_shots()
	_draw_beams()
	_draw_floaters()

	if _drag_uid >= 0:
		var v: UnitView = _views.get(_drag_uid, null)
		if v != null:
			var half := tile_size * 0.5
			var ghost := Rect2(_drag_pos - Vector2(half, half) + Vector2(5, 5),
				Vector2(tile_size - 10, tile_size - 10))
			var col: Color = v.unit.data.accent
			col.a = 0.85
			draw_rect(ghost, col, true)
			draw_rect(ghost, v.team_color(), false, 3.0)


func _draw_fog() -> void:
	var enemy := BoardModel.enemy_of(player_team)
	var cells := board.deploy_cells(enemy)
	if cells.is_empty():
		return

	var top := BoardModel.HEIGHT
	var bottom := 0
	for c in cells:
		top = mini(top, c.y)
		bottom = maxi(bottom, c.y)
	for y in range(top, bottom + 1):
		for x in BoardModel.WIDTH:
			if BoardModel.is_void(Vector2i(x, y)):
				continue
			draw_rect(Rect2(Vector2(x, y) * tile_size,
				Vector2(tile_size, tile_size)), COL_FOG, true)

	var y0 := top * tile_size
	var y1 := (bottom + 1) * tile_size
	var w := BoardModel.WIDTH * tile_size
	var step := 26.0
	var x := -(y1 - y0)
	while x < w:
		var a := Vector2(x, y1)
		var b := Vector2(x + (y1 - y0), y0)
		draw_line(a.clamp(Vector2(0, y0), Vector2(w, y1)),
			b.clamp(Vector2(0, y0), Vector2(w, y1)), COL_FOG_HATCH, 1.0)
		x += step

	var drawn := _draw_ghosts(enemy)

	var label := "hidden until you commit"
	if drawn > 0:
		label = "last round's board"
	elif FOG_SHOWS_COUNT:
		var n := concealed_count()
		label = "%d unit%s hidden" % [n, "" if n == 1 else "s"]
	var font := ThemeDB.fallback_font
	var size := 18
	var tw := font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
	var band := 20.0 if drawn > 0 else (y1 - y0) * 0.5
	draw_string(font, Vector2((w - tw) * 0.5, y0 + band), label,
		HORIZONTAL_ALIGNMENT_LEFT, -1, size, Color(0.62, 0.68, 0.76, 0.85))


func _draw_ghosts(enemy: int) -> int:
	if ghosts.is_empty():
		return 0
	var font := ThemeDB.fallback_font
	var drawn := 0
	for g in ghosts:
		var cell: Vector2i = g.cell
		if not board.can_deploy(enemy, cell):
			continue
		var d: UnitData = g.data
		var body := Rect2(Vector2(cell) * tile_size + Vector2(9, 9),
			Vector2(tile_size - 18, tile_size - 18))
		var fill: Color = d.accent
		fill.a = 0.26
		draw_rect(body, fill, true)
		var edge: Color = d.accent
		edge.a = 0.62
		draw_rect(body, edge, false, 1.5)

		var initial := String(d.display_name).substr(0, 1).to_upper()
		var iw := font.get_string_size(initial, HORIZONTAL_ALIGNMENT_LEFT, -1, 24).x
		draw_string(font, body.get_center() + Vector2(-iw * 0.5, 8.0), initial,
			HORIZONTAL_ALIGNMENT_LEFT, -1, 24, Color(0.88, 0.91, 0.96, 0.60))
		var tt := "T%d" % d.tier
		draw_string(font, body.position + Vector2(3.0, 13.0), tt,
			HORIZONTAL_ALIGNMENT_LEFT, -1, 11,
			Color(UnitView.tier_color(d.tier), 0.75))
		drawn += 1
	return drawn


func _draw_shots() -> void:
	for shot in _shots:
		var t: float = 1.0 - clampf(shot.left / shot.total, 0.0, 1.0)
		var head: Vector2 = shot.from.lerp(shot.to, t)
		var tail: Vector2 = shot.from.lerp(shot.to, maxf(t - 0.22, 0.0))
		draw_line(tail, head, Color(shot.color, 0.35), 2.0)
		draw_line(head.lerp(tail, 0.45), head, shot.color, 3.0)
		draw_circle(head, 2.6, shot.color)


func _draw_beams() -> void:
	if _beams.is_empty():
		return
	for beam in _beams:
		var t: float = clampf(beam.left / beam.total, 0.0, 1.0)
		var k: float = beam.width
		var end: Vector2 = beam.from + beam.dir * float(beam.span)
		var core: Color = beam.color
		var halo: Color = beam.color
		# Wide, soft, and fading; a thin bright core stays legible to the end.
		halo.a = 0.26 * t
		draw_line(beam.from, end, halo, (tile_size * 0.92 * t + 8.0) * k)
		halo.a = 0.46 * t
		draw_line(beam.from, end, halo, (tile_size * 0.44 * t + 5.0) * k)
		core.a = t
		draw_line(beam.from, end, core, (10.0 * t + 3.0) * k)
		draw_line(beam.from, end, Color(1, 1, 1, t), maxf(4.0 * k, 1.5))
		draw_circle(beam.from, (14.0 * t + 4.0) * k, Color(1, 1, 1, 0.85 * t))


func _draw_floaters() -> void:
	if _floaters.is_empty():
		return
	var font := ThemeDB.fallback_font
	for f in _floaters:
		var big := bool(f.get("big", false))
		# A crit lives longer, so its fade has to be measured against ITS lifetime
		# rather than the standard one, or it snaps from opaque to gone.
		var span := DMG_LIFE * (1.35 if big else 1.0)
		var t: float = clampf(f.left / span, 0.0, 1.0)
		var rise := (1.0 - t) * tile_size * 0.55
		var col: Color = f.color
		col.a = t if t > 0.45 else t / 0.45
		var size := 25 if big else 17
		var w := font.get_string_size(f.text, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
		var at: Vector2 = f.pos + Vector2(f.drift * (1.0 - t) - w * 0.5, -rise)
		draw_string(font, at + Vector2(1, 1), f.text,
			HORIZONTAL_ALIGNMENT_LEFT, -1, size, Color(0, 0, 0, col.a * 0.7))
		draw_string(font, at, f.text, HORIZONTAL_ALIGNMENT_LEFT, -1, size, col)


func _draw_grid() -> void:
	# Drawn per tile rather than as full-length lines, so the edge of a hole in
	# the board reads as an edge instead of a continuous rule across nothing.
	for y in BoardModel.HEIGHT:
		for x in BoardModel.WIDTH:
			var cell := Vector2i(x, y)
			if BoardModel.is_void(cell):
				continue
			draw_rect(Rect2(Vector2(x, y) * tile_size,
				Vector2(tile_size, tile_size)), COL_GRID, false, 1.0)


func _draw_wall(r: Rect2, breakable := false, left := 1.0) -> void:
	draw_rect(r.grow(-2.0), COL_WALL, true)
	draw_rect(r.grow(-2.0), COL_WALL_EDGE, false, 2.0)
	var step := tile_size * 0.28
	var i := 1
	while i * step < tile_size:
		var d := i * step
		draw_line(r.position + Vector2(d, 0.0), r.position + Vector2(0.0, d),
			Color(COL_WALL_EDGE, 0.35), 1.0)
		i += 1
	if not breakable:
		return
	# Breakable stone reads as courses of brick rather than solid rock. It has to
	# be obvious at a glance which walls a Sapper can do anything about, because
	# on Three Roads that is the entire decision the map is asking.
	var seam := Color(COL_WALL_EDGE, 0.75)
	var inner := r.grow(-2.0)
	for k in 3:
		var y := inner.position.y + inner.size.y * (float(k) + 1.0) / 4.0
		draw_line(Vector2(inner.position.x, y), Vector2(inner.end.x, y), seam, 1.5)
	for k in 2:
		var y0 := inner.position.y + inner.size.y * (float(k) * 2.0 + 1.0) / 4.0
		var x := inner.get_center().x
		draw_line(Vector2(x, y0), Vector2(x, y0 + inner.size.y * 0.25), seam, 1.5)
	if left >= 0.999:
		return
	# Damage eats the wall from the top down, so a tile that is nearly through
	# reads as a gap opening rather than as a slightly different shade of grey.
	# Somebody digging is the most important thing on the board while it happens.
	var gone := inner.size.y * (1.0 - clampf(left, 0.0, 1.0))
	var hole := Rect2(inner.position, Vector2(inner.size.x, gone))
	draw_rect(hole, _tile_color(Vector2i(-1, -1)), true)
	draw_line(Vector2(inner.position.x, inner.position.y + gone),
		Vector2(inner.end.x, inner.position.y + gone),
		Color(0.92, 0.74, 0.42, 0.95), 2.0)


func _draw_high(r: Rect2) -> void:
	# A chevron pointing up: the same mark whichever half it is on.
	var mid := r.get_center()
	var w := tile_size * 0.22
	var h := tile_size * 0.13
	for k in 2:
		var lift := mid.y + h * 1.6 * (float(k) - 0.5)
		draw_polyline([
			Vector2(mid.x - w, lift + h),
			Vector2(mid.x, lift - h),
			Vector2(mid.x + w, lift + h),
		] as PackedVector2Array, COL_HIGH_MARK, 2.0)


func _draw_stairs(r: Rect2) -> void:
	# Three rungs climbing the tile. Deliberately not the terrace's chevron: a
	# staircase is the one tile on the board whose rule is about which way you are
	# going, and a ladder reads that way where an arrow does not.
	var inset := tile_size * 0.22
	for k in 3:
		var y := r.position.y + tile_size * (0.32 + 0.18 * float(k))
		draw_line(Vector2(r.position.x + inset, y),
			Vector2(r.end.x - inset, y), COL_STAIRS_MARK, 2.0)


func _draw_barriers() -> void:
	if board == null:
		return
	for y in BoardModel.HEIGHT:
		for x in BoardModel.WIDTH:
			var c := Vector2i(x, y)
			var right := c + Vector2i(1, 0)
			var down := c + Vector2i(0, 1)
			if BoardModel.blocks_between(c, right):
				var px := float(x + 1) * tile_size
				_draw_barrier(Vector2(px, float(y) * tile_size),
					Vector2(px, float(y + 1) * tile_size))
			if BoardModel.blocks_between(c, down):
				var py := float(y + 1) * tile_size
				_draw_barrier(Vector2(float(x) * tile_size, py),
					Vector2(float(x + 1) * tile_size, py))


func _draw_barrier(from: Vector2, to: Vector2) -> void:
	draw_line(from, to, Color(0.05, 0.05, 0.07, 0.9), 7.0)
	draw_line(from, to, COL_BARRIER, 4.0)


func _tile_color(cell: Vector2i) -> Color:
	if BoardModel.is_wall(cell):
		return COL_WALL
	if BoardModel.is_high(cell):
		return COL_HIGH
	if BoardModel.is_stairs(cell):
		return COL_STAIRS
	if board != null and board.is_neutral(cell):
		return COL_NEUTRAL
	if board != null and board.can_deploy(player_team, cell):
		return COL_DEPLOY
	return COL_TILE if (cell.x + cell.y) % 2 == 0 else COL_TILE_ALT


func _draw_dashed(from: Vector2, to: Vector2) -> void:
	var dash := 10.0
	var gap := 7.0
	var dir := (to - from).normalized()
	var total := from.distance_to(to)
	var travelled := 0.0
	while travelled < total:
		var seg := minf(dash, total - travelled)
		draw_line(from + dir * travelled, from + dir * (travelled + seg),
			Color(0.85, 0.70, 0.42, 0.75), 2.0)
		travelled += dash + gap
