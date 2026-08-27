## Replays a finished battle from the sim's event log.
##
## The fight is over before this runs — the sim decided everything in a fraction
## of a millisecond. This walks a clock forward and animates what the log says
## happened, so playback speed can never change the outcome.
##
## THE RULE: this class owns the replayed position and health of every unit, in
## _pos and _hp. It must never read cell or current_hp off a UnitInstance. Those
## hold END-OF-BATTLE values during a replay, so reading them live made units
## teleport to their final tile whenever they attacked, and showed every health
## bar at its final value from the first frame.
class_name BattlePlayer
extends Node

signal finished(winner: int)

const ATTACK_LUNGE := 0.22   ## Fraction of a tile the attacker leans in.
const LUNGE_TIME := 0.14

## Seconds a projectile takes per tile travelled. Anything further than
## MELEE_REACH tiles is treated as a shot and gets travel time.
const FLIGHT_PER_TILE := 0.07
const MELEE_REACH := 1.5

@export var speed := 1.0

var _view: BoardView = null
var _events: Array[Dictionary] = []
var _cursor := 0
var _clock := 0.0
var _playing := false
var _winner := CombatSim.RESULT_DRAW

var _pos: Dictionary = {}       ## uid -> Vector2, the replayed position
var _hp: Dictionary = {}        ## uid -> {cur, max}
var _moves: Dictionary = {}     ## uid -> {from, to, start, duration}
var _lunges: Dictionary = {}    ## uid -> {dir, left}
var _flight: Dictionary = {}    ## uid -> seconds until the shot aimed at it lands
var _deferred: Array[Dictionary] = []  ## visual effects waiting on a projectile


func play(view: BoardView, events: Array[Dictionary]) -> void:
	_view = view
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
	set_process(true)


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


# ---------------------------------------------------------------- events

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
			_view.flash_cells([e.centre], Color(0.85, 0.55, 0.25, 0.30), float(e.duration))
		"cast_resolve":
			var cells: Array[Vector2i] = []
			for c in e.cells:
				cells.append(c)
			_view.flash_cells(cells, Color(0.95, 0.65, 0.30, 0.55), 0.35)
		"death":
			_schedule_death(e)
		"end":
			_winner = e.winner


## A swing lunges; a shot launches a projectile and takes time to arrive.
func _begin_attack(e: Dictionary) -> void:
	var from: Vector2 = _pos.get(e.uid, _view.cell_to_pos(e.from))
	var to: Vector2 = _pos.get(e.target_uid, _view.cell_to_pos(e.to))
	var tiles := from.distance_to(to) / maxf(_view.tile_size, 1.0)

	if tiles <= MELEE_REACH:
		_lunges[e.uid] = {dir = (to - from).normalized(), left = LUNGE_TIME}
		return

	var flight := tiles * FLIGHT_PER_TILE
	_flight[e.target_uid] = maxf(_flight.get(e.target_uid, 0.0), flight)
	_view.spawn_shot(from, to, flight / maxf(speed, 0.01), false)


## Damage lands when the projectile does. Without this the health bar drops and
## the number pops before the arrow has left the bow.
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


## Ability feedback. Each kind gets its own read so you can tell at a glance
## which one just went off without reading a log.
func _show_ability(e: Dictionary) -> void:
	var at: Vector2 = _pos.get(e.uid, _view.cell_to_pos(e.cell))
	match int(e.kind):
		AbilityData.Kind.HASTE:
			_view.spawn_label(at, "HASTE", Color(0.98, 0.85, 0.42))
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


func _hit(e: Dictionary) -> void:
	_hp[e.uid] = {cur = float(e.hp), max = float(_hp.get(e.uid, {}).get("max", 1.0))}
	var v := _view.view_for(e.uid)
	var at: Vector2 = _pos.get(e.uid, _view.cell_to_pos(e.cell))
	_view.spawn_damage(at, float(e.amount), bool(e.get("spell", false)))
	if v != null:
		v.set_hp(float(e.hp), v.hp_max)
		v.set_shield(float(e.get("shield", 0.0)))
		v.hit()


func _kill(uid: int) -> void:
	_view.kill_view(uid)
	_moves.erase(uid)
	_lunges.erase(uid)
	_flight.erase(uid)


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


# ---------------------------------------------------------------- motion

func _advance_moves() -> void:
	var done: Array[int] = []
	for uid in _moves:
		var m: Dictionary = _moves[uid]
		var t: float = clampf((_clock - m.start) / m.duration, 0.0, 1.0)
		# Ease-in-out: the commitment reads as weight, not a glide.
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


## Positions come from _pos, plus a transient lunge offset. Nothing here reads
## the model — see the note at the top of the file.
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
