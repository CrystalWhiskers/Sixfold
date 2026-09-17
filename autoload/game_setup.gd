extends Node

enum Mode { VS_COMPUTER, LOCAL_PVP, CUSTOM }

const SLOTS := 5
const BASE_LOADOUT := "res://data/loadouts/roster.tres"
const FALLBACK_LOADOUT := "res://data/loadouts/starter.tres"
const MAP_DIR := "res://data/maps"

var mode: Mode = Mode.VS_COMPUTER:
	set(value):
		mode = value
		# Leaving CUSTOM leaves its rules behind with it, structurally rather than by
		# every caller remembering to. The custom screen turns the rules on while it
		# is open so its numbers are live; a player who looks at that screen, backs
		# out and starts an ordinary match must not carry an eight-life match and a
		# forty-second clock into it, and "the menu sets custom = false in two
		# places" is a rule with two chances to be forgotten.
		if value != Mode.CUSTOM:
			custom = false

## Custom match rules. These are read by the flow layer and handed DOWN to the
## simulation as plain numbers — CombatSim never reads this autoload, because the
## combat layer sits below the flow layer and a simulation that needed a global to
## run could not be built in a test.
##
## `custom` is whether they apply at all. Off, every getter below returns the
## conventional value, so there is exactly one code path and the defaults are not a
## separate branch that can rot.
var custom := false

## Lives. Four is the conventional match; the number of buff picks follows from it,
## because picks come round on a cadence and a longer match simply reaches more of
## them. Asking for "more than the conventional three buffs" is asking for this.
var custom_wins := 0

## A buff pick every N rounds. Two is conventional. One is a pick every round.
var custom_buff_every := 2

## When everything doubles and nothing recovers, in seconds, and when the round is
## called a draw. Sudden death has to land before the timeout or it never happens.
var custom_sudden_death := CombatSim.SUDDEN_DEATH
var custom_timeout := CombatSim.DEFAULT_TIMEOUT

## Buff ids the player has switched OFF. Stored as the exclusions rather than the
## allowances so that a buff added to the game later is in the pool by default —
## an allow list would silently leave every new buff out.
var custom_banned: Dictionary = {}


func wins_needed() -> int:
	if not custom or custom_wins <= 0:
		return MatchState.WINS_NEEDED
	return custom_wins


func buff_every() -> int:
	return maxi(custom_buff_every, 1) if custom else 2


func sudden_death_at() -> float:
	if not custom:
		return CombatSim.SUDDEN_DEATH
	# Clamped below the timeout, because a sudden death that lands after the round
	# has already been called a draw is a rule that never fires.
	return clampf(custom_sudden_death, 5.0, round_timeout() - 5.0)


func round_timeout() -> float:
	return maxf(custom_timeout, 15.0) if custom else CombatSim.DEFAULT_TIMEOUT


func banned_buffs() -> Array:
	## The ids to keep out of the offer. Empty outside a custom match.
	return custom_banned.keys() if custom else []


func is_banned(id: StringName) -> bool:
	return custom and custom_banned.has(id)


func set_banned(id: StringName, banned: bool) -> void:
	if banned:
		custom_banned[id] = true
	else:
		custom_banned.erase(id)


func reset_custom() -> void:
	custom_wins = 0
	custom_buff_every = 2
	custom_sudden_death = CombatSim.SUDDEN_DEATH
	custom_timeout = CombatSim.DEFAULT_TIMEOUT
	custom_banned = {}
var catalogue: Array[UnitData] = []
var slots: Dictionary = {}
var maps: Array[MapData] = []
## Non-zero forces the match seed, so a test can replay an exact match.
var debug_seed := 0
var map_index := 0

## Which battle tracks are in rotation, one bool per track, chosen in the menu.
## Empty until the first read, because Audio has to have counted the files first.
var battle_playlist: Array[bool] = []

## Whether boss tracks may come up as ordinary battle music. Off by default: a
## boss theme means something when it only plays for a boss, and a player who
## wants them in the general rotation can say so.
var boss_in_pool := false

## Whether unit portraits are drawn at all. Off means every unit falls back to
## the coloured plate and its initial — the look the game has for the units that
## have no art yet, applied to all of them.
##
## On by default: a unit with art should show it unless you say otherwise.
var portraits := true:
	set(value):
		portraits = value
		# Written down to the view layer, which is where the drawing reads it.
		# The setting belongs up here with the playlist; the flag has to live down
		# there so the two scripts that draw a unit do not have to know an autoload
		# exists — see UnitView.portraits_on.
		UnitView.portraits_on = value

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
	# Rolled once per MATCH, not per round — the battle theme is meant to be the
	# sound of this match rather than a shuffle between rounds. play_music() is a
	# no-op when the roll lands on the track already playing.
	var live: Array[String] = []
	var list := playlist()
	for i in list.size():
		if list[i]:
			live.append(Audio.battle_track(i + 1))
	if boss_in_pool:
		# Let in as full members of the rotation rather than with some separate
		# weight: "allow boss themes into the pool" means the pool, and a boss
		# track being longer is not a reason for it to be rarer.
		for i in Audio.boss_track_count:
			live.append(Audio.boss_track(i + 1))
	if live.is_empty():
		return Audio.battle_track(1)
	return live[_music_rng.randi_range(0, live.size() - 1)]


func roll_boss_track() -> String:
	## The track for a round with a tier 6 on the board. Rolled fresh each time
	## rather than fixed for the match, because a boss round is an event and two
	## of them in one match should not sound like the same event twice.
	if Audio.boss_track_count <= 0:
		return ""
	return Audio.boss_track(_music_rng.randi_range(1, Audio.boss_track_count))


static func is_boss_round(board: BoardModel) -> bool:
	## A tier 6 unit anywhere on the board, either side. Deliberately not "the
	## PLAYER has a tier 6": the music is about what is on the field, and walking
	## into an enemy tier 6 is the moment that most deserves marking.
	if board == null:
		return false
	for u in board.all_units():
		if u.is_alive() and u.data != null and u.data.tier >= 6:
			return true
	return false


func toggle_boss_in_pool() -> void:
	boss_in_pool = not boss_in_pool


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
	match mode:
		Mode.LOCAL_PVP:
			return "Local PvP"
		Mode.CUSTOM:
			return "Custom"
	return "Vs Computer"


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
