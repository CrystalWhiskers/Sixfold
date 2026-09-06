class_name MapChip
extends Button

## One map in the picker: its shape drawn small, its name under it. Thirty-odd
## maps do not fit behind a pair of arrows, so the picker is a grid of these and
## you choose by looking rather than by clicking through.

const SIZE := Vector2(92.0, 96.0)
const PREVIEW_HEIGHT := 68.0

var map: MapData = null

var _preview: MapPreview = null
var _name: Label = null


func _init() -> void:
	toggle_mode = true
	custom_minimum_size = SIZE
	clip_contents = true
	focus_mode = Control.FOCUS_NONE
	add_theme_stylebox_override("normal", _box(Color(0.10, 0.11, 0.15),
		Color(0.24, 0.27, 0.33)))
	add_theme_stylebox_override("hover", _box(Color(0.14, 0.16, 0.21),
		Color(0.46, 0.50, 0.58)))
	add_theme_stylebox_override("pressed", _box(Color(0.16, 0.16, 0.12),
		Color(0.80, 0.77, 0.60)))
	add_theme_stylebox_override("focus", _box(Color(0, 0, 0, 0), Color(0, 0, 0, 0)))

	_preview = MapPreview.new()
	_preview.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_preview.position = Vector2(5.0, 5.0)
	_preview.size = Vector2(SIZE.x - 10.0, PREVIEW_HEIGHT)
	add_child(_preview)

	_name = Label.new()
	_name.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_name.position = Vector2(3.0, PREVIEW_HEIGHT + 6.0)
	_name.size = Vector2(SIZE.x - 6.0, SIZE.y - PREVIEW_HEIGHT - 8.0)
	_name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_name.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_name.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_name.add_theme_font_size_override("font_size", 10)
	add_child(_name)


func set_map(m: MapData) -> void:
	map = m
	_preview.set_map(m)
	_name.text = "" if m == null else m.display_name
	tooltip_text = "" if m == null else "%s\n%s" % [m.display_name, m.summary()]


func _box(fill: Color, edge: Color) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = fill
	s.border_color = edge
	s.set_border_width_all(1)
	s.set_corner_radius_all(5)
	return s
