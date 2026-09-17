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

## The track currently being auditioned, or "" for none. Kept so the button can be
## lit while it plays and so a second right click on the same one stops it.
var _previewing := ""

## What was playing before the first preview interrupted it. The settings screen can
## be opened from the menu or from the middle of a match, so "put it back" cannot
## mean a fixed track name — it has to mean whatever this actually was.
var _interrupted := ""
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
	box.add_child(_heading(
		"Battle music — left click to switch a track off, right click to hear it"))

	# A grid, not a row: forty tracks at 46 pixels each is nearly two thousand wide
	# and the panel is not. The grid wraps however many there turn out to be.
	var grid := GridContainer.new()
	grid.columns = mini(maxi(_all_tracks(), 1), TRACKS_PER_ROW)
	grid.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	grid.add_theme_constant_override("h_separation", 6)
	grid.add_theme_constant_override("v_separation", 6)
	box.add_child(grid)

	_track_buttons.clear()
	for i in Audio.battle_track_count:
		grid.add_child(_track_button(i + 1, false))
	# The boss tracks are in the grid too, marked "B1", "B2" and so on. They are
	# previewable exactly like the rest — auditioning the music is the point of the
	# right click, and a track you cannot hear is the one you most want to.
	#
	# Their TOGGLE means something narrower: whether they may come up in an ordinary
	# round. That is the Boss rounds switch above, so these are preview-only and say
	# so by being drawn in their own colour.
	for i in Audio.boss_track_count:
		grid.add_child(_track_button(i + 1, true))
	if _all_tracks() == 0:
		var none := Label.new()
		none.text = "no tracks found"
		none.add_theme_font_size_override("font_size", 13)
		grid.add_child(none)
	_refresh_tracks()
	return box


func _all_tracks() -> int:
	return Audio.battle_track_count + Audio.boss_track_count


func _track_button(index: int, boss: bool) -> Button:
	var b := Button.new()
	b.custom_minimum_size = TRACK_BUTTON_SIZE
	b.add_theme_font_size_override("font_size", 15)
	# Toggle mode purely for the look — the state of record is
	# GameSetup.playlist(), and _refresh_tracks writes the button from it. A
	# programmatic button_pressed emits `toggled`, not `pressed`, so writing it
	# back here cannot loop.
	b.toggle_mode = not boss
	b.set_meta(&"track", index)
	b.set_meta(&"boss", boss)
	if not boss:
		b.pressed.connect(Audio.play_confirm)
		b.pressed.connect(_on_toggle_track.bind(index))
	# Right click auditions it. gui_input rather than a second pressed handler,
	# because a Button only reports the left one.
	b.gui_input.connect(_on_track_input.bind(b))
	_track_buttons.append(b)
	return b


func _on_track_input(event: InputEvent, b: Button) -> void:
	var click := event as InputEventMouseButton
	if click == null or not click.pressed \
			or click.button_index != MOUSE_BUTTON_RIGHT:
		return
	# Accepted so the click does not fall through to whatever is behind the panel.
	b.accept_event()
	var index: int = int(b.get_meta(&"track", 1))
	var boss: bool = bool(b.get_meta(&"boss", false))
	var name := Audio.boss_track(index) if boss else Audio.battle_track(index)
	if name == _previewing:
		# Right clicking the track already playing puts back whatever it interrupted,
		# which is the only way out of a preview without leaving the screen.
		_stop_preview()
		_refresh_tracks()
		return
	if _previewing.is_empty():
		_interrupted = Audio.now_playing()
	_previewing = name
	Audio.play_music(name)
	_refresh_tracks()


func _stop_preview() -> void:
	if _previewing.is_empty():
		return
	_previewing = ""
	if _interrupted.is_empty():
		Audio.stop_music()
	else:
		Audio.play_music(_interrupted)
	_interrupted = ""


func _on_toggle_track(index: int) -> void:
	GameSetup.toggle_track(index)
	_refresh_tracks()


func _refresh_tracks() -> void:
	var list := GameSetup.playlist()
	var only_one := GameSetup.tracks_on() <= 1
	for b in _track_buttons:
		var index: int = int(b.get_meta(&"track", 1))
		var boss: bool = bool(b.get_meta(&"boss", false))
		# Just the number, or "B1" for a boss track. Whether it is IN the rotation is
		# the colour and the pressed look, not a tick glyph competing for the space.
		b.text = Audio.boss_track_name(index) if boss else Audio.battle_track_name(index)
		var name := Audio.boss_track(index) if boss else Audio.battle_track(index)
		var playing := name == _previewing
		if boss:
			# No toggle of its own — see _build_playlist. Its own colour so it is not
			# mistaken for a battle track that has been switched off.
			b.disabled = false
			b.add_theme_color_override("font_color",
				Color(0.98, 0.84, 0.54) if playing else Color(0.72, 0.62, 0.44))
			continue
		var on: bool = list[index - 1]
		b.button_pressed = on
		# The last one standing is greyed rather than hidden, so the reason the
		# click did nothing is visible instead of mysterious.
		b.disabled = on and only_one
		b.add_theme_color_override("font_color",
			Color(1.00, 0.94, 0.70) if playing
			else (Color(0.86, 0.90, 0.96) if on else Color(0.48, 0.52, 0.60)))


func open() -> void:
	_refresh_volume()
	_refresh_portraits()
	_refresh_tracks()
	_refresh_boss()
	visible = true


func _on_done() -> void:
	# A preview must not follow the player out of the settings screen.
	_stop_preview()
	visible = false
	closed.emit()
