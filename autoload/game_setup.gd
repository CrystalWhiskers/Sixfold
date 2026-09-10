extends Node

enum Mode { VS_COMPUTER, LOCAL_PVP }

const SLOTS := 5
const BASE_LOADOUT := "res://data/loadouts/roster.tres"
const FALLBACK_LOADOUT := "res://data/loadouts/starter.tres"
const MAP_DIR := "res://data/maps"

var mode: Mode = Mode.VS_COMPUTER
var catalogue: Array[UnitData] = []
var slots: Dictionary = {}
var maps: Array[MapData] = []
## Non-zero forces the match seed, so a test can replay an exact match.
var debug_seed := 0
var map_index := 0

## Which battle tracks are in rotation, one bool per track, chosen in the menu.
## Empty until the first read, because Audio has to have counted the files first.
var battle_playlist: Array[bool] = []

## Its own stream so which track you get is not decided by how many other random
## numbers the match happened to draw.
var _music_rng := RandomNumberGenerator.new()


func _ready() -> void:
	reload_catalogue()


func reload_maps() -> int:
	maps.clear()
	var dir := DirAccess.open(MAP_DIR)
	if dir != null:
		var names := dir.get_files()
		names.sort()
		for file_name in names:
			var clean := file_name.trim_suffix(".remap")
			if not clean.ends_with(".tres"):
				continue
			var res := load("%s/%s" % [MAP_DIR, clean])
			if res is MapData and (res as MapData).is_valid():
				maps.append(res as MapData)
	# Files come off disk alphabetically, which puts Standard somewhere in the
	# twenties. Each map carries the table's own order instead.
	maps.sort_custom(func(a: MapData, b: MapData) -> bool:
		if a.rank != b.rank:
			return a.rank < b.rank
		return a.display_name < b.display_name)
	map_index = clampi(map_index, 0, maxi(maps.size() - 1, 0))
	apply_map()
	return maps.size()


func playlist() -> Array[bool]:
	# Grown, never rebuilt: a track dropped into assets/music turns up switched on
	# and the choices already made about the others are kept.
	while battle_playlist.size() < Audio.battle_track_count:
		battle_playlist.append(true)
	return battle_playlist


func toggle_track(index: int) -> void:
	# One-based, matching the file names. The last track on cannot be switched
	# off — silence is a setting, but it is not one you should be able to reach by
	# clicking things off one at a time without noticing.
	var list := playlist()
	if index < 1 or index > list.size():
		return
	if list[index - 1] and tracks_on() <= 1:
		return
	list[index - 1] = not list[index - 1]


func tracks_on() -> int:
	var n := 0
	for on in playlist():
		if on:
			n += 1
	return n


func roll_battle_track() -> String:
	# Called at the top of every round, so a long match moves through the
	# playlist instead of sitting on whatever it opened with. play_music() is a
	# no-op when the roll lands on the track already playing, which is what keeps
	# a one-track playlist from restarting every round.
	var live: Array[int] = []
	var list := playlist()
	for i in list.size():
		if list[i]:
			live.append(i + 1)
	if live.is_empty():
		return Audio.battle_track(1)
	return Audio.battle_track(live[_music_rng.randi_range(0, live.size() - 1)])


func playlist_summary() -> String:
	var on: Array[String] = []
	for i in playlist().size():
		if playlist()[i]:
			on.append(Audio.battle_track_name(i + 1))
	if on.is_empty():
		return "none"
	if on.size() == playlist().size():
		return "all %d" % on.size()
	return ", ".join(on)


func current_map() -> MapData:
	if maps.is_empty():
		return null
	return maps[clampi(map_index, 0, maps.size() - 1)]


func cycle_map(step: int) -> void:
	if maps.is_empty():
		return
	map_index = wrapi(map_index + step, 0, maps.size())
	apply_map()


func select_map(index: int) -> void:
	if maps.is_empty() or index < 0 or index >= maps.size():
		return
	map_index = index
	apply_map()


func map_id_index(id: StringName) -> int:
	for i in maps.size():
		if maps[i].id == id:
			return i
	return -1


func apply_map() -> void:
	BoardModel.use_map(current_map())


func map_name() -> String:
	var m := current_map()
	return BoardModel.map_name if m == null else m.display_name


func map_summary() -> String:
	var m := current_map()
	return "%d x %d" % [BoardModel.WIDTH, BoardModel.HEIGHT] if m == null else m.summary()


func reload_catalogue() -> void:
	reload_maps()
	catalogue.clear()
	var base := load(BASE_LOADOUT) as LoadoutData
	if base == null or not base.is_valid():
		base = load(FALLBACK_LOADOUT) as LoadoutData
	if base != null and base.is_valid():
		for u in base.units:
			catalogue.append(u)
	reset_slots()


func reset_slots() -> void:
	slots.clear()
	for team in [BoardModel.TEAM_A, BoardModel.TEAM_B]:
		slots[team] = default_slots()


func default_slots() -> Array[int]:
	var out: Array[int] = []
	for i in SLOTS:
		out.append(i % maxi(catalogue.size(), 1))
	return out


func slots_for(team: int) -> Array[int]:
	if not slots.has(team):
		slots[team] = default_slots()
	return slots[team]


func set_slot(team: int, index: int, unit_index: int) -> void:
	var own := slots_for(team)
	if index < 0 or index >= own.size() or catalogue.is_empty():
		return
	own[index] = posmod(unit_index, catalogue.size())


func cycle_slot(team: int, index: int, step: int) -> void:
	var own := slots_for(team)
	if index < 0 or index >= own.size():
		return
	set_slot(team, index, own[index] + step)


func units_for(team: int) -> Array[UnitData]:
	var out: Array[UnitData] = []
	if catalogue.is_empty():
		return out
	for i in slots_for(team):
		out.append(catalogue[clampi(i, 0, catalogue.size() - 1)])
	return out


func loadout_for(team: int) -> LoadoutData:
	var l := LoadoutData.new()
	l.id = &"team_%d" % team
	l.display_name = "Player %d" % (team + 1)
	l.units = units_for(team)
	return l


func player_number(team: int) -> int:
	return 1 if team == BoardModel.TEAM_B else 2


func team_name(team: int) -> String:
	if mode == Mode.LOCAL_PVP:
		return "Player %d" % player_number(team)
	return "You" if team == BoardModel.TEAM_B else "Computer"


func short_name(team: int) -> String:
	if mode == Mode.LOCAL_PVP:
		return "P%d" % player_number(team)
	return "You" if team == BoardModel.TEAM_B else "CPU"


func turn_order() -> Array[int]:
	return [BoardModel.TEAM_B, BoardModel.TEAM_A]


func is_human(team: int) -> bool:
	if mode == Mode.LOCAL_PVP:
		return true
	return team == BoardModel.TEAM_B


func mode_name() -> String:
	return "Local PvP" if mode == Mode.LOCAL_PVP else "Vs Computer"


func default_units_check() -> Array[UnitData]:
	var out: Array[UnitData] = []
	for i in default_slots():
		out.append(catalogue[clampi(i, 0, catalogue.size() - 1)])
	return out


func slot_summary(team: int) -> String:
	var counts := {}
	var order: Array[StringName] = []
	for u in units_for(team):
		if not counts.has(u.id):
			counts[u.id] = 0
			order.append(u.id)
		counts[u.id] += 1
	var parts: PackedStringArray = []
	for id in order:
		var n: int = counts[id]
		var name := String(id).capitalize()
		parts.append(name if n == 1 else "%s x%d" % [name, n])
	return ", ".join(parts)
