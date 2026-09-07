class_name BattlePlayer
extends Node

signal finished(winner: int)
signal counts_changed(team_a: int, team_b: int)

const ATTACK_LUNGE := 0.22
const LUNGE_TIME := 0.14

const FLIGHT_PER_TILE := 0.07
const MELEE_REACH := 1.5

const MIN_CAST_SHOW := 0.32
const BEAM_COLOR := Color(0.72, 0.90, 1.0)

@export var speed := 1.0

var _view: BoardView = null
var _units: Dictionary = {}
var _events: Array[Dictionary] = []
var _cursor := 0
var _clock := 0.0
var _playing := false
var _winner := CombatSim.RESULT_DRAW

var _pos: Dictionary = {}
var _hp: Dictionary = {}
var _moves: Dictionary = {}
var _lunges: Dictionary = {}
var _flight: Dictionary = {}
var _deferred: Array[Dictionary] = []
var _counts: Array[int] = [0, 0]


func play(view: BoardView, events: Array[Dictionary], units := {}) -> void:
	_view = view
	_units = units
	_events = events
	_cursor = 0
	_clock = 0.0
	_playing = true
	_winner = CombatSim.RESULT_DRAW
	_pos.clear()
	_hp.clear()
	_moves.clear()
	_lunges.clear()
	_flight.clear()
	_deferred.clear()
	_counts = [0, 0]
	set_process(true)
	_announce_counts()


func stop() -> void:
	_playing = false
	set_process(false)


func is_playing() -> bool:
	return _playing


func _process(delta: float) -> void:
	if not _playing:
		return
	_clock += delta * speed

	while _cursor < _events.size() and _events[_cursor].t <= _clock:
		_apply(_events[_cursor])
		_cursor += 1

	_advance_moves()
	_advance_lunges(delta)
	_advance_deferred()
	_place_views()

	if _cursor >= _events.size() and _moves.is_empty() and _deferred.is_empty():
		_playing = false
		set_process(false)
		finished.emit(_winner)


func _apply(e: Dictionary) -> void:
	match e.kind:
		"spawn":
			_pos[e.uid] = _view.cell_to_pos(e.cell)
			_hp[e.uid] = {cur = float(e.hp), max = float(e.max_hp)}
			var sv := _view.view_for(e.uid)
			if sv != null:
				sv.set_hp(float(e.hp), float(e.max_hp))
				sv.has_ability = bool(e.get("has_ability", false))
				sv.set_mana(0.0)
				sv.set_shield(0.0)
		"move":
			_moves[e.uid] = {
				from = _view.cell_to_pos(e.from),
				to = _view.cell_to_pos(e.to),
				start = float(e.t),
				duration = maxf(float(e.duration), 0.01),
			}
		"attack":
			_begin_attack(e)
		"damage":
			_schedule_damage(e)
		"counts":
			_counts = [int(e.a), int(e.b)]
			_announce_counts()
		"empowered":
			var ev := _view.view_for(e.uid)
			if ev != null:
				ev.queue_redraw()
			_view.spawn_label(_view.cell_to_pos(e.cell), "EMPOWERED",
				Color(1.00, 0.86, 0.42))
		"ascend":
			# Its health bar has to be rebuilt, not just refilled: the maximum
			# moved, so a view still holding the old one draws it permanently full.
			var av := _view.view_for(e.uid)
			if av != null:
				av.set_hp(float(e.hp), float(e.max_hp))
				av.queue_redraw()
			_hp[e.uid] = {cur = float(e.hp), max = float(e.max_hp)}
			_view.spawn_label(_view.cell_to_pos(e.cell), "ASCENDED",
				Color(0.92, 0.40, 0.48))
		"taunt_end":
			var tv := _view.view_for(e.uid)
			if tv != null:
				tv.queue_redraw()
		"sudden_death":
			_view.spawn_label(_view.board_size() * 0.5, "SUDDEN DEATH",
				Color(0.98, 0.52, 0.40))
		"beam":
			_show_beam(e)
		"blocked":
			var bv := _view.view_for(e.uid)
			if bv != null:
				bv.hit()
		"heal":
			_heal(e)
		"blink":
			_pos[e.uid] = _view.cell_to_pos(e.to)
			_moves.erase(e.uid)
			_view.flash_cells([e.from, e.to], Color(0.55, 0.42, 0.78, 0.55), 0.4)
		"stealth":
			_set_stealth(e)
		"summon":
			_summon(e)
		"respawn_start":
			_schedule_revive(e)
		"respawn":
			_respawn(e)
		"mana":
			var mv := _view.view_for(e.uid)
			if mv != null:
				mv.set_mana(float(e.mana))
		"shield":
			var shv := _view.view_for(e.uid)
			if shv != null:
				shv.set_shield(float(e.shield))
		"ability":
			_show_ability(e)
		"cast_start":
			_begin_cast(e)
		"cast_resolve":
			var cells: Array[Vector2i] = []
			for c in e.cells:
				cells.append(c)
			_view.flash_cells(cells, Color(0.95, 0.65, 0.30, 0.55), 0.35)
		"death":
			if bool(e.get("consumed", false)):
				_view.spawn_label(_pos.get(e.uid, _view.cell_to_pos(e.cell)),
					"SPENT", Color(0.82, 0.74, 0.52))
			_schedule_death(e)
		"end":
			_winner = e.winner


func _begin_cast(e: Dictionary) -> void:
	# Openers resolve instantly in the sim; the view still shows a wind-up so no
	# ability ever lands out of nowhere.
	var sim_time := float(e.get("duration", 0.0))
	var shown := maxf(sim_time, MIN_CAST_SHOW) / maxf(speed, 0.01)
	_view.flash_cells([e.centre], Color(0.85, 0.55, 0.25, 0.30), shown)
	var v := _view.view_for(e.uid)
	if v == null:
		return
	v.begin_cast(shown, String(e.get("name", "")).to_upper(),
		bool(e.get("guarded", false)))


func _show_beam(e: Dictionary) -> void:
	# The line takes the brunt; the wash beside it is what makes it read as a
	# wide beam rather than a thread.
	var line: Array[Vector2i] = []
	for c in e.get("cells", []):
		line.append(c)
	var washed: Array[Vector2i] = []
	for c in e.get("washed", []):
		if not line.has(c):
			washed.append(c)
	_view.flash_cells(washed, Color(0.55, 0.80, 1.0, 0.28), 0.40)
	_view.flash_cells(line, Color(0.80, 0.94, 1.0, 0.50), 0.42)


func _begin_attack(e: Dictionary) -> void:
	var from: Vector2 = _pos.get(e.uid, _view.cell_to_pos(e.from))
	var to: Vector2 = _pos.get(e.target_uid, _view.cell_to_pos(e.to))
	var tiles := from.distance_to(to) / maxf(_view.tile_size, 1.0)

	var shooter: UnitInstance = _units.get(e.uid, null)
	if shooter != null and shooter.data.beam_attack:
		# Instant and unending: no travel time, and it runs past whoever it hit.
		_view.spawn_beam(from, to, BEAM_COLOR, shooter.data.beam_endless)
		_flight.erase(e.target_uid)
		return

	if tiles <= MELEE_REACH:
		_lunges[e.uid] = {dir = (to - from).normalized(), left = LUNGE_TIME}
		return

	var flight := tiles * FLIGHT_PER_TILE
	_flight[e.target_uid] = maxf(_flight.get(e.target_uid, 0.0), flight)
	_view.spawn_shot(from, to, flight / maxf(speed, 0.01), false)


func _schedule_damage(e: Dictionary) -> void:
	var delay: float = 0.0 if bool(e.get("spell", false)) else _flight.get(e.uid, 0.0)
	if delay <= 0.0:
		_hit(e)
		return
	_deferred.append({due = _clock + delay, kind = "damage", event = e})


func _schedule_death(e: Dictionary) -> void:
	var delay: float = _flight.get(e.uid, 0.0)
	if delay <= 0.0:
		_kill(e.uid)
		return
	_deferred.append({due = _clock + delay, kind = "death", event = e})


func _show_ability(e: Dictionary) -> void:
	var at: Vector2 = _pos.get(e.uid, _view.cell_to_pos(e.cell))
	match int(e.kind):
		AbilityData.Kind.HASTE:
			_view.spawn_label(at, "CAST", Color(0.98, 0.85, 0.42))
		AbilityData.Kind.SHIELD:
			_view.spawn_label(at, "SHIELD", Color(0.53, 0.79, 0.92))
		AbilityData.Kind.DOT:
			if e.has("target_cell"):
				_view.spawn_shot(at, _view.cell_to_pos(e.target_cell), 0.18, true)
				_view.flash_cells([e.target_cell], Color(0.55, 0.85, 0.40, 0.45), 0.5)
		AbilityData.Kind.FOCUS_BURST:
			var cells: Array[Vector2i] = []
			for c in e.get("cells", []):
				cells.append(c)
			_view.flash_cells(cells, Color(0.95, 0.60, 0.25, 0.40), 0.35)
			if e.has("target_cell"):
				_view.flash_cells([e.target_cell], Color(1.0, 0.82, 0.35, 0.75), 0.45)
		AbilityData.Kind.PIERCE:
			var line: Array[Vector2i] = []
			for c in e.get("cells", []):
				line.append(c)
			_view.flash_cells(line, Color(0.90, 0.45, 0.35, 0.55), 0.4)
		AbilityData.Kind.BLINK_STRIKE:
			if e.has("target_cell"):
				_view.flash_cells([e.target_cell], Color(0.62, 0.40, 0.80, 0.7), 0.45)
		AbilityData.Kind.SPEED_AURA:
			var buffed: Array[Vector2i] = []
			for c in e.get("cells", []):
				buffed.append(c)
			_view.flash_cells(buffed, Color(0.92, 0.84, 0.44, 0.45), 0.6)
			_view.spawn_label(at, "HORN", Color(0.92, 0.84, 0.44))
		AbilityData.Kind.BURST_HEAL:
			var mended: Array[Vector2i] = []
			for c in e.get("cells", []):
				mended.append(c)
			_view.flash_cells(mended, Color(0.45, 0.82, 0.70, 0.40), 0.5)
		AbilityData.Kind.SUMMON:
			if bool(e.get("wasted", false)):
				_view.spawn_label(at, _waste_label(String(e.get("reason", ""))),
					Color(0.86, 0.42, 0.38))
				return
			var spot: Array[Vector2i] = []
			for c in e.get("cells", []):
				spot.append(c)
			_view.flash_cells(spot, Color(0.66, 0.52, 0.88, 0.55), 0.45)
		AbilityData.Kind.REVIVE:
			pass
		AbilityData.Kind.RAISE:
			if bool(e.get("wasted", false)):
				_view.spawn_label(at, "NO DEAD", Color(0.62, 0.66, 0.74))
				return
			var graves: Array[Vector2i] = []
			for c in e.get("cells", []):
				graves.append(c)
			_view.flash_cells(graves, Color(0.58, 0.72, 0.86, 0.55), 0.6)
			_view.spawn_label(at, "RISE", Color(0.72, 0.82, 0.94))
		AbilityData.Kind.ASCEND:
			# Two different things share this ability, so they need two labels:
			# the one-off change, and the armed swing that follows every later bar.
			if bool(e.get("armed", false)):
				_view.spawn_label(at, "MARKED", Color(0.92, 0.36, 0.44))
			else:
				_view.spawn_label(at, "GORGED", Color(0.80, 0.30, 0.42))


static func _waste_label(reason: String) -> String:
	match reason:
		"no_home":
			return "NO ROOM"
		"no_room":
			return "NO SPACE"
		"capped":
			return "AT CAP"
	return "WASTED"


func _hit(e: Dictionary) -> void:
	_hp[e.uid] = {cur = float(e.hp), max = float(_hp.get(e.uid, {}).get("max", 1.0))}
	var v := _view.view_for(e.uid)
	var at: Vector2 = _pos.get(e.uid, _view.cell_to_pos(e.cell))
	_view.spawn_damage(at, float(e.amount), bool(e.get("spell", false)))
	if v != null:
		v.set_hp(float(e.hp), v.hp_max)
		v.set_shield(float(e.get("shield", 0.0)))
		v.hit()


func _set_stealth(e: Dictionary) -> void:
	var v := _view.view_for(e.uid)
	if v == null:
		return
	v.hidden_unit = bool(e.on)
	v.queue_redraw()
	if bool(e.on):
		_view.spawn_label(_pos.get(e.uid, v.position), "VANISH",
			Color(0.68, 0.56, 0.88))


func _summon(e: Dictionary) -> void:
	var unit: UnitInstance = _units.get(e.uid, null)
	if unit == null:
		return
	var v := _view.ensure_view(unit)
	_pos[e.uid] = _view.cell_to_pos(e.cell)
	_hp[e.uid] = {cur = float(e.hp), max = float(e.max_hp)}
	if v == null:
		return
	v.position = _pos[e.uid]
	v.dying = false
	v.death_t = 0.0
	v.set_hp(float(e.hp), float(e.max_hp))
	v.has_ability = bool(e.get("has_ability", false))
	v.set_mana(0.0)
	v.set_shield(0.0)
	_view.spawn_label(v.position, "SUMMON", Color(0.72, 0.62, 0.90))


func _schedule_revive(e: Dictionary) -> void:
	var delay: float = _flight.get(e.uid, 0.0)
	if delay <= 0.0:
		_begin_revive(e)
		return
	_deferred.append({due = _clock + delay + 0.01, kind = "revive_start", event = e})


func _begin_revive(e: Dictionary) -> void:
	var unit: UnitInstance = _units.get(e.uid, null)
	var v := _view.view_for(e.uid)
	if v == null and unit != null:
		v = _view.ensure_view(unit)
	_pos[e.uid] = _view.cell_to_pos(e.cell)
	if v == null:
		return
	v.position = _pos[e.uid]
	v.begin_revive()
	_view.spawn_label(v.position, "RISING", Color(0.60, 0.88, 0.66))
	_view.flash_cells([e.cell], Color(0.45, 0.85, 0.55, 0.35), float(e.duration))


func _respawn(e: Dictionary) -> void:
	var unit: UnitInstance = _units.get(e.uid, null)
	_pos[e.uid] = _view.cell_to_pos(e.cell)
	_hp[e.uid] = {cur = float(e.hp), max = float(e.max_hp)}
	var v := _view.view_for(e.uid)
	if v == null and unit != null:
		v = _view.ensure_view(unit)
	if v == null:
		return
	v.dying = false
	v.death_t = 0.0
	v.display_hp = 0.0
	v.end_revive()
	v.position = _pos[e.uid]
	v.set_hp(float(e.hp), float(e.max_hp))
	v.set_shield(0.0)
	v.set_mana(0.0)
	v.queue_redraw()
	_view.spawn_label(v.position, "UP AGAIN", Color(0.55, 0.85, 0.60))


func _heal(e: Dictionary) -> void:
	var entry: Dictionary = _hp.get(e.uid, {})
	_hp[e.uid] = {cur = float(e.hp), max = float(entry.get("max", 1.0))}
	var v := _view.view_for(e.uid)
	if v == null:
		return
	v.set_hp(float(e.hp), v.hp_max)
	if float(e.amount) >= 1.0:
		var at: Vector2 = _pos.get(e.uid, _view.cell_to_pos(e.cell))
		_view.spawn_label(at, "+%d" % roundi(float(e.amount)), Color(0.45, 0.82, 0.48))


func _kill(uid: int) -> void:
	_view.kill_view(uid)
	_moves.erase(uid)
	_lunges.erase(uid)
	_flight.erase(uid)


func living(team: int) -> int:
	return _counts[BoardModel.TEAM_B if team == BoardModel.TEAM_B else BoardModel.TEAM_A]


func _announce_counts() -> void:
	counts_changed.emit(_counts[BoardModel.TEAM_A], _counts[BoardModel.TEAM_B])


func _advance_deferred() -> void:
	if _deferred.is_empty():
		return
	var i := 0
	while i < _deferred.size():
		var d: Dictionary = _deferred[i]
		if d.due > _clock:
			i += 1
			continue
		if d.kind == "damage":
			_hit(d.event)
		else:
			_kill(d.event.uid)
			_flight.erase(d.event.uid)
		_deferred.remove_at(i)


func _advance_moves() -> void:
	var done: Array[int] = []
	for uid in _moves:
		var m: Dictionary = _moves[uid]
		var t: float = clampf((_clock - m.start) / m.duration, 0.0, 1.0)
		var eased: float = t * t * (3.0 - 2.0 * t)
		_pos[uid] = m.from.lerp(m.to, eased)
		if t >= 1.0:
			done.append(uid)
	for uid in done:
		_moves.erase(uid)


func _advance_lunges(delta: float) -> void:
	var done: Array[int] = []
	for uid in _lunges:
		var l: Dictionary = _lunges[uid]
		l.left -= delta * speed
		if l.left <= 0.0:
			done.append(uid)
	for uid in done:
		_lunges.erase(uid)


func _place_views() -> void:
	for uid in _pos:
		var v := _view.view_for(uid)
		if v == null:
			continue
		var p: Vector2 = _pos[uid]
		if _lunges.has(uid):
			var l: Dictionary = _lunges[uid]
			var amount: float = maxf(l.left, 0.0) / LUNGE_TIME
			p += l.dir * ATTACK_LUNGE * _view.tile_size * amount
		v.position = p
