extends Node2D

## Boss defence: build the army in the Barracks, then hold off the boss.
##
## The battlefield takes the top of the screen and the Barracks panel sits under
## it. Before Fight you spend the starting Supply and arrange the opening draws;
## after Fight the Barracks stays live — Supply keeps ticking, and every recruit,
## merge and drill shows up in the next wave. The fight is one continuous battle
## simulated as it plays, LEAD seconds ahead of the screen, so a five-minute fight
## starts on the first frame. See BossFight for the rules and Barracks for the
## economy.

const MENU_SCENE := "res://scenes/menu.tscn"
const BOSS_PATH := "res://data/boss/arbiter.tres"
const BOARD_AREA := Rect2(10.0, 112.0, 700.0, 728.0)
const BARRACKS_AREA := Rect2(8.0, 844.0, 704.0, 286.0)
## How far ahead of the screen the simulation runs.
const LEAD := 2.0
const SPEEDS: Array[float] = [1.0, 2.0, 4.0]
## Ground tints for the zones: Left, Middle, Right, Central.
const ZONE_GROUND: Array[Color] = [
	Color(0.35, 0.55, 0.95, 0.10), Color(0.40, 0.85, 0.45, 0.09),
	Color(0.75, 0.45, 0.95, 0.10), Color(0.95, 0.80, 0.35, 0.12),
]

var board: BoardModel = null
var boss_data: BossData = null
var fight: BossFight = null
var barracks: Barracks = null
var sim: CombatSim = null
var phase := "prep"
var units := {}
var result := CombatSim.RESULT_DRAW

var _view: BoardView = null
var _player: BattlePlayer = null
var _panel: BarracksPanel = null
var _rng := RandomNumberGenerator.new()
var _speed_idx := 1
var _known_units := 0

var _title: Label = null
var _hp_bar: ProgressBar = null
var _crystal_line: Label = null
var _clock_line: Label = null
var _status: Label = null
var _banner: Label = null
var _fight_btn: Button = null
var _speed_btn: Button = null
var _again_btn: Button = null

var _boss_uid := -1
var _boss_max := 1.0
var _phase_name := ""
var _next_move := ""
var _crystal_uids: Array[int] = []
var _crystal_hp: Dictionary = {}
var _crystal_max: Dictionary = {}
var _crystal_down: Dictionary = {}
var _sealed := true
var _next_wave_at := 0.0
var _waves := 0
## The phase track playing, as the HUD names it, or "" when the boss music is absent.
var _track := ""
## Which phase bar is on screen, and the stance meter while she is charging.
var _bar_index := 0
var _stance_need := 0.0
var _stance_taken := 0.0
## crystal uid -> playback time it will stand again.
var _rebuild_at: Dictionary = {}
## The running tally: the counter on the HUD and, at the end, the results screen.
var stats := BossStats.new()
var _counter: Label = null
## The fight clock and the enrage, right of the crystal line; and how many surges
## the screen has shown so far.
var _enrage_line: Label = null
var _enrage_shown := 0
var _collapse_btn: Button = null
var _boss_stats: Label = null
var barracks_hidden := false
var _results: Control = null


func _ready() -> void:
	boss_data = load(BOSS_PATH) as BossData
	# The boss's own music from the moment the mode opens: phase one's track on the
	# setup screen, carrying straight on into the fight. Only when that file is not
	# on this machine — always the case in the web build — does an ordinary track
	# stand in for it.
	if not _play_phase_music(0):
		var track := GameSetup.roll_boss_track()
		Audio.play_music(track if not track.is_empty() else GameSetup.roll_battle_track())
	BoardModel.use_map(BossFight.make_map())
	board = BoardModel.new()
	_rng.seed = (GameSetup.debug_seed if GameSetup.debug_seed != 0
		else int(Time.get_unix_time_from_system()))

	fight = BossFight.new()
	fight.limit_army = GameSetup.boss_army_limit
	fight.place_structures(board, boss_data)
	barracks = Barracks.new()
	barracks.setup(boss_data, GameSetup.loadout_for(BoardModel.TEAM_B), _rng.seed)
	barracks.ability_cap = 10 if GameSetup.boss_ability_lv10 else BossUpgrades.MAX_LEVEL

	_view = BoardView.new()
	_view.player_team = BoardModel.TEAM_B
	_view.min_tile = 20.0
	_view.zone_of = BossFight.zone_of_cell
	_view.zone_colors = ZONE_GROUND
	add_child(_view)
	_view.fit_to(BOARD_AREA)
	_view.bind(board)
	# Nothing to drag on the field — the army is built in the Barracks — but the
	# board still pans and zooms.
	_view.drag_dropped.connect(func(_a, _b): _view.sync_positions())

	_player = BattlePlayer.new()
	add_child(_player)
	_player.event_played.connect(_on_event)
	_player.finished.connect(_on_finished)
	_build_ui()
	_refresh_prep_hud()


# --- UI -----------------------------------------------------------------------

func _label(at: Vector2, size: int, color: Color) -> Label:
	var l := Label.new()
	l.position = at
	l.size = Vector2(672.0, 0.0)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	return l



func _button(text: String, handler: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(150, 54)
	b.pressed.connect(Audio.play_confirm)
	b.pressed.connect(handler)
	return b



func _crystal_text() -> String:
	var parts: PackedStringArray = []
	for i in _crystal_uids.size():
		var uid := _crystal_uids[i]
		var name: String = BossFight.ZONE_NAMES[i]
		if _crystal_down.has(uid):
			var back: float = float(_rebuild_at.get(uid, -1.0))
			if back >= 0.0 and _player != null:
				parts.append("%s rebuilding %ds" % [name, ceili(maxf(back - _player.clock(), 0.0))])
			else:
				parts.append("%s BROKEN" % name)
		elif i == 3 and _sealed:
			parts.append("Central sealed")
		else:
			parts.append("%s %.0f" % [name, float(_crystal_hp.get(uid, 0.0))])
	return "Crystals: " + "  ·  ".join(parts)



func _build_ui() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)
	var root := Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(root)
	_title = _label(Vector2(24, 8), 20, Color(1.0, 0.80, 0.74))
	root.add_child(_title)
	_hp_bar = ProgressBar.new()
	_hp_bar.position = Vector2(24, 40)
	_hp_bar.size = Vector2(672, 20)
	_hp_bar.show_percentage = false
	var fill := StyleBoxFlat.new()
	fill.bg_color = Color(0.82, 0.16, 0.15)
	_hp_bar.add_theme_stylebox_override("fill", fill)
	root.add_child(_hp_bar)
	_crystal_line = _label(Vector2(24, 64), 14, Color(0.70, 0.88, 0.96))
	root.add_child(_crystal_line)
	_clock_line = _label(Vector2(24, 86), 14, Color(0.95, 0.88, 0.60))
	root.add_child(_clock_line)
	# The two numbers you watch: what the army has dealt, and what it has lost.
	# Right-aligned on the title row, where the boss's name leaves room.
	_counter = _label(Vector2(24, 12), 15, Color(0.98, 0.92, 0.80))
	_counter.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_counter.add_theme_constant_override("outline_size", 4)
	_counter.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.85))
	root.add_child(_counter)
	_enrage_line = _label(Vector2(24, 64), 14, Color(1.0, 0.62, 0.50))
	_enrage_line.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	root.add_child(_enrage_line)

	_panel = BarracksPanel.new()
	_panel.position = BARRACKS_AREA.position
	_panel.size = BARRACKS_AREA.size
	root.add_child(_panel)
	_panel.setup(barracks)
	_panel.changed.connect(func(msg: String): _status.text = msg)
	# Collapse the Barracks away to see the whole field larger, and back.
	_collapse_btn = Button.new()
	_collapse_btn.text = "▾ Hide Barracks"
	_collapse_btn.position = Vector2(560, 818)
	_collapse_btn.size = Vector2(150, 24)
	_collapse_btn.add_theme_font_size_override("font_size", 12)
	_collapse_btn.pressed.connect(toggle_barracks)
	root.add_child(_collapse_btn)
	# Her strength, always on show under the field.
	_boss_stats = _label(Vector2(24, 1158), 13, Color(1.0, 0.70, 0.62))
	_boss_stats.add_theme_constant_override("outline_size", 3)
	_boss_stats.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.85))
	root.add_child(_boss_stats)

	_status = _label(Vector2(24, 1134), 14, Color(0.65, 0.71, 0.79))
	root.add_child(_status)
	var buttons := HBoxContainer.new()
	buttons.position = Vector2(24, 1182)
	buttons.add_theme_constant_override("separation", 12)
	root.add_child(buttons)
	_fight_btn = _button("Fight", _on_fight)
	buttons.add_child(_fight_btn)
	_speed_btn = _button("Speed x2", _cycle_speed)
	buttons.add_child(_speed_btn)
	_again_btn = _button("Again", _on_again)
	_again_btn.visible = false
	buttons.add_child(_again_btn)
	buttons.add_child(_button("Menu", _on_menu))

	_banner = _label(Vector2(24, 440), 54, Color(1.0, 0.9, 0.8))
	_banner.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_banner.add_theme_constant_override("outline_size", 10)
	_banner.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	_banner.visible = false
	root.add_child(_banner)


func _refresh_prep_hud() -> void:
	_title.text = "%s — %s" % [boss_data.display_name, boss_data.title]
	_hp_bar.max_value = boss_data.max_hp
	_hp_bar.value = boss_data.max_hp
	_crystal_line.text = "Crystals: Left · Middle · Right %.0f each, Central %.0f (sealed until the three fall)" % [
		boss_data.lane_crystal_hp, boss_data.central_crystal_hp]
	_clock_line.text = "Every %.0fs each Barracks section sends a fresh copy of itself to its crystal." % boss_data.wave_seconds
	_status.text = "Build your army in the Barracks — recruit, drag onto twins to merge, drill. Then Fight."
	_enrage_line.text = ("No time limit  ·  she enrages from %s" % _mmss(boss_data.enrage_after)
		if boss_data.enrage_every > 0.0 else "No time limit")


# --- The fight ----------------------------------------------------------------

func _on_fight() -> void:
	if phase != "prep":
		return
	phase = "fight"
	_fight_btn.disabled = true
	_view.interactive = false
	sim = CombatSim.new()
	fight.attach(sim, barracks)
	sim.setup(board, _rng.seed)
	fight.start()
	units = sim.unit_map()
	for u in sim._pending_units:
		units[u.uid] = u
	_known_units = units.size()
	_view.rebuild()
	_player.speed = SPEEDS[_speed_idx]
	_player.live = true
	_player.play(_view, sim.events, units)
	_status.text = "Hold the field. The Barracks stays open: Supply keeps coming in."
	_counter.text = counter_text()


func _process(delta: float) -> void:
	if _boss_stats != null and fight != null and fight.boss != null:
		_boss_stats.text = boss_stats_text()
	if phase != "fight" or sim == null:
		return
	if not sim.is_finished():
		# Supply runs on the clock the player is watching, not the simulation's.
		barracks.tick(delta * _player.speed)
		sim.step_until(_player.clock() + LEAD)
		if sim._units.size() + sim._pending_units.size() != _known_units:
			for u in sim._units:
				units[u.uid] = u
			for u in sim._pending_units:
				units[u.uid] = u
			_known_units = sim._units.size() + sim._pending_units.size()
		if sim.is_finished():
			_player.live = false
	_panel.refresh()
	if not _rebuild_at.is_empty():
		_crystal_line.text = _crystal_text()
	_enrage_line.text = enrage_text(_player.clock())
	var left := maxf(_next_wave_at - _player.clock(), 0.0)
	_clock_line.text = "Next wave in %.0fs  ·  wave %d  ·  %s%s%s" % [
		left, _waves, _phase_name,
		("  ·  next: %s" % _next_move) if not _next_move.is_empty() else "",
		("  ·  ♪ %s" % _track) if not _track.is_empty() else ""]
	if _stance_need > 0.0:
		# The stance meter: how close the army is to breaking her charge.
		_clock_line.text = "STANCE — break it: %d / %d damage" % [
			roundi(minf(_stance_taken, _stance_need)), roundi(_stance_need)]


static func _mmss(s: float) -> String:
	return "%d:%02d" % [int(s) / 60, int(s) % 60]


func enrage_text(now: float) -> String:
	## "3:12 · enrage in 0:48", then "4:40 · ENRAGED ×1 · surge in 0:20".
	if boss_data.enrage_every <= 0.0:
		return _mmss(now)
	var next := boss_data.enrage_after + boss_data.enrage_every * float(_enrage_shown)
	if _enrage_shown == 0:
		return "%s  ·  enrage in %s" % [_mmss(now), _mmss(maxf(next - now, 0.0))]
	return "%s  ·  ENRAGED ×%d  ·  surge in %s" % [_mmss(now), _enrage_shown,
		_mmss(maxf(next - now, 0.0))]


func counter_text() -> String:
	return "Dealt %s   ·   Lost %d" % [BossStats.short(stats.dealt), stats.lost]


func _on_event(e: Dictionary) -> void:
	stats.record(e, units)
	if _counter != null and (e.kind == "damage" or e.kind == "death"):
		_counter.text = counter_text()
	match e.kind:
		"boss_start":
			_boss_uid = int(e.uid)
			_boss_max = float(e.max_hp)
			_bar_index = int(e.phase)
			_show_bar(_boss_max)
			_phase_name = String(e.phase_name)
			_play_phase_music(int(e.phase))
			_crystal_uids.clear()
			for uid in e.crystals:
				_crystal_uids.append(int(uid))
				var c: UnitInstance = units.get(int(uid), null)
				var hp := c.stat(StatModifier.Stat.MAX_HP) if c != null else 0.0
				_crystal_hp[int(uid)] = hp
				_crystal_max[int(uid)] = hp
			_next_wave_at = float(e.t) + float(e.wave_seconds)
			_crystal_line.text = _crystal_text()
		"damage", "heal":
			var uid := int(e.uid)
			if uid == _boss_uid:
				_show_bar(float(e.hp))
			elif _crystal_hp.has(uid):
				_crystal_hp[uid] = float(e.hp)
				_crystal_line.text = _crystal_text()
		"boss_phase":
			_phase_name = String(e.name)
			_bar_index = int(e.index)
			_show_bar(float(e.get("hp", _boss_max)))
			_play_phase_music(int(e.index))
			_status.text = "%s takes up %s." % [boss_data.display_name, _phase_name]
			_phase_cutscene(int(e.index), _phase_name)
		"boss_stance":
			_stance_need = float(e.threshold)
			_stance_taken = 0.0
			_status.text = "%s is gathering power — deal %d damage to break %s!" % [
				boss_data.display_name, roundi(_stance_need), String(e.name)]
		"boss_stance_meter":
			_stance_taken = float(e.taken)
		"boss_stance_broken":
			_stance_need = 0.0
			_status.text = "Broken! %s is staggered and takes extra damage." % boss_data.display_name
		"boss_empowered":
			_stance_need = 0.0
			_status.text = "%s is empowered — and lets loose!" % boss_data.display_name
		"boss_summon":
			_status.text = ("%s calls a swarm of thralls!" if bool(e.get("swarm", false)) else "%s calls her shades — stay out of the circles!") % boss_data.display_name
		"boss_retreat":
			_status.text = "%s retreats to heal and calls everything she has — she takes %d%% more damage now. Hit her!" % [
				boss_data.display_name, roundi(float(e.vulnerability) * 100.0)]
		"boss_retreat_end":
			if bool(e.completed):
				_status.text = "%s returns stronger: +%d%% attack, +%d%% speed." % [
					boss_data.display_name, roundi(float(e.attack) * 100.0),
					roundi(float(e.speed) * 100.0)]
			else:
				_status.text = "Her retreat is cut short — she gains nothing from it."
		"boss_enrage":
			_enrage_shown = int(e.stacks)
			_status.text = "%s surges! Enraged ×%d: +%d%% attack, +%d%% speed, summons +%d%%. Finish her!" % [
				boss_data.display_name, int(e.stacks), roundi(float(e.attack) * 100.0),
				roundi(float(e.speed) * 100.0), roundi(float(e.minions) * 100.0)]
		"boss_ward":
			if int(e.shades) > 0:
				_status.text = "%d shade%s shield %s: she takes %d%% less damage. Kill them!" % [
					int(e.shades), "" if int(e.shades) == 1 else "s", boss_data.display_name,
					roundi(float(e.cut) * 100.0)]
		"boss_windup":
			_status.text = "%s is charging %s!" % [boss_data.display_name, String(e.name)]
			_next_move = String(e.name)
		"crystal_rebuilding":
			_rebuild_at[int(e.uid)] = float(e.t) + float(e.seconds)
			_status.text = "The %s Crystal is down — its section reinforces the centre while it rebuilds." % BossFight.ZONE_NAMES[int(e.lane)]
		"crystal_restored":
			_crystal_down.erase(int(e.uid))
			_rebuild_at.erase(int(e.uid))
			_crystal_hp[int(e.uid)] = float(e.hp)
			_crystal_line.text = _crystal_text()
			_status.text = "The %s Crystal stands again." % BossFight.ZONE_NAMES[int(e.lane)]
		"boss_telegraph":
			_next_move = String(e.name)
			if int(e.get("executes", 0)) > 0:
				_status.text = "%s will EXECUTE every tier %d it hits — get them out of the dark red!" % [
					String(e.name), int(e.executes)]
		"boss_blaze":
			_status.text = "%s sets the ground burning — move out of the orange!" % String(e.name)
		"boss_suppress":
			_status.text = "%s seals the mana of %d of your units for %ds." % [String(e.name),
				(e.uids as Array).size(), roundi(float(e.seconds))]
		"boss_execute":
			_status.text = "%s executed %d of your tier %d units." % [String(e.name),
				(e.cells as Array).size(), int(e.tier)]
		"boss_strike":
			_next_move = ""
		"wave":
			_waves = int(e.index)
			_next_wave_at = float(e.t) + float(e.next_in)
			_status.text = "Wave %d: %d arrived%s." % [_waves, int(e.placed),
				(", %d waiting for room" % int(e.queued)) if int(e.queued) > 0 else ""]
		"death":
			if _crystal_hp.has(int(e.uid)):
				_crystal_down[int(e.uid)] = true
				_crystal_line.text = _crystal_text()
				_status.text = "A crystal has broken."
		"crystals_merge":
			_sealed = false
			_crystal_line.text = _crystal_text()
			_status.text = "The lane crystals are gone. The armies merge on the Central Crystal."
		"end":
			result = int(e.winner)


func _on_finished(_winner: int) -> void:
	phase = "over"
	var won := result == BoardModel.TEAM_B
	_banner.text = "VICTORY" if won else "DEFEAT"
	_banner.add_theme_color_override("font_color",
		Color(0.70, 0.95, 0.70) if won else Color(1.0, 0.45, 0.40))
	_banner.visible = true
	var clock := "%d:%02d" % [int(sim.duration()) / 60, int(sim.duration()) % 60]
	if won:
		_status.text = "%s falls after %s." % [boss_data.display_name, clock]
	elif not fight.crystals[3].is_alive():
		_status.text = "The Central Crystal falls after %s." % clock
	else:
		_status.text = "Time is up after %s — %s holds the field." % [
			clock, boss_data.display_name]
	_again_btn.visible = true
	_show_results(won, clock)


func result_rows(won: bool, clock: String) -> Array:
	## The results screen, as [label, value] rows — kept apart from the drawing so a
	## test can read exactly what the player is shown.
	var full := maxf(fight.boss.stat(StatModifier.Stat.MAX_HP), 1.0)
	var left := maxf(fight.boss.current_hp, 0.0) if fight.boss.is_alive() else 0.0
	var levels := 0
	for t in barracks.types:
		levels += barracks.level_of(t.id)
	var rows := [
		["Result", ("Victory in %s" % clock) if won else ("Defeat after %s" % clock)],
		["Boss health left", "%d%%" % roundi(left / full * 100.0)],
		["Phase reached", "%d of %d — %s" % [stats.phase_reached + 1, boss_data.phases.size(),
			boss_data.phases[mini(stats.phase_reached, boss_data.phases.size() - 1)].display_name]],
		["Damage dealt", "%s" % BossStats.short(stats.dealt)],
		["   to the boss", "%s" % BossStats.short(stats.to_boss)],
		["   to her summons", "%s" % BossStats.short(stats.to_summons)],
		["Damage taken", "%s" % BossStats.short(stats.taken)],
		["Units sent", "%d" % stats.deployed],
		["Units lost", "%d" % stats.lost],
		["Summons killed", "%d" % stats.summons_killed],
		["Crystals broken", "%d" % stats.crystals_broken],
		["Retreats she finished", "%d" % stats.retreats],
		["Enrage surges", "%d" % _enrage_shown],
		["Waves", "%d" % _waves],
		["Supply spent", "%d" % roundi(barracks.spent)],
		["Recruits / upgrade levels", "%d / %d" % [barracks.recruits, levels]],
	]
	var top := stats.top_dealers(3)
	for i in top.size():
		rows.append(["Top damage #%d" % (i + 1), "%s — %s" % [top[i][0],
			BossStats.short(float(top[i][1]))]])
	return rows


func _show_results(won: bool, clock: String) -> void:
	## A panel over the field with the whole fight in numbers, and the way out.
	if _results != null:
		_results.queue_free()
	var layer := CanvasLayer.new()
	layer.layer = 5
	add_child(layer)
	var shade := ColorRect.new()
	shade.color = Color(0.02, 0.02, 0.04, 0.78)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shade.mouse_filter = Control.MOUSE_FILTER_STOP
	layer.add_child(shade)
	_results = shade

	var panel := PanelContainer.new()
	var box := StyleBoxFlat.new()
	box.bg_color = Color(0.10, 0.07, 0.07, 0.97)
	box.border_color = Color(0.85, 0.30, 0.25) if not won else Color(0.55, 0.85, 0.55)
	box.set_border_width_all(3)
	box.set_corner_radius_all(12)
	box.set_content_margin_all(22)
	panel.add_theme_stylebox_override("panel", box)
	panel.position = Vector2(70, 150)
	panel.custom_minimum_size = Vector2(580, 0)
	shade.add_child(panel)

	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 6)
	panel.add_child(column)
	var title := Label.new()
	title.text = "VICTORY" if won else "DEFEAT"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 40)
	title.add_theme_color_override("font_color",
		Color(0.70, 0.95, 0.70) if won else Color(1.0, 0.45, 0.40))
	column.add_child(title)
	var sub := Label.new()
	sub.text = "%s — %s" % [boss_data.display_name, boss_data.title]
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sub.add_theme_font_size_override("font_size", 15)
	sub.add_theme_color_override("font_color", Color(0.80, 0.72, 0.66))
	column.add_child(sub)
	column.add_child(HSeparator.new())

	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 24)
	grid.add_theme_constant_override("v_separation", 5)
	column.add_child(grid)
	for row in result_rows(won, clock):
		var k := Label.new()
		k.text = String(row[0])
		k.add_theme_font_size_override("font_size", 16)
		k.add_theme_color_override("font_color", Color(0.72, 0.76, 0.84))
		k.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		grid.add_child(k)
		var v := Label.new()
		v.text = String(row[1])
		v.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		v.add_theme_font_size_override("font_size", 16)
		v.add_theme_color_override("font_color", Color(0.98, 0.94, 0.86))
		grid.add_child(v)

	column.add_child(HSeparator.new())
	var buttons := HBoxContainer.new()
	buttons.alignment = BoxContainer.ALIGNMENT_CENTER
	buttons.add_theme_constant_override("separation", 14)
	column.add_child(buttons)
	buttons.add_child(_button("Again", _on_again))
	buttons.add_child(_button("Menu", _on_menu))
	var look := _button("See the field", func(): _results.visible = false)
	look.custom_minimum_size = Vector2(170, 54)
	buttons.add_child(look)


func _cycle_speed() -> void:
	_speed_idx = (_speed_idx + 1) % SPEEDS.size()
	_player.speed = SPEEDS[_speed_idx]
	_speed_btn.text = "Speed x%d" % int(SPEEDS[_speed_idx])


func _on_again() -> void:
	get_tree().reload_current_scene()


func _on_menu() -> void:
	BoardModel.reset_map()
	get_tree().change_scene_to_file(MENU_SCENE)


func _play_phase_music(index: int) -> bool:
	## The phase's own stretch of music, looped until the next phase. When the file
	## is not there (the web build never has it) whatever is playing carries on.
	## Asking for the stretch that is already playing changes nothing, so the
	## Theme 1 that starts on the setup screen runs on into the fight unbroken.
	if boss_data == null or index < 0 or index >= boss_data.phases.size():
		return false
	var p := boss_data.phases[index]
	if Audio.play_segment("boss_phase_%d" % index, p.music_path, p.music_from, p.music_to):
		_track = p.music_label
		return true
	return false


func _show_bar(hp: float) -> void:
	## Each phase is its own bar: the HUD shows only the current one, full to empty,
	## and says which of the four it is.
	var phases := boss_data.phases
	var top := phases[_bar_index].hp_threshold * _boss_max
	var bottom := (phases[_bar_index + 1].hp_threshold * _boss_max
		if _bar_index + 1 < phases.size() else 0.0)
	_hp_bar.max_value = maxf(top - bottom, 1.0)
	_hp_bar.value = clampf(hp - bottom, 0.0, top - bottom)
	_title.text = "%s — bar %d of %d: %s" % [boss_data.display_name, _bar_index + 1,
		phases.size(), phases[_bar_index].display_name]

## The phase-change cutscene: the field darkens, the camera turns to her, and the new
## phase is announced across the screen while she is sealed and gathering herself —
## then she opens with the phase's signature move.
var _cutscene: Control = null
var phase_banner_text := ""


func _phase_cutscene(index: int, name: String) -> void:
	phase_banner_text = "PHASE %d\n%s" % [index + 1, name.to_upper()]
	if _cutscene != null and is_instance_valid(_cutscene):
		_cutscene.queue_free()
	var layer := CanvasLayer.new()
	layer.layer = 4
	add_child(layer)
	var root := Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(root)
	_cutscene = root
	var dim := ColorRect.new()
	dim.color = Color(0.10, 0.0, 0.02, 0.0)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(dim)
	var banner := Label.new()
	banner.text = phase_banner_text
	banner.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	banner.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	banner.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	banner.offset_top = -120.0
	banner.add_theme_font_size_override("font_size", 64)
	banner.add_theme_color_override("font_color", Color(1.0, 0.82, 0.70))
	banner.add_theme_constant_override("outline_size", 14)
	banner.add_theme_color_override("font_outline_color", Color(0.25, 0.0, 0.02))
	banner.modulate.a = 0.0
	banner.scale = Vector2(1.3, 1.3)
	banner.pivot_offset = Vector2(360, 640)
	root.add_child(banner)
	# Turn the camera to her, so the transformation is seen.
	if fight != null and fight.boss != null:
		_view.centre_on(fight.boss.cell)
	var t := create_tween().set_parallel(true)
	t.tween_property(dim, "color:a", 0.55, 0.35)
	t.tween_property(banner, "modulate:a", 1.0, 0.35)
	t.tween_property(banner, "scale", Vector2.ONE, 0.45).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	t.chain().tween_interval(1.6)
	t.chain().set_parallel(true)
	t.tween_property(dim, "color:a", 0.0, 0.6)
	t.tween_property(banner, "modulate:a", 0.0, 0.6)
	t.chain().tween_callback(layer.queue_free)
	Audio.play_boss_slam()


func toggle_barracks() -> void:
	## Folds the Barracks away and lets the field take its space, or brings it back.
	barracks_hidden = not barracks_hidden
	_panel.visible = not barracks_hidden
	_collapse_btn.text = "▴ Show Barracks" if barracks_hidden else "▾ Hide Barracks"
	_collapse_btn.position.y = (BARRACKS_AREA.end.y - 26.0) if barracks_hidden else 818.0
	var area := BOARD_AREA
	if barracks_hidden:
		area.size.y = BARRACKS_AREA.end.y - BOARD_AREA.position.y - 30.0
	_view.fit_to(area)
	Audio.play_confirm()


func boss_stats_text() -> String:
	## Everything she has gained, at a glance: attack against her base, attack speed,
	## mending, lifesteal, her single-hit cap and ranged resistance.
	var b := fight.boss
	var atk := b.stat(StatModifier.Stat.ATTACK_DAMAGE)
	var base := maxf(boss_data.attack_damage, 1.0)
	var spd := b.stat(StatModifier.Stat.ATTACK_SPEED) / maxf(boss_data.attack_speed, 0.01)
	var p := boss_data.phases[mini(fight.phase, boss_data.phases.size() - 1)]
	var regen := b.stat(StatModifier.Stat.MAX_HP) * p.regen
	var steal := b.stat(StatModifier.Stat.LIFESTEAL)
	var cap := fight.max_hit()
	return "Boss  ATK %d (x%.2f)  ·  SPD x%.2f  ·  Regen %d/s  ·  Steal %d%%  ·  Hit cap %s  ·  Ranged -%d%%" % [
		roundi(atk), atk / base, spd, roundi(regen), roundi(steal * 100.0),
		"none" if is_inf(cap) else str(roundi(cap)), roundi((p.ranged_resist if p.ranged_resist > 0.0 else boss_data.ranged_resist) * 100.0)]
