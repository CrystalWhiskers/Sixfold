class_name ForceBar
extends Control

const LABEL_SIZE := 13
const TRACK_INSET := 3.0
const MIN_SLIVER := 0.0

var mine_name := "You"
var theirs_name := "Them"
var mine_color := Color(0.38, 0.66, 0.69)
var theirs_color := Color(0.83, 0.63, 0.39)

var mine := 0
var theirs := 0
var vertical := false


func set_counts(p_mine: int, p_theirs: int) -> void:
	var a := maxi(p_mine, 0)
	var b := maxi(p_theirs, 0)
	if a == mine and b == theirs:
		return
	mine = a
	theirs = b
	queue_redraw()


func total() -> int:
	return mine + theirs


func mine_share() -> float:
	# A wiped side gets exactly none of the bar, so a finished round reads as one
	# solid colour rather than a sliver of the loser.
	if total() <= 0:
		return 0.5
	return float(mine) / float(total())


func _draw() -> void:
	var track := Rect2(Vector2.ZERO, size).grow(-TRACK_INSET)
	draw_rect(track.grow(1.5), Color(0.03, 0.04, 0.06, 0.92), true)
	draw_rect(track, Color(0.11, 0.13, 0.17), true)
	if vertical:
		_draw_vertical(track)
	else:
		_draw_horizontal(track)


func _draw_horizontal(track: Rect2) -> void:
	var font := ThemeDB.fallback_font
	var split: float = track.size.x * mine_share()
	if mine > 0:
		draw_rect(Rect2(track.position, Vector2(split, track.size.y)),
			_fill(mine_color), true)
	if theirs > 0:
		draw_rect(Rect2(track.position + Vector2(split, 0.0),
			Vector2(track.size.x - split, track.size.y)), _fill(theirs_color), true)

	if mine > 0 and theirs > 0:
		var x := track.position.x + split
		draw_line(Vector2(x, track.position.y),
			Vector2(x, track.position.y + track.size.y),
			Color(0.04, 0.05, 0.07, 0.85), 2.0)

	var baseline := track.position.y + track.size.y * 0.5 + LABEL_SIZE * 0.38
	var left := "%s %d" % [mine_name, mine]
	draw_string(font, Vector2(track.position.x + 8.0, baseline), left,
		HORIZONTAL_ALIGNMENT_LEFT, -1, LABEL_SIZE, _ink(mine > 0))

	var right := "%d %s" % [theirs, theirs_name]
	var w := font.get_string_size(right, HORIZONTAL_ALIGNMENT_LEFT, -1, LABEL_SIZE).x
	draw_string(font, Vector2(track.position.x + track.size.x - w - 8.0, baseline),
		right, HORIZONTAL_ALIGNMENT_LEFT, -1, LABEL_SIZE, _ink(theirs > 0))


func _draw_vertical(track: Rect2) -> void:
	# Beside the board, so it reads the way the board does: your half fills from
	# the bottom, theirs presses down from the top.
	var font := ThemeDB.fallback_font
	var mine_h: float = track.size.y * mine_share()
	var split_y: float = track.position.y + track.size.y - mine_h
	if theirs > 0:
		draw_rect(Rect2(track.position, Vector2(track.size.x, split_y - track.position.y)),
			_fill(theirs_color), true)
	if mine > 0:
		draw_rect(Rect2(Vector2(track.position.x, split_y),
			Vector2(track.size.x, mine_h)), _fill(mine_color), true)

	if mine > 0 and theirs > 0:
		draw_line(Vector2(track.position.x, split_y),
			Vector2(track.position.x + track.size.x, split_y),
			Color(0.04, 0.05, 0.07, 0.85), 2.0)

	_stacked(font, "%d" % theirs, theirs_name,
		track.position.y + 6.0, track, _ink(theirs > 0))
	_stacked(font, "%d" % mine, mine_name,
		track.position.y + track.size.y - 34.0, track, _ink(mine > 0))


func _stacked(font: Font, count: String, who: String, top: float,
		track: Rect2, ink: Color) -> void:
	_centred(font, count, top + LABEL_SIZE, track, ink, LABEL_SIZE + 3)
	_centred(font, who, top + LABEL_SIZE * 2.2, track, ink, LABEL_SIZE - 2)


func _centred(font: Font, text: String, baseline: float, track: Rect2,
		ink: Color, size: int) -> void:
	var w := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
	draw_string(font, Vector2(track.position.x + (track.size.x - w) * 0.5, baseline),
		text, HORIZONTAL_ALIGNMENT_LEFT, -1, size, ink)


static func _fill(c: Color) -> Color:
	var out := c
	out.a = 0.72
	return out


static func _ink(alive: bool) -> Color:
	return Color(0.05, 0.06, 0.09, 0.92) if alive else Color(0.55, 0.60, 0.68)
