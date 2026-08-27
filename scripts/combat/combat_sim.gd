## The battle, as pure data. Steps on a fixed tick, touches no nodes, and emits
## an event log the view replays afterwards.
##
## Why it's built this way:
##   * Fog of war is a filter over known truth, not something bolted onto the view.
##   * It runs headless, so you can play 5,000 battles in a few seconds to balance.
##   * Same seed -> same battle, exactly. Bugs are reproducible; PvP stays possible.
##
## Nothing in here may reference a Node, a Sprite, or the scene tree. If you find
## yourself wanting to, the thing you actually want is another event kind.
class_name CombatSim
extends RefCounted

## Ten steps a second. Plenty for a deliberate battle, and it means a whole round
## simulates instantly. Never drive combat off frame delta — a slow frame would
## change who wins.
const TICK := 0.1
const DEFAULT_TIMEOUT := 45.0

const RESULT_DRAW := -1

var board: BoardModel = null
var rng := RandomNumberGenerator.new()
var elapsed := 0.0
var events: Array[Dictionary] = []

var _units: Array[UnitInstance] = []  ## Stable uid order. Includes the dead.
var _order: Array[int] = []           ## Indices into _units, reshuffled each tick.
var _astar := AStarGrid2D.new()
var _finished := false
var _result := RESULT_DRAW


func setup(p_board: BoardModel, p_seed: int) -> void:
	board = p_board
	rng.seed = p_seed
	elapsed = 0.0
	events.clear()
	_finished = false
	_result = RESULT_DRAW

	_units = board.all_units()
	_order.clear()
	for i in _units.size():
		_order.append(i)
	for u in _units:
		u.reset_for_battle()
		_emit("spawn", {
			uid = u.uid, team = u.team, cell = u.cell,
			unit_id = u.data.id, tier = u.data.tier,
			hp = u.current_hp, max_hp = u.stat(StatModifier.Stat.MAX_HP),
			has_ability = u.data.ability != null,
		})

	_astar.region = Rect2i(0, 0, BoardModel.WIDTH, BoardModel.HEIGHT)
	_astar.cell_size = Vector2.ONE
	_astar.diagonal_mode = (AStarGrid2D.DIAGONAL_MODE_ALWAYS if BoardModel.DIAGONAL_MOVEMENT
			else AStarGrid2D.DIAGONAL_MODE_NEVER)
	_astar.default_compute_heuristic = AStarGrid2D.HEURISTIC_CHEBYSHEV
	_astar.default_estimate_heuristic = AStarGrid2D.HEURISTIC_CHEBYSHEV
	_astar.update()


## Runs to a conclusion. Returns the winning team, or RESULT_DRAW.
func run(timeout := DEFAULT_TIMEOUT) -> int:
	while not _finished and elapsed < timeout:
		step()
	if not _finished:
		_result = _decide_timeout()
		_finish("timeout")
	return _result


func step() -> void:
	if _finished:
		return
	_shuffle_order()
	_rebuild_solidity()
	for idx in _order:
		var u := _units[idx]
		if not u.is_alive():
			continue
		match u.state:
			UnitInstance.State.IDLE:
				_decide(u)
			UnitInstance.State.MOVING:
				_advance_timer(u)
			UnitInstance.State.ATTACKING:
				_advance_timer(u)
			UnitInstance.State.CASTING:
				_advance_cast(u)
	_tick_dots()
	elapsed += TICK
	_check_over()


## Units act in a fresh random order every tick, drawn from the seeded rng.
##
## Without this, a fixed uid order means whichever team was created first acts
## first on every single tick, and on a perfectly mirrored board that alone is
## worth a systematic win-rate edge. Seeded Fisher-Yates keeps the sim fully
## deterministic while removing the bias — so a lopsided mirror matchup once
## again means a real bug rather than turn-order luck.
func _shuffle_order() -> void:
	for i in range(_order.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var tmp := _order[i]
		_order[i] = _order[j]
		_order[j] = tmp


# ---------------------------------------------------------------- decisions

func _decide(u: UnitInstance) -> void:
	# The free opening cast fires before the unit has done anything, and before
	# it even needs a target — Warden's shield goes up as the battle starts.
	if not u.has_opened and u.data.casts_at_battle_start and u.data.ability != null:
		u.has_opened = true
		_begin_cast(u)
		return

	u.target = board.nearest_enemy(u)
	if u.target == null:
		return

	# A full bar takes priority over attacking. Casting locks the unit, so this
	# is a real cost, not a free bonus action.
	if u.mana_full():
		_begin_cast(u)
		return

	var dist := BoardModel.tile_distance(u.cell, u.target.cell)
	if dist <= u.stat_int(StatModifier.Stat.ATTACK_RANGE):
		_begin_attack(u)
	else:
		_begin_move(u)


## Commits to one tile step. The destination is reserved immediately so two units
## can never walk into the same tile — and the unit is locked out of attacking for
## the whole move_time. That lockout is the mechanic; don't shorten it here.
func _begin_move(u: UnitInstance) -> void:
	var next := _next_step(u)
	if next == u.cell:
		return  # Fully blocked this tick. Try again next tick.
	var from := u.cell
	if not board.move_unit(u, next):
		return
	u.move_from = from
	var dur := u.stat(StatModifier.Stat.MOVE_TIME)
	_enter(u, UnitInstance.State.MOVING, dur)
	_emit("move", {uid = u.uid, from = from, to = next, duration = dur})


func _begin_attack(u: UnitInstance) -> void:
	var victim := u.target
	var dmg := u.stat(StatModifier.Stat.ATTACK_DAMAGE)
	var cd := u.stat(StatModifier.Stat.ATTACK_COOLDOWN)
	_enter(u, UnitInstance.State.ATTACKING, cd)
	_emit("attack", {
		uid = u.uid, target_uid = victim.uid,
		from = u.cell, to = victim.cell, amount = dmg,
	})

	# The actual target always takes the hit, whatever the geometry.
	_damage(victim, dmg, u)

	# Passive pierce: Lancer's ordinary swing carries through the unit behind.
	var extra := maxi(u.data.pierce_targets, 1) - 1
	if extra > 0:
		for v in _pierce_beyond(u.cell, victim, extra, u.team):
			_damage(v, dmg, u)

	# Mana is earned by LANDING attacks, not by existing. A unit that can't
	# reach anything never charges.
	u.gain_mana(u.data.mana_per_attack)
	if u.data.ability != null:
		_emit("mana", {uid = u.uid, mana = u.mana})


## Enemies standing BEYOND `victim`, continuing the line from `origin` through it.
##
## Deliberately starts at the victim rather than at the attacker. Walking the
## whole line from the attacker looks equivalent but isn't: a shot at a target
## offset by, say, (3, 1) steps diagonally and never lands on the target's own
## tile, so the attacker would damage whoever happens to sit on the stepped line
## and miss the unit it was actually aiming at.
func _pierce_beyond(origin: Vector2i, victim: UnitInstance, count: int,
		team: int) -> Array[UnitInstance]:
	var out: Array[UnitInstance] = []
	var delta := victim.cell - origin
	var step := Vector2i(signi(delta.x), signi(delta.y))
	if step == Vector2i.ZERO:
		return out
	var c := victim.cell
	for i in count + 2:
		c += step
		if not board.in_bounds(c):
			break
		var v := board.unit_at(c)
		if v == null or not v.is_alive() or v.team == team:
			continue
		out.append(v)
		if out.size() >= count:
			break
	return out


## Locks the unit and starts the wind-up. The target is captured now so a cast
## can't silently re-aim at someone better while it resolves.
func _begin_cast(u: UnitInstance) -> void:
	var ab := u.data.ability
	u.spend_mana()
	_emit("mana", {uid = u.uid, mana = 0.0})
	u.pending_target_uid = u.target.uid if u.target != null else -1
	_enter(u, UnitInstance.State.CASTING, ab.cast_time)
	_emit("cast_start", {
		uid = u.uid, ability = ab.id, kind = ab.kind,
		centre = u.cell if u.target == null else u.target.cell,
		duration = ab.cast_time,
	})


func _advance_cast(u: UnitInstance) -> void:
	u.state_timer -= TICK
	if u.state_timer > 0.0:
		return
	u.state = UnitInstance.State.IDLE
	_resolve_ability(u)


## The one place abilities branch. Everything else in the sim is kind-agnostic.
func _resolve_ability(u: UnitInstance) -> void:
	var ab := u.data.ability
	if ab == null:
		return
	var target := _unit_by_uid(u.pending_target_uid)
	u.pending_target_uid = -1

	match ab.kind:
		AbilityData.Kind.HASTE:
			_resolve_haste(u, ab)
		AbilityData.Kind.SHIELD:
			_resolve_shield(u, ab)
		AbilityData.Kind.DOT:
			_resolve_dot(u, ab, target)
		AbilityData.Kind.FOCUS_BURST:
			_resolve_burst(u, ab, target)
		AbilityData.Kind.PIERCE:
			_resolve_pierce(u, ab, target)


func _resolve_haste(u: UnitInstance, ab: AbilityData) -> void:
	if u.haste_stacks >= ab.haste_max_stacks:
		_emit("ability", {uid = u.uid, ability = ab.id, kind = ab.kind,
			cell = u.cell, wasted = true})
		return
	u.haste_stacks += 1
	# A battle modifier, not a buff: haste must not survive into the next round.
	u.add_battle_modifier(StatModifier.make(
		StatModifier.Stat.ATTACK_COOLDOWN, StatModifier.Mode.PERCENT, -ab.haste_percent))
	_emit("ability", {uid = u.uid, ability = ab.id, kind = ab.kind,
		cell = u.cell, stacks = u.haste_stacks})


func _resolve_shield(u: UnitInstance, ab: AbilityData) -> void:
	u.add_shield(ab.shield_amount, ab.shield_cap)
	_emit("ability", {uid = u.uid, ability = ab.id, kind = ab.kind,
		cell = u.cell, shield = u.shield})
	_emit("shield", {uid = u.uid, shield = u.shield})


func _resolve_dot(u: UnitInstance, ab: AbilityData, target: UnitInstance) -> void:
	if target == null or not target.is_alive():
		return
	target.apply_dot(ab.dot_damage, ab.dot_ticks, ab.dot_interval, u.uid)
	_emit("ability", {uid = u.uid, ability = ab.id, kind = ab.kind,
		cell = u.cell, target_uid = target.uid, target_cell = target.cell})


## Pseudo-AoE: the main target takes the burst, anything near it takes a little.
## Unlike a flat area spell this rewards picking the right target, not just the
## biggest clump.
func _resolve_burst(u: UnitInstance, ab: AbilityData, target: UnitInstance) -> void:
	if target == null or not target.is_alive():
		return
	var centre := target.cell
	var splashed: Array[Vector2i] = []
	for dy in range(-ab.splash_radius, ab.splash_radius + 1):
		for dx in range(-ab.splash_radius, ab.splash_radius + 1):
			var c := centre + Vector2i(dx, dy)
			if board.in_bounds(c):
				splashed.append(c)
	_emit("ability", {uid = u.uid, ability = ab.id, kind = ab.kind,
		cell = u.cell, target_uid = target.uid, target_cell = centre,
		cells = splashed, amount = ab.burst_damage})

	for c in splashed:
		var v := board.unit_at(c)
		if v == null or not v.is_alive() or v.team == u.team:
			continue
		_damage(v, ab.burst_damage if v == target else ab.splash_damage, u, true)


func _resolve_pierce(u: UnitInstance, ab: AbilityData, target: UnitInstance) -> void:
	if target == null or not target.is_alive():
		return
	var dmg := u.stat(StatModifier.Stat.ATTACK_DAMAGE) * ab.pierce_damage_mult
	var victims: Array[UnitInstance] = [target]
	victims.append_array(_pierce_beyond(u.cell, target, maxi(ab.pierce_targets, 1) - 1, u.team))
	var cells: Array[Vector2i] = []
	for v in victims:
		cells.append(v.cell)
	_emit("ability", {uid = u.uid, ability = ab.id, kind = ab.kind,
		cell = u.cell, target_cell = target.cell, cells = cells, amount = dmg})
	for v in victims:
		_damage(v, dmg, u, true)


func _unit_by_uid(uid: int) -> UnitInstance:
	if uid < 0:
		return null
	for v in _units:
		if v.uid == uid:
			return v
	return null


## Ticks poison on every unit carrying it. Damage-over-time is the one thing that
## kills without anybody attacking, so it runs from the main loop, not a unit's turn.
func _tick_dots() -> void:
	for u in _units:
		if not u.is_alive() or u.dots.is_empty():
			continue
		var i := u.dots.size() - 1
		while i >= 0:
			var d: Dictionary = u.dots[i]
			d.timer -= TICK
			if d.timer <= 0.0:
				d.timer += d.interval
				d.ticks_left -= 1
				var src := _unit_by_uid(d.source_uid)
				_damage(u, d.dmg, src if src != null else u, true)
			if d.ticks_left <= 0:
				u.dots.remove_at(i)
			i -= 1


# ---------------------------------------------------------------- resolution

func _damage(victim: UnitInstance, amount: float, source: UnitInstance,
		is_spell := false) -> void:
	if not victim.is_alive():
		return
	victim.take_damage(amount)
	_emit("damage", {
		uid = victim.uid, source_uid = source.uid,
		amount = amount, hp = victim.current_hp, shield = victim.shield,
		cell = victim.cell, spell = is_spell,
	})
	if not victim.is_alive():
		_emit("death", {uid = victim.uid, cell = victim.cell, killer_uid = source.uid})
		board.remove(victim)


func _enter(u: UnitInstance, s: UnitInstance.State, duration: float) -> void:
	u.state = s
	u.state_timer = duration


func _advance_timer(u: UnitInstance) -> void:
	u.state_timer -= TICK
	if u.state_timer <= 0.0:
		u.state = UnitInstance.State.IDLE


# ---------------------------------------------------------------- pathing

## Occupancy for the whole board, refreshed once per tick.
##
## This used to run per unit per tick — 66 writes x 60 units x 450 ticks was the
## single largest cost in a big battle. Units only move on their own turn, so the
## two cells that can be stale are the mover's own and its goal, and _next_step()
## patches exactly those before pathing.
func _rebuild_solidity() -> void:
	for y in BoardModel.HEIGHT:
		for x in BoardModel.WIDTH:
			var c := Vector2i(x, y)
			_astar.set_point_solid(c, board.unit_at(c) != null)


## One tile toward the target.
func _next_step(u: UnitInstance) -> Vector2i:
	var goal := u.target.cell
	# Endpoints must be traversable or A* refuses to path at all.
	_astar.set_point_solid(u.cell, false)
	_astar.set_point_solid(goal, false)
	var path := _astar.get_id_path(u.cell, goal)
	_astar.set_point_solid(u.cell, true)
	_astar.set_point_solid(goal, true)

	if path.size() >= 2 and board.is_empty(path[1]):
		return path[1]
	return _greedy_step(u, goal)


## Fallback when A* is fully blocked: shuffle one tile closer if any is free.
func _greedy_step(u: UnitInstance, goal: Vector2i) -> Vector2i:
	var best := u.cell
	var best_d := BoardModel.tile_distance(u.cell, goal)
	for off in _neighbour_offsets():
		var c := u.cell + off
		if not board.is_empty(c):
			continue
		var d := BoardModel.tile_distance(c, goal)
		if d < best_d:
			best_d = d
			best = c
	return best


func _neighbour_offsets() -> Array[Vector2i]:
	if BoardModel.DIAGONAL_MOVEMENT:
		return [
			Vector2i(0, -1), Vector2i(1, -1), Vector2i(1, 0), Vector2i(1, 1),
			Vector2i(0, 1), Vector2i(-1, 1), Vector2i(-1, 0), Vector2i(-1, -1),
		]
	return [Vector2i(0, -1), Vector2i(1, 0), Vector2i(0, 1), Vector2i(-1, 0)]


# ---------------------------------------------------------------- end state

func _check_over() -> void:
	var a := board.living_count_of(BoardModel.TEAM_A)
	var b := board.living_count_of(BoardModel.TEAM_B)
	if a > 0 and b > 0:
		return
	if a == 0 and b == 0:
		_result = RESULT_DRAW
	else:
		_result = BoardModel.TEAM_A if a > 0 else BoardModel.TEAM_B
	_finish("wipe")


## A stalled battle is decided on remaining health fraction, not unit count —
## otherwise a lone full-HP tank loses to four slivers.
func _decide_timeout() -> int:
	var frac := [0.0, 0.0]
	for team in 2:
		for u in board.living_units_of(team):
			frac[team] += u.effective_hp() / maxf(u.stat(StatModifier.Stat.MAX_HP), 1.0)
	if is_equal_approx(frac[0], frac[1]):
		return RESULT_DRAW
	return BoardModel.TEAM_A if frac[0] > frac[1] else BoardModel.TEAM_B


func _finish(reason: String) -> void:
	_finished = true
	# UnitInstances point at each other through `target`; left set, those cycles
	# keep every unit of every past battle alive for the whole session.
	for u in _units:
		u.target = null
	_emit("end", {winner = _result, reason = reason})


func _emit(kind: String, payload: Dictionary) -> void:
	payload["t"] = elapsed
	payload["kind"] = kind
	events.append(payload)


func is_finished() -> bool:
	return _finished


func result() -> int:
	return _result


func duration() -> float:
	return elapsed
