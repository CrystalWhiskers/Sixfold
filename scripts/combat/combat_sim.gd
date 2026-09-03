class_name CombatSim
extends RefCounted

const TICK := 0.1
const DEFAULT_TIMEOUT := 90.0

const RESULT_DRAW := -1

const DISPLACE_TIME := 0.12

const REGEN_INTERVAL := 1.0

# Two tier-1 Wardens carry 275 points of shield each and deal about 12 a second,
# so left alone they cannot finish each other inside the timeout. After this many
# seconds every hit lands harder, and keeps growing, until somebody falls over.
const SUDDEN_DEATH := 30.0
const PRESSURE_RATE := 0.15

var team_buffs: Dictionary = {}

var board: BoardModel = null
var rng := RandomNumberGenerator.new()
var elapsed := 0.0
var events: Array[Dictionary] = []

var _units: Array[UnitInstance] = []
var _order: Array[int] = []
var _finished := false
var _result := RESULT_DRAW
var _regen: Array[float] = [0.0, 0.0]
var _hp_damage: Array[float] = [0.0, 0.0]
var _regen_timer := 0.0
var _respawns: Array[Dictionary] = []
var _pending_units: Array[UnitInstance] = []
var _team_battle_mods: Dictionary = {}
var _mana_auras: Array[int] = []
var _recruits: Array[Dictionary] = []
var _start_count: Array[int] = [0, 0]
var _recruited: Array[int] = [0, 0]
var _sudden_death := false
var _last_counts: Array[int] = [-1, -1]


func setup(p_board: BoardModel, p_seed: int) -> void:
	board = p_board
	rng.seed = p_seed
	elapsed = 0.0
	events.clear()
	_finished = false
	_result = RESULT_DRAW

	_units = board.all_units()
	_respawns.clear()
	_pending_units.clear()
	_mana_auras.clear()
	_recruits.clear()
	_start_count = [0, 0]
	_recruited = [0, 0]
	_sudden_death = false
	_last_counts = [-1, -1]
	for u in _units:
		_start_count[u.team] += 1
	_order.clear()
	for i in _units.size():
		_order.append(i)
	for u in _units:
		u.reset_for_battle()
	_apply_battle_buffs()
	for u in _units:
		_emit("spawn", {
			uid = u.uid, team = u.team, cell = u.cell,
			unit_id = u.data.id, tier = u.data.tier,
			hp = u.current_hp, max_hp = u.stat(StatModifier.Stat.MAX_HP),
			has_ability = u.data.ability != null,
		})

	_resolve_openers()
	_tick_counts()


func living_count(team: int) -> int:
	# What the board would look like to a spectator: everything standing, plus
	# anything mid-revive, because the round is not over while it is getting up.
	var n := 0
	for u in _units:
		if u.team == team and u.is_alive():
			n += 1
	return n + pending_respawns(team)


func _tick_counts() -> void:
	# The simulation knows exactly who is standing, so it says so. Rebuilding
	# this from births and deaths in the view drifts the moment one is deferred.
	var a := living_count(BoardModel.TEAM_A)
	var b := living_count(BoardModel.TEAM_B)
	if a == _last_counts[0] and b == _last_counts[1]:
		return
	_last_counts = [a, b]
	_emit("counts", {a = a, b = b})


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
	_tick_regen()
	_tick_pressure()
	_tick_stealth()
	_tick_respawns()
	_absorb_new_units()
	elapsed += TICK
	_tick_counts()
	_check_over()


func _apply_battle_buffs() -> void:
	_regen = [0.0, 0.0]
	_hp_damage = [0.0, 0.0]
	_regen_timer = 0.0
	_team_battle_mods.clear()
	for team in [BoardModel.TEAM_A, BoardModel.TEAM_B]:
		var tb: TeamBuffs = team_buffs.get(team, null)
		if tb == null:
			continue
		_regen[team] = tb.regen_fraction()
		_hp_damage[team] = tb.hp_damage_fraction()
		var mods := tb.full_roster_modifiers()
		if mods.is_empty() or not _has_full_roster(team):
			continue
		_team_battle_mods[team] = mods
		for u in _units:
			if u.team != team:
				continue
			for m in mods:
				u.add_battle_modifier(m)
			u.heal_to_full()


func _has_full_roster(team: int) -> bool:
	var kinds := {}
	for u in _units:
		if u.team == team and u.is_alive():
			kinds[u.data.id] = true
	return kinds.size() >= TeamBuffs.FULL_ROSTER_TYPES


func pressure() -> float:
	if elapsed <= SUDDEN_DEATH:
		return 1.0
	return 1.0 + (elapsed - SUDDEN_DEATH) * PRESSURE_RATE


func _tick_pressure() -> void:
	if _sudden_death or elapsed <= SUDDEN_DEATH:
		return
	_sudden_death = true
	_emit("sudden_death", {at = elapsed})


func _tick_regen() -> void:
	_regen_timer += TICK
	if _regen_timer < REGEN_INTERVAL:
		return
	_regen_timer -= REGEN_INTERVAL
	_tick_mana_regen()
	_tick_mana_auras()
	if _regen[0] <= 0.0 and _regen[1] <= 0.0:
		return
	for u in _units:
		if not u.is_alive():
			continue
		var frac: float = _regen[u.team]
		if frac <= 0.0:
			continue
		var before := u.current_hp
		u.heal(u.stat(StatModifier.Stat.MAX_HP) * frac)
		if u.current_hp > before:
			_emit("heal", {
				uid = u.uid, amount = u.current_hp - before,
				hp = u.current_hp, cell = u.cell,
			})


func _resolve_openers() -> void:
	for u in _units:
		if not u.is_alive() or u.has_opened:
			continue
		if u.data.ability == null or not u.data.casts_at_battle_start:
			continue
		_open_now(u)
	_absorb_new_units()


func _open_now(u: UnitInstance, aim := false) -> void:
	# An instant cast: no wind-up in the simulation, though the view still shows
	# one. A caster that spends itself is never opened this way — a raised Spire
	# raising more Spires would run away with the whole board.
	var ab := u.data.ability
	if ab == null or ab.consumes_caster:
		return
	u.has_opened = true
	u.spend_mana()
	u.pending_target_uid = -1
	if aim:
		var mark := board.nearest_enemy(u)
		u.pending_target_uid = mark.uid if mark != null else -1
	_emit("cast_start", {
		uid = u.uid, ability = ab.id, name = ab.display_name, kind = ab.kind,
		centre = u.cell, duration = 0.0, opener = true,
		guarded = ab.guards_caster,
	})
	_resolve_ability(u)


func _shuffle_order() -> void:
	for i in range(_order.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var tmp := _order[i]
		_order[i] = _order[j]
		_order[j] = tmp


func _decide(u: UnitInstance) -> void:
	u.target = board.nearest_enemy(u)
	if u.mana_full():
		# Deliberately not gated on whether the cast can land. A Spire that fills
		# its bar with no room for the host burns it — that is the pressure to
		# merge before it is ready, not a bug.
		_begin_cast(u)
		return
	if u.target == null or not u.can_act():
		return

	var dist := BoardModel.tile_distance(u.cell, u.target.cell)
	if dist <= u.reach_on(BoardModel.is_high(u.cell)) and _has_shot(u, u.target):
		if u.data.can_attack:
			_begin_attack(u)
		return
	# In range but behind a wall: close in until there is a shot. Targeting is
	# deliberately not gated on sight, or a unit with no clear shot would stand
	# there with nothing to walk towards.
	if u.data.can_move:
		_begin_move(u)


func _has_shot(u: UnitInstance, target: UnitInstance) -> bool:
	# Only things that shoot need a clear line. A melee unit is standing next to
	# whatever it is hitting, so there is never a wall in the way anyway.
	if not u.is_ranged():
		return true
	return BoardModel.line_of_fire(u.cell, target.cell)


func _begin_move(u: UnitInstance) -> void:
	var next := _next_step(u)
	if next == u.cell:
		return
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
	var cd := u.attack_interval()
	_enter(u, UnitInstance.State.ATTACKING, cd)
	_emit("attack", {
		uid = u.uid, target_uid = victim.uid,
		from = u.cell, to = victim.cell, amount = dmg,
	})

	_damage(victim, dmg, u)

	var struck := {victim.uid: true}
	var extra := maxi(u.data.pierce_targets, 1) - 1
	if extra > 0:
		for v in _pierce_beyond(u.cell, victim, extra, u.team):
			struck[v.uid] = true
			_damage(v, dmg, u)

	if u.data.beam_attack and u.data.beam_splash > 0.0:
		_beam_wash(u, victim, dmg, struck)

	u.gain_mana(u.data.mana_per_attack)
	if u.data.ability != null:
		_emit("mana", {uid = u.uid, mana = u.mana})


func beam_cells(from: Vector2i, toward: Vector2i) -> Array[Vector2i]:
	# The line the beam travels, from the shooter to the far edge of the board.
	var out: Array[Vector2i] = []
	var step := Vector2i(signi(toward.x - from.x), signi(toward.y - from.y))
	if step == Vector2i.ZERO:
		return out
	var c := from + step
	while board.in_bounds(c) and not BoardModel.blocks_sight(c):
		out.append(c)
		c += step
	return out


func _beam_wash(u: UnitInstance, victim: UnitInstance, dmg: float,
		struck: Dictionary) -> void:
	var line := beam_cells(u.cell, victim.cell)
	if line.is_empty():
		return
	var washed: Array[Vector2i] = []
	var caught: Array[UnitInstance] = []
	var seen := {}
	for c in line:
		for dy in range(-1, 2):
			for dx in range(-1, 2):
				var n := c + Vector2i(dx, dy)
				if not board.in_bounds(n) or seen.has(n):
					continue
				seen[n] = true
				washed.append(n)
				var v := board.unit_at(n)
				if v == null or v.team == u.team or not v.is_alive():
					continue
				if struck.has(v.uid):
					continue
				struck[v.uid] = true
				caught.append(v)

	_emit("beam", {
		uid = u.uid, from = u.cell, cells = line, washed = washed,
		team = u.team,
	})
	if u.data.beam_splash <= 0.0:
		return
	for v in caught:
		_damage(v, dmg * u.data.beam_splash, u, true)


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
		if not board.in_bounds(c) or BoardModel.blocks_sight(c):
			break
		var v := board.unit_at(c)
		if v == null or not v.is_alive() or v.team == team:
			continue
		out.append(v)
		if out.size() >= count:
			break
	return out


func _begin_cast(u: UnitInstance) -> void:
	var ab := u.data.ability
	u.spend_mana()
	_emit("mana", {uid = u.uid, mana = 0.0})
	u.pending_target_uid = u.target.uid if u.target != null else -1
	_enter(u, UnitInstance.State.CASTING, ab.cast_time)
	_emit("cast_start", {
		uid = u.uid, ability = ab.id, name = ab.display_name, kind = ab.kind,
		centre = u.cell if u.target == null else u.target.cell,
		duration = ab.cast_time, opener = false, guarded = ab.guards_caster,
	})


func _advance_cast(u: UnitInstance) -> void:
	u.state_timer -= TICK
	if u.state_timer > 0.0:
		return
	u.state = UnitInstance.State.IDLE
	_resolve_ability(u)


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
		AbilityData.Kind.BLINK_STRIKE:
			_resolve_blink(u, ab, target)
		AbilityData.Kind.SPEED_AURA:
			_resolve_aura(u, ab)
		AbilityData.Kind.REVIVE:
			_emit("ability", {uid = u.uid, ability = ab.id, kind = ab.kind,
				cell = u.cell, wasted = true})
		AbilityData.Kind.BURST_HEAL:
			_resolve_burst_heal(u, ab)
		AbilityData.Kind.SUMMON:
			_resolve_summon(u, ab)
		AbilityData.Kind.MANA_AURA:
			_resolve_mana_aura(u, ab)


func _resolve_blink(u: UnitInstance, ab: AbilityData, target: UnitInstance) -> void:
	var victim := _backline_enemy(u)
	if victim == null:
		victim = target if target != null and target.is_alive() else board.nearest_enemy(u)
	if victim == null:
		_emit("ability", {uid = u.uid, ability = ab.id, kind = ab.kind,
			cell = u.cell, wasted = true})
		return

	var landing := _behind_cell(u, victim)
	var from := u.cell
	if landing != u.cell and board.teleport(u, landing):
		_emit("blink", {uid = u.uid, from = from, to = landing})

	var dmg := ab.blink_base_damage * pow(2.0, float(u.data.tier - 1))
	_emit("ability", {uid = u.uid, ability = ab.id, kind = ab.kind,
		cell = u.cell, target_cell = victim.cell, amount = dmg})
	_damage(victim, dmg, u, true)

	u.stealth_left = ab.stealth_time
	_emit("stealth", {uid = u.uid, on = true, duration = ab.stealth_time})


func _backline_enemy(u: UnitInstance) -> UnitInstance:
	var deepest: UnitInstance = null
	var best := -1
	for other in board.units_view():
		if not other.is_alive() or other.team == u.team or other.is_hidden():
			continue
		var depth: int = (BoardModel.HEIGHT - 1 - other.cell.y
			if u.team == BoardModel.TEAM_B else other.cell.y)
		if depth > best or (depth == best and deepest != null and other.uid < deepest.uid):
			deepest = other
			best = depth
	return deepest


func _behind_cell(u: UnitInstance, victim: UnitInstance) -> Vector2i:
	var facing := Vector2i(0, -1) if u.team == BoardModel.TEAM_B else Vector2i(0, 1)
	var wanted := victim.cell + facing
	if board.in_bounds(wanted) and board.is_empty(wanted):
		return wanted
	return _free_cell_near(victim.cell, u.cell)


func _any_free_cell(centre: Vector2i, fallback: Vector2i) -> Vector2i:
	# A unit coming back from the dead has to land somewhere. Searching only the
	# ring around it loses the unit outright on a busy board.
	var free := BoardModel.by_distance_to(board.free_cells(), centre)
	return fallback if free.is_empty() else free[0]


func _free_cell_near(centre: Vector2i, fallback: Vector2i) -> Vector2i:
	var best := fallback
	var best_d := 1 << 30
	for dy in range(-1, 2):
		for dx in range(-1, 2):
			var c := centre + Vector2i(dx, dy)
			if not board.in_bounds(c) or not board.is_empty(c):
				continue
			var d := BoardModel.tile_distance(c, centre)
			if d < best_d:
				best = c
				best_d = d
	return best


func _resolve_aura(u: UnitInstance, ab: AbilityData) -> void:
	var pct := (ab.aura_percent_per_tier * float(u.data.tier)
		* u.stat(StatModifier.Stat.AURA_POWER))
	var cells: Array[Vector2i] = []
	for ally in board.units_in_range(u.cell, ab.aura_radius, u.team):
		if ally == u or not ally.is_alive():
			continue
		ally.add_battle_modifier(StatModifier.make(
			StatModifier.Stat.ATTACK_SPEED, StatModifier.Mode.PERCENT, pct))
		cells.append(ally.cell)
	_emit("ability", {uid = u.uid, ability = ab.id, kind = ab.kind,
		cell = u.cell, cells = cells, percent = pct, wasted = cells.is_empty()})


func _resolve_burst_heal(u: UnitInstance, ab: AbilityData) -> void:
	var patient := _worst_hurt_ally(u, ab.heal_radius)
	if patient == null:
		_emit("ability", {uid = u.uid, ability = ab.id, kind = ab.kind,
			cell = u.cell, wasted = true})
		return

	var before := patient.current_hp
	patient.heal(patient.stat(StatModifier.Stat.MAX_HP) * heal_fraction(u, ab)
		* u.stat(StatModifier.Stat.HEAL_POWER))
	if patient.current_hp > before:
		_emit("heal", {
			uid = patient.uid, amount = patient.current_hp - before,
			hp = patient.current_hp, cell = patient.cell,
		})
	_emit("ability", {uid = u.uid, ability = ab.id, kind = ab.kind,
		cell = u.cell, target_cell = patient.cell,
		cells = [patient.cell] as Array[Vector2i]})


static func heal_fraction(u: UnitInstance, ab: AbilityData) -> float:
	return ab.heal_percent * (1.0
		+ ab.heal_percent_per_tier * float(u.data.tier - 1))


func _worst_hurt_ally(u: UnitInstance, radius: int) -> UnitInstance:
	var best: UnitInstance = null
	var worst := 2.0
	for ally in board.units_in_range(u.cell, radius, u.team):
		if not ally.is_alive():
			continue
		var frac := ally.current_hp / maxf(ally.stat(StatModifier.Stat.MAX_HP), 1.0)
		if frac >= 1.0:
			continue
		if frac < worst or (is_equal_approx(frac, worst) and best != null
				and ally.uid < best.uid):
			best = ally
			worst = frac
	return best


func summon_cap(u: UnitInstance, ab: AbilityData) -> int:
	if not ab.summon_cap_by_tier:
		return maxi(ab.summon_max, 1)
	return clampi((u.data.tier + 1) / 2, 1, maxi(ab.summon_max, 1))


func _resolve_mana_aura(u: UnitInstance, ab: AbilityData) -> void:
	if not _mana_auras.has(u.uid):
		_mana_auras.append(u.uid)
	var cells: Array[Vector2i] = []
	for dy in range(-ab.mana_aura_radius, ab.mana_aura_radius + 1):
		for dx in range(-ab.mana_aura_radius, ab.mana_aura_radius + 1):
			var c := u.cell + Vector2i(dx, dy)
			if board.in_bounds(c):
				cells.append(c)
	_emit("ability", {uid = u.uid, ability = ab.id, kind = ab.kind,
		cell = u.cell, cells = cells, radius = ab.mana_aura_radius})
	_emit("aura_zone", {uid = u.uid, cells = cells, team = u.team})


func _summon_shape(u: UnitInstance, ab: AbilityData) -> UnitData:
	if not ab.summon_random:
		return BoardModel.at_tier(ab.summon_unit, u.data.tier)
	var pool := board.pool_for(u.team)
	if pool.is_empty():
		return null
	var pick: UnitData = pool[rng.randi_range(0, pool.size() - 1)]
	return BoardModel.at_tier(pick, u.data.tier)


func _resolve_summon(u: UnitInstance, ab: AbilityData) -> void:
	var cap := summon_cap(u, ab)
	var want := mini(maxi(ab.summon_count, 1), maxi(cap - u.summons_made, 0))
	if want <= 0:
		_wasted_summon(u, ab, "capped")
		return

	# All or nothing. A half-placed summon means the caster spent a full bar and
	# some of what it paid for silently never existed.
	if ab.summon_persists and persist_room(u.team) < want:
		_wasted_summon(u, ab, "no_home")
		return
	var cells: Array[Vector2i] = _summon_cells(u, ab, want)
	if cells.is_empty():
		_wasted_summon(u, ab, "no_room")
		return

	var made: Array[Vector2i] = []
	var raised_now: Array[UnitInstance] = []
	for cell in cells:
		var shape := _summon_shape(u, ab)
		if shape == null:
			break
		var minion := UnitInstance.create(shape, u.team)
		var tb: TeamBuffs = team_buffs.get(u.team, null)
		if tb != null:
			tb.apply_to(minion)
		if not board.force_place(minion, cell):
			break
		minion.current_hp = minion.stat(StatModifier.Stat.MAX_HP)
		minion.permanent = ab.summon_persists
		u.summons_made += 1
		_pending_units.append(minion)
		raised_now.append(minion)
		made.append(cell)
		if minion.permanent:
			_recruited[u.team] += 1
			_recruits.append({unit = minion, owner_uid = u.uid})
		_emit("summon", {
			uid = minion.uid, owner_uid = u.uid, team = minion.team, cell = cell,
			unit_id = minion.data.id, tier = minion.data.tier,
			hp = minion.current_hp, max_hp = minion.stat(StatModifier.Stat.MAX_HP),
			has_ability = minion.data.ability != null,
			permanent = minion.permanent,
		})

	if made.is_empty():
		_wasted_summon(u, ab, "no_room")
		return
	_emit("ability", {uid = u.uid, ability = ab.id, kind = ab.kind,
		cell = u.cell, cells = made})
	if ab.summon_instacasts:
		for raised in raised_now:
			if raised.is_alive():
				_open_now(raised, true)
	if ab.consumes_caster:
		_consume_caster(u)


func _consume_caster(u: UnitInstance) -> void:
	# Not a kill: no killer, no lifesteal, and deliberately no revive roll. The
	# unit spent itself, and `consumed` keeps it out of next round's roster.
	u.consumed = true
	u.current_hp = 0.0
	var where := u.cell
	board.remove(u)
	_emit("death", {uid = u.uid, cell = where, killer_uid = -1, consumed = true})


func _wasted_summon(u: UnitInstance, ab: AbilityData, reason: String) -> void:
	_emit("ability", {uid = u.uid, ability = ab.id, kind = ab.kind,
		cell = u.cell, wasted = true, reason = reason})


func can_cast(u: UnitInstance) -> bool:
	var ab := u.data.ability
	if ab == null or ab.kind != AbilityData.Kind.SUMMON:
		return true
	return summon_shortfall(u, ab) == ""


func summon_shortfall(u: UnitInstance, ab: AbilityData) -> String:
	# Counted, never sampled: probing with _summon_cells() would consume the
	# seeded rng and desync every roll that follows.
	var want := mini(maxi(ab.summon_count, 1), maxi(summon_cap(u, ab) - u.summons_made, 0))
	if want <= 0:
		return "capped"
	if ab.summon_persists and persist_room(u.team) < want:
		return "no_home"
	if board.free_cells().size() < want:
		return "no_room"
	return ""


func persist_room(team: int) -> int:
	# A summon that outlives the round has to have somewhere to stand next round,
	# so it is measured against the half's whole capacity — not against whatever
	# happens to be free right now because someone just died.
	return (board.half_capacity(team) - _start_count[team] - _recruited[team])


func _summon_cells(u: UnitInstance, ab: AbilityData, count: int) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	if ab.summon_adjacent:
		# Closest to the summoner first, then further out. The far side of the
		# board is the fallback for a packed field, not the default.
		for c in BoardModel.by_distance_to(board.free_cells(), u.cell):
			if out.size() >= count:
				break
			out.append(c)
	else:
		# Scattered across the summoner's own half, spilling out only if it must.
		_take_random(board.free_deploy_cells(u.team), count, out)
		if out.size() < count:
			var elsewhere: Array[Vector2i] = []
			for c in board.free_cells():
				if not board.can_deploy(u.team, c):
					elsewhere.append(c)
			_take_random(elsewhere, count - out.size(), out)
	# A ternary here erases the element type, so the caller's typed array rejects
	# the result at runtime. Clear and return instead.
	if out.size() < count:
		out.clear()
	return out


func _take_random(pool: Array[Vector2i], count: int, into: Array[Vector2i]) -> void:
	for i in mini(count, pool.size()):
		var pick := rng.randi_range(0, pool.size() - 1)
		into.append(pool[pick])
		pool.remove_at(pick)


func recruits() -> Array[Dictionary]:
	return _recruits


func _absorb_new_units() -> void:
	if _pending_units.is_empty():
		return
	for u in _pending_units:
		_units.append(u)
	_pending_units.clear()
	_order.clear()
	for i in _units.size():
		_order.append(i)


func _tick_stealth() -> void:
	for u in _units:
		if u.stealth_left <= 0.0:
			continue
		u.stealth_left = maxf(u.stealth_left - TICK, 0.0)
		if u.stealth_left <= 0.0:
			_emit("stealth", {uid = u.uid, on = false, duration = 0.0})


func _tick_mana_regen() -> void:
	for u in _units:
		if not u.is_alive() or u.data.ability == null:
			continue
		if _mana_auras.has(u.uid):
			continue
		if not _charge_due(u):
			continue
		u.gain_mana(u.mana_per_charge())
		_emit("mana", {uid = u.uid, mana = u.mana})


func _charge_due(u: UnitInstance) -> bool:
	# Self-charging units run on their own clock, so a Spire can gather slowly
	# without the whole regen tick slowing down with it.
	if u.mana_per_charge() <= 0.0:
		return false
	u.mana_clock += REGEN_INTERVAL
	if u.mana_clock + 0.0001 < u.charge_time():
		return false
	u.mana_clock -= u.charge_time()
	return true


func _tick_mana_auras() -> void:
	if _mana_auras.is_empty():
		return
	for uid in _mana_auras:
		var caster := _unit_by_uid(uid)
		if caster == null or not caster.is_alive():
			continue
		var ab := caster.data.ability
		if ab == null:
			continue
		if not _charge_due(caster):
			continue
		var gift := caster.mana_per_charge()
		for ally in board.units_in_box(caster.cell, ab.mana_aura_radius, caster.team):
			if ally == caster or ally.data.ability == null:
				continue
			ally.gain_mana(gift)
			_emit("mana", {uid = ally.uid, mana = ally.mana})


func _try_queue_revive(victim: UnitInstance) -> bool:
	var ab := victim.data.ability
	if ab == null or ab.kind != AbilityData.Kind.REVIVE:
		return false
	if rng.randf() >= ab.revive_chance:
		return false
	_respawns.append({
		unit = victim, left = ab.revive_delay, cell = victim.cell,
		fraction = ab.revive_hp_percent,
	})
	_emit("respawn_start", {
		uid = victim.uid, cell = victim.cell, duration = ab.revive_delay,
	})
	return true


func pending_respawns(team: int) -> int:
	var n := 0
	for r in _respawns:
		var u: UnitInstance = r.unit
		if u.team == team:
			n += 1
	return n


func _tick_respawns() -> void:
	if _respawns.is_empty():
		return
	var i := _respawns.size() - 1
	while i >= 0:
		var r: Dictionary = _respawns[i]
		r.left -= TICK
		if r.left <= 0.0:
			_bring_back(r)
			_respawns.remove_at(i)
		i -= 1


func _bring_back(r: Dictionary) -> void:
	var u: UnitInstance = r.unit
	var home: Vector2i = r.cell
	if not board.in_bounds(home) or not board.is_empty(home):
		home = _any_free_cell(home, Vector2i(-1, -1))
	if not board.in_bounds(home) or not board.force_place(u, home):
		return
	u.state = UnitInstance.State.IDLE
	u.state_timer = 0.0
	u.target = null
	u.move_from = home
	u.mana = 0.0
	u.shield = 0.0
	u.dots.clear()
	u.stealth_left = 0.0
	u.haste_stacks = 0
	u.has_opened = false
	u.summons_made = 0
	u.battle_modifiers.clear()
	for m in _team_battle_mods.get(u.team, [] as Array[StatModifier]):
		u.add_battle_modifier(m)
	u.revives += 1
	u.current_hp = u.stat(StatModifier.Stat.MAX_HP) * clampf(r.fraction, 0.05, 1.0)
	_emit("respawn", {
		uid = u.uid, cell = home, hp = u.current_hp,
		max_hp = u.stat(StatModifier.Stat.MAX_HP), revives = u.revives,
	})
	if u.data.casts_at_battle_start and u.data.ability != null:
		u.has_opened = true


func _resolve_haste(u: UnitInstance, ab: AbilityData) -> void:
	if u.haste_stacks >= ab.haste_max_stacks:
		_emit("ability", {uid = u.uid, ability = ab.id, kind = ab.kind,
			cell = u.cell, wasted = true})
		return
	u.haste_stacks += 1
	u.add_battle_modifier(StatModifier.make(
		StatModifier.Stat.ATTACK_SPEED, StatModifier.Mode.PERCENT, ab.haste_percent))
	_emit("ability", {uid = u.uid, ability = ab.id, kind = ab.kind,
		cell = u.cell, stacks = u.haste_stacks})


func _resolve_shield(u: UnitInstance, ab: AbilityData) -> void:
	var pool := u.stat(StatModifier.Stat.MAX_HP)
	u.add_shield(pool * ab.shield_percent, pool * maxf(
		ab.shield_cap_percent, ab.shield_percent))
	_emit("ability", {uid = u.uid, ability = ab.id, kind = ab.kind,
		cell = u.cell, shield = u.shield})
	_emit("shield", {uid = u.uid, shield = u.shield})


func _resolve_dot(u: UnitInstance, ab: AbilityData, target: UnitInstance) -> void:
	if target == null or not target.is_alive():
		return
	target.apply_dot(ab.dot_damage, ab.dot_ticks, ab.dot_interval, u.uid)
	_emit("ability", {uid = u.uid, ability = ab.id, kind = ab.kind,
		cell = u.cell, target_uid = target.uid, target_cell = target.cell})


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
				_damage(u, d.dmg, src if src != null else u, true, false)
			if d.ticks_left <= 0:
				u.dots.remove_at(i)
			i -= 1


func displace(u: UnitInstance, dir: Vector2i, tiles: int) -> int:
	if not u.is_alive():
		return 0
	var from := u.cell
	var moved := board.push(u, dir, tiles)
	if moved <= 0:
		return 0
	if u.state == UnitInstance.State.MOVING:
		u.state = UnitInstance.State.IDLE
		u.state_timer = 0.0
	u.move_from = from
	_emit("displace", {
		uid = u.uid, from = from, to = u.cell,
		tiles = moved, duration = DISPLACE_TIME,
	})
	return moved


func _damage(victim: UnitInstance, amount: float, source: UnitInstance,
		is_spell := false, hp_bonus := true) -> void:
	if not victim.is_alive():
		return
	if victim.is_invulnerable():
		_emit("blocked", {uid = victim.uid, cell = victim.cell})
		return
	var total := amount
	if hp_bonus and source != null and source.team != victim.team:
		var frac: float = _hp_damage[source.team]
		if frac > 0.0:
			total += victim.stat(StatModifier.Stat.MAX_HP) * frac
	total *= victim.damage_taken_multiplier() * pressure()
	var landed := victim.take_damage(total)
	_drain_life(source, victim, total, landed)
	_emit("damage", {
		uid = victim.uid, source_uid = source.uid,
		amount = total, hp = victim.current_hp, shield = victim.shield,
		cell = victim.cell, spell = is_spell,
	})
	if not victim.is_alive():
		_emit("death", {uid = victim.uid, cell = victim.cell, killer_uid = source.uid})
		board.remove(victim)
		_try_queue_revive(victim)


func _drain_life(source: UnitInstance, victim: UnitInstance, dealt: float,
		_landed: float) -> void:
	if source == null or source == victim or source.team == victim.team:
		return
	var share := source.lifesteal()
	if share <= 0.0 or not source.is_alive():
		return
	var before := source.current_hp
	source.heal(dealt * share)
	if source.current_hp > before:
		_emit("heal", {
			uid = source.uid, amount = source.current_hp - before,
			hp = source.current_hp, cell = source.cell, drain = true,
		})


func _enter(u: UnitInstance, s: UnitInstance.State, duration: float) -> void:
	u.state = s
	u.state_timer = duration


func _advance_timer(u: UnitInstance) -> void:
	u.state_timer -= TICK
	if u.state_timer <= 0.0:
		u.state = UnitInstance.State.IDLE


func _next_step(u: UnitInstance) -> Vector2i:
	# Own BFS rather than AStarGrid2D: a grid solver can mark tiles solid but
	# has no way to express a barrier that sits *between* two open tiles.
	var goal := u.target.cell
	var came := _distance_field(goal, u.cell)
	var here: int = came.get(u.cell, -1)
	if here > 0:
		var best := u.cell
		var best_d := here
		for off in _neighbour_offsets():
			var c: Vector2i = u.cell + off
			if BoardModel.blocks_between(u.cell, c) or not board.is_empty(c):
				continue
			var d: int = came.get(c, -1)
			if d >= 0 and d < best_d:
				best_d = d
				best = c
		if best != u.cell:
			return best
	return _greedy_step(u, goal)


func _distance_field(goal: Vector2i, start: Vector2i) -> Dictionary:
	# Steps from every reachable tile back to the goal. The goal and the mover's
	# own tile are walkable even though something is standing on them.
	var dist := {goal: 0}
	var queue: Array[Vector2i] = [goal]
	var head := 0
	while head < queue.size():
		var c: Vector2i = queue[head]
		head += 1
		var next: int = int(dist[c]) + 1
		for off in _neighbour_offsets():
			var n: Vector2i = c + off
			if dist.has(n) or not board.in_bounds(n):
				continue
			if BoardModel.is_blocked(n) or BoardModel.blocks_between(c, n):
				continue
			if n != start and not board.is_empty(n):
				continue
			dist[n] = next
			if n == start:
				continue
			queue.append(n)
	return dist


func _greedy_step(u: UnitInstance, goal: Vector2i) -> Vector2i:
	var best := u.cell
	var best_d := BoardModel.tile_distance(u.cell, goal)
	for off in _neighbour_offsets():
		var c := u.cell + off
		if not board.is_empty(c) or BoardModel.blocks_between(u.cell, c):
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


func _check_over() -> void:
	var a := board.living_count_of(BoardModel.TEAM_A) + pending_respawns(BoardModel.TEAM_A)
	var b := board.living_count_of(BoardModel.TEAM_B) + pending_respawns(BoardModel.TEAM_B)
	if a > 0 and b > 0:
		return
	if a == 0 and b == 0:
		_result = RESULT_DRAW
	else:
		_result = BoardModel.TEAM_A if a > 0 else BoardModel.TEAM_B
	_finish("wipe")


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
	for u in _units:
		u.target = null
	_emit("end", {winner = _result, reason = reason})


func _emit(kind: String, payload: Dictionary) -> void:
	payload["t"] = elapsed
	payload["kind"] = kind
	events.append(payload)


func unit_map() -> Dictionary:
	var out := {}
	for u in _units:
		out[u.uid] = u
	return out


func is_finished() -> bool:
	return _finished


func result() -> int:
	return _result


func duration() -> float:
	return elapsed
