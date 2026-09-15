extends Control

const MAIN_SCENE := "res://scenes/main.tscn"
const BUTTON_SIZE := Vector2(340, 62)
var _editor: LoadoutEditor = null
var _settings: SettingsPanel = null
var _note: Label = null


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
	column.add_child(_menu_button("Settings", _on_settings))
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

	_settings = SettingsPanel.new()
	add_child(_settings)

	_refresh_note()


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


func _on_settings() -> void:
	_settings.open()


func _start() -> void:
	get_tree().change_scene_to_file(MAIN_SCENE)
