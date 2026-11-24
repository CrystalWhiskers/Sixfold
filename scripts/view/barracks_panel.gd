class_name BarracksPanel
extends Control

## The Barracks on screen: a panel of its own under the battlefield, deliberately
## not styled like the board — warm wood and brass rather than tiles — because it is
## not a place units fight. Three sections side by side, one per zone, each a grid
## of slots with a Recruit button; Supply and the income upgrade along the
## top. Drag a unit onto an empty slot to move it, onto its twin to merge, onto
## anything else to swap. Everything here takes effect from the next wave.

signal changed(message: String)

const SLOT := 36.0
const GAP := 4.0
const SECTION_W := 226.0
const BG := Color(0.17, 0.12, 0.08, 0.96)
const RIM := Color(0.72, 0.56, 0.30)
const SLOT_BG := Color(0.26, 0.19, 0.12)
const INK := Color(0.96, 0.90, 0.76)
const ZONE_TINTS := [Color(0.45, 0.65, 0.95), Color(0.50, 0.85, 0.55), Color(0.80, 0.55, 0.95)]

var barracks: Barracks = null
var _drag_from := Vector2i(-1, -1)
var _drag_at := Vector2.ZERO
var _header: Label = null
var _income_btn: Button = null
var _recruit_btns: Array[Button] = []
var _type_btns: Array[Button] = []
## Where the upgrade bar starts, below the three sections.
const BAR_Y := 230.0


func setup(p_barracks: Barracks) -> void:
	barracks = p_barracks
	mouse_filter = Control.MOUSE_FILTER_STOP
	_header = Label.new()
	_header.position = Vector2(12, 6)
	_header.add_theme_font_size_override("font_size", 16)
	_header.add_theme_color_override("font_color", INK)
	add_child(_header)
	_income_btn = Button.new()
	_income_btn.position = Vector2(size.x - 230, 4)
	_income_btn.size = Vector2(218, 28)
	_income_btn.add_theme_font_size_override("font_size", 13)
	_income_btn.pressed.connect(_on_income)
	add_child(_income_btn)
	for s in Barracks.SECTIONS:
		var x := 10.0 + float(s) * (SECTION_W + 8.0) + _grid_w() + 8.0
		var r := Button.new()
		r.position = Vector2(x, 60)
		r.size = Vector2(SECTION_W - _grid_w() - 12.0, 40)
		r.add_theme_font_size_override("font_size", 12)
		r.pressed.connect(_on_recruit.bind(s))
		add_child(r)
		_recruit_btns.append(r)
	# The upgrade bar: one button per unit type in the loadout. A level reaches every
	# copy of that unit — the ones fighting now and every wave after.
	var n := maxi(barracks.types.size(), 1)
	var w := (size.x - 20.0 - float(n - 1) * 6.0) / float(n)
	for i in barracks.types.size():
		var t := Button.new()
		t.position = Vector2(10.0 + float(i) * (w + 6.0), BAR_Y)
		t.size = Vector2(w, 46)
		t.add_theme_font_size_override("font_size", 12)
		t.pressed.connect(_on_upgrade.bind(i))
		add_child(t)
		_type_btns.append(t)
	refresh()


func _grid_w() -> float:
	return float(barracks.data.section_cols) * (SLOT + GAP)


func slot_rect(section: int, slot: int) -> Rect2:
	var col := slot % barracks.data.section_cols
	var row := slot / barracks.data.section_cols
	var origin := Vector2(10.0 + float(section) * (SECTION_W + 8.0), 60.0)
	return Rect2(origin + Vector2(col, row) * (SLOT + GAP), Vector2(SLOT, SLOT))


func slot_at(p: Vector2) -> Vector2i:
	for s in Barracks.SECTIONS:
		for i in barracks.slot_count():
			if slot_rect(s, i).has_point(p):
				return Vector2i(s, i)
	return Vector2i(-1, -1)


func refresh() -> void:
	if barracks == null:
		return
	var grow := barracks.next_passive_in()
	_header.text = "BARRACKS   Supply %d   (+%.0f/s%s)" % [floori(barracks.supply), barracks.income,
		("  ·  +%.0f in %ds" % [barracks.data.passive_income, ceili(grow)]) if not is_inf(grow) else ""]
	_income_btn.text = ("Income MAX  (%d/%d)" % [barracks.income_level, barracks.data.income_max_level]
		if barracks.income_maxed() else "Income +%.0f/s  (%d)  %d/%d" % [barracks.data.income_step,
		ceili(barracks.income_price()), barracks.income_level, barracks.data.income_max_level])
	_income_btn.disabled = barracks.supply < barracks.income_price()
	for s in Barracks.SECTIONS:
		_recruit_btns[s].text = "Recruit\n%d" % ceili(barracks.recruit_price())
		_recruit_btns[s].disabled = (barracks.supply < barracks.recruit_price()
			or barracks.free_slot(s) < 0)
	for i in _type_btns.size():
		var t: UnitData = barracks.types[i]
		var lv := barracks.level_of(t.id)
		var price := barracks.upgrade_price(t.id)
		_type_btns[i].text = ("%s  Lv%d\n%s" % [UnitView.short_name(t), lv,
			"MAX" if is_inf(price) else "Up: %d" % ceili(price)])
		_type_btns[i].disabled = is_inf(price) or barracks.supply < price
		var tip := "%s — Lv%d" % [t.display_name, lv]
		if lv < barracks.max_level():
			tip += "\nNext, Lv%d (and +%d%% health and attack):" % [lv + 1,
				roundi(barracks.data.upgrade_stat_per_level * 100.0)]
			for line in barracks.level_changes(t, lv + 1):
				tip += "\n  • " + line
		else:
			tip += " (maxed)"
		_type_btns[i].tooltip_text = tip
	queue_redraw()


func _draw() -> void:
	var box := StyleBoxFlat.new()
	box.bg_color = BG
	box.border_color = RIM
	box.set_border_width_all(3)
	box.set_corner_radius_all(10)
	draw_style_box(box, Rect2(Vector2.ZERO, size))
	if barracks == null:
		return
	var font := ThemeDB.fallback_font
	for s in Barracks.SECTIONS:
		var tint: Color = ZONE_TINTS[s]
		var title := "%s  ·  %d units" % [BossFight.ZONE_NAMES[s], barracks.unit_count(s)]
		draw_string(font, Vector2(10.0 + float(s) * (SECTION_W + 8.0), 52.0), title,
			HORIZONTAL_ALIGNMENT_LEFT, -1, 14, tint)
		for i in barracks.slot_count():
			var r := slot_rect(s, i)
			draw_rect(r, SLOT_BG, true)
			draw_rect(r, Color(tint, 0.45), false, 1.5)
			var d := barracks.at(s, i)
			if d == null or Vector2i(s, i) == _drag_from:
				continue
			_draw_unit(r, d)
	if _drag_from.x >= 0:
		var d := barracks.at(_drag_from.x, _drag_from.y)
		if d != null:
			_draw_unit(Rect2(_drag_at - Vector2(SLOT, SLOT) * 0.5, Vector2(SLOT, SLOT)), d)


func _draw_unit(r: Rect2, d: UnitData) -> void:
	var font := ThemeDB.fallback_font
	var inner := r.grow(-2.0)
	var ink := UnitView.tier_ink(d.tier)
	# The plate a little darker than on the board, so the tier-coloured letters on it
	# stand out; the rim in the same colour as the letters, heavier the higher it is.
	draw_rect(inner, d.accent.lerp(Color(0.10, 0.11, 0.14), 0.6), true)
	draw_rect(inner, ink, false, 1.5 + 0.4 * float(d.tier))
	var label := UnitView.short_name(d)
	var fs := 12
	var lw := font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	var at := inner.position + Vector2((inner.size.x - lw) * 0.5, inner.size.y - 6)
	draw_string_outline(font, at, label, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, 4, Color(0, 0, 0, 0.95))
	draw_string(font, at, label, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, ink)
	# The tier as a badge in the top-left corner, its number in black.
	var badge := inner.position + Vector2(7, 7)
	draw_circle(badge, 7.2, Color(0, 0, 0, 0.9))
	draw_circle(badge, 6.0, ink)
	var tw := font.get_string_size(str(d.tier), HORIZONTAL_ALIGNMENT_LEFT, -1, 10).x
	draw_string(font, badge + Vector2(-tw * 0.5, 3.6), str(d.tier),
		HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color(0.02, 0.02, 0.04))


func _gui_input(event: InputEvent) -> void:
	if barracks == null:
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		var at := slot_at(event.position)
		if event.pressed:
			if at.x >= 0 and barracks.at(at.x, at.y) != null:
				_drag_from = at
				_drag_at = event.position
				Audio.play_pickup()
				queue_redraw()
		elif _drag_from.x >= 0:
			var from := _drag_from
			_drag_from = Vector2i(-1, -1)
			if at.x >= 0:
				var what := barracks.drop(from.x, from.y, at.x, at.y)
				if what == "merged":
					Audio.play_merge()
					changed.emit("Merged into %s — from the next wave." %
						barracks.at(at.x, at.y).display_name)
				elif not what.is_empty():
					changed.emit("%s — from the next wave." % what.capitalize())
			refresh()
		accept_event()
	elif event is InputEventMouseMotion and _drag_from.x >= 0:
		_drag_at = event.position
		queue_redraw()


func _on_recruit(section: int) -> void:
	if barracks.recruit(section):
		Audio.play_recruit()
		var d := barracks.at(section, _last_filled(section))
		changed.emit("Recruited %s into %s — joins the next wave." % [
			d.display_name if d != null else "a unit", BossFight.ZONE_NAMES[section]])
	refresh()


func _last_filled(section: int) -> int:
	var last := -1
	for i in barracks.slot_count():
		if barracks.at(section, i) != null:
			last = i
	return last



func _on_income() -> void:
	if barracks.upgrade_income():
		Audio.play_upgrade()
		changed.emit("Supply now +%.0f a second." % barracks.income)
	refresh()


func _on_upgrade(index: int) -> void:
	var t: UnitData = barracks.types[index]
	if barracks.upgrade_type(t.id):
		Audio.play_upgrade()
		changed.emit("%s upgraded to Lv%d — every %s on the field and in every wave." % [
			t.display_name, barracks.level_of(t.id), t.display_name])
	refresh()
