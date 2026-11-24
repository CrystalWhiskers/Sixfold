class_name Barracks
extends RefCounted

## Boss defence's merge area and its economy, kept off the board.
##
## Three SECTIONS, one per zone (Left, Middle, Right), each a small grid of slots.
## Whatever stands in a section is that zone's army template: every wave sends a
## fresh copy of it onto the field. Editing a section — recruiting, merging, moving —
## therefore takes effect from the next wave.
##
## Supply ticks up in real time. It buys recruits (a random tier-1 draw from the
## player's loadout, a little dearer each time), income (more Supply per second,
## dearer each time) and UNIT UPGRADES: one unit type at a time, Lv1 to Lv5, each
## level growing that unit's own ability in its own terms (see BossUpgrades) plus a
## small bump to health and attack. An upgrade reaches every copy of that unit —
## the ones already fighting and every wave after.

const SECTIONS := 3

var data: BossData = null
var sections: Array = []        ## [section] -> Array of UnitData or null, one per slot
var supply := 0.0
var income := 0.0
var income_level := 0
var recruits := 0
var spent := 0.0
## The player's unit types, one per loadout entry (no repeats), in loadout order.
var types: Array[UnitData] = []
## unit id -> upgrade level 0..5.
var level: Dictionary = {}
## Goes up on every upgrade, so whoever holds units of an upgraded type can notice.
var revision := 0

var _loadout: LoadoutData = null
var _rng := RandomNumberGenerator.new()
## Only used for its merge lottery, so a merge here rolls exactly the way one on
## the prep board does.
var _merger := BoardModel.new()
var _field_cache: Dictionary = {}


func setup(p_data: BossData, loadout: LoadoutData, seed_value: int) -> void:
	data = p_data
	_loadout = loadout
	_rng.seed = seed_value
	_merger.configure_merges(loadout.units, seed_value + 4242)
	sections.clear()
	for s in SECTIONS:
		var slots: Array = []
		slots.resize(slot_count())
		sections.append(slots)
	supply = data.start_supply
	income = data.base_income
	income_level = 0
	clock = 0.0
	passive_gained = 0.0
	recruits = 0
	spent = 0.0
	types.clear()
	level.clear()
	_field_cache.clear()
	revision = 0
	for d in loadout.units:
		if d != null and not level.has(d.id):
			types.append(d)
			level[d.id] = 0
	# The opening draws, dealt round the sections so every zone starts with
	# somebody. Free: they do not raise the recruit price.
	for i in data.start_draws:
		_place(i % SECTIONS, _loadout.draw_one(_rng))


func slot_count() -> int:
	return data.section_cols * data.section_rows


## Fight time the Barracks has seen, and the Supply per second it has gained on its
## own (BossData.passive_income), separate from what was bought.
var clock := 0.0
var passive_gained := 0.0


func tick(seconds: float) -> void:
	seconds = maxf(seconds, 0.0)
	supply += income * seconds
	clock += seconds
	if data.passive_income > 0.0 and data.passive_income_every > 0.0:
		while clock >= data.passive_income_every * (passive_gained / data.passive_income + 1.0) - 0.0001:
			income += data.passive_income
			passive_gained += data.passive_income


func next_passive_in() -> float:
	## Seconds until income next rises on its own, or INF if it never does.
	if data.passive_income <= 0.0 or data.passive_income_every <= 0.0:
		return INF
	return data.passive_income_every * (passive_gained / data.passive_income + 1.0) - clock


# --- Prices -------------------------------------------------------------------

func next_income_gain() -> float:
	## What the next income upgrade adds: each one `income_step_growth` times the last.
	return data.income_step * pow(maxf(data.income_step_growth, 0.0001), income_level)


func stat_bump(lv: int) -> float:
	## How much a unit type's health and attack are multiplied by at upgrade level `lv`.
	if data.upgrade_stat_growth > 0.0:
		return pow(data.upgrade_stat_growth, lv)
	return 1.0 + data.upgrade_stat_per_level * float(lv)


func income_maxed() -> bool:
	return data.income_max_level > 0 and income_level >= data.income_max_level


func income_price() -> float:
	## The price of the next income upgrade, or INF once the last has been bought.
	if income_maxed():
		return INF
	return data.income_cost * pow(data.income_growth, income_level)


func recruit_price() -> float:
	return roundf(data.recruit_cost * pow(data.recruit_growth, recruits) + data.recruit_step * recruits)


func level_of(id: StringName) -> int:
	return int(level.get(id, 0))


func max_level() -> int:
	if data.upgrade_cost_growth > 0.0:
		return maxi(data.upgrade_max_level, 1)
	return data.upgrade_costs.size()


func upgrade_price(id: StringName) -> float:
	## The price of the NEXT level, or INF once a type is at the top.
	var lv := level_of(id)
	if lv >= max_level():
		return INF
	if data.upgrade_cost_growth > 0.0:
		return roundf(data.upgrade_cost_base * pow(data.upgrade_cost_growth, lv))
	return data.upgrade_costs[lv]


func _pay(cost: float) -> bool:
	if is_inf(cost) or cost > supply + 0.0001:
		return false
	supply -= cost
	spent += cost
	return true


# --- Spending -----------------------------------------------------------------

func recruit(section: int) -> bool:
	## A random draw into the first free slot of a section. Refused, with nothing
	## spent, when the section is full or the Supply is not there.
	if section < 0 or section >= SECTIONS or free_slot(section) < 0:
		return false
	if not _pay(recruit_price()):
		return false
	recruits += 1
	_place(section, _loadout.draw_one(_rng))
	return true


func upgrade_income() -> bool:
	if not _pay(income_price()):
		return false
	income += next_income_gain()
	income_level += 1
	return true


func upgrade_type(id: StringName) -> bool:
	## One level on one unit type, for every copy of it.
	if not level.has(id):
		return false
	if not _pay(upgrade_price(id)):
		return false
	level[id] = level_of(id) + 1
	revision += 1
	return true


# --- What an upgrade does -----------------------------------------------------

func field_data(d: UnitData) -> UnitData:
	## The unit as it takes the field: its upgrade level's ability changes and stat
	## bump applied to a copy, or the unit itself at Lv0. Cached per row and level, so
	## every copy of a type at a level shares one resource.
	if d == null:
		return d
	return field_data_at(d, level_of(d.id))


func field_data_at(d: UnitData, lv: int) -> UnitData:
	## field_data at a given level rather than the type's current one — for showing
	## what the next level will change.
	if d == null:
		return d
	lv = mini(lv, max_level())
	if lv <= 0:
		return d
	var key := "%s|%d|%d" % [d.id, d.tier, lv]
	if _field_cache.has(key):
		return _field_cache[key]
	var out: UnitData = d.duplicate()
	if d.ability != null:
		out.ability = d.ability.duplicate()
	var bump := stat_bump(lv)
	out.max_hp = d.max_hp * bump
	out.attack_damage = d.attack_damage * bump
	if data.upgrades != null:
		var vals := data.upgrades.level_values(d.id, lv)
		for raw in vals:
			var k := String(raw)
			var value = vals[raw]
			var target: Object = out.ability if k.begins_with("a.") else out
			if target == null:
				continue
			var field := k.substr(2)
			if field.ends_with("*"):
				field = field.trim_suffix("*")
				target.set(field, float(target.get(field)) * float(value))
			else:
				target.set(field, value)
	_field_cache[key] = out
	return out


func level_changes(d: UnitData, lv: int) -> PackedStringArray:
	## What buying level `lv` changes, one line per improvement, read off the unit
	## itself before and after — so the numbers are the real ones for this tier, not
	## the table's.
	var out: PackedStringArray = []
	if d == null or data.upgrades == null:
		return out
	var before := field_data_at(d, lv - 1)
	var after := field_data_at(d, lv)
	var vals := data.upgrades.level_values(d.id, lv)
	for raw in vals:
		var k := String(raw)
		var field := k.substr(2).trim_suffix("*")
		var obj_a: Object = before.ability if k.begins_with("a.") else before
		var obj_b: Object = after.ability if k.begins_with("a.") else after
		if obj_a == null or obj_b == null:
			continue
		var a = obj_a.get(field)
		var b = obj_b.get(field)
		if a == null or b == null:
			continue
		if typeof(a) == typeof(b) and a == b:
			# Past Lv5 the ability table holds still; only health and attack grow.
			continue
		out.append(describe_change(field, a, b, k.begins_with("u.") and k.ends_with("*"),
			d.get(field) if k.begins_with("u.") else null))
	return out


static func describe_change(field: String, a, b, relative: bool, base) -> String:
	## "Attack speed +10% → +15%" for a share of the unit's own number, "Shield
	## percent 1.5 → 1.75" for a value the table sets outright.
	if field == "move_time" and relative and base != null and float(base) > 0.0:
		# Lower is faster: shown as the speed it buys, which reads the right way up.
		return "Move speed +%d%% → +%d%%" % [roundi((float(base) / float(a) - 1.0) * 100.0),
			roundi((float(base) / float(b) - 1.0) * 100.0)]
	var label := field.replace("_", " ").capitalize()
	if relative and base != null and float(base) != 0.0:
		return "%s +%d%% → +%d%%" % [label, roundi((float(a) / float(base) - 1.0) * 100.0),
			roundi((float(b) / float(base) - 1.0) * 100.0)]
	return "%s %s → %s" % [label, _num(a), _num(b)]


static func _num(v) -> String:
	if v is int:
		return str(v)
	if v is bool:
		return "on" if v else "off"
	var f := float(v)
	if is_equal_approx(f, roundf(f)):
		return str(roundi(f))
	return String.num(f, 3)


# --- Arranging ----------------------------------------------------------------

func at(section: int, slot: int) -> UnitData:
	return sections[section][slot]


func free_slot(section: int) -> int:
	var slots: Array = sections[section]
	for i in slots.size():
		if slots[i] == null:
			return i
	return -1


func _place(section: int, d: UnitData) -> int:
	var i := free_slot(section)
	if i >= 0 and d != null:
		sections[section][i] = d
	return i


func can_merge(a: UnitData, b: UnitData) -> bool:
	return a != null and b != null and a == b and not a.is_max_tier()


func drop(from_section: int, from_slot: int, to_section: int, to_slot: int) -> String:
	## Drag one slot onto another: onto an empty slot it moves, onto its twin it
	## merges (rolling the result the way a merge on the board does), onto anything
	## else it swaps. Returns what happened: "moved", "merged", "swapped" or "".
	if from_section == to_section and from_slot == to_slot:
		return ""
	var a := at(from_section, from_slot)
	if a == null:
		return ""
	var b := at(to_section, to_slot)
	if b == null:
		sections[to_section][to_slot] = a
		sections[from_section][from_slot] = null
		return "moved"
	if can_merge(a, b):
		sections[to_section][to_slot] = _merger.roll_merge_result(b)
		sections[from_section][from_slot] = null
		return "merged"
	sections[to_section][to_slot] = a
	sections[from_section][from_slot] = b
	return "swapped"


func merge_all(section: int) -> int:
	## Every merge a section has in it, pair after pair, until no twins are left — the
	## Merge button. Returns how many merges were made.
	var n := 0
	while merge_any(section):
		n += 1
	return n


func has_twin(section: int, slot: int) -> int:
	## The slot of this unit's merge partner in the same section, or -1.
	var d: UnitData = sections[section][slot]
	if d == null:
		return -1
	var slots: Array = sections[section]
	for j in slots.size():
		if j != slot and can_merge(d, slots[j]):
			return j
	return -1


func merge_any(section: int) -> bool:
	## One merge inside a section if it has a pair. For the scripted player.
	var slots: Array = sections[section]
	for i in slots.size():
		for j in range(i + 1, slots.size()):
			if can_merge(slots[i], slots[j]):
				drop(section, i, section, j)
				return true
	return false


# --- What a wave sends --------------------------------------------------------

func template(section: int) -> Array[Dictionary]:
	## The section as a wave sees it: every unit with its slot, in slot order.
	var out: Array[Dictionary] = []
	var slots: Array = sections[section]
	for i in slots.size():
		if slots[i] != null:
			out.append({data = slots[i], slot = i, section = section})
	return out


func unit_count(section: int) -> int:
	return template(section).size()


func slot_offset(slot: int) -> Vector2i:
	## Where a slot's unit stands relative to its crystal: the section grid laid on
	## the field just in front of the crystal (towards the boss), centred on it.
	var col := slot % data.section_cols
	var row := slot / data.section_cols
	return Vector2i(col - data.section_cols / 2, -(row + 1))
