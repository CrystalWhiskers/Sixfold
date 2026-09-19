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

## Every timed condition a unit can be under, in one place.
##
## Until now each of these was an ad-hoc field with its own clearing code, which
## was fine while nothing ever asked "what is on this unit?" — and stopped being
## fine the moment something did. A cleanse written against the fields would
## enumerate the two that existed the day it was written and quietly miss every
## status added afterwards, which is the same shape as the bug heal() exists to
## prevent: a rule enforced in N places is a rule with N-1 chances to be
## forgotten.
##
## Adding a status is three adjacent edits in this file — a name here, an arm in
## has_status(), an arm in clear_status() — and everything that walks the list
## (cleanse, the round reset) picks it up for free.
##
## Deliberately NOT in here: burden, exposure, empowerment, isolation and the
## Leech's drain. Those are computed at the moment they are needed rather than
## stored, so there is nothing to clear and nothing to go stale.
enum Status {
	POISON,
	FROZEN,
	STUNNED,
	TAUNT,
	REFLECT,
	STEALTH,
	HASTE,
	NO_RECOVERY,
	DISORIENTED,
}

## `debuff` is whether it is done TO the unit by an enemy; `cleansable` is
## whether a cleanse may lift it. They are separate on purpose. Sudden death is
## unquestionably a debuff and must not be cleansable — it is a rule of the
## clock, not a spell, and a Seraph should not be able to switch it off. A
## Paragon's taunt is self-inflicted, so it is not a debuff at all.
const STATUSES := [
	{id = Status.POISON, name = "Poison", debuff = true, cleansable = true},
	{id = Status.FROZEN, name = "Frozen", debuff = true, cleansable = true},
	{id = Status.STUNNED, name = "Stunned", debuff = true, cleansable = true},
	{id = Status.TAUNT, name = "Taunt", debuff = false, cleansable = false},
	{id = Status.REFLECT, name = "Reflect", debuff = false, cleansable = false},
	{id = Status.STEALTH, name = "Stealth", debuff = false, cleansable = false},
	{id = Status.HASTE, name = "Haste", debuff = false, cleansable = false},
	{id = Status.NO_RECOVERY, name = "Sudden Death", debuff = true,
		cleansable = false},
	{id = Status.DISORIENTED, name = "Disoriented", debuff = true, cleansable = true},
]

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

## Seconds before the whole shield pool fizzles out, or 0 when there is nothing to
## run down.
##
## The clock belongs to the POOL, not to each contribution. It starts when a shield
## arrives on a unit that had none, and a second shield landing inside the window
## is added on without touching it — so a Warden that re-shields at four seconds has
## a bigger pool that still goes at seven, rather than an ever-renewing one. That is
## the whole of the rule and it is the reason there is one timer here rather than a
## list of timed layers: a list would let a unit keep a shield alive indefinitely by
## topping it up, which is what this replaces.
var shield_left: float = 0.0

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

# Set once at the opening bell by CombatSim, never during the battle. Both are
# wiped by reset_for_battle(), so empowerment is re-decided from scratch every
# round against whatever the board looks like then.
var empowered: bool = false

# The Pariah's condition, and like empowerment it is answered once at the bell
# and then left alone. It has to be: the unit is melee, so a live check would
# switch it off the instant it walked up to something, and it is meant to be a
# reward for where you PUT it during prep, not for where the fight drifts.
var isolated: bool = false

# Sudden death, switched on for every unit on the board when the clock reaches
# it. Deliberately NOT folded into is_suppressed(): suppression means "gains
# nothing at all" and also blocks haste stacks and gifted mana, which sudden
# death has no business touching. This one is exactly two things — no healing,
# no shield gained — which is what was asked for and nothing more.
var recovery_denied: bool = false

## Seconds since this unit last swung at anything. Grows while it walks, resets
## the moment it attacks. Only one thing reads it — see IMPATIENT_AFTER in
## CombatSim — but it is real state about the unit, so it lives on the unit.
var dry_spell: float = 0.0

## Seconds before a ranged unit may give ground again.
##
## A retreat costs this unit a swing — see CombatSim._give_ground — so it has to
## be rate-limited or a bow followed by a melee unit steps and swings alternately
## for the whole round at half its damage. Set to one full attack cycle on every
## step back, so the unit always gets a proper shot in between.
var kite_hold: float = 0.0

## Whether this unit has already gone through a gate this round.
##
## Currently redundant, and kept deliberately. CombatSim.GATE_TRANSITS_PER_TEAM is
## one, so a side gets a single transit and no unit can reach a second one anyway —
## but that cap is a number somebody may raise, and the moment it is above one this
## flag is what stops a unit walking back and forth. The pads sit a row in from each
## back rank, so standing on your own pad makes THEIR back rank close and standing on
## theirs makes YOURS close; a unit whose target ends up behind it would commute.
##
## A flag rather than a cooldown because "you committed that body to the flank" is
## the decision the gate is meant to create, and a flag cannot be tuned wrong.
var gate_used: bool = false

## The Martyr's two pieces of state.
##
## `frenzy_left` is seconds of death immunity remaining — the window at zero health
## where the unit is still standing and still swinging. `frenzy_spent` is what makes
## it once per round: without it, every subsequent blow would restart the window and
## the unit would never die at all.
##
## Zero health but not dead is the whole trick, and it is why is_alive() consults this
## rather than only the health bar. Every count, every targeting sweep and the win
## condition read is_alive(), so there is exactly one place that has to agree.
var frenzy_left: float = 0.0
var frenzy_spent: bool = false

## A charge in progress: how many tiles it still has in it, which way it is going, and
## how long until it reaches the next tile.
##
## State on the unit rather than a row in a list on the simulation — unlike the
## Culverin's shells — because a charge IS the unit moving. It occupies tiles as it goes,
## it can be stopped by a wall or a body, and it can be knocked out of it by a stun. A
## shell is a thing in the air with no relationship to its firer once it is away.
var charge_left: int = 0
var charge_step: Vector2i = Vector2i.ZERO
var charge_timer: float = 0.0

## Lost: wandering, and not swinging at anything.
##
## `disorient_immune_left` is the five seconds afterwards during which it cannot be
## disoriented again. Without it two of these units lock a target out of the round
## between them, and the counterplay — kill the Siren — is not available to a unit that
## never gets to act. The immunity is what makes the ability a tempo tool rather than a
## disable.
var disorient_left: float = 0.0
var disorient_immune_left: float = 0.0

## How long the immunity will last once THIS disorientation ends. Carried on the victim
## because the figure belongs to the CASTER's ability, and by the time the clock runs out
## the caster may be dead, may be a different Siren, or may never have been on the board
## the view is looking at. Reading it off the victim's own ability at that point is the
## obvious version and it is wrong: the victim is not the unit with the ability.
var disorient_immune_after: float = 0.0

var taunt_left: float = 0.0
var reflect_left: float = 0.0

# Frozen solid: cannot move, cannot swing, cannot cast, and takes `frozen_amp`
# times the damage while it lasts. The multiplier is baked in when the freeze
# lands rather than read live, for the same reason the Vexer's vulnerability is:
# it is the number the caster had at the moment it cast, so killing the caster
# afterwards does not thaw anything and buffing it does not deepen a freeze that
# is already running.
var frozen_left: float = 0.0
var frozen_amp: float = 1.0

# Stunned: cannot move, cannot swing, cannot cast. Deliberately its OWN state and
# not a short freeze, because a freeze is three things and a stun is one. The
# Stasis's freeze also amplifies incoming damage and cancels everything the
# victim would have done on death, and neither of those belongs to a unit that
# simply ran into something very hard. Folding them together would have handed
# the charger two mechanics it was never given.
var stun_left: float = 0.0

# The Devourer's two states. `ascended` is the transformation, which is one-way
# and lasts the round; `executes_next` is the armed swing, which is spent the
# moment it lands. Both are battle state, so a new round starts it small again.
var ascended: bool = false
var executes_next: bool = false

# Set on a unit raised by an ability that keeps its summons. Survives
# reset_for_battle deliberately: it is what earns the unit a place in the roster.
var permanent: bool = false

# Set when an ability used its caster up. Like `permanent`, it outlives
# reset_for_battle: it is what keeps the unit out of next round's roster.
var consumed: bool = false

# Possession. Three fields and they answer three different questions.
#
# `home_team` and `home_data` are what this unit WAS before anybody took it over:
# the side it belongs to and the tier row it was drawn at. They exist so
# reset_for_battle() can hand it back. Getting this wrong does not produce a
# subtle bug — it permanently transfers a unit out of its owner's roster, because
# _restore_roster() places every unit by its `team`.
#
# `puppeteer_uid` is the Usurper currently inside this unit, or -1. It is what
# stops two Usurpers taking the same host.
#
# `host_uid` is the unit THIS unit is inside, or -1. Only an Usurper ever sets it.
var home_team: int = -1
var home_data: UnitData = null
var puppeteer_uid: int = -1
var host_uid: int = -1

# What the puppeteer LENT this host — the Reins buff's host-only half. Recorded so
# a timed release can take back exactly those modifiers and nothing else: the host
# may also be carrying its own side's empowerment and full-roster bonuses, and
# clearing battle_modifiers wholesale would silently delete those.
var lent_modifiers: Array[StatModifier] = []

# Seconds of grip left, or -1 for a hold that lasts the whole round. Lives on the
# HOST rather than on the puppeteer because the host is the thing being held, and
# because a husk that re-infects has to start a fresh clock on its new victim.
var possess_left: float = -1.0

# The husk. One health, and nothing may change it — no healing, no shield, no
# max-health buff. "1 hp that cannot be changed" is a promise about the number on
# the bar, so it is enforced at the place the number is read rather than at the
# handful of places that might raise it.
var hp_locked: bool = false

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
		StatModifier.Stat.FREEZE_POWER:
			return 1.0
		StatModifier.Stat.FREEZE_AMP:
			return 1.0
		StatModifier.Stat.DAMAGE_TAKEN:
			return 1.0
		StatModifier.Stat.RESIST:
			return data.damage_resist
		StatModifier.Stat.LIFESTEAL:
			return data.lifesteal
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
	# The husk's health is pinned before any modifier is consulted, which is what
	# "cannot be changed" has to mean: a max-health buff, a Militia pick and a
	# forced tier all have to arrive here and be ignored.
	if hp_locked and s == StatModifier.Stat.MAX_HP:
		return 1.0
	var v := (_base(s) + flat) * (1.0 + pct)
	# The Martyr's two multipliers, applied after the modifiers rather than as
	# modifiers: they change every time the health bar moves, and a modifier list that
	# had to be rewritten on every point of damage would be wrong the moment anything
	# read it between the hit and the rewrite.
	if s == StatModifier.Stat.ATTACK_DAMAGE or s == StatModifier.Stat.ATTACK_SPEED:
		v *= rage()
	v *= frenzy_bonus(s)
	if s in StatModifier.INVERTED_STATS:
		return maxf(v, MIN_TIME)
	return maxf(v, 0.0)


func range_band() -> UnitData.RangeBand:
	return UnitData.clamp_band(stat_int(StatModifier.Stat.ATTACK_RANGE))


func range_name() -> String:
	return UnitData.band_name(stat_int(StatModifier.Stat.ATTACK_RANGE))


const MAX_RESIST := 0.90


func resist() -> float:
	# Capped short of 1.0 so nothing can ever become literally unkillable by
	# stacking resistance; the Paragon's taunt is the only thing in the game
	# allowed to take it that far, and only for four seconds.
	var r := stat(StatModifier.Stat.RESIST)
	if is_reflecting() and data.ability != null:
		r += data.ability.reflect_resist
	return clampf(r, 0.0, MAX_RESIST)


func damage_taken_multiplier() -> float:
	return maxf(stat(StatModifier.Stat.DAMAGE_TAKEN), 0.0) * (1.0 - resist())


func mana_per_charge() -> float:
	return maxf(stat(StatModifier.Stat.MANA_REGEN), 0.0)


func charge_time() -> float:
	return maxf(data.mana_charge_time, MIN_TIME)


func is_invulnerable() -> bool:
	return (state == State.CASTING and data.ability != null
		and data.ability.guards_caster)


func is_taunting() -> bool:
	return taunt_left > 0.0


func is_reflecting() -> bool:
	return reflect_left > 0.0


func is_charging() -> bool:
	## Mid-run. A charging unit gets no turn of its own — it is committed, and the
	## simulation's charge tick is what moves it.
	return charge_left > 0


func stop_charging() -> void:
	charge_left = 0
	charge_step = Vector2i.ZERO
	charge_timer = 0.0


func is_disoriented() -> bool:
	return disorient_left > 0.0


func is_disorient_immune() -> bool:
	return disorient_immune_left > 0.0


func is_frozen() -> bool:
	return frozen_left > 0.0


func is_stunned() -> bool:
	return stun_left > 0.0


func is_held() -> bool:
	## Frozen or stunned — the two states that stop a unit acting outright. One
	## function so the three gates below cannot end up disagreeing about which
	## conditions count, which is exactly what happened the first time a freeze
	## was added and can_attack_now() was missed.
	return is_frozen() or is_stunned()


func frozen_damage_taken() -> float:
	return maxf(frozen_amp, 1.0) if is_frozen() else 1.0


func can_move_now() -> bool:
	# Holding still is the price of the taunt: it plants itself, and it cannot
	# swing while it is doing it either. Being frozen is the same shape and none
	# of the payoff.
	return data.can_move and not is_taunting() and not is_held()


func can_attack_now() -> bool:
	# Disorientation is deliberately NOT part of is_held(). Held means frozen or stunned:
	# rooted to the spot, doing nothing. A disoriented unit is the opposite shape — it is
	# very much moving, it just has no idea where, and it does not swing at anything on
	# the way. Folding it into is_held() would plant it, which is a different ability.
	return (data.can_attack and not is_taunting() and not is_held()
		and not is_disoriented())


func taunt_damage_taken() -> float:
	if not is_taunting() or data.ability == null:
		return 1.0
	return maxf(data.ability.taunt_damage_taken, 0.0)


func missing_fraction() -> float:
	## How much of its health bar is gone, 0.0 at full and 1.0 at empty.
	##
	## Deliberately NOT using stat() on anything this feeds, or the rage multiplier
	## below would recurse through its own maximum.
	var full := stat(StatModifier.Stat.MAX_HP)
	if full <= 0.0:
		return 0.0
	return clampf(1.0 - current_hp / full, 0.0, 1.0)


func rage() -> float:
	## The Martyr's scaling: harder and faster the worse it is doing.
	##
	## Linear in missing health rather than stepped, so there is no threshold to play
	## around — every point of damage it takes is worth something, which is what makes
	## standing it in front of an Archer a real decision.
	##
	## Applied to attack damage and attack speed only. Applying it to the health bar it
	## is computed FROM would be a loop, and applying it to movement would make a
	## wounded Martyr outrun the line it is supposed to be part of.
	if data == null or data.ability == null:
		return 1.0
	var ab := data.ability
	if ab.kind != AbilityData.Kind.FRENZY:
		return 1.0
	return 1.0 + maxf(ab.rage_per_missing, 0.0) * missing_fraction()


func frenzy_bonus(s: StatModifier.Stat) -> float:
	## The extra on top while the window is open. Separate from rage() because these
	## arrive all at once at zero health rather than climbing with the bar, and because
	## this one DOES touch movement — the last charge is meant to cross ground.
	if not is_frenzied() or data == null or data.ability == null:
		return 1.0
	var ab := data.ability
	match s:
		StatModifier.Stat.ATTACK_DAMAGE:
			return 1.0 + maxf(ab.frenzy_damage, 0.0)
		StatModifier.Stat.ATTACK_SPEED:
			return 1.0 + maxf(ab.frenzy_attack_speed, 0.0)
		StatModifier.Stat.MOVE_TIME:
			# Seconds per tile, so FASTER is a smaller number. Divided rather than
			# multiplied for the same reason BuffData._signed exists.
			return 1.0 / (1.0 + maxf(ab.frenzy_move, 0.0))
	return 1.0


func pierce_now() -> int:
	## How many units one swing reaches. Its ordinary pierce, except inside the window
	## where the dying blow cuts through the rank in front of it.
	var base := maxi(data.pierce_targets, 1)
	if not is_frenzied() or data.ability == null:
		return base
	return maxi(base, maxi(data.ability.frenzy_pierce, 1))


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
	# Zero health is normally death. A Martyr inside its window is the one exception,
	# and it is checked HERE rather than at the dozen places that ask, because
	# "standing" has to mean the same thing to the targeting, the counts and the win
	# condition or the board and the scoreboard disagree.
	return state != State.DEAD and (current_hp > 0.0 or frenzy_left > 0.0)


func is_frenzied() -> bool:
	return frenzy_left > 0.0


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
	# Zero health means dead, EXCEPT inside a Martyr's window. Without that second
	# clause the very next hit after the window opened would set DEAD again, and a
	# DEAD unit gets no turn in step() and fails is_alive() — the unit would still
	# be on the board, still be a target, and do nothing at all until its clock ran
	# out. The window is the one state where the health bar is not the authority.
	if current_hp <= 0.0 and frenzy_left <= 0.0:
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


func add_shield(amount: float, cap: float, seconds := 0.0) -> void:
	# Same reasoning as heal(). Note this stops shields being GAINED and does not
	# strip the ones already there: a Warden that opened with its bulwark keeps it
	# and simply cannot top it up.
	#
	# THE one place a shield is gained. Every source goes through here — the
	# Warden's bulwark, the Colossus hardening, the Aegis Wall buff — so the
	# duration cannot be attached at three sites and forgotten at a fourth.
	if is_suppressed() or recovery_denied or hp_locked:
		return
	var had := shield > 0.0
	shield = minf(maxf(shield, 0.0) + amount, cap)
	if shield <= 0.0 or seconds <= 0.0:
		return
	if not had:
		# A fresh pool on a bare unit starts the clock. One that was already standing
		# keeps the clock it had: topping up must not renew it.
		shield_left = seconds


func tick_shield(delta: float) -> bool:
	## Runs the pool's clock down. Returns true when it just fizzled, so the caller
	## can tell the view the bar has gone.
	if shield_left <= 0.0:
		return false
	if shield <= 0.0:
		# Absorbed to nothing before the clock ran out. The clock goes with it, so
		# the next shield this unit gains starts a fresh one.
		shield_left = 0.0
		return false
	shield_left -= delta
	if shield_left > 0.0:
		return false
	shield_left = 0.0
	shield = 0.0
	return true


func add_battle_modifier(m: StatModifier) -> void:
	battle_modifiers.append(m)


func apply_dot(dmg: float, ticks: int, interval: float, source_uid: int,
		vuln := 0.0, hp_share := 0.0, falloff := 1.0, suppress := false) -> void:
	# The vulnerability rides on the dot entry rather than being a separate timed
	# effect, so its lifetime IS the poison's lifetime with nothing to expire, no
	# cleanup at the round boundary, and correct stacking for free when two
	# Vexers poison the same target.
	dots.append({
		dmg = dmg, ticks_left = ticks, interval = interval,
		timer = interval, source_uid = source_uid, vuln = maxf(vuln, 0.0),
		hp_share = maxf(hp_share, 0.0), falloff = clampf(falloff, 0.0, 1.0),
		suppress = suppress,
	})


func vulnerability() -> float:
	# Additive across poisons, applied as one multiplier. Two tier 3 Vexers at
	# 5%/tier make you take 30% more, not 32.25% more — additive keeps a second
	# Vexer worth exactly as much as the first, which is what "stacks" should
	# mean for a number a player is asked to reason about.
	var total := 0.0
	for d in dots:
		total += float(d.get("vuln", 0.0))
	return 1.0 + total


func is_suppressed() -> bool:
	# Any poison that suppresses is enough; they do not need to agree. Like the
	# vulnerability, this rides on the dot entries, so it ends exactly when the
	# last suppressing poison does and there is nothing to expire or clean up.
	for d in dots:
		if bool(d.get("suppress", false)):
			return true
	return false


func heal(amount: float) -> void:
	# The gate lives HERE rather than at each of the six call sites — regen, the
	# Seraph, the Engineer's repair, lifesteal — because "cannot be healed" has to
	# mean all of them, and a rule enforced in six places is a rule with five
	# chances to be forgotten when a seventh healer is written.
	if amount <= 0.0 or not is_alive() or is_suppressed() or recovery_denied:
		return
	# A husk stays on one health for as long as it lives. Healing it is the most
	# obvious way to break that promise, so it is refused here as well as being
	# impossible through max health.
	if hp_locked:
		return
	current_hp = minf(current_hp + amount, stat(StatModifier.Stat.MAX_HP))


func heal_to_full() -> void:
	current_hp = stat(StatModifier.Stat.MAX_HP)


func has_status(s: Status) -> bool:
	match s:
		Status.POISON:
			return not dots.is_empty()
		Status.FROZEN:
			return frozen_left > 0.0
		Status.STUNNED:
			return stun_left > 0.0
		Status.TAUNT:
			return taunt_left > 0.0
		Status.REFLECT:
			return reflect_left > 0.0
		Status.STEALTH:
			return stealth_left > 0.0
		Status.HASTE:
			return haste_stacks > 0
		Status.NO_RECOVERY:
			return recovery_denied
		Status.DISORIENTED:
			return disorient_left > 0.0
	return false


func clear_status(s: Status) -> void:
	match s:
		Status.POISON:
			# The whole entry goes, which takes the remaining ticks, the
			# vulnerability and the suppression with it — those three ride on the
			# dot rather than living separately, so there is nothing else to undo.
			dots.clear()
		Status.FROZEN:
			frozen_left = 0.0
			frozen_amp = 1.0
		Status.STUNNED:
			stun_left = 0.0
		Status.TAUNT:
			taunt_left = 0.0
		Status.REFLECT:
			reflect_left = 0.0
		Status.STEALTH:
			stealth_left = 0.0
		Status.HASTE:
			# The stacks go; the modifiers they put on the unit are cleared with
			# the rest of the battle modifiers at the round boundary, not here.
			haste_stacks = 0
		Status.NO_RECOVERY:
			recovery_denied = false
		Status.DISORIENTED:
			# The immunity is deliberately NOT granted here. A cleanse is an ally
			# pulling you together, not you shaking it off yourself — handing out the
			# five seconds too would make one Seraph the answer to the whole unit.
			disorient_left = 0.0


static func status_name(s: Status) -> String:
	for row in STATUSES:
		if row.id == s:
			return row.name
	return "?"


func cleanse() -> Array[String]:
	## Lifts every cleansable debuff currently on this unit and names what went.
	## Walks the table rather than naming fields, so a status added later is
	## cleansed without anyone remembering to come back here.
	var removed: Array[String] = []
	for row in STATUSES:
		if not row.debuff or not row.cleansable:
			continue
		if not has_status(row.id):
			continue
		clear_status(row.id)
		removed.append(row.name)
	return removed


func is_riding() -> bool:
	## Inside a host: off the board entirely, taking no turns and reachable by
	## nothing. The only way out is the host dying.
	return host_uid >= 0


func is_possessed() -> bool:
	## Being ridden. Its team says the puppeteer's side, and every count, every
	## targeting sweep and the win condition itself read `team` live, so nothing
	## else has to be told.
	return puppeteer_uid >= 0


func is_husk() -> bool:
	## What is left of an Usurper once its host has been killed under it: one
	## health that nothing can raise, and slow. `hp_locked` IS the husk — there is
	## no second flag to fall out of step with it.
	return hp_locked


func release_possession() -> void:
	## Hands a unit back to whoever owned it, and clears every trace of having been
	## held. Called at the round boundary for every unit, so a possession can never
	## outlive the round it happened in — and mid-round by CombatSim when a timed
	## grip runs out (see AbilityData.possess_seconds).
	##
	## `home_data` is restored as well as the team: a higher-tier Usurper forces
	## its host up to its own tier, and the owner does not get to keep that.
	##
	## The lent modifiers are removed one by one rather than by clearing
	## battle_modifiers, because a host may also be carrying its own side's
	## empowerment and full-roster bonuses and those are not the thief's to take.
	if home_team >= 0:
		team = home_team
	if home_data != null:
		data = home_data
	for m in lent_modifiers:
		battle_modifiers.erase(m)
	lent_modifiers.clear()
	# The maximum may have just fallen — a handed-back host loses both the forced
	# tier and the thief's health buff — so the bar has to come down with it.
	current_hp = minf(current_hp, stat(StatModifier.Stat.MAX_HP))
	home_team = -1
	home_data = null
	puppeteer_uid = -1
	host_uid = -1
	possess_left = -1.0
	hp_locked = false


func reset_for_battle() -> void:
	# FIRST, before anything reads `team` — _restore_roster() places every unit by
	# its team, so a unit still flipped at this point is a unit permanently stolen
	# from the other side's roster.
	release_possession()
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
	empowered = false
	isolated = false
	dry_spell = 0.0
	kite_hold = 0.0
	gate_used = false
	frenzy_left = 0.0
	frenzy_spent = false
	# The immunity goes with the round too. It is cleared by the STATUSES walk below for
	# the disorientation itself, but the immunity is not a status — it is the absence of
	# one — so it needs its own line here.
	disorient_immune_left = 0.0
	disorient_immune_after = 0.0
	# A charge cannot outlive the round it was started in. Without this a Breaker that
	# was still running when the bell went would resume mid-lane on the next board, from
	# a tile it is no longer standing on.
	stop_charging()
	# Every status goes at the round boundary, cleansable or not — sudden death
	# belongs to the round that ran out of clock, and a freeze does not carry over
	# into a fight that has not started. Walked from the table rather than listed
	# by hand, so this cannot fall out of step with what a status IS.
	for row in STATUSES:
		clear_status(row.id)
	ascended = false
	executes_next = false
	shield = 0.0
	shield_left = 0.0
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
