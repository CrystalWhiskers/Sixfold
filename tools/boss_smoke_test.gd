extends Node

## The boss defence screen, start to finish, headless: prep, the fight played back
## live against a simulation running ahead of it, and the result banner. The rules
## themselves are tested in run_tests.gd; this is about the screen.
##
##   godot --headless res://tools/boss_smoke_test.tscn

var _passed := 0
var _failed := 0
var _tree: SceneTree = null


func _check(label: String, condition: bool, detail := "") -> void:
	if condition:
		_passed += 1
		print("  ok    %s" % label)
	else:
		_failed += 1
		print("  FAIL  %s %s" % [label, detail])


func _ready() -> void:
	_tree = get_tree()
	print("\n=== Boss defence screen ===\n")
	GameSetup.debug_seed = 4321
	var scn: Node = load("res://scenes/boss.tscn").instantiate()
	add_child(scn)
	await get_tree().process_frame
	var board: BoardModel = scn.board
	_check("the boss board is the open field, 17 x 26",
		BoardModel.WIDTH == 17 and BoardModel.HEIGHT == 26,
		"%dx%d" % [BoardModel.WIDTH, BoardModel.HEIGHT])
	_check("and the whole of it is on screen at once",
		scn._view.board_size().x <= scn.BOARD_AREA.size.x
		and scn._view.board_size().y <= scn.BOARD_AREA.size.y,
		"%s in %s" % [scn._view.board_size(), scn.BOARD_AREA.size])
	_check("the four crystals and the boss are on the board, and nobody else yet",
		scn.fight.crystals.size() == 4 and scn.fight.boss.cell == BossFight.BOSS_CELL
		and board.units_of(BoardModel.TEAM_B).size() == 4)
	_check("every crystal and the boss has a view",
		scn._view.view_for(scn.fight.boss.uid) != null
		and scn._view.view_for(scn.fight.crystals[3].uid) != null)
	_check("the HUD names the boss before the fight",
		scn._title.text.contains(scn.boss_data.display_name), scn._title.text)
	var b: Barracks = scn.barracks
	_check("the Barracks panel sits under the battlefield, with the opening draws in it",
		scn._panel != null and scn._panel.position.y >= scn.BOARD_AREA.end.y
		and b.unit_count(0) + b.unit_count(1) + b.unit_count(2) == scn.boss_data.start_draws)
	var supply_before := b.supply
	var price_before := b.recruit_price()
	scn._panel._on_recruit(1)
	_check("the Recruit button buys a unit into its section, and the next one costs more",
		b.unit_count(1) == 3 and is_equal_approx(b.supply, supply_before - price_before)
		and b.recruit_price() > price_before,
		"%d in Middle, Supply %.0f" % [b.unit_count(1), b.supply])
	# A drag in the panel, from one slot to an empty one, moves the unit.
	var from_rect: Rect2 = scn._panel.slot_rect(0, 0)
	var to_rect: Rect2 = scn._panel.slot_rect(0, b.slot_count() - 1)
	var moving: UnitData = b.at(0, 0)
	var press := InputEventMouseButton.new()
	press.button_index = MOUSE_BUTTON_LEFT
	press.pressed = true
	press.position = from_rect.get_center()
	scn._panel._gui_input(press)
	var release := InputEventMouseButton.new()
	release.button_index = MOUSE_BUTTON_LEFT
	release.pressed = false
	release.position = to_rect.get_center()
	scn._panel._gui_input(release)
	_check("the upgrade bar has a button for each of the five unit types",
		scn._panel._type_btns.size() == b.types.size() and b.types.size() == 5)
	b.supply += 1000.0
	scn._panel._on_upgrade(0)
	_check("and pressing one levels that unit type up",
		b.level_of(b.types[0].id) == 1 and scn._panel._type_btns[0].text.contains("Lv1"),
		scn._panel._type_btns[0].text)
	b.supply -= 1000.0 - b.upgrade_price(b.types[0].id) + b.upgrade_price(b.types[0].id)
	_check("dragging in the Barracks moves a unit to another slot",
		b.at(0, 0) == null and b.at(0, b.slot_count() - 1) == moving)

	var music_here := ResourceLoader.exists("res://audio/boss/gebura_battle.mp3")
	if music_here:
		_check("opening the mode starts Theme 1 at once, before Fight",
			Audio.now_playing() == "boss_phase_0" and scn._track == "Theme 1",
			"playing %s" % Audio.now_playing())
		Audio._music.seek(30.0)
	scn._on_fight()
	if music_here:
		_check("and Fight carries it on without starting it again",
			Audio.now_playing() == "boss_phase_0"
			and Audio._music.get_playback_position() >= 29.0,
			"at %.1fs" % Audio._music.get_playback_position())
	_check("Fight starts the live fight", scn.phase == "fight" and scn._player.live)
	_check("and the first wave is on the field at once, near its crystals",
		board.units_of(BoardModel.TEAM_B).size() == 4 + b.unit_count(0) + b.unit_count(1)
			+ b.unit_count(2),
		"%d on the field" % board.units_of(BoardModel.TEAM_B).size())
	var supply_at_fight := b.supply
	var hp_start: float = scn._hp_bar.value
	var saw_wave := false
	var saw_mark := false
	var frames := 0
	scn._player.speed = 4.0
	while scn.phase != "over" and frames < 20000:
		scn._process(0.05)
		scn._player._process(0.05)
		frames += 1
		if scn._waves > 0:
			saw_wave = true
		if not scn._next_move.is_empty():
			saw_mark = true
		if frames == 400:
			_check("the simulation stays only a moment ahead of the screen",
				scn.sim.elapsed <= scn._player.clock() + scn.LEAD + 0.25 and not scn.sim.is_finished(),
				"sim %.1f, screen %.1f" % [scn.sim.elapsed, scn._player.clock()])
	_check("the fight finishes on screen", scn.phase == "over", "%d frames" % frames)
	_check("Supply kept coming in during the fight", b.supply > supply_at_fight + 50.0,
		"%.0f -> %.0f" % [supply_at_fight, b.supply])
	_check("the boss bar moved", scn._hp_bar.value < hp_start or scn.result == BoardModel.TEAM_B,
		"%.0f -> %.0f" % [hp_start, scn._hp_bar.value])
	_check("a reinforcement wave reached the HUD", saw_wave)
	_check("a move was named as it was marked", saw_mark)
	_check("and the banner says how it ended", scn._banner.visible
		and (scn._banner.text == "VICTORY" or scn._banner.text == "DEFEAT"), scn._banner.text)
	var down := 0
	for i in 3:
		if not scn.fight.crystals[i].is_alive():
			down += 1
	print("\n  (fight lasted %.0fs, %s, %d lane crystals down, %d waves)" % [
		scn.sim.duration(), scn._banner.text, down, scn._waves])
	# The phase music loops its own stretch. Only checkable here, where the Audio
	# autoload is live (the main suite runs before autoloads are ready).
	if ResourceLoader.exists("res://audio/boss/gebura_battle.mp3"):
		Audio.play_segment("smoke_phase_4", "res://audio/boss/gebura_battle.mp3", 183.2727, 0.0)
		_check("a stretch to the end of the file loops in the stream itself, on the exact sample",
			Audio._music.stream.get("loop") == true
			and is_equal_approx(float(Audio._music.stream.get("loop_offset")), 183.2727))
		Audio._restart_music()
		_check("a stretch that ran out starts again from its own start",
			absf(Audio._music.get_playback_position() - 183.2727) < 1.0,
			"at %.1fs" % Audio._music.get_playback_position())
		Audio.play_segment("smoke_phase_2", "res://audio/boss/gebura_battle.mp3", 91.6364, 183.2727)
		var mid: AudioStream = Audio._music.stream
		var mid_len := mid.get_length() if mid != null else 0.0
		var mid_loop := (mid_len - float(mid.get("loop_offset"))) if mid != null else 0.0
		_check("and a phase change switches to the next stretch",
			Audio.now_playing() == "smoke_phase_2"
			and absf(Audio._music.get_playback_position() - 91.6364) < 1.0)
		_check("a stretch that ends mid-file is cut there and looped by the engine, not by a per-frame check",
			mid is AudioStreamMP3 and mid.get("loop") == true and Audio._segment_to <= 0.0
			and mid_len >= 183.2727 and mid_len < 183.2727 + 0.03,
			"ends %.4fs" % mid_len)
		_check("and its loop is exactly the stretch's length (168 beats), so it keeps the beat",
			absf(mid_loop - (183.2727 - 91.6364)) < 0.0005, "%.4fs" % mid_loop)
		Audio.stop_music()
	# Boss music is for this mode only. Leaving puts the menu back on its own music,
	# and the ordinary battle and boss rotations never include the boss stretches.
	if music_here:
		Audio.play_segment("boss_phase_0", "res://audio/boss/gebura_battle.mp3", 0.0, 91.6364)
	var menu: Node = load("res://scenes/menu.tscn").instantiate()
	add_child(menu)
	_check("back at the menu, the menu music is playing, not the boss's",
		Audio.now_playing() == "menu_theme" and Audio._segment_from < 0.0,
		"playing %s" % Audio.now_playing())
	menu.queue_free()
	var leaked := false
	for i in range(1, Audio.battle_track_count + 1):
		leaked = leaked or Audio.battle_track(i).begins_with("boss_phase")
	for i in range(1, Audio.boss_track_count + 1):
		leaked = leaked or Audio.boss_track(i).begins_with("boss_phase")
	for f in DirAccess.get_files_at(Audio.MUSIC_DIR):
		leaked = leaked or f.contains("gebura") or f.contains("red_mist")
	_check("and the boss stretches are in neither the battle nor the boss rotation",
		not leaked)
	# Not scn._on_menu(): that changes the scene, and this test IS the scene.
	BoardModel.reset_map()
	BoardModel.reset_map()
	print("\n%d passed, %d failed" % [_passed, _failed])
	print("Boss smoke test passed." if _failed == 0 else "%d FAILURES" % _failed)
	_tree.quit(1 if _failed > 0 else 0)
