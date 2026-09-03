class_name UnitInspector
extends Control

signal unit_pressed(unit: UnitInstance)

const TOOLTIP_WIDTH := 320.0

var view: BoardView = null


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_PASS


func bind(p_view: BoardView) -> void:
	view = p_view
	# The window, not the board: a board larger than its window scrolls beneath
	# this, and only the part on screen should answer to the mouse.
	position = p_view.view_area.position
	size = p_view.view_area.size


func to_board(at_position: Vector2) -> Vector2:
	return at_position + position - view.position


func unit_under(at_position: Vector2) -> UnitInstance:
	if view == null:
		return null
	var u := view.unit_at_point(to_board(at_position))
	if u == null or view.is_concealed(u):
		return null
	return u


func _get_tooltip(at_position: Vector2) -> String:
	var u := unit_under(at_position)
	if u == null:
		return ""
	return "%s\n\n— %s" % [UnitCodex.card_of(u), GameSetup.team_name(u.team)]


func _make_custom_tooltip(for_text: String) -> Object:
	return TipPanel.build(for_text, TOOLTIP_WIDTH)


func _gui_input(event: InputEvent) -> void:
	if not (event is InputEventMouseButton):
		return
	var mb := event as InputEventMouseButton
	if mb.button_index != MOUSE_BUTTON_LEFT or not mb.pressed:
		return
	var u := unit_under(mb.position)
	if u != null:
		unit_pressed.emit(u)
