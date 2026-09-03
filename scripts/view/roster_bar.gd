class_name RosterBar
extends Control

const LABEL_SIZE := 12
const CHIP_SIZE := 12
const CHIP_PAD := 7.0
const CHIP_GAP := 5.0
const CHIP_HEIGHT := 20.0
const LABEL_GAP := 8.0
const HOVER_GROW := 3.0
const TOOLTIP_WIDTH := 320.0

var heading := "Roster"
var accent := Color(0.38, 0.66, 0.69)

var _entries: Array[Dictionary] = []
var _chips: Array[Rect2] = []


func _ready() -> void:
	resized.connect(_relayout)


func set_units(units: Array[UnitData]) -> void:
	# Repeats are the point of a loadout, so they collapse into one chip with a
	# count rather than five chips that say the same thing.
	_entries.clear()
	var seen := {}
	for u in units:
		if u == null:
			continue
		var key := String(u.id)
		if seen.has(key):
			var at: int = seen[key]
			_entries[at].count += 1
			continue
		seen[key] = _entries.size()
		_entries.append({data = u, count = 1, shown = u.display_name})
	_relayout()


func chip_label(entry: Dictionary) -> String:
	var d: UnitData = entry.data
	if int(entry.count) <= 1:
		return d.display_name
	return "%s x%d" % [d.display_name, int(entry.count)]


func _relayout() -> void:
	_chips.clear()
	var font := ThemeDB.fallback_font
	var x := _label_width() + LABEL_GAP
	var top := size.y * 0.5 - CHIP_HEIGHT * 0.5
	for e in _entries:
		var text := chip_label(e)
		e.shown = text
		var w := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, CHIP_SIZE).x
		_chips.append(Rect2(x, top, w + CHIP_PAD * 2.0, CHIP_HEIGHT))
		x += w + CHIP_PAD * 2.0 + CHIP_GAP
	queue_redraw()


func _label_width() -> float:
	var font := ThemeDB.fallback_font
	return font.get_string_size(heading, HORIZONTAL_ALIGNMENT_LEFT, -1, LABEL_SIZE).x


func _get_tooltip(at_position: Vector2) -> String:
	for i in _chips.size():
		if _chips[i].grow(HOVER_GROW).has_point(at_position):
			return UnitCodex.card(_entries[i].data)
	return ""


func _make_custom_tooltip(for_text: String) -> Object:
	return TipPanel.build(for_text, TOOLTIP_WIDTH)


func _draw() -> void:
	var font := ThemeDB.fallback_font
	var mid := size.y * 0.5

	var dim := accent
	dim.a = 0.85
	draw_string(font, Vector2(0.0, mid + LABEL_SIZE * 0.38), heading,
		HORIZONTAL_ALIGNMENT_LEFT, -1, LABEL_SIZE, dim)

	if _entries.is_empty():
		draw_string(font, Vector2(_label_width() + LABEL_GAP, mid + LABEL_SIZE * 0.38),
			"no units", HORIZONTAL_ALIGNMENT_LEFT, -1, LABEL_SIZE,
			Color(0.45, 0.49, 0.57))
		return

	for i in _chips.size():
		var e: Dictionary = _entries[i]
		var chip: Rect2 = _chips[i]
		var d: UnitData = e.data
		var edge: Color = d.accent
		var fill := edge
		fill.a = 0.20
		draw_rect(chip, fill, true)
		draw_rect(chip, edge, false, 1.5)
		draw_string(font, Vector2(chip.position.x + CHIP_PAD, mid + CHIP_SIZE * 0.36),
			e.shown, HORIZONTAL_ALIGNMENT_LEFT, -1, CHIP_SIZE,
			Color(0.92, 0.94, 0.97))
