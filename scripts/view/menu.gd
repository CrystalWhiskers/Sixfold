extends Control

const MAIN_SCENE := "res://scenes/main.tscn"
const BUTTON_SIZE := Vector2(340, 62)
const TRACK_BUTTON_SIZE := Vector2(46, 34)
const TRACKS_PER_ROW := 6

var _editor: LoadoutEditor = null
var _note: Label = null
var _track_buttons: Array[Button] = []


func _ready() -> void:
	Audio.play_music("menu_theme")
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	var frame := MarginContainer.new()
	frame.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	frame.add_theme_constant_override("margin_left", 24)
	frame.add_theme_constant_override("margin_right", 24)
	frame.add_theme_constant_override("margin_top", 60)
	frame.add_theme_constant_override("margin_bottom", 60)
	add_child(frame)

	var column := VBoxContainer.new()
	column.alignment = BoxContainer.ALIGNMENT_CENTER
	column.add_theme_constant_override("separation", 16)
	frame.add_child(column)

	var title := Label.new()
	title.text = "Six by Eleven"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	title.add_theme_font_size_override("font_size", 40)
	column.add_child(title)

	var subtitle := Label.new()
	subtitle.text = "A merge autobattler"
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	subtitle.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	subtitle.add_theme_font_size_override("font_size", 15)
	subtitle.add_theme_color_override("font_color", Color(0.55, 0.60, 0.70))
	column.add_child(subtitle)

	column.add_child(_spacer(28.0))
	column.add_child(_menu_button("Battle the Computer", _on_vs_computer))
	column.add_child(_menu_button("Local PvP", _on_local_pvp))
	column.add_child(_menu_button("Loadouts", _on_loadouts))
	column.add_child(_spacer(10.0))
	column.add_child(_build_playlist())
	column.add_child(_spacer(10.0))

	_note = Label.new()
	_note.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_note.custom_minimum_size = Vector2(BUTTON_SIZE.x + 80.0, 0.0)
	_note.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_note.add_theme_font_size_override("font_size", 13)
	_note.add_theme_color_override("font_color", Color(0.55, 0.60, 0.70))
	column.add_child(_note)

	_editor = LoadoutEditor.new()
	_editor.closed.connect(_refresh_note)
	add_child(_editor)

	_refresh_note()


func _build_playlist() -> Control:
	# The battle playlist. Every track is a toggle; a round rolls one of whatever
	# is switched on. Built from Audio.battle_track_count rather than a list here,
	# so dropping battle_3.ogg into assets/music puts a third button on this
	# screen with no edit to the menu at all.
	var box := VBoxContainer.new()
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_theme_constant_override("separation", 6)

	var heading := Label.new()
	heading.text = "Battle music — a round rolls one of the tracks left on"
	heading.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	heading.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	heading.add_theme_font_size_override("font_size", 14)
	heading.add_theme_color_override("font_color", Color(0.55, 0.60, 0.70))
	box.add_child(heading)

	# A grid, not a row: ten tracks at 150 pixels each is 1500 wide and the menu
	# is not. Numbered buttons are small enough that TRACKS_PER_ROW of them fit
	# comfortably, and the grid wraps however many there turn out to be.
	var grid := GridContainer.new()
	grid.columns = mini(maxi(Audio.battle_track_count, 1), TRACKS_PER_ROW)
	grid.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	grid.add_theme_constant_override("h_separation", 6)
	grid.add_theme_constant_override("v_separation", 6)
	box.add_child(grid)

	_track_buttons.clear()
	for i in Audio.battle_track_count:
		var b := Button.new()
		b.custom_minimum_size = TRACK_BUTTON_SIZE
		b.add_theme_font_size_override("font_size", 15)
		# Toggle mode purely for the look — the state of record is
		# GameSetup.playlist(), and _refresh_tracks writes the button from it. A
		# programmatic button_pressed emits `toggled`, not `pressed`, so writing it
		# back here cannot loop.
		b.toggle_mode = true
		b.pressed.connect(Audio.play_confirm)
		b.pressed.connect(_on_toggle_track.bind(i + 1))
		grid.add_child(b)
		_track_buttons.append(b)
	if Audio.battle_track_count == 0:
		var none := Label.new()
		none.text = "no tracks found"
		none.add_theme_font_size_override("font_size", 13)
		grid.add_child(none)
	_refresh_tracks()
	return box


func _on_toggle_track(index: int) -> void:
	GameSetup.toggle_track(index)
	_refresh_tracks()


func _refresh_tracks() -> void:
	var list := GameSetup.playlist()
	var only_one := GameSetup.tracks_on() <= 1
	for i in _track_buttons.size():
		var on: bool = list[i]
		var b := _track_buttons[i]
		# Just the number. Whether it is IN the rotation is the colour and the
		# pressed look, not a tick glyph competing with the digit for the space.
		b.text = Audio.battle_track_name(i + 1)
		b.button_pressed = on
		# The last one standing is greyed rather than hidden, so the reason the
		# click did nothing is visible instead of mysterious.
		b.disabled = on and only_one
		b.add_theme_color_override("font_color",
			Color(0.86, 0.90, 0.96) if on else Color(0.48, 0.52, 0.60))


func _spacer(height: float) -> Control:
	var s := Control.new()
	s.custom_minimum_size = Vector2(0.0, height)
	s.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return s


func _menu_button(text: String, handler: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = BUTTON_SIZE
	b.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	b.add_theme_font_size_override("font_size", 19)
	# Every menu button is built here, so one line covers the whole screen.
	b.pressed.connect(Audio.play_confirm)
	b.pressed.connect(handler)
	return b


func _refresh_note() -> void:
	if _note == null:
		return
	_note.text = "Yours: %s\nOpponent: %s" % [
		GameSetup.slot_summary(BoardModel.TEAM_B),
		GameSetup.slot_summary(BoardModel.TEAM_A),
	]


func _on_vs_computer() -> void:
	GameSetup.mode = GameSetup.Mode.VS_COMPUTER
	_start()


func _on_local_pvp() -> void:
	GameSetup.mode = GameSetup.Mode.LOCAL_PVP
	_start()


func _on_loadouts() -> void:
	_editor.open()


func _start() -> void:
	get_tree().change_scene_to_file(MAIN_SCENE)
