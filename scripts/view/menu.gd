extends Control

const MAIN_SCENE := "res://scenes/main.tscn"
const BUTTON_SIZE := Vector2(340, 62)
var _editor: LoadoutEditor = null
var _settings: SettingsPanel = null
var _custom: CustomPanel = null
var _note: Label = null


func _ready() -> void:
	Audio.play_music("menu_theme")
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	# Added FIRST, so every control below draws on top of it. A Control's children are
	# painted in child order, so this is the whole of the layering — there is no z-index
	# anywhere in this file and there should not be.
	add_child(MenuBackdrop.new())

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
	# Spaced in the string rather than by a theme constant: Godot's Label has no
	# letterspacing property, and faking one with a per-character container would be a
	# lot of machinery for a word that never changes.
	title.text = "S I X F O L D"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	title.add_theme_font_size_override("font_size", 72)
	title.add_theme_color_override("font_color", Color(0.96, 0.94, 0.90))
	# An outline plus a shadow, because the title now sits on a moving board and a plain
	# label would flicker in and out of legibility as units walked under it. The outline
	# is what keeps it readable; the shadow is what stops it looking pasted on.
	title.add_theme_constant_override("outline_size", 10)
	title.add_theme_color_override("font_outline_color", Color(0.05, 0.05, 0.08, 0.92))
	title.add_theme_constant_override("shadow_offset_x", 0)
	title.add_theme_constant_override("shadow_offset_y", 3)
	title.add_theme_constant_override("shadow_outline_size", 14)
	title.add_theme_color_override("font_shadow_color", Color(0.62, 0.34, 0.30, 0.55))
	column.add_child(title)

	var subtitle := Label.new()
	# Set plainly. The first attempt spaced every letter the way the title is spaced, and
	# the screenshot showed it: at 13px that stops being a design choice and starts being
	# hard to read.
	subtitle.text = "A merge autobattler"
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	subtitle.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	subtitle.add_theme_font_size_override("font_size", 13)
	subtitle.add_theme_color_override("font_color", Color(0.62, 0.66, 0.76))
	subtitle.add_theme_constant_override("outline_size", 6)
	subtitle.add_theme_color_override("font_outline_color", Color(0.05, 0.05, 0.08, 0.85))
	column.add_child(subtitle)

	column.add_child(_rule())

	column.add_child(_spacer(28.0))
	column.add_child(_menu_button("Battle the Computer", _on_vs_computer))
	column.add_child(_menu_button("Local PvP", _on_local_pvp))
	column.add_child(_menu_button("Custom Match", _on_custom))
	column.add_child(_menu_button("Loadouts", _on_loadouts))
	column.add_child(_menu_button("Settings", _on_settings))
	column.add_child(_spacer(10.0))

	_note = Label.new()
	_note.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_note.custom_minimum_size = Vector2(BUTTON_SIZE.x + 80.0, 0.0)
	_note.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_note.add_theme_font_size_override("font_size", 13)
	_note.add_theme_color_override("font_color", Color(0.62, 0.67, 0.78))
	# The same outline the title and the buttons get. This line sits at the bottom of the
	# column where the scrim is already easing off, so it is the text most likely to have
	# a unit walk under it — and it is the smallest, so it is the first to become
	# unreadable when one does.
	_note.add_theme_constant_override("outline_size", 6)
	_note.add_theme_color_override("font_outline_color", Color(0.04, 0.04, 0.06, 0.92))
	column.add_child(_note)

	_editor = LoadoutEditor.new()
	_editor.closed.connect(_refresh_note)
	add_child(_editor)

	_settings = SettingsPanel.new()
	add_child(_settings)

	_custom = CustomPanel.new()
	# It starts the match itself rather than handing a flag back to the menu: every
	# knob on it is only meaningful for the match it starts, so the Start button
	# belongs on the screen you set them on.
	_custom.start_pressed.connect(_start)
	add_child(_custom)

	_refresh_note()


func _spacer(height: float) -> Control:
	var s := Control.new()
	s.custom_minimum_size = Vector2(0.0, height)
	s.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return s


func _rule() -> Control:
	## A thin horizontal line under the title. Its own tiny Control rather than a Label of
	## dashes, so it scales with the column instead of with the font.
	var line := Panel.new()
	line.custom_minimum_size = Vector2(BUTTON_SIZE.x * 0.55, 2.0)
	line.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	var box := StyleBoxFlat.new()
	box.bg_color = Color(0.62, 0.34, 0.30, 0.55)
	line.add_theme_stylebox_override("panel", box)
	return line


## The four states a Button styles separately. Kept as one dictionary so that adding a
## state means adding a line here rather than remembering which of four calls to repeat.
const BUTTON_SKIN := {
	normal = {fill = Color(0.10, 0.11, 0.15, 0.82), edge = Color(0.30, 0.33, 0.42, 0.85),
		width = 1, ink = Color(0.84, 0.87, 0.93)},
	hover = {fill = Color(0.16, 0.18, 0.24, 0.94), edge = Color(0.86, 0.66, 0.42, 0.95),
		width = 2, ink = Color(1.00, 0.96, 0.88)},
	pressed = {fill = Color(0.07, 0.08, 0.11, 0.96), edge = Color(0.86, 0.66, 0.42, 0.85),
		width = 2, ink = Color(0.92, 0.80, 0.62)},
	focus = {fill = Color(0.13, 0.15, 0.20, 0.88), edge = Color(0.52, 0.58, 0.70, 0.90),
		width = 1, ink = Color(0.88, 0.91, 0.96)},
}


func _button_box(spec: Dictionary) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = spec.fill
	box.border_color = spec.edge
	box.set_border_width_all(spec.width)
	box.set_corner_radius_all(4)
	# Padding rather than a taller custom_minimum_size, so the text sits off the border
	# at every font size.
	box.content_margin_left = 18.0
	box.content_margin_right = 18.0
	return box


func _menu_button(text: String, handler: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = BUTTON_SIZE
	b.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	b.add_theme_font_size_override("font_size", 19)
	# The default Button is opaque grey, which would hide the board behind it and make the
	# backdrop pointless. These are translucent on purpose: the battle shows through, and
	# the border is what defines the button rather than the fill.
	for state in BUTTON_SKIN:
		var spec: Dictionary = BUTTON_SKIN[state]
		b.add_theme_stylebox_override(state, _button_box(spec))
		# The stylebox and the font colour do NOT share a naming scheme in Godot: the
		# boxes are "normal"/"hover"/..., but the font colours are "font_color" for the
		# resting state and "font_hover_color" for the rest. Generating
		# "font_normal_color" from the loop variable looks right, is silently ignored,
		# and leaves the resting label the engine's default grey.
		var ink_name := "font_color" if state == "normal" else "font_%s_color" % state
		b.add_theme_color_override(ink_name, spec.ink)
	# Buttons sit on moving units, so their labels get the same outline the title does.
	b.add_theme_constant_override("outline_size", 5)
	b.add_theme_color_override("font_outline_color", Color(0.04, 0.04, 0.06, 0.9))
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
	# Setting the mode is what clears the custom rules — see GameSetup.mode.
	GameSetup.mode = GameSetup.Mode.VS_COMPUTER
	_start()


func _on_local_pvp() -> void:
	GameSetup.mode = GameSetup.Mode.LOCAL_PVP
	_start()


func _on_loadouts() -> void:
	_editor.open()


func _on_custom() -> void:
	_custom.open()


func _on_settings() -> void:
	_settings.open()


func _start() -> void:
	get_tree().change_scene_to_file(MAIN_SCENE)
