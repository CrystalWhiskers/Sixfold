class_name BossFight
extends RefCounted

## Boss defence: one boss against an open field of three zones and four crystals,
## in one long continuous battle on the ordinary CombatSim.
##
## The board (make_map) is one wide open battlefield. The boss enters at the top.
## Below it are three wide ZONES, Left, Middle and Right, marked only by the colour
## of the ground and a few scattered rocks for cover. Each has a crystal standing in
## it. A fourth zone runs down the middle towards the bottom, holding the Central
## Crystal as far from the boss's entry as the board allows; it is sealed until the
## other three are gone. The boss goes for the zone crystals in a fixed order
## (BossData.crystal_order), fighting whatever gets in its way. When the last breaks,
## the seal comes off and it turns on the centre.
##
## The armies come from the Barracks: three sections, one per zone. Every
## `wave_seconds` each section sends a fresh copy of itself to its zone's crystal,
## on top of whoever is still standing (reinforcements STACK). Its units default to
## guarding that crystal, and go after the boss — anywhere on the field — once it
## comes within reach of them or of their crystal. A zone at its cap keeps the
## rest of a wave waiting, at most one section's worth, and drops them in as space
## opens. After the merge every section's wave arrives around the Central Crystal.
##
## The sim calls in three places: boss_turn() is the boss's whole turn, tick() runs
## the clocks and the waves, outcome() decides the fight, and holds() lets a guard
## stand still without pathfinding. Everything else — damage, death, summons, the
## event log — is the sim's ordinary machinery.

const UNDECIDED := -2

const WIDTH := 17
const HEIGHT := 26
## Rows 0..HUB_ROWS-1 are where the boss comes in.
const HUB_ROWS := 4
const ZONE_NAMES := ["Left", "Middle", "Right", "Central"]
## Zone boundaries: the Middle zone is the middle columns down to CENTRAL_TOP, the
## Central zone the same columns below it, Left and Right everything either side.
const MIDDLE_COLS := Vector2i(6, 10)
const CENTRAL_TOP := 18
const CRYSTAL_CELLS := [Vector2i(2, 17), Vector2i(8, 11), Vector2i(14, 17)]
const CENTRAL_CELL := Vector2i(8, 24)
const BOSS_CELL := Vector2i(8, 1)
## Scattered broken wall: cover, not corridors. Short segments, never a line.
const ROCKS := [
	Vector2i(4, 6), Vector2i(5, 6), Vector2i(11, 6), Vector2i(12, 6),
	Vector2i(1, 9), Vector2i(15, 9),
	Vector2i(7, 8), Vector2i(9, 8),
	Vector2i(4, 13), Vector2i(12, 13),
	Vector2i(7, 15), Vector2i(9, 15),
	Vector2i(2, 21), Vector2i(3, 21), Vector2i(13, 21), Vector2i(14, 21),
	Vector2i(6, 20), Vector2i(10, 20),
]
## How close a unit has to be for the boss to aim a move at it rather than at the
## crystal it is walking to.
const AIM_RADIUS := 4
## A guard leaves its crystal for the boss once the boss is this close to it...
const ENGAGE_RANGE := 6
## ...or this close to the crystal it guards.
const GUARD_RADIUS := 7
## How long a dash or leap takes on screen. The move itself is instant.
const LEAP_TIME := 0.18
## The sim's timeout when the boss has no time limit: never, in practice.
const NO_TIME_LIMIT := 1.0e9


## True only while a big move's blow is landing on a crystal that stood in its way.
var _crystal_accident := false
## The aim a sweep started with, kept for its later beats.
var _sweep_aim := Vector2i.ZERO
## Seconds before she may answer a crowd with her surround move again.
var surround_cd := 0.0
## Burning ground: {cells, left, tick, dps}.
var _blazes: Array[Dictionary] = []


func crowd_around() -> int:
	## How many of the army stand within two tiles of her.
	var n := 0
	for v in sim.board.units_in_box(boss.cell, 2, player_team()):
		if v.is_alive() and not v.structure:
			n += 1
	return n


func _tick_hazards() -> void:
	if surround_cd > 0.0:
		surround_cd -= CombatSim.TICK
	# The burning ground: twice a second, everything of the army standing in it burns.
	var i := _blazes.size() - 1
	while i >= 0:
		var b: Dictionary = _blazes[i]
		b.left = float(b.left) - CombatSim.TICK
		b.tick = float(b.tick) + CombatSim.TICK
		if float(b.tick) >= 0.5:
			b.tick = float(b.tick) - 0.5
			for c in b.cells:
				var v := sim.board.unit_at(c)
				if v != null and v.team == player_team() and v.is_alive() and not v.structure:
					_soul_blow = bool(b.get("soul", false))
					sim._damage(v, float(b.dps) * 0.5, boss, true)
					_soul_blow = false
		if float(b.left) <= 0.0:
			_blazes.remove_at(i)
		i -= 1
	# The mana seal wears off.
	for u in sim._units:
		if u.mana_suppressed > 0.0:
			u.mana_suppressed = maxf(u.mana_suppressed - CombatSim.TICK, 0.0)


func max_hit() -> float:
	## The most one blow can take off her, or INF with no cap.
	if data.max_hit_percent <= 0.0:
		return INF
	return boss.stat(StatModifier.Stat.MAX_HP) * data.max_hit_percent


func shape_boss_damage(amount: float, source: UnitInstance) -> float:
	## Every hit on her, after all the usual multipliers: ranged blows are cut by her
	## ranged resistance, and nothing lands bigger than her single-hit cap.
	var out := amount
	if source != null and source.is_ranged():
		var reach := UnitData.band_tiles(source.stat_int(StatModifier.Stat.ATTACK_RANGE))
		var p := _phase()
		var resist := p.ranged_resist if p != null and p.ranged_resist > 0.0 else data.ranged_resist
		if reach >= data.long_range_tiles:
			var far := p.long_range_resist if p != null and p.long_range_resist > 0.0 else data.long_range_resist
			resist = maxf(resist, far)
		out *= 1.0 - clampf(resist, 0.0, 0.95)
	return minf(out, max_hit())


## Her lasting gain from the army's dead: one modifier, re-laid when the count grows.
var _death_mod: StatModifier = null
var dead_counted := 0


func _tick_death_power() -> void:
	if data.death_power <= 0.0 or not boss.is_alive():
		return
	var dead := 0
	for u in sim._units:
		if u.team == player_team() and not u.structure and not u.is_alive() and not u.is_lit():
			dead += 1
	if dead == dead_counted:
		return
	dead_counted = dead
	if _death_mod != null:
		boss.battle_modifiers.erase(_death_mod)
	_death_mod = StatModifier.make(StatModifier.Stat.ATTACK_DAMAGE, StatModifier.Mode.PERCENT,
		data.death_power * float(dead))
	boss.add_battle_modifier(_death_mod)


func _tick_regen() -> void:
	var p := _phase()
	if p != null and p.regen > 0.0 and boss.is_alive():
		heal_boss(boss.stat(StatModifier.Stat.MAX_HP) * p.regen * CombatSim.TICK)


func top_army_tier() -> int:
	## The highest tier of anything in the army on the field right now, 0 if none.
	var top := 0
	for u in sim.board.units_view():
		if u.team == player_team() and u.is_alive() and not u.structure and u.data != null:
			top = maxi(top, u.data.tier)
	return top


func execute_tier(mv: BossMove) -> int:
	## The tier a move will execute outright, or 0 if it executes nothing: the army's
	## highest tier, as long as that is at least the move's minimum.
	if mv == null or not mv.executes_top_tier:
		return 0
	var top := top_army_tier()
	return top if top >= maxi(mv.execute_min_tier, 1) else 0

## How many times she has surged (see BossData.enrage_*), and the modifiers that carry
## it, one pair per surge.
var enrage_stacks := 0
var _enrage_mods: Array[StatModifier] = []


func next_enrage_at() -> float:
	## The fight time of her next surge, or INF if she never enrages.
	if data.enrage_every <= 0.0:
		return INF
	return data.enrage_after + data.enrage_every * float(enrage_stacks)


func _tick_enrage() -> void:
	## The longer the fight, the stronger she gets: no clock runs out, but every surge
	## makes her hit harder and faster, and her summons tougher, for good.
	if not boss.is_alive() or sim.elapsed < next_enrage_at():
		return
	enrage_stacks += 1
	for m in [StatModifier.make(StatModifier.Stat.ATTACK_DAMAGE, StatModifier.Mode.PERCENT,
				data.enrage_attack),
			StatModifier.make(StatModifier.Stat.ATTACK_SPEED, StatModifier.Mode.PERCENT,
				data.enrage_speed)]:
		boss.add_battle_modifier(m)
		_enrage_mods.append(m)
	sim._emit("boss_enrage", {uid = boss.uid, cell = boss.cell, stacks = enrage_stacks,
		attack = data.enrage_attack * enrage_stacks, speed = data.enrage_speed * enrage_stacks,
		minions = data.enrage_minions * enrage_stacks, next_at = next_enrage_at()})

var data: BossData = null
var sim: CombatSim = null
var barracks: Barracks = null
var boss: UnitInstance = null
## Index 0..2 are the zone crystals, 3 is the Central Crystal.
var crystals: Array[UnitInstance] = []

var phase := 0
var merged := false
## Position in the phase's move list of the NEXT move to be marked.
var move_index := 0
var gap_left := 0.0
## Seconds left of a phase change's announcement, during which it does nothing.
var pause_left := 0.0
## The move currently marked on the board, or empty: {move, cells, left, aim}.
var marked: Dictionary = {}
var wave_left := 0.0
var waves := 0

## Units waiting for room, per zone (index 3 = the Central zone, after the merge).
var queued: Array = [[], [], [], []]
## uid -> the zone a unit was sent to guard: 0..2, or 3 once the armies merge.
var zone_of_uid: Dictionary = {}
var _phase_mods: Array[StatModifier] = []


# --- The board ----------------------------------------------------------------

static func make_map() -> MapData:
	var m := MapData.new()
	m.id = &"boss_field"
	m.display_name = "The Open Field"
	m.width = WIDTH
	m.height = HEIGHT
	m.has_neutral = false
	m.asymmetric = true
	var rows := PackedStringArray()
	for y in HEIGHT:
		var row := ""
		for x in WIDTH:
			row += MapData.WALL if ROCKS.has(Vector2i(x, y)) else MapData.OPEN
		rows.append(row)
	m.rows = rows
	m.note = "One open battlefield in four zones, with scattered rock for cover."
	return m


static func zone_of_cell(c: Vector2i) -> int:
	## 0/1/2 for the Left/Middle/Right zones, 3 for the Central zone, -1 for the
	## boss's entry at the top.
	if c.y < HUB_ROWS:
		return -1
	if c.x >= MIDDLE_COLS.x and c.x <= MIDDLE_COLS.y:
		return 3 if c.y >= CENTRAL_TOP else 1
	return 0 if c.x < MIDDLE_COLS.x else 2


func player_team() -> int:
	return BoardModel.TEAM_B


func boss_team() -> int:
	return BoardModel.TEAM_A


# --- Setting up ---------------------------------------------------------------

func place_structures(board: BoardModel, boss_data: BossData) -> void:
	## Puts the boss and the four crystals on a board whose map is make_map(). Call
	## before CombatSim.setup().
	data = boss_data
	crystals.clear()
	for i in 4:
		var cd := UnitData.new()
		cd.id = &"crystal"
		cd.display_name = "%s Crystal" % ZONE_NAMES[i]
		cd.max_hp = data.central_crystal_hp if i == 3 else data.lane_crystal_hp
		cd.attack_damage = 0.0
		cd.can_move = false
		cd.can_attack = false
		cd.mana_per_attack = 0.0
		cd.accent = Color(0.55, 0.85, 0.95) if i < 3 else Color(0.95, 0.85, 0.50)
		var c := UnitInstance.create(cd, player_team())
		c.structure = true
		c.sealed = i == 3
		board.force_place(c, CENTRAL_CELL if i == 3 else CRYSTAL_CELLS[i])
		crystals.append(c)
	var bd := UnitData.new()
	bd.id = data.id
	bd.display_name = data.display_name
	bd.max_hp = data.max_hp
	bd.attack_damage = data.attack_damage
	bd.attack_speed = data.attack_speed
	bd.move_time = data.move_time
	bd.sight_range = 40
	bd.mana_per_attack = 0.0
	bd.accent = data.accent
	bd.note = data.note
	boss = UnitInstance.create(bd, boss_team())
	boss.boss = true
	boss.percent_cap = data.percent_cap
	boss.hold_scale = data.hold_scale
	board.force_place(boss, BOSS_CELL)


func attach(p_sim: CombatSim, p_barracks: Barracks) -> void:
	## Hooks into a sim that has NOT been set up yet. The fight's own rules replace
	## the round clock: no sudden death, and the boss's time limit as the timeout.
	sim = p_sim
	barracks = p_barracks
	sim.boss_fight = self
	sim.sudden_death = 1.0e9
	# No time limit unless the data sets one: the enrage settles a long fight instead.
	sim.timeout = data.time_limit if data.time_limit > 0.0 else NO_TIME_LIMIT


func start() -> void:
	## After CombatSim.setup(): opens the fight, and the first wave goes out at once.
	zone_of_uid.clear()
	queued = [[], [], [], []]
	phase = 0
	merged = false
	move_index = 0
	marked = {}
	waves = 0
	wave_left = data.wave_seconds
	gap_left = _phase().gap if _phase() != null else 999.0
	_apply_phase_mods()
	var ids: Array[int] = []
	for c in crystals:
		ids.append(c.uid)
	sim._emit("boss_start", {uid = boss.uid, name = data.display_name,
		title = data.title, max_hp = boss.stat(StatModifier.Stat.MAX_HP),
		crystals = ids, phase = phase, phase_name = _phase_name(),
		wave_seconds = data.wave_seconds, target_uid = current_target_uid()})
	# The Spire's Raise Host and every other "random unit from your own side"
	# draws from this pool: the player's own loadout.
	if barracks != null:
		sim.board.set_team_pool(player_team(), barracks.types)
	send_wave()


# --- Queries ------------------------------------------------------------------

func _phase() -> BossPhase:
	if data == null or data.phases.is_empty():
		return null
	return data.phases[clampi(phase, 0, data.phases.size() - 1)]


func _phase_name() -> String:
	var p := _phase()
	return "" if p == null else p.display_name


func current_target() -> UnitInstance:
	## The crystal it is going for. Before the seal lifts: the first zone crystal
	## standing in the fixed order — including one that has rebuilt, even after the
	## seal has lifted: while any lane crystal stands the Central Crystal is immune,
	## so she has to go back and break it. Only with all three down is it the centre.
	if merged and lane_crystals_left() == 0:
		return crystals[3]
	for zone in data.crystal_order:
		var c := crystals[zone]
		if c.is_alive():
			return c
	return crystals[3]


func may_hurt_crystal(crystal: UnitInstance, source: UnitInstance) -> bool:
	## A crystal takes damage from one thing only: the boss's own blow on the
	## crystal she is after. Her moves, her minions and anything splashing never do.
	if crystal == crystals[3] and lane_crystals_left() > 0:
		# The Central Crystal is immune while any lane crystal stands — a rebuilt one
		# included. She has to break the lanes again first.
		return false
	return _crystal_accident or source == boss and crystal == current_target()


func current_target_uid() -> int:
	var t := current_target()
	return -1 if t == null else t.uid


func lane_crystals_left() -> int:
	var n := 0
	for i in 3:
		if crystals[i].is_alive():
			n += 1
	return n


func outcome() -> int:
	if not boss.is_alive():
		return player_team()
	if not crystals[3].is_alive():
		return boss_team()
	return UNDECIDED


var _side_cache: Array[UnitInstance] = []
var _side_cache_at := -1.0
var _side_cache_n := -1


func _her_side() -> Array[UnitInstance]:
	## Her summons on the field, gathered once a tick: every unit of the army asks.
	# Re-gathered each tick, and whenever anyone joins the field mid-tick.
	if not is_equal_approx(_side_cache_at, sim.elapsed) or _side_cache_n != sim._units.size():
		_side_cache_at = sim.elapsed
		_side_cache_n = sim._units.size()
		_side_cache.clear()
		for m in sim._units:
			if m.team == boss_team() and m != boss and m.is_alive():
				_side_cache.append(m)
	return _side_cache


func player_target(u: UnitInstance) -> UnitInstance:
	## What one of the player's units fights. The boss, whenever it can: if the boss
	## is in reach it is the target whatever else is closer. A minion is fought only
	## when the boss is out of reach and the minion is IN reach — it is in the way, or
	## at arm's length. Otherwise the unit marches on the boss.
	if not boss.is_alive():
		return null
	var reach := sim.reach_against(u, boss)
	if BoardModel.in_reach(u.cell, boss.cell, reach) and sim._has_shot(u, boss):
		return boss
	var near: UnitInstance = null
	var near_d := 1 << 30
	for m in _her_side():
		if not m.is_alive() or m.team != boss_team() or m.is_hidden():
			continue
		if not BoardModel.in_reach(u.cell, m.cell, sim.reach_against(u, m)):
			continue
		var d := BoardModel.tile_distance(u.cell, m.cell)
		if d < near_d or (d == near_d and near != null and m.uid < near.uid):
			near = m
			near_d = d
	return near if near != null else boss


# --- The boss's turn ----------------------------------------------------------

func boss_turn() -> void:
	var u := boss
	if u.is_held():
		return
	if not marked.is_empty():
		# Committed. It stands in the middle of its own mark until the blow lands.
		return
	if pause_left > 0.0:
		# Announcing a new phase: it stands where it is and does nothing at all.
		return
	if u.state != UnitInstance.State.IDLE:
		sim._advance_timer(u)
		return
	if gap_left <= 0.0:
		_mark_next_move()
		return
	var foe := _foe_in_reach()
	if foe != null:
		u.target = foe
		if u.can_attack_now():
			sim._begin_attack(u)
		return
	var aim := current_target()
	if aim == null or not u.can_move_now():
		return
	u.target = aim
	sim._begin_move(u)


func _foe_in_reach() -> UnitInstance:
	## What it swings at when it is not using a move: the crystal it wants if it is
	## standing at it, otherwise the weakest thing in arm's reach — it is cutting a
	## way through, not picking a fight.
	var want := current_target()
	var best: UnitInstance = null
	for v in sim.board.units_in_box(boss.cell, 1, player_team()):
		if not v.is_alive() or v.sealed:
			continue
		if v == want:
			return v
		if v.structure:
			continue
		if best == null or v.current_hp < best.current_hp \
				or (is_equal_approx(v.current_hp, best.current_hp) and v.uid < best.uid):
			best = v
	return best


static func is_big(m: BossMove) -> bool:
	return m != null and (m.windup > 0.0 or m.shape == BossMove.Shape.STANCE
		or m.shape == BossMove.Shape.RETREAT)


func _split(p: BossPhase) -> Array:
	## [ordinary moves in cycle order, big moves].
	var normals: Array[BossMove] = []
	var bigs: Array[BossMove] = []
	for m in p.moves:
		if is_big(m):
			if not bigs.has(m):
				bigs.append(m)
		else:
			normals.append(m)
	return [normals, bigs]


func big_chance_of(p: BossPhase) -> float:
	if p == null:
		return 0.0
	if p.big_chance >= 0.0:
		return p.big_chance
	var n := 0
	for m in p.moves:
		if is_big(m):
			n += 1
	return float(n) / maxf(float(p.moves.size()), 1.0)


func next_move() -> BossMove:
	## The next of her ORDINARY moves, which still come round in their listed order.
	var p := _phase()
	if p == null or p.moves.is_empty():
		return null
	var normals: Array = _split(p)[0]
	if normals.is_empty():
		return p.moves[move_index % p.moves.size()]
	return normals[move_index % normals.size()]


func army_within(r: int) -> int:
	var n := 0
	for v in sim.board.units_in_box(boss.cell, r, player_team()):
		if v.is_alive() and not v.structure:
			n += 1
	return n


var _last_big: BossMove = null


func _mark_next_move() -> void:
	var p := _phase()
	# Crowded: whatever was next in her cycle waits, and she answers the crowd with
	# her surround move — a big one, wound up first like every big one.
	if data.surround_move != null and surround_cd <= 0.0 and crowd_around() >= data.surround_count:
		surround_cd = p.surround_cooldown if p != null and p.surround_cooldown > 0.0 else data.surround_cooldown
		_mark(data.surround_move)
		return
	# A big one, at random — the chance grows phase by phase — but only if there is
	# anyone near enough to be worth it. Otherwise the next ordinary move, and only if
	# someone is in reach of it: she does not swing at empty ground; she walks on.
	var bigs: Array = _split(p)[1] if p != null else []
	if not bigs.is_empty() and sim.rng.randf() < big_chance_of(p) and army_within(10) > 0:
		var pick: BossMove = bigs[sim.rng.randi_range(0, bigs.size() - 1)]
		if pick == _last_big and bigs.size() > 1:
			pick = bigs[(bigs.find(pick) + 1) % bigs.size()]
		_last_big = pick
		if pick.shape == BossMove.Shape.STANCE:
			_begin_stance(pick)
		else:
			_mark(pick)
		return
	var mv := next_move()
	if mv == null:
		gap_left = 999.0
		return
	if army_within(6) == 0:
		gap_left = 0.5
		return
	var n_normals: int = maxi((_split(p)[0] as Array).size(), 1)
	move_index = (move_index + 1) % n_normals
	if mv.shape == BossMove.Shape.STANCE:
		_begin_stance(mv)
		return
	_mark(mv)


# --- The charge-up stance -----------------------------------------------------

var _stance_mods: Array[StatModifier] = []
var _stagger_mods: Array[StatModifier] = []
var _boost_mods: Array[StatModifier] = []
var stagger_left := 0.0
var boost_left := 0.0


func in_stance() -> bool:
	return bool(marked.get("stance", false))


func _begin_stance(mv: BossMove) -> void:
	## It plants itself and gathers power: less damage taken, and a meter the player
	## can see filling. The meter is the damage it has taken since it began.
	_stance_mods = [StatModifier.make(StatModifier.Stat.DAMAGE_TAKEN,
		StatModifier.Mode.PERCENT, -clampf(mv.stance_resist, 0.0, 0.95))]
	for m in _stance_mods:
		boss.add_battle_modifier(m)
	marked = {move = mv, stance = true, left = maxf(mv.telegraph, CombatSim.TICK),
		hp = boss.current_hp, taken = 0.0, cells = [] as Array[Vector2i]}
	boss.target = null
	sim._emit("boss_stance", {uid = boss.uid, name = mv.display_name, cell = boss.cell,
		seconds = mv.telegraph, threshold = mv.break_threshold, phase = phase})


func _tick_stance() -> void:
	var mv: BossMove = marked.move
	var lost := maxf(float(marked.hp) - boss.current_hp, 0.0)
	marked.taken = float(marked.taken) + lost
	marked.hp = boss.current_hp
	marked.left = float(marked.left) - CombatSim.TICK
	if lost > 0.0:
		sim._emit("boss_stance_meter", {uid = boss.uid, taken = marked.taken,
			threshold = mv.break_threshold})
	if float(marked.taken) >= mv.break_threshold:
		_break_stance(mv)
	elif float(marked.left) <= 0.0:
		_complete_stance(mv)


func _end_stance() -> void:
	for m in _stance_mods:
		boss.battle_modifiers.erase(m)
	_stance_mods.clear()
	marked = {}


func _break_stance(mv: BossMove) -> void:
	## Broken: staggered, open to everything, and its cycle carries on afterwards.
	_end_stance()
	boss.stun_left = maxf(boss.stun_left, mv.stagger_seconds)
	boss.state = UnitInstance.State.IDLE
	_stagger_mods = [StatModifier.make(StatModifier.Stat.DAMAGE_TAKEN,
		StatModifier.Mode.PERCENT, mv.stagger_amp)]
	for m in _stagger_mods:
		boss.add_battle_modifier(m)
	stagger_left = mv.stagger_seconds
	var p := _phase()
	gap_left = maxf(p.gap if p != null else 3.0, mv.stagger_seconds)
	sim._emit("boss_stance_broken", {uid = boss.uid, cell = boss.cell,
		seconds = mv.stagger_seconds})
	sim._emit("stun", {uid = boss.uid, cell = boss.cell, seconds = mv.stagger_seconds})


func _complete_stance(mv: BossMove) -> void:
	## Not broken: it comes out of the stance stronger and opens with its finisher.
	_end_stance()
	for m in _boost_mods:
		boss.battle_modifiers.erase(m)
	_boost_mods = [
		StatModifier.make(StatModifier.Stat.ATTACK_DAMAGE, StatModifier.Mode.PERCENT, mv.boost_attack),
		StatModifier.make(StatModifier.Stat.ATTACK_SPEED, StatModifier.Mode.PERCENT, mv.boost_speed),
	]
	for m in _boost_mods:
		boss.add_battle_modifier(m)
	boost_left = mv.boost_seconds
	sim._emit("boss_empowered", {uid = boss.uid, cell = boss.cell,
		seconds = mv.boost_seconds})
	if mv.finisher != null:
		_mark(mv.finisher)


# --- The retreat ---------------------------------------------------------------

## Her lasting gains from every retreat that ran its course, and how many that was.
var _retreat_mods: Array[StatModifier] = []
var _retreat_vuln: Array[StatModifier] = []
var retreats_completed := 0
## Where she can be sent to heal: the back of the field, in the hub.
const RETREAT_ROWS := 3


func retreat_cell() -> Vector2i:
	## The middle of the back of the field: the centre of the top row, or the free tile
	## nearest it — where she can be seen healing, behind her summons.
	var want := Vector2i(WIDTH / 2, 0)
	if want == boss.cell or (sim.board.is_empty(want) and not BoardModel.is_blocked(want)):
		return want
	var best := boss.cell
	var best_d := 1 << 30
	for y in RETREAT_ROWS:
		for x in WIDTH:
			var c := Vector2i(x, y)
			if not sim.board.is_empty(c) or BoardModel.is_blocked(c):
				continue
			var d := BoardModel.tile_distance(c, want)
			if d < best_d:
				best = c
				best_d = d
	return best


func _begin_retreat(mv: BossMove) -> void:
	## She vanishes to the back of the field, calls her summons round her and heals —
	## open to everything while she does.
	var from := boss.cell
	var to := retreat_cell()
	if to != from and sim.board.move_unit(boss, to):
		boss.move_from = from
		sim._emit("move", {uid = boss.uid, from = from, to = to, duration = LEAP_TIME,
			leap = true})
	boss.target = null
	boss.state = UnitInstance.State.IDLE
	_retreat_vuln = [StatModifier.make(StatModifier.Stat.DAMAGE_TAKEN,
		StatModifier.Mode.PERCENT, maxf(mv.retreat_vulnerability, 0.0))]
	for m in _retreat_vuln:
		boss.add_battle_modifier(m)
	marked = {move = mv, retreat = true, left = maxf(mv.retreat_seconds, CombatSim.TICK),
		cells = [] as Array[Vector2i]}
	sim._emit("boss_retreat", {uid = boss.uid, from = from, cell = boss.cell,
		name = mv.display_name, seconds = mv.retreat_seconds,
		vulnerability = mv.retreat_vulnerability, phase = phase})
	_summon_kinds(mv.retreat_summons)


func _summon_kinds(kinds: Array[BossMinion]) -> void:
	## A retreat's summons: every one in the list, in circles round her, not held to
	## the ordinary cap — this is her calling everything she has. Each steps out a
	## summon_warning later, like any other.
	var p := _phase()
	var power := p.minion_power if p != null else 1.0
	var cells: Array[Vector2i] = []
	var ring := [Vector2i(-2, 1), Vector2i(2, 1), Vector2i(-1, 2), Vector2i(1, 2), Vector2i(0, 2),
		Vector2i(-3, 2), Vector2i(3, 2), Vector2i(-2, 3), Vector2i(2, 3), Vector2i(0, 3)]
	for i in kinds.size():
		if minions_alive() + cells.size() >= mini(data.minion_cap + kinds.size(), summon_ceiling()):
			break
		var want: Vector2i = boss.cell + ring[i % ring.size()]
		var c := _nearest_free(want, boss.cell)
		if c == boss.cell or cells.has(c):
			continue
		cells.append(c)
		_summon_marks.append({cell = c, left = data.summon_warning, power = power,
			kind = kinds[i]})
	if not cells.is_empty():
		sim._emit("boss_summon", {uid = boss.uid, cells = cells, seconds = data.summon_warning,
			cell = boss.cell, retreat = true})


func _tick_retreat() -> void:
	marked.left = float(marked.left) - CombatSim.TICK
	if float(marked.left) <= 0.0:
		_end_retreat(true)


func _end_retreat(completed: bool) -> void:
	var mv: BossMove = marked.move
	for m in _retreat_vuln:
		boss.battle_modifiers.erase(m)
	_retreat_vuln.clear()
	marked = {}
	var p := _phase()
	gap_left = p.gap if p != null else 3.0
	if completed and boss.is_alive():
		# Back, and stronger for good: every retreat that runs its course stacks.
		retreats_completed += 1
		var gains := [
			StatModifier.make(StatModifier.Stat.ATTACK_DAMAGE, StatModifier.Mode.PERCENT,
				mv.retreat_attack),
			StatModifier.make(StatModifier.Stat.ATTACK_SPEED, StatModifier.Mode.PERCENT,
				mv.retreat_speed),
		]
		for m: StatModifier in gains:
			boss.add_battle_modifier(m)
			_retreat_mods.append(m)
	sim._emit("boss_retreat_end", {uid = boss.uid, cell = boss.cell, completed = completed,
		stacks = retreats_completed, attack = mv.retreat_attack * retreats_completed,
		speed = mv.retreat_speed * retreats_completed})


func _tick_boosts() -> void:
	if stagger_left > 0.0:
		stagger_left -= CombatSim.TICK
		if stagger_left <= 0.0:
			for m in _stagger_mods:
				boss.battle_modifiers.erase(m)
			_stagger_mods.clear()
	if boost_left > 0.0:
		boost_left -= CombatSim.TICK
		if boost_left <= 0.0:
			for m in _boost_mods:
				boss.battle_modifiers.erase(m)
			_boost_mods.clear()
			sim._emit("boss_boost_end", {uid = boss.uid, cell = boss.cell})


func _mark(mv: BossMove, step := 0, wound := false) -> void:
	## Marks a move — or, for a chained one (Onrush's legs, the stripes' two beats),
	## its `step`-th part. The next part is marked when this one lands.
	##
	## A big move with a `windup` charges first: for that long she glows and its
	## name is up, and only then do the tiles get marked. Three beats in all —
	## charge, mark, blow.
	if step == 0 and not wound and mv.windup > 0.0:
		marked = {move = mv, windup = true, left = mv.windup, cells = [] as Array[Vector2i]}
		boss.target = null
		sim._emit("boss_windup", {uid = boss.uid, move = mv.id, name = mv.display_name,
			seconds = mv.windup, cell = boss.cell, phase = phase})
		return
	if mv.shape == BossMove.Shape.RETREAT:
		if bar_of(boss.current_hp).x <= 0.0:
			# Her bar is already empty: the next one is about to begin, and a retreat
			# now would be cut short before it started.
			marked = {}
			var p := _phase()
			gap_left = p.gap if p != null else 3.0
			return
		_begin_retreat(mv)
		return
	var aim := _aim_for(mv)
	if mv.shape == BossMove.Shape.ARC and step > 0:
		# A sweep keeps the aim it started with, so each beat is the next slice round.
		aim = _sweep_aim
	_sweep_aim = aim
	var cells := move_cells(mv, boss.cell, aim, step)
	marked = {move = mv, cells = cells, left = maxf(mv.telegraph, CombatSim.TICK),
		aim = aim, step = step, doom = execute_tier(mv)}
	boss.target = null
	sim._emit("boss_telegraph", {uid = boss.uid, move = mv.id, name = mv.display_name,
		cells = cells, seconds = mv.telegraph, cell = boss.cell, phase = phase,
		executes = int(marked.doom), max_hp_percent = mv.max_hp_percent})


func _aim_for(mv: BossMove) -> Vector2i:
	## Where a move points. A dash heads straight for the crystal it is after; a leap
	## finds its own crowd; everything else points at the nearest of the army if
	## any is close, and at the crystal it is walking to if not.
	if mv.shape == BossMove.Shape.DASH:
		# At the crystal it is going for: a charge across the open field that carries
		# it most of the way there, through anything standing on the line.
		var t := current_target()
		return t.cell if t != null else boss.cell + Vector2i(0, 1)
	if mv.shape == BossMove.Shape.LEAP or mv.shape == BossMove.Shape.HUNT:
		return _thickest(mv)
	if mv.shape == BossMove.Shape.ONRUSH:
		# A hunting Onrush aims each leg at the army; a plain one ignores the aim.
		return _thickest_anywhere() if mv.seeks_army else NO_AIM
	if mv.shape == BossMove.Shape.BLAZE:
		var thick := _thickest_anywhere()
		return thick if thick != NO_AIM else current_target().cell
	var best: UnitInstance = null
	var best_d := AIM_RADIUS + 1
	for v in sim.board.units_in_box(boss.cell, AIM_RADIUS, player_team()):
		if not v.is_alive() or v.structure:
			continue
		var d := BoardModel.box_distance(boss.cell, v.cell)
		if d < best_d or (d == best_d and best != null and v.uid < best.uid):
			best = v
			best_d = d
	if best != null:
		return best.cell
	var t := current_target()
	return t.cell if t != null else boss.cell + Vector2i(0, 1)


func _crystal_after(c: UnitInstance) -> UnitInstance:
	## The crystal it will go for after this one, or this one if it is the last.
	var order: Array = []
	for lane in data.crystal_order:
		order.append(crystals[lane])
	order.append(crystals[3])
	var at := order.find(c)
	for i in range(at + 1, order.size()):
		if (order[i] as UnitInstance).is_alive():
			return order[i]
	return c


func _thickest(mv: BossMove) -> Vector2i:
	## The tile within the leap's reach with the most of the army in the box around
	## it. Ties go to the nearer, then to the lower uid of the unit it centres on.
	var best := current_target().cell
	var best_n := 0
	var best_d := 1 << 30
	var best_uid := 1 << 30
	for v in sim.board.units_in_box(boss.cell, mv.reach, player_team()):
		if not v.is_alive() or v.structure:
			continue
		var n := 0
		for w in sim.board.units_in_box(v.cell, mv.span, player_team()):
			if w.is_alive() and not w.structure:
				n += 1
		var d := BoardModel.box_distance(boss.cell, v.cell)
		if n > best_n or (n == best_n and (d < best_d or (d == best_d and v.uid < best_uid))):
			best = v.cell
			best_n = n
			best_d = d
			best_uid = v.uid
	return best


const NO_AIM := Vector2i(-1, -1)


func _thickest_anywhere() -> Vector2i:
	## The unit of the army, anywhere on the field, with the most of the army packed
	## round it — what a hunting Onrush runs through. Ties go to the one nearer the
	## boss, then to the lower uid. NO_AIM when there is no army on the field.
	var best := NO_AIM
	var best_n := -1
	var best_d := 1 << 30
	var best_uid := 1 << 30
	for v in sim.board.units_view():
		if v.team != player_team() or not v.is_alive() or v.structure:
			continue
		var n := 0
		for w in sim.board.units_in_box(v.cell, 1, player_team()):
			if w.is_alive() and not w.structure:
				n += 1
		var d := BoardModel.box_distance(boss.cell, v.cell)
		if n > best_n or (n == best_n and (d < best_d or (d == best_d and v.uid < best_uid))):
			best = v.cell
			best_n = n
			best_d = d
			best_uid = v.uid
	return best


static func aimed_line(at: Vector2i, aim: Vector2i) -> Array[Vector2i]:
	## Every tile on the straight line from `at` through `aim` and on to the edge of
	## the map — any angle, not just the eight directions. Stepped one tile at a time
	## along the longer axis, so the line has no gaps to slip through.
	var out: Array[Vector2i] = []
	var d := aim - at
	var steps := maxi(absi(d.x), absi(d.y))
	if steps == 0:
		return out
	var inc := Vector2(d) / float(steps)
	for i in range(1, WIDTH + HEIGHT):
		var c := Vector2i(roundi(at.x + inc.x * i), roundi(at.y + inc.y * i))
		if c.x < 0 or c.y < 0 or c.x >= WIDTH or c.y >= HEIGHT:
			break
		out.append(c)
	return out


static func _direction(from: Vector2i, to: Vector2i) -> Vector2i:
	var d := to - from
	var dir := Vector2i(signi(d.x), signi(d.y))
	if dir == Vector2i.ZERO:
		dir = Vector2i(0, 1)
	return dir


static func onrush_direction(at: Vector2i, step: int) -> Vector2i:
	## Which way an Onrush leg runs: always towards the far side of the map from where
	## she stands, and cycling diagonal, across, down-or-up, so the legs criss-cross
	## the whole field instead of tracing one line back and forth.
	var dx := 1 if at.x < WIDTH / 2 else -1
	var dy := 1 if at.y < HEIGHT / 2 else -1
	match step % 3:
		0:
			return Vector2i(dx, dy)
		1:
			return Vector2i(dx, 0)
	return Vector2i(0, dy)


func move_cells(mv: BossMove, at: Vector2i, aim: Vector2i, step := 0) -> Array[Vector2i]:
	## Every tile a move will hit, worked out when it is marked and never again: the
	## mark on the board IS the blow.
	var out: Array[Vector2i] = []
	# Enraged, her blows grow: every two surges widen a band by a row.
	var span := mv.span + enrage_stacks / 2
	match mv.shape:
		BossMove.Shape.ONRUSH:
			if mv.seeks_army and aim != NO_AIM and aim != at:
				# A band, not a thread: `span` tiles wide across the line of the charge.
				var d0 := aim - at
				var side := Vector2i(0, 1) if absi(d0.x) >= absi(d0.y) else Vector2i(1, 0)
				for c in aimed_line(at, aim):
					for k in _band(span):
						out.append(c + side * k)
			else:
				var d := onrush_direction(at, step)
				var c := at + d
				while c.x >= 0 and c.y >= 0 and c.x < WIDTH and c.y < HEIGHT:
					out.append(c)
					c += d
		BossMove.Shape.CROSS:
			for k in _band(span):
				for x in WIDTH:
					out.append(Vector2i(x, at.y + k))
				for y in HEIGHT:
					out.append(Vector2i(at.x + k, y))
		BossMove.Shape.RING:
			for y in HEIGHT:
				for x in WIDTH:
					var r := BoardModel.box_distance(Vector2i(x, y), at)
					if r >= mv.reach and r < mv.reach + maxi(span, 1):
						out.append(Vector2i(x, y))
		BossMove.Shape.STRIPES:
			# The whole stage, top to bottom: there is no row she leaves out.
			for y in HEIGHT:
				if y % 2 == step % 2:
					for x in WIDTH:
						out.append(Vector2i(x, y))
		BossMove.Shape.RAIN:
			var open: Array[Vector2i] = []
			for y in range(HUB_ROWS, HEIGHT):
				for x in WIDTH:
					if not BoardModel.is_blocked(Vector2i(x, y)):
						open.append(Vector2i(x, y))
			for i in mini(mv.count + 4 * enrage_stacks, open.size() / 2):
				out.append(open.pop_at(sim.rng.randi_range(0, open.size() - 1)))
		BossMove.Shape.HUNT:
			for k in _band(span):
				for x in WIDTH:
					out.append(Vector2i(x, aim.y + k))
		BossMove.Shape.ARC:
			# A slice of a circle round her: within `reach`, inside `arc_degrees`. Beat
			# `step` of a sweep is the next slice round from the one before.
			var width := deg_to_rad(mv.arc_degrees + 10.0 * enrage_stacks)
			var base := Vector2(aim - at).angle() if aim != at else PI * 0.5
			var centre := base + (float(step) - float(maxi(mv.legs, 1) - 1) * 0.5) * width
			var r := mv.reach + enrage_stacks / 2
			for y in range(at.y - r, at.y + r + 1):
				for x in range(at.x - r, at.x + r + 1):
					var c := Vector2i(x, y)
					if c == at or Vector2(c - at).length() > float(r) + 0.5:
						continue
					if absf(angle_difference(centre, Vector2(c - at).angle())) <= width * 0.5:
						out.append(c)
		BossMove.Shape.BLAZE:
			for dy in range(-span, span + 1):
				for dx in range(-span, span + 1):
					out.append(aim + Vector2i(dx, dy))
		BossMove.Shape.SUPPRESS:
			for y in range(at.y - mv.reach, at.y + mv.reach + 1):
				for x in range(at.x - mv.reach, at.x + mv.reach + 1):
					if Vector2i(x, y) != at:
						out.append(Vector2i(x, y))
	var dir := _direction(at, aim)
	var sy := dir.y if dir.y != 0 else 1
	var sx := dir.x if dir.x != 0 else 1
	match mv.shape:
		BossMove.Shape.ROWS:
			for k in _band(span):
				for x in range(at.x - mv.reach, at.x + mv.reach + 1):
					out.append(Vector2i(x, at.y + k * sy))
		BossMove.Shape.COLUMNS:
			for k in _band(span):
				for i in range(1, mv.reach + 1):
					out.append(Vector2i(at.x + k * sx, at.y + i * sy))
		BossMove.Shape.THRUST, BossMove.Shape.DASH:
			for i in range(1, mv.reach + 1):
				out.append(at + dir * i)
		BossMove.Shape.LEAP:
			for dy in range(-span, span + 1):
				for dx in range(-span, span + 1):
					out.append(aim + Vector2i(dx, dy))
	var kept: Array[Vector2i] = []
	for c in out:
		if sim != null and not sim.board.in_bounds(c):
			continue
		if BoardModel.is_blocked(c) or kept.has(c):
			continue
		kept.append(c)
	return kept


static func _band(span: int) -> Array[int]:
	## Offsets for a band `span` wide: centred when odd, leaning towards the aim
	## when even (a two-row combo is its own row and the one it is facing).
	var out: Array[int] = []
	var lo := -((span - 1) / 2)
	for k in range(lo, lo + maxi(span, 1)):
		out.append(k)
	return out


func _strike() -> void:
	var mv: BossMove = marked.move
	var cells: Array[Vector2i] = marked.cells
	var aim: Vector2i = marked.aim
	var step := int(marked.get("step", 0))
	# The tier announced when it was marked: what the mark said is what it does.
	var doom := int(marked.get("doom", 0))
	marked = {}
	var p := _phase()
	gap_left = p.gap if p != null else 4.0
	if not boss.is_alive():
		return
	sim._emit("boss_strike", {uid = boss.uid, move = mv.id, name = mv.display_name,
		cells = cells, cell = boss.cell})
	var dmg := boss.stat(StatModifier.Stat.ATTACK_DAMAGE) * maxf(mv.damage_mult, 0.0)
	var victims: Array[UnitInstance] = []
	for c in cells:
		var v := sim.board.unit_at(c)
		if v == null or v.team == boss.team or not v.is_alive() or v.sealed:
			continue
		if v.structure:
			# She never aims a move at a crystal, but a BIG one (wound up first) that
			# sweeps over one standing in the way hurts it, by `crystal_share` of the blow.
			if mv.windup > 0.0 and data.crystal_share > 0.0:
				_crystal_accident = true
				sim._damage(v, dmg * data.crystal_share, boss, true)
				_crystal_accident = false
			continue
		victims.append(v)
	if mv.shape == BossMove.Shape.BLAZE:
		# No burst: the ground starts burning, and keeps burning.
		_blazes.append({cells = cells, left = mv.blaze_seconds, tick = 0.0, soul = mv.windup > 0.0,
			dps = boss.stat(StatModifier.Stat.ATTACK_DAMAGE) * mv.blaze_dps})
		sim._emit("boss_blaze", {uid = boss.uid, cells = cells, seconds = mv.blaze_seconds,
			name = mv.display_name})
		return
	if mv.shape == BossMove.Shape.SUPPRESS:
		var sealed_uids: Array[int] = []
		for v in victims:
			v.mana = 0.0
			v.mana_suppressed = maxf(v.mana_suppressed, mv.suppress_seconds)
			sealed_uids.append(v.uid)
			sim._emit("mana", {uid = v.uid, mana = 0.0, cell = v.cell})
		sim._emit("boss_suppress", {uid = boss.uid, cells = cells, uids = sealed_uids,
			seconds = mv.suppress_seconds, name = mv.display_name})
		return
	var doomed := doom
	var executed: Array[Vector2i] = []
	for v in victims:
		if doomed > 0 and v.data.tier >= doomed:
			# Her execution: the army's best die outright where they stand.
			executed.append(v.cell)
			_soul_blow = true
			sim._execute(boss, v)
			_soul_blow = false
			continue
		# And a share of the victim's own full health on top, for the moves that have it.
		var hit := dmg + v.stat(StatModifier.Stat.MAX_HP) * maxf(mv.max_hp_percent, 0.0)
		_soul_blow = mv.windup > 0.0
		sim._damage(v, hit, boss, true)
		_soul_blow = false
	if not executed.is_empty():
		sim._emit("boss_execute", {uid = boss.uid, name = mv.display_name, cells = executed,
			tier = doomed, cell = boss.cell})
	if mv.shape == BossMove.Shape.DASH or mv.shape == BossMove.Shape.LEAP \
			or mv.shape == BossMove.Shape.ONRUSH:
		_land(mv, cells, aim)
	# Chained moves: the next leg or beat is marked the moment this one lands, so
	# each part is telegraphed on its own before it comes.
	# Enraged, every surge adds a dash to her Onrush.
	if mv.shape == BossMove.Shape.ONRUSH and step + 1 < mv.legs + enrage_stacks:
		_mark(mv, step + 1)
	elif mv.shape == BossMove.Shape.ARC and step + 1 < maxi(mv.legs, 1):
		_mark(mv, step + 1)
	elif mv.shape == BossMove.Shape.STRIPES and step == 0:
		_mark(mv, 1)


func _land(mv: BossMove, cells: Array[Vector2i], aim: Vector2i) -> void:
	## Where a dash or a leap leaves the boss: as far along the dash as it can stand,
	## or beside the crowd it leapt on.
	var to := boss.cell
	if mv.shape == BossMove.Shape.DASH or mv.shape == BossMove.Shape.ONRUSH:
		for i in range(cells.size() - 1, -1, -1):
			if sim.board.is_empty(cells[i]):
				to = cells[i]
				break
	else:
		to = _nearest_free(aim, boss.cell)
	if to == boss.cell:
		return
	var from := boss.cell
	if sim.board.move_unit(boss, to):
		boss.move_from = from
		sim._emit("move", {uid = boss.uid, from = from, to = to, duration = LEAP_TIME,
			leap = true})


func _nearest_free(centre: Vector2i, fallback: Vector2i) -> Vector2i:
	var best := fallback
	var best_d := 1 << 30
	for dy in range(-2, 3):
		for dx in range(-2, 3):
			var c := centre + Vector2i(dx, dy)
			if not sim.board.in_bounds(c) or not sim.board.is_empty(c):
				continue
			var d := BoardModel.box_distance(c, centre) * 10 + BoardModel.tile_distance(c, centre)
			if d < best_d:
				best = c
				best_d = d
	return best


# --- The clocks ---------------------------------------------------------------

# --- The clocks ---------------------------------------------------------------

func tick() -> void:
	# No healing of hers — lifesteal included — ever climbs past the top of the bar
	# she is on: healing undoes damage, never a phase.
	if boss.is_alive() and not data.phases.is_empty():
		var top := data.phases[phase].hp_threshold * boss.stat(StatModifier.Stat.MAX_HP)
		if boss.current_hp > top:
			boss.current_hp = top
	if in_stance():
		_tick_stance()
	elif bool(marked.get("windup", false)):
		marked.left = float(marked.left) - CombatSim.TICK
		if float(marked.left) <= 0.0:
			_mark(marked.move, 0, true)
	elif bool(marked.get("retreat", false)):
		_tick_retreat()
	elif not marked.is_empty():
		marked.left = float(marked.left) - CombatSim.TICK
		if float(marked.left) <= 0.0:
			_strike()
	elif pause_left > 0.0:
		pause_left = maxf(pause_left - CombatSim.TICK, 0.0)
		if pause_left <= 0.0:
			# The bar's break is over: it can be hurt again.
			boss.sealed = false
			# And the new phase opens with its signature move.
			var opener := _phase().entry_move if _phase() != null else null
			if opener != null and boss.is_alive() and marked.is_empty():
				_mark(opener)
	elif gap_left > 0.0:
		gap_left -= CombatSim.TICK
	_tick_enrage()
	_tick_death_power()
	_tick_hazards()
	_tick_solitude()
	_tick_regen()
	_tick_boosts()
	_tick_rebuilds()
	_tick_summons()
	_refresh_upgrades()
	_check_crystals()
	_check_phase()
	wave_left -= CombatSim.TICK
	if wave_left <= 0.0:
		wave_left += data.wave_seconds
		send_wave()
	_drop_queued()


func _check_crystals() -> void:
	if merged or lane_crystals_left() > 0:
		return
	merged = true
	crystals[3].sealed = false
	for uid in zone_of_uid.keys():
		zone_of_uid[uid] = 3
	# Whatever was still waiting for the zones goes to the centre instead.
	for zone in 3:
		for e in queued[zone]:
			queued[3].append(e)
		queued[zone] = []
	sim._emit("crystals_merge", {central_uid = crystals[3].uid,
		cell = crystals[3].cell})
	_check_phase()
	# The armies merge now, not at the next wave: the centre is under attack.
	send_wave()
	wave_left = data.wave_seconds


# --- Waves --------------------------------------------------------------------

func send_wave() -> void:
	## One fresh copy of every Barracks section, on top of whoever is still
	## standing: each to its own zone's crystal, or all to the centre once merged.
	waves += 1
	if barracks != null:
		for section in Barracks.SECTIONS:
			# A section whose crystal has fallen sends its waves to the Central Crystal
			# from then on; the others keep coming to their own until theirs falls.
			var zone := 3 if merged or not crystals[section].is_alive() else section
			for e in barracks.template(section):
				queued[zone].append(e)
	# At most one section's worth may wait per zone (three for the merged centre):
	# a zone that has been full for three waves does not owe the player three armies
	# the moment it clears.
	for zone in 4:
		var cap := _queue_cap(zone)
		while (queued[zone] as Array).size() > cap:
			(queued[zone] as Array).pop_front()
	var placed := _drop_queued()
	var waiting := 0
	for q in queued:
		waiting += (q as Array).size()
	sim._emit("wave", {index = waves, placed = placed, queued = waiting,
		next_in = data.wave_seconds, merged = merged})


func _queue_cap(zone: int) -> int:
	var per := barracks.slot_count() if barracks != null else 0
	return per * 3 if zone == 3 else per


## Whether each zone's army on the field is held to BossData.zone_cap. Off by default
## (Settings: Army limit): every wave lands in full as long as there is ground to
## stand on. On, a full zone keeps the rest of its wave waiting.
var limit_army := false


func zone_cap(zone: int) -> int:
	if not limit_army or data.zone_cap <= 0:
		return 1 << 20
	return data.zone_cap * 3 if zone == 3 else data.zone_cap


func army_in_zone(zone: int) -> int:
	## How many of a zone's guards are on their feet.
	var n := 0
	for u in sim._units:
		if u.is_alive() and int(zone_of_uid.get(u.uid, -9)) == zone:
			n += 1
	for u in sim._pending_units:
		if u.is_alive() and int(zone_of_uid.get(u.uid, -9)) == zone:
			n += 1
	return n


func _drop_queued() -> int:
	var placed := 0
	for zone in 4:
		var q: Array = queued[zone]
		if q.is_empty():
			continue
		var room := zone_cap(zone) - army_in_zone(zone)
		while not q.is_empty() and room > 0:
			var e: Dictionary = q[0]
			var cell := spawn_cell(zone, e)
			if cell == Vector2i(-1, -1):
				break
			q.pop_front()
			_spawn(e, cell, zone)
			placed += 1
			room -= 1
	return placed


func home_cell(zone: int, e: Dictionary) -> Vector2i:
	## Where a unit from this Barracks slot would ideally stand: its slot laid out
	## just in front of its crystal. After the merge every section packs in round
	## the Central Crystal, nearest first, so the whole army lands in the centre.
	var off: Vector2i = barracks.slot_offset(int(e.slot)) if barracks != null else Vector2i.ZERO
	if zone == 3:
		return CENTRAL_CELL + off
	return crystals[zone].cell + off


func spawn_cell(zone: int, e: Dictionary) -> Vector2i:
	## The free tile nearest its home, searched outwards ring by ring. A unit lands
	## near where it is meant to be or, on a crowded field, as near as it can.
	var home := home_cell(zone, e)
	for r in maxi(WIDTH, HEIGHT):
		var best := Vector2i(-1, -1)
		var best_d := 1 << 30
		for dy in range(-r, r + 1):
			for dx in range(-r, r + 1):
				if maxi(absi(dx), absi(dy)) != r:
					continue
				var c := home + Vector2i(dx, dy)
				if not sim.board.in_bounds(c) or not sim.board.is_empty(c):
					continue
				if c.y < HUB_ROWS:
					continue
				var d := absi(dx) + absi(dy)
				if d < best_d:
					best = c
					best_d = d
		if best != Vector2i(-1, -1):
			return best
	return Vector2i(-1, -1)


func _spawn(e: Dictionary, cell: Vector2i, zone: int) -> void:
	var base: UnitData = e.data
	var u := UnitInstance.create(barracks.field_data(base) if barracks != null else base,
		player_team())
	var tb: TeamBuffs = sim.team_buffs.get(player_team(), null)
	if tb != null:
		tb.apply_to(u)
	if not sim.board.force_place(u, cell):
		return
	u.current_hp = u.stat(StatModifier.Stat.MAX_HP)
	u.move_from = cell
	zone_of_uid[u.uid] = zone
	base_of_uid[u.uid] = base
	sim._pending_units.append(u)
	sim._emit("summon", {
		uid = u.uid, owner_uid = -1, team = u.team, cell = cell,
		unit_id = u.data.id, tier = u.data.tier,
		hp = u.current_hp, max_hp = u.stat(StatModifier.Stat.MAX_HP),
		has_ability = u.data.ability != null, permanent = false, wave = true,
		zone = zone,
	})


func living_army() -> int:
	var n := 0
	for u in sim._units:
		if u.team == player_team() and u.is_alive() and not u.structure:
			n += 1
	for u in sim._pending_units:
		if u.team == player_team() and u.is_alive():
			n += 1
	return n


func _check_phase() -> void:
	if data == null or data.phases.is_empty():
		return
	var frac := boss.current_hp / maxf(boss.stat(StatModifier.Stat.MAX_HP), 1.0)
	var want := data.phase_for(frac, merged)
	if want <= phase:
		return
	# Beaten down to the next bar while she was off healing: the retreat is cut
	# short, and she gains nothing from it.
	if bool(marked.get("retreat", false)):
		_end_retreat(false)
	# One bar at a time. Each phase is its own health bar: however big the blow that
	# emptied this one, the next starts full — the overflow is lost — and nothing
	# can hurt the boss during the announcement.
	phase = phase + 1
	var top := data.phases[phase].hp_threshold * boss.stat(StatModifier.Stat.MAX_HP)
	boss.current_hp = maxf(boss.current_hp, top)
	move_index = 0
	_apply_phase_mods()
	var p := _phase()
	# The announcement: it stops for a breath, and its next move comes a full gap
	# after that, so the change of pattern is something you see coming.
	pause_left = maxf(p.entry_pause, 0.0)
	boss.sealed = pause_left > 0.0
	gap_left = maxf(gap_left, p.gap)
	sim._emit("boss_phase", {uid = boss.uid, index = phase, name = _phase_name(),
		cell = boss.cell, seconds = pause_left, hp = boss.current_hp})
	_summon_wave(p.summons_on_start, p.minion_power)
	summon_left = p.summon_every


func bar_of(hp: float) -> Vector2:
	## The current phase's own bar: (health left in it, its size).
	var full := boss.stat(StatModifier.Stat.MAX_HP)
	var top := data.phases[phase].hp_threshold * full
	var bottom := (data.phases[phase + 1].hp_threshold * full
		if phase + 1 < data.phases.size() else 0.0)
	return Vector2(clampf(hp - bottom, 0.0, top - bottom), top - bottom)


# --- Summons ------------------------------------------------------------------

var summon_left := 0.0
const MINION_ID := &"crimson_shade"
## Circles marked on the ground, each becoming a minion when its clock runs out.
var _summon_marks: Array[Dictionary] = []


func minions_alive() -> int:
	var n := 0
	for u in sim._units:
		if u.is_alive() and u.team == boss_team() and u != boss:
			n += 1
	for u in sim._pending_units:
		if u.is_alive() and u.team == boss_team():
			n += 1
	return n + _summon_marks.size()


func _tick_summons() -> void:
	var p := _phase()
	if data.flank_kind != null and data.flank_every > 0.0 and boss.is_alive():
		flank_left -= CombatSim.TICK
		if flank_left <= 0.0:
			flank_left += data.flank_every
			_flank()
	if data.swarm_kind != null and data.swarm_every > 0.0 and boss.is_alive():
		swarm_left -= CombatSim.TICK
		if swarm_left <= 0.0:
			swarm_left += data.swarm_every
			_swarm()
	if p != null and p.summon_every > 0.0 and boss.is_alive():
		summon_left -= CombatSim.TICK
		if summon_left <= 0.0:
			summon_left += p.summon_every
			_summon_wave(p.summon_count, p.minion_power)
	var i := _summon_marks.size() - 1
	while i >= 0:
		var m: Dictionary = _summon_marks[i]
		m.left = float(m.left) - CombatSim.TICK
		if float(m.left) <= 0.0:
			_summon_marks.remove_at(i)
			_spawn_minion(m.cell, float(m.power), m.get("kind", null))
		i -= 1
	_refresh_ward()
	_tick_menders()


## Healing owed to the boss but not yet shown, so the bar is told about it a few
## times a second rather than every tick.
var _heal_unshown := 0.0
var _heal_clock := 0.0


func _tick_menders() -> void:
	## Every summon that mends her does so while it stands — kill them to stop it.
	if not boss.is_alive():
		return
	var rate := 0.0
	for u in sim._units:
		if u.is_alive() and u.team == boss_team() and u != boss:
			rate += float(_heal_rate.get(u.uid, 0.0))
	if bool(marked.get("retreat", false)):
		rate += (marked.move as BossMove).retreat_heal
	if rate > 0.0:
		heal_boss(boss.stat(StatModifier.Stat.MAX_HP) * rate * CombatSim.TICK)
	_heal_clock -= CombatSim.TICK
	if _heal_clock <= 0.0:
		_heal_clock = 0.5
		if _heal_unshown > 0.0:
			sim._emit("heal", {uid = boss.uid, amount = _heal_unshown, hp = boss.current_hp,
				cell = boss.cell})
			_heal_unshown = 0.0


func heal_boss(amount: float) -> float:
	## Mends her, never past the top of the health bar she is on: healing can undo
	## damage, not a phase. Returns how much it actually mended.
	if amount <= 0.0 or not boss.is_alive():
		return 0.0
	var top := data.phases[phase].hp_threshold * boss.stat(StatModifier.Stat.MAX_HP)
	var before := boss.current_hp
	boss.current_hp = minf(boss.current_hp + amount, maxf(top, before))
	var got := boss.current_hp - before
	_heal_unshown += got
	return got


## The damage cut the boss gets from the shades standing beside her, and how many it
## was worked out for — so it is only re-laid when that number changes.
var _ward_mod: StatModifier = null
var _ward_shades := 0


func shades_alive() -> int:
	var n := 0
	for u in sim._units:
		if u.is_alive() and u.team == boss_team() and u != boss and u.data.id == MINION_ID:
			n += 1
	return n


func _refresh_ward() -> void:
	## While shades stand, she takes less damage: a share per shade. Killing them is
	## how you take it away again.
	if data.minion_ward_per_shade <= 0.0:
		return
	var n := shades_alive() if boss.is_alive() else 0
	if n == _ward_shades:
		return
	_ward_shades = n
	if _ward_mod != null:
		boss.battle_modifiers.erase(_ward_mod)
		_ward_mod = null
	var cut := clampf(data.minion_ward_per_shade * float(n), 0.0, 0.3)
	if n > 0:
		_ward_mod = StatModifier.make(StatModifier.Stat.DAMAGE_TAKEN,
			StatModifier.Mode.PERCENT, -cut)
		boss.add_battle_modifier(_ward_mod)
	sim._emit("boss_ward", {uid = boss.uid, cell = boss.cell, shades = n, cut = cut})


var _pool_n := 0
## Seconds until her next swarm of fodder.
var swarm_left := 30.0
## Seconds until her next flankers.
var flank_left := 20.0


func _flank() -> void:
	## Stalkers step in at the edge of the arena nearest the army's ranged units —
	## behind the back line, where the bows thought they were safe.
	var shooters: Array[UnitInstance] = []
	for v in sim._units:
		if v.is_alive() and v.team == player_team() and not v.structure and v.is_ranged():
			shooters.append(v)
	if shooters.is_empty():
		return
	var cells: Array[Vector2i] = []
	for i in data.flank_count + phase:
		if minions_alive() + cells.size() >= summon_ceiling():
			break
		var prey: UnitInstance = shooters[i % shooters.size()]
		var edges := [Vector2i(0, prey.cell.y), Vector2i(WIDTH - 1, prey.cell.y),
			Vector2i(prey.cell.x, HEIGHT - 1)]
		var edge: Vector2i = edges[0]
		for e in edges:
			if BoardModel.tile_distance(e, prey.cell) < BoardModel.tile_distance(edge, prey.cell):
				edge = e
		var c := _free_tile_near(edge, cells)
		if c == NO_AIM:
			continue
		cells.append(c)
		_summon_marks.append({cell = c, left = data.summon_warning,
			power = _phase().minion_power if _phase() != null else 1.0, kind = data.flank_kind})
	if not cells.is_empty():
		sim._emit("boss_summon", {uid = boss.uid, cells = cells, seconds = data.summon_warning,
			cell = boss.cell, flank = true})


func _free_tile_near(want: Vector2i, taken: Array[Vector2i]) -> Vector2i:
	## The free field tile (below the hub) nearest `want`, not already in `taken`.
	for r in 6:
		var best := NO_AIM
		var best_d := 1 << 30
		for dy in range(-r, r + 1):
			for dx in range(-r, r + 1):
				if maxi(absi(dx), absi(dy)) != r:
					continue
				var c := want + Vector2i(dx, dy)
				if c.y < HUB_ROWS or not sim.board.in_bounds(c) or not sim.board.is_empty(c):
					continue
				if BoardModel.is_blocked(c) or taken.has(c):
					continue
				var d := absi(dx) + absi(dy)
				if d < best_d:
					best = c
					best_d = d
		if best != NO_AIM:
			return best
	return NO_AIM


func summon_ceiling() -> int:
	## However she calls them — waves, swarms, flankers, retreats — no more than this
	## many of her summons stand at once: twice her ordinary cap. Unkilled, they would
	## otherwise pile up until they boxed her in.
	return maxi(data.minion_cap, 1) * 2


func _swarm() -> void:
	## A crowd of fodder at once, in circles spread round her.
	var cells: Array[Vector2i] = []
	for i in data.swarm_count:
		if minions_alive() + cells.size() >= summon_ceiling():
			break
		var ang := TAU * float(i) / float(maxi(data.swarm_count, 1))
		var r := 2.0 + float(i % 3)
		var want := boss.cell + Vector2i(roundi(cos(ang) * r), roundi(sin(ang) * r) + 3)
		var c := _free_tile_near(want, cells)
		if c == NO_AIM:
			continue
		cells.append(c)
		_summon_marks.append({cell = c, left = data.summon_warning, power = 1.0,
			kind = data.swarm_kind})
	if not cells.is_empty():
		sim._emit("boss_summon", {uid = boss.uid, cells = cells, seconds = data.summon_warning,
			cell = boss.cell, swarm = true})
## uid -> how one of her summons picks its target (BossMinion.Targeting).
var _targeting: Dictionary = {}


func _next_pool_kind() -> BossMinion:
	if data.summon_pool.is_empty():
		return null
	var k: BossMinion = data.summon_pool[_pool_n % data.summon_pool.size()]
	_pool_n += 1
	return k


func minion_tier() -> int:
	return clampi(data.minion_base_tier + phase + enrage_stacks / 2, 1, 6)


func _summon_wave(count: int, power: float) -> void:
	## Marks `count` summoning circles round the boss (up to the cap). Each becomes a
	## minion `summon_warning` seconds later — the circle is the telegraph.
	var cells: Array[Vector2i] = []
	for i in count:
		if minions_alive() + cells.size() >= data.minion_cap:
			break
		var c := _nearest_free(boss.cell + Vector2i([-2, 2, 0, -1, 1][i % 5], 2), boss.cell)
		if c == boss.cell or cells.has(c):
			continue
		cells.append(c)
	if cells.is_empty():
		return
	for c in cells:
		_summon_marks.append({cell = c, left = data.summon_warning, power = power, kind = _next_pool_kind()})
	sim._emit("boss_summon", {uid = boss.uid, cells = cells, seconds = data.summon_warning,
		cell = boss.cell})


## uid -> the share of her full health a standing summon mends each second.
var _heal_rate: Dictionary = {}


func _spawn_minion(cell: Vector2i, power: float, kind: BossMinion = null) -> UnitInstance:
	## One summon stepping out of its circle: an ordinary shade, or `kind`.
	power *= 1.0 + data.enrage_minions * float(enrage_stacks)
	if not boss.is_alive():
		return null
	if not sim.board.is_empty(cell):
		cell = _nearest_free(cell, Vector2i(-1, -1))
		if cell == Vector2i(-1, -1):
			return null
	var md := UnitData.new()
	md.sight_range = 40
	md.mana_per_attack = 0.0
	# Her summons grow with the fight: a tier per phase, and more as she enrages.
	md.tier = minion_tier()
	var burst := data.minion_burst_mult
	if kind == null:
		md.id = MINION_ID
		md.display_name = data.minion_name
		md.max_hp = data.minion_hp * power
		md.attack_damage = data.minion_attack * power
		md.attack_speed = data.minion_attack_speed
		md.move_time = data.minion_move_time
		md.accent = data.accent.lightened(0.25)
	else:
		md.id = kind.id
		md.display_name = kind.display_name
		md.max_hp = kind.max_hp * power
		md.attack_damage = kind.attack_damage * power
		md.attack_speed = kind.attack_speed
		md.move_time = kind.move_time
		md.attack_range = kind.attack_range
		md.attack_type = UnitData.AttackType.RANGED if kind.ranged else UnitData.AttackType.MELEE
		md.can_move = kind.can_move
		md.can_attack = kind.can_attack
		md.accent = kind.accent
		burst = kind.burst_mult
		md.empower_splash_radius = kind.cleave_radius
	var m := UnitInstance.create(md, boss_team())
	if not sim.board.force_place(m, cell):
		return null
	m.current_hp = m.stat(StatModifier.Stat.MAX_HP)
	m.move_from = cell
	sim._pending_units.append(m)
	if kind != null and kind.heal_boss > 0.0:
		_heal_rate[m.uid] = kind.heal_boss
	if kind != null:
		_targeting[m.uid] = kind.targeting
		if kind.soul_taker:
			_soul_takers[m.uid] = true
		if kind.cleave_radius > 0:
			# Its swings land on everything round what it hits.
			m.empowered = true
	sim._emit("summon", {
		uid = m.uid, owner_uid = boss.uid, team = m.team, cell = cell,
		unit_id = md.id, tier = md.tier, hp = m.current_hp, max_hp = m.current_hp,
		has_ability = false, permanent = false, minion = true,
	})
	_shade_burst(m, burst)
	return m


func _shade_burst(m: UnitInstance, mult: float) -> void:
	## A shade does not just appear: it tears out of its circle, hitting everything of
	## the army around it. The circle was the warning — standing in it costs.
	if mult <= 0.0:
		return
	var dmg := m.stat(StatModifier.Stat.ATTACK_DAMAGE) * mult
	var r := maxi(data.minion_burst_radius, 0)
	var cells: Array[Vector2i] = []
	for dy in range(-r, r + 1):
		for dx in range(-r, r + 1):
			var c := m.cell + Vector2i(dx, dy)
			if sim.board.in_bounds(c):
				cells.append(c)
	sim._emit("shade_burst", {uid = m.uid, cell = m.cell, cells = cells, radius = r})
	for v in sim.board.units_in_box(m.cell, r, player_team()):
		if v.is_alive() and not v.structure and not v.sealed:
			sim._damage(v, dmg, m, true)


# --- Upgrades reach the field -------------------------------------------------

var _seen_revision := 0
## uid -> the plain (un-upgraded) UnitData a unit was sent as, so an upgrade bought
## later can be laid over it.
var base_of_uid: Dictionary = {}


func _refresh_upgrades() -> void:
	## An upgrade bought mid-fight reaches the units already fighting, not just the
	## next wave: each takes its type's new level, keeping the share of health it had.
	if barracks == null or barracks.revision == _seen_revision:
		return
	_seen_revision = barracks.revision
	for u in sim._units:
		if not u.is_alive() or u.team != player_team() or not base_of_uid.has(u.uid):
			continue
		var want := barracks.field_data(base_of_uid[u.uid])
		if want == u.data:
			continue
		var frac := u.current_hp / maxf(u.stat(StatModifier.Stat.MAX_HP), 1.0)
		u.data = want
		u.current_hp = u.stat(StatModifier.Stat.MAX_HP) * frac
		sim._emit("upgraded", {uid = u.uid, cell = u.cell, hp = u.current_hp,
			max_hp = u.stat(StatModifier.Stat.MAX_HP)})


func _apply_phase_mods() -> void:
	## Haste and lifesteal for the phase, as battle modifiers on the boss, replacing
	## the last phase's. Lifesteal through the stat means every source of its damage
	## heals it — swings and moves alike — through the sim's one drain rule.
	for m in _phase_mods:
		boss.battle_modifiers.erase(m)
	_phase_mods.clear()
	var p := _phase()
	if p == null:
		return
	if not is_equal_approx(p.haste, 1.0):
		_phase_mods.append(StatModifier.make(StatModifier.Stat.ATTACK_SPEED,
			StatModifier.Mode.PERCENT, p.haste - 1.0))
		_phase_mods.append(StatModifier.make(StatModifier.Stat.MOVE_TIME,
			StatModifier.Mode.PERCENT,
			BuffData.signed_percent(StatModifier.Stat.MOVE_TIME, p.haste - 1.0)))
	if p.lifesteal > 0.0:
		_phase_mods.append(StatModifier.make(StatModifier.Stat.LIFESTEAL,
			StatModifier.Mode.FLAT, p.lifesteal))
	if p.attack_bonus > 0.0:
		_phase_mods.append(StatModifier.make(StatModifier.Stat.ATTACK_DAMAGE,
			StatModifier.Mode.PERCENT, p.attack_bonus))
	for m in _phase_mods:
		boss.add_battle_modifier(m)




# --- Crystals rebuild ---------------------------------------------------------

## lane -> seconds until a broken zone crystal stands again.
var rebuilding: Dictionary = {}
## lane -> how many times that crystal has been broken.
var times_broken: Dictionary = {}


func _tick_rebuilds() -> void:
	## A broken zone crystal rebuilds itself after crystal_rebuild_seconds, at
	## crystal_rebuild_fraction of its health. While it is down its section's waves
	## go to the Central Crystal; once it stands again they come back to it, and —
	## until the seal has lifted — so does the boss, in her fixed order.
	for i in 3:
		var c := crystals[i]
		if c.is_alive():
			continue
		if not rebuilding.has(i):
			# Each time a crystal is broken it takes twice as long to come back: 90 s,
			# 180, 360... A rebuilt crystal makes the centre immune again, and without
			# this the three could keep rebuilding faster than she can cross the field
			# between them, and the fight would never end.
			var n := int(times_broken.get(i, 0))
			times_broken[i] = n + 1
			var secs := data.crystal_rebuild_seconds * pow(2.0, n)
			rebuilding[i] = secs
			sim._emit("crystal_rebuilding", {uid = c.uid, cell = c.cell, lane = i,
				seconds = secs})
		rebuilding[i] = float(rebuilding[i]) - CombatSim.TICK
		if float(rebuilding[i]) <= 0.0 and _restore_crystal(i):
			rebuilding.erase(i)


func _restore_crystal(i: int) -> bool:
	var c := crystals[i]
	var cell: Vector2i = CRYSTAL_CELLS[i]
	if not sim.board.is_empty(cell):
		# Somebody is standing on its spot: it waits until they move.
		return false
	if not sim.board.force_place(c, cell):
		return false
	c.state = UnitInstance.State.IDLE
	# Its rebuild is done, however it was brought back: the next break starts a new one.
	rebuilding.erase(i)
	c.target = null
	c.shield = 0.0
	c.current_hp = c.stat(StatModifier.Stat.MAX_HP) * clampf(data.crystal_rebuild_fraction, 0.05, 1.0)
	# The view put its body away when it broke; a "summon" brings one back.
	sim._emit("summon", {uid = c.uid, owner_uid = -1, team = c.team, cell = cell,
		unit_id = c.data.id, tier = 1, hp = c.current_hp,
		max_hp = c.stat(StatModifier.Stat.MAX_HP), has_ability = false, permanent = true,
		wave = true, restored = true})
	sim._emit("crystal_restored", {uid = c.uid, cell = cell, lane = i, hp = c.current_hp})
	return true


func minion_target(u: UnitInstance) -> UnitInstance:
	## What one of her summons fights. Never a crystal — those are hers alone to break.
	## Most go for the nearest of the army; a Headhunter for its highest tier, wherever
	## it stands; a Berserker for the thickest knot.
	var how := int(_targeting.get(u.uid, BossMinion.Targeting.NEAREST))
	if how == BossMinion.Targeting.TOP_TIER:
		var prey: UnitInstance = null
		for v in sim._units:
			if not v.is_alive() or v.team != player_team() or v.structure or v.is_hidden():
				continue
			if prey == null or v.data.tier > prey.data.tier or (v.data.tier == prey.data.tier
					and BoardModel.tile_distance(u.cell, v.cell) < BoardModel.tile_distance(u.cell, prey.cell)):
				prey = v
		if prey != null:
			return prey
	elif how == BossMinion.Targeting.RANGED:
		var shooter: UnitInstance = null
		var best_d := 1 << 30
		for v in sim._units:
			if not v.is_alive() or v.team != player_team() or v.structure or v.is_hidden():
				continue
			if not v.is_ranged():
				continue
			var d := BoardModel.tile_distance(u.cell, v.cell)
			if d < best_d:
				shooter = v
				best_d = d
		if shooter != null:
			return shooter
	elif how == BossMinion.Targeting.CROWD:
		var knot := _thickest_anywhere()
		if knot != NO_AIM:
			var at_knot := sim.board.unit_at(knot)
			if at_knot != null and at_knot.is_alive():
				return at_knot
	var best: UnitInstance = null
	var best_d := 1 << 30
	for v in sim._units:
		if not v.is_alive() or v.team != player_team() or v.structure or v.is_hidden():
			continue
		var d := BoardModel.tile_distance(u.cell, v.cell)
		if d < best_d or (d == best_d and best != null and v.uid < best.uid):
			best = v
			best_d = d
	return best


# --- Souls, solitude ----------------------------------------------------------

func soul_kills(killer_uid: int, victim: UnitInstance) -> bool:
	## Only her BIG attacks take souls — the ones she winds up first, and the
	## executions they carry. What they kill stays dead: no Revenant's second wind,
	## and no Vigil raises it. Her ordinary swings, her quick moves and her summons
	## kill the ordinary way, and those can still come back.
	if victim == null or victim.team != player_team():
		return false
	if killer_uid == boss.uid:
		return _soul_blow
	# And the few summons that take souls too (the Headhunter).
	return _soul_takers.has(killer_uid)


## True while one of her big (wound-up) attacks is landing, burning included.
var _soul_blow := false
## uids of her summons whose kills take souls.
var _soul_takers: Dictionary = {}


## Paragons are empowered only with no other Paragon within this many tiles, and a
## Pariah strikes hardest with no ally near it at all — both re-read all fight long,
## since in this mode the army never stands still at an opening bell.
const PARAGON_SPACE := 3
var _empower_mods: Dictionary = {}
## uid -> seconds before a unit may step away again to find its solitude.
var _solitude_cd: Dictionary = {}


func wants_solitude(u: UnitInstance) -> bool:
	return u.team == player_team() and (u.data.alone_hp_damage > 0.0 or u.data.solo_empower)


func solitude_crowding(u: UnitInstance, at: Vector2i) -> int:
	## How badly `at` spoils this unit's solitude: allies too close for a Pariah,
	## other Paragons too close for a Paragon. 0 is alone.
	var n := 0
	for o in sim._units:
		if o == u or o.team != u.team or not o.is_alive() or o.structure:
			continue
		var d := BoardModel.box_distance(o.cell, at)
		if u.data.solo_empower:
			if o.data.id == u.data.id and d <= PARAGON_SPACE:
				n += PARAGON_SPACE + 1 - d
		elif d <= CombatSim.ISOLATION_RADIUS:
			n += 1
	return n


func _tick_solitude() -> void:
	for u in sim._units:
		if not u.is_alive() or not wants_solitude(u):
			continue
		if _solitude_cd.has(u.uid):
			_solitude_cd[u.uid] = maxf(float(_solitude_cd[u.uid]) - CombatSim.TICK, 0.0)
		var alone := solitude_crowding(u, u.cell) == 0
		if u.data.alone_hp_damage > 0.0 and alone != u.isolated:
			u.isolated = alone
			sim._emit("isolated" if alone else "crowded", {uid = u.uid, cell = u.cell})
		if u.data.solo_empower and alone != u.empowered:
			_set_empowered(u, alone)


func _set_empowered(u: UnitInstance, on: bool) -> void:
	var frac := u.current_hp / maxf(u.stat(StatModifier.Stat.MAX_HP), 1.0)
	for m in _empower_mods.get(u.uid, []):
		u.battle_modifiers.erase(m)
	_empower_mods.erase(u.uid)
	u.empowered = on
	if on:
		var mods: Array[StatModifier] = []
		if u.data.empower_hp_mult > 1.0:
			mods.append(StatModifier.make(StatModifier.Stat.MAX_HP, StatModifier.Mode.PERCENT,
				u.data.empower_hp_mult - 1.0))
		if u.data.empower_damage_mult > 1.0:
			mods.append(StatModifier.make(StatModifier.Stat.ATTACK_DAMAGE, StatModifier.Mode.PERCENT,
				u.data.empower_damage_mult - 1.0))
		if not is_equal_approx(u.data.empower_attack_speed_mult, 1.0):
			mods.append(StatModifier.make(StatModifier.Stat.ATTACK_SPEED, StatModifier.Mode.PERCENT,
				maxf(u.data.empower_attack_speed_mult, 0.05) - 1.0))
		for m in mods:
			u.add_battle_modifier(m)
		_empower_mods[u.uid] = mods
	# Same share of health either way, so stepping in and out is not a heal.
	u.current_hp = maxf(frac * u.stat(StatModifier.Stat.MAX_HP), 1.0)
	sim._emit("empowered" if on else "unempowered", {uid = u.uid, cell = u.cell,
		hp = u.current_hp, max_hp = u.stat(StatModifier.Stat.MAX_HP)})


func seek_solitude(u: UnitInstance) -> bool:
	## A Pariah or Paragon crowded by its own side steps away to be alone — it
	## goes looking for the room its power needs. One step at a time, at most once a
	## second, and only to a tile that is less crowded; ties go towards its target.
	if not wants_solitude(u) or not u.can_move_now():
		return false
	if float(_solitude_cd.get(u.uid, 0.0)) > 0.0:
		return false
	var here := solitude_crowding(u, u.cell)
	if here == 0:
		return false
	var best := u.cell
	var best_n := here
	var best_d := 1 << 30
	for off in sim._neighbour_offsets():
		var c: Vector2i = u.cell + off
		if not sim.board.in_bounds(c) or not sim.board.is_empty(c) or BoardModel.is_blocked(c):
			continue
		if BoardModel.blocks_between(u.cell, c) or not BoardModel.can_climb(u.cell, c):
			continue
		var n := solitude_crowding(u, c)
		var d := BoardModel.tile_distance(c, u.target.cell) if u.target != null else 0
		if n < best_n or (n == best_n and n < here and d < best_d):
			best = c
			best_n = n
			best_d = d
	if best == u.cell:
		return false
	_solitude_cd[u.uid] = 1.0
	return sim._step_to(u, best)
