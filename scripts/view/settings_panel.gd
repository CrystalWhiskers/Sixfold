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

## The category faders, keyed by the Audio property each one drives.
##
## Held in dictionaries rather than as four named pairs of fields because the four are
## identical in every respect except which property they set — and the version with named
## fields was four copies of the same eight lines, which is four places to forget the
## mute-at-zero wording.
var _level_sliders: Dictionary = {}
var _level_labels: Dictionary = {}

## Each row: the Audio property it drives, and what the label calls it.
const LEVELS := [
	{prop = "volume", name = "Overall"},
	{prop = "music_volume", name = "Music"},
	{prop = "sfx_volume", name = "Effects"},
	{prop = "voice_volume", name = "Voices"},
]
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

	column.add_child(_build_levels())
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


func _build_levels() -> Control:
	var box := VBoxContainer.new()
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_theme_constant_override("separation", 4)
	for row in LEVELS:
		box.add_child(_build_level(row.prop, row.name))
	return box


func _build_level(prop: String, label_text: String) -> Control:
	var box := VBoxContainer.new()
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_theme_constant_override("separation", 2)

	var label := _heading("")
	_level_labels[prop] = label
	box.add_child(label)

	var slider := HSlider.new()
	slider.min_value = 0.0
	slider.max_value = 1.0
	# A hundred stops across the bar, so the number under it can read in whole
	# percent without the fader and the label disagreeing about where it is.
	slider.step = 0.01
	slider.value = Audio.get(prop)
	slider.custom_minimum_size = Vector2(PANEL_WIDTH * 0.6, 20.0)
	slider.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	# value_changed, not drag_ended: the whole point of a volume fader is that you
	# hear the change while you are moving it.
	slider.value_changed.connect(_on_level.bind(prop))
	_level_sliders[prop] = slider
	box.add_child(slider)

	# The first one is also the one the rest of the panel already knew about, so the
	# existing handles keep pointing at something real rather than every caller of
	# _volume_slider having to learn about the dictionary.
	if prop == "volume":
		_volume_slider = slider
		_volume_label = label

	_refresh_level(prop)
	return box


func _on_level(value: float, prop: String) -> void:
	Audio.set(prop, value)
	_refresh_level(prop)


func _refresh_level(prop: String) -> void:
	var label: Label = _level_labels.get(prop, null)
	if label == null:
		return
	var name := prop
	for row in LEVELS:
		if row.prop == prop:
			name = row.name
	# Read back off Audio rather than off the slider: Audio clamps, and a label that
	# trusted the slider would disagree with what is actually playing the moment
	# anything set the level from outside this panel.
	var level: float = Audio.get(prop)
	label.text = ("%s — muted" % name if level <= 0.0
		else "%s — %d%%" % [name, roundi(level * 100.0)])


func _refresh_volume() -> void:
	## Kept as a name because the rest of the panel and the menu suite both call it.
	for row in LEVELS:
		_refresh_level(row.prop)


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
	# Two labelled blocks, not one grid with the boss tracks tacked on the end.
	#
	# They WERE one grid, and the right click worked on the boss buttons the whole
	# time — but the only heading on screen said "Battle music", so the B row read as
	# decoration rather than as something you could click. A capability nothing names
	# is a capability nobody uses. Splitting them also stops the boss row starting
	# half way along a line whenever the battle count is not a multiple of
	# TRACKS_PER_ROW, which today it happens to be and tomorrow it will not.
	var box := VBoxContainer.new()
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_theme_constant_override("separation", 6)

	_track_buttons.clear()

	box.add_child(_heading(
		"Battle music — left click to switch a track off, right click to hear it"))
	box.add_child(_track_grid(Audio.battle_track_count, false))

	# These toggle too, and their toggle means the same thing a battle track's does:
	# switched off is out of the rotation, boss rounds included. What stays separate
	# is WHEN the ones left play — that is the Boss rounds switch below. Drawn in
	# their own colour so the two rows are not mistaken for one list.
	box.add_child(_heading(
		"Boss themes — left click to switch one off, right click to hear it"))
	box.add_child(_track_grid(Audio.boss_track_count, true))

	_refresh_tracks()
	return box


func _track_grid(count: int, boss: bool) -> Control:
	# A grid, not a row: forty tracks at 46 pixels each is nearly two thousand wide
	# and the panel is not. The grid wraps however many there turn out to be. Built
	# from the count Audio found on disk rather than a list here, so dropping
	# battle_31.ogg into assets/music puts another button on this screen with no edit
	# to this file at all.
	var grid := GridContainer.new()
	grid.columns = mini(maxi(count, 1), TRACKS_PER_ROW)
	grid.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	grid.add_theme_constant_override("h_separation", 6)
	grid.add_theme_constant_override("v_separation", 6)
	if count <= 0:
		var none := Label.new()
		none.text = "no boss tracks found" if boss else "no tracks found"
		none.add_theme_font_size_override("font_size", 13)
		grid.add_child(none)
		return grid
	for i in count:
		grid.add_child(_track_button(i + 1, boss))
	return grid


func _track_button(index: int, boss: bool) -> Button:
	var b := Button.new()
	b.custom_minimum_size = TRACK_BUTTON_SIZE
	b.add_theme_font_size_override("font_size", 15)
	# Toggle mode purely for the look — the state of record is GameSetup.playlist()
	# or boss_list(), and _refresh_tracks writes the button from it. A programmatic
	# button_pressed emits `toggled`, not `pressed`, so writing it back here cannot
	# loop.
	b.toggle_mode = true
	b.set_meta(&"track", index)
	b.set_meta(&"boss", boss)
	b.pressed.connect(Audio.play_confirm)
	b.pressed.connect(_on_toggle_track.bind(index, boss))
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


func _on_toggle_track(index: int, boss: bool) -> void:
	if boss:
		GameSetup.toggle_boss_track(index)
	else:
		GameSetup.toggle_track(index)
	_refresh_tracks()


## The four colours a track button can be, in both rows: currently being heard, in
## the rotation, switched off. The boss row runs warm and the battle row cool so the
## two are never read as one list — the SHAPE of the rule is identical, only the hue
## differs, because the rule is now identical too.
const TRACK_COLOURS := {
	false: {
		playing = Color(1.00, 0.94, 0.70),
		on = Color(0.86, 0.90, 0.96),
		off = Color(0.48, 0.52, 0.60),
	},
	true: {
		playing = Color(1.00, 0.88, 0.58),
		on = Color(0.90, 0.74, 0.44),
		off = Color(0.46, 0.40, 0.32),
	},
}


func _refresh_tracks() -> void:
	var battle := GameSetup.playlist()
	var boss_tracks := GameSetup.boss_list()
	var last_battle := GameSetup.tracks_on() <= 1
	var last_boss := GameSetup.boss_tracks_on() <= 1
	for b in _track_buttons:
		var index: int = int(b.get_meta(&"track", 1))
		var boss: bool = bool(b.get_meta(&"boss", false))
		# Just the number, or "B1" for a boss track. Whether it is IN the rotation is
		# the colour and the pressed look, not a tick glyph competing for the space.
		b.text = Audio.boss_track_name(index) if boss else Audio.battle_track_name(index)
		var name := Audio.boss_track(index) if boss else Audio.battle_track(index)
		var list: Array[bool] = boss_tracks if boss else battle
		var only_one: bool = last_boss if boss else last_battle
		if index < 1 or index > list.size():
			continue
		var on: bool = list[index - 1]
		b.button_pressed = on
		# The last one standing is greyed rather than hidden, so the reason the
		# click did nothing is visible instead of mysterious. It can still be
		# auditioned — a disabled Button stops reporting its own press, not the
		# right click, which arrives through gui_input.
		b.disabled = on and only_one
		var shades: Dictionary = TRACK_COLOURS[boss]
		var colour: Color = (shades.playing if name == _previewing
			else (shades.on if on else shades.off))
		_paint(b, colour)


## The font colour slots a track button can actually be drawn with.
##
## NOT just "font_color". That one is the RESTING colour, and a toggle button that
## is switched on is held in the pressed state, which reads font_pressed_color
## instead — so setting only the first left every switched-on boss button white
## while the switched-off ones were correctly amber. It cost a screenshot to see,
## because the battle row's "on" colour is near-white anyway and hid the same bug.
##
## font_disabled_color is deliberately absent: the last track standing is greyed by
## the theme's own disabled colour, and that dimming IS the message that it cannot
## be switched off.
const FONT_SLOTS: Array[StringName] = [
	&"font_color",
	&"font_pressed_color",
	&"font_hover_color",
	&"font_hover_pressed_color",
	&"font_focus_color",
]


func _paint(b: Button, colour: Color) -> void:
	for slot in FONT_SLOTS:
		b.add_theme_color_override(slot, colour)


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
