class_name UnitInstance
extends RefCounted

enum State {
	IDLE,
	MOVING,
	ATTACKING,
	CASTING,
	DEAD,
}

const MIN_TIME := 0.05

const MANA_MAX := 100.0

static var _next_uid: int = 1

var data: UnitData = null
var team: int = 0
var cell: Vector2i = Vector2i(-1, -1)
var current_hp: float = 0.0
var modifiers: Array[StatModifier] = []
var uid: int = 0

var state: State = State.IDLE
var state_timer: float = 0.0
var target: UnitInstance = null
var move_from: Vector2i = Vector2i(-1, -1)
var mana: float = 0.0
var has_opened: bool = false
var pending_target_uid: int = -1

var shield: float = 0.0

var battle_modifiers: Array[StatModifier] = []
var haste_stacks: int = 0
var stealth_left: float = 0.0
var revives: int = 0
var summons_made: int = 0
var mana_clock: float = 0.0

# Who called this unit onto the board, or -1 for one that was deployed. A
# retinue is capped by how many of its summons are *standing*, not by how many
# were ever made, so the caster has to be able to find its own again.
var summoned_by: int = -1

# Set on a unit raised by an ability that keeps its summons. Survives
# reset_for_battle deliberately: it is what earns the unit a place in the roster.
var permanent: bool = false

# Set when an ability used its caster up. Like `permanent`, it outlives
# reset_for_battle: it is what keeps the unit out of next round's roster.
var consumed: bool = false

var dots: Array[Dictionary] = []


static func create(p_data: UnitData, p_team: int) -> UnitInstance:
	var u := UnitInstance.new()
	u.data = p_data
	u.team = p_team
	u.uid = _next_uid
	_next_uid += 1
	u.current_hp = u.stat(StatModifier.Stat.MAX_HP)
	return u


static func reset_uid_counter() -> void:
	_next_uid = 1


func _base(s: StatModifier.Stat) -> float:
	match s:
		StatModifier.Stat.MAX_HP:
			return data.max_hp
		StatModifier.Stat.ATTACK_DAMAGE:
			return data.attack_damage
		StatModifier.Stat.ATTACK_SPEED:
			return data.attack_speed
		StatModifier.Stat.MOVE_TIME:
			return data.move_time
		StatModifier.Stat.ATTACK_RANGE:
			return float(data.attack_range)
		StatModifier.Stat.SIGHT_RANGE:
			return float(data.sight_range)
		StatModifier.Stat.HEAL_POWER:
			return 1.0
		StatModifier.Stat.AURA_POWER:
			return 1.0
		StatModifier.Stat.DAMAGE_TAKEN:
			return 1.0
		StatModifier.Stat.MANA_REGEN:
			return data.mana_per_charge
	return 0.0


func stat(s: StatModifier.Stat) -> float:
	var flat := 0.0
	var pct := 0.0
	for m in modifiers:
		if m.stat != s:
			continue
		if m.mode == StatModifier.Mode.FLAT:
			flat += m.value
		else:
			pct += m.value
	for m in battle_modifiers:
		if m.stat != s:
			continue
		if m.mode == StatModifier.Mode.FLAT:
			flat += m.value
		else:
			pct += m.value
	var v := (_base(s) + flat) * (1.0 + pct)
	if s in StatModifier.INVERTED_STATS:
		return maxf(v, MIN_TIME)
	return maxf(v, 0.0)


func range_band() -> UnitData.RangeBand:
	return UnitData.clamp_band(stat_int(StatModifier.Stat.ATTACK_RANGE))


func range_name() -> String:
	return UnitData.band_name(stat_int(StatModifier.Stat.ATTACK_RANGE))


func damage_taken_multiplier() -> float:
	return maxf(stat(StatModifier.Stat.DAMAGE_TAKEN), 0.0)


func mana_per_charge() -> float:
	return maxf(stat(StatModifier.Stat.MANA_REGEN), 0.0)


func charge_time() -> float:
	return maxf(data.mana_charge_time, MIN_TIME)


func is_invulnerable() -> bool:
	return (state == State.CASTING and data.ability != null
		and data.ability.guards_caster)


func exposure() -> float:
	# Extra damage taken while mid-cast. The Engineer is head-down building its
	# turret and cannot defend itself; this is what that costs.
	if state != State.CASTING or data.ability == null:
		return 1.0
	return 1.0 + maxf(data.ability.exposes_caster, 0.0)


func can_act() -> bool:
	return data.can_attack or data.can_move


func lifesteal() -> float:
	return clampf(stat(StatModifier.Stat.LIFESTEAL), 0.0, 1.0)


func attack_reach() -> int:
	return reach_on(false)


func reach_on(high_ground: bool) -> int:
	# High ground is worth a whole band to anything that shoots. A melee unit
	# gains nothing from standing on a hill.
	var band := stat_int(StatModifier.Stat.ATTACK_RANGE)
	if high_ground and is_ranged():
		band += 1
	return UnitData.band_tiles(band)


func is_ranged() -> bool:
	return data.attack_type != UnitData.AttackType.MELEE


func takes_high_ground() -> bool:
	return is_ranged()


func attack_interval() -> float:
	return maxf(1.0 / maxf(stat(StatModifier.Stat.ATTACK_SPEED), 0.01), MIN_TIME)


func stat_int(s: StatModifier.Stat) -> int:
	return int(round(stat(s)))


func is_hidden() -> bool:
	return stealth_left > 0.0 and is_alive()


func is_alive() -> bool:
	return state != State.DEAD and current_hp > 0.0


func is_committed() -> bool:
	return state == State.MOVING or state == State.ATTACKING or state == State.CASTING


func apply_modifiers(mods: Array[StatModifier]) -> void:
	var hp_before := stat(StatModifier.Stat.MAX_HP)
	for m in mods:
		modifiers.append(m)
	var gained := stat(StatModifier.Stat.MAX_HP) - hp_before
	if gained > 0.0:
		current_hp += gained
	current_hp = minf(current_hp, stat(StatModifier.Stat.MAX_HP))


func take_damage(amount: float) -> float:
	if shield > 0.0:
		var absorbed := minf(shield, amount)
		shield -= absorbed
		amount -= absorbed
	current_hp = maxf(current_hp - amount, 0.0)
	if current_hp <= 0.0:
		state = State.DEAD
		target = null
	return amount


func effective_hp() -> float:
	return current_hp + shield


func gain_mana(amount: float) -> void:
	mana = clampf(mana + amount, 0.0, MANA_MAX)


func mana_full() -> bool:
	return data.ability != null and mana >= MANA_MAX


func spend_mana() -> void:
	mana = 0.0


func add_shield(amount: float, cap: float) -> void:
	shield = minf(maxf(shield, 0.0) + amount, cap)


func add_battle_modifier(m: StatModifier) -> void:
	battle_modifiers.append(m)


func apply_dot(dmg: float, ticks: int, interval: float, source_uid: int) -> void:
	dots.append({
		dmg = dmg, ticks_left = ticks, interval = interval,
		timer = interval, source_uid = source_uid,
	})


func heal(amount: float) -> void:
	if amount <= 0.0 or not is_alive():
		return
	current_hp = minf(current_hp + amount, stat(StatModifier.Stat.MAX_HP))


func heal_to_full() -> void:
	current_hp = stat(StatModifier.Stat.MAX_HP)


func reset_for_battle() -> void:
	state = State.IDLE
	state_timer = 0.0
	target = null
	move_from = cell
	# A unit that banks its charge carries the bar from round to round; that is
	# the whole of its progress, so wiping it here would undo every round of it.
	if not data.keeps_mana:
		mana = 0.0
	has_opened = false
	pending_target_uid = -1
	shield = 0.0
	haste_stacks = 0
	stealth_left = 0.0
	revives = 0
	summons_made = 0
	mana_clock = 0.0
	battle_modifiers.clear()
	dots.clear()
	heal_to_full()


func promote_to(next: UnitData, inherit: Array[StatModifier]) -> void:
	data = next
	modifiers = inherit
	heal_to_full()


func describe() -> String:
	return "%s T%d (team %d) hp %.0f/%.0f @ %s" % [
		data.display_name, data.tier, team,
		current_hp, stat(StatModifier.Stat.MAX_HP), cell,
	]
