class_name MapPreview
extends Control

const COL_BACK := Color(0.05, 0.06, 0.09)
const COL_OPEN := Color(0.16, 0.19, 0.25)
const COL_OPEN_ALT := Color(0.19, 0.22, 0.28)
const COL_WALL := Color(0.36, 0.37, 0.43)
const COL_HIGH := Color(0.30, 0.44, 0.33)
const COL_NEUTRAL := Color(0.28, 0.24, 0.17)
const COL_BARRIER := Color(0.80, 0.72, 0.55)
const COL_TOP := Color(0.83, 0.63, 0.39)
const COL_BOTTOM := Color(0.38, 0.66, 0.69)

var map: MapData = null


func set_map(m: MapData) -> void:
	map = m
	queue_redraw()


func cell_size() -> float:
	if map == null or map.width <= 0 or map.height <= 0:
		return 0.0
	return floorf(minf(size.x / float(map.width), size.y / float(map.height)))


func grid_rect() -> Rect2:
	var s := cell_size()
	var span := Vector2(map.width, map.height) * s
	return Rect2(((size - span) * 0.5).round(), span)


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), COL_BACK, true)
	if map == null:
		return
	var s := cell_size()
	if s <= 0.0:
		return
	var origin := grid_rect().position
	var divider := map.half_rows()

	for y in map.height:
		for x in map.width:
			var c := Vector2i(x, y)
			if map.is_void(c):
				continue
			var r := Rect2(origin + Vector2(x, y) * s, Vector2(s, s))
			draw_rect(r, _tile_color(c, divider), true)

	# A thin wash over each half, so which end is yours is obvious at a glance.
	var half_h := float(divider) * s
	var top := Rect2(origin, Vector2(float(map.width) * s, half_h))
	draw_rect(top, Color(COL_TOP, 0.10), true)
	var below := origin + Vector2(0.0, half_h + (s if map.has_neutral else 0.0))
	draw_rect(Rect2(below, Vector2(float(map.width) * s, half_h)),
		Color(COL_BOTTOM, 0.10), true)

	for e in map.lines:
		_draw_barrier(origin, s, Vector2i(e.x, e.y), Vector2i(e.z, e.w))

	draw_rect(grid_rect(), Color(0.34, 0.38, 0.46, 0.8), false, 1.0)


func _tile_color(c: Vector2i, divider: int) -> Color:
	if map.is_wall(c):
		return COL_WALL
	if map.is_high(c):
		return COL_HIGH
	if map.has_neutral and c.y == divider:
		return COL_NEUTRAL
	return COL_OPEN if (c.x + c.y) % 2 == 0 else COL_OPEN_ALT


func _draw_barrier(origin: Vector2, s: float, a: Vector2i, b: Vector2i) -> void:
	var low := a if (a.y < b.y or (a.y == b.y and a.x < b.x)) else b
	if a.y == b.y:
		var px := origin.x + float(low.x + 1) * s
		draw_line(Vector2(px, origin.y + float(low.y) * s),
			Vector2(px, origin.y + float(low.y + 1) * s), COL_BARRIER, 2.0)
	else:
		var py := origin.y + float(low.y + 1) * s
		draw_line(Vector2(origin.x + float(low.x) * s, py),
			Vector2(origin.x + float(low.x + 1) * s, py), COL_BARRIER, 2.0)
