## Generates every .tres in res://data/ from the tables below.
##
##   godot --headless --script res://tools/generate_data.gd
##
## Numbers are yours to own — this exists so you tune a table in one place and
## regenerate, rather than clicking through 15 inspector panels. Once you're happy
## editing .tres files directly in the editor, you can stop running this.
##
## WARNING: this overwrites everything in res://data/. Anything you tweaked by
## hand in the inspector is lost. Change the tables here instead, or stop using it.
extends SceneTree

const UNITS_DIR := "res://data/units"
const ABILITY_DIR := "res://data/abilities"
const LOADOUT_DIR := "res://data/loadouts"
const BUFF_DIR := "res://data/buffs"

const TIERS := 7
## Every tier doubles health and damage. Tier 7 is 2^6 = 64x a tier 1.
##
## Cooldown, move_time and range deliberately do NOT scale. Two of those are
## lower-is-better, so doubling them would make a merged unit worse; halving them
## instead would stack with the damage doubling and put tier 7 at 4096x the DPS
## of a tier 1. Range doubling would give a tier-7 Archer reach of 256 tiles on a
## board 11 deep. Power scales, tempo and reach do not.
const HP_SCALE := 2.0
const DMG_SCALE := 2.0

## Every unit has one mana ability. The bar is 100 for all of them; mana_per_attack
## is the only thing that differs, so a rate of 25 casts every 4th attack.
const UNIT_TABLE := [
	{
		id = &"warden", name = "Warden", hp = 180.0, dmg = 8.0, cd = 1.3,
		move = 0.60, range = 1, sight = 3, type = "MELEE",
		accent = Color(0.38, 0.47, 0.60),
		ability = &"bulwark_shield", mana = 20.0, opens = true,
		note = "Opens with its shield already up, then rebuilds it slowly.",
	},
	{
		id = &"lancer", name = "Lancer", hp = 95.0, dmg = 16.0, cd = 0.9,
		move = 0.36, range = 1, sight = 4, type = "MELEE",
		accent = Color(0.72, 0.35, 0.28),
		ability = &"impale", mana = 25.0, pierce = 2,
		note = "Every swing already cuts through two. The ability makes it three, harder.",
	},
	{
		id = &"archer", name = "Archer", hp = 55.0, dmg = 19.0, cd = 0.95,
		move = 0.50, range = 4, sight = 5, type = "RANGED",
		accent = Color(0.55, 0.62, 0.32),
		ability = &"quickdraw", mana = 25.0,
		note = "Charges fastest of anyone and never stops speeding up. Fold if reached.",
	},
	{
		id = &"vexer", name = "Vexer", hp = 85.0, dmg = 6.0, cd = 0.42,
		move = 0.45, range = 2, sight = 4, type = "RANGED",
		accent = Color(0.45, 0.40, 0.66),
		ability = &"blight", mana = 12.0,
		note = "Weak hits, but the fastest attack rate means the bar fills constantly.",
	},
	{
		id = &"pyre", name = "Pyre", hp = 90.0, dmg = 7.0, cd = 1.4,
		move = 0.55, range = 3, sight = 4, type = "SPELL",
		accent = Color(0.78, 0.55, 0.22),
		ability = &"cinder_lance", mana = 34.0,
		note = "Ordinary attacks are feeble. Everything rides on landing the burst.",
	},
]

## kind decides which fields matter — see AbilityData.
const ABILITY_TABLE := [
	{
		id = &"bulwark_shield", name = "Bulwark", kind = "SHIELD", cast_time = 0.3,
		desc = "Raises a shield that soaks damage before health and cannot be healed.",
		shield_amount = 70.0, shield_cap = 70.0,
	},
	{
		id = &"impale", name = "Impale", kind = "PIERCE", cast_time = 0.5,
		desc = "A driving thrust through up to three enemies.",
		pierce_targets = 3, pierce_damage_mult = 2.1,
	},
	{
		id = &"quickdraw", name = "Quickdraw", kind = "HASTE", cast_time = 0.35,
		desc = "Permanently quickens the draw. Stacks all battle.",
		haste_percent = 0.16, haste_max_stacks = 6,
	},
	{
		id = &"blight", name = "Blight", kind = "DOT", cast_time = 0.4,
		desc = "Poisons one enemy. Keeps working while the Vexer shoots someone else.",
		dot_damage = 11.0, dot_ticks = 6, dot_interval = 0.5,
	},
	{
		id = &"cinder_lance", name = "Cinder Lance", kind = "FOCUS_BURST", cast_time = 0.7,
		desc = "A lance of fire: heavy on the target, scorching everything beside it.",
		burst_damage = 78.0, splash_damage = 16.0, splash_radius = 1,
	},
]

## Between-rounds buffs. Scope SINGLE_UNIT lets the player pick who gets it.
const BUFF_TABLE = [
	{id = &"sharpen", name = "Sharpen", scope = "SINGLE_UNIT", weight = 1.0,
		mods = [["ATTACK_DAMAGE", "PERCENT", 0.35]]},
	{id = &"whetstone", name = "Whetstone", scope = "ALL_UNITS", weight = 1.0,
		mods = [["ATTACK_DAMAGE", "PERCENT", 0.12]]},
	{id = &"bulwark", name = "Bulwark", scope = "SINGLE_UNIT", weight = 1.0,
		mods = [["MAX_HP", "PERCENT", 0.45]]},
	{id = &"rations", name = "Rations", scope = "ALL_UNITS", weight = 1.0,
		mods = [["MAX_HP", "PERCENT", 0.15]]},
	{id = &"quickstep", name = "Quickstep", scope = "SINGLE_UNIT", weight = 1.0,
		mods = [["MOVE_TIME", "PERCENT", -0.30]]},
	{id = &"forced_march", name = "Forced March", scope = "ALL_UNITS", weight = 0.8,
		mods = [["MOVE_TIME", "PERCENT", -0.12]]},
	{id = &"frenzy", name = "Frenzy", scope = "SINGLE_UNIT", weight = 0.9,
		mods = [["ATTACK_COOLDOWN", "PERCENT", -0.28]]},
	{id = &"longshot", name = "Longshot", scope = "SINGLE_UNIT", weight = 0.5,
		mods = [["ATTACK_RANGE", "FLAT", 1.0]]},
	{id = &"glass_edge", name = "Glass Edge", scope = "ALL_UNITS", weight = 0.6,
		mods = [["ATTACK_DAMAGE", "PERCENT", 0.30], ["MAX_HP", "PERCENT", -0.15]]},
]


func _initialize() -> void:
	print("Generating data for Six by Eleven...")
	var abilities := _make_abilities()
	var loadout := _make_units(abilities)
	_make_buffs()
	print("\nDone. %d units, %d abilities, %d buffs." % [
		UNIT_TABLE.size() * TIERS, ABILITY_TABLE.size(), BUFF_TABLE.size()])
	if not loadout.is_valid():
		push_error("Generated loadout is invalid.")
	quit()


func _save(res: Resource, path: String) -> void:
	var err := ResourceSaver.save(res, path)
	if err != OK:
		push_error("Failed to save %s (error %d)" % [path, err])
	else:
		print("  ", path)


func _make_abilities() -> Dictionary:
	var out := {}
	for row in ABILITY_TABLE:
		var a := AbilityData.new()
		a.id = row.id
		a.display_name = row.name
		a.description = row.desc
		a.kind = AbilityData.Kind[row.kind]
		a.cast_time = row.cast_time
		for key in ["haste_percent", "haste_max_stacks", "shield_amount", "shield_cap",
				"dot_damage", "dot_ticks", "dot_interval", "burst_damage",
				"splash_damage", "splash_radius", "pierce_targets", "pierce_damage_mult"]:
			if row.has(key):
				a.set(key, row[key])
		_save(a, "%s/%s.tres" % [ABILITY_DIR, row.id])
		out[row.id] = a
	return out


func _make_units(abilities: Dictionary) -> LoadoutData:
	var loadout := LoadoutData.new()
	loadout.id = &"starter"
	loadout.display_name = "Starter Five"
	var tier_ones: Array[UnitData] = []

	for row in UNIT_TABLE:
		# Build top tier first: next_tier must already have a resource_path,
		# or the reference gets embedded instead of linked.
		var built: Array[UnitData] = []
		for t in range(TIERS, 0, -1):
			var u := UnitData.new()
			var mult_hp: float = pow(HP_SCALE, t - 1)
			var mult_dmg: float = pow(DMG_SCALE, t - 1)
			u.id = row.id
			u.display_name = row.name if t == 1 else "%s %s" % [row.name, _numeral(t)]
			u.tier = t
			u.max_hp = snappedf(row.hp * mult_hp, 1.0)
			u.attack_damage = snappedf(row.dmg * mult_dmg, 0.5)
			u.attack_cooldown = row.cd
			u.move_time = row.move
			u.attack_range = row.range
			u.sight_range = row.sight
			u.attack_type = UnitData.AttackType[row.type]
			u.accent = row.accent
			u.mana_per_attack = row.get("mana", 25.0)
			u.casts_at_battle_start = row.get("opens", false)
			u.pierce_targets = row.get("pierce", 1)
			if row.has("ability"):
				u.ability = abilities[row.ability]
			u.next_tier = built[0] if not built.is_empty() else null
			_save(u, "%s/%s_t%d.tres" % [UNITS_DIR, row.id, t])
			built.push_front(u)
		tier_ones.append(built[0])
		if built[0].chain_length() != TIERS:
			push_error("Merge chain for %s is %d long, expected %d" % [
				row.id, built[0].chain_length(), TIERS])

	loadout.units = tier_ones
	_save(loadout, "%s/starter.tres" % LOADOUT_DIR)
	return loadout


func _make_buffs() -> void:
	for row in BUFF_TABLE:
		var b := BuffData.new()
		b.id = row.id
		b.display_name = row.name
		b.scope = BuffData.Scope[row.scope]
		b.weight = row.weight
		var mods: Array[StatModifier] = []
		for m in row.mods:
			mods.append(StatModifier.make(
				StatModifier.Stat[m[0]], StatModifier.Mode[m[1]], m[2]))
		b.modifiers = mods
		_save(b, "%s/%s.tres" % [BUFF_DIR, row.id])


func _numeral(t: int) -> String:
	return ["", "I", "II", "III", "IV", "V", "VI", "VII", "VIII"][clampi(t, 0, 8)]
