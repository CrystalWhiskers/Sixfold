class_name CombatSim
extends RefCounted

const TICK := 0.1
## Two minutes, and it is a real deadline rather than a safety net: a round that
## reaches it is decided on units still standing, and the player watching has a
## countdown on screen the whole time.
const DEFAULT_TIMEOUT := 120.0

const RESULT_DRAW := -1

const DISPLACE_TIME := 0.12

const REGEN_INTERVAL := 1.0

# Two tier-1 Wardens carry 275 points of shield each and deal about 12 a second,
# so left alone they cannot finish each other inside the timeout. At 1:45 the
# gloves come off and the last fifteen seconds are meant to produce a body.
#
# Held until the last fifteen seconds on purpose. It used to start at 30s, which
# meant almost nothing survived to the timeout and the clock never decided
# anything — the escalation did. The clock is the rule; this is the backstop
# against a fight that would otherwise never touch.
const SUDDEN_DEATH := 105.0

# One step, not a ramp. It used to climb 15% a second, which over a long tail was
# the thing that actually decided rounds; over fifteen seconds a ramp would be
# nearly invisible for the first ten and absurd for the last two. A flat doubling
# is legible — you can hear it happen and you know exactly what changed.
#
# It multiplies damage, attack speed and movement alike. Movement is in here
# because the other half of an overrunning round is two units that never MEET —
# on a maze or a long corridor, harder hits do nothing for a unit that is still
# walking. Every unit is divided by the same number, so who outruns whom never
# changes.
const SUDDEN_DEATH_MULT := 2.0

# A round can also overrun because the last two units never *meet* — on a maze
# or a long corridor, harder hits do nothing for a unit that is still walking.
# So pressure shortens the step as well as fattening the hit. Every unit is
# divided by the same number, so who outruns whom never changes.
## How long a shield stands before it fizzles.
##
## One number for every shield in the game — the Warden's bulwark, the Colossus
## hardening itself, the Aegis Wall buff — because a shield that lasted forever made
## the opening bulwark a permanent slab of extra health rather than a window to
## fight behind. Seven rather than five: the Warden's whole identity is the shield,
## and at five it has fizzled before the lines meet on the larger maps.
##
## The clock belongs to the POOL, not to each contribution, which is what makes
## topping up a real decision rather than a free renewal. See
## UnitInstance.shield_left.
const SHIELD_SECONDS := 7.0

const MIN_MOVE_TIME := TICK
const MIN_ATTACK_TIME := TICK

# What a tile costs to path through when one of your own is standing on it. Six
# says "walk four tiles round rather than wait behind one, but do not walk
# twenty". It is a queueing cost, not a wall.
const CONGESTION_COST := 6

# What a breakable wall costs to path "through". Enormous on purpose: an ordinary
# unit will walk a long way round rather than start digging, which is what makes
# breaking a wall the last resort rather than a shortcut. It is not infinite,
# though, and that is the whole trick — when a side is genuinely sealed in, the
# route through the stone becomes the *only* route, the field prices it, and the
# army digs its way out instead of standing at the wall forever.
const WALL_COST := 40

# What it costs a unit that breaks walls for a living. Two says "a wall is worth
# about one tile of detour", so a Sapper goes at the stone almost every time.
const SAPPER_WALL_COST := 2

# A unit that has not landed a blow in this many seconds stops being patient
# about walls. Six seconds is long enough that nothing in a normal fight ever
# reaches it, and short enough that a unit sent the long way round a map wall
# gives up on the detour well before the round is decided.
const IMPATIENT_AFTER := 6.0

# And after this long it stops wanting the thing it cannot have. Two seconds
# past the point where it starts breaking walls, so digging gets its chance
# first; see _gave_up_on_target().
const STUBBORN_AFTER := 8.0

# An ordinary unit does 0.15x its attack damage to stone, and at that rate a map
# wall outlasts the round several times over — smashing at that speed would be
# strictly worse than walking, a quirk that traps units against a rock. This
# floor puts an impatient unit through a map wall in a handful of swings while
# still leaving the Sapper (6.0x) three times faster and, unlike anyone else,
# eager from the opening bell.
const IMPATIENT_WALL_MULT := 2.0

# What a burning tile costs to path across. Three says "walk two tiles round if
# you can, otherwise take the burn" — dissuaded, not forbidden. Making fire
# impassable would let a Culverin wall a corridor off with one shell, which is a
# different and much stronger unit than the one asked for.
const FIELD_COST := 3

# Every point of damage in the game rolls for this, wherever it comes from — a
# swing, a spell, a shell, a burning tile, a drain tick. Rolled off the seeded
# rng like everything else, so a replay of the same seed crits in the same places.
const CRIT_CHANCE := 0.05
const CRIT_MULT := 2.0

# How far the Pariah's elbow room reaches, in tiles, measured as a square rather
# than a cross — 1 here is the eight cells around it, the "3x3" the design asks
# for. Widening it to 2 would make it a 5x5 and is a one-character change.
const ISOLATION_RADIUS := 1

## The live rate, so a test that measures an exact damage figure can set it to
## zero and get a quiet board. It is a var rather than a hidden flag because
## "how often does anything crit" is a real dial — turning it off is just one end
## of it — and there is a test asserting the default is still 5%.
var crit_chance := CRIT_CHANCE

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
var _field_wall_cost := WALL_COST

## Whether the field being built may route through a gate. False for a unit that has
## already spent its one transit, so the field does not send it to a pad it cannot
## use and leave it standing there.
var _field_gates := true

## How many units a side may send through a gate in one round.
##
## One, and this number is the whole feature. A gate is a single tile, so a field that
## prices it cheaply prices it cheaply for EVERYBODY — and an army that agrees the
## shortcut is worth taking walks through it in single file and arrives in the enemy
## half one body at a time, with no line to fall back on. Measured with no cap at all,
## across five boards, the gate helped the attacker on exactly one of them and was
## catastrophic on two: the Breach went from 85% to 15%.
##
## Capped at one, it is what it was meant to be — a flanker, the thing you would
## otherwise have needed an Assassin for — and the rest of the line fights normally.
const GATE_TRANSITS_PER_TEAM := 1

## Transits spent this round, per team.
var _gate_used: Array[int] = [0, 0]

# Everything that has died and could still be called back. A unit leaves this
# list the moment something raises it, so two Vigils never raise the same corpse
# and one Vigil never raises it twice.
var _fallen: Array[UnitInstance] = []

# Shells that have been fired and have not landed yet. A cast puts one here and
# `_tick_shells` resolves it seconds later, which is what makes the Culverin's
# shot a thing you watch arrive rather than a number that happens instantly.
var _shells: Array[Dictionary] = []

# Burning ground: {cell, team, damage, left, clock}. `team` is who laid it, so it
# only ever hurts the other side.
var _fields: Array[Dictionary] = []

# Live drains: {source_uid, victim, percent, clock, interval}. Several may point
# at the same victim, and that is the point.
var _drains: Array[Dictionary] = []


func setup(p_board: BoardModel, p_seed: int) -> void:
	board = p_board
	rng.seed = p_seed
	elapsed = 0.0
	events.clear()
	_finished = false
	_result = RESULT_DRAW

	_units = board.all_units()
	# Every battle starts from the map as it was drawn. Terrain damage is battle
	# state, exactly like shields and mana, so this is the round boundary for it —
	# and doing it here rather than in the flow layer means a test that sets up a
	# sim gets a clean board without knowing the rule exists.
	BoardModel.clear_changes()
	_respawns.clear()
	_fallen.clear()
	_shells.clear()
	_fields.clear()
	_drains.clear()
	_pending_units.clear()
	_mana_auras.clear()
	_recruits.clear()
	_start_count = [0, 0]
	_recruited = [0, 0]
	_sudden_death = false
	_gate_used = [0, 0]
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
			# The shield a unit is ALREADY standing behind at the bell, which is the
			# Aegis Wall buff's whole effect — applied by _apply_battle_buffs above,
			# before any of this is emitted. It used to be left off, and the view's
			# spawn handler zeroes the bar, so a round-shield buff put a thousand
			# points on every unit and drew none of it. It looked like the buff did
			# nothing.
			shield = u.shield,
			has_ability = u.data.ability != null,
		})

	_decide_empowerment()
	_decide_isolation()
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


func run(limit := -1.0) -> int:
	## Negative means "use this sim's own timeout", which is the conventional one
	## unless the flow layer set a custom round length. A caller may still pass an
	## explicit limit; a few tests do.
	var stop := timeout_at() if limit < 0.0 else limit
	while not _finished and elapsed < stop:
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
		if u.is_riding():
			# Inside a host and off the board. It gets no turn of its own — the
			# thing it is wearing is taking them.
			continue
		if u.is_charging():
			# Committed. A charge with travel time is a decision you cannot take back
			# halfway, which is the other half of what makes it dodgeable: the runner
			# holds its line while everything else is free to move.
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
	# Before the shields and the poisons, and AFTER the unit loop above: the units have
	# already taken their turns this tick, so a unit that stepped out of the lane this
	# tick is already out of it when the charge arrives. That ordering is the dodge.
	_tick_charges()
	_tick_disorient()
	_tick_shields()
	_tick_possessions()
	_tick_dry_spells()
	_tick_dots()
	_tick_frenzy()
	_tick_regen()
	_tick_pressure()
	_tick_stealth()
	_tick_taunts()
	_tick_freezes()
	_tick_stuns()
	_tick_reflects()
	_tick_shells()
	_tick_fields()
	_tick_drains()
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
		var bulwark := tb.round_shield()
		if bulwark > 0.0:
			# Through add_shield() with no ceiling, rather than writing the pool
			# directly. The unit's own shield_cap is a number meant for the Warden's
			# bulwark and most units set it to zero, so this gift from outside has to
			# pass an infinite cap — but it still has to pass through the one door, or
			# it is a shield with no clock on it.
			for u in _units:
				if u.team == team:
					u.add_shield(bulwark, INF, SHIELD_SECONDS)
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


## When everything doubles and nothing recovers, and when the round is called a draw.
## Both default to the conventional numbers and both are written by the flow layer
## for a custom match — see GameSetup.sudden_death_at().
##
## Fields rather than consts, and read through the two functions below rather than
## directly, so a custom match cannot end up with a sudden death that lands after the
## timeout and therefore never happens.
var sudden_death := SUDDEN_DEATH
var timeout := DEFAULT_TIMEOUT


func sudden_death_at() -> float:
	return clampf(sudden_death, 1.0, timeout_at() - 1.0)


func timeout_at() -> float:
	return maxf(timeout, 5.0)


func pressure() -> float:
	## The one number sudden death multiplies by. Read by the damage calculation,
	## the attack timer and the move timer, so all three change together and there
	## is a single place to look when the last fifteen seconds feel wrong.
	return SUDDEN_DEATH_MULT if _sudden_death else 1.0


func attack_interval(u: UnitInstance) -> float:
	## The unit's own swing timer, divided by the pressure. This lives here rather
	## than on UnitInstance because pressure belongs to the battle, not to the
	## unit — a unit has no idea what time it is.
	return maxf(u.attack_interval() / pressure(), MIN_ATTACK_TIME)


func _tick_pressure() -> void:
	if _sudden_death or elapsed <= sudden_death_at():
		return
	_sudden_death = true
	# Nothing recovers from here on: no healing from any source, and no shield
	# may be GAINED. Shields already standing are not stripped — the rule is that
	# the fight stops replenishing, not that armour evaporates, and stripping them
	# would delete the Warden's whole identity fifteen seconds from the end.
	for u in _units:
		u.recovery_denied = true
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
	# Held units do not get a turn at all — frozen or stunned, the two are the
	# same refusal here. Checked before the target is even picked, and before the
	# full-mana cast below, so a bar that filled the tick before it landed is held
	# rather than spent.
	if u.is_held():
		return
	if u.is_disoriented():
		# Lost. It still moves — that is the whole difference between this and a stun —
		# but it moves somewhere arbitrary and it swings at nothing on the way.
		_wander(u)
		return
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
		# Standing over its machine with nothing to walk to. Still swing at
		# anything that has come within arm's length.
		_swing_at_hand(u)
		return

	var reach := reach_against(u, u.target)
	if BoardModel.in_reach(u.cell, u.target.cell, reach) and _has_shot(u, u.target):
		# In range, and something has got closer than this unit wants to fight.
		# Give ground before swinging.
		#
		# The first attempt put this in the cooldown window instead, on the theory
		# that a step taken between swings is free. There is no such window: the
		# cooldown IS the ATTACKING state, _decide only ever runs on an IDLE unit,
		# so a unit that is in reach and idle is a unit that is about to swing.
		# "Retreat when you cannot shoot anyway" was dead code that read correctly
		# and never once ran.
		#
		# So a retreat costs a swing, and the rate limit is what keeps that cost
		# bounded — see kite_hold. One step back, then a full attack cycle of
		# shooting, then it may give ground again. That is a unit that fights at its
		# range rather than one that walks backwards for the whole round.
		if _give_ground(u, reach):
			return
		if u.can_attack_now():
			_begin_attack(u)
		return
	# Fed up. Before taking another step of a walk that has already gone on for
	# six seconds, take the wall in front of it instead.
	#
	# This is deliberately NOT done by making stone cheaper in the distance field,
	# which was the first attempt. Movement here is diagonal, so rounding the end
	# of a lane wall is only a tile or two longer than going through it and the
	# two routes tie almost everywhere; a price low enough to break that tie is
	# lower than the Sapper's, and then nothing distinguishes them. The field
	# stays honest about which route is SHORTER, and this overrides it on the
	# grounds that the unit has run out of patience, which is not a claim about
	# distance at all.
	if is_impatient(u) and _smash_through(u):
		return
	# In range but behind a wall: close in until there is a shot. Targeting is
	# deliberately not gated on sight, or a unit with no clear shot would stand
	# there with nothing to walk towards.
	if u.can_move_now() and _begin_move(u):
		return
	# It wanted to walk and could not — rooted, walled in, or queued behind a
	# friend who has not moved yet. Standing perfectly still next to an enemy it
	# was not aiming at is the bug this fixes: if anything at all is in reach,
	# hit it instead of waiting for the traffic to clear.
	_swing_at_hand(u)


func prefers_distance(u: UnitInstance) -> bool:
	## Whether this unit wants a gap at all. Melee does not — its preferred range
	## IS contact — and neither does anything that cannot shoot.
	return (u.can_act() and u.data.can_attack
		and u.range_band() != UnitData.RangeBand.MELEE)


func _give_ground(u: UnitInstance, reach: int) -> bool:
	## One step away from what it is shooting at, to restore the gap it fights best
	## at. Returns whether it moved.
	##
	## Capped at `reach`: it backs off until it is at the edge of its own range and
	## then stands its ground. Without the cap a bow walks to the far wall and
	## spends the round there, which is not "fighting at its preferred range", it is
	## refusing to fight.
	if not prefers_distance(u) or not u.can_move_now() or u.target == null:
		return false
	if u.kite_hold > 0.0:
		# Already gave ground recently. Without this the unit alternates step and
		# swing forever against anything that follows it, which halves its damage
		# for the whole round — worse than simply standing and shooting, and not
		# what "fights at its preferred range" is meant to buy.
		return false
	var mark := u.target
	var here := BoardModel.tile_distance(u.cell, mark.cell)
	if here >= reach:
		return false
	# Two metrics, and both have to improve. This is not belt and braces, it is the
	# difference between backing off and sidestepping.
	#
	# Range is measured in Manhattan steps (BoardModel.DIAGONAL_RANGE is false) but
	# units WALK diagonally, so a purely sideways step increases the Manhattan
	# distance by one while leaving the unit exactly as far away as it was. An apex
	# Transcendence standing on the back row did precisely that: it shuffled one
	# tile sideways, called it a retreat, and its beam — which now ran diagonally —
	# missed everything lined up behind its target.
	var here_box := BoardModel.box_distance(u.cell, mark.cell)
	var best := Vector2i(-1, -1)
	var best_d := here
	for off in _neighbour_offsets():
		var c: Vector2i = u.cell + off
		if not board.in_bounds(c) or not board.is_empty(c):
			continue
		if BoardModel.is_blocked(c) or not BoardModel.can_climb(u.cell, c):
			continue
		var d := BoardModel.tile_distance(c, mark.cell)
		if d <= best_d or d > reach:
			continue
		if BoardModel.box_distance(c, mark.cell) <= here_box:
			continue
		# It has to be able to keep shooting from where it retreats to. A step that
		# breaks the line of fire is worse than standing still — it would spend the
		# cooldown moving and then have nothing to shoot.
		if not BoardModel.in_reach(c, mark.cell, reach):
			continue
		if not _shot_from(u, c, mark):
			continue
		best = c
		best_d = d
	if best.x < 0:
		return false
	if not _step_to(u, best):
		return false
	# Paid for with one swing, so the next one is owed. A full attack cycle rather
	# than a fixed number of seconds, because a slow bow giving ground every two
	# seconds would be giving ground between every single shot.
	u.kite_hold = attack_interval(u)
	return true


func _step_to(u: UnitInstance, to: Vector2i) -> bool:
	## A plain step into a tile already known to be legal and empty. Deliberately
	## much less than _begin_move: no distance field, no trading places with a
	## rooted friend, no smashing through stone. A retreat that has to shove
	## something out of the way is not a retreat.
	var from := u.cell
	if not board.move_unit(u, to):
		return false
	var dur := maxf(u.stat(StatModifier.Stat.MOVE_TIME) / pressure(), MIN_MOVE_TIME)
	u.move_from = from
	_enter(u, UnitInstance.State.MOVING, dur)
	_emit("move", {uid = u.uid, from = from, to = to, duration = dur})
	return true


func _smash_through(u: UnitInstance) -> bool:
	# The breakable tile beside it that lies toward whatever it is trying to
	# reach. "Toward" is the whole guard: without it a unit kept waiting anywhere
	# on the board starts demolishing whatever stone happens to be next to it,
	# including the wall protecting its own back line.
	if u.target == null or not u.can_attack_now():
		return false
	var here := BoardModel.tile_distance(u.cell, u.target.cell)
	var best := Vector2i(-1, -1)
	var best_d := here
	for off in _neighbour_offsets():
		var c: Vector2i = u.cell + off
		if not board.in_bounds(c) or not BoardModel.is_breakable(c):
			continue
		if BoardModel.blocks_between(u.cell, c):
			continue
		var d := BoardModel.tile_distance(c, u.target.cell)
		if d < best_d:
			best = c
			best_d = d
	if best.x < 0:
		return false
	return _hit_wall(u, best)


func reach_against(u: UnitInstance, target: UnitInstance) -> int:
	# How far this unit can hit THAT unit, which is not a property of the unit
	# alone once the board has a second layer on it. Three rules, and the first
	# one is absolute:
	#
	#   * A melee unit standing on the ground cannot touch anything on high
	#     ground. Not "at a penalty" — at all. Stairs are the answer, and finding
	#     them is the melee player's problem. Standing ON the stairs counts as
	#     being up there for this: the step is the fighting ground, and a melee
	#     line that had to finish the climb before it could swing would be cut
	#     down one at a time by anything waiting at the top. Stairs are the way
	#     up, so they have to be a place you can fight from.
	#   * Shooting FROM high ground is worth a band, which it always has been.
	#   * Shooting AT high ground costs a band. A Long-ranged Archer has to come
	#     to Medium range to touch the terrace.
	#
	# The two ranged adjustments cancel, so a duel between two units on separate
	# terraces is fought at exactly the range it would be on flat ground.
	var high_from := BoardModel.is_high(u.cell)
	var high_to := target != null and BoardModel.is_high(target.cell)
	# Stairs let a MELEE unit swing up onto the terrace, and do nothing else. A
	# unit on the steps is halfway up: close enough to reach the man at the top,
	# not high enough to be safe from him, and not high enough for a bow to gain
	# the elevation band — that is a reward for holding the terrace, not for
	# putting one foot on it.
	var footing := high_from or BoardModel.is_stairs(u.cell)
	if high_to and not footing and not u.is_ranged():
		# Zero, not one: in_reach compares against a distance of at least one for
		# any two distinct tiles, so this can never be satisfied.
		return 0
	var band := u.stat_int(StatModifier.Stat.ATTACK_RANGE)
	if u.is_ranged():
		if high_from:
			band += 1
		if high_to:
			band -= 1
	return UnitData.band_tiles(maxi(band, int(UnitData.RangeBand.MELEE)))


func wall_damage_of(u: UnitInstance) -> float:
	# Off the unit's *current* attack damage, not its printed one, so a tier 6
	# Sapper digs 32 times faster than a tier 1 and Blasting Powder's attack bonus
	# reaches the stone too. Writing it as a flat number per tier was the same
	# mistake Cinder Lance still has.
	var mult := maxf(u.data.wall_damage_mult, 0.0)
	if is_impatient(u):
		# A floor, not a bonus: a Sapper is already well past it and is not made
		# faster by being kept waiting.
		mult = maxf(mult, IMPATIENT_WALL_MULT)
	return u.stat(StatModifier.Stat.ATTACK_DAMAGE) * mult


func _hit_wall(u: UnitInstance, cell: Vector2i) -> bool:
	if not u.can_attack_now() or not BoardModel.is_breakable(cell):
		return false
	var hit := wall_damage_of(u)
	if hit <= 0.0:
		return false
	# It costs a swing, at the unit's own attack speed. A Sapper digs quickly
	# because it hits hard and often; a Warden digs slowly for both reasons.
	_enter(u, UnitInstance.State.ATTACKING, attack_interval(u))
	var fell := BoardModel.damage_wall(cell, hit)
	_emit("wall_hit", {
		uid = u.uid, from = u.cell, cell = cell, amount = hit,
		left = BoardModel.wall_hp(cell), fraction = BoardModel.wall_fraction(cell),
		down = fell,
	})
	if fell:
		_emit("terrain", {broken = [cell], raised = [] as Array[Vector2i]})
	return true


func _swing_at_hand(u: UnitInstance) -> void:
	# The consolation swing. It deliberately re-picks a target rather than using
	# u.target: the whole point is that the unit it *wanted* is unreachable and
	# something else is not.
	if not u.can_attack_now():
		return
	var best: UnitInstance = null
	var best_d := 1 << 30
	for other in _units:
		if other.team == u.team or not other.is_alive() or other.is_hidden():
			continue
		if not BoardModel.in_reach(u.cell, other.cell, reach_against(u, other)):
			continue
		if not _has_shot(u, other):
			continue
		var d := BoardModel.tile_distance(u.cell, other.cell)
		if d < best_d:
			best = other
			best_d = d
	if best == null:
		return
	u.target = best
	_begin_attack(u)


func _mark_for(u: UnitInstance) -> UnitInstance:
	## THE place a unit decides what it is fighting, and the hook any unit with its
	## own targeting rule should be added to.
	##
	## The shape is already here: a precedence check first, the general rule second.
	## A unit that always goes for the biggest body, or the weakest, or the nearest
	## caster, is another arm above the fall-through — not a special case scattered
	## through _decide.
	#
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
	#
	# Unless it has been stuck. The stickiness above is what makes a unit fight
	# instead of dithering, but it is also how a unit freezes solid: it locks on
	# to something it cannot actually get to — the far side of permanent stone,
	# a plateau whose only stairs are on the enemy's half — and then walks into
	# the same obstacle for the rest of the round because the target is still
	# "sensible" by distance. Distance was never the question. Whether it has
	# managed to do anything in the last few seconds is.
	var held := u.target
	if held != null and not held.is_alive():
		# It just finished something off. The next thing it fights is the NEAREST
		# thing — no slack band, no roll.
		#
		# The slack below exists to stop a whole line converging on one body, and
		# that is a question about where a unit points when it has nobody in
		# particular to fight. This is a different moment: the unit was fighting
		# something, it won, and rolling a random body two tiles further out reads as
		# the unit losing interest and wandering off. That was the complaint.
		return near
	var give_up := _gave_up_on_target(u)
	if not give_up and held != null and held.is_alive() and held.team != u.team \
			and not held.is_hidden() \
			and BoardModel.tile_distance(u.cell, held.cell) <= reach:
		return held

	var pool: Array[UnitInstance] = []
	for other in _units:
		if other.team == u.team or not other.is_alive() or other.is_hidden():
			continue
		# The one it just gave up on is off the list, so "pick again" cannot pick
		# the same body and leave the unit standing exactly where it was.
		if give_up and other == held:
			continue
		if BoardModel.tile_distance(u.cell, other.cell) <= reach:
			pool.append(other)
	if pool.is_empty():
		# Nobody else within reach — often literally nobody else alive. Better to
		# keep battering at the one enemy there is than to stand with no target
		# at all, so the give-up is abandoned rather than the target.
		return near
	if pool.size() == 1:
		return pool[0]
	return pool[rng.randi_range(0, pool.size() - 1)]


func _gave_up_on_target(u: UnitInstance) -> bool:
	## Has this unit gone long enough without landing anything that it should stop
	## being stubborn? Deliberately LONGER than IMPATIENT_AFTER: a unit with a
	## wall in the way starts breaking it at six seconds, and it deserves the
	## chance to finish rather than being pulled off the moment it starts digging.
	## What is left after that is a unit that cannot solve its problem by walking
	## or by digging, and the only move left is to want something else.
	if u == null or u.dry_spell < STUBBORN_AFTER:
		return false
	# The clock restarts on the decision, not on the next hit. Without this the
	# unit is over the line on every subsequent tick and re-rolls its target
	# constantly — the dithering the stickiness exists to prevent, arrived at
	# from the other direction.
	u.dry_spell = 0.0
	return true


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


func shoots_through_walls(u: UnitInstance) -> bool:
	## Unlimited range means unlimited: across the whole board and over anything
	## in the way. A band that already ignores distance has no business being
	## stopped by a wall — and the units that have it are the ones whose whole
	## identity is that nothing is out of their reach. It is the one band that
	## does this; a Horizon shot one band below still needs a clear line.
	##
	## Asked in three places — whether the shot connects, where the apex beam
	## draws to, and who the beam catches BEHIND its target — because a beam that
	## targets through stone but stops drawing at it would look like a bug and a
	## beam that stopped catching things behind the wall would be one.
	return u != null and u.range_band() == UnitData.RangeBand.UNLIMITED


func _has_shot(u: UnitInstance, target: UnitInstance) -> bool:
	if shoots_through_walls(u):
		return true
	# Only things that shoot need a clear line — with one exception. A melee unit
	# swinging at the tile beside it never has a wall in the way, but now that it
	# can also reach the four corners, it can be swinging across a barrier. Those
	# still have to be checked.
	if not u.is_ranged():
		if BoardModel.tile_distance(u.cell, target.cell) <= 1:
			return true
		return BoardModel.line_of_fire(u.cell, target.cell, u.team)
	return BoardModel.line_of_fire(u.cell, target.cell, u.team)


func _shot_from(u: UnitInstance, from: Vector2i, target: UnitInstance) -> bool:
	## _has_shot asked about a tile the unit is not standing on yet, which is what a
	## retreat has to know before it commits to the step.
	if shoots_through_walls(u):
		return true
	if not u.is_ranged() and BoardModel.tile_distance(from, target.cell) <= 1:
		return true
	return BoardModel.line_of_fire(from, target.cell, u.team)


func _begin_move(u: UnitInstance) -> bool:
	# Returns whether a step was actually taken. Every `false` here used to be a
	# silently wasted tick — the caller returned regardless, so a unit that could
	# not move also did not attack.
	var next := _next_step(u)
	if next == u.cell:
		return false
	# A gate. The step is not to a neighbouring tile, so none of the adjacency rules
	# below apply to it: there is no edge to be barred, no climb, no wall to swing at
	# and nobody to shove. It is its own branch and it ends here.
	if BoardModel.is_gate(u.cell) and may_use_gate(u) \
			and next == BoardModel.gate_from(u.cell):
		return _step_through_gate(u, next)
	# Belt and braces. The choosers already refuse an illegal climb; this is the
	# one place every move actually happens, so a future chooser that forgets
	# cannot walk a unit up a cliff.
	if not BoardModel.can_climb(u.cell, next):
		return false
	if BoardModel.is_wall(next):
		# The route the field chose runs through stone, which only happens when
		# going round is worse than digging — usually because there is no way
		# round at all. Swing at it rather than step into it.
		return _hit_wall(u, next)
	var from := u.cell
	var dur := maxf(u.stat(StatModifier.Stat.MOVE_TIME) / pressure(), MIN_MOVE_TIME)
	var blocker := board.unit_at(next)
	if blocker != null:
		# _next_step only picks an occupied tile when a friend is standing in the
		# only way through. One that can walk will clear it itself, so we hold
		# our place in the queue rather than barging.
		if blocker.data.can_move:
			return false
		# One that cannot never will, so we trade places with it. The log carries
		# both halves so the view animates a shove, not a teleport.
		if not board.trade_places(u, blocker):
			return false
		blocker.move_from = from
		_emit("move", {uid = blocker.uid, from = next, to = from, duration = dur})
	elif not board.move_unit(u, next):
		return false
	u.move_from = from
	_enter(u, UnitInstance.State.MOVING, dur)
	_emit("move", {uid = u.uid, from = from, to = next, duration = dur})
	return true


func _wander(u: UnitInstance) -> void:
	## One step in a direction it did not choose.
	##
	## Drawn from the simulation's own seeded generator, so a disoriented unit wanders the
	## same way every time the same battle is replayed — the view replays an event log and
	## a unit that took a different path on playback than it did in the simulation would
	## desync the board from the model for the rest of the round.
	##
	## A blocked or occupied choice is simply a step not taken rather than a re-roll: a
	## unit hemmed in by its own line mills about on the spot, which is what being lost in
	## a crowd looks like.
	u.target = null
	if not u.can_move_now():
		return
	# The same offsets the pathfinder uses, so a wandering unit cannot reach a tile a
	# walking one could not.
	var dirs := _neighbour_offsets()
	var to: Vector2i = u.cell + dirs[rng.randi_range(0, dirs.size() - 1)]
	if not board.in_bounds(to) or not board.is_empty(to):
		return
	if BoardModel.is_blocked(to) or not BoardModel.can_climb(u.cell, to):
		return
	if BoardModel.blocks_between(u.cell, to):
		return
	var from := u.cell
	if not board.move_unit(u, to):
		return
	var dur := maxf(u.stat(StatModifier.Stat.MOVE_TIME) / pressure(), MIN_MOVE_TIME)
	u.move_from = from
	_enter(u, UnitInstance.State.MOVING, dur)
	_emit("move", {uid = u.uid, from = from, to = to, duration = dur})


func may_use_gate(u: UnitInstance) -> bool:
	## Whether this unit may go through a gate: it has not spent its own transit, and
	## its side has a transit left to spend. See GATE_TRANSITS_PER_TEAM.
	if u == null or u.gate_used:
		return false
	return _gate_used[u.team] < GATE_TRANSITS_PER_TEAM


func gate_transits(team: int) -> int:
	return _gate_used[team]


func _step_through_gate(u: UnitInstance, to: Vector2i) -> bool:
	## In one pad and out the other. Costs the unit a normal step of movement time,
	## so a gate is a shortcut in DISTANCE and not a free action — a unit that could
	## cross the board instantly would make the far half's back rank indefensible.
	if not board.in_bounds(to) or not board.is_empty(to):
		return false
	var from := u.cell
	if not board.move_unit(u, to):
		return false
	u.gate_used = true
	_gate_used[u.team] += 1
	var dur := maxf(u.stat(StatModifier.Stat.MOVE_TIME) / pressure(), MIN_MOVE_TIME)
	u.move_from = from
	_enter(u, UnitInstance.State.MOVING, dur)
	# Its own event, not a "move": the view must NOT interpolate across the board,
	# and a unit sliding through the intervening ten tiles is exactly what would
	# happen if this were a move. The view flashes both pads and puts the unit down
	# at the far one.
	_emit("gate", {uid = u.uid, from = from, to = to, duration = dur})
	return true


func _begin_attack(u: UnitInstance) -> void:
	# Reset on the SWING, not on the hit. What the timer measures is "am I
	# getting anywhere", and a shot that misses or is absorbed still means this
	# unit is in the fight rather than walking round a rock.
	u.dry_spell = 0.0
	var victim := u.target
	var dmg := u.stat(StatModifier.Stat.ATTACK_DAMAGE)
	var cd := attack_interval(u)
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
	# pierce_now() rather than the data field, because a Martyr inside its window cuts
	# through the rank in front of it and an ordinary unit does not.
	var extra := u.pierce_now() - 1
	if extra > 0:
		for v in _pierce_beyond(u.cell, victim, extra, u.team,
				shoots_through_walls(u)):
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
	# A husk that connects is back inside something. Last, after everything the
	# swing does, so it is a live enemy that survived the blow being taken over
	# rather than a corpse — _reinfect checks that itself, but the ordering also
	# means the damage numbers read in the order they happened.
	if u.is_husk():
		_reinfect(u, victim)


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


func beam_cells(from: Vector2i, toward: Vector2i,
		team := BoardModel.NOBODY, through_walls := false) -> Array[Vector2i]:
	# The line the beam travels, from the shooter to the far edge of the board.
	# `through_walls` is the apex Transcendence: its beam does not stop at stone,
	# it goes through it, so the line runs to the edge of the board regardless of
	# what is standing in the way.
	var out: Array[Vector2i] = []
	var step := Vector2i(signi(toward.x - from.x), signi(toward.y - from.y))
	if step == Vector2i.ZERO:
		return out
	var c := from + step
	while board.in_bounds(c):
		if not through_walls and BoardModel.blocks_sight(c, team):
			break
		out.append(c)
		c += step
	return out


func _beam_wash(u: UnitInstance, victim: UnitInstance, dmg: float,
		struck: Dictionary) -> void:
	var line := beam_cells(u.cell, victim.cell, u.team, shoots_through_walls(u))
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
		team: int, through_walls := false) -> Array[UnitInstance]:
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
		if not through_walls and BoardModel.blocks_sight(c, team):
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
		AbilityData.Kind.FREEZE:
			_resolve_freeze(u, ab)
		AbilityData.Kind.DISORIENT:
			_resolve_disorient(u, ab)
		AbilityData.Kind.CHARGE:
			_resolve_charge(u, ab)
		AbilityData.Kind.POSSESS:
			_resolve_possess(u, ab)
		AbilityData.Kind.TAUNT:
			_resolve_taunt(u, ab)
		AbilityData.Kind.REFLECT:
			_resolve_reflect(u, ab)
		AbilityData.Kind.RAISE:
			_resolve_raise(u, ab)
		AbilityData.Kind.ASCEND:
			_resolve_ascend(u, ab)
		AbilityData.Kind.SAP:
			_resolve_sap(u, ab)
		AbilityData.Kind.BUILD:
			_resolve_build(u, ab)
		AbilityData.Kind.SHELL:
			_resolve_shell(u, ab)
		AbilityData.Kind.DRAIN:
			_resolve_drain(u, ab)


func _resolve_blink(u: UnitInstance, ab: AbilityData, target: UnitInstance) -> void:
	var victim := _backline_enemy(u)
	if victim == null:
		victim = target if target != null and target.is_alive() else board.nearest_enemy(u)
	if victim == null:
		_emit("ability", {uid = u.uid, ability = ab.id, kind = ab.kind,
			cell = u.cell, wasted = true})
		return

	# The cloak goes on BEFORE the jump, not after it. Mechanically it barely
	# matters — nothing can retarget inside one instant — but it is the order the
	# ability describes: it disappears, and then it is behind you. Emitted first so
	# the view can show the vanish and then the arrival rather than the reverse.
	u.stealth_left = ab.stealth_time
	_emit("stealth", {uid = u.uid, on = true, duration = ab.stealth_time,
		cell = u.cell})

	var landing := _behind_cell(u, victim)
	var from := u.cell
	if landing != u.cell and board.teleport(u, landing):
		_emit("blink", {uid = u.uid, from = from, to = landing})

	var dmg := ab.blink_base_damage * pow(2.0, float(u.data.tier - 1))
	_emit("ability", {uid = u.uid, ability = ab.id, kind = ab.kind,
		cell = u.cell, target_cell = victim.cell, amount = dmg})
	_damage(victim, dmg, u, true)


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
		if ally == u or not ally.is_alive() or ally.is_suppressed():
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

	# BEFORE the heal, and the order is the whole point. The Vexer's poison stops
	# its target being healed at all, so a cleanse that ran afterwards would lift
	# the poison off a unit it had just failed to heal, and the Seraph would read
	# as useless against the one unit it most obviously answers. Lifted first, the
	# heal lands the same tick.
	if ab.cleanses:
		var lifted := patient.cleanse()
		if not lifted.is_empty():
			_emit("cleanse", {uid = patient.uid, cell = patient.cell,
				removed = lifted})

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
	# ceil() rather than round(), so a rate of 0.5 gives 1 at tier 1 rather than
	# 0 — a retinue unit with no retinue at its lowest tier is just a bad unit.
	return clampi(ceili(float(u.data.tier) * maxf(ab.summon_per_tier, 0.01)),
		1, maxi(ab.summon_max, 1))


func extra_summons(u: UnitInstance) -> int:
	var tb: TeamBuffs = team_buffs.get(u.team, null)
	return tb.extra_summons_for(u) if tb != null else 0


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
		# Buffs add to what a single cast produces, not to the lifetime cap. For
		# the Spire that is the whole of it: the cast is once and then the unit is
		# gone, so "more per cast" and "more, full stop" are the same sentence.
		var want := maxi(ab.summon_count, 1) + extra_summons(u)
		return mini(want, maxi(cap - u.summons_made, 0))
	# A retinue is measured by who is standing, and a cast refills it. That is
	# what makes a tier 6 Conjurer open with six wisps rather than one, and what
	# lets it replace one that dies instead of being done for the round.
	var want := maxi(cap - retinue_size(u), 0)
	# Except when the thing is built on the caster's OWN tile. There is one tile
	# to give, so an Engineer entitled to three Sentries builds them one cast at
	# a time rather than stacking three turrets on one square.
	if ab.summon_at_caster:
		want = mini(want, 1)
	return want


func _resolve_reflect(u: UnitInstance, ab: AbilityData) -> void:
	u.reflect_left = ab.reflect_duration
	_emit("ability", {uid = u.uid, ability = ab.id, kind = ab.kind,
		cell = u.cell, duration = ab.reflect_duration,
		percent = ab.reflect_percent})


func _resolve_freeze(u: UnitInstance, ab: AbilityData) -> void:
	# Whatever the unit was already aiming at. A freeze aimed somewhere other than
	# the thing the caster is shooting would split its own focus, and the point of
	# the amp is that everything else piles onto the same target.
	var mark := u.target
	if mark == null or not mark.is_alive() or mark.team == u.team:
		mark = board.nearest_enemy(u)
	if mark == null or not mark.is_alive():
		_wasted_summon(u, ab, "no_target")
		return
	var tier := float(u.data.tier)
	# Both read off the caster HERE and frozen into the victim, not read live off
	# the caster while the freeze runs: killing the caster does not thaw anything,
	# and a buff picked mid-round does not deepen a freeze already in progress.
	var seconds := ab.freeze_seconds_per_tier * tier \
		* maxf(u.stat(StatModifier.Stat.FREEZE_POWER), 0.0)
	var amp := 1.0 + ab.freeze_amp_per_tier * tier \
		* maxf(u.stat(StatModifier.Stat.FREEZE_AMP), 0.0)
	if seconds <= 0.0:
		_wasted_summon(u, ab, "no_target")
		return
	# Longest wins rather than adding. Two casters stacking freeze into a
	# permanent lock is the one outcome nobody enjoys being on the wrong end of,
	# and taking the better of the two keeps a second caster useful without
	# making a target it can never act again.
	mark.frozen_left = maxf(mark.frozen_left, seconds)
	mark.frozen_amp = maxf(mark.frozen_amp, amp)
	# Whatever it was in the middle of is dropped, including a cast it had already
	# paid the mana for.
	mark.state = UnitInstance.State.IDLE
	mark.state_timer = 0.0
	_emit("ability", {uid = u.uid, ability = ab.id, kind = ab.kind,
		cell = u.cell, target_uid = mark.uid, target_cell = mark.cell})
	_emit("freeze", {uid = mark.uid, cell = mark.cell,
		seconds = seconds, amp = amp})


func charge_direction(team: int) -> Vector2i:
	## Straight at the enemy, down the column the unit is standing in. TEAM_A holds
	## the low rows and TEAM_B the high ones, so "forward" is the only direction
	## either of them could mean.
	return Vector2i(0, 1) if team == BoardModel.TEAM_A else Vector2i(0, -1)


func charge_damage_of(u: UnitInstance, ab: AbilityData) -> float:
	## A multiple of the unit's own attack damage, times its tier. Off attack
	## rather than a flat figure so it rides every buff that sharpens the unit,
	## and times tier because one AbilityData is shared by all six tiers — a flat
	## number here would leave a tier 6 charging for exactly what a tier 1 does.
	var base := u.stat(StatModifier.Stat.ATTACK_DAMAGE) \
		* ab.charge_damage_per_tier * float(maxi(u.data.tier, 1))
	return base * (1.0 + charge_bonus(u))


func charge_bonus(u: UnitInstance) -> float:
	var tb: TeamBuffs = team_buffs.get(u.team, null)
	return tb.charge_bonus_for(u) if tb != null else 0.0


func stun_seconds_of(u: UnitInstance, ab: AbilityData) -> float:
	var secs := ab.stun_seconds_per_tier * float(maxi(u.data.tier, 1))
	var tb: TeamBuffs = team_buffs.get(u.team, null)
	# The buff adds FLAT seconds rather than a percentage. A percentage of a stun
	# is a number nobody can feel; "one second longer" is one you can count.
	return secs + (tb.stun_bonus_for(u) if tb != null else 0.0)


func charge_tile_seconds(ab: AbilityData) -> float:
	## How long one tile of the run takes. Zero means the old instant charge, which is
	## still a legal thing for an ability to be — it is just no longer what the Breaker
	## is.
	return maxf(ab.charge_tile_seconds, 0.0)


func charge_lane(from: Vector2i, step: Vector2i, reach: int) -> Array[Vector2i]:
	## The tiles the charge intends to cross, stopping at the first wall or edge. What it
	## will actually reach depends on who is standing where when it gets there — this is
	## the telegraph, not the outcome.
	var cells: Array[Vector2i] = []
	var c := from
	for i in maxi(reach, 1):
		var next := c + step
		if not board.in_bounds(next) or BoardModel.is_blocked(next):
			break
		cells.append(next)
		c = next
	return cells


func _resolve_charge(u: UnitInstance, ab: AbilityData) -> void:
	## Starts the run. It does NOT resolve it.
	##
	## This is the whole of the change that makes a charge dodgeable. It used to walk the
	## lane in a single loop and apply the damage in the same tick the unit decided to
	## charge — so the victim was chosen at the moment of the cast, and the run you saw
	## was an animation played afterwards over a result that was already decided. Nothing
	## could get out of the way because there was no interval to get out of the way in.
	##
	## Now the lane is only a telegraph. _tick_charges advances the unit a tile at a time
	## and asks what is in front of it each time it arrives, so a unit that leaves the
	## lane is missed and a unit that wanders into it is hit instead.
	var step := charge_direction(u.team)
	var reach := maxi(ab.charge_distance, 1)
	u.charge_step = step
	u.charge_left = reach
	u.charge_timer = charge_tile_seconds(ab)
	u.state = UnitInstance.State.IDLE
	u.state_timer = 0.0
	u.target = null
	_emit("charge", {uid = u.uid, from = u.cell, dir = step,
		cells = charge_lane(u.cell, step, reach),
		per_tile = charge_tile_seconds(ab)})
	if u.charge_timer <= 0.0:
		# An instant charge still has to go somewhere, and it must not depend on the tick
		# loop reaching it — a zero timer would otherwise resolve one tick late and look
		# like a very short travel time rather than none.
		_run_charge(u, ab, reach)


func _tick_charges() -> void:
	for u in _units:
		if not u.is_alive() or not u.is_charging():
			continue
		if u.is_riding():
			continue
		if u.is_stunned() or u.is_frozen():
			# Knocked out of it. This is the counterplay the travel time buys and it
			# costs nothing to write: a Stasis that freezes a Breaker mid-lane has
			# stopped the charge, not merely delayed the unit.
			_end_charge(u, "stopped")
			continue
		u.charge_timer -= TICK
		if u.charge_timer > 0.0:
			continue
		var ab := u.data.ability
		if ab == null:
			u.stop_charging()
			continue
		# ADDED to whatever is left over rather than reset to a full tile, and the
		# difference is not pedantic. The simulation only advances in whole 0.1s ticks, so
		# resetting rounds every tile UP to the next tick: a stated 0.22s/tile ran at 0.30
		# — a third slower than the number in the data, with no way to ask for anything in
		# between. Carrying the overshoot makes the AVERAGE match the figure, so 0.22
		# alternates two ticks and three and means what it says.
		u.charge_timer += charge_tile_seconds(ab)
		_run_charge(u, ab, 1)


func _run_charge(u: UnitInstance, ab: AbilityData, tiles: int) -> void:
	## Advances the run by up to `tiles` tiles, stopping the moment it meets anything.
	## One tile per call while a charge is travelling; the whole lane in one call for an
	## ability whose charge_tile_seconds is zero.
	for i in tiles:
		if u.charge_left <= 0:
			_end_charge(u, "spent")
			return
		var next := u.cell + u.charge_step
		if not board.in_bounds(next) or BoardModel.is_blocked(next):
			# Stone stops it dead. It does not break through — the charge is a body at
			# speed, not a siege engine, and the Sapper already owns that job.
			_end_charge(u, "wall")
			return
		var who := board.unit_at(next)
		if who != null and who.is_alive():
			# An ALLY stops the charge and takes nothing: there is no friendly fire
			# anywhere else in this game and inventing it here would make the unit a
			# trap rather than a puzzle.
			if who.team == u.team:
				_end_charge(u, "ally")
			else:
				_charge_connects(u, who, ab)
			return
		var from := u.cell
		if not board.move_unit(u, next):
			_end_charge(u, "blocked")
			return
		u.move_from = from
		u.charge_left -= 1
		# Its own event rather than a "move", because the view must draw it as a
		# straight uneased slide and must not treat it as the unit walking.
		_emit("charge_step", {uid = u.uid, from = from, to = next,
			duration = charge_tile_seconds(ab)})
	if u.charge_left <= 0:
		_end_charge(u, "spent")


func _charge_connects(u: UnitInstance, victim: UnitInstance, ab: AbilityData) -> void:
	## The moment of impact, resolved where the runner actually ended up rather than
	## where the lane was pointed when it set off.
	u.stop_charging()
	_emit("charge_end", {uid = u.uid, cell = u.cell, hit = true,
		target_cell = victim.cell, dir = u.charge_step})
	var secs := stun_seconds_of(u, ab)
	if secs > 0.0:
		# Longest wins rather than adding, the same rule the freeze uses: two
		# chargers hitting one unit should not lock it out of the round.
		victim.stun_left = maxf(victim.stun_left, secs)
		victim.state = UnitInstance.State.IDLE
		victim.state_timer = 0.0
		_emit("stun", {uid = victim.uid, cell = victim.cell, seconds = secs})

	_emit("ability", {uid = u.uid, ability = ab.id, kind = ab.kind,
		cell = u.cell, target_cell = victim.cell,
		cells = [victim.cell] as Array[Vector2i]})
	# Damage last, because it can kill — and a dead unit should not be handed a
	# stun, nor should the charge event arrive after the death it caused.
	_damage(victim, charge_damage_of(u, ab), u, true, false)


func _end_charge(u: UnitInstance, reason: String) -> void:
	## Every way a charge stops without connecting. It still moved, which is what makes a
	## charge into an empty lane a real cost rather than a no-op — the unit ends up out
	## of position, at the far end of the board, with the round still going on behind it.
	var dir := u.charge_step
	u.stop_charging()
	u.state = UnitInstance.State.IDLE
	u.state_timer = 0.0
	_emit("charge_end", {uid = u.uid, cell = u.cell, hit = false,
		reason = reason, dir = dir})
	var ab := u.data.ability
	if ab == null:
		return
	# Emitted as a wasted cast so the card's promise and what happened on screen agree.
	# "empty_lane" is kept as the reason for every miss rather than reporting the four
	# ways it can happen, because the card makes one promise and this is it failing.
	_emit("ability", {uid = u.uid, ability = ab.id, kind = ab.kind,
		cell = u.cell, wasted = true, reason = "empty_lane"})


# ---------------------------------------------------------------- possession --
#
# The Usurper does not fight. It gets inside something of yours and then YOU are
# fighting it, which is why almost none of this is damage code.
#
# The shape, in one place, because it is spread over five functions below and the
# order matters in every one of them:
#
#   * At the bell it picks a host and goes inside. The host changes side —
#     `team` is what every count, every targeting sweep and the win condition
#     read, and none of them cache it, so a flip is total and immediate. The
#     Usurper itself comes OFF the board: it is not standing next to its puppet,
#     it is in it, so nothing can shoot it and nothing can be blocked by it.
#   * Same tier is what it wants. Below its tier it drags the host UP to its own
#     tier for the round — a borrowed body, not a gift, and release_possession()
#     is what makes sure the owner does not keep the promotion. Above its tier it
#     cannot get in at all and bursts against it instead.
#   * Kill the puppet and the puppeteer falls out of it with one health. That is
#     the counterplay and it is the whole reason the unit is fair: every point of
#     value it has is sitting inside something you are allowed to shoot.
#   * A husk that lands a blow is back in business, in whatever it just hit.


func possess_candidates(u: UnitInstance) -> Array[UnitInstance]:
	## Everything on the board this Usurper could go for, best first.
	##
	## Ordering is the whole of the rule the user asked for and it is three bands:
	## its own tier, then downwards (nearest tier first), then upwards. Upwards is
	## last because going up is suicide — a unit that killed itself while a safe
	## host was standing four tiles away would just look broken.
	var same: Array[UnitInstance] = []
	var below: Array[UnitInstance] = []
	var above: Array[UnitInstance] = []
	for other in board.units_view():
		if other == u or not other.is_alive() or other.team == u.team:
			continue
		if other.is_possessed():
			# Already has something inside it. Two Usurpers do not share.
			continue
		if other.data.tier == u.data.tier:
			same.append(other)
		elif other.data.tier < u.data.tier:
			below.append(other)
		else:
			above.append(other)

	var here := u.cell
	same.sort_custom(func(a: UnitInstance, b: UnitInstance) -> bool:
		return _closer(a, b, here))
	# Nearest tier first within each band: a tier 4 Usurper would rather drag a
	# tier 3 up than a tier 1, and would rather burst against a tier 5 than a 6.
	below.sort_custom(func(a: UnitInstance, b: UnitInstance) -> bool:
		if a.data.tier != b.data.tier:
			return a.data.tier > b.data.tier
		return _closer(a, b, here))
	above.sort_custom(func(a: UnitInstance, b: UnitInstance) -> bool:
		if a.data.tier != b.data.tier:
			return a.data.tier < b.data.tier
		return _closer(a, b, here))

	var out: Array[UnitInstance] = []
	out.append_array(same)
	out.append_array(below)
	out.append_array(above)
	return out


func _closer(a: UnitInstance, b: UnitInstance, from: Vector2i) -> bool:
	var da := BoardModel.tile_distance(from, a.cell)
	var db := BoardModel.tile_distance(from, b.cell)
	if da != db:
		return da < db
	# uid last so the whole ordering is total — two equally close hosts must not
	# depend on what order the board happened to hand them over in.
	return a.uid < b.uid


func forced_tier_row(host: UnitInstance, tier: int) -> UnitData:
	## The same unit, at `tier`, walked up its own merge chain. Nothing is
	## fabricated: every tier of every unit already exists as a row, so a forced
	## promotion gives a body the game already knows how to draw and balance.
	##
	## Returns null when the chain cannot get there, which is the honest answer for
	## a unit whose chain is shorter than the Usurper's tier.
	var row := host.data
	while row != null and row.tier < tier:
		row = row.next_tier
	return row if row != null and row.tier == tier else null


func backlash_damage(u: UnitInstance, ab: AbilityData, gap: int) -> float:
	## What it costs the winner to shrug it off: a share of the Usurper's own
	## health per tier it was outmatched by.
	##
	## Measured off the DATA row rather than stat(), so a husk — whose maximum
	## health is pinned to 1 — still bursts for what the unit is worth. A husk that
	## threw itself at a tier 6 for one point of damage would make re-infection a
	## trap rather than a second chance.
	return maxf(ab.backlash_per_tier, 0.0) * u.data.max_hp * float(maxi(gap, 1))


func grip_seconds(u: UnitInstance, ab: AbilityData) -> float:
	## How long this Usurper holds on, or -1 for a hold that lasts the round.
	##
	## Measured off the Usurper's OWN tier, not the host's. A tier 5 Usurper dragging
	## a tier 1 up should keep it for as long as its own tier is worth; reading the
	## host's tier would punish it for taking the small body it was forced to take.
	if ab.possess_seconds_per_tier <= 0.0:
		return -1.0
	return maxf(ab.possess_seconds_per_tier * float(u.data.tier), TICK)


func _resolve_possess(u: UnitInstance, ab: AbilityData) -> void:
	var picks := possess_candidates(u)
	if picks.is_empty():
		_emit("ability", {uid = u.uid, ability = ab.id, kind = ab.kind,
			cell = u.cell, wasted = true, reason = "no_host"})
		return
	var host: UnitInstance = picks[0]
	if host.data.tier > u.data.tier:
		_burst_against(u, ab, host)
		return
	_take_host(u, ab, host)


func _burst_against(u: UnitInstance, ab: AbilityData, host: UnitInstance) -> void:
	## Everything left on the board is above its tier, so it cannot get in. It goes
	## off instead.
	var gap := host.data.tier - u.data.tier
	var dmg := backlash_damage(u, ab, gap)
	_emit("ability", {uid = u.uid, ability = ab.id, kind = ab.kind,
		cell = u.cell, target_cell = host.cell, amount = dmg,
		backlash = true, gap = gap})
	_emit("backlash", {uid = u.uid, cell = u.cell, target_uid = host.uid,
		target_cell = host.cell, amount = dmg, gap = gap})
	# Its own death first, so the board is already down a unit before the blow
	# lands — otherwise a host killed by the burst could be raised or revived into
	# a round the Usurper is still nominally alive in.
	u.current_hp = 0.0
	u.shield = 0.0
	u.state = UnitInstance.State.DEAD
	u.target = null
	_fell(u, host.uid, false)
	# Not a spell for reflect purposes: `may_reflect` stays on, because bursting
	# against an Aegis should absolutely come back at it — except there is nothing
	# left to come back at, which _reflect_back already handles by checking the
	# source is alive.
	_damage(host, dmg, u, true, false)


func _take_host(u: UnitInstance, ab: AbilityData, host: UnitInstance) -> void:
	## Goes inside. Order is load-bearing throughout: `home_team` and `home_data`
	## are recorded BEFORE anything is changed, because they are the only record of
	## what has to be handed back at the round boundary, and a possession that
	## cannot be undone is a unit permanently stolen out of a roster.
	host.home_team = host.team
	host.home_data = host.data
	host.puppeteer_uid = u.uid
	u.host_uid = host.uid

	var forced: UnitData = null
	if ab.possess_forces_tier and host.data.tier < u.data.tier:
		forced = forced_tier_row(host, u.data.tier)
		if forced != null:
			host.data = forced

	host.team = u.team
	host.possess_left = grip_seconds(u, ab)
	# It has just changed sides mid-swing: whatever it was aiming at is now a
	# friend. Dropped rather than re-picked here, so _decide does it on the next
	# tick through the ordinary path.
	host.target = null
	host.state = UnitInstance.State.IDLE
	host.state_timer = 0.0
	# Whatever its owner gave it, it keeps. That is deliberate and it is the
	# generous reading: you have not borrowed a blank body, you have turned their
	# investment around and pointed it back at them. Stripping the owner's buffs
	# here was the first attempt and it was worse in every way — an empowered host
	# would have lost its empowerment while still claiming to be empowered, and a
	# full-roster bonus would have vanished for a unit that is still the same body
	# standing on the same tile.
	_apply_host_buffs(u, host)
	if forced != null:
		# A bigger body arrives whole. Done after the buff reseat so the new
		# maximum is the one being filled.
		host.heal_to_full()

	# Off the board. This is what makes the Usurper impossible to answer directly:
	# it is not beside its puppet, it is in it, and the only way to reach it is
	# through the thing it is wearing.
	board.remove(u)
	u.target = null
	u.state = UnitInstance.State.IDLE
	u.state_timer = 0.0

	_emit("possess", {
		uid = u.uid, cell = u.cell, host_uid = host.uid, host_cell = host.cell,
		team = u.team, forced_tier = 0 if forced == null else forced.tier,
		host_name = host.data.display_name,
		hp = host.current_hp, max_hp = host.stat(StatModifier.Stat.MAX_HP),
	})
	_emit("ability", {uid = u.uid, ability = ab.id, kind = ab.kind,
		cell = u.cell, target_cell = host.cell,
		cells = [host.cell] as Array[Vector2i]})


func host_bonuses(team: int) -> Dictionary:
	## What the puppeteer's side has bought for whatever it is wearing. Two
	## separately-scoped halves and they are separate because the user asked for
	## them separately: `move` is given to the Usurper AND its host, `power` only to
	## the host.
	##
	## The Usurper's own half of the movement is an ordinary unit-scoped stat buff
	## and does not appear here — it is already on the unit before the bell.
	var tb: TeamBuffs = team_buffs.get(team, null)
	if tb == null:
		return {move = 0.0, power = 0.0}
	return {move = tb.host_move_bonus(), power = tb.host_power_bonus()}


func possess_weakness_of(u: UnitInstance) -> float:
	## How much weaker this Usurper's puppets are, after its tier has paid some of it off.
	## Clamped at zero rather than allowed to go negative: past the tier where the penalty
	## runs out, a stolen body is simply at full strength — it does not start getting
	## BETTER than the unit it was taken from.
	if u == null or u.data == null or u.data.ability == null:
		return 0.0
	var ab := u.data.ability
	var paid := ab.possess_weakness_per_tier * float(maxi(u.data.tier, 1) - 1)
	return clampf(ab.possess_weakness - paid, 0.0, 1.0)


func _apply_host_buffs(u: UnitInstance, host: UnitInstance) -> void:
	## The Usurper buff's host-only half, applied at the moment the reins change
	## hands. Battle modifiers, so the round boundary takes them away — a host
	## handed back to its owner must not still be carrying the thief's buff.
	var bonus := host_bonuses(u.team)
	var move: float = bonus.move
	var power: float = bonus.power
	var lent: Array[StatModifier] = []
	if move > 0.0:
		# MOVE_TIME is seconds per tile, so "75% faster" is not +0.75 here. Routed
		# through the same conversion the buff table uses rather than repeating the
		# arithmetic, because writing +0.75 by hand makes the unit SLOWER and the
		# mistake does not announce itself.
		lent.append(StatModifier.make(
			StatModifier.Stat.MOVE_TIME, StatModifier.Mode.PERCENT,
			BuffData.signed_percent(StatModifier.Stat.MOVE_TIME, move)))
	if power > 0.0:
		lent.append(StatModifier.make(
			StatModifier.Stat.ATTACK_DAMAGE, StatModifier.Mode.PERCENT, power))
		lent.append(StatModifier.make(
			StatModifier.Stat.MAX_HP, StatModifier.Mode.PERCENT, power))
	# The ability's own penalty, on top of whatever the buff lent. It goes in the SAME
	# list on purpose: release_possession removes exactly what is in lent_modifiers, so a
	# debuff recorded anywhere else would survive the hand-back and quietly follow the
	# host around for the rest of the round as its owner's unit.
	var weak := possess_weakness_of(u)
	if weak > 0.0:
		lent.append(StatModifier.make(
			StatModifier.Stat.ATTACK_DAMAGE, StatModifier.Mode.PERCENT, -weak))
		lent.append(StatModifier.make(
			StatModifier.Stat.MAX_HP, StatModifier.Mode.PERCENT, -weak))
	for m in lent:
		host.add_battle_modifier(m)
	# Remembered, so a timed release can hand back exactly what was lent and leave
	# the host's own empowerment and roster bonuses alone.
	host.lent_modifiers = lent
	if weak > 0.0:
		# The maximum just fell, so the bar has to come down with it — a unit left holding
		# more health than its maximum reads as a full bar that will not move when it is
		# hit, and heals back to a cap that no longer exists.
		host.current_hp = minf(host.current_hp, host.stat(StatModifier.Stat.MAX_HP))
	if power > 0.0:
		# The bigger body is filled, exactly as an empowerment or a forced tier is:
		# a unit that gains maximum health and stays on the old number has been
		# given a worse deal than the card promises.
		host.heal_to_full()


func _tick_husk_slow(u: UnitInstance, ab: AbilityData) -> void:
	## The husk's one stat change. A battle modifier so the round boundary takes it
	## away with everything else, and PERCENT on MOVE_TIME, which is seconds per
	## tile — a positive value here makes it slower. See BuffData._signed for why
	## that trap is worth naming every time it comes up.
	var mult := maxf(ab.husk_move_mult, 1.0)
	if is_equal_approx(mult, 1.0):
		return
	u.add_battle_modifier(StatModifier.make(
		StatModifier.Stat.MOVE_TIME, StatModifier.Mode.PERCENT, mult - 1.0))


func _tick_shields() -> void:
	## Runs every standing shield's clock down. The unit owns the arithmetic — see
	## UnitInstance.tick_shield — and this only has to tell the view when a bar has
	## gone, because the view has no clock of its own.
	for u in _units:
		if u.shield_left <= 0.0 or not u.is_alive():
			continue
		if u.tick_shield(TICK):
			_emit("shield", {uid = u.uid, shield = 0.0})
			_emit("shield_gone", {uid = u.uid, cell = u.cell})


func _tick_possessions() -> void:
	## Runs down a timed grip. Does nothing at all for the default, whole-round
	## possession, which carries possess_left = -1.
	for u in _units:
		if u.possess_left < 0.0 or not u.is_possessed():
			continue
		u.possess_left -= TICK
		if u.possess_left > 0.0:
			continue
		# Order: the puppeteer comes out FIRST, while the host's cell is still the
		# right place to look, and the host is handed back second.
		_eject_husk(u, true)
		var home := u.home_team
		u.release_possession()
		u.target = null
		u.state = UnitInstance.State.IDLE
		u.state_timer = 0.0
		_emit("possess_end", {uid = u.uid, cell = u.cell, team = home,
			hp = u.current_hp, max_hp = u.stat(StatModifier.Stat.MAX_HP),
			tier = u.data.tier})


func _eject_husk(host: UnitInstance, timed := false) -> void:
	## Called from _fell the moment a possessed unit dies, and from
	## _tick_possessions when a timed grip runs out. Puts the puppeteer back on the
	## board at its puppet's shoulder, with one health.
	##
	## `timed` is the difference between the two callers: on a death the host's tile
	## has just been vacated and is the obvious place to stand, but a host that is
	## still alive is standing on it, so the husk has to take the nearest free tile
	## instead.
	var u := _unit_by_uid(host.puppeteer_uid)
	# Cleared whatever happens, so a revived host is an ordinary unit rather than
	# one still claiming to be ridden by something that has already fallen out.
	host.puppeteer_uid = -1
	if u == null or u.host_uid != host.uid:
		return
	u.host_uid = -1
	if not u.is_alive():
		# It died inside — a burst, or sudden death arithmetic. Nothing to eject.
		return

	u.hp_locked = true
	u.current_hp = 1.0
	u.shield = 0.0
	u.target = null
	u.state = UnitInstance.State.IDLE
	u.state_timer = 0.0
	var ab := u.data.ability
	if ab != null:
		_tick_husk_slow(u, ab)

	# The host's tile was vacated by _fell immediately before this, so it is
	# normally free. The fallback is for the one case it is not: a trade or a
	# summon that took the tile in the same instant — or a timed release, where the
	# host is alive and still standing there.
	var at := _nearest_free(host.cell) if timed else host.cell
	if at.x < 0 or not board.force_place(u, at):
		at = _nearest_free(host.cell)
		if at.x < 0 or not board.force_place(u, at):
			# Nowhere to stand. It stays off the board rather than being dropped on
			# top of somebody, and the round ends without it — which is the same
			# outcome as dying, reached honestly.
			u.current_hp = 0.0
			u.state = UnitInstance.State.DEAD
			_emit("death", {uid = u.uid, cell = host.cell,
				killer_uid = -1, frozen = false, overkill = false})
			return
	u.move_from = at

	_emit("husk", {uid = u.uid, cell = at, from_uid = host.uid,
		hp = 1.0, max_hp = 1.0})


func _nearest_free(from: Vector2i) -> Vector2i:
	var best := Vector2i(-1, -1)
	var best_d := 1 << 30
	for c in board.free_cells():
		var d := BoardModel.tile_distance(from, c)
		if d < best_d or (d == best_d and (c.y < best.y or (c.y == best.y and c.x < best.x))):
			best = c
			best_d = d
	return best


func _reinfect(u: UnitInstance, victim: UnitInstance) -> void:
	## A husk that lands a blow gets back inside. Same rules as the opening bell,
	## except the host is decided for it — it is whatever it just hit.
	if not u.is_husk() or u.is_riding() or victim == null:
		return
	if not victim.is_alive() or victim.team == u.team or victim.is_possessed():
		return
	var ab := u.data.ability
	if ab == null or ab.kind != AbilityData.Kind.POSSESS:
		return
	if victim.data.tier > u.data.tier:
		_burst_against(u, ab, victim)
		return
	_take_host(u, ab, victim)


func disorient_seconds_of(u: UnitInstance, ab: AbilityData) -> float:
	## How long this caster's disorientation lasts.
	##
	## The cap applies to the TIER ladder only. A buff that lengthens it adds on top,
	## because the cap describes how far the unit gets on its own — not how long anything
	## can ever be disoriented for. Written the other way round the buff would be worth
	## nothing at all on the tier where you most want it.
	var tiers := float(maxi(u.data.tier, 1) - 1)
	var own := minf(ab.disorient_seconds + ab.disorient_seconds_per_tier * tiers,
		maxf(ab.disorient_max, 0.0))
	var tb: TeamBuffs = team_buffs.get(u.team, null)
	return maxf(own, 0.0) + (tb.disorient_bonus_for(u) if tb != null else 0.0)


func _resolve_disorient(u: UnitInstance, ab: AbilityData) -> void:
	## Sends one enemy reeling. Whatever the caster was already shooting at, so the
	## disorientation lands on the unit its own side is already working on rather than
	## splitting the army's attention — the same rule the freeze uses.
	var mark := u.target
	if mark == null or not mark.is_alive() or mark.team == u.team \
			or mark.is_disorient_immune():
		mark = _nearest_disorientable(u)
	if mark == null:
		_wasted_summon(u, ab, "no_target")
		return
	var secs := disorient_seconds_of(u, ab)
	if secs <= 0.0:
		_wasted_summon(u, ab, "no_target")
		return
	# RESET, not extended, and not "longest wins". Catching a unit that is already
	# reeling starts its count again from the top — which is what was asked for, and it
	# is a different rule from the freeze deliberately: the immunity below is what stops
	# it becoming a permanent lock, so the reset does not have to.
	mark.disorient_left = secs
	# Recorded now, spent when the clock runs out. See UnitInstance.disorient_immune_after.
	mark.disorient_immune_after = maxf(ab.disorient_immunity, 0.0)
	# Whatever it was in the middle of is dropped. A unit that keeps its half-finished
	# swing and lands it a moment after being sent reeling reads as the ability failing.
	mark.state = UnitInstance.State.IDLE
	mark.state_timer = 0.0
	mark.target = null
	_emit("ability", {uid = u.uid, ability = ab.id, kind = ab.kind,
		cell = u.cell, target_cell = mark.cell,
		cells = [mark.cell] as Array[Vector2i]})
	_emit("disorient", {uid = mark.uid, cell = mark.cell, seconds = secs,
		source_uid = u.uid})


func _nearest_disorientable(u: UnitInstance) -> UnitInstance:
	## The closest enemy that is not already immune. Immunity is checked HERE rather than
	## only at the moment of application, or the cast picks the one unit it cannot touch
	## and is wasted while three others stand in range.
	var best: UnitInstance = null
	var best_gap := 1 << 30
	for v in _units:
		if not v.is_alive() or v.team == u.team or v.is_disorient_immune():
			continue
		var gap := BoardModel.tile_distance(u.cell, v.cell)
		if gap < best_gap:
			best_gap = gap
			best = v
	return best


func _tick_disorient() -> void:
	for u in _units:
		if u.disorient_immune_left > 0.0:
			u.disorient_immune_left = maxf(u.disorient_immune_left - TICK, 0.0)
		if u.disorient_left <= 0.0:
			continue
		u.disorient_left -= TICK
		if u.disorient_left > 0.0:
			continue
		u.disorient_left = 0.0
		# The immunity starts the moment it comes OUT of it, not when it went in. Started
		# at the other end it would overlap the disorientation itself and a long one would
		# burn most of its own protection.
		u.disorient_immune_left = maxf(u.disorient_immune_after, 0.0)
		u.disorient_immune_after = 0.0
		_emit("disorient_end", {uid = u.uid, cell = u.cell,
			immune = u.disorient_immune_left})


func _tick_stuns() -> void:
	for u in _units:
		if u.stun_left <= 0.0:
			continue
		u.stun_left -= TICK
		if u.stun_left <= 0.0:
			u.stun_left = 0.0
			_emit("stun_end", {uid = u.uid, cell = u.cell})


func _tick_freezes() -> void:
	for u in _units:
		if u.frozen_left <= 0.0:
			continue
		u.frozen_left -= TICK
		if u.frozen_left <= 0.0:
			u.frozen_left = 0.0
			u.frozen_amp = 1.0
			_emit("thaw", {uid = u.uid, cell = u.cell})


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
	# Radius as well as cells: the view redraws this every frame around the
	# caster's live position, so a fixed list of tiles from the moment of the cast
	# would be left behind the first time the Wellspring took a step.
	_emit("aura_zone", {uid = u.uid, cells = cells, team = u.team,
		radius = ab.mana_aura_radius})


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
	_emit("death", {uid = u.uid, cell = where,
		killer_uid = -1, consumed = true, overkill = false})


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
		var vacated := _vacate_for_build(u)
		if vacated != Vector2i(-1, -1):
			out.append(vacated)
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


func _vacate_for_build(u: UnitInstance) -> Vector2i:
	# The builder rule, in one place because two units follow it: whatever gets
	# built takes the BUILDER'S tile and the builder steps off. Never the other
	# way round — a Sentry that shuffled over to make room would be a turret in a
	# place nobody chose, and the whole point of both units is that where you
	# stand them is where the thing goes.
	#
	# Returns the tile it vacated, or (-1, -1) if it is boxed in and could not
	# step anywhere. Callers fall back to building beside it rather than wasting
	# the cast: being unable to move is not a reason to produce nothing.
	#
	# The Conjurer is deliberately not on this path. Its wisps are a retinue that
	# arrives around it, not a thing it puts down, so it never moves for them.
	var here := u.cell
	var step := _step_aside(u)
	if step == Vector2i(-1, -1) or not board.move_unit(u, step):
		return Vector2i(-1, -1)
	u.move_from = here
	_emit("move", {uid = u.uid, from = here, to = step, duration = DISPLACE_TIME})
	return here


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
		# Anything that arrives DURING sudden death arrives under it. Without this
		# a summoner would be an unlimited source of healable, shieldable bodies in
		# exactly the fifteen seconds meant to stop the round going round forever —
		# and the newest unit on the board would be the only one playing by the old
		# rules.
		u.recovery_denied = _sudden_death
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
			if ally == caster or ally.data.ability == null or ally.is_suppressed():
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


static func cross_cells(centre: Vector2i, arm: int) -> Array[Vector2i]:
	# A plus sign, centre first. Not a box and not a diamond — the arms run along
	# the axes only, so where the shell is aimed decides which rank it catches.
	var out: Array[Vector2i] = [centre]
	for step in range(1, arm + 1):
		out.append(centre + Vector2i(step, 0))
		out.append(centre + Vector2i(-step, 0))
		out.append(centre + Vector2i(0, step))
		out.append(centre + Vector2i(0, -step))
	return out


func _thickest_cluster(u: UnitInstance, arm: int) -> UnitInstance:
	# Which enemy has the most of its friends sharing a cross with it. Ties go to
	# the closest, so on a spread-out board this is simply "the nearest enemy" and
	# the unit reads as an ordinary sniper until a clump forms.
	var best: UnitInstance = null
	var best_hits := -1
	var best_d := 1 << 30
	for other in _units:
		if other.team == u.team or not other.is_alive() or other.is_hidden():
			continue
		var hits := 0
		for c in cross_cells(other.cell, arm):
			var v := board.unit_at(c)
			if v != null and v.is_alive() and v.team != u.team:
				hits += 1
		var d := BoardModel.tile_distance(u.cell, other.cell)
		if hits > best_hits or (hits == best_hits and d < best_d):
			best = other
			best_hits = hits
			best_d = d
	return best


func shell_damage_of(u: UnitInstance, ab: AbilityData) -> float:
	return u.stat(StatModifier.Stat.ATTACK_DAMAGE) \
		* maxf(ab.shell_attack_multiple, 0.0)


func _resolve_shell(u: UnitInstance, ab: AbilityData) -> void:
	var mark := _thickest_cluster(u, ab.shell_arm)
	if mark == null:
		_emit("ability", {uid = u.uid, ability = ab.id, kind = ab.kind,
			cell = u.cell, wasted = true, reason = "no_target"})
		return
	# Aimed at the TILE, not at the unit. Once it is in the air the shell is
	# committed to a piece of ground, so walking off it works — which is the whole
	# reason the flight time exists.
	var at := mark.cell
	_shells.append({
		source_uid = u.uid, team = u.team, cell = at,
		left = maxf(ab.shell_flight, TICK),
		damage = shell_damage_of(u, ab),
		direct = ab.shell_direct, splash = ab.shell_splash, arm = ab.shell_arm,
		field = ab.field_damage, field_left = ab.field_seconds,
	})
	_emit("shell_away", {
		uid = u.uid, from = u.cell, cell = at,
		flight = maxf(ab.shell_flight, TICK),
		cells = cross_cells(at, ab.shell_arm),
	})
	_emit("ability", {uid = u.uid, ability = ab.id, kind = ab.kind,
		cell = u.cell, target_cell = at})


func _tick_shells() -> void:
	if _shells.is_empty():
		return
	var i := _shells.size() - 1
	while i >= 0:
		var sh: Dictionary = _shells[i]
		sh.left -= TICK
		if sh.left <= 0.0:
			_land_shell(sh)
			_shells.remove_at(i)
		i -= 1


func _land_shell(sh: Dictionary) -> void:
	var firer := _unit_by_uid(sh.source_uid)
	var centre: Vector2i = sh.cell
	var hit: Array[Vector2i] = cross_cells(centre, sh.arm)
	var struck: Array[Vector2i] = []
	for c in hit:
		if not board.in_bounds(c):
			continue
		struck.append(c)
		var v := board.unit_at(c)
		if v == null or not v.is_alive() or v.team == sh.team:
			continue
		var share: float = sh.direct if c == centre else sh.splash
		# The shell has no owner to credit if the Culverin died mid-flight, but it
		# still lands. `firer` may be null; _damage wants a source, so a shell from
		# a dead gun is credited to its victim with no lifesteal and no hp bonus.
		_damage(v, float(sh.damage) * share, firer if firer != null else v,
			true, firer != null)
	_emit("shell_land", {
		cell = centre, cells = struck, amount = float(sh.damage) * float(sh.direct),
	})
	# And the ground keeps burning. Enemies only: your own line walks through its
	# own fire, which is what keeps the unit usable when it is badly placed.
	if sh.field > 0.0 and sh.field_left > 0.0:
		for c in struck:
			_fields.append({
				cell = c, team = sh.team, clock = 0.0,
				damage = float(sh.damage) * float(sh.field),
				left = float(sh.field_left), source_uid = sh.source_uid,
			})
		_emit("field_up", {
			cells = struck, team = sh.team, seconds = float(sh.field_left),
		})


func field_at(cell: Vector2i, team: int) -> float:
	# Damage a second this tile would do to a unit of `team` standing on it. Zero
	# for the side that laid it, which is also how the pathing nudge stays free:
	# _distance_field asks this and prices the tile up if it answers.
	var total := 0.0
	for f in _fields:
		if f.cell == cell and f.team != team:
			total += float(f.damage)
	return total


func _tick_fields() -> void:
	if _fields.is_empty():
		return
	var done: Array[Vector2i] = []
	var i := _fields.size() - 1
	while i >= 0:
		var f: Dictionary = _fields[i]
		f.left -= TICK
		f.clock += TICK
		if f.clock + 0.0001 >= 1.0:
			f.clock -= 1.0
			var v := board.unit_at(f.cell)
			if v != null and v.is_alive() and v.team != f.team:
				var src := _unit_by_uid(f.source_uid)
				_damage(v, float(f.damage), src if src != null else v, true, false)
		if f.left <= 0.0:
			done.append(f.cell)
			_fields.remove_at(i)
		i -= 1
	if not done.is_empty():
		_emit("field_down", {cells = done})


func _fattest_enemy(u: UnitInstance) -> UnitInstance:
	# Biggest MAX health anywhere on the board — no range check at all, which is
	# the whole of "infinite range on the cast". Max health rather than current, so
	# it commits to the thing that is genuinely hard to kill rather than to
	# whatever happens to be full at that moment.
	var best: UnitInstance = null
	var best_hp := -1.0
	for other in _units:
		if other.team == u.team or not other.is_alive() or other.is_hidden():
			continue
		var hp := other.stat(StatModifier.Stat.MAX_HP)
		if hp > best_hp:
			best = other
			best_hp = hp
	return best


func drain_percent_of(u: UnitInstance, ab: AbilityData) -> float:
	## The slice this Leech takes per tick. Linear in tier rather than doubling,
	## because the slice is already a fraction of a maximum that doubles — compound
	## both and a tier 6 Siphon would delete a tier 6 Warden in under two seconds.
	return maxf(ab.drain_percent
		+ ab.drain_percent_per_tier * float(u.data.tier - 1), 0.0)


func _resolve_drain(u: UnitInstance, ab: AbilityData) -> void:
	var victim := _fattest_enemy(u)
	if victim == null:
		_emit("ability", {uid = u.uid, ability = ab.id, kind = ab.kind,
			cell = u.cell, wasted = true, reason = "no_target"})
		return
	# Stacking on purpose, and not deduplicated: two Leechs on one Transcendence
	# drain it twice as fast, and so does one Leech casting twice.
	# Baked in at the moment it fastens on, not read live, for the same reason the
	# freeze multiplier is: it is the number the Leech had when it cast, so merging
	# the Leech up afterwards does not deepen a bite that is already running.
	var slice := drain_percent_of(u, ab)
	_drains.append({
		source_uid = u.uid, victim = victim, percent = slice,
		clock = 0.0, interval = maxf(ab.drain_interval, TICK),
	})
	_emit("drain_start", {
		uid = u.uid, target_uid = victim.uid, cell = victim.cell,
		percent = slice,
	})
	_emit("ability", {uid = u.uid, ability = ab.id, kind = ab.kind,
		cell = u.cell, target_cell = victim.cell})


func drains_on(victim: UnitInstance) -> int:
	var n := 0
	for d in _drains:
		if d.victim == victim:
			n += 1
	return n


func _tick_drains() -> void:
	if _drains.is_empty():
		return
	var i := _drains.size() - 1
	while i >= 0:
		var d: Dictionary = _drains[i]
		var victim: UnitInstance = d.victim
		if victim == null or not victim.is_alive():
			# Until death, and no longer. A drain does not carry over to whatever
			# the victim's team fields next.
			_emit("drain_end", {uid = int(d.source_uid), target_uid = victim.uid})
			_drains.remove_at(i)
			i -= 1
			continue
		d.clock += TICK
		if d.clock + 0.0001 >= float(d.interval):
			d.clock -= float(d.interval)
			# Of MAX health, and shields are not part of that — a Warden cannot
			# hide behind one, and the bite does not shrink as the victim wears
			# down. That is what makes it an answer to something enormous.
			var bite := victim.stat(StatModifier.Stat.MAX_HP) * float(d.percent)
			var src := _unit_by_uid(int(d.source_uid))
			if src != null and src.is_alive():
				# Through _damage, so the Leech's lifesteal applies to it.
				_damage(victim, bite, src, true, false)
			else:
				# The Leech is dead. Its drain dies with it.
				_emit("drain_end", {uid = int(d.source_uid), target_uid = victim.uid})
				_drains.remove_at(i)
		i -= 1


func _terrain_ring(u: UnitInstance, reach: int) -> Array[Vector2i]:
	# Every tile within reach, nearest first, ties broken by a fixed scan order.
	# Deterministic on purpose: which wall comes down decides where the whole army
	# walks next, so it must not depend on dictionary iteration order.
	var out: Array[Vector2i] = []
	for dy in range(-reach, reach + 1):
		for dx in range(-reach, reach + 1):
			var c := u.cell + Vector2i(dx, dy)
			if c != u.cell and board.in_bounds(c):
				out.append(c)
	var origin := u.cell
	out.sort_custom(func(a: Vector2i, b: Vector2i) -> bool:
		var da := BoardModel.box_distance(origin, a)
		var db := BoardModel.box_distance(origin, b)
		if da != db:
			return da < db
		if a.y != b.y:
			return a.y < b.y
		return a.x < b.x)
	return out


func _resolve_sap(u: UnitInstance, ab: AbilityData) -> void:
	# Toward the enemy first. A Sapper that knocks down the wall behind it has
	# done nothing; the whole unit is about opening the route its army wants.
	var forward := 1 if u.team == BoardModel.TEAM_A else -1
	var ring := _terrain_ring(u, ab.terrain_reach)
	var ahead: Array[Vector2i] = []
	var behind: Array[Vector2i] = []
	for c in ring:
		if (c.y - u.cell.y) * forward >= 0:
			ahead.append(c)
		else:
			behind.append(c)
	var order := ahead
	order.append_array(behind)

	# A heavy blow rather than a deletion. The wall has health now, so the cast
	# is worth several ordinary swings and the tier decides how many — a tier 6
	# charge takes any map wall down on its own, a tier 1 charge does not.
	var blast := wall_damage_of(u) * maxf(ab.sap_burst_multiple, 1.0)
	var gone: Array[Vector2i] = []
	var struck: Array[Vector2i] = []
	for c in order:
		if struck.size() >= maxi(ab.terrain_tiles, 1):
			break
		if not BoardModel.is_breakable(c):
			continue
		struck.append(c)
		if BoardModel.damage_wall(c, blast):
			gone.append(c)
	if struck.is_empty():
		_emit("ability", {uid = u.uid, ability = ab.id, kind = ab.kind,
			cell = u.cell, wasted = true, reason = "no_wall"})
		return
	if not gone.is_empty():
		_emit("terrain", {broken = gone, raised = [] as Array[Vector2i]})
	_emit("ability", {uid = u.uid, ability = ab.id, kind = ab.kind,
		cell = u.cell, cells = struck, amount = blast})


func wall_toughness_for(u: UnitInstance, ab: AbilityData) -> float:
	# What a Mason's wall is worth. The base comes from the ability; Bastion adds
	# to it, and that rider is the whole of what the buff buys — a tougher wall,
	# not a bigger builder.
	var hp := maxf(ab.wall_hp, 1.0)
	var tb: TeamBuffs = team_buffs.get(u.team, null)
	if tb != null:
		hp *= 1.0 + maxf(tb.wall_toughness_for(u), 0.0)
	return hp


func _resolve_build(u: UnitInstance, ab: AbilityData) -> void:
	var made: Array[Vector2i] = []

	# Underfoot first, the way the Engineer builds its Sentry: the wall goes on
	# the tile the Mason chose to stand on and the Mason steps off it. That makes
	# *placing the Mason* the decision, rather than guessing which way it happens
	# to be facing when the bar fills.
	if ab.terrain_at_caster:
		var vacated := _vacate_for_build(u)
		if vacated != Vector2i(-1, -1) \
				and BoardModel.raise_wall(vacated, wall_toughness_for(u, ab), u.team):
			made.append(vacated)
		# If it cannot step off, it falls through and builds beside itself
		# instead. Burning the whole bar because it was boxed in would be a trap,
		# and it is already standing in the place it wanted the wall.

	# Toward the enemy, for the opposite reason to the Sapper: a wall is only
	# worth raising between them and you.
	var forward := 1 if u.team == BoardModel.TEAM_A else -1
	var ring := _terrain_ring(u, ab.terrain_reach)
	for c in ring:
		if made.size() >= maxi(ab.terrain_tiles, 1):
			break
		if (c.y - u.cell.y) * forward < 0:
			continue
		# Never build on top of anybody, either side's. Walling a live unit into
		# the stone is not something the rest of the simulation is prepared for.
		if board.unit_at(c) != null or not board.is_empty(c):
			continue
		if BoardModel.raise_wall(c, wall_toughness_for(u, ab), u.team):
			made.append(c)
	if made.is_empty():
		_emit("ability", {uid = u.uid, ability = ab.id, kind = ab.kind,
			cell = u.cell, wasted = true, reason = "no_room"})
		return
	_emit("terrain", {broken = [] as Array[Vector2i], raised = made})
	_emit("ability", {uid = u.uid, ability = ab.id, kind = ab.kind,
		cell = u.cell, cells = made})


func _resolve_haste(u: UnitInstance, ab: AbilityData) -> void:
	# A poisoned unit gains nothing, and a haste stack is a gain. It does not lose
	# the stacks it already had — the poison stops it getting better, it does not
	# undo what it already is.
	if u.is_suppressed():
		return
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
	u.add_shield(pool * ab.shield_percent,
		pool * maxf(ab.shield_cap_percent, ab.shield_percent), SHIELD_SECONDS)
	_emit("ability", {uid = u.uid, ability = ab.id, kind = ab.kind,
		cell = u.cell, shield = u.shield})
	_emit("shield", {uid = u.uid, shield = u.shield})


func _resolve_dot(u: UnitInstance, ab: AbilityData, target: UnitInstance) -> void:
	if target == null or not target.is_alive():
		return
	target.apply_dot(ab.dot_damage, ab.dot_ticks, ab.dot_interval, u.uid,
		ab.dot_vulnerability_per_tier * float(u.data.tier),
		ab.dot_current_hp_percent, ab.dot_falloff, ab.dot_suppresses)
	_emit("ability", {uid = u.uid, ability = ab.id, kind = ab.kind,
		cell = u.cell, target_uid = target.uid, target_cell = target.cell})


func tier_multiple(u: UnitInstance) -> float:
	## The curve every other number in the game follows: a tier doubles it. Named
	## here because three separate abilities were spelling `pow(2.0, tier - 1)` out
	## by hand and a fourth forgot to.
	return pow(2.0, float(u.data.tier - 1))


func burst_damage_of(u: UnitInstance, ab: AbilityData) -> float:
	if ab.burst_attack_multiple > 0.0:
		# Already scales, because the unit's own attack does.
		return u.stat(StatModifier.Stat.ATTACK_DAMAGE) * ab.burst_attack_multiple
	# Flat burst damage now doubles per tier. Without this the Pyre's whole identity
	# — "ordinary attacks are feeble, everything rides on the burst" — stopped being
	# true somewhere around tier 3, and its tier 6 was a 90-health body that hit for
	# 78 into bars of eleven thousand.
	return ab.burst_damage * tier_multiple(u)


func burst_splash_of(u: UnitInstance, ab: AbilityData) -> float:
	## The splash rides the same curve as the direct hit. It has to: a lance that
	## grows thirty-twofold while the scorch beside it stays at 16 is a lance with no
	## splash at tier 6.
	return ab.splash_damage * tier_multiple(u)


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
		_damage(v, hit if v == target else burst_splash_of(u, ab), u, true)


func _resolve_pierce(u: UnitInstance, ab: AbilityData, target: UnitInstance) -> void:
	if target == null or not target.is_alive():
		return
	var dmg := u.stat(StatModifier.Stat.ATTACK_DAMAGE) * ab.pierce_damage_mult
	var victims: Array[UnitInstance] = [target]
	victims.append_array(_pierce_beyond(u.cell, target,
		maxi(ab.pierce_targets, 1) - 1, u.team, shoots_through_walls(u)))
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


func _tick_dry_spells() -> void:
	# Counted for everything, read for almost nothing: a unit that swings on
	# cooldown never gets near IMPATIENT_AFTER, so this is only ever true for
	# units that are genuinely stuck walking. Rooted and harmless units accumulate
	# it too and it costs them nothing — they cannot move to a wall, and
	# _hit_wall refuses a unit whose wall damage is zero.
	for u in _units:
		if u.is_alive():
			u.dry_spell += TICK
			u.kite_hold = maxf(u.kite_hold - TICK, 0.0)


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
				# A share of what the victim has left RIGHT NOW, which is why the
				# poison front-loads on its own without any special case for the
				# first tick: the biggest number the target will ever have is the
				# one it has when the poison lands. The share then decays on top
				# of that, so this peters out twice over.
				var bite: float = d.dmg + u.current_hp * float(d.get("hp_share", 0.0))
				d.hp_share = float(d.get("hp_share", 0.0)) * float(d.get("falloff", 1.0))
				_damage(u, bite, src if src != null else u, true, false)
			if d.ticks_left <= 0:
				u.dots.remove_at(i)
			i -= 1


func frenzy_seconds_of(u: UnitInstance, ab: AbilityData) -> float:
	## How long the death-immunity window lasts for this unit. The ability's own
	## figure, unless a gold pick of its buff says longer — see
	## BuffData.frenzy_seconds_at_gold for why that is a replacement and not a sum.
	var secs := maxf(ab.frenzy_seconds, 0.0)
	var tb: TeamBuffs = team_buffs.get(u.team, null)
	if tb != null:
		secs = maxf(secs, tb.frenzy_seconds_for(u))
	return secs


func _open_frenzy(u: UnitInstance) -> bool:
	## Turns a death into the window, or returns false and lets the death happen.
	##
	## Once per round, and that is what frenzy_spent is for: without it every blow
	## that landed during the window would restart the clock and the unit would never
	## die at all.
	if u.frenzy_spent or u.data == null:
		return false
	var ab := u.data.ability
	if ab == null or ab.kind != AbilityData.Kind.FRENZY:
		return false
	var secs := frenzy_seconds_of(u, ab)
	if secs <= 0.0:
		return false
	u.frenzy_spent = true
	u.frenzy_left = secs
	# take_damage() and _execute() both set DEAD before handing over to _fell, so the
	# unit has to be stood back up explicitly. IDLE rather than whatever it was doing:
	# the swing it was halfway through is gone, and the next decision gets made fresh
	# with the new numbers — which are considerably better ones.
	u.state = UnitInstance.State.IDLE
	u.state_timer = 0.0
	u.target = null
	# Belt and braces: every route to zero health has already spent the shield, and a
	# bar left standing at zero health would make effective_hp() disagree with the
	# health bar for the whole window.
	u.shield = 0.0
	u.shield_left = 0.0
	_emit("frenzy", {uid = u.uid, cell = u.cell, seconds = secs})
	return true


func _tick_frenzy() -> void:
	## The Martyr's two clocks: the bleed that walks it down to zero, and the window
	## at the bottom that ends in a real death.
	for u in _units:
		if not u.is_alive() or u.is_riding():
			continue
		var ab := u.data.ability
		if ab == null or ab.kind != AbilityData.Kind.FRENZY:
			continue
		if u.frenzy_left > 0.0:
			u.frenzy_left = maxf(u.frenzy_left - TICK, 0.0)
			if u.frenzy_left > 0.0:
				continue
			_emit("frenzy_end", {uid = u.uid, cell = u.cell})
			if u.current_hp > 0.0:
				# Somebody healed it through the window, so it keeps standing. It does
				# not get a second one — frenzy_spent is already set, which means the
				# next time the bleed walks it to zero is the last.
				continue
			u.state = UnitInstance.State.DEAD
			u.target = null
			_fell(u, u.uid)
			continue
		var full := u.stat(StatModifier.Stat.MAX_HP)
		if full <= 0.0 or u.current_hp > full * maxf(ab.frenzy_threshold, 0.0):
			continue
		var bleed := full * maxf(ab.frenzy_decay, 0.0) * TICK
		if bleed <= 0.0:
			continue
		# Deliberately NOT through _damage(). The bleed comes from the inside: it is
		# not resisted, not amplified, cannot crit, cannot be reflected, and above all
		# is not absorbed by a shield — a shield eating it would let one Aegis Wall
		# park the Martyr at 49% health and switch the entire unit off.
		u.current_hp = maxf(u.current_hp - bleed, 0.0)
		_emit("damage", {
			uid = u.uid, source_uid = u.uid,
			amount = bleed, hp = u.current_hp, shield = u.shield,
			absorbed = 0.0, cell = u.cell, spell = false, crit = false,
			bleed = true,
		})
		if u.current_hp <= 0.0:
			u.state = UnitInstance.State.DEAD
			u.target = null
			_fell(u, u.uid)


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
		# Rupture's team-wide share, plus whatever the attacker earns on its own
		# for being the last one standing. Both are fractions of the VICTIM's
		# maximum health, so neither needs to scale with tier — they already do.
		var frac: float = _hp_damage[source.team] + last_stand_share(source)
		if frac > 0.0:
			total += victim.stat(StatModifier.Stat.MAX_HP) * frac
	total *= victim.damage_taken_multiplier() * pressure() * victim.exposure()
	total *= victim.taunt_damage_taken()
	total *= victim.frozen_damage_taken()
	total *= _burden_on(victim)
	# The Vexer's poison opening the target up to everything else. It sits here
	# with the other damage-taken multipliers, which means it also amplifies the
	# poison's OWN ticks — that is deliberate and it is what "from all sources"
	# has to mean; carving out the one source that applied it would be a special
	# case with nothing behind it.
	total *= victim.vulnerability()
	# Rolled last, on the final figure, so a crit doubles what actually lands
	# rather than doubling a number three multipliers still have to chew on. It is
	# rolled for EVERY source of damage — "all damage can be critical" — which is
	# why it lives here and not in _begin_attack.
	var crit := crit_chance > 0.0 and rng.randf() < crit_chance
	if crit:
		total *= CRIT_MULT
	var landed := victim.take_damage(total)
	_harden(victim)
	_drain_life(source, victim, total, landed)
	# take_damage() returns the part that reached HEALTH, so the difference is
	# exactly what the shield ate. Worked out here rather than in the view, which
	# only ever sees the shield value that is left and could not tell a hit that
	# was absorbed from one that landed on a unit that happens to have a shield.
	_emit("damage", {
		uid = victim.uid, source_uid = source.uid,
		amount = total, hp = victim.current_hp, shield = victim.shield,
		absorbed = maxf(total - landed, 0.0),
		cell = victim.cell, spell = is_spell, crit = crit,
	})
	if not victim.is_alive():
		_fell(victim, source.uid, is_overkill(victim, total))
	_reflect_back(victim, source, total, may_reflect)


func is_overkill(victim: UnitInstance, dealt: float) -> bool:
	## One blow bigger than the victim's ENTIRE health bar — not bigger than
	## whatever was left of it. A tier 1 chipped down to 3 HP dies to everything,
	## and calling that an overkill would make the loudest sound in the game the
	## most common one. Measured against max HP, it means what it sounds like: the
	## hit would have killed the unit from full.
	##
	## The figure compared is the damage ROLLED at the unit, after crits and every
	## multiplier, not the part of it the health bar had room to absorb — the
	## excess is exactly the thing being detected.
	return dealt > victim.stat(StatModifier.Stat.MAX_HP)


func _fell(victim: UnitInstance, killer_uid: int, overkill := false) -> void:
	# Every route to a death goes through here — an ordinary swing, a spell, and
	# the Devourer's execute. Keeping it in one place is what stops the execute
	# from quietly skipping the revive roll or the mana it owes the other side's
	# scavengers.
	var frozen := victim.is_frozen()
	if not frozen and _open_frenzy(victim):
		# A Martyr at zero health does not die yet. Intercepted HERE rather than in
		# _damage because this is the single funnel every death goes through — an
		# ordinary swing, a spell, its own bleed, a Devourer execute — and a window
		# that only opened for swings would be a bug the first time somebody cast at
		# it. Gated on `frozen` alongside the revive roll below: dying frozen means
		# nothing you would have done on death happens, and this is a thing it would
		# have done on death.
		return
	_emit("death", {uid = victim.uid, cell = victim.cell,
		killer_uid = killer_uid, frozen = frozen, overkill = overkill})
	board.remove(victim)
	if victim.is_possessed():
		# The puppeteer falls out of it. Done after board.remove() so the tile it
		# lands on is the one that has just been vacated, and before the revive roll
		# and the body pile below — a revived host must not still be marked as
		# ridden by something that is already standing next to it.
		_eject_husk(victim)
	if frozen:
		# Died frozen, so nothing it would have done on death happens: no revive
		# roll, no body in the pile for a Vigil to raise, and no mana for its own
		# side's scavengers. That is the whole second half of the ability, and it
		# is one branch because _fell is the single funnel every death goes
		# through — an ordinary swing, a spell, a Devourer execute.
		return
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
	# An execute deletes exactly what is left, so by the max-HP rule it is normally
	# NOT an overkill — which is right. The unit was not blown apart, it was
	# switched off, and the two deserve different sounds.
	_fell(victim, u.uid, is_overkill(victim, taken))


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
	# "Arm's length" has to mean the same eight tiles a melee unit can now swing
	# across, or a Reaver standing at the Aegis's corner would hit it for free.
	if not BoardModel.is_beside(source.cell, victim.cell):
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


func shield_gain_for(u: UnitInstance) -> float:
	# Per hit, as a fraction of max health, plus whatever its buff adds.
	if u == null or u.data == null:
		return 0.0
	var share := u.data.shield_on_hit
	var tb: TeamBuffs = team_buffs.get(u.team, null)
	if tb != null:
		share += tb.shield_on_hit_for(u)
	return maxf(share, 0.0)


func _harden(victim: UnitInstance) -> void:
	# Struck, so it hardens. Called after the blow has already landed, which is
	# what stops the very first hit being free — you are paying for the NEXT one.
	if not victim.is_alive():
		return
	var share := shield_gain_for(victim)
	if share <= 0.0:
		return
	var pool := victim.stat(StatModifier.Stat.MAX_HP)
	var before := victim.shield
	victim.add_shield(pool * share, pool * maxf(victim.data.shield_cap, 0.0),
		SHIELD_SECONDS)
	if victim.shield > before:
		_emit("shield", {uid = victim.uid, shield = victim.shield})
		_emit("harden", {
			uid = victim.uid, cell = victim.cell,
			shield = victim.shield, gained = victim.shield - before,
		})


func _decide_isolation() -> void:
	# Read off the board as it stands at the opening bell, exactly like
	# empowerment, and then never asked again. Anything that arrives after the
	# bell — a merge result, a Mimic's copy, a Conjurer's minion — is never
	# isolated, because it was not placed, and placement is the whole cost.
	for u in _units:
		if u.data.alone_hp_damage <= 0.0:
			continue
		u.isolated = _isolation_clear(u)
		if u.isolated:
			_emit("isolated", {uid = u.uid, cell = u.cell})


func _isolation_clear(u: UnitInstance) -> bool:
	# The 3x3 square centred on the unit: all eight neighbours, diagonals
	# included.
	#
	# ALLIES only, and that is a deliberate narrowing of "no units". Enemy
	# placement happens behind fog, so a condition an enemy could spoil would be
	# one you cannot see the inputs of — un-plannable, which is the opposite of a
	# placement puzzle. On the standard map it makes no difference at all (the
	# neutral row leaves the two halves two tiles apart at the bell), but on a map
	# with no neutral row the front ranks start touching, and there the difference
	# is the whole unit.
	for other in _units:
		if other == u or other.team != u.team:
			continue
		var d := other.cell - u.cell
		if absi(d.x) <= ISOLATION_RADIUS and absi(d.y) <= ISOLATION_RADIUS:
			return false
	return true


func is_isolated(u: UnitInstance) -> bool:
	# Dying does not un-isolate it; it just stops it swinging. Kept as a function
	# rather than reading the flag directly so the null case has one home.
	return u != null and u.isolated


func last_stand_share(u: UnitInstance) -> float:
	if u == null or u.data.alone_hp_damage <= 0.0:
		return 0.0
	return u.data.alone_hp_damage if is_isolated(u) else 0.0


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
	_field_wall_cost = wall_cost_for(u)
	# A unit that cannot use a gate must not be routed through one, or the field sends
	# it to a pad it cannot use and it stands there for the rest of the round. Two
	# reasons it might not be able to: it has spent its own transit, or its side has
	# spent the one it is allowed.
	_field_gates = may_use_gate(u)
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


func wall_cost_for(u: UnitInstance) -> int:
	# A unit that breaks stone for a living treats a wall as almost free; everyone
	# else treats it as a last resort. Same field, same rule, one number apart.
	if u.data.breaks_walls():
		return SAPPER_WALL_COST
	return WALL_COST


func is_impatient(u: UnitInstance) -> bool:
	return u != null and u.dry_spell >= IMPATIENT_AFTER


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
	# Standing ON a gate, the far pad is a candidate step alongside the four
	# neighbours. Checked first so a unit that has walked onto a gate actually goes
	# through it rather than stepping off the way it came.
	if BoardModel.is_gate(u.cell) and may_use_gate(u):
		var far := BoardModel.gate_from(u.cell)
		var far_d: int = field.get(far, -1)
		if far != u.cell and far_d >= 0 and far_d < here and board.is_empty(far):
			best = far
			best_d = far_d
			best_free = true
	for off in _neighbour_offsets():
		var c: Vector2i = u.cell + off
		if BoardModel.blocks_between(u.cell, c):
			continue
		if not BoardModel.can_climb(u.cell, c):
			continue
		var free := board.is_empty(c)
		if BoardModel.is_wall(c):
			# Breakable stone is a legal step for the *chooser* even though it is
			# not a legal tile to stand on — the caller turns a step into stone
			# into a swing at it. Without this the field can price a route through
			# a wall and then no step is ever taken along it, which is a unit
			# standing still forever in a sealed room.
			if not BoardModel.is_breakable(c):
				continue
			free = false
		elif not free and not through.has(c):
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
	#
	# Breakable stone is priced the same way, at WALL_COST — passable, ruinously
	# expensive. That one number does two jobs at once and replaces what would
	# otherwise have been a special case: ordinary units walk round any wall they
	# possibly can, and a unit with no way round at all still finds a route and
	# starts swinging at the stone. Permanent stone and holes stay impassable, so
	# a map can still say "never through here".
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
			if BoardModel.blocks_between(c, n):
				continue
			# The field is built backwards from the goal, so the step under
			# consideration is the one FROM n TO c and the climb is checked that
			# way round. Getting this the wrong way about prices the route up a
			# staircase as if you were coming down it.
			if not BoardModel.can_climb(n, c):
				continue
			var step := 1
			if _field_team >= 0 and field_at(n, _field_team) > 0.0:
				step = FIELD_COST
			if BoardModel.is_wall(n):
				if not BoardModel.is_breakable(n):
					continue
				step = _field_wall_cost
			elif BoardModel.is_void(n):
				continue
			elif n != start and not through.has(n):
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

		# And through a gate. This is the part that makes gates real rather than
		# decorative: the field is built backwards from the goal, so if `c` costs k
		# then the OTHER gate costs k + 1 — one step to walk into it and out the far
		# side. Without this the field knows nothing about the link, every unit prices
		# the long way round as the only way round, and a gate is a tile that units
		# walk over without ever using.
		#
		# The partner is relaxed exactly like a neighbour, including the congestion
		# and occupancy rules, because arriving on an occupied pad is not a move.
		if _field_gates and BoardModel.is_gate(c):
			var far := BoardModel.gate_from(c)
			if far != c:
				var gate_step := 1
				var standing := board.unit_at(far)
				if far != start and not through.has(far) and standing != null:
					if standing.team != _field_team:
						gate_step = -1
					else:
						gate_step = CONGESTION_COST
				if gate_step > 0:
					var gate_cost := here + gate_step
					if not dist.has(far) or int(dist[far]) > gate_cost:
						dist[far] = gate_cost
						open.append(far)
	return dist


func _greedy_step(u: UnitInstance, goal: Vector2i) -> Vector2i:
	var best := u.cell
	var best_d := BoardModel.tile_distance(u.cell, goal)
	for off in _neighbour_offsets():
		var c := u.cell + off
		if not board.is_empty(c) or BoardModel.blocks_between(u.cell, c):
			continue
		if not BoardModel.can_climb(u.cell, c):
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
	# Bodies, not health. It used to total everyone's remaining health as a
	# fraction of their maximum, which is a fairer measure of who was winning and
	# a much worse one to play to: you cannot count it while watching, so the
	# result arrived as an announcement rather than something you saw coming. Six
	# units against five is a number on the screen the whole round.
	var alive := [0, 0]
	for team in 2:
		alive[team] = board.living_count_of(team) + pending_respawns(team)
	if alive[0] == alive[1]:
		return RESULT_DRAW
	return BoardModel.TEAM_A if alive[0] > alive[1] else BoardModel.TEAM_B


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
