class_name BuffBar
extends Control

const LABEL_SIZE := 12
const CHIP_SIZE := 13
const CHIP_PAD := 9.0
const CHIP_GAP := 6.0
const CHIP_HEIGHT := 22.0
const LABEL_GAP := 8.0
const HOVER_GROW := 3.0
const TOOLTIP_WIDTH := 300.0

var heading := "Your buffs"
var accent := Color(0.38, 0.66, 0.69)
var active := false
var _entries: Array[Dictionary] = []
var _chips: Array[Rect2] = []


func _ready() -> void:
	resized.connect(_relayout)


func set_active(value: bool) -> void:
	if active == value:
		return
	active = value
	_relayout()


func set_picks(picks: Array[Dictionary], present: Dictionary = {}) -> void:
	_entries.clear()
	for p in picks:
		var buff: BuffData = p.buff
		var live := TeamBuffs.is_live(buff, present)
		_entries.append({
			text = buff.display_name,
			shown = buff.display_name,
			color = BuffData.rarity_color(p.rarity),
			rarity = BuffData.rarity_name(p.rarity),
			detail = buff.describe(p.rarity),
			scope = "All units" if buff.is_global() else String(buff.unit_id).capitalize(),
			live = live,
			idle_reason = "" if live else TeamBuffs.why_idle(buff, present),
		})
	_relayout()


func _relayout() -> void:
	_chips.clear()
	if _entries.is_empty():
		queue_redraw()
		return

	var font := ThemeDB.fallback_font
	var x := _label_width() + LABEL_GAP
	var widths := chip_widths(font, size.x - x)
	var top := size.y * 0.5 - CHIP_HEIGHT * 0.5

	for i in _entries.size():
		var text: String = _fit(font, _entries[i].text, widths[i] - CHIP_PAD * 2.0)
		_entries[i].shown = text
		var text_w := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, CHIP_SIZE).x
		_chips.append(Rect2(x, top, text_w + CHIP_PAD * 2.0, CHIP_HEIGHT))
		x += text_w + CHIP_PAD * 2.0 + CHIP_GAP

	queue_redraw()


func label_text() -> String:
	return "> %s" % heading if active else heading


func _label_width() -> float:
	var font := ThemeDB.fallback_font
	return font.get_string_size(label_text(), HORIZONTAL_ALIGNMENT_LEFT, -1, LABEL_SIZE).x


func _get_tooltip(at_position: Vector2) -> String:
	for i in _chips.size():
		if _chips[i].grow(HOVER_GROW).has_point(at_position):
			var e: Dictionary = _entries[i]
			var tip := "%s — %s\n%s\n%s" % [e.text, e.rarity, e.scope, e.detail]
			if not bool(e.live) and not String(e.idle_reason).is_empty():
				tip += "\n\n%s" % e.idle_reason
			return tip
	return ""


func _make_custom_tooltip(for_text: String) -> Object:
	return TipPanel.build(for_text, TOOLTIP_WIDTH)


func _draw() -> void:
	var font := ThemeDB.fallback_font
	var mid := size.y * 0.5

	if active:
		var glow := accent
		glow.a = 0.13
		draw_rect(Rect2(-6.0, 0.0, size.x + 12.0, size.y), glow, true)

	var dim := accent
	dim.a = 1.0 if active else 0.75
	draw_string(font, Vector2(0.0, mid + LABEL_SIZE * 0.38), label_text(),
		HORIZONTAL_ALIGNMENT_LEFT, -1, LABEL_SIZE, dim)

	if _entries.is_empty():
		draw_string(font, Vector2(_label_width() + LABEL_GAP, mid + LABEL_SIZE * 0.38),
			"none yet", HORIZONTAL_ALIGNMENT_LEFT, -1, LABEL_SIZE,
			Color(0.45, 0.49, 0.57))
		return

	for i in _chips.size():
		var e: Dictionary = _entries[i]
		var chip: Rect2 = _chips[i]
		var live := bool(e.live)
		var edge: Color = e.color if live else grey_out(e.color)
		var fill := edge
		fill.a = 0.18 if live else 0.07
		draw_rect(chip, fill, true)
		draw_rect(chip, edge, false, 1.5)
		draw_string(font, Vector2(chip.position.x + CHIP_PAD, mid + CHIP_SIZE * 0.36),
			e.shown, HORIZONTAL_ALIGNMENT_LEFT, -1, CHIP_SIZE, edge)


static func grey_out(c: Color) -> Color:
	var flat := Color(0.42, 0.45, 0.51)
	var out := c.lerp(flat, 0.78)
	out.a = 0.55
	return out


func chip_widths(font: Font, available: float) -> Array[float]:
	var n := _entries.size()
	var natural: Array[float] = []
	var total := 0.0
	for e in _entries:
		var w: float = font.get_string_size(
			e.text, HORIZONTAL_ALIGNMENT_LEFT, -1, CHIP_SIZE).x + CHIP_PAD * 2.0
		natural.append(w)
		total += w

	var room := available - CHIP_GAP * maxf(n - 1, 0)
	if total <= room or n == 0:
		return natural

	var order: Array[int] = []
	for i in n:
		order.append(i)
	order.sort_custom(func(a, b): return natural[a] < natural[b])

	var out: Array[float] = []
	out.resize(n)
	var left := room
	var remaining := n
	for i in order:
		var share := left / float(remaining)
		var w: float = minf(natural[i], share)
		out[i] = w
		left -= w
		remaining -= 1
	return out


static func _fit(font: Font, text: String, room: float) -> String:
	if room <= 0.0:
		return ""
	if font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, CHIP_SIZE).x <= room:
		return text
	var cut := text
	while cut.length() > 1:
		cut = cut.substr(0, cut.length() - 1)
		var probe := cut + "…"
		if font.get_string_size(probe, HORIZONTAL_ALIGNMENT_LEFT, -1, CHIP_SIZE).x <= room:
			return probe
	return "…"
