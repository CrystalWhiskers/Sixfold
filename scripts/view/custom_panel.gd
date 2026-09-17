class_name CustomPanel
extends Control

## The knobs a custom match gets: how long the match is, how often a buff comes
## round, how long a round lasts, and which buffs are allowed to appear at all.
##
## Built like SettingsPanel and LoadoutEditor — a full-rect panel that starts
## hidden, opens over the menu and emits `closed` when it is done — so the menu has
## one way of opening a screen rather than three.
##
## Nothing here holds state of its own. Every control writes straight into
## GameSetup and every refresh reads back out of it, which is what makes "open the
## screen again and it says what you set" true without a save step. The one thing
## this screen owns is the START button, because a custom match is a mode and you
## get into it from here rather than from the main menu.

signal closed
signal start_pressed

const PANEL_WIDTH := 620.0
const BUFF_BUTTON_SIZE := Vector2(132, 30)
const BUFFS_PER_ROW := 4

## The shortest and longest match the screen will let you ask for. Bounds rather
## than free text: a one-life match is a legitimate thing to want and a
## ninety-nine-life one is a typo.
const MIN_WINS := 1
const MAX_WINS := 12

## How often a buff pick comes round, in rounds. One is every round.
const MIN_EVERY := 1
const MAX_EVERY := 5

## The round clock, in seconds. The floor is low enough to make a frantic match and
## the ceiling is high enough that nothing ever times out.
const MIN_CLOCK := 30.0
const MAX_CLOCK := 240.0

var _pool := BuffPool.new()
var _buff_buttons: Array[Button] = []
var _wins_label: Label = null
var _wins_slider: HSlider = null
var _every_label: Label = null
var _every_slider: HSlider = null
var _clock_label: Label = null
var _clock_slider: HSlider = null
var _death_label: Label = null
var _death_slider: HSlider = null
var _picks_note: Label = null


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	visible = false
	_pool.load_all()

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
	frame.add_theme_constant_override("margin_top", 28)
	frame.add_theme_constant_override("margin_bottom", 28)
	add_child(frame)

	var column := VBoxContainer.new()
	column.alignment = BoxContainer.ALIGNMENT_CENTER
	column.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	column.add_theme_constant_override("separation", 10)
	frame.add_child(column)

	var title := Label.new()
	title.text = "Custom Match"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	title.add_theme_font_size_override("font_size", 30)
	column.add_child(title)

	_wins_label = _heading("")
	_wins_slider = _slider(MIN_WINS, MAX_WINS, 1.0, _on_wins)
	column.add_child(_wins_label)
	column.add_child(_wins_slider)

	_every_label = _heading("")
	_every_slider = _slider(MIN_EVERY, MAX_EVERY, 1.0, _on_every)
	column.add_child(_every_label)
	column.add_child(_every_slider)

	# The number that actually answers "how many buffs do I get", worked out from
	# the two sliders above rather than set on its own. Asking for more buffs is
	# asking for a longer match or a faster cadence, and showing the product is what
	# makes that legible instead of a thing you discover by playing.
	_picks_note = _heading("")
	_picks_note.add_theme_color_override("font_color", Color(0.78, 0.84, 0.62))
	column.add_child(_picks_note)

	_death_label = _heading("")
	_death_slider = _slider(MIN_CLOCK - 15.0, MAX_CLOCK - 15.0, 5.0, _on_death)
	column.add_child(_death_label)
	column.add_child(_death_slider)

	_clock_label = _heading("")
	_clock_slider = _slider(MIN_CLOCK, MAX_CLOCK, 5.0, _on_clock)
	column.add_child(_clock_label)
	column.add_child(_clock_slider)

	column.add_child(_build_buffs())

	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 12)
	column.add_child(row)
	row.add_child(_button("Reset", _on_reset))
	row.add_child(_button("Back", _on_done))
	var go := _button("Start Custom Match", _on_start)
	go.add_theme_color_override("font_color", Color(0.86, 0.92, 0.70))
	row.add_child(go)


func _heading(text: String) -> Label:
	var l := Label.new()
	l.text = text
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	l.add_theme_font_size_override("font_size", 14)
	l.add_theme_color_override("font_color", Color(0.55, 0.60, 0.70))
	return l


func _slider(low: float, high: float, step: float, handler: Callable) -> HSlider:
	var s := HSlider.new()
	s.min_value = low
	s.max_value = high
	s.step = step
	s.custom_minimum_size = Vector2(PANEL_WIDTH * 0.6, 22.0)
	s.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	s.value_changed.connect(handler)
	return s


func _button(text: String, handler: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.add_theme_font_size_override("font_size", 17)
	b.pressed.connect(Audio.play_confirm)
	b.pressed.connect(handler)
	return b


func _build_buffs() -> Control:
	var box := VBoxContainer.new()
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_theme_constant_override("separation", 6)
	box.add_child(_heading("Buffs — click one to keep it out of the match"))

	# A grid for the same reason the track list is one: forty-eight buffs in a row
	# is far wider than the screen.
	var grid := GridContainer.new()
	grid.columns = BUFFS_PER_ROW
	grid.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	grid.add_theme_constant_override("h_separation", 6)
	grid.add_theme_constant_override("v_separation", 4)
	box.add_child(grid)

	_buff_buttons.clear()
	# Sorted by name so the grid is scannable. The pool's own order is whatever the
	# filesystem handed back, which puts nothing next to anything.
	var all := _pool.buffs.duplicate()
	all.sort_custom(func(a: BuffData, b: BuffData) -> bool:
		return a.display_name < b.display_name)
	for buff in all:
		var b := Button.new()
		b.custom_minimum_size = BUFF_BUTTON_SIZE
		b.add_theme_font_size_override("font_size", 12)
		b.toggle_mode = true
		b.set_meta(&"buff", buff.id)
		b.tooltip_text = buff.describe(BuffData.Rarity.GOLD)
		b.pressed.connect(Audio.play_select)
		b.pressed.connect(_on_toggle_buff.bind(buff.id))
		grid.add_child(b)
		_buff_buttons.append(b)
	if _buff_buttons.is_empty():
		grid.add_child(_heading("no buffs found"))
	return box


func _on_toggle_buff(id: StringName) -> void:
	var banned := not GameSetup.is_banned(id)
	if banned and _allowed_count() <= floor_allowed():
		_refresh_buffs()
		return
	GameSetup.set_banned(id, banned)
	_refresh_buffs()


func floor_allowed() -> int:
	## The fewest buffs a match may be left with: enough to fill one pick.
	##
	## Not one. BuffPool.offer() has a deliberate fallback — if the exclusions empty
	## the pool it ignores them and offers from everything — so a match banned down to
	## one or two buffs does not get a short pick, it gets EVERY buff back, silently.
	## Stopping at three means the bans always mean what they say.
	return BuffPool.OPTIONS


func _allowed_count() -> int:
	var n := 0
	for buff in _pool.buffs:
		if not GameSetup.is_banned(buff.id):
			n += 1
	return n


func _on_wins(value: float) -> void:
	GameSetup.custom_wins = int(value)
	_refresh_numbers()


func _on_every(value: float) -> void:
	GameSetup.custom_buff_every = int(value)
	_refresh_numbers()


func _on_death(value: float) -> void:
	GameSetup.custom_sudden_death = value
	# Sudden death has to stay below the round clock or it never fires, so pushing it
	# up pushes the clock up with it rather than being silently clamped later.
	if GameSetup.custom_timeout < value + 15.0:
		GameSetup.custom_timeout = minf(value + 15.0, MAX_CLOCK)
	_refresh_numbers()


func _on_clock(value: float) -> void:
	GameSetup.custom_timeout = value
	if GameSetup.custom_sudden_death > value - 15.0:
		GameSetup.custom_sudden_death = maxf(value - 15.0, MIN_CLOCK - 15.0)
	_refresh_numbers()


func _on_reset() -> void:
	GameSetup.reset_custom()
	_refresh()


func _on_start() -> void:
	# Mode first: setting the mode to anything else clears `custom`, so writing the
	# flag first would have it wiped a line later.
	GameSetup.mode = GameSetup.Mode.CUSTOM
	GameSetup.custom = true
	visible = false
	start_pressed.emit()


func _on_done() -> void:
	visible = false
	closed.emit()


func open() -> void:
	# Switched on as the screen opens, so every number the screen shows is the number
	# a match would actually use — GameSetup's getters all return the conventional
	# value while `custom` is off, and a screen showing those while claiming to be
	# editing them would be lying.
	GameSetup.custom = true
	if GameSetup.custom_wins <= 0:
		GameSetup.custom_wins = MatchState.WINS_NEEDED
	_refresh()
	visible = true


func picks_in_match() -> int:
	## How many buff picks a match of this length and cadence actually reaches.
	##
	## A side loses when it has run out of lives, so the LONGEST a match can run is
	## one round short of both sides reaching the line — and the number of picks in it
	## follows from the cadence. This is the figure the player is really setting when
	## they ask for "more than the conventional three buffs".
	var rounds := GameSetup.wins_needed() * 2 - 1
	return rounds / GameSetup.buff_every()


func _refresh() -> void:
	_wins_slider.set_value_no_signal(float(GameSetup.wins_needed()))
	_every_slider.set_value_no_signal(float(GameSetup.buff_every()))
	_death_slider.set_value_no_signal(GameSetup.sudden_death_at())
	_clock_slider.set_value_no_signal(GameSetup.round_timeout())
	_refresh_numbers()
	_refresh_buffs()


func _refresh_numbers() -> void:
	var lives := GameSetup.wins_needed()
	_wins_label.text = "Match length — %d %s each" % [
		lives, "life" if lives == 1 else "lives"]
	var every := GameSetup.buff_every()
	_every_label.text = ("A buff every round" if every == 1
		else "A buff every %d rounds" % every)
	var picks := picks_in_match()
	_picks_note.text = "Up to %d buff %s in the longest match this allows" % [
		picks, "pick" if picks == 1 else "picks"]
	_death_label.text = "Sudden death at %s" % _clock_text(GameSetup.sudden_death_at())
	_clock_label.text = "Round called a draw at %s" % _clock_text(
		GameSetup.round_timeout())


func _clock_text(seconds: float) -> String:
	return "%d:%02d" % [int(seconds) / 60, int(seconds) % 60]


func _refresh_buffs() -> void:
	# The same rule the click uses, or the greying tells the player something other
	# than what the screen will actually do — they disagreed for exactly one commit
	# and the greying vanished while the refusal stayed.
	var at_floor := _allowed_count() <= floor_allowed()
	for b in _buff_buttons:
		var id: StringName = b.get_meta(&"buff", &"")
		var banned := GameSetup.is_banned(id)
		var buff := _pool.by_id(id)
		b.text = "" if buff == null else buff.display_name
		# Pressed means BANNED, which is the opposite of the track list next door —
		# and it is the right way round here: the default is everything allowed, so an
		# unpressed grid is a grid you have not touched.
		b.button_pressed = banned
		# The last few allowed are greyed rather than silently refusing, so the reason
		# the click does nothing is visible.
		b.disabled = at_floor and not banned
		b.add_theme_color_override("font_color",
			Color(0.52, 0.44, 0.46) if banned else Color(0.82, 0.88, 0.96))
