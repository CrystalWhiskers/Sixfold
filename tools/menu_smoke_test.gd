extends Node

var _menu: Control
var _failed := 0
var _passed := 0


func _check(label: String, condition: bool, detail := "") -> void:
	if condition:
		_passed += 1
		print("  ok    %s" % label)
	else:
		_failed += 1
		print("  FAIL  %s %s" % [label, detail])


func _ready() -> void:
	print("\n=== Sixfold — menu smoke test ===\n")
	GameSetup.reload_catalogue()
	_check("the menu loads its maps", GameSetup.maps.size() >= 5,
		"%d maps" % GameSetup.maps.size())
	_check("and starts on one of them", GameSetup.current_map() != null)
	# Tied to what is actually on disk rather than a number in this file, so
	# adding a unit does not fail a test that has nothing to do with it.
	var roster := load("res://data/loadouts/roster.tres") as LoadoutData
	_check("the menu knows every unit type",
		roster != null and GameSetup.catalogue.size() == roster.units.size(),
		"menu has %d, roster has %d" % [
			GameSetup.catalogue.size(),
			0 if roster == null else roster.units.size()])
	_check("and none of them are units you are not meant to draw",
		not GameSetup.catalogue.any(func(u: UnitData) -> bool:
			return String(u.id) in ["wisp", "sentry"]))
	var ids: PackedStringArray = []
	for u in GameSetup.catalogue:
		ids.append(String(u.id))
	var absent: PackedStringArray = []
	for want in ["assassin", "herald", "revenant", "seraph", "conjurer", "transcendence",
			"amalgam", "spire", "wellspring"]:
		if not ids.has(want):
			absent.append(want)
	_check("the newer units are all pickable", absent.is_empty(),
		"missing %s" % ", ".join(absent))
	_check("the summoned Wisp is not pickable", not ids.has("wisp"),
		"catalogue is %s" % ", ".join(ids))
	_check("a fresh loadout still holds five slots from fourteen types",
		GameSetup.slots_for(BoardModel.TEAM_B).size() == GameSetup.SLOTS)
	_check("each side starts with one of each",
		GameSetup.slots_for(BoardModel.TEAM_A) == GameSetup.default_slots()
		and GameSetup.units_for(BoardModel.TEAM_B).size() == GameSetup.SLOTS)

	var packed := load("res://scenes/menu.tscn") as PackedScene
	_check("menu.tscn loads", packed != null)
	if packed == null:
		_report()
		return
	_menu = packed.instantiate() as Control
	add_child(_menu)
	call_deferred("_run")


func _check_volume_slider() -> void:
	_section_volume()
	var panel: SettingsPanel = _menu._settings
	_check("the settings panel exists and starts hidden or shut",
		panel != null)
	if panel == null:
		return
	panel.open()
	var slider: HSlider = panel._volume_slider
	_check("it has a volume slider", slider != null)
	if slider == null:
		return
	var started := Audio.volume
	_check("the slider runs from silence to full",
		is_equal_approx(slider.min_value, 0.0)
		and is_equal_approx(slider.max_value, 1.0),
		"%.2f to %.2f" % [slider.min_value, slider.max_value])

	var bus := AudioServer.get_bus_index("Master")
	_check("there is a Master bus to drive", bus >= 0)

	slider.value = 0.5
	_check("moving it sets the volume", is_equal_approx(Audio.volume, 0.5),
		"%.2f" % Audio.volume)
	_check("and the label says where it is",
		panel._volume_label.text.contains("50"), panel._volume_label.text)
	# The fader moves the BUS, not the level constants — the mix ladder between
	# the swings, the crits and the bell has to survive a volume change intact.
	if bus >= 0:
		_check("half volume is a quieter bus, not a quieter melee constant",
			AudioServer.get_bus_volume_db(bus) < 0.0
			and is_equal_approx(Audio.MELEE_DB, -12.0),
			"bus at %.1f dB" % AudioServer.get_bus_volume_db(bus))

	slider.value = 0.0
	_check("dragged to the bottom it mutes outright, not nearly",
		bus < 0 or AudioServer.is_bus_mute(bus))
	_check("and the label says muted, not 0%",
		panel._volume_label.text.contains("muted"), panel._volume_label.text)

	slider.value = 1.0
	_check("and back up unmutes it", bus < 0 or not AudioServer.is_bus_mute(bus))
	Audio.volume = started
	panel._on_done()
	_check("Done closes the panel", not panel.visible)


func _section_volume() -> void:
	print("\nSettings")



func _tracks_on_disk(prefix: String) -> int:
	## How many <prefix>_N.ogg files are actually there, counted the way the folder is
	## rather than the way Audio walks it — otherwise this would be checking the counter
	## against itself and a gap in the numbering would agree with itself perfectly.
	var dir := DirAccess.open("res://assets/music")
	if dir == null:
		return -1
	var highest := 0
	var found := 0
	for file_name in dir.get_files():
		# .import files are skipped rather than trimmed. Trimming them turns
		# "boss_1.ogg.import" back into "boss_1.ogg" and every track gets counted twice,
		# which is exactly what the first version of this did.
		if file_name.ends_with(".import"):
			continue
		var clean := file_name.trim_suffix(".remap")
		if not clean.ends_with(".ogg") or not clean.begins_with(prefix + "_"):
			continue
		var n := clean.trim_suffix(".ogg").substr(prefix.length() + 1).to_int()
		if n <= 0:
			continue
		found += 1
		highest = maxi(highest, n)
	# Reported as the highest number only when the run is unbroken. A folder holding
	# 1..20 and 30 has thirty as its highest and twenty-one files, and the playlist a
	# player hears stops at twenty — so the mismatch is the thing worth surfacing.
	return highest if highest == found else -found


func _check_boss_music() -> void:
	print("\nBoss music")
	var panel: SettingsPanel = _menu._settings
	if panel == null:
		return
	panel.open()
	# Counted off the folder rather than pinned to a number. The old version asserted
	# "eighteen", which is a fact about how much music happened to be in the project on
	# the day it was written — it broke the moment a track was added, and it never
	# actually tested anything the counter could get wrong.
	#
	# What the counter CAN get wrong is stopping early, because it walks upward from 1
	# until a number is missing. A gap in the sequence silently truncates the playlist
	# and the only symptom is music you never hear, so that is what is checked here.
	_check("every boss track on disk is loaded",
		Audio.boss_track_count == _tracks_on_disk("boss"),
		"counter says %d, folder has %d" % [
			Audio.boss_track_count, _tracks_on_disk("boss")])
	_check("and every battle track too",
		Audio.battle_track_count == _tracks_on_disk("battle"),
		"counter says %d, folder has %d" % [
			Audio.battle_track_count, _tracks_on_disk("battle")])
	_check("there is a real playlist to draw from",
		Audio.boss_track_count >= 1 and Audio.battle_track_count >= 2,
		"%d boss, %d battle" % [Audio.boss_track_count, Audio.battle_track_count])
	_check("boss tracks are named apart from the battle ones",
		Audio.boss_track(1) == "boss_1"
		and Audio.boss_track_name(1) == "B1",
		"%s / %s" % [Audio.boss_track(1), Audio.boss_track_name(1)])

	var started := GameSetup.boss_in_pool
	GameSetup.boss_in_pool = false
	panel._refresh_boss()
	_check("they stay out of the ordinary rotation by default",
		not GameSetup.boss_in_pool
		and panel._boss_button.text == "Boss rounds only",
		panel._boss_button.text)

	# With them out, forty rolls of the battle track must never land on a boss.
	var leaked := 0
	for i in 200:
		if GameSetup.roll_battle_track().begins_with("boss_"):
			leaked += 1
	_check("and a battle roll never returns one", leaked == 0,
		"%d of 200 rolls were boss tracks" % leaked)

	panel._boss_button.pressed.emit()
	_check("the switch lets them in", GameSetup.boss_in_pool)
	_check("and says where they play now",
		panel._boss_button.text == "Boss rounds and ordinary rounds",
		panel._boss_button.text)
	var got := 0
	for i in 400:
		if GameSetup.roll_battle_track().begins_with("boss_"):
			got += 1
	_check("a battle roll can now land on one", got > 0,
		"never in 400 rolls")

	panel._boss_button.pressed.emit()
	_check("and switching it back shuts them out again",
		not GameSetup.boss_in_pool)

	# The boss rule itself: a tier 6 anywhere on the board, either side.
	BoardModel.reset_map()
	var b := BoardModel.new()
	_check("an empty board is not a boss round",
		not GameSetup.is_boss_round(b))
	var low: UnitData = load("res://data/units/warden_t1.tres")
	b.force_place(UnitInstance.create(low, BoardModel.TEAM_B), Vector2i(2, 8))
	_check("nor is one with only low tiers on it",
		not GameSetup.is_boss_round(b))
	var top: UnitData = load("res://data/units/warden_t6.tres")
	# On the ENEMY half, because walking into their tier 6 is the moment this is
	# most worth marking — the rule is about the field, not about who owns it.
	var boss := UnitInstance.create(top, BoardModel.TEAM_A)
	b.force_place(boss, Vector2i(2, 2))
	_check("an enemy tier 6 makes it a boss round",
		GameSetup.is_boss_round(b))
	boss.current_hp = 0.0
	_check("and a dead one does not", not GameSetup.is_boss_round(b))
	BoardModel.reset_map()

	_check("rolling a boss track gives a boss track",
		GameSetup.roll_boss_track().begins_with("boss_"),
		GameSetup.roll_boss_track())

	GameSetup.boss_in_pool = started
	panel._refresh_boss()
	panel._on_done()


func _check_portrait_toggle() -> void:
	# The switch that turns unit art off, so the coloured blocks can be used while
	# the portraits are placeholder material.
	# The settings live behind the Settings button now, so the panel has to be
	# open before anything in it has a position or can be clicked.
	_menu._settings.open()
	var b: Button = _menu._settings._portrait_button
	_check("the menu has a portrait switch", b != null)
	if b == null:
		return
	var started_on := GameSetup.portraits
	GameSetup.portraits = true
	_menu._settings._refresh_portraits()
	_check("portraits are on by default and the button says so",
		GameSetup.portraits and b.button_pressed and b.text == "Portraits",
		"reads '%s'" % b.text)

	# A unit that HAS art. Whether it draws that art is the whole question, and
	# the one function both draw sites ask is where the answer comes from.
	var warden: UnitData = load("res://data/units/warden_t1.tres")
	_check("the test unit has a portrait to hide",
		warden != null and warden.sprite != null)
	if warden == null or warden.sprite == null:
		return
	_check("with the switch on, it hands back the unit's art",
		UnitView.portrait_for(warden) == warden.sprite)
	# The setting lives on GameSetup and the flag lives on UnitView, because the
	# two scripts that DRAW a unit must not reach for an autoload — one that does
	# will not compile in the headless model suite, and every test touching it is
	# then skipped without saying so. This is the check that they stay in step.
	_check("the setting is written down to the view layer",
		UnitView.portraits_on == GameSetup.portraits)

	b.pressed.emit()
	_check("clicking it turns portraits off", not GameSetup.portraits)
	_check("the button now says what the board will look like instead",
		b.text == "Coloured blocks" and not b.button_pressed,
		"reads '%s'" % b.text)
	# Null, not a flag: the art-less path is the path portraits-off takes, so
	# there is only ever one placeholder look in the game.
	_check("the flag followed it down", not UnitView.portraits_on)
	_check("and the unit reports no art at all, exactly like an art-less unit",
		UnitView.portrait_for(warden) == null)

	b.pressed.emit()
	_check("clicking again puts the art back", GameSetup.portraits
		and UnitView.portrait_for(warden) == warden.sprite)
	_check("and the label goes back too", b.text == "Portraits")

	# A unit with no art is unaffected either way — the switch removes art, it
	# does not add a second placeholder.
	var wisp: UnitData = load("res://data/units/wisp_t1.tres")
	if wisp != null and wisp.sprite == null:
		GameSetup.portraits = false
		var off := UnitView.portrait_for(wisp)
		GameSetup.portraits = true
		_check("a unit that never had art reads the same with the switch either way",
			off == null and UnitView.portrait_for(wisp) == null)

	GameSetup.portraits = started_on
	_menu._settings._refresh_portraits()


func _check_playlist(_buttons_unused: Array) -> void:
	# Read the toggles off the menu rather than sniffing button text: the labels
	# are bare numbers now, and matching "ends with 1" against every Button on the
	# screen finds things that are not tracks.
	_menu._settings.open()
	# The grid now holds the boss tracks as well, for auditioning — see
	# SettingsPanel._build_playlist. Only the battle ones carry a toggle, so the
	# rotation checks below have to be read off the battle subset rather than off
	# every button on the screen.
	var all_buttons: Array[Button] = _menu._settings._track_buttons
	var toggles: Array[Button] = []
	var boss_buttons: Array[Button] = []
	for b in all_buttons:
		if bool(b.get_meta(&"boss", false)):
			boss_buttons.append(b)
		else:
			toggles.append(b)
	var count: int = Audio.battle_track_count
	_check("there is a toggle for every battle track",
		toggles.size() == count and count >= 2,
		"%d buttons for %d tracks" % [toggles.size(), count])
	_check("and a button for every boss track too, so they can be heard",
		boss_buttons.size() == Audio.boss_track_count
		and Audio.boss_track_count >= 1,
		"%d buttons for %d boss tracks" % [
			boss_buttons.size(), Audio.boss_track_count])
	if toggles.size() < 2:
		return
	var numbered := true
	for i in toggles.size():
		if String(toggles[i].text) != str(i + 1):
			numbered = false
	_check("and each one is labelled with its number and nothing else", numbered,
		"first three read %s, %s, %s" % [
			toggles[0].text, toggles[1].text, toggles[2].text])
	var marked := true
	for i in boss_buttons.size():
		if String(boss_buttons[i].text) != "B%d" % (i + 1):
			marked = false
	_check("and the boss ones are marked apart rather than renumbered", marked,
		"first boss button reads %s" % (
			"none" if boss_buttons.is_empty() else boss_buttons[0].text))
	# A boss track's toggle means nothing — whether they enter the ordinary rotation
	# is the Boss rounds switch — so they must not be togglable here, or the screen
	# offers two controls for one rule.
	var togglable := 0
	for b in boss_buttons:
		if b.toggle_mode:
			togglable += 1
	_check("boss buttons are preview-only, not a second rotation control",
		togglable == 0, "%d of them are toggles" % togglable)

	var screen := Rect2(Vector2.ZERO, _menu.get_viewport_rect().size)
	var spilled := 0
	for b in all_buttons:
		if not screen.encloses(Rect2(b.global_position, b.size)):
			spilled += 1
	# Ten in a single row would be 1500 pixels wide. The grid is what keeps them
	# on the screen, and this is the check that says so.
	_check("every track button fits on the screen", spilled == 0,
		"%d of %d are off the edge" % [spilled, all_buttons.size()])

	_check("every track starts in the rotation", GameSetup.tracks_on() == count,
		"%d of %d" % [GameSetup.tracks_on(), count])
	var rolled := {}
	for i in count * 40:
		rolled[GameSetup.roll_battle_track()] = true
	_check("and a round can roll any of them", rolled.size() == count,
		"only ever rolled %d of %d" % [rolled.size(), count])

	toggles[0].pressed.emit()
	_check("switching one off takes it out of the rotation",
		GameSetup.tracks_on() == count - 1, "%d still on" % GameSetup.tracks_on())
	var gone := Audio.battle_track(1)
	var after := {}
	for i in count * 40:
		after[GameSetup.roll_battle_track()] = true
	_check("and it is never rolled again", not after.has(gone),
		"%s came up anyway" % gone)

	# Switch off everything except the last one, then try that one too.
	for i in range(1, toggles.size() - 1):
		toggles[i].pressed.emit()
	_check("they can all be switched off but one", GameSetup.tracks_on() == 1,
		"%d on" % GameSetup.tracks_on())
	var last := toggles[toggles.size() - 1]
	last.pressed.emit()
	_check("and the last one standing cannot be switched off",
		GameSetup.tracks_on() == 1, "%d on" % GameSetup.tracks_on())
	_check("it is greyed out so the refusal is visible rather than mysterious",
		last.disabled)

	for i in toggles.size() - 1:
		toggles[i].pressed.emit()
	_check("switching them back on restores the whole rotation",
		GameSetup.tracks_on() == count, "%d on" % GameSetup.tracks_on())

	_check_track_preview(toggles, boss_buttons)


func _right_click(b: Button) -> void:
	var click := InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_RIGHT
	click.pressed = true
	b.gui_input.emit(click)


func _check_track_preview(toggles: Array[Button], boss: Array[Button]) -> void:
	print("\nTrack preview")
	var panel: SettingsPanel = _menu._settings
	# Something has to be playing first, or "puts back what it interrupted" has
	# nothing to put back and the check passes for the wrong reason.
	Audio.play_music("menu_theme")
	var before := Audio.now_playing()
	_check("the menu theme is playing before any preview", before == "menu_theme",
		before)

	_right_click(toggles[2])
	_check("right clicking a battle track plays it",
		Audio.now_playing() == Audio.battle_track(3), Audio.now_playing())
	_check("and the button says which one is being heard",
		panel._previewing == Audio.battle_track(3), panel._previewing)
	# The LEFT click still only toggles. A right click that also switched the track
	# out of the rotation would make auditioning destructive.
	var on_before := GameSetup.tracks_on()
	_right_click(toggles[3])
	_check("and auditioning one does not change the rotation",
		GameSetup.tracks_on() == on_before,
		"%d on, was %d" % [GameSetup.tracks_on(), on_before])
	_check("right clicking another switches the preview over",
		Audio.now_playing() == Audio.battle_track(4), Audio.now_playing())

	if not boss.is_empty():
		_right_click(boss[0])
		_check("boss tracks can be auditioned too",
			Audio.now_playing() == Audio.boss_track(1), Audio.now_playing())
		# Even while they are shut out of the ordinary rotation: hearing one and
		# letting one come up in a round are different questions.
		var was := GameSetup.boss_in_pool
		GameSetup.boss_in_pool = false
		panel._refresh_boss()
		_right_click(boss[0])
		_right_click(boss[0])
		_check("including while they are shut out of ordinary rounds",
			Audio.now_playing() == Audio.boss_track(1)
			and not GameSetup.boss_in_pool, Audio.now_playing())
		GameSetup.boss_in_pool = was
		panel._refresh_boss()

	# Right clicking whatever is playing stops the preview and puts back what it
	# interrupted.
	var playing := panel._previewing
	_right_click(_button_for(toggles + boss, playing))
	_check("right clicking it again puts back what it interrupted",
		Audio.now_playing() == "menu_theme", Audio.now_playing())
	_check("and nothing is marked as previewing", panel._previewing.is_empty(),
		panel._previewing)

	# And closing the screen cannot leave a preview running.
	_right_click(toggles[1])
	_check("a preview is playing before Done", panel._previewing != "")
	panel._on_done()
	_check("Done puts the music back as well",
		Audio.now_playing() == "menu_theme" and panel._previewing.is_empty(),
		Audio.now_playing())
	panel.open()


func _button_for(buttons: Array[Button], track: String) -> Button:
	for b in buttons:
		var index: int = int(b.get_meta(&"track", 1))
		var boss: bool = bool(b.get_meta(&"boss", false))
		var name := Audio.boss_track(index) if boss else Audio.battle_track(index)
		if name == track:
			return b
	return buttons[0]


func _check_custom_matches() -> void:
	print("\nCustom matches")
	var panel: CustomPanel = _menu._custom
	_check("the menu has a custom match screen", panel != null)
	if panel == null:
		return
	var was_mode := GameSetup.mode
	var was_custom := GameSetup.custom
	GameSetup.custom = false
	GameSetup.reset_custom()

	# With the rules off, every getter has to hand back the conventional value. That
	# is what makes "off" a single code path rather than a second set of defaults
	# living somewhere else and rotting.
	_check("with custom off the match is the conventional one",
		GameSetup.wins_needed() == MatchState.WINS_NEEDED
		and GameSetup.buff_every() == 2
		and is_equal_approx(GameSetup.sudden_death_at(), CombatSim.SUDDEN_DEATH)
		and is_equal_approx(GameSetup.round_timeout(), CombatSim.DEFAULT_TIMEOUT),
		"%d lives, every %d, %.0f / %.0f" % [GameSetup.wins_needed(),
			GameSetup.buff_every(), GameSetup.sudden_death_at(),
			GameSetup.round_timeout()])
	_check("and no buff is banned", GameSetup.banned_buffs().is_empty())

	_check("the screen starts hidden", not panel.visible)
	panel.open()
	_check("opening it shows it and turns the rules on",
		panel.visible and GameSetup.custom)

	# Match length, and the number that follows from it. "More than the conventional
	# three buffs" is what the player is really asking for, so the screen has to say
	# how many they are going to get.
	var short_picks := panel.picks_in_match()
	panel._wins_slider.value = 8
	_check("the length slider sets the lives", GameSetup.wins_needed() == 8,
		"%d lives" % GameSetup.wins_needed())
	_check("a longer match reaches more buff picks",
		panel.picks_in_match() > short_picks,
		"%d picks against %d" % [panel.picks_in_match(), short_picks])
	_check("and the screen says how many", panel._picks_note.text.contains(
		str(panel.picks_in_match())), panel._picks_note.text)
	_check("which is more than the conventional three",
		panel.picks_in_match() > 3, "%d picks" % panel.picks_in_match())

	# MatchState has to agree, or the number on the screen is decoration.
	MatchState.wins = [7, 0]
	_check("the match is not over at seven of eight", not MatchState.is_match_over())
	MatchState.wins = [8, 0]
	_check("and is at eight", MatchState.is_match_over()
		and MatchState.match_winner() == 0)
	MatchState.wins = [0, 0]
	_check("lives left counts down from the custom number",
		MatchState.lives_left(BoardModel.TEAM_A) == 8,
		"%d" % MatchState.lives_left(BoardModel.TEAM_A))

	# The cadence, and that the ROUND LOOP reads it — buff_pick_due is what decides
	# whether a pick happens at all.
	panel._every_slider.value = 1
	_check("a cadence of one means a buff every round",
		GameSetup.buff_every() == 1)
	MatchState.round_index = 3
	_check("so round three is a pick round", MatchState.buff_pick_due())
	panel._every_slider.value = 4
	_check("and at every four rounds it is not",
		not MatchState.buff_pick_due(), "round 3, every %d" % GameSetup.buff_every())
	MatchState.round_index = 4
	_check("but round four is", MatchState.buff_pick_due())
	_check("and the rarity odds advance on the cadence, not the round",
		MatchState.buff_pick_number() == 1,
		"pick %d on round 4 at every 4" % MatchState.buff_pick_number())
	MatchState.round_index = 1

	# The clock.
	panel._death_slider.value = 40.0
	_check("the sudden death slider sets it",
		is_equal_approx(GameSetup.sudden_death_at(), 40.0),
		"%.0f" % GameSetup.sudden_death_at())
	# Dragging sudden death up past the draw clock has to carry the clock with it,
	# because a sudden death after the round has already been called never fires.
	panel._death_slider.value = panel.MAX_CLOCK - 15.0
	_check("pushing it up pushes the draw clock up too",
		GameSetup.round_timeout() > GameSetup.sudden_death_at(),
		"%.0f against %.0f" % [GameSetup.round_timeout(),
			GameSetup.sudden_death_at()])
	panel._clock_slider.value = panel.MIN_CLOCK
	_check("and pulling the draw clock down pulls sudden death with it",
		GameSetup.sudden_death_at() < GameSetup.round_timeout(),
		"%.0f against %.0f" % [GameSetup.sudden_death_at(),
			GameSetup.round_timeout()])

	# Which buffs may appear.
	var buttons: Array[Button] = panel._buff_buttons
	_check("every buff has a switch", buttons.size() == _buff_count(),
		"%d switches for %d buffs" % [buttons.size(), _buff_count()])
	if buttons.is_empty():
		return
	var first: StringName = buttons[0].get_meta(&"buff", &"")
	buttons[0].pressed.emit()
	_check("switching one off bans it", GameSetup.is_banned(first),
		String(first))
	_check("and it is reported as an exclusion",
		GameSetup.banned_buffs().has(first))
	buttons[0].pressed.emit()
	_check("switching it back on allows it again", not GameSetup.is_banned(first))

	# Banning down to nothing would not give the player a short pick — BuffPool.offer
	# ignores the exclusions once they empty the pool and hands back EVERY buff — so
	# the screen stops at enough for one full pick, and the ones it will not ban are
	# greyed rather than silently refusing.
	for b in buttons:
		b.pressed.emit()
	var allowed := 0
	for b in buttons:
		if not GameSetup.is_banned(b.get_meta(&"buff", &"")):
			allowed += 1
	_check("it stops at enough buffs to fill one pick",
		allowed == panel.floor_allowed() and allowed == BuffPool.OPTIONS,
		"%d allowed, floor is %d" % [allowed, panel.floor_allowed()])
	var greyed := 0
	for b in buttons:
		if not GameSetup.is_banned(b.get_meta(&"buff", &"")):
			if b.disabled:
				greyed += 1
	_check("and every one it will not ban is greyed, so the refusal is visible",
		greyed == allowed, "%d of %d greyed" % [greyed, allowed])

	panel._on_reset()
	_check("Reset puts everything back", GameSetup.banned_buffs().is_empty()
		and GameSetup.wins_needed() == MatchState.WINS_NEEDED
		and GameSetup.buff_every() == 2)
	panel._on_done()
	_check("Back closes it", not panel.visible)

	# Backing out of the screen must not leave an ordinary match running custom
	# rules. Structural rather than remembered: picking any other mode clears them,
	# so there is no code path that can carry them into an ordinary match.
	GameSetup.custom = true
	GameSetup.mode = GameSetup.Mode.VS_COMPUTER
	_check("choosing an ordinary mode clears the custom rules",
		not GameSetup.custom)
	GameSetup.custom = true
	GameSetup.mode = GameSetup.Mode.LOCAL_PVP
	_check("either ordinary mode, not just one of them", not GameSetup.custom)
	GameSetup.mode = GameSetup.Mode.CUSTOM
	GameSetup.custom = true
	_check("and the custom mode keeps them", GameSetup.custom)
	GameSetup.mode = was_mode
	GameSetup.custom = was_custom
	GameSetup.reset_custom()


func _buff_count() -> int:
	var pool := BuffPool.new()
	pool.load_all()
	return pool.buffs.size()


func _check_drawn_rounds() -> void:
	# MatchState is an autoload, so this cannot live in the headless suite.
	var before_a := MatchState.wins[0]
	var before_b := MatchState.wins[1]
	var lives_a := MatchState.lives_left(0)
	var lives_b := MatchState.lives_left(1)
	MatchState.record_round(CombatSim.RESULT_DRAW)
	_check("both scores move", MatchState.wins[0] == before_a + 1
		and MatchState.wins[1] == before_b + 1,
		"%d/%d became %d/%d" % [before_a, before_b,
			MatchState.wins[0], MatchState.wins[1]])
	_check("which is a life off each of them",
		MatchState.lives_left(0) == lives_a - 1
		and MatchState.lives_left(1) == lives_b - 1,
		"%d and %d left" % [MatchState.lives_left(0), MatchState.lives_left(1)])

	# A real win still only costs the loser.
	var was := MatchState.wins[1]
	MatchState.record_round(0)
	_check("a won round still only takes from the loser",
		MatchState.wins[0] == before_a + 2 and MatchState.wins[1] == was)

	# Both sides can now cross the line together, so match_winner has to have an
	# answer for it rather than picking whoever is checked first.
	MatchState.wins[0] = MatchState.WINS_NEEDED
	MatchState.wins[1] = MatchState.WINS_NEEDED
	_check("a match that ends dead level has no winner",
		MatchState.is_match_over() and MatchState.match_winner() < 0,
		"winner %d" % MatchState.match_winner())
	MatchState.wins[0] = MatchState.WINS_NEEDED + 1
	_check("but ahead on the line still wins it",
		MatchState.match_winner() == 0, "winner %d" % MatchState.match_winner())
	MatchState.wins = [0, 0]


func _run() -> void:
	await get_tree().process_frame
	await get_tree().process_frame

	var buttons := _buttons(_menu)
	var labels: PackedStringArray = []
	for b in buttons:
		labels.append(b.text)
	_check("the menu offers all five choices",
		labels.has("Battle the Computer") and labels.has("Local PvP")
		and labels.has("Custom Match") and labels.has("Loadouts")
		and labels.has("Settings"),
		"found %s" % str(labels))

	var screen := Rect2(Vector2.ZERO, _menu.get_viewport_rect().size)
	var spilled: PackedStringArray = []
	for b in buttons:
		if not screen.encloses(Rect2(b.global_position, b.size)):
			spilled.append(b.text)
	_check("every menu button is on screen", spilled.is_empty(), "; ".join(spilled))
	await _check_backdrop()
	_check_playlist(buttons)
	_check_portrait_toggle()
	_check_volume_slider()
	_check_boss_music()
	_check_custom_matches()
	_check_drawn_rounds()

	GameSetup.mode = GameSetup.Mode.VS_COMPUTER
	_check("vs computer means only you are human",
		GameSetup.is_human(BoardModel.TEAM_B)
		and not GameSetup.is_human(BoardModel.TEAM_A))
	_check("vs computer names the sides You and Computer",
		GameSetup.team_name(BoardModel.TEAM_B) == "You"
		and GameSetup.team_name(BoardModel.TEAM_A) == "Computer")

	GameSetup.mode = GameSetup.Mode.LOCAL_PVP
	_check("local pvp makes both sides human",
		GameSetup.is_human(BoardModel.TEAM_A)
		and GameSetup.is_human(BoardModel.TEAM_B))
	_check("Player 1 is the bottom half, Player 2 the top",
		GameSetup.team_name(BoardModel.TEAM_B) == "Player 1"
		and GameSetup.team_name(BoardModel.TEAM_A) == "Player 2")
	var want_order: Array[int] = [BoardModel.TEAM_B, BoardModel.TEAM_A]
	_check("the turn order is fixed: bottom half first",
		GameSetup.turn_order() == want_order, str(GameSetup.turn_order()))
	_check("the editor lists Player 1 above Player 2",
		_menu._editor._heading(BoardModel.TEAM_B) == "Player 1"
		and _menu._editor._heading(BoardModel.TEAM_A) == "Player 2")

	var editor: LoadoutEditor = _menu._editor
	_check("the loadout editor starts hidden", not editor.visible)
	editor.open()
	await get_tree().process_frame
	await get_tree().process_frame
	_check("opening the editor shows it", editor.visible)

	var before := GameSetup.units_for(BoardModel.TEAM_B).duplicate()
	editor._on_cycle(BoardModel.TEAM_B, 0, 1)
	_check("cycling a slot changes that player's units",
		GameSetup.units_for(BoardModel.TEAM_B) != before)
	_check("cycling one player leaves the other alone",
		GameSetup.units_for(BoardModel.TEAM_A) == GameSetup.default_units_check())

	var wrapped := GameSetup.units_for(BoardModel.TEAM_B)
	for i in GameSetup.catalogue.size():
		editor._on_cycle(BoardModel.TEAM_B, 0, 1)
	_check("cycling all the way round comes back to where it started",
		GameSetup.units_for(BoardModel.TEAM_B) == wrapped)

	for i in GameSetup.SLOTS:
		GameSetup.set_slot(BoardModel.TEAM_B, i, 1)
	_check("a player can stack the same unit in every slot",
		GameSetup.slot_summary(BoardModel.TEAM_B).contains("x5"),
		GameSetup.slot_summary(BoardModel.TEAM_B))
	var stacked := GameSetup.loadout_for(BoardModel.TEAM_B)
	_check("a stacked loadout is still valid", stacked.is_valid())
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	var only_one := true
	for u in stacked.draw(rng, 20):
		if u.id != GameSetup.catalogue[1].id:
			only_one = false
	_check("stacking one unit means you only draw that unit", only_one)

	editor._on_reset()
	_check("reset puts both sides back to one of each",
		GameSetup.slots_for(BoardModel.TEAM_B) == GameSetup.default_slots()
		and GameSetup.slots_for(BoardModel.TEAM_A) == GameSetup.default_slots())

	_check("the editor has a detail panel", editor._detail != null)
	editor.show_unit(null)
	_check("with nothing picked it invites you to hover",
		editor._detail.text.to_lower().contains("hover"))

	var warden: UnitData = null
	for u in GameSetup.catalogue:
		if String(u.id) == "warden":
			warden = u
	_check("the catalogue still holds the Warden", warden != null)
	if warden != null:
		editor.show_unit(warden)
		_check("picking a unit titles the panel with it",
			editor._detail_title.text.contains("Warden"),
			editor._detail_title.text)
		var body: String = editor._detail.text
		_check("the panel says what its ability does",
			body.contains("Bulwark") and body.contains(warden.ability.describe()),
			body)
		_check("the panel carries its stats and its note",
			body.contains("hp") and body.contains(warden.note), body)
		_check("the panel wraps instead of running off the card",
			editor._detail.autowrap_mode != TextServer.AUTOWRAP_OFF)

	editor._on_slot_hovered(BoardModel.TEAM_A, 0)
	var hovered: UnitData = GameSetup.units_for(BoardModel.TEAM_A)[0]
	_check("hovering a slot on either side fills the panel",
		editor.focused() == hovered, editor._detail_title.text)
	_check("hovering a slot that is not there changes nothing",
		_stays_put(editor, hovered))

	var slots: Array[Label] = editor._rows[BoardModel.TEAM_B]
	_check("every slot carries its own card as a tooltip",
		not slots[0].tooltip_text.is_empty()
		and slots[0].tooltip_text.contains(
			GameSetup.units_for(BoardModel.TEAM_B)[0].display_name),
		slots[0].tooltip_text)
	_check("a slot label accepts the mouse so its tooltip can show",
		slots[0].mouse_filter == Control.MOUSE_FILTER_STOP)

	editor._on_cycle(BoardModel.TEAM_B, 0, 1)
	_check("cycling a slot refreshes its tooltip too",
		slots[0].tooltip_text.contains(
			GameSetup.units_for(BoardModel.TEAM_B)[0].display_name),
		slots[0].tooltip_text)

	# The panel grew a 33-map grid and pushed Done off the bottom of the screen,
	# which left no way out of the menu at all. Whatever else goes into it, the
	# way out has to stay on screen.
	var window := Rect2(Vector2.ZERO,
		Vector2(ProjectSettings.get_setting("display/window/size/viewport_width"),
			ProjectSettings.get_setting("display/window/size/viewport_height")))
	var exits: Array[Button] = []
	for b in _all_buttons(editor):
		if b.text == "Done" or b.text == "Reset both":
			exits.append(b)
	_check("the editor still has a way out of it", exits.size() == 2,
		"found %d of the two bottom buttons" % exits.size())
	var hidden: Array[String] = []
	for b in exits:
		if not window.encloses(Rect2(b.global_position, b.size)):
			hidden.append("%s at %s" % [b.text, b.global_position])
	_check("and you can see it without scrolling to it",
		hidden.is_empty(), ", ".join(hidden))

	_check("the editor offers a map picker", editor._map_label != null)
	_check("the picker is a grid, not a pair of arrows",
		editor._map_grid != null and editor._map_grid.columns > 1)
	if editor._map_label != null:
		var before_name: String = editor._map_label.text
		var before_shape := Vector2i(BoardModel.WIDTH, BoardModel.HEIGHT)
		_check("it names the map and its shape",
			before_name.contains("x"), before_name)
		_check("the note explains what the board is like",
			not editor._map_note.text.is_empty())

		_check("every map has a chip in the grid",
			editor._chips.size() == GameSetup.maps.size(),
			"%d chips for %d maps" % [
				editor._chips.size(), GameSetup.maps.size()])
		_check("each chip draws the map it stands for",
			editor._chips.is_empty() or (
				editor._chips[0].map == GameSetup.maps[0]
				and editor._chips[0]._preview.map == GameSetup.maps[0]))
		_check("the grid is ordered by the table, not the filenames",
			GameSetup.maps[0].id == &"standard",
			"first map is '%s'" % GameSetup.maps[0].id)

		var other: int = GameSetup.maps.size() - 1
		editor._on_pick_map(other)
		_check("picking a chip changes the map",
			editor._map_label.text != before_name, editor._map_label.text)
		_check("and the board actually changes shape with it",
			Vector2i(BoardModel.WIDTH, BoardModel.HEIGHT) != before_shape
			or GameSetup.maps.size() < 2,
			"still %dx%d" % [BoardModel.WIDTH, BoardModel.HEIGHT])
		_check("the picked map is the one the board is using",
			BoardModel.WIDTH == GameSetup.current_map().width
			and BoardModel.HEIGHT == GameSetup.current_map().height,
			"board %dx%d, map %s" % [
				BoardModel.WIDTH, BoardModel.HEIGHT,
				GameSetup.current_map().shape()])
		_check("exactly the chosen chip is lit",
			_lit_chips(editor) == [other], str(_lit_chips(editor)))

		# Every map has to survive being selected: use_map() silently falls back
		# to the default board on an invalid one, and that would go unnoticed.
		var seen := {}
		for i in GameSetup.maps.size():
			editor._on_pick_map(i)
			var m := GameSetup.current_map()
			seen[String(m.id)] = true
			if BoardModel.WIDTH != m.width or BoardModel.HEIGHT != m.height:
				_check("map '%s' loads onto the board" % m.id, false,
					"asked for %s, board is %dx%d" % [
						m.shape(), BoardModel.WIDTH, BoardModel.HEIGHT])
				break
		_check("every map in the grid can be picked and loads its own board",
			seen.size() == GameSetup.maps.size(),
			"%d of %d" % [seen.size(), GameSetup.maps.size()])
		editor._on_pick_map(0)

		var divided := 0
		for m in GameSetup.maps:
			if not m.has_neutral:
				divided += 1
		_check("at least one map has no separating line", divided > 0)

	await _check_previews(editor)

	editor._on_done()
	_check("done closes the editor", not editor.visible)
	_report()


func _check_previews(editor: LoadoutEditor) -> void:
	var preview: MapPreview = editor._map_preview
	_check("the map card shows a preview of the board", preview != null)
	if preview != null:
		await get_tree().process_frame
		_check("it is showing the map that is selected",
			preview.map == GameSetup.current_map())
		_check("it has room to draw",
			preview.size.x >= 40.0 and preview.size.y >= 40.0,
			"sized %s" % preview.size)
		_check("its cells are sized to fit the board it is drawing",
			preview.cell_size() > 0.0
			and preview.grid_rect().size.x <= preview.size.x + 0.5
			and preview.grid_rect().size.y <= preview.size.y + 0.5,
			"grid %s in %s" % [preview.grid_rect().size, preview.size])

		var biggest: MapData = null
		for m in GameSetup.maps:
			if biggest == null or m.tiles() > biggest.tiles():
				biggest = m
		preview.set_map(biggest)
		_check("even the largest board fits the preview box",
			preview.grid_rect().size.x <= preview.size.x + 0.5
			and preview.grid_rect().size.y <= preview.size.y + 0.5,
			"%s needs %s in %s" % [
				biggest.shape(), preview.grid_rect().size, preview.size])
		preview.set_map(GameSetup.current_map())

	var icons: Array[UnitIcon] = editor._icons[BoardModel.TEAM_B]
	_check("every slot has a unit icon", icons.size() == GameSetup.SLOTS)
	if not icons.is_empty():
		_check("and it is showing that slot's unit",
			icons[0].unit == GameSetup.units_for(BoardModel.TEAM_B)[0],
			"icon holds %s" % ("nothing" if icons[0].unit == null
				else icons[0].unit.display_name))
		editor._on_cycle(BoardModel.TEAM_B, 0, 1)
		_check("cycling the slot changes the icon too",
			icons[0].unit == GameSetup.units_for(BoardModel.TEAM_B)[0])
		_check("icons never eat the mouse",
			icons[0].mouse_filter == Control.MOUSE_FILTER_IGNORE)

	_check("the detail panel has an icon as well", editor._detail_icon != null)
	if editor._detail_icon != null:
		editor.show_unit(GameSetup.catalogue[0])
		_check("which follows whatever is being read",
			editor._detail_icon.unit == GameSetup.catalogue[0])

	await get_tree().process_frame
	var screen := Rect2(Vector2.ZERO, editor.get_viewport_rect().size)
	_check("the editor still fits the screen with previews in it",
		screen.encloses(Rect2(editor._map_preview.global_position,
			editor._map_preview.size)),
		"preview at %s sized %s, screen %s" % [
			editor._map_preview.global_position, editor._map_preview.size,
			screen.size])


func _stays_put(editor: LoadoutEditor, expected: UnitData) -> bool:
	editor._on_slot_hovered(BoardModel.TEAM_A, 99)
	return editor.focused() == expected


func _buttons(node: Node) -> Array[Button]:
	var out: Array[Button] = []
	for child in node.get_children():
		if child is Button and child.is_visible_in_tree():
			out.append(child as Button)
		out.append_array(_buttons(child))
	return out


func _report() -> void:
	if _failed > 0:
		print("\n%d FAILURES" % _failed)
	else:
		print("\nMenu smoke test passed. %d checks." % _passed)
	get_tree().quit(1 if _failed > 0 else 0)


func _lit_chips(editor: LoadoutEditor) -> Array[int]:
	var out: Array[int] = []
	for i in editor._chips.size():
		if editor._chips[i].button_pressed:
			out.append(i)
	return out


func _all_buttons(root: Node) -> Array[Button]:
	var out: Array[Button] = []
	var stack: Array[Node] = [root]
	while not stack.is_empty():
		var n: Node = stack.pop_back()
		if n is Button:
			out.append(n as Button)
		for child in n.get_children():
			stack.append(child)
	return out


func _check_backdrop() -> void:
	print("\nThe living backdrop")

	# The menu passed its whole suite before this existed, so none of these checks are
	# about the menu working — they are about the backdrop being REACHED. A Control that
	# is built and never processed looks identical from the outside to one that is not
	# built at all.
	var backdrop: MenuBackdrop = null
	for child in _menu.get_children():
		if child is MenuBackdrop:
			backdrop = child as MenuBackdrop
			break
	_check("the menu has a backdrop", backdrop != null)
	if backdrop == null:
		return
	_check("it is the FIRST child, so everything else draws over it",
		_menu.get_child(0) == backdrop,
		"child %d of %d" % [backdrop.get_index(), _menu.get_child_count()])
	# It covers the whole screen and must never take a click: it sits under every button
	# on the menu, and a Control that accepts input there would swallow presses.
	_check("it ignores the mouse", backdrop.mouse_filter == Control.MOUSE_FILTER_IGNORE)
	_check("and fills the screen", backdrop.size.x > 100.0 and backdrop.size.y > 100.0,
		"%s" % backdrop.size)

	var board: BoardModel = backdrop._board
	_check("it built a board", board != null)
	if board == null:
		return
	for team in [BoardModel.TEAM_A, BoardModel.TEAM_B]:
		_check("it fielded units for team %d" % team,
			board.living_count_of(team) > 1,
			"%d alive" % board.living_count_of(team))
	var walkers := 0
	for u in board.units_view():
		if u.data.can_move and u.data.can_attack:
			walkers += 1
	_check("every unit it picked can walk and swing, or nothing would happen",
		walkers == board.units_view().size(),
		"%d of %d" % [walkers, board.units_view().size()])

	# The claim that matters and the one a static check cannot make: the simulation is
	# actually advancing. Sampled across frames rather than by calling step() by hand,
	# because "somebody calls _process" is the thing being tested.
	# Two claims, and they need two different tests.
	#
	# First: the engine calls _process on this thing at all. That has to be measured
	# across real frames, because "somebody drives it" is the whole point — and it is
	# the failure a static check cannot see.
	var ticks_before: float = backdrop._elapsed
	for i in 40:
		await get_tree().process_frame
	_check("the battle advances on its own", backdrop._elapsed > ticks_before,
		"%.3fs against %.3fs" % [backdrop._elapsed, ticks_before])

	# Second: units cross tiles. This one must NOT be measured in frames. Headless frames
	# run as fast as the machine allows, so forty of them are a few milliseconds of battle
	# and nothing has time to walk anywhere — which is exactly what the first version of
	# this check reported, and it was the test being impatient rather than the backdrop
	# being broken. Driven with a fixed delta instead, which exercises the same
	# accumulator on a clock that does not depend on how fast the box is.
	var before_positions := {}
	for u in backdrop._board.units_view():
		before_positions[u.uid] = u.cell
	for i in 60:
		backdrop._process(0.1)
	var moved := 0
	for u in backdrop._board.units_view():
		if before_positions.has(u.uid) and before_positions[u.uid] != u.cell:
			moved += 1
	_check("and units cross tiles once it has run a few seconds", moved > 0,
		"%d of %d moved in %.1fs" % [moved, before_positions.size(),
			backdrop._elapsed])
	# Sliding between tiles is the only reason the movement does not look like a slideshow,
	# and it depends on capturing a duration the simulation never stores. If that capture
	# ever breaks, every unit snaps and nothing else complains.
	var slid := false
	for i in 40:
		backdrop._process(0.05)
		for u in backdrop._board.units_view():
			if u.state != UnitInstance.State.MOVING:
				continue
			var at := backdrop._slide_position(u)
			if at.distance_to(Vector2(u.cell)) > 0.05:
				slid = true
	_check("a walking unit is drawn between tiles, not snapped onto them", slid)

	# The bug this design exists to avoid. The board's SHAPE is static state on
	# BoardModel that every screen reads, so a backdrop that chose its own map would
	# silently overwrite the map the player picked — and the symptom would be a map
	# selection that does not stick, a long way from this file.
	var chosen := GameSetup.current_map()
	if chosen != null:
		_check("the backdrop plays on the player's chosen map, not one of its own",
			BoardModel.WIDTH == chosen.width and BoardModel.HEIGHT == chosen.height,
			"board is %dx%d, %s is %dx%d" % [BoardModel.WIDTH, BoardModel.HEIGHT,
				chosen.display_name, chosen.width, chosen.height])
	# And it stays true after the backdrop starts a fresh battle, which is the moment it
	# touches the map at all.
	backdrop._new_battle()
	if chosen != null:
		_check("and still after it restarts one",
			BoardModel.WIDTH == chosen.width and BoardModel.HEIGHT == chosen.height,
			"board is %dx%d" % [BoardModel.WIDTH, BoardModel.HEIGHT])

	# A finished battle has to be replaced, or the title screen ends on a still image of
	# two corpses. Forced rather than waited for: a real one takes most of a minute.
	backdrop._elapsed = MenuBackdrop.MAX_BATTLE + 1.0
	var stale := backdrop._board
	await get_tree().process_frame
	await get_tree().process_frame
	_check("a battle that runs long is replaced with a new one",
		backdrop._board != stale and backdrop._board != null)
	_check("and the new one has a full board again",
		backdrop._board.living_count_of(BoardModel.TEAM_A) > 1
		and backdrop._board.living_count_of(BoardModel.TEAM_B) > 1)
