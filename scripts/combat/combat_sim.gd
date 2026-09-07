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

# A round can also overrun because the last two units never *meet* — on a maze
# or a long corridor, harder hits do nothing for a unit that is still walking.
# So pressure shortens the step as well as fattening the hit. Every unit is
# divided by the same number, so who outruns whom never changes.
const MIN_MOVE_TIME := TICK

# What a tile costs to path through when one of your own is standing on it. Six
# says "walk four tiles round rather than wait behind one, but do not walk
# twenty". It is a queueing cost, not a wall.
const CONGESTION_COST := 6

# How much further than the closest enemy another one may be and still be worth
# picking. Without this every unit in range converges on the same body and the
# whole line fixates; with it they spread across the front.
const TARGET_SLACK := 2

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
var _field_team := -1

# Everything that has died and could still be called back. A unit leaves this
# list the moment something raises it, so two Vigils never raise the same corpse
# and one Vigil never raises it twice.
var _fallen: Array[UnitInstance] = []


func setup(p_board: BoardModel, p_seed: int) -> void:
	board = p_board
	rng.seed = p_seed
	elapsed = 0.0
	events.clear()
	_finished = false
	_result = RESULT_DRAW

	_units = board.all_units()
	_respawns.clear()
	_fallen.clear()
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

	_decide_empowerment()
	_resolve_openers()
	_tick_counts()


func empowered_cap(team: int) -> int:
	var tb: TeamBuffs = team_buffs.get(team, null)
	return 1 if tb == null else tb.empowered_cap()


func _decide_empowerment() -> void:
	# Counted once, here, against the board as it stands at the opening bell.
	# Nothing that arrives later is ever empowered — not a Mimic's copy, not a
	# Spire's host, not a merge result — because this is a reward for the board
	# you built, and a summon you can pay for is not that.
	var tally := {}
	for u in _units:
		if not u.data.solo_empower:
			continue
		var key := [u.team, String(u.data.id)]
		tally[key] = int(tally.get(key, 0)) + 1
	for u in _units:
		if not u.data.solo_empower:
			continue
		var key := [u.team, String(u.data.id)]
		if int(tally[key]) > empowered_cap(u.team):
			continue
		u.empowered = true
		# Battle modifiers, not permanent ones: the round boundary wipes them, so
		# next round re-decides empowerment from scratch.
		var hp_mult := maxf(u.data.empower_hp_mult, 1.0)
		if hp_mult > 1.0:
			u.add_battle_modifier(StatModifier.make(StatModifier.Stat.MAX_HP,
				StatModifier.Mode.PERCENT, hp_mult - 1.0))
		var dmg_mult := maxf(u.data.empower_damage_mult, 1.0)
		if dmg_mult > 1.0:
			u.add_battle_modifier(StatModifier.make(
				StatModifier.Stat.ATTACK_DAMAGE,
				StatModifier.Mode.PERCENT, dmg_mult - 1.0))
		# The only empowerment multiplier allowed to go the wrong way, and the
		# reason the empowered form reads as a siege piece rather than a bigger
		# soldier: it hits enormously, over a 3x3, and almost never.
		var spd_mult := maxf(u.data.empower_attack_speed_mult, 0.05)
		if not is_equal_approx(spd_mult, 1.0):
			u.add_battle_modifier(StatModifier.make(
				StatModifier.Stat.ATTACK_SPEED,
				StatModifier.Mode.PERCENT, spd_mult - 1.0))
		u.heal_to_full()
		_emit("empowered", {uid = u.uid, cell = u.cell,
			hp = u.current_hp, max_hp = u.stat(StatModifier.Stat.MAX_HP)})


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
	_tick_taunts()
	_tick_reflects()
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
	_tick_repairs()
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
		if u.data.ability.opener_takes_time:
			# Not instant: this one wants a window in which it is standing there
			# doing the thing, and can be interrupted by dying.
			u.has_opened = true
			_begin_cast(u)
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
	u.target = _mark_for(u)
	if u.is_taunting():
		# Planted. It cannot move and it cannot swing while it holds — that is
		# what it is paying for the damage reduction and everyone's attention.
		return
	if u.mana_full() and can_cast(u):
		# Deliberately not gated on whether the cast can land, unless the ability
		# asks to be. A Spire that fills its bar with no room for the host burns
		# it — that is the pressure to merge before it is ready, not a bug.
		_begin_cast(u)
		return
	if u.target == null or not u.can_act():
		return

	var patient := _tending(u)
	if patient != null:
		# Already beside it: stand still and keep working rather than drifting off
		# and letting the repair lapse.
		if BoardModel.tile_distance(u.cell, patient.cell) > 1:
			var was := u.target
			u.target = patient
			_begin_move(u)
			u.target = was
		return

	var dist := BoardModel.tile_distance(u.cell, u.target.cell)
	if dist <= u.reach_on(BoardModel.is_high(u.cell)) and _has_shot(u, u.target):
		if u.can_attack_now():
			_begin_attack(u)
		return
	# In range but behind a wall: close in until there is a shot. Targeting is
	# deliberately not gated on sight, or a unit with no clear shot would stand
	# there with nothing to walk towards.
	if u.can_move_now():
		_begin_move(u)


func _mark_for(u: UnitInstance) -> UnitInstance:
	# An enemy holding a taunt inside its radius takes precedence over whoever
	# was closest. That is the whole ability: it does not deal damage, it decides
	# who the other army is fighting.
	var best: UnitInstance = null
	var best_d := 1 << 30
	for other in _units:
		if other.team == u.team or not other.is_alive() or not other.is_taunting():
			continue
		var ab := other.data.ability
		if ab == null:
			continue
		var d := BoardModel.tile_distance(u.cell, other.cell)
		if d <= ab.taunt_radius and d < best_d:
			best = other
			best_d = d
	return best if best != null else _choose_enemy(u)


func _choose_enemy(u: UnitInstance) -> UnitInstance:
	# Not simply the closest. Everything picking the strict nearest meant a whole
	# line converging on one body while the rest of the front stood unopposed,
	# and it made every battle on a given seed play out identically. Anything
	# within TARGET_SLACK of the closest is fair game, chosen off the seeded rng
	# so a replay is still exact.
	var near := board.nearest_enemy(u)
	if near == null:
		return null
	var reach := BoardModel.tile_distance(u.cell, near.cell) + TARGET_SLACK

	# Stick with what it is already fighting while that is still sensible, or a
	# unit would re-roll its mind every tick and never finish anything.
	var held := u.target
	if held != null and held.is_alive() and held.team != u.team \
			and not held.is_hidden() \
			and BoardModel.tile_distance(u.cell, held.cell) <= reach:
		return held

	var pool: Array[UnitInstance] = []
	for other in _units:
		if other.team == u.team or not other.is_alive() or other.is_hidden():
			continue
		if BoardModel.tile_distance(u.cell, other.cell) <= reach:
			pool.append(other)
	if pool.size() <= 1:
		return near
	return pool[rng.randi_range(0, pool.size() - 1)]


func _tending(u: UnitInstance) -> UnitInstance:
	# A repairer with a hurt machine to fix goes to it instead of going forward.
	# Without this the Engineer steps off its build tile, walks at the enemy, and
	# the repair trait never fires once — the turret it just built is the only
	# mechanical thing on the board and it is walking away from it.
	if u.data.repair_per_second <= 0.0 or not u.data.can_move:
		return null
	# It holds station with its machines whether they are hurt or not. A body with
	# 130 health and 8 damage advancing on the enemy is not a trade, it is a
	# donation — and it would not be there to repair the turret when the turret
	# finally needs it. A damaged one wins over a healthy one at the same range.
	var best: UnitInstance = null
	var best_key := Vector2i(9, 99)
	for other in _units:
		if other == u or other.team != u.team or not other.is_alive():
			continue
		if not other.data.is_mechanical():
			continue
		var hurt := 0 if other.current_hp < other.stat(StatModifier.Stat.MAX_HP) else 1
		var key := Vector2i(hurt, BoardModel.tile_distance(u.cell, other.cell))
		if key.x < best_key.x or (key.x == best_key.x and key.y < best_key.y):
			best_key = key
			best = other
	return best


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
	var dur := maxf(u.stat(StatModifier.Stat.MOVE_TIME) / pressure(), MIN_MOVE_TIME)
	var blocker := board.unit_at(next)
	if blocker != null:
		# _next_step only picks an occupied tile when a friend is standing in the
		# only way through. One that can walk will clear it itself, so we hold
		# our place in the queue rather than barging.
		if blocker.data.can_move:
			return
		# One that cannot never will, so we trade places with it. The log carries
		# both halves so the view animates a shove, not a teleport.
		if not board.trade_places(u, blocker):
			return
		blocker.move_from = from
		_emit("move", {uid = blocker.uid, from = next, to = from, duration = dur})
	elif not board.move_unit(u, next):
		return
	u.move_from = from
	_enter(u, UnitInstance.State.MOVING, dur)
	_emit("move", {uid = u.uid, from = from, to = next, duration = dur})


func _begin_attack(u: UnitInstance) -> void:
	var victim := u.target
	var dmg := u.stat(StatModifier.Stat.ATTACK_DAMAGE)
	var cd := u.attack_interval()
	_enter(u, UnitInstance.State.ATTACKING, cd)

	if u.executes_next:
		# The armed swing. Spent whatever happens, so a Devourer that arms itself
		# and then swings at something already dying has burnt it — the bar is not
		# saved for a better target.
		u.executes_next = false
		_execute(u, victim)
		_mana_from_swing(u)
		return

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

	# An empowered swing lands on the square around what it hit. Full damage, not
	# a wash: this is the reward for fielding exactly one of it.
	var splash := u.data.empower_splash_radius if u.empowered else 0
	if splash > 0:
		for other in board.units_in_box(victim.cell, splash, 1 - u.team):
			if struck.has(other.uid) or not other.is_alive():
				continue
			struck[other.uid] = true
			_damage(other, dmg, u)

	_mana_from_swing(u)


func _mana_from_swing(u: UnitInstance) -> void:
	var gained := u.data.mana_per_attack
	if u.ascended and u.data.ability != null:
		# The changed form pays for itself. A Devourer that has not changed yet
		# gains nothing from swinging at all, so its first bar has to come from
		# its own side dying.
		gained += u.data.ability.ascend_mana_per_attack
	if gained <= 0.0:
		return
	u.gain_mana(gained)
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
		AbilityData.Kind.TAUNT:
			_resolve_taunt(u, ab)
		AbilityData.Kind.REFLECT:
			_resolve_reflect(u, ab)
		AbilityData.Kind.RAISE:
			_resolve_raise(u, ab)
		AbilityData.Kind.ASCEND:
			_resolve_ascend(u, ab)


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


func retinue_size(u: UnitInstance) -> int:
	var n := 0
	for other in _units:
		if other.summoned_by == u.uid and other.is_alive():
			n += 1
	return n


func summon_want(u: UnitInstance, ab: AbilityData) -> int:
	# One place decides how many a cast makes, so _resolve_summon and
	# summon_shortfall can never disagree about whether it is worth casting.
	var cap := summon_cap(u, ab)
	if not ab.summon_retinue:
		return mini(maxi(ab.summon_count, 1), maxi(cap - u.summons_made, 0))
	# A retinue is measured by who is standing, and a cast refills it. That is
	# what makes a tier 6 Conjurer open with three wisps rather than one, and
	# what lets it replace one that dies instead of being done for the round.
	return maxi(cap - retinue_size(u), 0)


func _resolve_reflect(u: UnitInstance, ab: AbilityData) -> void:
	u.reflect_left = ab.reflect_duration
	_emit("ability", {uid = u.uid, ability = ab.id, kind = ab.kind,
		cell = u.cell, duration = ab.reflect_duration,
		percent = ab.reflect_percent})


func _resolve_taunt(u: UnitInstance, ab: AbilityData) -> void:
	u.taunt_left = ab.taunt_duration
	var pulled: Array[int] = []
	var cells: Array[Vector2i] = []
	for dy in range(-ab.taunt_radius, ab.taunt_radius + 1):
		for dx in range(-ab.taunt_radius, ab.taunt_radius + 1):
			var c := u.cell + Vector2i(dx, dy)
			if board.in_bounds(c) and BoardModel.tile_distance(u.cell, c) <= ab.taunt_radius:
				cells.append(c)
	for other in _units:
		if other.team == u.team or not other.is_alive():
			continue
		if BoardModel.tile_distance(u.cell, other.cell) > ab.taunt_radius:
			continue
		# Drop what you were doing. A unit mid-swing at something else finishes
		# that swing and then comes here; one mid-walk turns around now.
		other.target = u
		if other.state == UnitInstance.State.MOVING:
			other.state = UnitInstance.State.IDLE
			other.state_timer = 0.0
		pulled.append(other.uid)
	_emit("ability", {uid = u.uid, ability = ab.id, kind = ab.kind,
		cell = u.cell, cells = cells, radius = ab.taunt_radius,
		duration = ab.taunt_duration, pulled = pulled})


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
	var pool := _random_summon_pool(u.team)
	if pool.is_empty():
		return null
	var pick: UnitData = pool[rng.randi_range(0, pool.size() - 1)]
	return BoardModel.at_tier(pick, u.data.tier)


func _random_summon_pool(team: int) -> Array[UnitData]:
	# A Spire never rolls another Spire. Raising one would hand the winner of a
	# single cast a free second cast, and the one after that another — a board
	# that pays for itself. The rule is written against the mechanic rather than
	# the name: nothing that spends itself to summon can be summoned this way.
	var out: Array[UnitData] = []
	for d in board.pool_for(team):
		var ab := d.ability
		if ab != null and ab.kind == AbilityData.Kind.SUMMON and ab.consumes_caster:
			continue
		out.append(d)
	return out


func _resolve_summon(u: UnitInstance, ab: AbilityData) -> void:
	var want := summon_want(u, ab)
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
		minion.summoned_by = u.uid
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
	if ab == null:
		return true
	if ab.requires_empowered and not u.empowered:
		return false
	if ab.kind != AbilityData.Kind.SUMMON:
		return true
	if not ab.holds_when_capped:
		return true
	return summon_shortfall(u, ab) == ""


func summon_shortfall(u: UnitInstance, ab: AbilityData) -> String:
	# Counted, never sampled: probing with _summon_cells() would consume the
	# seeded rng and desync every roll that follows.
	var want := summon_want(u, ab)
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
	if ab.summon_at_caster and count == 1:
		# It is built where the builder was standing, and the builder steps off.
		# If there is nowhere to step, fall through to ordinary placement rather
		# than wasting the cast — the turret still gets built, just beside them.
		var step := _step_aside(u)
		if step != Vector2i(-1, -1):
			out.append(u.cell)
			board.move_unit(u, step)
			u.move_from = out[0]
			_emit("move", {
				uid = u.uid, from = out[0], to = step, duration = DISPLACE_TIME,
			})
			return out
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


func _step_aside(u: UnitInstance) -> Vector2i:
	for off in _neighbour_offsets():
		var c: Vector2i = u.cell + off
		if board.in_bounds(c) and board.is_empty(c) \
				and not BoardModel.blocks_between(u.cell, c):
			return c
	return Vector2i(-1, -1)


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


func _tick_reflects() -> void:
	for u in _units:
		if u.reflect_left <= 0.0:
			continue
		u.reflect_left -= TICK
		if u.reflect_left <= 0.0:
			u.reflect_left = 0.0
			_emit("reflect_end", {uid = u.uid, cell = u.cell})


func _tick_taunts() -> void:
	for u in _units:
		if u.taunt_left <= 0.0:
			continue
		u.taunt_left -= TICK
		if u.taunt_left <= 0.0:
			u.taunt_left = 0.0
			_emit("taunt_end", {uid = u.uid, cell = u.cell})


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


func _tick_repairs() -> void:
	# A trait, not an ability: the unit that has this already spends its ability
	# slot building the thing it repairs. Only reaches adjacent friendly
	# MECHANICAL units, which is the whole reason a chassis exists.
	for mech in _units:
		if not mech.is_alive() or mech.data.repair_per_second <= 0.0:
			continue
		for other in board.units_in_box(mech.cell, 1, mech.team):
			if other == mech or not other.data.is_mechanical():
				continue
			if BoardModel.tile_distance(mech.cell, other.cell) != 1:
				continue
			var before := other.current_hp
			other.heal(mech.data.repair_per_second)
			if other.current_hp > before:
				_emit("heal", {
					uid = other.uid, amount = other.current_hp - before,
					hp = other.current_hp, cell = other.cell, repair = true,
				})


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
	_restore(u, home, r.fraction)


func _restore(u: UnitInstance, home: Vector2i, fraction: float) -> void:
	# Shared by the Revenant getting itself up and the Vigil calling someone else
	# up. Both have to wipe exactly the same state or the two paths drift: a unit
	# that came back with its old shield, or its old stealth, or having already
	# spent its opener, is a different unit from the one that died.
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
	u.ascended = false
	u.executes_next = false
	u.revives += 1
	u.current_hp = u.stat(StatModifier.Stat.MAX_HP) * clampf(fraction, 0.05, 1.0)
	_emit("respawn", {
		uid = u.uid, cell = home, hp = u.current_hp,
		max_hp = u.stat(StatModifier.Stat.MAX_HP), revives = u.revives,
	})
	if u.data.casts_at_battle_start and u.data.ability != null:
		u.has_opened = true


func raise_count(u: UnitInstance) -> int:
	# Tier is the whole of this unit's scaling. Its own stats barely move between
	# tier 1 and tier 6; what changes is how much of your army it hands back.
	var ab := u.data.ability
	if ab == null or ab.kind != AbilityData.Kind.RAISE:
		return 0
	var n := maxi(ab.raise_per_tier, 0) * maxi(u.data.tier, 1)
	var tb: TeamBuffs = team_buffs.get(u.team, null)
	if tb != null:
		n += tb.extra_raises_for(u)
	return n


func _take_fallen(team: int) -> UnitInstance:
	# Randomly, not in the order they died. Which of your dead comes back is a
	# roll, so a Vigil is never a way to reliably rescue the one unit you care
	# about — it hands you back an army, not a choice.
	var pool: Array[int] = []
	for i in _fallen.size():
		var u: UnitInstance = _fallen[i]
		if u.team == team and not u.consumed:
			pool.append(i)
	if pool.is_empty():
		return null
	var at: int = pool[rng.randi_range(0, pool.size() - 1)]
	var picked: UnitInstance = _fallen[at]
	_fallen.remove_at(at)
	return picked


func _resolve_raise(u: UnitInstance, ab: AbilityData) -> void:
	var want := raise_count(u)
	var risen: Array[Vector2i] = []
	var uids: Array[int] = []
	while risen.size() < want:
		var body := _take_fallen(u.team)
		if body == null:
			break
		# Its own grave first, the ground near the Vigil second. A raised line
		# reforms roughly where it fell, which is usually where it was needed.
		var home := body.cell
		if not board.in_bounds(home) or not board.is_empty(home):
			home = _any_free_cell(u.cell, Vector2i(-1, -1))
		if not board.in_bounds(home) or not board.force_place(body, home):
			# No room anywhere. Put it back rather than losing the body — the
			# next cast, after the board has thinned, can still use it.
			_fallen.append(body)
			break
		_restore(body, home, ab.raise_hp_percent)
		risen.append(home)
		uids.append(body.uid)
	if risen.is_empty():
		_emit("ability", {uid = u.uid, ability = ab.id, kind = ab.kind,
			cell = u.cell, wasted = true, reason = "no_dead"})
		return
	# No _absorb_new_units() here on purpose: a raised unit is not a new unit. It
	# was on the board at the opening bell, so it is already in _units and already
	# has its slot in the action order — it just stopped being alive for a while.
	_emit("ability", {uid = u.uid, ability = ab.id, kind = ab.kind,
		cell = u.cell, cells = risen, raised = uids})


func _resolve_ascend(u: UnitInstance, ab: AbilityData) -> void:
	if u.ascended:
		# Already changed shape. A full bar now does the other thing: it arms the
		# next swing. Nothing stacks and nothing is wasted — the bar always buys
		# exactly one of the two.
		u.executes_next = true
		_emit("ability", {uid = u.uid, ability = ab.id, kind = ab.kind,
			cell = u.cell, armed = true})
		return
	u.ascended = true
	# Battle modifiers, like empowerment: the round boundary wipes them, so every
	# round it has to eat its way back up again.
	var hp_mult := maxf(ab.ascend_hp_mult, 1.0)
	if hp_mult > 1.0:
		u.add_battle_modifier(StatModifier.make(StatModifier.Stat.MAX_HP,
			StatModifier.Mode.PERCENT, hp_mult - 1.0))
	var spd_mult := maxf(ab.ascend_attack_speed_mult, 1.0)
	if spd_mult > 1.0:
		u.add_battle_modifier(StatModifier.make(StatModifier.Stat.ATTACK_SPEED,
			StatModifier.Mode.PERCENT, spd_mult - 1.0))
	# MOVE_TIME is inverted — less of it is faster — so a multiplier below 1.0
	# has to become a negative percentage here.
	var move_mult := clampf(ab.ascend_move_mult, 0.05, 1.0)
	if move_mult < 1.0:
		u.add_battle_modifier(StatModifier.make(StatModifier.Stat.MOVE_TIME,
			StatModifier.Mode.PERCENT, move_mult - 1.0))
	u.heal_to_full()
	_emit("ascend", {
		uid = u.uid, cell = u.cell, hp = u.current_hp,
		max_hp = u.stat(StatModifier.Stat.MAX_HP),
	})
	_emit("ability", {uid = u.uid, ability = ab.id, kind = ab.kind,
		cell = u.cell, ascended = true})


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


func burst_damage_of(u: UnitInstance, ab: AbilityData) -> float:
	if ab.burst_attack_multiple > 0.0:
		return u.stat(StatModifier.Stat.ATTACK_DAMAGE) * ab.burst_attack_multiple
	return ab.burst_damage


func _resolve_burst(u: UnitInstance, ab: AbilityData, target: UnitInstance) -> void:
	if target == null or not target.is_alive():
		return
	var hit := burst_damage_of(u, ab)
	var centre := target.cell
	var splashed: Array[Vector2i] = []
	for dy in range(-ab.splash_radius, ab.splash_radius + 1):
		for dx in range(-ab.splash_radius, ab.splash_radius + 1):
			var c := centre + Vector2i(dx, dy)
			if board.in_bounds(c):
				splashed.append(c)
	_emit("ability", {uid = u.uid, ability = ab.id, kind = ab.kind,
		cell = u.cell, target_uid = target.uid, target_cell = centre,
		cells = splashed, amount = hit})

	for c in splashed:
		var v := board.unit_at(c)
		if v == null or not v.is_alive() or v.team == u.team:
			continue
		_damage(v, hit if v == target else ab.splash_damage, u, true)


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
		is_spell := false, hp_bonus := true, may_reflect := true) -> void:
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
	total *= victim.damage_taken_multiplier() * pressure() * victim.exposure()
	total *= victim.taunt_damage_taken()
	total *= _burden_on(victim)
	var landed := victim.take_damage(total)
	_drain_life(source, victim, total, landed)
	_emit("damage", {
		uid = victim.uid, source_uid = source.uid,
		amount = total, hp = victim.current_hp, shield = victim.shield,
		cell = victim.cell, spell = is_spell,
	})
	if not victim.is_alive():
		_fell(victim, source.uid)
	_reflect_back(victim, source, total, may_reflect)


func _fell(victim: UnitInstance, killer_uid: int) -> void:
	# Every route to a death goes through here — an ordinary swing, a spell, and
	# the Devourer's execute. Keeping it in one place is what stops the execute
	# from quietly skipping the revive roll or the mana it owes the other side's
	# scavengers.
	_emit("death", {uid = victim.uid, cell = victim.cell, killer_uid = killer_uid})
	board.remove(victim)
	if not _try_queue_revive(victim):
		# Only a body nobody is already getting back up goes in the pile. A
		# Revenant mid-revive is not available to be raised as well.
		_fallen.append(victim)
	_feed_on_death(victim)


func _execute(u: UnitInstance, victim: UnitInstance) -> void:
	# Not enormous damage — an actual deletion. It goes through shields, through
	# resistance and through the Aegis's reflect, because a number big enough to
	# be reliable against a tier 6 Warden would be absurd against everything else.
	# The one thing it does not go through is invulnerability, so a guarded cast
	# is still guarded.
	if victim.is_invulnerable():
		_emit("blocked", {uid = victim.uid, cell = victim.cell})
		return
	_emit("attack", {
		uid = u.uid, target_uid = victim.uid,
		from = u.cell, to = victim.cell,
		amount = victim.effective_hp(), execute = true,
	})
	var taken := victim.effective_hp()
	victim.shield = 0.0
	victim.current_hp = 0.0
	victim.state = UnitInstance.State.DEAD
	victim.target = null
	_emit("damage", {
		uid = victim.uid, source_uid = u.uid,
		amount = taken, hp = 0.0, shield = 0.0,
		cell = victim.cell, spell = false, execute = true,
	})
	_fell(victim, u.uid)


func _feed_on_death(victim: UnitInstance) -> void:
	# Every living unit on the DEAD one's own side that eats deaths gets a charge.
	# It is deliberately not a kill reward — you cannot fill this bar by winning,
	# only by losing people, which is why the units built on it are comebacks
	# rather than snowballs.
	for u in _units:
		if u == victim or u.team != victim.team or not u.is_alive():
			continue
		if u.data.mana_per_ally_death <= 0.0:
			continue
		u.gain_mana(u.data.mana_per_ally_death)
		_emit("mana", {uid = u.uid, mana = u.mana})


func _reflect_back(victim: UnitInstance, source: UnitInstance, dealt: float,
		may_reflect: bool) -> void:
	# Only what hit it from arm's length comes back — a swing or an ability cast
	# from an adjacent tile. An archer across the board is safe, which is what
	# makes this a melee answer rather than a blanket one.
	if not may_reflect or source == null or not victim.is_reflecting():
		return
	if source == victim or source.team == victim.team or not source.is_alive():
		return
	if BoardModel.tile_distance(source.cell, victim.cell) > 1:
		return
	var ab := victim.data.ability
	if ab == null or ab.reflect_percent <= 0.0:
		return
	var back := dealt * ab.reflect_percent
	_emit("reflect", {uid = victim.uid, target_uid = source.uid,
		cell = source.cell, amount = back})
	# may_reflect false on the way back, or two of these facing each other would
	# bounce a hit between them until one of the stacks ran out.
	_damage(source, back, victim, false, false, false)


func _burden_on(victim: UnitInstance) -> float:
	# Asked at the moment of the hit rather than tracked as state, so a Tyrant
	# that dies or walks off stops mattering immediately and there is no stale
	# aura to clean up at the round boundary.
	var mult := 1.0
	for other in _units:
		if other == victim or other.team != victim.team or not other.is_alive():
			continue
		if other.data.burden_radius <= 0 or other.data.burden_percent <= 0.0:
			continue
		if BoardModel.tile_distance(other.cell, victim.cell) <= other.data.burden_radius:
			mult += other.data.burden_percent
	return mult


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
	_field_team = u.team
	var step := _downhill(u, _distance_field(goal, u.cell), {})
	if step != u.cell:
		return step

	# Every route out is blocked by our own people. Path again as if they were
	# not there and take our place in the queue: shove past anything rooted, and
	# wait behind anything that will move on its own. Falling straight through to
	# a greedy step here is what made a corridor board time out — the units at
	# the back scatter along the wall beside the jam instead of lining up for it.
	var friends := _friendly_cells(u)
	if not friends.is_empty():
		step = _downhill(u, _distance_field(goal, u.cell, friends), friends)
		if step != u.cell:
			return step
	return _greedy_step(u, goal)


func _friendly_cells(u: UnitInstance) -> Dictionary:
	var out := {}
	for other in _units:
		if other != u and other.team == u.team and other.is_alive():
			out[other.cell] = true
	return out


func _downhill(u: UnitInstance, field: Dictionary, through: Dictionary) -> Vector2i:
	var here: int = field.get(u.cell, -1)
	if here <= 0:
		return u.cell
	var best := u.cell
	var best_d := here
	var best_free := false
	for off in _neighbour_offsets():
		var c: Vector2i = u.cell + off
		if BoardModel.blocks_between(u.cell, c):
			continue
		var free := board.is_empty(c)
		if not free and not through.has(c):
			continue
		var d: int = field.get(c, -1)
		if d < 0 or d >= here:
			continue
		# Strictly closer wins; at the same distance an open tile beats one we
		# would have to queue behind.
		if best == u.cell or d < best_d or (d == best_d and free and not best_free):
			best = c
			best_d = d
			best_free = free
	return best


func _distance_field(goal: Vector2i, start: Vector2i,
		through: Dictionary = {}) -> Dictionary:
	# Cost from every reachable tile back to the goal — cost, not steps, because
	# a tile with one of your own people standing on it is passable but slow.
	# Treating it as a wall was what made a whole column queue behind one jam
	# when a two-tile detour was standing empty beside them; charging it
	# CONGESTION_COST instead means a short way round wins and a long one does
	# not, which is the judgement a player would make.
	#
	# Enemies stay impassable. You do not walk through them, you fight them, and
	# the one you are walking at is the goal and therefore free.
	var dist := {goal: 0}
	var open: Array[Vector2i] = [goal]
	while not open.is_empty():
		# Small boards, so a linear scan for the cheapest open tile is cheaper
		# than keeping a heap in order.
		var pick := 0
		for i in range(1, open.size()):
			if int(dist[open[i]]) < int(dist[open[pick]]):
				pick = i
		var c: Vector2i = open[pick]
		open.remove_at(pick)
		if c == start:
			continue
		var here: int = int(dist[c])
		for off in _neighbour_offsets():
			var n: Vector2i = c + off
			if not board.in_bounds(n):
				continue
			if BoardModel.is_blocked(n) or BoardModel.blocks_between(c, n):
				continue
			var step := 1
			if n != start and not through.has(n):
				var sitting := board.unit_at(n)
				if sitting != null:
					if sitting.team != _field_team:
						continue
					step = CONGESTION_COST
			var cost := here + step
			if dist.has(n) and int(dist[n]) <= cost:
				continue
			dist[n] = cost
			open.append(n)
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
