extends Node

const ROUNDS := 6
const MAX_FRAMES := 20000

var _main: Node2D
var _frames := 0
var _rounds_played := 0
var _force_seen := false
var _force_min := 999
var _force_wipe_seen := false
var _inspector_checked := false
var _recruits_seen := 0
var _spent_seen := 0
var _no_room_seen := false
var _failed := 0
var _last_phase := -1
var _buff_picks := 0
var _picker_frames := 0
var _hold_checked := false
var _start_hold_checked := false
var _status_overflow := ""
var _hud_overflow := ""
var _done := false
var _roster_before := -1
var _roster_after := -1


func _ready() -> void:
	print("\n=== Six by Eleven — scene smoke test ===\n")
	var packed := load("res://scenes/main.tscn") as PackedScene
	if packed == null:
		push_error("main.tscn failed to load")
		get_tree().quit(1)
		return
	GameSetup.reload_catalogue()
	GameSetup.mode = GameSetup.Mode.VS_COMPUTER
	var forced := OS.get_environment("SIXBYELEVEN_SEED")
	if not forced.is_empty():
		GameSetup.debug_seed = forced.to_int()
		print("(forced match seed %d)" % GameSetup.debug_seed)
	for i in GameSetup.SLOTS:
		GameSetup.set_slot(BoardModel.TEAM_B, i, 5 + i)
		GameSetup.set_slot(BoardModel.TEAM_A, i, 5 + i)
	_main = packed.instantiate() as Node2D
	if _main == null:
		push_error("main.tscn did not instantiate as Node2D")
		get_tree().quit(1)
		return
	add_child(_main)
	_main._player.speed = 80.0
	_check_unbound_board_survives()


func _process(_delta: float) -> void:
	if _done:
		return
	_frames += 1
	if _frames < 3:
		return

	if _frames == 3:
		_check("scene has a BoardView", _main.get_node_or_null("BoardView") != null)
		_check("the bench is gone from the scene",
		_main.get_node_or_null("UI/Root/Bench") == null,
		"a Bench node is still in main.tscn")
		_check("loadout resolved", _main.loadout != null)
		_check("a match can be played entirely with the new units",
			_all_new_units(), "the draw contained an original unit")
		_check("the round-end pause is long enough to read",
			_main.round_end_hold >= 1.0,
			"hold is %.2fs" % _main.round_end_hold)
		_main.round_end_hold = 0.2
		_main.battle_start_hold = 0.15
		_check("the status line wraps instead of running off the screen",
			_main._status.autowrap_mode != TextServer.AUTOWRAP_OFF)
		var screen := Rect2(Vector2.ZERO, _main.get_viewport_rect().size)
		_check("the status line stays inside the window",
			screen.encloses(Rect2(_main._status.position, _main._status.size)),
			"label at %s sized %s" % [_main._status.position, _main._status.size])
		_check("the first draw landed on the board",
			_main.board.count_of(BoardModel.TEAM_B) == MatchState.UNITS_PER_DRAW,
			"got %d units, expected %d" % [
				_main.board.count_of(BoardModel.TEAM_B), MatchState.UNITS_PER_DRAW])
		_check("opponent deployed", _main.board.count_of(BoardModel.TEAM_A) > 0)
		_check("board starts within bounds", _all_units_in_bounds())
		_check_fog_up()

	_watch_status_label()
	_watch_force_bar()

	var phase: int = MatchState.phase
	if phase != _last_phase:
		_last_phase = phase

	match phase:
		MatchState.Phase.BATTLE:
			_watch_round_end_hold()
		MatchState.Phase.PREP:
			_do_prep()
		MatchState.Phase.BUFF_PICK:
			_do_buff_pick()
		MatchState.Phase.ROUND_END:
			_rounds_played += 1
			_check("round %d left a legal board" % _rounds_played, _all_units_in_bounds())
			_check("no unit sits in the neutral row after a round" , _none_in_neutral_row())
			_roster_after = _main.board.all_units().size()
			_check("the whole roster comes back after the battle",
				_roster_after == _roster_before
					+ (_main._kept_recruits - _recruits_seen)
					- (_main._spent_casters - _spent_seen),
				"%d before, %d after, %d raised, %d spent" % [
					_roster_before, _roster_after,
					_main._kept_recruits - _recruits_seen,
					_main._spent_casters - _spent_seen])
			_recruits_seen = _main._kept_recruits
			_spent_seen = _main._spent_casters
			_check("everyone is restored at full health", _all_at_full_health())
			if _rounds_played >= ROUNDS or MatchState.is_match_over():
				_report()
				return
			_main._on_fight_pressed()
		MatchState.Phase.MATCH_END:
			_check("match ended with a winner", MatchState.match_winner() >= 0)
			_report()
			return

	if _frames > MAX_FRAMES:
		_check("test completed before the frame budget", false,
			"stuck in phase %s after %d frames" % [MatchState.phase_name(), _frames])
		_report()


func _do_buff_pick() -> void:
	var picker: BuffPicker = _main._picker
	if picker == null or not picker.visible:
		return
	_picker_frames += 1
	if _picker_frames < 4:
		return
	_picker_frames = 0
	if _buff_picks == 0:
		var options: Array = picker._options
		_check("the picker offers three buffs", options.size() == BuffPool.OPTIONS,
			"offered %d" % options.size())
		_check("the rolled rarity is one the odds allow",
			MatchState.rarity_chance(picker._rarity) > 0.0,
			"%s had a 0%% chance on pick %d" % [
				BuffData.rarity_name(picker._rarity), MatchState.buff_pick_number()])
		_check("the picker tells you what the odds were",
			not String(picker._subtitle.text).is_empty()
			and picker._subtitle.visible,
			"subtitle reads '%s'" % picker._subtitle.text)
		var descriptions_read := true
		for o in options:
			if String(o.describe(picker._rarity)).is_empty():
				descriptions_read = false
		_check("every offered buff describes itself", descriptions_read)
		_check_cards_are_on_screen(picker)
		_check_buff_bars_are_placed()
	var before: int = _main._buffs_for(BoardModel.TEAM_B).size()
	picker._on_take(0)
	_buff_picks += 1
	_check("taking a buff records it for the player",
		_main._buffs_for(BoardModel.TEAM_B).size() == before + 1)
	_check("the opponent picks at the same rarity",
		_main._buffs_for(BoardModel.TEAM_A).size() == before + 1)
	var yours: Dictionary = _main._buffs_for(BoardModel.TEAM_B).picks[before]
	var theirs: Dictionary = _main._buffs_for(BoardModel.TEAM_A).picks[before]
	_check("both sides land on the same rarity even though it was rolled",
		yours.rarity == theirs.rarity,
		"you got %s, they got %s" % [
			BuffData.rarity_name(yours.rarity), BuffData.rarity_name(theirs.rarity)])
	_check("the picker closes once a buff is taken", not picker.visible)
	_check("the buff round moves straight into prep",
		MatchState.phase == MatchState.Phase.PREP,
		"phase is %s" % MatchState.phase_name())
	_check_bars_show_the_picks()


func _bar(team: int) -> BuffBar:
	return _main._bars[team]


func _check_buff_bars_are_placed() -> void:
	var board_top: float = _main._board_view.position.y
	var board_bottom: float = board_top + BoardModel.HEIGHT * _main._board_view.tile_size
	var mine := _bar(BoardModel.TEAM_B)
	var theirs := _bar(BoardModel.TEAM_A)

	_check("your buff bar sits under your half of the board",
		mine.position.y >= board_bottom,
		"bar at y %.0f, board ends at %.0f" % [mine.position.y, board_bottom])
	_check("the opponent's buff bar sits above their half",
		theirs.position.y + theirs.size.y <= board_top,
		"bar ends at y %.0f, board starts at %.0f" % [
			theirs.position.y + theirs.size.y, board_top])
	_check("both bars line up with the board",
		is_equal_approx(mine.position.x, _main._board_view.position.x)
		and is_equal_approx(theirs.position.x, _main._board_view.position.x))

	var screen := Rect2(Vector2.ZERO, _main.get_viewport_rect().size)
	_check("both bars are inside the window",
		screen.encloses(Rect2(mine.position, mine.size))
		and screen.encloses(Rect2(theirs.position, theirs.size)))
	_check("the two bars are told apart by heading",
		mine.heading != theirs.heading and not mine.heading.is_empty())


func _check_bars_show_the_picks() -> void:
	var mine := _bar(BoardModel.TEAM_B)
	var theirs := _bar(BoardModel.TEAM_A)
	_check("your bar lists every buff you hold",
		mine._entries.size() == _main._buffs_for(BoardModel.TEAM_B).size(),
		"%d chips for %d buffs" % [
			mine._entries.size(), _main._buffs_for(BoardModel.TEAM_B).size()])
	_check("you can read the opponent's buffs off their bar",
		theirs._entries.size() == _main._buffs_for(BoardModel.TEAM_A).size()
		and theirs._entries.size() > 0,
		"%d chips for %d buffs" % [
			theirs._entries.size(), _main._buffs_for(BoardModel.TEAM_A).size()])
	_check_hover_reads_a_buff(theirs)
	_check_hover_reads_a_buff(mine)
	_check_idle_buffs_are_greyed(theirs, BoardModel.TEAM_A)


func _check_idle_buffs_are_greyed(bar: BuffBar, team: int) -> void:
	var present: Dictionary = _main._types_on_board(team)
	var mismatched: PackedStringArray = []
	for i in bar._entries.size():
		var e: Dictionary = bar._entries[i]
		var want: bool = TeamBuffs.is_live(_main._buffs_for(team).picks[i].buff, present)
		if bool(e.live) != want:
			mismatched.append(String(e.text))
		if not bool(e.live) and String(e.idle_reason).is_empty():
			mismatched.append("%s has no reason" % e.text)
	_check("every chip's live/greyed state matches the board",
		mismatched.is_empty(), "; ".join(mismatched))

	var starved := TeamBuffs.new()
	starved.add(_main._buffs.by_id(&"ironwall"), BuffData.Rarity.GOLD)
	var probe := BuffBar.new()
	probe.size = bar.size
	probe.set_picks(starved.picks, {&"archer": true})
	_check("a unit buff with none of that unit out reads as greyed",
		not bool(probe._entries[0].live))
	_check("its tooltip says why it is doing nothing",
		probe._get_tooltip(probe._chips[0].get_center()).contains("Inactive"),
		probe._get_tooltip(probe._chips[0].get_center()))
	probe.set_picks(starved.picks, {&"warden": true})
	_check("it lights back up when that unit returns to the board",
		bool(probe._entries[0].live)
		and not probe._get_tooltip(probe._chips[0].get_center()).contains("Inactive"))
	probe.free()


func _check_hover_reads_a_buff(bar: BuffBar) -> void:
	_check("the bar can be hovered at all",
		bar.mouse_filter != Control.MOUSE_FILTER_IGNORE,
		"mouse_filter is %d" % bar.mouse_filter)
	_check("hovering a chip is possible — the bar remembers where it drew them",
		bar._chips.size() == bar._entries.size(),
		"%d hit areas for %d chips" % [bar._chips.size(), bar._entries.size()])
	if bar._chips.is_empty():
		return

	var tip: String = bar._get_tooltip(bar._chips[0].get_center())
	var first: Dictionary = bar._entries[0]
	_check("hovering an enemy buff tells you what it does",
		tip.contains(first.text) and tip.contains(first.rarity)
		and tip.contains(String(first.detail)),
		"tooltip was '%s'" % tip)
	_check("hovering empty bar space says nothing",
		bar._get_tooltip(Vector2(bar.size.x - 2.0, bar.size.y * 0.5)).is_empty())
	_check("the tooltip is built as a wrapped panel, not one long line",
		bar._make_custom_tooltip(tip) is PanelContainer)


func _check_cards_are_on_screen(picker: BuffPicker) -> void:
	var screen := Rect2(Vector2.ZERO, picker.get_viewport_rect().size)
	var cards := picker._column.get_children()
	_check("the picker built a card for every option",
		cards.size() == picker._options.size(),
		"%d cards for %d options" % [cards.size(), picker._options.size()])

	var offenders: PackedStringArray = []
	var last_bottom := -1.0
	var stacked := true
	for i in cards.size():
		var card: Control = cards[i]
		var r := Rect2(card.global_position, card.size)
		if r.size.x <= 1.0 or r.size.y <= 1.0:
			offenders.append("card %d has no size (%s)" % [i, r.size])
			continue
		if not screen.encloses(r):
			offenders.append("card %d at %s spills out of %s" % [i, r, screen.size])
		if r.position.y < last_bottom:
			stacked = false
		last_bottom = r.position.y + r.size.y
	_check("every buff card sits fully inside the window", offenders.is_empty(),
		"; ".join(offenders))
	_check("the cards stack top to bottom, not side by side", stacked)

	if cards.size() >= 2:
		var a: Control = cards[0]
		var b: Control = cards[1]
		_check("the stack is horizontally centred",
			is_equal_approx(a.global_position.x, b.global_position.x)
			and absf((a.global_position.x + a.size.x * 0.5) - screen.size.x * 0.5) < 2.0,
			"card left edges at %.1f and %.1f, screen is %.0f wide" % [
				a.global_position.x, b.global_position.x, screen.size.x])
		_check("the stack sits in the lower half of the screen",
			a.global_position.y > screen.size.y * 0.4,
			"top card starts at y %.0f of %.0f" % [
				a.global_position.y, screen.size.y])


func _all_new_units() -> bool:
	var new_ids := ["assassin", "herald", "revenant", "seraph", "conjurer"]
	for u in _main.board.all_units():
		if not new_ids.has(String(u.data.id)):
			return false
	return true


func _watch_status_label() -> void:
	if _hud_overflow.is_empty():
		var hud: Label = _main._hud
		if hud.get_visible_line_count() < hud.get_line_count():
			_hud_overflow = hud.text
	if not _status_overflow.is_empty():
		return
	var lbl: Label = _main._status
	if lbl.get_visible_line_count() < lbl.get_line_count():
		_status_overflow = lbl.text


func _watch_force_bar() -> void:
	var bar: ForceBar = _main._force
	if bar == null:
		return
	if MatchState.phase == MatchState.Phase.BATTLE and bar.visible:
		_force_seen = true
		_force_min = mini(_force_min, bar.total())
		if bar.mine == 0 or bar.theirs == 0:
			_force_wipe_seen = true


func _check_inspector() -> void:
	if _inspector_checked:
		return
	_inspector_checked = true
	var inspector: UnitInspector = _main._inspector
	_check("the board has a unit inspector over it", inspector != null)
	if inspector == null:
		return
	_check("the inspector covers the board window",
		inspector.position == _main._board_view.view_area.position
		and inspector.size == _main._board_view.view_area.size,
		"inspector at %s sized %s, window %s, board at %s sized %s" % [
			inspector.position, inspector.size,
			_main._board_view.view_area, _main._board_view.position,
			_main._board_view.board_size()])
	_check("the inspector takes mouse input without stealing drags",
		inspector.mouse_filter == Control.MOUSE_FILTER_PASS)

	var mine: Array[UnitInstance] = _main.board.living_units_of(_main.PLAYER_TEAM)
	_check("there is something of yours to inspect", not mine.is_empty())
	if mine.is_empty():
		return
	var unit: UnitInstance = mine[0]
	# The inspector sits over the window; the board scrolls beneath it. A point
	# on the board is only the same point on the inspector when the two happen
	# to be aligned, so convert rather than assume.
	var at: Vector2 = _main._board_view.cell_to_pos(unit.cell) \
		+ _main._board_view.position - inspector.position
	_check("hovering one of your units finds it",
		inspector.unit_under(at) == unit)
	var tip: String = inspector._get_tooltip(at)
	_check("hovering it explains what it does",
		tip.contains(unit.data.display_name) and tip.contains(
			UnitCodex.ability_name(unit.data) if unit.data.ability != null
			else "No ability"),
		tip)
	_check("the tooltip says whose it is",
		tip.contains(GameSetup.team_name(unit.team)), tip)
	_check("hovering empty board says nothing",
		inspector._get_tooltip(Vector2(-500.0, -500.0)).is_empty())

	var panel := inspector._make_custom_tooltip(tip) as Control
	_check("the tooltip is a wrapped panel, not one long line",
		panel != null and panel.get_child_count() > 0
		and (panel.get_child(0) as Label).autowrap_mode != TextServer.AUTOWRAP_OFF)
	if panel != null:
		panel.free()

	var theirs: Array[UnitInstance] = _main.board.living_units_of(
		BoardModel.enemy_of(_main.PLAYER_TEAM))
	if not theirs.is_empty() and _main._board_view.fog:
		_check("fog keeps the enemy's card hidden during prep",
			inspector.unit_under(
				_main._board_view.cell_to_pos(theirs[0].cell)) == null)

	_main._on_unit_inspected(unit)
	_check("clicking a unit writes its card into the status line",
		_main._status.text.contains(unit.data.display_name), _main._status.text)


func _watch_round_end_hold() -> void:
	if _main._player.is_playing() or _hold_checked:
		return
	# Both holds look the same from here — neither is playing — so the ready
	# beat is simply the one that comes first.
	if not _start_hold_checked:
		_watch_battle_start_hold()
		return
	_hold_checked = true
	_check("the board holds after the last unit falls",
		MatchState.phase == MatchState.Phase.BATTLE,
		"phase already moved to %s" % MatchState.phase_name())
	_check("a result banner shows during the pause",
		_main._banner != null and _main._banner.visible,
		"banner reads '%s'" % ("" if _main._banner == null else _main._banner.text))

	var a: int = _main.board.living_units_of(BoardModel.TEAM_A).size()
	var b: int = _main.board.living_units_of(BoardModel.TEAM_B).size()
	_check("the surviving side is still standing on the board", a == 0 or b == 0,
		"A has %d, B has %d — nobody was wiped out" % [a, b])
	_check("the winner's units keep their end-of-battle places",
		_main.board.all_units().size() == a + b,
		"%d on the board, %d alive" % [_main.board.all_units().size(), a + b])

	var bar: ForceBar = _main._force
	_check("the force bar is still readable during the hold", bar.visible)
	_check("it agrees with the board about who is left",
		bar.mine == b and bar.theirs == a,
		"bar says %d v %d, board says %d v %d" % [bar.mine, bar.theirs, b, a])
	_check("one side ends the round holding the whole bar",
		is_equal_approx(bar.mine_share(), 1.0)
		or is_equal_approx(bar.mine_share(), 0.0)
		or bar.total() == 0,
		"share is %.2f" % bar.mine_share())


func _watch_battle_start_hold() -> void:
	if _start_hold_checked:
		return
	_start_hold_checked = true
	_check("the round starts with a beat of anticipation before anyone moves",
		_main.battle_start_hold >= 0.1 and MatchState.phase == MatchState.Phase.BATTLE)
	_check("the ready banner is up during that pause",
		_main._banner != null and _main._banner.visible,
		"banner reads '%s'" % ("" if _main._banner == null else _main._banner.text))
	_check("the shipped pause is long enough to register",
		_main.BATTLE_START_HOLD >= 0.75,
		"BATTLE_START_HOLD is %.2fs" % _main.BATTLE_START_HOLD)
	_check("nobody has taken a swing yet", not _main._player.is_playing())
	_check("the force bar is up before the first blow", _main._force.visible)
	_check("it opens with everyone on the field",
		_main._force.total() == _main.board.all_units().size(),
		"bar says %d, board holds %d" % [
			_main._force.total(), _main.board.all_units().size()])


func _do_prep() -> void:
	_hold_checked = false
	_start_hold_checked = false
	_check_inspector()
	_check("the force bar is out of the way during prep",
		_main._force == null or not _main._force.visible)
	_check_rosters()
	_check_ghosts()
	_check_board_fits()
	_check_no_leftover_views()
	_check_playback_is_event_driven()
	_check("dealt exactly 6 units this turn",
		MatchState.UNITS_PER_DRAW == 6,
		"UNITS_PER_DRAW is %d" % MatchState.UNITS_PER_DRAW)
	_check("units arrive on the board without being placed",
		_main.board.count_of(BoardModel.TEAM_B) > 0,
		"the player's half is empty at the start of prep")
	var has_bench := false
	for prop in _main.get_property_list():
		if prop.name == "player_bench":
			has_bench = true
	_check("nothing is waiting off-board", not has_bench, "a bench still exists")
	_check_fog_up()
	_roster_before = _main.board.all_units().size()
	_main._on_fight_pressed()
	_check_fog_lifted()


func _check_unbound_board_survives() -> void:
	var bare := BoardView.new()
	add_child(bare)
	bare.flash_cells([Vector2i(2, 2)], Color.RED, 1.0)
	bare._hover = Vector2i(3, 3)
	bare.fog = true
	bare._drag_uid = -1
	bare.queue_redraw()
	_check("an unbound BoardView was created and queued for drawing",
		bare.board == null and bare.is_inside_tree())


func _check_fog_up() -> void:
	var view: BoardView = _main.get_node("BoardView")
	_check("fog is up during prep", view.fog)
	_check("no enemy unit is in the tree while fogged",
		_enemy_views(view) == 0, "found %d" % _enemy_views(view))
	_check("player's own units stay visible under fog",
		_own_views(view) == _main.board.count_of(BoardModel.TEAM_B),
		"%d views for %d units" % [_own_views(view), _main.board.count_of(BoardModel.TEAM_B)])


func _check_fog_lifted() -> void:
	var view: BoardView = _main.get_node("BoardView")
	_check("fog lifts when the battle starts", not view.fog)
	_check("enemy units appear on the reveal", _enemy_views(view) > 0)


func _enemy_views(view: BoardView) -> int:
	var n := 0
	for child in view.get_children():
		if child is UnitView and child.unit != null and child.unit.team != view.player_team:
			n += 1
	return n


func _own_views(view: BoardView) -> int:
	var n := 0
	for child in view.get_children():
		if child is UnitView and child.unit != null and child.unit.team == view.player_team:
			n += 1
	return n


func _check_no_leftover_views() -> void:
	var view: BoardView = _main.get_node("BoardView")
	var total := 0
	var ghostly := 0
	var faded := 0
	for child in view.get_children():
		if not (child is UnitView):
			continue
		total += 1
		if child.dying:
			ghostly += 1
		if child.dimmed:
			faded += 1
	var expected: int = _main.board.count_of(BoardModel.TEAM_B)
	_check("no corpses linger into prep", ghostly == 0, "%d still dying" % ghostly)
	_check("no dimmed leftovers in prep", faded == 0, "%d dimmed" % faded)
	_check("exactly one view per visible unit", total == expected,
		"%d views for %d units" % [total, expected])


func _check_playback_is_event_driven() -> void:
	var view: BoardView = _main.get_node("BoardView")
	var mismatched := 0
	var checked := 0
	for child in view.get_children():
		if not (child is UnitView) or child.unit == null or child.dying:
			continue
		checked += 1
		if child.hp_max <= 0.0:
			mismatched += 1
	_check("every live view carries its own health state",
		checked > 0 and mismatched == 0, "%d bad of %d" % [mismatched, checked])


func _all_at_full_health() -> bool:
	for u in _main.board.all_units():
		if not u.is_alive():
			return false
		if u.current_hp < u.stat(StatModifier.Stat.MAX_HP) - 0.01:
			return false
	return true


func _all_units_in_bounds() -> bool:
	for u in _main.board.all_units():
		if not _main.board.in_bounds(u.cell):
			return false
	return true


var _fit_checked := false
var _rosters_checked := false
var _ghosts_seen := false
var _ghost_rounds := 0


func _check_board_fits() -> void:
	if _fit_checked:
		return
	_fit_checked = true
	var view: BoardView = _main._board_view
	var area: Rect2 = _main.BOARD_AREA
	var span := view.board_size()
	_check("the board is laid out from the map, not a fixed tile count",
		is_equal_approx(span.x, BoardModel.WIDTH * view.tile_size)
		and is_equal_approx(span.y, BoardModel.HEIGHT * view.tile_size),
		"%s at tile %.0f for %dx%d" % [
			span, view.tile_size, BoardModel.WIDTH, BoardModel.HEIGHT])
	_check("whatever its shape, it fits the slot reserved for it",
		span.x <= area.size.x + 0.5 and span.y <= area.size.y + 0.5,
		"board %s against area %s" % [span, area.size])
	_check("and it is centred in that slot",
		area.encloses(Rect2(view.position, span)),
		"board at %s sized %s, area %s" % [view.position, span, area])
	_check("the tiles are big enough to see",
		view.tile_size >= 24.0, "%.0f px" % view.tile_size)


func _check_rosters() -> void:
	if _rosters_checked:
		return
	_rosters_checked = true
	var screen := Rect2(Vector2.ZERO, _main.get_viewport_rect().size)
	for team in [BoardModel.TEAM_A, BoardModel.TEAM_B]:
		var bar: RosterBar = _main._rosters[team]
		_check("%s has a roster strip" % GameSetup.short_name(team), bar != null)
		if bar == null:
			continue
		_check("it names the units that side draws from",
			not bar._entries.is_empty())
		var chips: int = bar._chips.size()
		_check("its chips are laid out, so they can be hovered", chips > 0)
		if chips > 0:
			var tip: String = bar._get_tooltip(bar._chips[0].get_center())
			_check("hovering a chip explains the unit",
				tip.contains(String(bar._entries[0].data.display_name)), tip)
		_check("the strip is on screen",
			screen.encloses(Rect2(bar.global_position, bar.size)),
			"at %s sized %s" % [bar.global_position, bar.size])

	var theirs: RosterBar = _main._rosters[BoardModel.TEAM_A]
	var mine: RosterBar = _main._rosters[BoardModel.TEAM_B]
	_check("theirs sits above the board and yours below it",
		theirs.position.y < _main._board_view.position.y
		and mine.position.y > _main._board_view.position.y,
		"theirs %.0f, mine %.0f" % [theirs.position.y, mine.position.y])

	var force: ForceBar = _main._force
	_check("the force bar stands beside the board, not above it", force.vertical
		and force.position.x >= _main._board_view.position.x
			+ _main._board_view.board_size().x,
		"bar at %s" % force.position)
	_check("and it is on screen",
		screen.encloses(Rect2(force.position, force.size)),
		"at %s sized %s" % [force.position, force.size])
	_check("nothing overlaps the roster strips",
		mine.position.y + mine.size.y <= _main._fight_btn.global_position.y,
		"strip ends at %.0f, buttons start at %.0f" % [
			mine.position.y + mine.size.y, _main._fight_btn.global_position.y])


func _check_ghosts() -> void:
	var seen: Array = _main._board_view.ghosts
	if _ghost_rounds == 0:
		_check("the first prep shows no ghosts — there is no last round yet",
			seen.is_empty(), "%d ghosts on round one" % seen.size())
	elif not _ghosts_seen and not seen.is_empty():
		_ghosts_seen = true
		var all_enemy := true
		for g in seen:
			if not _main.board.can_deploy(BoardModel.TEAM_A, g.cell):
				all_enemy = false
		_check("later preps show last round's enemy board through the fog",
			all_enemy, "a ghost sat outside the enemy half")
		_check("and the ghosts are data, not units in the tree",
			_main._board_view._views.size()
				== _main.board.living_units_of(BoardModel.TEAM_B).size(),
			"the enemy leaked real views")
	_ghost_rounds += 1


func _no_spent_unit_on_board() -> bool:
	for entry in _main._roster:
		var u: UnitInstance = entry.unit
		if u.consumed:
			return false
	for u in _main.board.all_units():
		if u.consumed:
			return false
	return true


func _none_in_neutral_row() -> bool:
	for u in _main.board.all_units():
		if _main.board.is_neutral(u.cell):
			return false
	return true


func _check(label: String, condition: bool, detail := "") -> void:
	if condition:
		print("  ok    %s" % label)
	else:
		_failed += 1
		print("  FAIL  %s %s" % [label, detail])


func _report() -> void:
	_done = true
	_check("the HUD never gets cut off", _hud_overflow.is_empty(),
		"clipped: '%s'" % _hud_overflow.replace("\n", " | "))
	_check("the status line never gets cut off", _status_overflow.is_empty(),
		"this message was clipped: '%s'" % _status_overflow)
	_check("a raised host that survives is added to the roster, not lost",
		_main._kept_recruits == _recruits_seen,
		"%d raised, %d accounted for" % [_main._kept_recruits, _recruits_seen])
	_check("the fog eventually shows last round's board", _ghosts_seen,
		"%d preps and never a ghost" % _ghost_rounds)
	_check("a spent Spire never comes back",
		_no_spent_unit_on_board(),
		"a consumed unit is still in the roster")
	_check("the force bar was on screen during the fighting", _force_seen)
	_check("its count fell as units died",
		_force_min < MatchState.UNITS_PER_DRAW * 2,
		"the lowest it ever read was %d" % _force_min)
	_check("it ended a round wholly one colour", _force_wipe_seen)
	_check("the force bar sits on screen above the board",
		_main._force != null
		and Rect2(Vector2.ZERO, _main.get_viewport_rect().size).encloses(
			Rect2(_main._force.position, _main._force.size)),
		"bar at %s sized %s" % [_main._force.position, _main._force.size])
	print("\nPlayed %d rounds. Score %s." % [_rounds_played, str(MatchState.wins)])
	if _failed > 0:
		print("%d FAILURES" % _failed)
	else:
		print("Scene smoke test passed.")
	get_tree().quit(1 if _failed > 0 else 0)
