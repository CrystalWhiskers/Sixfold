class_name ScrollDemo
extends Control

## A board to try the scroll-zoom speed on, opened from Settings.
##
## A speed is a feel, not a number: "1.4x" means nothing until you have rolled the
## wheel. So the slider sits right above a real board — the map you have picked, a
## few units from each side on it — and every notch over that board goes through
## BoardView's own wheel handling, the exact code a match uses. What you feel here
## is what you get.
##
## The board lives in a SubViewport so it has a coordinate space of its own: the
## BoardView's mouse tests and pan limits are all written against its window, and
## inside a SubViewport that window is just this box.

signal closed

const DEMO_SIZE := Vector2i(520, 600)
const UNITS_PER_SIDE := 6
const MAX_TIER := 4

var _slider: HSlider = null
var _speed_label: Label = null
var _zoom_label: Label = null
var _holder: SubViewportContainer = null
var _viewport: SubViewport = null
var _view: BoardView = null
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	visible = false
	set_process(false)

	var shade := ColorRect.new()
	shade.color = Color(0.04, 0.05, 0.08, 1.0)
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

	var column := VBoxContainer.new()
	column.alignment = BoxContainer.ALIGNMENT_CENTER
	column.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	column.add_theme_constant_override("separation", 12)
	frame.add_child(column)

	var title := Label.new()
	title.text = "Scroll zoom speed"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 28)
	column.add_child(title)

	var hint := Label.new()
	hint.text = ("Roll the mouse wheel over the board to zoom. Move the slider until one "
		+ "notch feels right. Drag the board to look around when it is zoomed in.")
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.custom_minimum_size = Vector2(DEMO_SIZE.x, 0.0)
	hint.add_theme_font_size_override("font_size", 14)
	hint.add_theme_color_override("font_color", Color(0.62, 0.67, 0.76))
	column.add_child(hint)

	_speed_label = Label.new()
	_speed_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_speed_label.add_theme_font_size_override("font_size", 16)
	column.add_child(_speed_label)

	_slider = SettingsPanel.make_scroll_slider()
	_slider.custom_minimum_size = Vector2(DEMO_SIZE.x * 0.8, 20.0)
	_slider.value_changed.connect(_on_speed)
	column.add_child(_slider)

	_holder = SubViewportContainer.new()
	_holder.custom_minimum_size = Vector2(DEMO_SIZE)
	_holder.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_holder.stretch = false
	column.add_child(_holder)

	_zoom_label = Label.new()
	_zoom_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_zoom_label.add_theme_font_size_override("font_size", 14)
	_zoom_label.add_theme_color_override("font_color", Color(0.62, 0.67, 0.76))
	column.add_child(_zoom_label)

	var buttons := HBoxContainer.new()
	buttons.alignment = BoxContainer.ALIGNMENT_CENTER
	buttons.add_theme_constant_override("separation", 16)
	column.add_child(buttons)

	var reset := Button.new()
	reset.text = "Reset view"
	reset.custom_minimum_size = Vector2(160.0, 44.0)
	reset.add_theme_font_size_override("font_size", 17)
	reset.pressed.connect(Audio.play_confirm)
	reset.pressed.connect(func():
		if _view != null:
			_view.reset_zoom())
	buttons.add_child(reset)

	var done := Button.new()
	done.text = "Done"
	done.custom_minimum_size = Vector2(160.0, 44.0)
	done.add_theme_font_size_override("font_size", 17)
	done.pressed.connect(Audio.play_confirm)
	done.pressed.connect(_on_done)
	buttons.add_child(done)


func open() -> void:
	_slider.set_value_no_signal(GameSetup.scroll_sensitivity)
	_refresh_speed()
	_build_board()
	visible = true
	set_process(true)


func _build_board() -> void:
	_clear_board()
	# The player's own map, so the size you tune on is the size you play on.
	if GameSetup.maps.is_empty():
		GameSetup.reload_maps()
	GameSetup.apply_map()
	if GameSetup.catalogue.is_empty():
		GameSetup.reload_catalogue()

	var board := BoardModel.new()
	_rng.randomize()
	for team in [BoardModel.TEAM_A, BoardModel.TEAM_B]:
		_fill(board, team)

	_viewport = SubViewport.new()
	_viewport.size = DEMO_SIZE
	_viewport.handle_input_locally = true
	_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	_holder.add_child(_viewport)

	_view = BoardView.new()
	_view.player_team = BoardModel.TEAM_B
	# Nothing to pick up: a press on the board takes the camera, as it does mid-battle.
	_view.interactive = false
	# Small enough that the whole board fits the box at 100%, so zooming in is what
	# you are testing rather than a board that already overflows.
	_view.min_tile = 24.0
	_viewport.add_child(_view)
	_view.fit_to(Rect2(Vector2.ZERO, Vector2(DEMO_SIZE)))
	_view.bind(board)


func _fill(board: BoardModel, team: int) -> void:
	var pool: Array[UnitData] = []
	for u in GameSetup.catalogue:
		if u.can_move:
			pool.append(u)
	if pool.is_empty():
		return
	var cells := board.deploy_cells(team)
	for i in range(cells.size() - 1, 0, -1):
		var j := _rng.randi_range(0, i)
		var swap: Vector2i = cells[i]
		cells[i] = cells[j]
		cells[j] = swap
	for i in mini(UNITS_PER_SIDE, cells.size()):
		var pick: UnitData = pool[_rng.randi_range(0, pool.size() - 1)]
		board.force_place(UnitInstance.create(
			BoardModel.at_tier(pick, _rng.randi_range(1, MAX_TIER)), team), cells[i])


func _clear_board() -> void:
	if _viewport != null and is_instance_valid(_viewport):
		_holder.remove_child(_viewport)
		_viewport.queue_free()
	_viewport = null
	_view = null


func _process(_delta: float) -> void:
	if _view == null:
		return
	_zoom_label.text = "Board zoom: %d%%" % roundi(_view.zoom * 100.0)


func _on_speed(value: float) -> void:
	GameSetup.scroll_sensitivity = value
	_refresh_speed()


func _refresh_speed() -> void:
	_speed_label.text = SettingsPanel.scroll_text()


func _on_done() -> void:
	set_process(false)
	_clear_board()
	visible = false
	closed.emit()
