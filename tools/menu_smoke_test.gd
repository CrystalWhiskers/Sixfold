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
	print("\n=== Six by Eleven — menu smoke test ===\n")
	GameSetup.reload_catalogue()
	_check("the menu loads its maps", GameSetup.maps.size() >= 5,
		"%d maps" % GameSetup.maps.size())
	_check("and starts on one of them", GameSetup.current_map() != null)
	_check("the menu knows every unit type",
		GameSetup.catalogue.size() == 14, "%d types" % GameSetup.catalogue.size())
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


func _run() -> void:
	await get_tree().process_frame
	await get_tree().process_frame

	var buttons := _buttons(_menu)
	var labels: PackedStringArray = []
	for b in buttons:
		labels.append(b.text)
	_check("the menu offers all three choices",
		labels.has("Battle the Computer") and labels.has("Local PvP")
		and labels.has("Loadouts"),
		"found %s" % str(labels))

	var screen := Rect2(Vector2.ZERO, _menu.get_viewport_rect().size)
	var spilled: PackedStringArray = []
	for b in buttons:
		if not screen.encloses(Rect2(b.global_position, b.size)):
			spilled.append(b.text)
	_check("every menu button is on screen", spilled.is_empty(), "; ".join(spilled))

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

	_check("the editor offers a map picker", editor._map_label != null)
	if editor._map_label != null:
		var before_name: String = editor._map_label.text
		var before_shape := Vector2i(BoardModel.WIDTH, BoardModel.HEIGHT)
		_check("it names the map and its shape",
			before_name.contains("x"), before_name)
		_check("the note explains what the board is like",
			not editor._map_note.text.is_empty())

		editor._on_cycle_map(1)
		_check("cycling changes the map", editor._map_label.text != before_name,
			editor._map_label.text)
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

		var loop_start: String = editor._map_label.text
		var seen := {}
		for i in GameSetup.maps.size():
			seen[String(GameSetup.current_map().id)] = true
			editor._on_cycle_map(1)
		_check("cycling reaches every map and comes back round",
			seen.size() == GameSetup.maps.size()
			and editor._map_label.text == loop_start,
			"%d of %d seen, landed on '%s' from '%s'" % [
				seen.size(), GameSetup.maps.size(),
				editor._map_label.text, loop_start])

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
