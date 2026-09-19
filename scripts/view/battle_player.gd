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

## How long the Assassin is visibly wrapped in its cloak before it jumps. The
## simulation resolves the vanish and the strike in the same instant; this is the
## beat that lets a viewer read the order they happened in.
const CLOAK_BEAT := 0.22

@export var speed := 1.0

var _view: BoardView = null
var _units: Dictionary = {}
var _events: Array[Dictionary] = []
var _cursor := 0
var _clock := 0.0
var _playing := false
var _winner := CombatSim.RESULT_DRAW

## Where each unit is, in BOARD space — fractional tile coordinates, not pixels.
##
## This used to hold pixels, and that was the bug behind units jumping around
## when you zoomed: a pixel position is only meaningful at the tile_size it was
## worked out at, so the moment the board rescaled, every cached position in here
## was quietly describing somewhere else. Tiles do not care how big a tile is on
## screen, so nothing in here goes stale. _place_views() multiplies by the live
## tile_size once a frame and that is the only place pixels are involved.
var _pos: Dictionary = {}
var _hp: Dictionary = {}
var _moves: Dictionary = {}
var _lunges: Dictionary = {}
var _flight: Dictionary = {}
var _deferred: Array[Dictionary] = []
var _counts: Array[int] = [0, 0]

## Seconds the event cursor is pinned for while something that takes TIME on
## screen but no time in the simulation finishes happening.
##
## The simulation resolves a cloak-then-blink in a single instant: the Assassin is
## already behind its target and the damage is already dealt before the first frame is
## drawn, so playing it back honestly would show it reappear before it had vanished.
## Holding the cursor postpones EVERYTHING that follows, which is the only version of
## this that cannot desync — a per-event delay has to be plumbed into every kind of
## event the held moment might be followed by (damage, stun, death, the next cast) and
## silently gets it wrong for whichever one nobody remembered.
##
## The cost is that other units freeze for the length of the hold, which is acceptable
## because it is short and happens at the opening bell where nothing else has started.
##
## The Breaker's charge used to need this too and no longer does: the simulation now
## takes real seconds to cross the lane, so the damage genuinely arrives later in the
## log than the run did and there is nothing to paper over. If a hold is ever added
## back for a charge, it is a sign the travel time has been removed.
var _hold := 0.0


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
	_hold = 0.0
	_counts = [0, 0]
	# Last round's zones are not this round's. Cleared here rather than at the end
	# of playback, so the board still shows them during the round-end hold.
	view.clear_aura_zones()
	# From here the board must not place units from the model's cells; see
	# BoardView.playback.
	view.playback = true
	set_process(true)
	_announce_counts()


func stop() -> void:
	_playing = false
	if _view != null:
		_view.playback = false
	set_process(false)


func is_playing() -> bool:
	return _playing


func clock() -> float:
	# Battle time as the VIEWER is experiencing it, which is what a countdown on
	# screen has to count. The sim resolved the whole round before frame one, so
	# its own `elapsed` is already at the end and is no use here.
	return _clock


func _process(delta: float) -> void:
	if not _playing:
		return
	_clock += delta * speed

	if _hold > 0.0:
		# The clock keeps running so an in-flight charge or a cloak animates, but
		# nothing new is read off the log until the held moment is over.
		_hold -= delta * speed
	else:
		while _cursor < _events.size() and _events[_cursor].t <= _clock:
			_apply(_events[_cursor])
			_cursor += 1
			if _hold > 0.0:
				break

	_advance_moves()
	_advance_lunges(delta)
	_advance_deferred()
	_place_views()

	if (_cursor >= _events.size() and _moves.is_empty() and _deferred.is_empty()
			and _hold <= 0.0):
		_playing = false
		_view.playback = false
		set_process(false)
		finished.emit(_winner)


func _apply(e: Dictionary) -> void:
	match e.kind:
		"spawn":
			_pos[e.uid] = _board(e.cell)
			_hp[e.uid] = {cur = float(e.hp), max = float(e.max_hp)}
			var sv := _view.view_for(e.uid)
			if sv != null:
				sv.set_hp(float(e.hp), float(e.max_hp))
				sv.has_ability = bool(e.get("has_ability", false))
				sv.set_mana(0.0)
				# From the event, not zero: a unit can already be shielded at the bell.
				sv.set_shield(float(e.get("shield", 0.0)))
		"move":
			_moves[e.uid] = {
				from = _board(e.from),
				to = _board(e.to),
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
		"freeze":
			# Held for as long as the freeze lasts rather than the usual flash, so
			# the tile is readable the whole time the unit is missing its turns.
			var fv := _view.view_for(e.uid)
			if fv != null:
				fv.hold(UnitView.HELD_FROZEN, float(e.seconds) / maxf(speed, 0.01))
			_view.flash_cells([e.cell], Color(0.60, 0.82, 0.95, 0.50),
				maxf(float(e.seconds), 0.4))
			_view.spawn_label(_view.cell_to_pos(e.cell), "FROZEN",
				Color(0.66, 0.87, 1.00))
		"aura_zone":
			# Persistent, unlike every other overlay here: the Wellspring's reach is
			# on screen from its opening instacast until it dies, so this hands the
			# board a zone to keep rather than a flash to count down.
			_view.add_aura_zone(int(e.uid), int(e.get("radius", 1)), int(e.team))
		"thaw":
			var tv := _view.view_for(e.uid)
			if tv != null:
				tv.release(UnitView.HELD_FROZEN)
		"isolated":
			# Fired at the bell, before anything has moved, so the player finds out
			# whether their placement worked at the one moment they can still learn
			# from it. Cold grey-blue: this is not a buff being handed out, it is a
			# unit confirming it got the room it needed.
			_view.spawn_label(_view.cell_to_pos(e.cell), "ISOLATED",
				Color(0.72, 0.78, 0.90))
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
		"shell_away":
			# The shot leaves now and lands later, so the view shows the arc AND
			# marks the ground it is aimed at — the whole point of the flight time
			# is that you get to see where it will land and move.
			var away: Vector2 = _at(int(e.uid), e.from)
			_view.spawn_shot(away, _view.cell_to_pos(e.cell),
				float(e.flight) / maxf(speed, 0.01), true)
			var marked: Array[Vector2i] = []
			for c in e.get("cells", []):
				marked.append(c)
			_view.flash_cells(marked, Color(0.95, 0.55, 0.25, 0.30),
				float(e.flight) / maxf(speed, 0.01))
		"shell_land":
			var blast: Array[Vector2i] = []
			for c in e.get("cells", []):
				blast.append(c)
			_view.flash_cells(blast, Color(0.99, 0.72, 0.30, 0.60), 0.45)
			_view.spawn_label(_view.cell_to_pos(e.cell), "IMPACT",
				Color(0.99, 0.72, 0.30))
		"field_up":
			var lit: Array[Vector2i] = []
			for c in e.get("cells", []):
				lit.append(c)
			# Held for the field's whole life, so the burning ground stays visible
			# the entire time it is dangerous rather than blinking once.
			_view.flash_cells(lit, Color(0.92, 0.42, 0.20, 0.28),
				float(e.seconds) / maxf(speed, 0.01))
		"field_down":
			pass
		"charge":
			# The lane the charge is ABOUT to run, lit as a warning rather than as a
			# record of where it went. The simulation now takes real seconds to cross it
			# and chooses its victim on arrival, so this is the one moment where showing
			# the player the lane actually matters: anything standing in it has until the
			# runner arrives to be somewhere else.
			#
			# Held for the length of the whole run, worked out from the event, so the
			# warning is up for exactly as long as the threat is real.
			var lane: Array[Vector2i] = []
			for c in e.get("cells", []):
				lane.append(c)
			var warn := float(e.get("per_tile", 0.0)) * float(lane.size())
			_view.flash_cells(lane, Color(0.98, 0.62, 0.28, 0.42),
				maxf(warn / maxf(speed, 0.01), 0.45))
		"charge_step":
			# One tile of the run. Linear on purpose: a charge has no wind-up and no
			# settle, and easing each tile would make it look like it kept changing its
			# mind. No _hold anywhere here — the simulation's own timing is what keeps
			# the impact honest now, because the damage really does arrive later in the
			# log than the first step did.
			_moves[int(e.uid)] = {
				from = _board(e.from),
				to = _board(e.to),
				start = _clock,
				duration = maxf(float(e.get("duration", 0.0)) / maxf(speed, 0.01), 0.01),
				linear = true,
			}
		"charge_end":
			var cev := _view.view_for(int(e.uid))
			if cev != null:
				cev.queue_redraw()
			if bool(e.get("hit", false)):
				# The lunge sells the impact, pointed the way it was running.
				_lunges[int(e.uid)] = {
					dir = Vector2(e.get("dir", Vector2i.ZERO)), left = LUNGE_TIME}
		"possess":
			_possess(e)
		"husk":
			_husk(e)
		"shield_gone":
			# The bar has already been zeroed by the "shield" event that came with
			# this one; this is the feedback that says WHY it went, which matters
			# because a shield fizzling and a shield being chewed through look
			# identical on the bar.
			_view.spawn_label(_at(int(e.uid), e.cell), "SHIELD GONE",
				Color(0.70, 0.76, 0.86))
		"possess_end":
			# The grip ran out and the host is its owner's again. The bar and the
			# team ring both have to come back, and the health may have dropped: a
			# handed-back host loses the forced tier and the thief's buff with it.
			_hp[int(e.uid)] = {cur = float(e.hp), max = float(e.max_hp)}
			var rv := _view.view_for(int(e.uid))
			if rv != null:
				rv.set_hp(float(e.hp), float(e.max_hp))
				rv.possessed = false
				rv.queue_redraw()
			_view.spawn_label(_at(int(e.uid), e.cell), "FREED",
				Color(0.72, 0.88, 0.72))
		"backlash":
			_view.flash_cells([e.cell, e.target_cell],
				Color(0.58, 0.34, 0.72, 0.55), 0.5)
			_view.spawn_label(_at(int(e.uid), e.cell), "REJECTED",
				Color(0.72, 0.52, 0.88))
		"stun":
			var stv := _view.view_for(e.uid)
			if stv != null:
				# The mark on the UNIT, driven off the event and its duration. The
				# redraw that used to be here on its own did nothing: UnitView had
				# nothing to draw, and anything it read off the unit would have been
				# the unit's state at the END of the round.
				stv.hold(UnitView.HELD_STUNNED, float(e.seconds) / maxf(speed, 0.01))
			# Held for as long as the stun lasts, the same as the freeze tile, so the
			# whole time the unit is missing its turns is readable.
			_view.flash_cells([e.cell], Color(0.98, 0.82, 0.42, 0.42),
				maxf(float(e.seconds), 0.4))
			_view.spawn_label(_at(int(e.uid), e.cell), "STUNNED",
				Color(1.00, 0.86, 0.46))
		"stun_end":
			var ev2 := _view.view_for(e.uid)
			if ev2 != null:
				ev2.release(UnitView.HELD_STUNNED)
		"frenzy":
			# The Martyr hit zero and did not fall. Nothing else in the game leaves a
			# unit standing on an empty bar, so this needs to be unmistakable — and it
			# has to come off the event, because the unit's own frenzy_left is the
			# end-of-round value during playback.
			var fzv := _view.view_for(int(e.uid))
			if fzv != null:
				fzv.begin_frenzy(float(e.seconds) / maxf(speed, 0.01))
			_view.flash_cells([e.cell], Color(1.00, 0.28, 0.24, 0.50),
				maxf(float(e.seconds), 0.4))
			_view.spawn_label(_at(int(e.uid), e.cell), "NOTHING TO LOSE",
				Color(1.00, 0.44, 0.34))
		"disorient":
			var dzv := _view.view_for(int(e.uid))
			if dzv != null:
				dzv.begin_reeling(float(e.seconds) / maxf(speed, 0.01))
			_view.flash_cells([e.cell], Color(0.88, 0.80, 0.40, 0.40),
				maxf(float(e.seconds), 0.4))
			_view.spawn_label(_at(int(e.uid), e.cell), "LOST",
				Color(0.92, 0.86, 0.50))
		"disorient_end":
			var dev := _view.view_for(int(e.uid))
			if dev != null:
				dev.end_reeling()
		"frenzy_end":
			var fev := _view.view_for(int(e.uid))
			if fev != null:
				fev.end_frenzy()
		"cleanse":
			# Names what came off rather than saying "CLEANSE": a Seraph lifting a
			# freeze and a Seraph lifting a poison are different moments and the
			# player should be able to tell which one they just got.
			_view.spawn_label(_at(int(e.uid), e.cell),
				String(", ").join(e.get("removed", [])).to_upper(),
				Color(0.68, 0.94, 0.86))
		"drain_start":
			_view.spawn_label(_view.cell_to_pos(e.cell), "SIPHONED",
				Color(0.72, 0.42, 0.68))
		"drain_end":
			pass
		"harden":
			# The shield bar already moves off the "shield" event; this is the
			# feedback that says WHY it moved, which is the whole read on this
			# unit — you want to see it thickening as it is being pecked at.
			var kv := _view.view_for(e.uid)
			if kv != null:
				kv.set_shield(float(e.shield))
				kv.queue_redraw()
		"wall_hit":
			# Chips of stone, and a redraw so the wall visibly loses height. The
			# "terrain" event still follows on the blow that finishes it.
			_view.flash_cells([e.cell], Color(0.86, 0.72, 0.42, 0.35), 0.25)
			var hv := _view.view_for(e.uid)
			if hv != null:
				_lunges[e.uid] = {
					dir = (Vector2(e.cell) - Vector2(e.from)).normalized(),
					left = LUNGE_TIME,
				}
			_view.queue_redraw()
		"terrain":
			# The sim already changed BoardModel — this event exists so the view
			# knows to repaint and to flash the tiles, not to carry the change.
			var touched: Array[Vector2i] = []
			for c in e.get("broken", []):
				touched.append(c)
			if not touched.is_empty():
				_view.flash_cells(touched, Color(0.86, 0.72, 0.42, 0.60), 0.6)
			var built: Array[Vector2i] = []
			for c in e.get("raised", []):
				built.append(c)
			if not built.is_empty():
				_view.flash_cells(built, Color(0.62, 0.68, 0.78, 0.60), 0.6)
			_view.queue_redraw()
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
		"gate":
			# Put down at the far pad, not walked there. Both pads are lit so the link
			# is legible: a unit vanishing from one tile and appearing ten rows away
			# reads as a bug unless the board says where it went.
			_pos[e.uid] = _board(e.to)
			_moves.erase(e.uid)
			_view.flash_cells([e.from, e.to], Color(0.52, 0.82, 0.88, 0.55), 0.45)
			_view.spawn_label(_view.cell_to_pos(e.to), "THROUGH",
				Color(0.62, 0.90, 0.94))
		"blink":
			_pos[e.uid] = _board(e.to)
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
				_view.spawn_label(_at(int(e.uid), e.cell),
					"SPENT", Color(0.82, 0.74, 0.52))
			_schedule_death(e)
		"end":
			_winner = e.winner


func _board(cell: Vector2i) -> Vector2:
	## A cell as a board-space point: the middle of the tile, measured in tiles.
	return Vector2(cell.x + 0.5, cell.y + 0.5)


func _at(uid: int, fallback: Vector2i) -> Vector2:
	## Where a unit is on SCREEN right now, for a label or a projectile to be
	## anchored to. Live positions come from _pos; anything the playback has not
	## seen yet falls back to the cell the event names.
	var b: Vector2 = _pos.get(uid, _board(fallback))
	return b * _view.tile_size


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
	var from := _at(int(e.uid), e.from)
	var to := _at(int(e.target_uid), e.to)
	# In tiles directly, off the board-space positions, rather than by dividing
	# pixels back down by the tile size. Same number, one fewer thing to get
	# wrong when the tile size changes underneath it.
	var tiles: float = (_pos.get(e.uid, _board(e.from)) as Vector2).distance_to(
		_pos.get(e.target_uid, _board(e.to)) as Vector2)

	var shooter: UnitInstance = _units.get(e.uid, null)
	# On the SWING, not on the hit: a shot in flight should be heard leaving the
	# bow, and the crack of the hit is a separate sound a moment later.
	if shooter != null:
		Audio.play_attack(shooter.data.attack_type, shooter.data.beam_attack)
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
		_kill(e)
		return
	_deferred.append({due = _clock + delay, kind = "death", event = e})


func _show_ability(e: Dictionary) -> void:
	var at := _at(int(e.uid), e.cell)
	match int(e.kind):
		AbilityData.Kind.HASTE:
			_view.spawn_label(at, "CAST", Color(0.98, 0.85, 0.42))
		AbilityData.Kind.SHIELD:
			_view.spawn_label(at, "SHIELD", Color(0.53, 0.79, 0.92))
		AbilityData.Kind.DOT:
			if e.has("target_cell"):
				_view.spawn_shot(at, _view.cell_to_pos(e.target_cell), 0.18, true)
				_view.flash_cells([e.target_cell], Color(0.55, 0.85, 0.40, 0.45), 0.5)
		AbilityData.Kind.FREEZE:
			# The bolt only. The FROZEN label and the tile are drawn off the
			# "freeze" event below, which carries how long it actually lasted.
			if e.has("target_cell"):
				_view.spawn_shot(at, _view.cell_to_pos(e.target_cell), 0.14, true)
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
		AbilityData.Kind.SAP:
			if bool(e.get("wasted", false)):
				_view.spawn_label(at, "NO STONE", Color(0.62, 0.66, 0.74))
				return
			_view.spawn_label(at, "BREACH", Color(0.86, 0.72, 0.42))
		AbilityData.Kind.BUILD:
			if bool(e.get("wasted", false)):
				_view.spawn_label(at, "NO ROOM", Color(0.62, 0.66, 0.74))
				return
			_view.spawn_label(at, "EMPLACED", Color(0.70, 0.76, 0.86))
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
	var at := _at(int(e.uid), e.cell)
	var crit := bool(e.get("crit", false))
	if crit:
		Audio.play_crit()
	# Any part of the hit eaten by a shield, not just a hit fully absorbed. A
	# blow that chews through the last of a shield and carries on into health is
	# still a blow the shield answered, and hearing nothing there would make the
	# shield feel like it stopped working one hit early.
	if float(e.get("absorbed", 0.0)) > 0.0:
		Audio.play_shield_hit()
	_view.spawn_damage(at, float(e.amount), bool(e.get("spell", false)), crit)
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
	if not bool(e.on):
		return
	_view.spawn_label(_at(int(e.uid), e.get("cell", Vector2i.ZERO)), "VANISH",
		Color(0.68, 0.56, 0.88))
	# A beat on the vanish before the log moves on, which for an Assassin is the
	# blink that follows in the same instant. Without it the unit is already
	# behind its victim by the time the cloak is drawn.
	_hold = maxf(_hold, CLOAK_BEAT)


func _summon(e: Dictionary) -> void:
	var unit: UnitInstance = _units.get(e.uid, null)
	if unit == null:
		return
	var v := _view.ensure_view(unit)
	_pos[e.uid] = _board(e.cell)
	_hp[e.uid] = {cur = float(e.hp), max = float(e.max_hp)}
	if v == null:
		return
	v.position = _pos[e.uid] * _view.tile_size
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
	_pos[e.uid] = _board(e.cell)
	if v == null:
		return
	v.position = _pos[e.uid] * _view.tile_size
	v.begin_revive()
	_view.spawn_label(v.position, "RISING", Color(0.60, 0.88, 0.66))
	_view.flash_cells([e.cell], Color(0.45, 0.85, 0.55, 0.35), float(e.duration))


func _respawn(e: Dictionary) -> void:
	var unit: UnitInstance = _units.get(e.uid, null)
	_pos[e.uid] = _board(e.cell)
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
	v.position = _pos[e.uid] * _view.tile_size
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
		var at := _at(int(e.uid), e.cell)
		_view.spawn_label(at, "+%d" % roundi(float(e.amount)), Color(0.45, 0.82, 0.48))


func _kill(e: Dictionary) -> void:
	var uid := int(e.uid)
	# The zone belongs to the caster, so it goes when the caster does.
	_view.clear_aura_zone(uid)
	# Here rather than in _schedule_death, so the sound lands with the body and
	# not with the arrow leaving the bow. Both teams: the fog lifts when the
	# battle starts, so there is nothing left to give away.
	Audio.play_death()
	# On top of the thump, from the same moment. Which line depends on whether the
	# blow that landed was bigger than the unit's whole health bar — the sim
	# decided that when it dealt the damage and put the answer on the event,
	# because it is the only place that ever saw the number.
	Audio.play_death_voice(bool(e.get("overkill", false)))
	_view.kill_view(uid)
	_moves.erase(uid)
	_lunges.erase(uid)
	_flight.erase(uid)


func _possess(e: Dictionary) -> void:
	## The Usurper vanishes into its host and the host changes colour.
	##
	## drop_view rather than kill_view: it is not dead, and giving it the death
	## animation would tell the player it had been killed at the opening bell, which
	## is the opposite of what has happened.
	var uid := int(e.uid)
	_view.drop_view(uid)
	_pos.erase(uid)
	_moves.erase(uid)
	_lunges.erase(uid)
	_hp.erase(uid)

	var host_uid := int(e.host_uid)
	_hp[host_uid] = {cur = float(e.hp), max = float(e.max_hp)}
	var hv := _view.view_for(host_uid)
	if hv != null:
		# UnitView reads unit.team live when it draws, and the simulation has
		# already flipped it, so a repaint is the whole of the colour change.
		hv.set_hp(float(e.hp), float(e.max_hp))
		# The mark that says the body is on loan. Set from the EVENT and not from
		# host.is_possessed(), which during playback is the host's state at the end of the
		# round — so a host that was freed before the bell would never show it and one
		# still held would show it from frame one.
		hv.possessed = true
		hv.queue_redraw()
	var forced := int(e.get("forced_tier", 0))
	_view.spawn_label(_at(host_uid, e.host_cell),
		"TAKEN" if forced <= 0 else "TAKEN · T%d" % forced,
		Color(0.72, 0.52, 0.88))
	_view.flash_cells([e.cell, e.host_cell], Color(0.58, 0.34, 0.72, 0.45), 0.5)


func _husk(e: Dictionary) -> void:
	## Its puppet died under it and it is back on the board with one health.
	##
	## The other way a possession ends, and it has to clear the host's mark too — the host
	## is dead, but a revived one (a Revenant, a Vigil raising it) comes back as its
	## owner's again and must not come back still wearing the brackets.
	# The simulation calls it from_uid on this event — the body it fell OUT of.
	var host_uid := int(e.get("from_uid", -1))
	if host_uid >= 0:
		var freed := _view.view_for(host_uid)
		if freed != null:
			freed.possessed = false
			freed.queue_redraw()
	var uid := int(e.uid)
	var unit: UnitInstance = _units.get(uid, null)
	if unit == null:
		return
	_pos[uid] = _board(e.cell)
	_hp[uid] = {cur = 1.0, max = 1.0}
	var v := _view.ensure_view(unit)
	if v != null:
		v.set_hp(1.0, 1.0)
		v.set_shield(0.0)
		v.position = (_pos[uid] as Vector2) * _view.tile_size
		v.queue_redraw()
	_view.spawn_label(_view.cell_to_pos(e.cell), "HUSK", Color(0.66, 0.46, 0.80))


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
		match d.kind:
			"damage":
				_hit(d.event)
			"lunge":
				_lunges[d.uid] = {dir = d.dir, left = LUNGE_TIME}
			_:
				_kill(d.event)
				_flight.erase(d.event.uid)
		_deferred.remove_at(i)


func _advance_moves() -> void:
	var done: Array[int] = []
	for uid in _moves:
		var m: Dictionary = _moves[uid]
		var t: float = clampf((_clock - m.start) / m.duration, 0.0, 1.0)
		# A walk eases in and out of each tile; a charge does not — see the "charge_step"
		# arm of _apply, which sets linear.
		var shaped: float = t if bool(m.get("linear", false)) else t * t * (3.0 - 2.0 * t)
		_pos[uid] = m.from.lerp(m.to, shaped)
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
		var p: Vector2 = (_pos[uid] as Vector2) * _view.tile_size
		if _lunges.has(uid):
			var l: Dictionary = _lunges[uid]
			var amount: float = maxf(l.left, 0.0) / LUNGE_TIME
			p += l.dir * ATTACK_LUNGE * _view.tile_size * amount
		v.position = p
