extends SceneTree

## Writes data/boss/arbiter.tres, the boss for the defence mode, and
## data/boss/upgrades.tres, the per-unit upgrade table. Run it once; after that the
## .tres files are the source of truth and can be edited in the inspector — reorder
## a phase's `moves` to change its cycle, retune any number, change what a unit's
## upgrade level does. Running this again OVERWRITES those edits.
##
##   godot --headless --script res://tools/generate_boss.gd

const OUT := "res://data/boss/arbiter.tres"
const UPGRADES_OUT := "res://data/boss/upgrades.tres"


func _move(id: StringName, name: String, shape: BossMove.Shape, reach: int, span: int,
		mult: float, telegraph: float, crystals := false) -> BossMove:
	var m := BossMove.new()
	m.id = id
	m.display_name = name
	m.shape = shape
	m.reach = reach
	m.span = span
	m.damage_mult = mult
	m.telegraph = telegraph
	m.hits_crystals = crystals
	return m


func _stance(id: StringName, name: String, seconds: float, threshold: float,
		finisher: BossMove) -> BossMove:
	var m := _move(id, name, BossMove.Shape.STANCE, 0, 0, 0.0, seconds)
	m.stance_resist = 0.6
	m.break_threshold = threshold
	m.stagger_seconds = 3.0
	m.stagger_amp = 0.5
	m.boost_attack = 0.5
	m.boost_speed = 0.3
	m.boost_seconds = 15.0
	m.finisher = finisher
	return m


func _minion(id: StringName, name: String, hp: float, atk: float, speed: float,
		move: float, reach: int, accent: Color) -> BossMinion:
	var m := BossMinion.new()
	m.id = id
	m.display_name = name
	m.max_hp = hp
	m.attack_damage = atk
	m.attack_speed = speed
	m.move_time = move
	m.attack_range = reach
	m.accent = accent
	return m


func _phase(name: String, threshold: float, gap: float, haste: float,
		moves: Array[BossMove], lifesteal := 0.0) -> BossPhase:
	var p := BossPhase.new()
	p.display_name = name
	p.hp_threshold = threshold
	p.gap = gap
	p.haste = haste
	p.moves = moves
	p.lifesteal = lifesteal
	return p


func _cycle(normals: Array, bigs: Array, between: int) -> Array[BossMove]:
	## A phase's cycle: `between` ordinary moves before each big one, the ordinary
	## ones taken in turn. Keeps the big moves rarer than the rest, at a fixed spot.
	var out: Array[BossMove] = []
	var n := 0
	for big in bigs:
		for i in between:
			out.append(normals[n % normals.size()])
			n += 1
		out.append(big)
	return out


func _lv(table: Dictionary) -> Array:
	## {key: [Lv1, Lv2, Lv3, Lv4, Lv5]} -> five Dictionaries, one per level.
	var out: Array = []
	for i in 5:
		var row := {}
		for k in table:
			row[k] = table[k][i]
		out.append(row)
	return out


func _upgrades() -> BossUpgrades:
	## What each level does to each unit's OWN ability. Every level changes something
	## you can see — range, width, count, duration, chain, shape — and Lv5 is the
	## dramatic version. BossData.upgrade_stat_per_level adds a little health and
	## attack on top of every level.
	var u := BossUpgrades.new()
	u.levels = {
		# Bulwark: a bigger shield, then one that outgrows its own cap.
		&"warden": _lv({"a.shield_percent": [1.5, 1.75, 2.0, 2.5, 3.5],
			"a.shield_cap_percent": [1.5, 1.75, 2.0, 2.5, 3.5],
			"u.mana_per_attack*": [1.1, 1.2, 1.3, 1.4, 1.6]}),
		# Quickdraw: more stacks, and the bow reaches further.
		&"archer": _lv({"a.haste_max_stacks": [7, 8, 9, 10, 14],
			"u.attack_range": [3, 4, 4, 4, 5],
			"u.attack_speed*": [1.05, 1.1, 1.15, 1.2, 1.3]}),
		# Impale and its ordinary swing both run further down the line: 2 -> 7.
		&"lancer": _lv({"u.pierce_targets": [3, 4, 5, 6, 7],
			"a.pierce_targets": [4, 5, 6, 7, 9], "a.pierce_damage_mult": [2.2, 2.4, 2.6, 2.8, 3.5]}),
		# Execute: a heavier blow, and from Lv3 it splashes round the target.
		&"reaver": _lv({"a.burst_attack_multiple": [4.5, 5.0, 5.5, 6.0, 8.0],
			"a.splash_radius": [0, 0, 1, 1, 2], "a.splash_damage": [0.0, 0.0, 20.0, 30.0, 60.0]}),
		# Blight: a bigger first bite, longer to run, a deeper opening.
		&"vexer": _lv({"a.dot_current_hp_percent": [0.28, 0.31, 0.34, 0.37, 0.45],
			"a.dot_ticks": [7, 8, 9, 10, 12],
			"a.dot_vulnerability_per_tier": [0.06, 0.07, 0.08, 0.09, 0.12]}),
		# Arrest: longer, harder freezes.
		&"stasis": _lv({"a.freeze_seconds_per_tier": [1.0, 1.1, 1.25, 1.4, 1.8],
			"a.freeze_amp_per_tier": [0.17, 0.19, 0.22, 0.25, 0.32],
			"u.mana_per_attack*": [1.1, 1.2, 1.3, 1.4, 1.6]}),
		# Cinder Lance: hotter, and the scorch spreads wider.
		&"pyre": _lv({"a.burst_damage": [90.0, 105.0, 120.0, 140.0, 190.0],
			"a.splash_radius": [1, 1, 2, 2, 3],
			"u.mana_per_attack*": [1.1, 1.2, 1.3, 1.4, 1.6]}),
		# Retribution: holds longer and throws back more.
		&"aegis": _lv({"a.reflect_duration": [6.0, 7.0, 8.0, 9.0, 12.0],
			"a.reflect_percent": [2.25, 2.5, 2.75, 3.0, 4.0],
			"u.mana_per_attack*": [1.1, 1.2, 1.3, 1.4, 1.6]}),
		# Its weight on the field reaches further.
		&"tyrant": _lv({"u.burden_radius": [2, 3, 3, 4, 5],
			"u.burden_percent*": [1.1, 1.2, 1.3, 1.4, 1.7],
			"u.attack_speed*": [1.05, 1.1, 1.15, 1.2, 1.3]}),
		# Benediction: heals more, from further away.
		&"seraph": _lv({"a.heal_radius": [4, 4, 5, 5, 7],
			"a.heal_percent": [0.5, 0.55, 0.6, 0.7, 0.9],
			"u.mana_per_attack*": [1.1, 1.2, 1.3, 1.4, 1.6]}),
		# War Horn: reaches more of the line, and lifts it harder.
		&"herald": _lv({"a.aura_radius": [1, 2, 2, 3, 4],
			"a.aura_percent_per_tier": [0.13, 0.14, 0.15, 0.17, 0.22],
			"u.mana_per_attack*": [1.1, 1.2, 1.3, 1.4, 1.6]}),
		# Second Wind: up again more often, and sooner.
		&"revenant": _lv({"a.revive_chance": [0.55, 0.6, 0.65, 0.75, 0.9],
			"a.revive_delay": [0.9, 0.8, 0.7, 0.6, 0.4],
			"u.attack_speed*": [1.05, 1.1, 1.15, 1.2, 1.3]}),
		# Shadowstep: a harder strike, and longer unseen afterwards.
		&"assassin": _lv({"a.blink_base_damage": [55.0, 65.0, 75.0, 90.0, 130.0],
			"a.stealth_time": [4.0, 4.5, 5.0, 5.5, 7.0],
			"u.move_time*": [0.95, 0.9, 0.85, 0.8, 0.7]}),
		# Overflow: the mana zone grows.
		&"wellspring": _lv({"a.mana_aura_radius": [1, 2, 3, 4, 5],
			"u.mana_per_charge*": [1.1, 1.2, 1.3, 1.4, 1.6],
			"u.attack_speed*": [1.05, 1.1, 1.15, 1.2, 1.3]}),
		# No ability: its plating learns to take blows, more with every level.
		&"amalgam": _lv({"u.shield_on_hit": [0.01, 0.02, 0.03, 0.04, 0.06],
			"u.attack_speed*": [1.05, 1.1, 1.15, 1.2, 1.3],
			"u.move_time*": [0.95, 0.9, 0.85, 0.8, 0.7]}),
		# The beam washes over more and more of what it passes.
		&"transcendence": _lv({"u.beam_splash": [0.1, 0.2, 0.3, 0.4, 0.6],
			"u.attack_speed*": [1.05, 1.1, 1.15, 1.2, 1.3],
			"u.move_time*": [0.95, 0.9, 0.85, 0.8, 0.7]}),
		# Call Wisp: more wisps per tier, and a bigger retinue.
		&"conjurer": _lv({"a.summon_per_tier": [1.25, 1.5, 1.75, 2.0, 3.0],
			"a.summon_max": [6, 7, 8, 9, 12],
			"u.mana_per_attack*": [1.1, 1.2, 1.3, 1.4, 1.6]}),
		# Bombardment: a wider cross, and the ground burns longer.
		&"culverin": _lv({"a.shell_arm": [1, 2, 2, 3, 4], "a.field_seconds": [6.0, 7.0, 8.0, 9.0, 12.0],
			"u.mana_per_attack*": [1.1, 1.2, 1.3, 1.4, 1.6]}),
		# Siphon: drinks faster, and keeps more of what it takes.
		&"leech": _lv({"a.drain_percent_per_tier": [0.006, 0.007, 0.008, 0.01, 0.015],
			"u.lifesteal": [0.3, 0.35, 0.4, 0.45, 0.6],
			"u.attack_speed*": [1.05, 1.1, 1.15, 1.2, 1.3]}),
		# Usurpation: holds its host longer.
		&"usurper": _lv({"a.possess_seconds_per_tier": [3.0, 3.5, 4.0, 4.5, 6.0],
			"u.attack_speed*": [1.05, 1.1, 1.15, 1.2, 1.3],
			"u.move_time*": [0.95, 0.9, 0.85, 0.8, 0.7]}),
		# Onslaught: hits harder and stuns longer at the end of the run.
		&"breaker": _lv({"a.charge_damage_per_tier": [2.0, 2.2, 2.4, 2.7, 3.5],
			"a.stun_seconds_per_tier": [0.5, 0.55, 0.65, 0.75, 1.0],
			"u.attack_speed*": [1.05, 1.1, 1.15, 1.2, 1.3]}),
		# Hardens faster under blows.
		&"colossus": _lv({"u.shield_on_hit*": [1.15, 1.3, 1.6, 1.9, 2.8],
			"u.attack_speed*": [1.05, 1.1, 1.15, 1.2, 1.3],
			"u.move_time*": [0.95, 0.9, 0.85, 0.8, 0.7]}),
		# Alone, it bites deeper.
		&"pariah": _lv({"u.alone_hp_damage*": [1.15, 1.3, 1.45, 1.7, 2.3],
			"u.attack_speed*": [1.05, 1.1, 1.15, 1.2, 1.3],
			"u.move_time*": [0.95, 0.9, 0.85, 0.8, 0.7]}),
		# Lament: calls back more of the fallen, at fuller health.
		&"vigil": _lv({"a.raise_per_tier": [1, 2, 2, 3, 4], "a.raise_hp_percent": [0.9, 0.95, 1.0, 1.0, 1.0],
			"u.attack_speed*": [1.05, 1.1, 1.15, 1.2, 1.3]}),
		# Last Stand: pulls from further, and holds longer.
		&"paragon": _lv({"a.taunt_radius": [3, 4, 4, 5, 6], "a.taunt_duration": [4.5, 5.0, 5.5, 6.0, 8.0],
			"u.mana_per_attack*": [1.1, 1.2, 1.3, 1.4, 1.6]}),
		# Undermine: more ground at once, and a bigger charge.
		&"sapper": _lv({"a.terrain_tiles": [1, 2, 2, 3, 4], "a.sap_burst_multiple": [4.5, 5.0, 5.5, 6.0, 8.0],
			"u.mana_per_charge*": [1.1, 1.2, 1.3, 1.4, 1.6]}),
		# Raise walls: more of them, tougher.
		&"mason": _lv({"a.terrain_tiles": [1, 2, 2, 3, 4], "a.wall_hp": [280.0, 320.0, 360.0, 420.0, 600.0],
			"u.mana_per_charge*": [1.1, 1.2, 1.3, 1.4, 1.6]}),
		# Gorge: a bigger, faster ascended form.
		&"devourer": _lv({"a.ascend_hp_mult": [2.7, 2.9, 3.1, 3.4, 4.0],
			"a.ascend_attack_speed_mult": [1.55, 1.6, 1.7, 1.8, 2.0],
			"u.move_time*": [0.95, 0.9, 0.85, 0.8, 0.7]}),
		# Raise Host: more hosts per raising.
		&"spire": _lv({"a.summon_count": [2, 3, 4, 5, 6],
			"u.mana_per_charge*": [1.1, 1.2, 1.3, 1.4, 1.6],
			"u.shield_on_hit": [0.01, 0.02, 0.03, 0.04, 0.06]}),
		# Assemble: builds sooner, and mends faster.
		&"engineer": _lv({"a.cast_time": [9.0, 8.0, 7.0, 6.0, 4.0],
			"u.repair_per_second*": [1.2, 1.4, 1.6, 2.0, 3.0],
			"u.mana_per_charge*": [1.1, 1.2, 1.3, 1.4, 1.6]}),
		# Martyrdom: a longer last stand, cutting through more.
		&"martyr": _lv({"a.frenzy_seconds": [3.0, 3.5, 4.0, 4.5, 6.0], "a.frenzy_pierce": [3, 4, 4, 5, 7],
			"u.attack_speed*": [1.05, 1.1, 1.15, 1.2, 1.3]}),
		# Vertigo: longer lost, and a higher ceiling.
		&"siren": _lv({"a.disorient_seconds": [0.6, 0.7, 0.8, 0.9, 1.2],
			"a.disorient_max": [2.3, 2.6, 3.0, 3.5, 4.5],
			"u.mana_per_attack*": [1.1, 1.2, 1.3, 1.4, 1.6]}),
		# Triage: reaches further, mends more, and more often.
		&"hospitaller": _lv({"a.heal_radius": [3, 4, 4, 5, 6], "a.mend_percent": [0.06, 0.07, 0.08, 0.09, 0.12],
			"a.mend_interval": [1.0, 0.9, 0.8, 0.7, 0.5]}),
		# Slow Match: a heavier blast, over a bigger square.
		&"powderkeg": _lv({"a.blast_radius": [1, 2, 2, 2, 3],
			"a.blast_attack_multiple": [5.5, 6.0, 6.5, 7.0, 9.0],
			"u.move_time*": [0.95, 0.9, 0.85, 0.8, 0.7]}),
	}
	return u


func _initialize() -> void:
	var S := BossMove.Shape
	# Sized for the open field: sweeps reach further either side, columns and the
	# spear run deeper, and the dash and the leap cover real ground.
	var sweep := _move(&"crescent_sweep", "Crescent Sweep", S.ROWS, 3, 1, 2.0, 1.0)
	var edge := _move(&"falling_edge", "Falling Edge", S.COLUMNS, 6, 1, 2.5, 1.0)
	var spear := _move(&"longspear", "Longspear", S.THRUST, 7, 1, 3.0, 1.2)
	var dash := _move(&"breach_dash", "Breach Dash", S.DASH, 8, 1, 2.0, 1.0)
	var crossed := _move(&"crossed_blades", "Crossed Blades", S.ROWS, 4, 2, 2.5, 0.9)
	var heaven := _move(&"heaven_split", "Heaven Split", S.COLUMNS, 8, 3, 4.5, 1.6, true)
	var horizon := _move(&"horizon_split", "Horizon Split", S.ROWS, 5, 3, 4.0, 1.6, true)
	var pounce := _move(&"pouncing_ruin", "Pouncing Ruin", S.LEAP, 6, 1, 3.0, 1.2)
	# The map-wide moves. Each leaves somewhere safe and is marked before it lands.
	var hunt := _move(&"hunting_sweep", "Hunting Sweep", S.HUNT, 40, 3, 2.5, 1.4)
	var cross := _move(&"crimson_cross", "Crimson Cross", S.CROSS, 0, 3, 3.0, 1.5)
	var ring := _move(&"shockwave", "Shockwave", S.RING, 3, 2, 2.5, 1.4)
	var ring_big := _move(&"great_shockwave", "Great Shockwave", S.RING, 4, 3, 3.0, 1.5)
	var rain := _move(&"blade_rain", "Blade Rain", S.RAIN, 0, 1, 3.0, 1.4)
	rain.count = 24
	var rain_big := _move(&"blade_storm", "Blade Storm", S.RAIN, 0, 1, 3.0, 1.4)
	rain_big.count = 40
	var onrush := _move(&"onrush", "Onrush", S.ONRUSH, 0, 1, 4.0, 0.7)
	onrush.legs = 6
	var onrush_long := _move(&"endless_onrush", "Endless Onrush", S.ONRUSH, 0, 1, 4.0, 0.6)
	onrush_long.legs = 9
	# Endless Onrush hunts: every leg runs through the thickest knot of the army.
	onrush_long.seeks_army = true
	var stripes := _move(&"thousand_cuts", "Thousand Cuts", S.STRIPES, 0, 1, 3.5, 1.2)
	# % max HP on the heavy blows, and executions on the two stance finishers — break
	# the stance, or her answer kills your best units outright.
	for pair in [[heaven, 0.12], [horizon, 0.10], [pounce, 0.08], [spear, 0.06], [ring_big, 0.15], [rain_big, 0.10]]:
		pair[0].max_hp_percent = pair[1]
	cross.executes_top_tier = true
	stripes.executes_top_tier = true
	# The charge-up stances, and what each lets loose if it is not broken.
	var gather := _stance(&"gathering_storm", "Gathering Storm", 5.0, 3000.0, cross)
	var red_tide := _stance(&"red_tide", "Red Tide", 5.0, 4500.0, onrush)
	var last_breath := _stance(&"last_breath", "Last Breath", 5.0, 6000.0, stripes)

	var b := BossData.new()
	b.id = &"arbiter"
	b.display_name = "The Vermilion Arbiter"
	b.title = "Keeper of Every Blade"
	b.note = "A duellist in lacquered red who has outlived every weapon she was handed and kept them all. She starts with one blade and a spear, picks up a second blade when she is hurt, and fights hardest at the end."
	b.max_hp = 90000.0
	b.attack_damage = 100.0
	b.attack_speed = 0.9
	b.move_time = 0.9
	# The economy. See BossData for what each number does.
	b.start_supply = 20.0
	b.base_income = 4.0
	b.income_step = 2.0
	b.income_cost = 30.0
	b.income_growth = 1.6
	# Recruits: 10 Supply, then 2 more each time — 10, 12, 14, 16...
	b.recruit_cost = 10.0
	b.recruit_step = 2.0
	b.recruit_growth = 1.0
	b.upgrade_costs = PackedFloat32Array([30, 50, 80, 120, 180])
	b.upgrade_stat_per_level = 0.15
	b.start_draws = 6
	b.section_cols = 3
	b.section_rows = 4
	b.zone_cap = 20
	# The adds.
	b.minion_name = "Crimson Shade"
	b.minion_hp = 420.0
	b.minion_attack = 35.0
	b.minion_cap = 8
	# A shade tears out of its circle, hitting everything round it, and while shades
	# stand she takes less damage — so they are worth killing, not just walking past.
	b.minion_burst_mult = 2.5
	b.minion_burst_radius = 1
	b.minion_ward_per_shade = 0.06
	b.summon_warning = 1.0
	b.accent = Color(0.80, 0.12, 0.14)
	# Every map-wide move and every stance finisher charges up before it is marked.
	for big in [hunt, cross, ring, ring_big, rain, rain_big, onrush, onrush_long, stripes]:
		big.windup = 2.5
	# The retreats: she vanishes to the back of the field, calls up all three kinds of
	# summon, and heals while taking extra damage. Ride it out and she comes back
	# stronger for good; beat her down a bar meanwhile and it is cut short.
	var shade := _minion(&"crimson_shade", "Crimson Shade", 420.0, 35.0, 1.0, 0.8, 1,
		Color(0.80, 0.12, 0.14).lightened(0.25))
	shade.burst_mult = 2.5
	var thorn := _minion(&"scarlet_thorn", "Scarlet Thorn", 240.0, 30.0, 0.9, 0.85, 3,
		Color(0.78, 0.22, 0.34))
	thorn.ranged = true
	var chalice := _minion(&"blood_chalice", "Blood Chalice", 700.0, 0.0, 0.5, 0.8, 1,
		Color(0.55, 0.14, 0.20))
	chalice.can_move = false
	chalice.can_attack = false
	chalice.heal_boss = 0.003
	var retreat := _move(&"crimson_retreat", "Crimson Retreat", S.RETREAT, 0, 0, 0.0, 0.5)
	retreat.windup = 1.5
	retreat.retreat_summons = [shade, shade, thorn, thorn, chalice, chalice] as Array[BossMinion]
	var sanctum := _move(&"scarlet_sanctum", "Scarlet Sanctum", S.RETREAT, 0, 0, 0.0, 0.5)
	sanctum.windup = 1.5
	sanctum.retreat_seconds = 9.0
	sanctum.retreat_heal = 0.007
	sanctum.retreat_summons = [shade, shade, shade, thorn, thorn, thorn, chalice, chalice] as Array[BossMinion]
	b.phases = [
		# Four phases, each its own health bar. The crystals and the merge are a
		# separate track: they change WHERE it fights, these change HOW.
		_phase("First Blade", 1.0, 3.0, 1.0, [sweep, edge, spear, dash]),
		# It takes up a second weapon: quicker, the two-row combo joins the cycle, and
		# the first stance and the first map-wide sweep arrive. The big moves are
		# spaced out with ordinary ones — about one in eight of the cycle.
		_phase("Twin Blades", 0.75, 2.4, 1.2,
			_cycle([crossed, sweep, spear, edge, dash], [gather, hunt], 7)),
		_phase("Rending Arts", 0.50, 2.2, 1.3,
			_cycle([heaven, crossed, horizon, pounce, spear], [ring, red_tide, retreat, rain], 4)),
		# Its final form: the widest moves, and every blow feeds it.
		_phase("Crimson Finale", 0.25, 2.0, 1.4,
			_cycle([heaven, pounce, horizon, spear, crossed], [onrush_long, last_breath,
				sanctum, ring_big, rain_big], 4),
			0.10),
	]
	var summons := [[0, 0.0, 0, 1.0], [2, 20.0, 1, 1.0], [3, 18.0, 2, 1.3], [4, 15.0, 2, 1.6]]
	for i in b.phases.size():
		b.phases[i].summons_on_start = summons[i][0]
		b.phases[i].summon_every = summons[i][1]
		b.phases[i].summon_count = summons[i][2]
		b.phases[i].minion_power = summons[i][3]
	# Phase music: stretches of two personal tracks in audio/boss (never exported —
	# see the README there). Gebura Battle Theme split on its bar lines: 110 BPM, a
	# beat every 60/110 s, the first at 0.071 s, a section every 168 beats (42 bars) —
	# 91.6364 s and 183.2727 s, measured from the onsets in the file. Every stretch is a
	# whole number of beats long, so each loop lands on the downbeat (the file itself is
	# 506 beats, so Theme 4 wrapping off its end lands right too). The Red Mist theme
	# whole, from its first sound: the file opens on 65 ms of silence (2854 samples, measured
	# from the decoded audio), which looping from 0 put into every lap as an audible gap. [path, from, to]; to 0 = the end of the file.
	var music := [
		["res://audio/boss/gebura_battle.mp3", 0.0, 91.6364, "Theme 1"],
		["res://audio/boss/gebura_battle.mp3", 91.6364, 183.2727, "Theme 2"],
		["res://audio/boss/red_mist.mp3", 0.0647, 0.0, "Theme 3"],
		["res://audio/boss/gebura_battle.mp3", 183.2727, 0.0, "Theme 4"],
	]
	for i in b.phases.size():
		b.phases[i].music_path = music[i][0]
		b.phases[i].music_from = music[i][1]
		b.phases[i].music_to = music[i][2]
		b.phases[i].music_label = music[i][3]
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://data/boss"))
	var up := _upgrades()
	print("  ", UPGRADES_OUT, "  err=", ResourceSaver.save(up, UPGRADES_OUT))
	b.upgrades = load(UPGRADES_OUT) as BossUpgrades
	var err := ResourceSaver.save(b, OUT)
	print("  ", OUT, "  err=", err)
	quit()
