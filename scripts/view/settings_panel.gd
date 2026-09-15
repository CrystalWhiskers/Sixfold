class_name SettingsPanel
extends Control

## Everything that changes how the game looks and sounds, on one screen.
##
## The volume fader is new; the battle playlist and the unit-art switch moved
## here from the main menu, which had grown three buttons, twenty-two track
## toggles and a switch stacked down the middle of it. They are settings, and
## this is where settings live.
##
## Built like LoadoutEditor — a full-rect panel that starts hidden, opens over
## the menu and emits `closed` when it is done — so the menu has one way of
## opening a screen rather than two.

signal closed

const TRACK_BUTTON_SIZE := Vector2(46, 34)
const TRACKS_PER_ROW := 6
const PANEL_WIDTH := 560.0

var _track_buttons: Array[Button] = []
var _portrait_button: Button = null
var _volume_slider: HSlider = null
var _volume_label: Label = null
var _boss_button: Button = null


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

	var column := VBoxContainer.new()
	column.alignment = BoxContainer.ALIGNMENT_CENTER
	column.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	column.add_theme_constant_override("separation", 14)
	frame.add_child(column)

	var title := Label.new()
	title.text = "Settings"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	title.add_theme_font_size_override("font_size", 30)
	column.add_child(title)

	column.add_child(_build_volume())
	column.add_child(_build_portrait_toggle())
	column.add_child(_build_playlist())
	column.add_child(_build_boss_toggle())

	var done := Button.new()
	done.text = "Done"
	done.custom_minimum_size = Vector2(200.0, 44.0)
	done.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	done.add_theme_font_size_override("font_size", 17)
	done.pressed.connect(Audio.play_confirm)
	done.pressed.connect(_on_done)
	column.add_child(done)


func _heading(text: String) -> Label:
	var l := Label.new()
	l.text = text
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	l.add_theme_font_size_override("font_size", 14)
	l.add_theme_color_override("font_color", Color(0.55, 0.60, 0.70))
	return l


func _build_volume() -> Control:
	var box := VBoxContainer.new()
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_theme_constant_override("separation", 6)

	_volume_label = _heading("")
	box.add_child(_volume_label)

	_volume_slider = HSlider.new()
	_volume_slider.min_value = 0.0
	_volume_slider.max_value = 1.0
	# A hundred stops across the bar, so the number under it can read in whole
	# percent without the fader and the label disagreeing about where it is.
	_volume_slider.step = 0.01
	_volume_slider.value = Audio.volume
	_volume_slider.custom_minimum_size = Vector2(PANEL_WIDTH * 0.6, 24.0)
	_volume_slider.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	# value_changed, not drag_ended: the whole point of a volume fader is that you
	# hear the change while you are moving it.
	_volume_slider.value_changed.connect(_on_volume)
	box.add_child(_volume_slider)

	_refresh_volume()
	return box


func _on_volume(value: float) -> void:
	Audio.volume = value
	_refresh_volume()


func _refresh_volume() -> void:
	if _volume_label == null:
		return
	_volume_label.text = ("Volume — muted" if Audio.volume <= 0.0
		else "Volume — %d%%" % roundi(Audio.volume * 100.0))


func _build_portrait_toggle() -> Control:
	var box := VBoxContainer.new()
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_theme_constant_override("separation", 6)
	box.add_child(_heading("Unit art"))

	_portrait_button = Button.new()
	_portrait_button.custom_minimum_size = Vector2(PANEL_WIDTH * 0.38, 34.0)
	_portrait_button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_portrait_button.add_theme_font_size_override("font_size", 15)
	_portrait_button.toggle_mode = true
	_portrait_button.pressed.connect(Audio.play_confirm)
	_portrait_button.pressed.connect(_on_toggle_portraits)
	box.add_child(_portrait_button)

	_refresh_portraits()
	return box


func _on_toggle_portraits() -> void:
	GameSetup.portraits = not GameSetup.portraits
	_refresh_portraits()
	# Every icon already on screen has to be repainted. propagate_call reaches the
	# whole subtree, so a screen that grows another icon later is covered without
	# a second thought.
	get_tree().root.propagate_call("queue_redraw")


func _refresh_portraits() -> void:
	if _portrait_button == null:
		return
	var on := GameSetup.portraits
	# The label says what the board will LOOK like, not what the switch is
	# called. "Portraits: off" makes you work out what you get instead; "Coloured
	# blocks" just tells you.
	_portrait_button.text = "Portraits" if on else "Coloured blocks"
	_portrait_button.button_pressed = on
	_portrait_button.add_theme_color_override("font_color",
		Color(0.86, 0.90, 0.96) if on else Color(0.48, 0.52, 0.60))


func _build_boss_toggle() -> Control:
	var box := VBoxContainer.new()
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_theme_constant_override("separation", 6)
	box.add_child(_heading(
		"Boss themes play when a tier 6 is on the board"))

	_boss_button = Button.new()
	_boss_button.custom_minimum_size = Vector2(PANEL_WIDTH * 0.52, 34.0)
	_boss_button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_boss_button.add_theme_font_size_override("font_size", 15)
	_boss_button.toggle_mode = true
	_boss_button.pressed.connect(Audio.play_confirm)
	_boss_button.pressed.connect(_on_toggle_boss)
	# Nothing to let in, so the switch says so rather than sitting there doing
	# nothing when clicked.
	_boss_button.disabled = Audio.boss_track_count <= 0
	box.add_child(_boss_button)

	_refresh_boss()
	return box


func _on_toggle_boss() -> void:
	GameSetup.toggle_boss_in_pool()
	_refresh_boss()


func _refresh_boss() -> void:
	if _boss_button == null:
		return
	if Audio.boss_track_count <= 0:
		_boss_button.text = "no boss tracks found"
		_boss_button.button_pressed = false
		return
	var on := GameSetup.boss_in_pool
	# Says what the setting DOES, not what it is named. "Boss themes: on" leaves
	# you wondering on for what — these say where they play.
	_boss_button.text = ("Boss rounds and ordinary rounds" if on
		else "Boss rounds only")
	_boss_button.button_pressed = on
	_boss_button.add_theme_color_override("font_color",
		Color(0.86, 0.90, 0.96) if on else Color(0.48, 0.52, 0.60))


func _build_playlist() -> Control:
	# Every track is a toggle; a round rolls one of whatever is switched on. Built
	# from Audio.battle_track_count rather than a list here, so dropping
	# battle_23.ogg into assets/music puts another button on this screen with no
	# edit to this file at all.
	var box := VBoxContainer.new()
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_theme_constant_override("separation", 6)
	box.add_child(_heading("Battle music — a round rolls one of the tracks left on"))

	# A grid, not a row: twenty-two tracks at 46 pixels each is over a thousand
	# wide and the panel is not. The grid wraps however many there turn out to be.
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


func open() -> void:
	_refresh_volume()
	_refresh_portraits()
	_refresh_tracks()
	_refresh_boss()
	visible = true


func _on_done() -> void:
	visible = false
	closed.emit()
