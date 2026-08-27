## Draws the 6x11 grid and owns the UnitView children. Holds zero rules —
## every legality question goes to BoardModel.
##
## Local origin is the top-left corner of tile (0, 0), so cell maths stays trivial.
class_name BoardView
extends Node2D

signal cell_pressed(cell: Vector2i)
signal drag_dropped(from: Vector2i, to: Vector2i)

const UNIT_VIEW := preload("res://scenes/units/unit_view.tscn")

@export var tile_size := 84.0
## The side the human plays. Their deploy zone gets the highlight.
@export var player_team := BoardModel.TEAM_B
@export var interactive := true

## Fog is a PREP-PHASE mechanic only. You arrange blind, then it lifts when the
## fight starts and you watch the whole battle.
##
## It is implemented by not building UnitViews for concealed units at all, rather
## than by drawing something opaque over them. That distinction matters: a black
## rectangle on top still leaves every enemy position sitting in the scene tree
## for anyone who cares to look, which is worthless the moment this is PvP.
var fog := false

## Whether the fog reports how many units the opponent is fielding.
## false — total blackout: you learn nothing about their half until you commit.
## true  — you'd know the size of what's coming, never its shape.
const FOG_SHOWS_COUNT := false

var board: BoardModel = null

var _views: Dictionary = {}          ## uid -> UnitView
var _hover := Vector2i(-1, -1)
var _drag_uid := -1
var _drag_from := Vector2i(-1, -1)
var _drag_pos := Vector2.ZERO
var _flashes: Array[Dictionary] = []
var _floaters: Array[Dictionary] = []  ## Damage numbers rising off a hit.
var _shots: Array[Dictionary] = []     ## Projectiles in flight.
var _dying: Array[UnitView] = []       ## Views playing out their death.

# Palette. Deliberately flat — swap freely, nothing depends on these.
const COL_TILE := Color(0.13, 0.16, 0.21)
const COL_TILE_ALT := Color(0.15, 0.18, 0.24)
const COL_DEPLOY := Color(0.18, 0.24, 0.28)
const COL_NEUTRAL := Color(0.24, 0.20, 0.14)
const COL_GRID := Color(0.28, 0.32, 0.40, 0.9)
const COL_HOVER := Color(1, 1, 1, 0.10)
const COL_LEGAL := Color(0.45, 0.75, 0.50, 0.18)
const COL_SHOT := Color(0.93, 0.88, 0.66)
const COL_SHOT_SPELL := Color(0.98, 0.66, 0.30)
const COL_DMG := Color(0.97, 0.95, 0.90)
const COL_DMG_SPELL := Color(0.98, 0.72, 0.34)
const DMG_LIFE := 0.75
const COL_FOG := Color(0.09, 0.10, 0.13)
const COL_FOG_HATCH := Color(0.20, 0.23, 0.29, 0.55)


func board_size() -> Vector2:
	return Vector2(BoardModel.WIDTH, BoardModel.HEIGHT) * tile_size


func cell_to_pos(cell: Vector2i) -> Vector2:
	return Vector2(cell.x + 0.5, cell.y + 0.5) * tile_size


func pos_to_cell(pos: Vector2) -> Vector2i:
	return Vector2i(floori(pos.x / tile_size), floori(pos.y / tile_size))


func bind(p_board: BoardModel) -> void:
	board = p_board
	rebuild()


# ---------------------------------------------------------------- unit views

## Rebuilds every UnitView from the model. Cheap at this board size, and it
## means the screen can never drift out of sync with the board.
func rebuild() -> void:
	for uid in _views.keys():
		# remove_child() before queue_free(): freeing is deferred to the end of
		# the frame, so several rebuilds in one frame (placing a whole bench, say)
		# would otherwise stack duplicate views in the tree until it ends.
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
	if board == null:
		return
	for u in board.all_units():
		if is_concealed(u):
			continue
		_add_view(u)
	queue_redraw()


## True when the player is not allowed to know this unit exists right now.
func is_concealed(u: UnitInstance) -> bool:
	return fog and u.team != player_team


## Raise or lower the fog. Rebuilds, so concealed units are added or dropped
## from the tree rather than merely hidden.
func set_fog(enabled: bool) -> void:
	if fog == enabled:
		return
	fog = enabled
	rebuild()


## Count of enemy units, for the fog readout. Deliberately the ONLY thing that
## leaks across the fog — a number, never a position or a type.
func concealed_count() -> int:
	if board == null:
		return 0
	return board.living_units_of(BoardModel.enemy_of(player_team)).size()


func _add_view(u: UnitInstance) -> UnitView:
	var v: UnitView = UNIT_VIEW.instantiate()
	v.tile_size = tile_size
	add_child(v)
	v.bind(u)
	v.position = cell_to_pos(u.cell)
	_views[u.uid] = v
	return v


func view_for(uid: int) -> UnitView:
	return _views.get(uid, null)


## Kills a unit visibly: the view leaves the addressable set immediately but
## stays in the tree to play its death out. Use this during battle playback;
## drop_view() is the instant version for teardown.
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


## Snaps every view back to its model cell. Call after any prep-phase change.
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


# ---------------------------------------------------------------- tile flashes

## Temporary tile highlights — spell areas, and later anything else worth
## pointing at. Purely cosmetic; nothing reads these back.
func flash_cells(cells: Array, color: Color, duration: float) -> void:
	_flashes.append({cells = cells.duplicate(), color = color,
		left = duration, total = maxf(duration, 0.01)})
	set_process(true)
	queue_redraw()


## Floating damage number. `world` is a position in this node's local space.
func spawn_damage(world: Vector2, amount: float, spell: bool) -> void:
	if amount <= 0.0:
		return
	_floaters.append({
		pos = world + Vector2(0, -tile_size * 0.30),
		text = str(roundi(amount)),
		color = COL_DMG_SPELL if spell else COL_DMG,
		left = DMG_LIFE,
		drift = randf_range(-9.0, 9.0),
	})
	set_process(true)
	queue_redraw()


## A projectile from `from` to `to`, arriving in `flight` real seconds.
## Purely cosmetic — the sim already decided the damage; this is why the number
## and the health drop wait until it lands.
func spawn_shot(from: Vector2, to: Vector2, flight: float, spell: bool) -> void:
	_shots.append({
		from = from, to = to,
		left = maxf(flight, 0.02), total = maxf(flight, 0.02),
		color = COL_SHOT_SPELL if spell else COL_SHOT,
	})
	set_process(true)
	queue_redraw()


## A short text pop that isn't a damage number — ability names, mostly.
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

	if not busy:
		set_process(false)
	queue_redraw()


# ---------------------------------------------------------------- input

func _unhandled_input(event: InputEvent) -> void:
	if not interactive or board == null:
		return

	if event is InputEventMouseMotion:
		var cell := pos_to_cell(to_local(get_global_mouse_position()))
		if _drag_uid >= 0:
			_drag_pos = to_local(get_global_mouse_position())
			queue_redraw()
		if cell != _hover:
			_hover = cell
			queue_redraw()
		return

	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		var cell := pos_to_cell(to_local(get_global_mouse_position()))
		if event.pressed:
			_begin_drag(cell)
		else:
			_end_drag(cell)


func _begin_drag(cell: Vector2i) -> void:
	if not board.in_bounds(cell):
		return
	var u := board.unit_at(cell)
	cell_pressed.emit(cell)
	if u == null or u.team != player_team:
		return
	_drag_uid = u.uid
	_drag_from = cell
	_drag_pos = cell_to_pos(cell)
	set_dimmed(u.uid, true)
	queue_redraw()


func _end_drag(cell: Vector2i) -> void:
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
	if _drag_uid >= 0:
		set_dimmed(_drag_uid, false)
	_drag_uid = -1
	sync_positions()


func is_dragging() -> bool:
	return _drag_uid >= 0


# ---------------------------------------------------------------- drawing

func _draw() -> void:
	var size := board_size()

	for y in BoardModel.HEIGHT:
		for x in BoardModel.WIDTH:
			var cell := Vector2i(x, y)
			var r := Rect2(Vector2(x, y) * tile_size, Vector2(tile_size, tile_size))
			draw_rect(r, _tile_color(cell), true)

	# Legal destinations, shown only while actually dragging.
	if _drag_uid >= 0:
		for c in board.deploy_cells(player_team):
			draw_rect(Rect2(Vector2(c) * tile_size, Vector2(tile_size, tile_size)),
				COL_LEGAL, true)

	for f in _flashes:
		var fade: float = clampf(f.left / f.total, 0.0, 1.0)
		var col: Color = f.color
		col.a *= fade
		for c in f.cells:
			if board.in_bounds(c):
				draw_rect(Rect2(Vector2(c) * tile_size, Vector2(tile_size, tile_size)), 
					col, true)

	if board.in_bounds(_hover) and _drag_uid < 0:
		draw_rect(Rect2(Vector2(_hover) * tile_size, Vector2(tile_size, tile_size)),
			COL_HOVER, true)

	# Grid lines.
	for x in BoardModel.WIDTH + 1:
		var px := x * tile_size
		draw_line(Vector2(px, 0), Vector2(px, size.y), COL_GRID, 1.0)
	for y in BoardModel.HEIGHT + 1:
		var py := y * tile_size
		draw_line(Vector2(0, py), Vector2(size.x, py), COL_GRID, 1.0)

	# The neutral row reads as contested: a dashed edge top and bottom.
	var ny := BoardModel.NEUTRAL_ROW * tile_size
	_draw_dashed(Vector2(0, ny), Vector2(size.x, ny))
	_draw_dashed(Vector2(0, ny + tile_size), Vector2(size.x, ny + tile_size))

	if fog:
		_draw_fog()

	_draw_shots()
	_draw_floaters()

	# Drag ghost follows the cursor.
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


## Covers the opponent's half while they arrange. Nothing is drawn underneath it —
## the concealed units were never added to the tree in the first place.
func _draw_fog() -> void:
	var enemy := BoardModel.enemy_of(player_team)
	var cells := board.deploy_cells(enemy)
	if cells.is_empty():
		return

	var top := BoardModel.HEIGHT
	var bottom := 0
	for c in cells:
		draw_rect(Rect2(Vector2(c) * tile_size, Vector2(tile_size, tile_size)),
			COL_FOG, true)
		top = mini(top, c.y)
		bottom = maxi(bottom, c.y)

	# Diagonal hatch, so it reads as concealment rather than an empty board.
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

	var label := "hidden until you commit"
	if FOG_SHOWS_COUNT:
		var n := concealed_count()
		label = "%d unit%s hidden" % [n, "" if n == 1 else "s"]
	var font := ThemeDB.fallback_font
	var size := 18
	var tw := font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
	draw_string(font, Vector2((w - tw) * 0.5, (y0 + y1) * 0.5), label,
		HORIZONTAL_ALIGNMENT_LEFT, -1, size, Color(0.62, 0.68, 0.76, 0.85))


## Arrows in flight. A short tapered streak reads better than a dot — you can
## see which way it's going at a glance.
func _draw_shots() -> void:
	for shot in _shots:
		var t: float = 1.0 - clampf(shot.left / shot.total, 0.0, 1.0)
		var head: Vector2 = shot.from.lerp(shot.to, t)
		var tail: Vector2 = shot.from.lerp(shot.to, maxf(t - 0.22, 0.0))
		draw_line(tail, head, Color(shot.color, 0.35), 2.0)
		draw_line(head.lerp(tail, 0.45), head, shot.color, 3.0)
		draw_circle(head, 2.6, shot.color)


## Damage numbers. Drawn by the board rather than spawned as nodes so they
## outlive the unit that took the hit — the killing blow still shows its number.
func _draw_floaters() -> void:
	if _floaters.is_empty():
		return
	var font := ThemeDB.fallback_font
	for f in _floaters:
		var t: float = clampf(f.left / DMG_LIFE, 0.0, 1.0)
		var rise := (1.0 - t) * tile_size * 0.55
		var col: Color = f.color
		col.a = t if t > 0.45 else t / 0.45
		var size := 17
		var w := font.get_string_size(f.text, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
		var at: Vector2 = f.pos + Vector2(f.drift * (1.0 - t) - w * 0.5, -rise)
		draw_string(font, at + Vector2(1, 1), f.text,
			HORIZONTAL_ALIGNMENT_LEFT, -1, size, Color(0, 0, 0, col.a * 0.7))
		draw_string(font, at, f.text, HORIZONTAL_ALIGNMENT_LEFT, -1, size, col)


func _tile_color(cell: Vector2i) -> Color:
	if cell.y == BoardModel.NEUTRAL_ROW:
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
