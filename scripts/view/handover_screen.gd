class_name HandoverScreen
extends Control

signal ready_pressed

const BLIND_SECONDS := 2.5

var _title: Label = null
var _sub: Label = null
var _button: Button = null
var _left := 0.0
var _counting := false


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	visible = false
	set_process(false)

	var shade := ColorRect.new()
	shade.color = Color(0.03, 0.035, 0.05, 1.0)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shade.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(shade)

	var frame := MarginContainer.new()
	frame.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	frame.add_theme_constant_override("margin_left", 32)
	frame.add_theme_constant_override("margin_right", 32)
	add_child(frame)

	var column := VBoxContainer.new()
	column.alignment = BoxContainer.ALIGNMENT_CENTER
	column.add_theme_constant_override("separation", 20)
	frame.add_child(column)

	_title = Label.new()
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_title.add_theme_font_size_override("font_size", 32)
	column.add_child(_title)

	_sub = Label.new()
	_sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_sub.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_sub.custom_minimum_size = Vector2(420.0, 0.0)
	_sub.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_sub.add_theme_font_size_override("font_size", 15)
	_sub.add_theme_color_override("font_color", Color(0.58, 0.63, 0.72))
	column.add_child(_sub)

	_button = Button.new()
	_button.custom_minimum_size = Vector2(260, 56)
	_button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_button.add_theme_font_size_override("font_size", 18)
	_button.pressed.connect(_on_ready)
	column.add_child(_button)


func blind(next_team: int, blind_for := BLIND_SECONDS) -> void:
	_title.text = "Pass to %s" % GameSetup.team_name(next_team)
	_title.add_theme_color_override("font_color", team_tint(next_team))
	_sub.text = "Screen hidden so nobody reads the other board. Hand the device over, then press Ready."
	_left = maxf(blind_for, 0.0)
	_counting = _left > 0.0
	_button.disabled = _counting
	_refresh_button()
	visible = true
	set_process(_counting)
	if not _counting:
		_button.grab_focus()


func is_blinding() -> bool:
	return visible


func _process(delta: float) -> void:
	if not _counting:
		return
	_left = maxf(_left - delta, 0.0)
	_refresh_button()
	if _left <= 0.0:
		_counting = false
		_button.disabled = false
		set_process(false)
		_button.grab_focus()


func _refresh_button() -> void:
	if _counting:
		_button.text = "Ready in %d..." % maxi(ceili(_left), 1)
	else:
		_button.text = "Ready"


static func team_tint(team: int) -> Color:
	return (Color(0.38, 0.66, 0.69) if team == BoardModel.TEAM_B
		else Color(0.83, 0.63, 0.39))


func _on_ready() -> void:
	if _counting:
		return
	visible = false
	set_process(false)
	ready_pressed.emit()
