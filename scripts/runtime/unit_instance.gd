## One living unit. Points at a shared UnitData for its base numbers and owns
## everything that changes: HP, buffs, tile, combat state.
##
## This is the template/instance split. UnitData is read-only; everything mutable
## is here. Buffs live on the instance and persist across rounds for the whole match.
class_name UnitInstance
extends RefCounted

enum State {
	IDLE,       ## Free to decide. The only state that can start an action.
	MOVING,     ## Committed to a tile step. CANNOT attack. This is the exposure window.
	ATTACKING,  ## Swung, now recovering for attack_cooldown. Also cannot move.
	CASTING,    ## Winding up an ability. Cannot attack or move.
	DEAD,
}

## Cooldown-like stats can never reach zero, or the sim would act infinitely fast.
const MIN_TIME := 0.05

## One bar length for every unit. Only the gain rate differs, per UnitData.
const MANA_MAX := 100.0

static var _next_uid: int = 1

var data: UnitData = null           ## Shared. Never written to.
var team: int = 0
## Off-board sentinel, NOT (0,0). A unit sitting on the bench must not compare
## equal to a real tile, or removing it would erase whoever stands on (0,0).
var cell: Vector2i = Vector2i(-1, -1)
var current_hp: float = 0.0
var modifiers: Array[StatModifier] = []  ## Buffs. Persist across rounds.
var uid: int = 0                    ## Stable ordering key. Determinism depends on it.

# --- battle-only, cleared by reset_for_battle() ---
var state: State = State.IDLE
var state_timer: float = 0.0
var target: UnitInstance = null
var move_from: Vector2i = Vector2i(-1, -1)  ## For the view to interpolate from.
var mana: float = 0.0
var has_opened: bool = false        ## Consumed the free battle-start cast.
var pending_target_uid: int = -1    ## Who the in-progress cast is aimed at.

## Temporary hit points. Absorbed before real HP and NEVER healed — heal_to_full()
## deliberately leaves this alone. That's what makes Warden's shield a race
## against incoming damage rather than a bigger health pool.
var shield: float = 0.0

## Stat changes that last only for this battle: Archer's haste stacks live here.
## They must stay separate from `modifiers`, which is the persistent buff list —
## putting haste there would carry it into every later round of the match.
var battle_modifiers: Array[StatModifier] = []
var haste_stacks: int = 0

## Active damage-over-time effects: {dmg, ticks_left, interval, timer, source_uid}
var dots: Array[Dictionary] = []


static func create(p_data: UnitData, p_team: int) -> UnitInstance:
	var u := UnitInstance.new()
	u.data = p_data
	u.team = p_team
	u.uid = _next_uid
	_next_uid += 1
	u.current_hp = u.stat(StatModifier.Stat.MAX_HP)
	return u


## Only for tests that need reproducible uids across runs.
static func reset_uid_counter() -> void:
	_next_uid = 1


func _base(s: StatModifier.Stat) -> float:
	match s:
		StatModifier.Stat.MAX_HP:
			return data.max_hp
		StatModifier.Stat.ATTACK_DAMAGE:
			return data.attack_damage
		StatModifier.Stat.ATTACK_COOLDOWN:
			return data.attack_cooldown
		StatModifier.Stat.MOVE_TIME:
			return data.move_time
		StatModifier.Stat.ATTACK_RANGE:
			return float(data.attack_range)
		StatModifier.Stat.SIGHT_RANGE:
			return float(data.sight_range)
	return 0.0


## Base + flat modifiers, then percentages. Computed on demand so a buff applied
## mid-match is immediately live everywhere without a refresh step.
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


func stat_int(s: StatModifier.Stat) -> int:
	return int(round(stat(s)))


func is_alive() -> bool:
	return state != State.DEAD and current_hp > 0.0


## True whenever the unit is locked into something and cannot respond.
## A ranged attacker killing a walker depends on this being true during MOVING.
func is_committed() -> bool:
	return state == State.MOVING or state == State.ATTACKING or state == State.CASTING


func apply_modifiers(mods: Array[StatModifier]) -> void:
	var hp_before := stat(StatModifier.Stat.MAX_HP)
	for m in mods:
		modifiers.append(m)
	# Raising max HP heals by the same amount, so a +HP buff isn't a downgrade
	# in effective health percentage.
	var gained := stat(StatModifier.Stat.MAX_HP) - hp_before
	if gained > 0.0:
		current_hp += gained
	current_hp = minf(current_hp, stat(StatModifier.Stat.MAX_HP))


## Shield soaks first, then real health. Returns how much reached the health bar,
## so the view can show the two differently if you ever want that.
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


## Total effective health, shield included. Used to settle a timed-out battle.
func effective_hp() -> float:
	return current_hp + shield


func gain_mana(amount: float) -> void:
	mana = clampf(mana + amount, 0.0, MANA_MAX)


func mana_full() -> bool:
	return data.ability != null and mana >= MANA_MAX


func spend_mana() -> void:
	mana = 0.0


func add_shield(amount: float, cap: float) -> void:
	# Tops back up rather than stacking past the cap: a Warden left alone would
	# otherwise become effectively unkillable over a long fight.
	shield = minf(maxf(shield, 0.0) + amount, cap)


func add_battle_modifier(m: StatModifier) -> void:
	battle_modifiers.append(m)


func apply_dot(dmg: float, ticks: int, interval: float, source_uid: int) -> void:
	dots.append({
		dmg = dmg, ticks_left = ticks, interval = interval,
		timer = interval, source_uid = source_uid,
	})


func heal_to_full() -> void:
	current_hp = stat(StatModifier.Stat.MAX_HP)


func reset_for_battle() -> void:
	state = State.IDLE
	state_timer = 0.0
	target = null
	move_from = cell
	mana = 0.0
	has_opened = false
	pending_target_uid = -1
	shield = 0.0
	haste_stacks = 0
	battle_modifiers.clear()
	dots.clear()
	heal_to_full()


## Merging keeps the higher-tier stat block. Buff inheritance is a real balance
## decision — see MERGE_INHERITS_BUFFS in BoardModel.
func promote_to(next: UnitData, inherit: Array[StatModifier]) -> void:
	data = next
	modifiers = inherit
	heal_to_full()


func describe() -> String:
	return "%s T%d (team %d) hp %.0f/%.0f @ %s" % [
		data.display_name, data.tier, team,
		current_hp, stat(StatModifier.Stat.MAX_HP), cell,
	]
