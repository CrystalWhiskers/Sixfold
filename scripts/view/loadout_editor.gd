class_name LoadoutEditor
extends Control

signal closed

const PANEL_WIDTH := 640.0
const ROW_HEIGHT := 40.0
const DETAIL_HEIGHT := 176.0
const PREVIEW_SIZE := Vector2(112.0, 112.0)
const GRID_COLUMNS := 6
const GRID_HEIGHT := 216.0
const ICON_SIZE := Vector2(34.0, 34.0)

var _rows: Dictionary = {}
var _summaries: Dictionary = {}
var _detail: Label = null
var _detail_title: Label = null
var _focus: UnitData = null
var _map_label: Label = null
var _map_note: Label = null
var _map_preview: MapPreview = null
var _map_grid: GridContainer = null
var _map_group: ButtonGroup = null
var _chips: Array[MapChip] = []
var _icons: Dictionary = {}
var _detail_icon: UnitIcon = null


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	visible = false

	var shade := ColorRect.new()
	shade.color = Color(0.04, 0.05, 0.08, 0.96)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shade.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(shade)

	var frame := MarginContainer.new()
	frame.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	frame.add_theme_constant_override("margin_left", 24)
	frame.add_theme_constant_override("margin_right", 24)
	frame.add_theme_constant_override("margin_top", 40)
	frame.add_theme_constant_override("margin_bottom", 40)
	add_child(frame)

	# Title and buttons are pinned; everything between them scrolls. The panel
	# grew a 33-map grid and pushed Done off the bottom of the screen, and a
	# menu you cannot leave is worse than one you have to scroll.
	var shell := VBoxContainer.new()
	shell.add_theme_constant_override("separation", 12)
	frame.add_child(shell)

	var title := Label.new()
	title.text = "Loadouts"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	title.add_theme_font_size_override("font_size", 26)
	shell.add_child(title)

	var page := ScrollContainer.new()
	page.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	page.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	page.size_flags_vertical = Control.SIZE_EXPAND_FILL
	shell.add_child(page)

	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 18)
	column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	page.add_child(column)

	var blurb := Label.new()
	blurb.text = "Pick the board, then fill five slots each. Repeat a unit to weight your draw toward it — and to weight the merge lottery, which rolls from this same list. Hover a slot to read what that unit does."
	blurb.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	blurb.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	blurb.custom_minimum_size = Vector2(PANEL_WIDTH, 0.0)
	blurb.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	blurb.add_theme_font_size_override("font_size", 13)
	blurb.add_theme_color_override("font_color", Color(0.60, 0.65, 0.74))
	column.add_child(blurb)

	column.add_child(_build_map_block())

	for team in [BoardModel.TEAM_B, BoardModel.TEAM_A]:
		column.add_child(_build_team_block(team))

	column.add_child(_build_detail_panel())

	var buttons := HBoxContainer.new()
	buttons.alignment = BoxContainer.ALIGNMENT_CENTER
	buttons.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	buttons.add_theme_constant_override("separation", 12)
	shell.add_child(buttons)

	var reset := Button.new()
	reset.text = "Reset both"
	reset.custom_minimum_size = Vector2(150, 46)
	reset.pressed.connect(Audio.play_confirm)
	reset.pressed.connect(_on_reset)
	buttons.add_child(reset)

	var done := Button.new()
	done.text = "Done"
	done.custom_minimum_size = Vector2(150, 46)
	done.pressed.connect(Audio.play_confirm)
	done.pressed.connect(_on_done)
	buttons.add_child(done)


func _build_map_block() -> Control:
	var card := PanelContainer.new()
	card.custom_minimum_size = Vector2(PANEL_WIDTH, 0.0)
	card.size_flags_horizontal = Control.SIZE_SHRINK_CENTER

	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.09, 0.10, 0.14, 0.98)
	style.border_color = Color(0.58, 0.56, 0.44)
	style.set_border_width_all(2)
	style.set_corner_radius_all(8)
	style.set_content_margin_all(14)
	card.add_theme_stylebox_override("panel", style)

	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 8)
	card.add_child(column)

	var heading := Label.new()
	heading.text = "Map"
	heading.add_theme_font_size_override("font_size", 18)
	heading.add_theme_color_override("font_color", Color(0.80, 0.77, 0.60))
	column.add_child(heading)

	# Thirty-odd boards do not fit behind a pair of arrows, so they are a grid of
	# shapes you pick by looking. The scroller is deliberately short — the panel
	# has two loadouts and a detail pane under it that must stay on screen.
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(0.0, GRID_HEIGHT)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	column.add_child(scroll)

	_map_grid = GridContainer.new()
	_map_grid.columns = GRID_COLUMNS
	_map_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_map_grid.add_theme_constant_override("h_separation", 8)
	_map_grid.add_theme_constant_override("v_separation", 8)
	scroll.add_child(_map_grid)

	_map_group = ButtonGroup.new()
	for i in GameSetup.maps.size():
		var chip := MapChip.new()
		chip.button_group = _map_group
		chip.set_map(GameSetup.maps[i])
		chip.pressed.connect(Audio.play_confirm)
		chip.pressed.connect(_on_pick_map.bind(i))
		_map_grid.add_child(chip)
		_chips.append(chip)

	var body := HBoxContainer.new()
	body.add_theme_constant_override("separation", 12)
	column.add_child(body)

	_map_preview = MapPreview.new()
	_map_preview.custom_minimum_size = PREVIEW_SIZE
	_map_preview.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	body.add_child(_map_preview)

	var chosen := VBoxContainer.new()
	chosen.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	chosen.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	chosen.add_theme_constant_override("separation", 4)
	body.add_child(chosen)

	_map_label = Label.new()
	_map_label.add_theme_font_size_override("font_size", 16)
	chosen.add_child(_map_label)

	_map_note = Label.new()
	_map_note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_map_note.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_map_note.add_theme_font_size_override("font_size", 13)
	_map_note.add_theme_color_override("font_color", Color(0.60, 0.65, 0.74))
	chosen.add_child(_map_note)

	return card


func _on_pick_map(index: int) -> void:
	GameSetup.select_map(index)
	refresh()


func _refresh_map() -> void:
	if _map_label == null:
		return
	var m := GameSetup.current_map()
	if m == null:
		_map_label.text = "Standard"
		_map_note.text = "No maps on disk — running the default board."
		if _map_preview != null:
			_map_preview.set_map(null)
		return
	_map_label.text = "%s  ·  %s" % [m.display_name, m.summary()]
	var terrain := m.terrain_note()
	_map_note.text = m.note if terrain.is_empty() else "%s\n\n%s" % [m.note, terrain]
	if _map_preview != null:
		_map_preview.set_map(m)
	# The grid is the picker, so it has to agree with whatever the map actually
	# is — including a map chosen from somewhere other than a chip.
	for i in _chips.size():
		_chips[i].set_pressed_no_signal(i == GameSetup.map_index)


func _build_team_block(team: int) -> Control:
	var card := PanelContainer.new()
	card.custom_minimum_size = Vector2(PANEL_WIDTH, 0.0)
	card.size_flags_horizontal = Control.SIZE_SHRINK_CENTER

	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.09, 0.10, 0.14, 0.98)
	style.border_color = _tint(team)
	style.set_border_width_all(2)
	style.set_corner_radius_all(8)
	style.set_content_margin_all(14)
	card.add_theme_stylebox_override("panel", style)

	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 8)
	card.add_child(column)

	var heading := Label.new()
	heading.text = _heading(team)
	heading.add_theme_font_size_override("font_size", 18)
	heading.add_theme_color_override("font_color", _tint(team))
	column.add_child(heading)

	var rows: Array[Label] = []
	var icons: Array[UnitIcon] = []
	for i in GameSetup.SLOTS:
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 10)
		column.add_child(row)

		var index := Label.new()
		index.text = "%d." % (i + 1)
		index.custom_minimum_size = Vector2(26.0, ROW_HEIGHT)
		index.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		index.add_theme_color_override("font_color", Color(0.52, 0.57, 0.66))
		row.add_child(index)

		var left := Button.new()
		left.text = "<"
		left.custom_minimum_size = Vector2(44.0, ROW_HEIGHT)
		# The cycle arrows get the tap, not the confirm: they are how you browse
		# the roster, and you click them a dozen times to cross it.
		left.pressed.connect(Audio.play_select)
		left.pressed.connect(_on_cycle.bind(team, i, -1))
		row.add_child(left)

		var icon := UnitIcon.new()
		icon.custom_minimum_size = ICON_SIZE
		icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_child(icon)
		icons.append(icon)

		var name_label := Label.new()
		name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		name_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		name_label.custom_minimum_size = Vector2(0.0, ROW_HEIGHT)
		name_label.add_theme_font_size_override("font_size", 16)
		name_label.mouse_filter = Control.MOUSE_FILTER_STOP
		name_label.mouse_entered.connect(_on_slot_hovered.bind(team, i))
		row.add_child(name_label)
		rows.append(name_label)

		var right := Button.new()
		right.text = ">"
		right.custom_minimum_size = Vector2(44.0, ROW_HEIGHT)
		right.pressed.connect(Audio.play_select)
		right.pressed.connect(_on_cycle.bind(team, i, 1))
		row.add_child(right)

	_rows[team] = rows
	_icons[team] = icons

	var summary := Label.new()
	summary.add_theme_font_size_override("font_size", 13)
	summary.add_theme_color_override("font_color", Color(0.60, 0.65, 0.74))
	summary.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	column.add_child(summary)
	_summaries[team] = summary

	return card


func _build_detail_panel() -> Control:
	var card := PanelContainer.new()
	card.custom_minimum_size = Vector2(PANEL_WIDTH, DETAIL_HEIGHT)
	card.size_flags_horizontal = Control.SIZE_SHRINK_CENTER

	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.07, 0.08, 0.11, 0.98)
	style.border_color = Color(0.30, 0.34, 0.42)
	style.set_border_width_all(1)
	style.set_corner_radius_all(8)
	style.set_content_margin_all(14)
	card.add_theme_stylebox_override("panel", style)

	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 6)
	card.add_child(column)

	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 10)
	column.add_child(head)

	_detail_icon = UnitIcon.new()
	_detail_icon.custom_minimum_size = Vector2(30.0, 30.0)
	_detail_icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_detail_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	head.add_child(_detail_icon)

	_detail_title = Label.new()
	_detail_title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_detail_title.add_theme_font_size_override("font_size", 17)
	_detail_title.add_theme_color_override("font_color", Color(0.90, 0.92, 0.96))
	head.add_child(_detail_title)

	_detail = Label.new()
	_detail.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_detail.add_theme_font_size_override("font_size", 13)
	_detail.add_theme_color_override("font_color", Color(0.72, 0.77, 0.85))
	_detail.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_child(_detail)

	return card


func _on_slot_hovered(team: int, index: int) -> void:
	var units := GameSetup.units_for(team)
	if index < 0 or index >= units.size():
		return
	show_unit(units[index])


func show_unit(d: UnitData) -> void:
	_focus = d
	if _detail == null or _detail_title == null:
		return
	if _detail_icon != null:
		_detail_icon.set_unit(d)
	if d == null:
		_detail_title.text = "Nothing selected"
		_detail.text = "Hover a slot to read what that unit does."
		return
	_detail_title.text = UnitCodex.headline(d)
	_detail.text = detail_body(d)


func focused() -> UnitData:
	return _focus


static func detail_body(d: UnitData) -> String:
	var lines: PackedStringArray = []
	if not d.note.is_empty():
		lines.append(d.note)
	lines.append(UnitCodex.stat_line(d))
	for t in UnitCodex.traits(d):
		lines.append("* %s" % t)
	lines.append(UnitCodex.ability_block(d))
	var charge := UnitCodex.charge_line(d)
	if not charge.is_empty():
		lines.append(charge)
	return "\n".join(lines)


func _heading(team: int) -> String:
	return GameSetup.team_name(team)


static func _tint(team: int) -> Color:
	return (Color(0.38, 0.66, 0.69) if team == BoardModel.TEAM_B
		else Color(0.83, 0.63, 0.39))


func open() -> void:
	refresh()
	visible = true


func refresh() -> void:
	_refresh_map()
	for team in _rows:
		var units := GameSetup.units_for(team)
		var labels: Array[Label] = _rows[team]
		for i in labels.size():
			var icons: Array[UnitIcon] = _icons[team]
			if i < units.size():
				var d: UnitData = units[i]
				labels[i].text = "%s  ·  %s" % [d.display_name, d.range_name()]
				labels[i].tooltip_text = UnitCodex.card(d)
				icons[i].set_unit(d)
			else:
				labels[i].text = "—"
				labels[i].tooltip_text = ""
				icons[i].set_unit(null)
		var heading_text := _heading(team)
		var summary: Label = _summaries[team]
		summary.text = "%s draws from: %s" % [heading_text, GameSetup.slot_summary(team)]
	_refresh_detail()


func _refresh_detail() -> void:
	if _focus != null:
		show_unit(_focus)
		return
	var first := GameSetup.units_for(BoardModel.TEAM_B)
	show_unit(null if first.is_empty() else first[0])


func _on_cycle(team: int, index: int, step: int) -> void:
	GameSetup.cycle_slot(team, index, step)
	refresh()


func _on_reset() -> void:
	GameSetup.reset_slots()
	refresh()


func _on_done() -> void:
	visible = false
	closed.emit()
