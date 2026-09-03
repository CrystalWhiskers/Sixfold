class_name BuffPicker
extends Control

signal picked(buff: BuffData, rarity: int)

const CARD_WIDTH := 460.0
const CARD_HEIGHT := 74.0
const CARD_GAP := 10.0
const BOTTOM_MARGIN := 26.0
const CENTER_VERTICALLY := false

var _rarity: BuffData.Rarity = BuffData.Rarity.BRONZE
var _options: Array[BuffData] = []
var _panel: VBoxContainer = null
var _title: Label = null
var _subtitle: Label = null
var _column: VBoxContainer = null


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	visible = false

	var shade := ColorRect.new()
	shade.color = Color(0.03, 0.04, 0.07, 0.82)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shade.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(shade)

	var frame := MarginContainer.new()
	frame.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	frame.add_theme_constant_override("margin_left", 12)
	frame.add_theme_constant_override("margin_right", 12)
	frame.add_theme_constant_override("margin_top", 12)
	frame.add_theme_constant_override("margin_bottom", int(BOTTOM_MARGIN))
	add_child(frame)

	_panel = VBoxContainer.new()
	_panel.alignment = (BoxContainer.ALIGNMENT_CENTER if CENTER_VERTICALLY
		else BoxContainer.ALIGNMENT_END)
	_panel.add_theme_constant_override("separation", 12)
	frame.add_child(_panel)

	_title = Label.new()
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_title.add_theme_font_size_override("font_size", 21)
	_panel.add_child(_title)

	_subtitle = Label.new()
	_subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_subtitle.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_subtitle.add_theme_font_size_override("font_size", 12)
	_subtitle.add_theme_color_override("font_color", Color(0.58, 0.63, 0.72))
	_panel.add_child(_subtitle)

	_column = VBoxContainer.new()
	_column.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_column.add_theme_constant_override("separation", int(CARD_GAP))
	_panel.add_child(_column)


func open(options: Array[BuffData], rarity: BuffData.Rarity, round_index: int,
		note := "", who := "") -> void:
	_options = options
	_rarity = rarity
	for child in _column.get_children():
		_column.remove_child(child)
		child.queue_free()

	var tint := BuffData.rarity_color(rarity)
	if who.is_empty():
		_title.text = "Round %d — choose a %s buff" % [
			round_index, BuffData.rarity_name(rarity)]
	else:
		_title.text = "%s — choose a %s buff" % [who, BuffData.rarity_name(rarity)]
	_title.add_theme_color_override("font_color", tint)
	_subtitle.text = note
	_subtitle.visible = not note.is_empty()

	for i in options.size():
		_column.add_child(_make_card(options[i], i, tint))

	visible = true


func close() -> void:
	visible = false


func _make_card(buff: BuffData, index: int, tint: Color) -> Control:
	var card := PanelContainer.new()
	card.custom_minimum_size = Vector2(_card_width(), CARD_HEIGHT)
	card.size_flags_horizontal = Control.SIZE_SHRINK_CENTER

	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.09, 0.10, 0.14, 0.97)
	style.border_color = tint
	style.set_border_width_all(2)
	style.set_corner_radius_all(8)
	style.set_content_margin_all(12)
	card.add_theme_stylebox_override("panel", style)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 14)
	card.add_child(row)

	var heading := VBoxContainer.new()
	heading.custom_minimum_size = Vector2(122.0, 0.0)
	heading.add_theme_constant_override("separation", 2)
	row.add_child(heading)

	var name_label := Label.new()
	name_label.text = buff.display_name
	name_label.add_theme_font_size_override("font_size", 17)
	name_label.add_theme_color_override("font_color", tint)
	heading.add_child(name_label)

	var scope := Label.new()
	scope.text = "All units" if buff.is_global() else String(buff.unit_id).capitalize()
	scope.add_theme_font_size_override("font_size", 12)
	scope.add_theme_color_override("font_color", Color(0.58, 0.63, 0.72))
	heading.add_child(scope)

	var body := Label.new()
	body.text = buff.describe(_rarity)
	body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.size_flags_vertical = Control.SIZE_FILL
	body.add_theme_font_size_override("font_size", 14)
	row.add_child(body)

	var take := Button.new()
	take.text = "Take"
	take.custom_minimum_size = Vector2(64.0, 0.0)
	take.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	take.pressed.connect(_on_take.bind(index))
	row.add_child(take)

	return card


func _card_width() -> float:
	var available := get_viewport_rect().size.x - 48.0
	return minf(CARD_WIDTH, maxf(available, 200.0))


func _on_take(index: int) -> void:
	if index < 0 or index >= _options.size():
		return
	var chosen := _options[index]
	close()
	picked.emit(chosen, int(_rarity))
