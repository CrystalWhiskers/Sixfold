class_name BossDifficulty
extends RefCounted

## Boss defence difficulty: five steps from Easy to Nightmare, Normal being the boss
## exactly as data/boss/arbiter.tres describes her. Each step is applied to a COPY of
## that data when the mode opens, so the file on disk never changes.
##
## What a step turns:
##   hp, atk      her health and attack
##   summons      the power of everything she summons
##   income       every Supply source: base income, income upgrades, passive growth
##                and the Supply paid for damage
##   attack_mode  her map-wide moves stop taking a share of max health and hit off her
##                attack instead (full attack, which grows all fight), and her ordinary
##                moves hit with her whole attack rather than 75% of it

const NAMES := ["Easy", "Normal", "Hard", "Brutal", "Nightmare"]
const NORMAL := 1

const LEVELS := [
	{hp = 0.6, atk = 0.8, summons = 0.75, income = 1.25, attack_mode = false},
	{hp = 1.0, atk = 1.0, summons = 1.0, income = 1.0, attack_mode = false},
	{hp = 1.3, atk = 1.2, summons = 1.25, income = 0.85, attack_mode = false},
	{hp = 1.6, atk = 1.4, summons = 1.5, income = 0.7, attack_mode = true},
	{hp = 2.0, atk = 1.6, summons = 2.0, income = 0.55, attack_mode = true},
]


static func clamp_level(level: int) -> int:
	return clampi(level, 0, LEVELS.size() - 1)


static func name_of(level: int) -> String:
	return NAMES[clamp_level(level)]


static func describe(level: int) -> String:
	## One line for the menu: what this step does compared with Normal.
	var row: Dictionary = LEVELS[clamp_level(level)]
	if clamp_level(level) == NORMAL:
		return "The boss as designed."
	var parts: PackedStringArray = []
	parts.append("Boss health %s" % _pct(row.hp))
	parts.append("attack %s" % _pct(row.atk))
	parts.append("summons %s" % _pct(row.summons))
	parts.append("income %s" % _pct(row.income))
	var line := ", ".join(parts) + "."
	if row.attack_mode:
		line += " Her map-wide attacks hit off her attack instead of max health, and every move hits with her full attack."
	return line


static func _pct(mult: float) -> String:
	var p := roundi((mult - 1.0) * 100.0)
	return "%+d%%" % p


static func apply(base: BossData, level: int) -> BossData:
	## A copy of `base` at this difficulty. Normal returns `base` itself.
	level = clamp_level(level)
	if level == NORMAL or base == null:
		return base
	var row: Dictionary = LEVELS[level]
	var d: BossData = base.duplicate(true)
	d.max_hp = base.max_hp * float(row.hp)
	# Her single-hit cap stays the same number of points: it is a share of her health,
	# so the share moves the other way.
	if d.max_hit_percent > 0.0:
		d.max_hit_percent = base.max_hit_percent / float(row.hp)
	d.posture_damage = base.posture_damage * float(row.hp)
	d.attack_damage = base.attack_damage * float(row.atk)
	d.summon_power_mult = base.summon_power_mult * float(row.summons)
	var inc := float(row.income)
	d.base_income = base.base_income * inc
	d.income_step = base.income_step * inc
	d.passive_income = base.passive_income * inc
	d.damage_income = base.damage_income * inc
	d.summon_damage_income = base.summon_damage_income * inc
	if row.attack_mode:
		d.attack_mode = true
		d.small_move_share = 1.0
	return d
