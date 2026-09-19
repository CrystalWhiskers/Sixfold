extends Node2D

const LOADOUT_PATH := "res://data/loadouts/starter.tres"
const MENU_SCENE := "res://scenes/menu.tscn"
const PLAYER_TEAM := BoardModel.TEAM_B
const AI_TEAM := BoardModel.TEAM_A
const BAR_HEIGHT := 26.0
const BAR_GAP := 8.0
# Every map is drawn into this slot, so the HUD around it never has to move.
const BOARD_AREA := Rect2(108.0, 132.0, 504.0, 924.0)
const FORCE_WIDTH := 74.0
const FORCE_GAP := 16.0
const ROSTER_HEIGHT := 24.0
const ROUND_END_HOLD := 1.8
const BATTLE_START_HOLD := 1.3

@onready var _board_view: BoardView = $BoardView
@onready var _hud: Label = $UI/Root/Hud
@onready var _status: Label = $UI/Root/Status
@onready var _fight_btn: Button = $UI/Root/Buttons/Fight
@onready var _merge_all_btn: Button = $UI/Root/Buttons/MergeAll
@onready var _speed_btn: Button = $UI/Root/Buttons/Speed
@onready var _menu_btn: Button = $UI/Root/Buttons/Menu

var board := BoardModel.new()
var loadout: LoadoutData
var _player_rng := RandomNumberGenerator.new()
var _ai_rng := RandomNumberGenerator.new()
var _roster: Array[Dictionary] = []
var _player: BattlePlayer
var _speeds: Array[float] = [1.0, 2.0, 4.0]
var _speed_idx := 1
var _buffs: BuffPool = BuffPool.new()
var _team_buffs: Dictionary = {}
var _buff_rng := RandomNumberGenerator.new()
var _picker: BuffPicker = null

## The track this MATCH drew. Held so the boss rule has something to put back
## when the tier 6 that triggered it is off the board again.
var _match_track := ""

## The boss track this match turned over to, once it has. Empty until the first round
## with a tier 6 on the board, and then never empty again for the rest of the match.
##
## This is what makes the change a ONE-WAY door. It used to re-roll a boss track at the
## start of every boss round and fall back to the ordinary theme on every round without a
## tier 6 — so a match where the big unit died and got merged back flipped between two
## kinds of music round after round, and even a run of consecutive boss rounds played a
## different boss theme each time. The moment is supposed to be "the fight changed", and a
## moment that happens five times is not a moment.
var _boss_track := ""

## How many times the boss rule has been asked. Exists for one reason: the smoke
## test checks it against the number of rounds played, which is the only way to
## prove the round loop still CALLS _refresh_music(). Testing the rule itself is
## easy; testing that anybody asks it is what kept slipping — three separate
## bugs this week were a working function nothing called.
var music_checks := 0
var _bars: Dictionary = {}
var _force: ForceBar = null
var _rosters: Dictionary = {}
var _mask: BoardMask = null
var _last_formation: Dictionary = {}
var _inspector: UnitInspector = null
var _banner: Label = null
var _clock_label: Label = null
var _handover: HandoverScreen = null
var _loadouts: Dictionary = {}
var _active_team := PLAYER_TEAM
var _prep_queue: Array[int] = []
var _pick_queue: Array[int] = []
var _pick_rarity: BuffData.Rarity = BuffData.Rarity.BRONZE
var _after_blind: Callable = Callable()
var round_end_hold := ROUND_END_HOLD
var battle_start_hold := BATTLE_START_HOLD
var battle_running := false
var _kept_recruits := 0
var _spent_casters := 0


func _pvp() -> bool:
	return GameSetup.mode == GameSetup.Mode.LOCAL_PVP


func _human_teams() -> Array[int]:
	if _pvp():
		return GameSetup.turn_order()
	return [PLAYER_TEAM]


func _rng_for(team: int) -> RandomNumberGenerator:
	return _player_rng if team == PLAYER_TEAM else _ai_rng


func _loadout_for(team: int) -> LoadoutData:
	return _loadouts[team]


func _blind_then(next_team: int, action: Callable) -> void:
	if not _pvp() or _handover == null:
		action.call()
		return
	_board_view.interactive = false
	_fight_btn.disabled = true
	_merge_all_btn.disabled = true
	_after_blind = action
	_handover.blind(next_team)


func _on_handover_ready() -> void:
	var action := _after_blind
	_after_blind = Callable()
	_fight_btn.disabled = false
	_merge_all_btn.disabled = false
	if action.is_valid():
		action.call()


func _ready() -> void:
	# Rolled ONCE, here, and never touched again. The playlist decides which track
	# a match gets; it does not shuffle between rounds. A match is one piece of
	# music from the first prep phase to the last body — the boss rule below is
	# the single exception, and it puts this track back when the tier 6 is gone.
	_match_track = GameSetup.roll_battle_track()
	# Per MATCH, not per round: a new match starts on ordinary music however the last one
	# ended, or the boss theme would leak from one match into the next.
	_boss_track = ""
	Audio.play_music(_match_track)
	# The map decides the board's shape, so it has to be chosen before anything
	# asks the board how big it is.
	if GameSetup.maps.is_empty():
		GameSetup.reload_maps()
	GameSetup.apply_map()
	_board_view.player_team = PLAYER_TEAM
	_board_view.fit_to(BOARD_AREA)
	_board_view.bind(board)
	_build_board_mask()

	var raw := load(LOADOUT_PATH)
	if raw == null:
		_fail("Can't load %s at all — the file is missing, or its script failed to bind."
			% LOADOUT_PATH)
		return
	if not (raw is LoadoutData):
		_fail("%s loaded as %s, not a LoadoutData. Your .godot cache is probably stale: close Godot, delete the .godot folder, reopen."
			% [LOADOUT_PATH, raw.get_class()])
		return
	loadout = raw as LoadoutData
	if not loadout.is_valid():
		_fail("Loadout at %s is empty or has a null unit in it. Regenerate with tools/generate_data.gd."
			% LOADOUT_PATH)
		return

	if GameSetup.catalogue.is_empty():
		GameSetup.reload_catalogue()
	_loadouts = {
		BoardModel.TEAM_A: GameSetup.loadout_for(BoardModel.TEAM_A),
		BoardModel.TEAM_B: GameSetup.loadout_for(BoardModel.TEAM_B),
	}
	if not _loadout_for(PLAYER_TEAM).is_valid():
		_fail("The chosen loadout is empty. Go back to the menu and pick units.")
		return

	_player = BattlePlayer.new()
	add_child(_player)
	_player.finished.connect(_on_playback_finished)
	_player.counts_changed.connect(_on_counts_changed)
	_board_view.cell_pressed.connect(_on_cell_pressed)
	_board_view.drag_dropped.connect(_on_drag_dropped)
	_board_view.cell_double_clicked.connect(_on_cell_double_clicked)

	# Fight gets the bell rather than the confirm click: it IS the round starting,
	# and two sounds on one press is one too many. Menu keeps the confirm; the
	# speed toggle stays silent rather than clicking every time you cycle past a
	# setting.
	_fight_btn.pressed.connect(Audio.play_round_start)
	_fight_btn.pressed.connect(_on_fight_pressed)
	_merge_all_btn.pressed.connect(_on_merge_all_pressed)
	_speed_btn.pressed.connect(_cycle_speed)
	_menu_btn.pressed.connect(Audio.play_confirm)
	_menu_btn.pressed.connect(_on_menu_pressed)
	_update_speed_label()

	_team_buffs = {
		BoardModel.TEAM_A: TeamBuffs.new(),
		BoardModel.TEAM_B: TeamBuffs.new(),
	}
	board.team_buffs = _team_buffs
	if _buffs.load_all() == 0:
		push_warning("No buffs in %s — buff picks will be skipped." % BuffPool.BUFF_DIR)

	_build_buff_bars()

	_picker = BuffPicker.new()
	_picker.picked.connect(_on_buff_picked)
	_picker.rerolled.connect(_on_buff_rerolled)
	$UI/Root.add_child(_picker)

	_handover = HandoverScreen.new()
	_handover.ready_pressed.connect(_on_handover_ready)
	$UI/Root.add_child(_handover)

	var seed_value := (GameSetup.debug_seed if GameSetup.debug_seed != 0
		else int(Time.get_unix_time_from_system()))
	board.configure_merges(_loadout_for(PLAYER_TEAM).units, seed_value + 4242)
	board.set_team_pool(BoardModel.TEAM_A, GameSetup.units_for(BoardModel.TEAM_A))
	board.set_team_pool(BoardModel.TEAM_B, GameSetup.units_for(BoardModel.TEAM_B))
	MatchState.start_match(seed_value, [
		_loadout_for(BoardModel.TEAM_A), _loadout_for(BoardModel.TEAM_B),
	] as Array[LoadoutData])
	_player_rng.seed = seed_value
	_ai_rng.seed = seed_value + 9001
	_buff_rng.seed = seed_value + 77
	_begin_prep()


func _build_board_mask() -> void:
	# First child of the HUD layer, so it paints over the board and under
	# everything else the HUD draws.
	_mask = BoardMask.new()
	_mask.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_mask.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_mask.set_window(BOARD_AREA)
	$UI/Root.add_child(_mask)
	$UI/Root.move_child(_mask, 0)


func _look_at_half(team: int) -> void:
	if not _board_view.overflows():
		return
	var cells := board.deploy_cells(team)
	if cells.is_empty():
		return
	var mid := 0
	for c in cells:
		mid += c.y
	_board_view.centre_on(Vector2i(BoardModel.WIDTH / 2, mid / cells.size()))


func _build_buff_bars() -> void:
	# Everything here is laid out against BOARD_AREA — the window the board is
	# seen through — and never against the board's own pixel size. A 9 x 25 map
	# is 1400 pixels tall and slides under the pan; furniture pinned to that ends
	# up off screen, or worse, parked on top of the buttons where its PASS filter
	# swallows the clicks.
	var origin := BOARD_AREA.position
	var board_w := BOARD_AREA.size.x
	var board_h := BOARD_AREA.size.y

	var theirs := BuffBar.new()
	theirs.heading = GameSetup.short_name(AI_TEAM) if _pvp() else "Theirs"
	theirs.accent = Color(0.83, 0.63, 0.39)
	theirs.position = Vector2(origin.x, origin.y - BAR_HEIGHT - BAR_GAP)
	theirs.size = Vector2(board_w, BAR_HEIGHT)
	theirs.mouse_filter = Control.MOUSE_FILTER_PASS
	$UI/Root.add_child(theirs)

	var mine := BuffBar.new()
	mine.heading = GameSetup.short_name(PLAYER_TEAM) if _pvp() else "Yours"
	mine.accent = Color(0.38, 0.66, 0.69)
	mine.position = Vector2(origin.x, origin.y + board_h + BAR_GAP)
	mine.size = Vector2(board_w, BAR_HEIGHT)
	mine.mouse_filter = Control.MOUSE_FILTER_PASS
	$UI/Root.add_child(mine)

	_bars = {AI_TEAM: theirs, PLAYER_TEAM: mine}
	_refresh_buff_bars()

	# The force bar stands beside the board so the two horizontal slots above and
	# below it belong to the rosters. Vertical also reads the way the board does.
	_force = ForceBar.new()
	_force.vertical = true
	_force.mine_name = GameSetup.short_name(PLAYER_TEAM)
	_force.theirs_name = GameSetup.short_name(AI_TEAM)
	# Aligned to the VISIBLE board: the board's drawn rect clipped to the slot it is
	# drawn in. Two failures, one from each direction, and it has to avoid both.
	#
	# Sized to the SLOT, a short map leaves the bar floating past both ends of the
	# board, and it stops reading as "this half is yours". Sized to the BOARD, a map
	# taller than the window — the Labyrinth is twenty-four rows — makes the bar
	# taller than the screen. The intersection is what the player can actually see,
	# which is what BoardMask windows the board down to anyway.
	#
	# The buff bars above and below stay on the slot, so the horizontal HUD never
	# moves between maps. Only this one has to line up row for row.
	var shown := Rect2(_board_view.position,
		_board_view.board_size()).intersection(BOARD_AREA)
	if shown.size.y <= 0.0:
		shown = BOARD_AREA
	_force.position = Vector2(origin.x + board_w + FORCE_GAP, shown.position.y)
	_force.size = Vector2(FORCE_WIDTH, shown.size.y)
	_force.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_force.visible = false
	$UI/Root.add_child(_force)

	var their_roster := RosterBar.new()
	their_roster.heading = "%s draws" % GameSetup.short_name(AI_TEAM)
	their_roster.accent = Color(0.83, 0.63, 0.39)
	their_roster.position = Vector2(origin.x,
		origin.y - BAR_HEIGHT - BAR_GAP - ROSTER_HEIGHT - 4.0)
	their_roster.size = Vector2(board_w, ROSTER_HEIGHT)
	their_roster.mouse_filter = Control.MOUSE_FILTER_PASS
	$UI/Root.add_child(their_roster)

	var my_roster := RosterBar.new()
	my_roster.heading = "%s draws" % GameSetup.short_name(PLAYER_TEAM)
	my_roster.accent = Color(0.38, 0.66, 0.69)
	my_roster.position = Vector2(origin.x,
		origin.y + board_h + BAR_GAP + BAR_HEIGHT + 4.0)
	my_roster.size = Vector2(board_w, ROSTER_HEIGHT)
	my_roster.mouse_filter = Control.MOUSE_FILTER_PASS
	$UI/Root.add_child(my_roster)

	_rosters = {AI_TEAM: their_roster, PLAYER_TEAM: my_roster}
	_refresh_rosters()

	_inspector = UnitInspector.new()
	_inspector.bind(_board_view)
	_inspector.unit_pressed.connect(_on_unit_inspected)
	$UI/Root.add_child(_inspector)

	_banner = Label.new()
	_banner.position = Vector2(origin.x, origin.y + board_h * 0.5 - 34.0)
	_banner.size = Vector2(board_w, 68.0)
	_banner.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_banner.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_banner.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_banner.add_theme_font_size_override("font_size", 34)
	_banner.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.85))
	_banner.add_theme_constant_override("shadow_offset_x", 2)
	_banner.add_theme_constant_override("shadow_offset_y", 2)
	_banner.visible = false
	$UI/Root.add_child(_banner)

	# The round clock. Parked just under the board's top edge, over the opponent's
	# half, where nothing else is drawn and it is never in the way of a drag.
	_clock_label = Label.new()
	_clock_label.position = Vector2(origin.x, origin.y + 4.0)
	_clock_label.size = Vector2(board_w, 30.0)
	_clock_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_clock_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_clock_label.add_theme_font_size_override("font_size", 22)
	_clock_label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.85))
	_clock_label.add_theme_constant_override("shadow_offset_x", 2)
	_clock_label.add_theme_constant_override("shadow_offset_y", 2)
	_clock_label.visible = false
	$UI/Root.add_child(_clock_label)


func _process(_delta: float) -> void:
	# The countdown, and the one thing on screen that has to be recomputed every
	# frame rather than on an event. It follows the PLAYER's clock, not the sim's:
	# the battle is fully resolved before frame one, so the sim's own elapsed is
	# already at the end, and at 4x speed the clock has to run at 4x with it or it
	# would disagree with what you are watching.
	if _clock_label == null:
		return
	var showing := battle_running and _player != null and _player.is_playing()
	_clock_label.visible = showing
	if not showing:
		return
	var left := maxf(CombatSim.DEFAULT_TIMEOUT - _player.clock(), 0.0)
	_clock_label.text = "%d:%02d" % [int(left) / 60, int(left) % 60]
	# Amber for the last thirty seconds, which is also exactly when hits start
	# escalating — one colour change for both facts, because they arrive together.
	_clock_label.add_theme_color_override("font_color",
		Color(0.98, 0.72, 0.36) if left <= CombatSim.DEFAULT_TIMEOUT - CombatSim.SUDDEN_DEATH
		else Color(0.86, 0.90, 0.96))


func _on_counts_changed(team_a: int, team_b: int) -> void:
	if _force == null:
		return
	_force.set_counts(
		team_b if PLAYER_TEAM == BoardModel.TEAM_B else team_a,
		team_a if PLAYER_TEAM == BoardModel.TEAM_B else team_b)
	_refresh_hud()


func _seed_force_bar() -> void:
	if _force == null:
		return
	_force.set_counts(board.living_units_of(PLAYER_TEAM).size(),
		board.living_units_of(AI_TEAM).size())
	_force.visible = true


func _hide_force_bar() -> void:
	if _force != null:
		_force.visible = false


func live_count(team: int) -> int:
	# During playback the board holds end-of-battle state, so the running tally
	# has to come from the player, not the model.
	if battle_running and _player != null:
		return _player.living(team)
	return board.living_units_of(team).size()


func _on_unit_inspected(u: UnitInstance) -> void:
	if u == null:
		return
	_status.text = UnitCodex.one_line_of(u)
	if MatchState.phase == MatchState.Phase.PREP and u.team == _active_team:
		_status.text += " Drag onto a twin to merge, or double-click one."


func _refresh_rosters() -> void:
	for team in _rosters:
		var bar: RosterBar = _rosters[team]
		bar.set_units(GameSetup.units_for(team))


func _refresh_buff_bars() -> void:
	var taking_turn := _pvp() and (MatchState.phase == MatchState.Phase.PREP
		or MatchState.phase == MatchState.Phase.BUFF_PICK)
	for team in _bars:
		var bar: BuffBar = _bars[team]
		bar.set_picks(_buffs_for(team).picks, _types_on_board(team))
		bar.set_active(taking_turn and team == _active_team)


func _types_on_board(team: int) -> Dictionary:
	var present := {}
	for u in board.units_of(team):
		present[u.data.id] = true
	return present


func _begin_prep() -> void:
	MatchState.set_phase(MatchState.Phase.PREP)
	_resync_buffs()

	var placed := {}
	for team in [BoardModel.TEAM_B, BoardModel.TEAM_A]:
		placed[team] = _summon(team, _rng_for(team))
	if not _pvp():
		_ai_merge_pass()

	_prep_queue = _human_teams()
	_open_prep_turn(_prep_queue[0], int(placed[_prep_queue[0]]))


func _refresh_music() -> void:
	music_checks += 1
	# Checked at ROUND START, not during prep, and the difference is the whole of
	# why this rule used to look broken.
	#
	# It was asked at the top of the prep phase, which is before the player has
	# touched anything — and a tier 6 only ever comes from a MERGE, which happens
	# during prep. So the round you finally built your tier 6 was the one round
	# guaranteed to play an ordinary battle theme, and the announcement arrived a
	# round late, attached to nothing. Asked here, the answer is about the board
	# the fight is actually being fought on.
	if not _boss_track.is_empty():
		# Already turned over. It stays turned over: no re-roll, and no going back to the
		# ordinary theme because the tier 6 happens to be dead this round.
		Audio.play_music(_boss_track)
		return
	if not GameSetup.is_boss_round(board):
		Audio.play_music(_match_track)
		return
	var boss := GameSetup.roll_boss_track()
	if boss.is_empty():
		# No boss files on disk is a perfectly ordinary state — the match track just keeps
		# playing, and nothing is remembered, so the rule is still armed if files appear.
		Audio.play_music(_match_track)
		return
	_boss_track = boss
	Audio.play_music(_boss_track)


func _resync_buffs() -> void:
	for u in board.all_units():
		_buffs_for(u.team).resync(u)
	for team in [BoardModel.TEAM_A, BoardModel.TEAM_B]:
		board.set_wild_merge(team, _buffs_for(team).wild_merge())


func _open_prep_turn(team: int, placed := -1) -> void:
	_hide_force_bar()
	_look_at_half(team)
	_active_team = team
	_board_view.player_team = team
	_board_view.set_ghosts(_last_formation.get(BoardModel.enemy_of(team), []))
	_board_view.set_fog(true)
	_board_view.interactive = true
	_board_view.rebuild()
	_board_view.sync_positions()
	_fight_btn.disabled = false
	_merge_all_btn.disabled = false
	_fight_btn.text = "Fight" if _prep_queue.size() <= 1 else "Done"
	_refresh_hud()
	_refresh_buff_bars()
	if placed >= 0:
		_report_summon(placed)
	else:
		_status.text = "%s — arrange your half, then press %s." % [
			GameSetup.team_name(team), _fight_btn.text]


func _finish_prep_turn() -> void:
	if board.living_units_of(_active_team).is_empty():
		_status.text = "Place at least one unit first."
		return
	_prep_queue.pop_front()
	if _prep_queue.is_empty():
		_start_battle()
		return
	var next: int = _prep_queue[0]
	_blind_then(next, _open_prep_turn.bind(next, -1))


func _draw_size(team: int) -> int:
	var tb := _buffs_for(team)
	if tb.skip_draws > 0:
		tb.skip_draws -= 1
		return 0
	return maxi(MatchState.UNITS_PER_DRAW + tb.extra_draw(), 0)


func _summon(team: int, rng: RandomNumberGenerator) -> int:
	var drawn := _loadout_for(team).draw(rng, _draw_size(team))
	var placed := 0
	for d in drawn:
		var free := board.free_deploy_cells(team)
		if free.is_empty():
			break
		var cell: Vector2i = free[rng.randi_range(0, free.size() - 1)]
		var u := UnitInstance.create(d, team)
		_buffs_for(team).apply_to(u)
		if board.place(u, cell):
			placed += 1
	return placed


func _report_summon(placed: int) -> void:
	var wanted := maxi(MatchState.UNITS_PER_DRAW
		+ _buffs_for(_active_team).extra_draw(), 0)
	if placed == 0 and wanted > 0 and board.units_of(_active_team).size() > 0:
		_status.text = "No draw this round — you took the tier 3 gift. Arrange what you have."
		return
	if placed == wanted:
		_status.text = "%d units arrived. Arrange them, then Fight." % placed
	elif placed > 0:
		_status.text = "Only %d of %d fit — the rest were lost. Merge to make room." % [
			placed, wanted]
	else:
		_status.text = "Your half is full, so this round's draw was lost entirely. Merge."


func _ai_merge_pass() -> void:
	for i in MatchState.UNITS_PER_DRAW:
		if not _ai_merge_once():
			break


func _ai_merge_once() -> bool:
	var mine := board.units_of(AI_TEAM)
	for a in mine:
		for b in mine:
			if board.can_merge(a, b):
				board.merge(a, b, b.cell)
				return true
	return false


func _on_cell_pressed(cell: Vector2i) -> void:
	if MatchState.phase != MatchState.Phase.PREP:
		return
	var u := board.unit_at(cell)
	if u == null or u.team != _active_team:
		return
	_status.text = "%s Drag onto a twin to merge, or double-click." % UnitCodex.one_line_of(u)


func _next_merge_for(team: int) -> Dictionary:
	## One legal merge for this side, or an empty dictionary. Deliberately returns the
	## FIRST it finds rather than the best: there is no "best" here — a merge is a merge,
	## the pool decides what comes out, and picking by some other rule would only make the
	## button's result harder to predict than doing it by hand.
	var mine := board.units_of(team)
	for a in mine:
		for b in mine:
			if board.can_merge(a, b):
				return {a = a, b = b, at = b.cell}
	return {}


func _on_merge_all_pressed() -> void:
	## Merges everything that can be merged, repeatedly, until nothing can.
	##
	## Repeatedly matters: merging two tier 1s makes a tier 2, which may now pair with a
	## tier 2 that was already there. Stopping after one pass would leave the board in a
	## state the player can obviously improve by pressing the button again, which is worse
	## than not having the button.
	##
	## The loop cannot run away — every merge removes exactly one unit from the board — so
	## the number of units it starts with is a real bound rather than a guessed cap.
	if MatchState.phase != MatchState.Phase.PREP:
		return
	Audio.play_confirm()
	var budget := board.units_of(_active_team).size()
	var merged := 0
	var last := Vector2i(-1, -1)
	while merged < budget:
		var pair := _next_merge_for(_active_team)
		if pair.is_empty():
			break
		board.merge(pair.a, pair.b, pair.at)
		last = pair.at
		merged += 1
	if merged == 0:
		_after_board_change("Nothing left to merge.")
		return
	# ONE sound and one flourish for the batch, on the last tile. A merge sound per pair
	# is a machine gun, and the player pressed one button.
	var note := _proc_note()
	_after_board_change("Merged %d time%s.%s" % [
		merged, "" if merged == 1 else "s", note])
	_celebrate_merge(last)
	_show_merge_procs(last)


func _on_cell_double_clicked(cell: Vector2i) -> void:
	## Merge without the drag. Finds a twin of whatever is under the cursor and brings it
	## here, so the common case — two of the same unit sitting somewhere on your half —
	## takes one gesture instead of a drag across the board.
	##
	## The result lands on the tile you CLICKED, not on the twin's tile. You pointed at
	## where you want the bigger unit to be; making it appear somewhere else and leaving a
	## hole where you pointed would be the opposite of what the gesture asks for.
	if MatchState.phase != MatchState.Phase.PREP:
		return
	var target := board.unit_at(cell)
	if target == null or target.team != _active_team:
		return
	var twin := _merge_twin_for(target)
	if twin == null:
		# Said out loud rather than ignored. A gesture that silently does nothing is
		# indistinguishable from one the game does not have.
		_after_board_change("Nothing to merge that with.")
		return
	board.merge(twin, target, cell)
	var note := _proc_note()
	_after_board_change("Merged — rolled %s.%s" % [
		board.unit_at(cell).data.display_name, note])
	_celebrate_merge(cell)
	_show_merge_procs(cell)


func _merge_twin_for(target: UnitInstance) -> UnitInstance:
	## The best other unit to merge INTO `target`, or null.
	##
	## Nearest first, and that is a real choice rather than a tidiness one: with three of
	## a kind on the board, taking the nearest leaves the two you did not touch where you
	## put them, which is the outcome you can predict without looking. Picking by uid or by
	## board order would move a different one every time for no reason the player can see.
	var best: UnitInstance = null
	var best_gap := 1 << 30
	for u in board.units_of(_active_team):
		if u == target or not board.can_merge(u, target):
			continue
		var gap := BoardModel.tile_distance(u.cell, target.cell)
		if gap < best_gap:
			best_gap = gap
			best = u
	return best


func _on_drag_dropped(from: Vector2i, to: Vector2i) -> void:
	if MatchState.phase != MatchState.Phase.PREP:
		_board_view.sync_positions()
		return
	var mover := board.unit_at(from)
	var target := board.unit_at(to)
	if mover == null or mover.team != _active_team:
		_board_view.sync_positions()
		return

	if target == null:
		if board.can_deploy(_active_team, to):
			board.move_unit(mover, to)
			_after_board_change("Moved.")
		else:
			_after_board_change("You can't deploy there.")
		return

	if board.can_merge(mover, target):
		board.merge(mover, target, to)
		var note := _proc_note()
		_after_board_change("Merged — rolled %s.%s" % [
			board.unit_at(to).data.display_name, note])
		_celebrate_merge(to)
		_show_merge_procs(to)
	elif target.team == _active_team:
		board.swap_cells(from, to)
		_after_board_change("Swapped.")
	else:
		_after_board_change("That's not your unit.")


func _proc_note() -> String:
	var procs := board.last_merge_procs
	var parts: PackedStringArray = []
	var tiers := int(procs.get("extra_tiers", 0))
	if tiers == 1:
		parts.append("Promotion pushed it up a tier!")
	elif tiers > 1:
		parts.append("Promotion pushed it up %d tiers!" % tiers)
	var extras: Array = procs.get("extra_units", [])
	for extra in extras:
		parts.append("Windfall summoned a %s!" % extra.data.display_name)
	if parts.is_empty():
		return ""
	return " " + " ".join(parts)


func _celebrate_merge(at: Vector2i) -> void:
	# Must run after _after_board_change: that rebuilds every view, which would
	# throw away a pop set on the old one.
	var made := board.unit_at(at)
	if made == null:
		return
	var pos := _board_view.cell_to_pos(at)
	# Only reached from a human drag — the AI's merges run through
	# _ai_merge_pass() and never come here, which is what keeps the opponent's
	# prep phase silent. A merge sound behind the fog would count their units for
	# you.
	Audio.play_merge()
	_board_view.flash_cells([at], Color(1.0, 0.88, 0.52, 0.55), 0.45)
	_board_view.spawn_label(pos, "T%d" % made.data.tier, Color(1.0, 0.92, 0.62))
	var v := _board_view.view_for(made.uid)
	if v != null:
		v.merge_pop()


func _show_merge_procs(at: Vector2i) -> void:
	var procs := board.last_merge_procs
	if int(procs.get("extra_tiers", 0)) > 0:
		Audio.play_promotion()
		_board_view.flash_cells([at], Color(1.0, 0.84, 0.35, 0.65), 0.9)
		_board_view.spawn_label(_board_view.cell_to_pos(at),
			"PROMOTION!" if int(procs.extra_tiers) == 1
				else "PROMOTION x%d!" % int(procs.extra_tiers),
			Color(1.0, 0.86, 0.40))
	for extra in procs.get("extra_units", []) as Array:
		Audio.play_windfall()
		_board_view.flash_cells([extra.cell], Color(0.55, 0.88, 0.62, 0.65), 0.9)
		_board_view.spawn_label(_board_view.cell_to_pos(extra.cell), "WINDFALL!",
			Color(0.58, 0.92, 0.66))


func _after_board_change(message: String) -> void:
	_board_view.rebuild()
	_refresh_hud()
	_refresh_buff_bars()
	_status.text = message


func _on_fight_pressed() -> void:
	match MatchState.phase:
		MatchState.Phase.PREP:
			_finish_prep_turn()
		MatchState.Phase.ROUND_END, MatchState.Phase.BUFF_PICK:
			_next_round()
		MatchState.Phase.MATCH_END:
			get_tree().change_scene_to_file(MENU_SCENE)
		_:
			pass


func _next_round() -> void:
	MatchState.advance_round()
	if MatchState.phase == MatchState.Phase.BUFF_PICK and not _buffs.buffs.is_empty():
		_open_buff_pick()
		return
	_begin_prep()


func _buffs_for(team: int) -> TeamBuffs:
	return _team_buffs[team]


func _open_buff_pick() -> void:
	_pick_rarity = MatchState.roll_rarity(_buff_rng)
	_pick_queue = _human_teams()
	_show_picker_for(_pick_queue[0])


## Rerolls a player gets per buff pick. One: enough to rescue a hand of three
## buffs that suit none of your units, not enough to shop for the best in the pool.
const REROLLS_PER_PICK := 1


func _on_buff_rerolled() -> void:
	# Same team, same rarity, three new cards. The rng is the match's own, so a
	# replay of the same match with the same clicks still comes out identical.
	_show_picker_for(_active_team, false)


func _show_picker_for(team: int, fresh := true) -> void:
	var options := _buffs.offer(_buff_rng, BuffPool.OPTIONS, _taken_ids(team),
		_fielded_ids(team), _pick_rarity)
	if options.is_empty():
		_finish_buff_pick()
		return
	_active_team = team
	_board_view.interactive = false
	_fight_btn.disabled = true
	_merge_all_btn.disabled = true
	_status.text = "%s buff — %s picks one." % [
		BuffData.rarity_name(_pick_rarity), GameSetup.team_name(team)]
	_refresh_hud()
	_refresh_buff_bars()
	_picker.open(options, _pick_rarity, MatchState.round_index,
		_odds_note(_pick_rarity), GameSetup.team_name(team) if _pvp() else "",
		REROLLS_PER_PICK if fresh else -1)


func _finish_buff_pick() -> void:
	if not _pick_queue.is_empty():
		var next: int = _pick_queue[0]
		_blind_then(next, _show_picker_for.bind(next))
		return
	if not _pvp():
		_ai_pick_buff(_pick_rarity)
	_fight_btn.disabled = false
	_merge_all_btn.disabled = false
	_begin_prep()


func _odds_note(_rolled: BuffData.Rarity) -> String:
	return "Odds this round —  %s" % RarityTable.describe(MatchState.buff_pick_number())


func _fielded_ids(team: int) -> Dictionary:
	var out := {}
	for u in GameSetup.units_for(team):
		out[u.id] = true
	return out


func _taken_ids(team: int) -> Array:
	# Only what is already held AT THE RARITY BEING OFFERED. Holding a bronze
	# Windfall does not take Windfall off the table — a silver one is a second,
	# independent instance that rolls on its own, which is the whole point of
	# letting the rarities stack. Holding the bronze one does stop a second
	# bronze, because two identical picks would be indistinguishable.
	var out: Array = []
	for p in _buffs_for(team).picks:
		if int(p.rarity) == int(_pick_rarity):
			out.append(p.buff.id)
	# And whatever a custom match has switched off. Folded in here rather than
	# filtered out of the pool, because BuffPool.offer() already takes exclusions and
	# a second filtering mechanism would be a second thing to keep in step.
	out.append_array(GameSetup.banned_buffs())
	return out


func _on_buff_picked(buff: BuffData, rarity: int) -> void:
	var team: int = _pick_queue.pop_front() if not _pick_queue.is_empty() else PLAYER_TEAM
	_grant(team, buff, rarity as BuffData.Rarity)
	var taker := GameSetup.team_name(team)
	_finish_buff_pick()
	_status.text = "%s took %s %s. %s" % [
		taker, BuffData.rarity_name(rarity as BuffData.Rarity), buff.display_name,
		buff.describe(rarity as BuffData.Rarity)]


func _ai_pick_buff(rarity: BuffData.Rarity) -> void:
	var options := _buffs.offer(_buff_rng, BuffPool.OPTIONS, _taken_ids(AI_TEAM),
		_fielded_ids(AI_TEAM), rarity)
	if options.is_empty():
		return
	_grant(AI_TEAM, options[_buff_rng.randi_range(0, options.size() - 1)], rarity)


func _grant(team: int, buff: BuffData, rarity: BuffData.Rarity) -> void:
	var tb := _buffs_for(team)
	tb.add(buff, rarity)
	for u in board.units_of(team):
		tb.apply_last_to(u)
	board.set_wild_merge(team, tb.wild_merge())
	_fire_one_shot(team, buff, rarity)
	_refresh_buff_bars()


func _fire_one_shot(team: int, buff: BuffData, rarity: BuffData.Rarity) -> void:
	match buff.kind:
		BuffData.Kind.BOARD_FILL:
			_fill_half(team, roundi(buff.magnitude(rarity).x))
		BuffData.Kind.TIER_GIFT:
			_gift_units(team, buff.magnitude(rarity))
			_buffs_for(team).skip_draws += 1
		BuffData.Kind.SACRIFICE:
			_sacrifice_highest(team)
		BuffData.Kind.MIMIC:
			_mimic_highest(team, roundi(buff.magnitude(rarity).x))


func _fill_half(team: int, target: int) -> int:
	# Up to a headcount, not up to the edges of the board. Filling every free
	# tile made Levy scale with the map — a formality on the Pit and an army on
	# the Compound — and it rewarded going into the pick with an empty board.
	# Topping up to a fixed number means it is worth most when you are behind.
	var made := 0
	var rng := _rng_for(team)
	while board.count_of(team) < target:
		var free := board.free_deploy_cells(team)
		if free.is_empty():
			break
		var pick := _loadout_for(team).draw_one(rng)
		if pick == null:
			break
		var u := UnitInstance.create(pick, team)
		_buffs_for(team).apply_to(u)
		if not board.place(u, free[rng.randi_range(0, free.size() - 1)]):
			break
		made += 1
	_board_view.rebuild()
	return made


func _gift_units(team: int, spec: Vector2) -> int:
	var count := roundi(spec.x)
	var tier := maxi(roundi(spec.y), 1)
	var rng := _rng_for(team)
	var made := 0
	for i in count:
		var free := board.free_deploy_cells(team)
		if free.is_empty():
			break
		var base := _loadout_for(team).draw_one(rng)
		if base == null:
			break
		var shape := BoardModel.at_tier(base, tier)
		if shape == null:
			shape = base
		var u := UnitInstance.create(shape, team)
		_buffs_for(team).apply_to(u)
		if board.place(u, free[rng.randi_range(0, free.size() - 1)]):
			made += 1
	_board_view.rebuild()
	return made


func _mimic_highest(team: int, copies: int) -> int:
	# Copies the *template*, not the instance: a mimic of a wounded unit arrives
	# at full health, and it carries no shields, mana or battle state from the
	# thing it copied. Ties go to whatever is furthest along the board order,
	# which is stable for a given board rather than random.
	var best: UnitInstance = null
	for u in board.units_of(team):
		if best == null or u.data.tier > best.data.tier:
			best = u
	if best == null:
		return 0
	var made := 0
	var rng := _rng_for(team)
	for i in maxi(copies, 1):
		var free := board.free_deploy_cells(team)
		if free.is_empty():
			break
		var copy := UnitInstance.create(best.data, team)
		_buffs_for(team).apply_to(copy)
		if board.place(copy, free[rng.randi_range(0, free.size() - 1)]):
			made += 1
	_board_view.rebuild()
	return made


static func sacrifice_yield(tier: int) -> int:
	return clampi((tier + 1) / 2, 1, 3)


func _sacrifice_highest(team: int) -> int:
	var best: UnitInstance = null
	for u in board.units_of(team):
		if best == null or u.data.tier > best.data.tier:
			best = u
	if best == null:
		return 0
	var steps := sacrifice_yield(best.data.tier)
	var altar := best.cell
	board.remove(best)
	for u in board.units_of(team):
		for i in steps:
			if u.data.is_max_tier():
				break
			u.promote_to(u.data.next_tier, [] as Array[StatModifier])
		_buffs_for(team).resync(u)
	_board_view.rebuild()
	_board_view.flash_cells([altar], Color(0.92, 0.72, 0.35, 0.7), 1.0)
	_board_view.spawn_label(_board_view.cell_to_pos(altar), "SACRIFICE",
		Color(0.95, 0.78, 0.42))
	return steps


func _start_battle() -> void:
	_board_view.interactive = false
	_board_view.player_team = PLAYER_TEAM
	battle_running = false
	_resync_buffs()
	# Before the phase flips, so the boss theme is already playing under the
	# "Steady..." banner rather than arriving after the first blow.
	_refresh_music()
	MatchState.set_phase(MatchState.Phase.BATTLE)
	_fight_btn.disabled = true
	_merge_all_btn.disabled = true

	_roster.clear()
	for u in board.all_units():
		_roster.append({unit = u, cell = u.cell})

	_last_sim = CombatSim.new()
	_last_sim.team_buffs = _team_buffs
	# The clock, handed down as plain numbers. The simulation never reads GameSetup —
	# the combat layer sits below this one — so a custom round length arrives here or
	# not at all.
	_last_sim.sudden_death = GameSetup.sudden_death_at()
	_last_sim.timeout = GameSetup.round_timeout()
	_last_sim.setup(board, MatchState.round_seed())
	EventBus.battle_started.emit(MatchState.round_seed())

	_board_view.set_fog(false)
	_board_view.rebuild()
	_board_view.flash_cells(board.deploy_cells(AI_TEAM),
		Color(0.55, 0.68, 0.80, 0.45), 0.55)
	_fight_btn.text = "Fight"

	_pending_winner = _last_sim.run()
	_absorb_recruits()
	_pending_duration = _last_sim.duration()
	_player.speed = _speeds[_speed_idx]
	_seed_force_bar()
	_refresh_hud()
	_show_ready_banner()
	_status.text = "Both sides are set. Steady..."
	await get_tree().create_timer(maxf(battle_start_hold, 0.01)).timeout
	if not is_inside_tree() or MatchState.phase != MatchState.Phase.BATTLE:
		return
	if _banner != null:
		_banner.visible = false
	battle_running = true
	_player.play(_board_view, _last_sim.events, _last_sim.unit_map())
	_status.text = "Fighting..."


func _show_ready_banner() -> void:
	if _banner == null:
		return
	_banner.text = "READY..."
	_banner.add_theme_color_override("font_color", Color(0.88, 0.90, 0.95))
	_banner.visible = true


var _last_sim: CombatSim = null
var _pending_winner := CombatSim.RESULT_DRAW
var _pending_duration := 0.0


func _on_playback_finished(_winner: int) -> void:
	battle_running = false
	_show_banner()
	_status.text = "%s Holding the board..." % _outcome_line()
	await get_tree().create_timer(maxf(round_end_hold, 0.01)).timeout
	if not is_inside_tree():
		return
	_conclude_round()


func _outcome_line() -> String:
	if _pending_winner < 0:
		return "Both sides wiped out. Draw."
	var loser := BoardModel.enemy_of(_pending_winner)
	return "%s's last unit falls — %s takes the round." % [
		GameSetup.team_name(loser), GameSetup.team_name(_pending_winner)]


func _show_banner() -> void:
	if _banner == null:
		return
	if _pending_winner >= 0 and _pvp():
		_banner.text = "%s WINS" % GameSetup.team_name(_pending_winner).to_upper()
		_banner.add_theme_color_override("font_color",
			HandoverScreen.team_tint(_pending_winner))
	elif _pending_winner == PLAYER_TEAM:
		_banner.text = "ROUND WON"
		_banner.add_theme_color_override("font_color", Color(0.52, 0.84, 0.56))
	elif _pending_winner == AI_TEAM:
		_banner.text = "ROUND LOST"
		_banner.add_theme_color_override("font_color", Color(0.88, 0.42, 0.38))
	else:
		_banner.text = "DRAW"
		_banner.add_theme_color_override("font_color", Color(0.82, 0.80, 0.62))
	_banner.visible = true


func _conclude_round() -> void:
	if _banner != null:
		_banner.visible = false
	_restore_roster()
	_record_formations()
	EventBus.battle_finished.emit(_pending_winner, _pending_duration)

	var label := "Draw."
	if _pending_winner >= 0:
		label = "%s won the round." % GameSetup.team_name(_pending_winner)
	MatchState.record_round(_pending_winner)

	_board_view.rebuild()
	_refresh_hud()
	_refresh_buff_bars()
	_fight_btn.disabled = false
	_merge_all_btn.disabled = false

	if MatchState.is_match_over():
		var champ := "%s wins the match." % GameSetup.team_name(MatchState.match_winner())
		_status.text = "%s %s Back to the menu?" % [label, champ]
		_fight_btn.text = "Menu"
		MatchState.set_phase(MatchState.Phase.MATCH_END)
	else:
		_status.text = "%s%s Click Next Round." % [label, _recruit_note()]
		_fight_btn.text = "Next Round"


func _recruit_note() -> String:
	var n: int = _last_sim.recruits().size() if _last_sim != null else 0
	if n <= 0:
		return ""
	return " Your Spires spent themselves and raised %d unit%s — yours from now on." % [
		n, "" if n == 1 else "s"]


func _absorb_recruits() -> void:
	# A Spire's host joins the roster for good. Their battle cell is meaningless
	# next round — they get a fresh place in their own half, which persist_room()
	# already guaranteed exists. The Spire that raised them is spent, so it drops
	# out of the roster in the same pass.
	var kept: Array[Dictionary] = []
	var spent := 0
	for entry in _roster:
		var u: UnitInstance = entry.unit
		if u.consumed:
			spent += 1
			continue
		kept.append(entry)
	for entry in _last_sim.recruits():
		var u: UnitInstance = entry.unit
		kept.append({unit = u, cell = Vector2i(-1, -1)})
	_roster = kept
	_kept_recruits += _last_sim.recruits().size()
	_spent_casters += spent


func _record_formations() -> void:
	# Taken after the roster is restored, so a Spire that spent itself is already
	# gone and the units it raised are already in. This is what the other player
	# sees through the fog next round.
	for team in [BoardModel.TEAM_A, BoardModel.TEAM_B]:
		var seen: Array[Dictionary] = []
		for u in board.units_of(team):
			seen.append({data = u.data, cell = u.cell})
		_last_formation[team] = seen


func _restore_roster() -> void:
	board.clear()
	# The round boundary for terrain as well as for units. A Mason's wall and a
	# Sapper's hole are battle state, exactly like shields and mana, and they have
	# to be gone BEFORE deploy cells are worked out below — otherwise last round's
	# stone is still standing on tiles you are trying to place into, and the map
	# quietly shrinks a little every round.
	#
	# CombatSim.setup() clears it too. That is the belt to this braces: the sim
	# guarantees a battle starts from the drawn map even in a test that never went
	# through this function.
	BoardModel.clear_changes()
	for entry in _roster:
		var u: UnitInstance = entry.unit
		u.reset_for_battle()
		var home: Vector2i = entry.cell
		if board.in_bounds(home) and board.is_empty(home) and board.can_deploy(u.team, home):
			board.force_place(u, home)
		else:
			var free := board.free_deploy_cells(u.team)
			if not free.is_empty():
				board.force_place(u, free[0])


func _on_menu_pressed() -> void:
	get_tree().change_scene_to_file(MENU_SCENE)


func _cycle_speed() -> void:
	_speed_idx = (_speed_idx + 1) % _speeds.size()
	_player.speed = _speeds[_speed_idx]
	_update_speed_label()


func _update_speed_label() -> void:
	_speed_btn.text = "Speed x%d" % int(_speeds[_speed_idx])


func _refresh_hud() -> void:
	var first := BoardModel.TEAM_B
	var second := BoardModel.TEAM_A
	var counts := {}
	for team: int in [first, second]:
		var hidden: bool = _board_view.fog and team != _board_view.player_team
		counts[team] = ("?" if hidden and not BoardView.FOG_SHOWS_COUNT
			else str(live_count(team)))

	_hud.text = "%s  ·  Round %d  ·  %s\n%s %d – %d %s   ·   board %s v %s" % [
		GameSetup.mode_name(), MatchState.round_index, MatchState.phase_name(),
		GameSetup.team_name(first), MatchState.wins[first],
		MatchState.wins[second], GameSetup.team_name(second),
		counts[first], counts[second],
	]
	if _pvp() and MatchState.phase == MatchState.Phase.PREP:
		_hud.text += "   ·   %s is arranging" % GameSetup.team_name(_active_team)



func _fail(message: String) -> void:
	_status.text = message
	push_error(message)


func _unhandled_key_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and event.keycode == KEY_F1:
		print(board.to_ascii())
