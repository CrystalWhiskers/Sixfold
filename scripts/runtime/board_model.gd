class_name BoardModel
extends RefCounted

# The board's shape is chosen per match, so these are static rather than const.
# One board is live at a time; use_map() sets them and reset_map() puts the
# default back, which is what every test starts from.
const DEFAULT_WIDTH := 6
const DEFAULT_HEIGHT := 11

static var WIDTH := DEFAULT_WIDTH
static var HEIGHT := DEFAULT_HEIGHT
static var NEUTRAL_ROW := DEFAULT_HEIGHT / 2
static var HAS_NEUTRAL := true
static var map_name := "Standard"

# Terrain follows the dimensions: one board is live, so one set of tables.
static var _walls: Dictionary = {}
static var _voids: Dictionary = {}
static var _high: Dictionary = {}
static var _stairs: Dictionary = {}
static var _edges: Dictionary = {}

# Terrain the battle itself changed. `_rubble` is which of the map's walls may be
# knocked down at all; `_broken` and `_raised` are this round's damage and
# building. The map resource is never touched — clear_changes() at the round
# boundary puts the board back exactly as it was drawn, so a map is still a
# static, shareable thing and a *battle* is what makes it mutable.
static var _rubble: Dictionary = {}
static var _broken: Dictionary = {}
# cell -> the team that raised it, or NOBODY for one with no owner. The owner is
# what makes a Mason's wall a membrane: its own side shoots straight through and
# the other side does not. Map stone has no owner and blocks everybody.
static var _raised: Dictionary = {}
const NOBODY := -1

# What is left of each standing breakable wall. A wall is no longer something one
# cast deletes — it is a thing with health that anybody can chew through, given
# long enough. Cells appear here lazily on the first hit, so a map with a hundred
# breakable tiles costs nothing until somebody starts digging.
static var _wall_hp: Dictionary = {}
static var _wall_full: Dictionary = {}

# The default toughness of map stone. A Sapper is meant to take a few swings over
# it and an ordinary unit is meant to regret starting.
const WALL_HP := 240.0

const TEAM_A := 0
const TEAM_B := 1

const DIAGONAL_MOVEMENT := false

const DIAGONAL_RANGE := false

const MERGE_INHERITS_BUFFS := false

var _cells: Dictionary = {}
var _sorted: Array[UnitInstance] = []
var _sorted_dirty := true

var merge_pool: Array[UnitData] = []
var team_merge_pools: Dictionary = {}
var wild_merge_teams: Dictionary = {}
var team_buffs: Dictionary = {}
var last_merge_procs: Dictionary = {}
var merge_rng := RandomNumberGenerator.new()


static func use_map(m: MapData) -> void:
	if m == null or not m.is_valid():
		reset_map()
		return
	WIDTH = m.width
	HEIGHT = m.height
	HAS_NEUTRAL = m.has_neutral
	NEUTRAL_ROW = HEIGHT / 2
	map_name = m.display_name
	_walls = {}
	_voids = {}
	_high = {}
	_stairs = {}
	_rubble = {}
	_broken = {}
	_raised = {}
	_wall_hp = {}
	_wall_full = {}
	_edges = m.edge_keys()
	for y in HEIGHT:
		for x in WIDTH:
			var c := Vector2i(x, y)
			if m.is_wall(c):
				_walls[c] = true
				if m.is_breakable(c):
					_rubble[c] = true
			elif m.is_void(c):
				_voids[c] = true
			elif m.is_high(c):
				_high[c] = true
			elif m.is_stairs(c):
				_stairs[c] = true


static func reset_map() -> void:
	WIDTH = DEFAULT_WIDTH
	HEIGHT = DEFAULT_HEIGHT
	HAS_NEUTRAL = true
	NEUTRAL_ROW = DEFAULT_HEIGHT / 2
	map_name = "Standard"
	_walls = {}
	_voids = {}
	_high = {}
	_stairs = {}
	_rubble = {}
	_broken = {}
	_raised = {}
	_wall_hp = {}
	_wall_full = {}
	_edges = {}


static func first_row(team: int) -> int:
	if team == TEAM_A:
		return 0
	return NEUTRAL_ROW + (1 if HAS_NEUTRAL else 0)


static func last_row(team: int) -> int:
	return NEUTRAL_ROW if team == TEAM_A else HEIGHT


func in_bounds(c: Vector2i) -> bool:
	return c.x >= 0 and c.x < WIDTH and c.y >= 0 and c.y < HEIGHT


static func is_wall(c: Vector2i) -> bool:
	if _raised.has(c):
		return true
	return _walls.has(c) and not _broken.has(c)


static func is_breakable(c: Vector2i) -> bool:
	# A raised wall can be knocked back down: whoever put it there does not get
	# to make it permanent, and the Mason/Sapper pair has to answer each other.
	if _raised.has(c):
		return true
	return _rubble.has(c) and not _broken.has(c)


static func wall_hp(c: Vector2i) -> float:
	if not is_breakable(c):
		return 0.0
	return float(_wall_hp.get(c, WALL_HP))


static func wall_fraction(c: Vector2i) -> float:
	# For the view: how much of it is left, so a wall visibly crumbles rather than
	# vanishing without warning.
	if not is_breakable(c):
		return 0.0
	var full: float = float(_wall_full.get(c, WALL_HP))
	if full <= 0.0:
		return 0.0
	return clampf(wall_hp(c) / full, 0.0, 1.0)


static func damage_wall(c: Vector2i, amount: float) -> bool:
	# Returns true only on the blow that brings it down, so a caller can react to
	# the hole appearing without having to check afterwards.
	if not is_breakable(c) or amount <= 0.0:
		return false
	var left := wall_hp(c) - amount
	if left > 0.0:
		_wall_hp[c] = left
		if not _wall_full.has(c):
			_wall_full[c] = WALL_HP
		return false
	_wall_hp.erase(c)
	_wall_full.erase(c)
	if _raised.has(c):
		_raised.erase(c)
	else:
		_broken[c] = true
	return true


static func break_wall(c: Vector2i) -> bool:
	# The instant version. Kept because "take this wall down now" is a clearer
	# thing to say in a test than "hit it for more than it could possibly have".
	if not is_breakable(c):
		return false
	return damage_wall(c, wall_hp(c))


static func raise_wall(c: Vector2i, hp := WALL_HP, team := NOBODY) -> bool:
	# Only onto ground that is genuinely open. Never over a hole in the board —
	# a void is not a tile you can build on, it is a tile that is not there.
	if not is_playable(c) or _voids.has(c) or _raised.has(c):
		return false
	_raised[c] = team
	# A raised wall carries the toughness its builder gave it, which is what the
	# Mason's buff actually buys.
	_wall_hp[c] = maxf(hp, 1.0)
	_wall_full[c] = maxf(hp, 1.0)
	return true


static func changed_terrain() -> Dictionary:
	return {broken = _broken.keys(), raised = _raised.keys()}


static func clear_changes() -> void:
	_broken = {}
	_raised = {}
	_wall_hp = {}
	_wall_full = {}


static func is_void(c: Vector2i) -> bool:
	return _voids.has(c)


static func is_high(c: Vector2i) -> bool:
	return _high.has(c)


static func is_stairs(c: Vector2i) -> bool:
	return _stairs.has(c)


static func can_climb(from: Vector2i, to: Vector2i) -> bool:
	# High ground is a second layer everywhere, on every map, with no exceptions —
	# the eleven older maps that predate stairs all had them cut in rather than
	# being grandfathered out of the rule. The builder refuses to produce a map
	# with a plateau no staircase touches, which is what makes "no exceptions"
	# safe to rely on here.
	#
	# Getting DOWN off a plateau is free — you can step off an edge anywhere — and
	# only getting UP is restricted, which is what makes a terrace a place you
	# retreat to rather than a box you get stuck in.
	if not is_high(to):
		return true
	return is_high(from) or is_stairs(from)


static func is_blocked(c: Vector2i) -> bool:
	return is_wall(c) or _voids.has(c)


static func is_playable(c: Vector2i) -> bool:
	return (c.x >= 0 and c.x < WIDTH and c.y >= 0 and c.y < HEIGHT
		and not is_blocked(c))


static func blocks_sight(c: Vector2i, team := NOBODY) -> bool:
	# Solid walls stop a shot. Holes in the board do not — you can fire across a
	# gap, you just cannot stand in it. Barriers are waist-high: they stop bodies
	# and nothing else. A wall knocked down this round stops nothing.
	#
	# A raised wall is the exception, and the only team-aware terrain in the game:
	# the side that built it shoots straight through its own, and everybody else
	# is stopped. It still blocks MOVEMENT for both sides — is_blocked() does not
	# take a team — so a Mason's wall is a firing slit, not a door.
	if _raised.has(c) and team != NOBODY and int(_raised[c]) == team:
		return false
	return is_wall(c)


static func line_of_fire(from: Vector2i, to: Vector2i, team := NOBODY) -> bool:
	# _raised has to be in the early-out too, or a Mason's wall on an otherwise
	# open map would block nothing at all.
	if from == to or (_walls.is_empty() and _raised.is_empty()):
		return true
	# Walk the line from a fixed end, so "A can shoot B" and "B can shoot A" can
	# never disagree over a tie. That symmetry is about rounding, not about teams:
	# with a team given, the two directions are SUPPOSED to disagree across a
	# Mason's wall, and they do, because the swap only fixes which end the walk
	# starts from and not which tiles are on the line.
	var a := from
	var b := to
	if b.y < a.y or (b.y == a.y and b.x < a.x):
		a = to
		b = from

	var dx := absi(b.x - a.x)
	var dy := absi(b.y - a.y)
	var sx := signi(b.x - a.x)
	var sy := signi(b.y - a.y)
	var x := a.x
	var y := a.y
	var err := dx - dy
	while true:
		var c := Vector2i(x, y)
		if c != a and c != b and blocks_sight(c, team):
			return false
		if c == b:
			return true
		var e2 := err * 2
		if e2 > -dy:
			err -= dy
			x += sx
		if e2 < dx:
			err += dx
			y += sy
	# Unreachable: the walk always lands on b. GDScript needs it spelled out.
	return true


static func blocks_between(a: Vector2i, b: Vector2i) -> bool:
	# A barrier sits on the line between two tiles: both stay usable, but
	# nothing crosses. Range is unaffected — it stops movement, not sight.
	return _edges.has(MapData.edge_key(a, b))


static func has_terrain() -> bool:
	return not (_walls.is_empty() and _voids.is_empty()
		and _high.is_empty() and _stairs.is_empty()
		and _edges.is_empty() and _raised.is_empty())


func is_neutral(c: Vector2i) -> bool:
	return HAS_NEUTRAL and c.y == NEUTRAL_ROW


func is_empty(c: Vector2i) -> bool:
	return in_bounds(c) and not is_blocked(c) and not _cells.has(c)


func unit_at(c: Vector2i) -> UnitInstance:
	return _cells.get(c, null)


func _ensure_sorted() -> void:
	if not _sorted_dirty:
		return
	_sorted.clear()
	for u in _cells.values():
		_sorted.append(u)
	_sorted.sort_custom(func(a: UnitInstance, b: UnitInstance) -> bool: return a.uid < b.uid)
	_sorted_dirty = false


func all_units() -> Array[UnitInstance]:
	_ensure_sorted()
	return _sorted.duplicate()


func units_view() -> Array[UnitInstance]:
	_ensure_sorted()
	return _sorted


func living_count_of(team: int) -> int:
	var n := 0
	for u in units_view():
		if u.team == team and u.is_alive():
			n += 1
	return n


func units_of(team: int) -> Array[UnitInstance]:
	var out: Array[UnitInstance] = []
	for u in units_view():
		if u.team == team:
			out.append(u)
	return out


func living_units_of(team: int) -> Array[UnitInstance]:
	var out: Array[UnitInstance] = []
	for u in units_of(team):
		if u.is_alive():
			out.append(u)
	return out


func count_of(team: int) -> int:
	return units_of(team).size()


static func tile_distance(a: Vector2i, b: Vector2i) -> int:
	var d := (a - b).abs()
	if DIAGONAL_RANGE:
		return maxi(d.x, d.y)
	return d.x + d.y


static func box_distance(a: Vector2i, b: Vector2i) -> int:
	# Chebyshev: how many rings out b sits from a. Always 1 for any of the eight
	# tiles touching a, corners included.
	var d := (a - b).abs()
	return maxi(d.x, d.y)


static func is_beside(a: Vector2i, b: Vector2i) -> bool:
	return a != b and box_distance(a, b) <= 1


static func in_reach(from: Vector2i, to: Vector2i, tiles: int) -> bool:
	# The melee band is the eight tiles around you, not the four. Movement is
	# still four-way — nothing walks diagonally — but a unit can obviously hit the
	# one standing at its shoulder, and before this it could not, which is why
	# melee units used to shuffle around each other in corners without swinging.
	#
	# Only the melee band changes. Every longer band still measures in Manhattan
	# steps, so a "medium" unit reaches a diamond and not a 5x5 box.
	# Zero reach is a refusal, not a short range, and it has to be checked before
	# the melee branch below or "cannot reach this at all" quietly becomes "can
	# hit anything at its shoulder". Nothing produced a zero here until high
	# ground did: reach_on() floors at the melee band, which is one.
	if tiles <= 0:
		return false
	if tiles <= 1:
		return is_beside(from, to)
	return tile_distance(from, to) <= tiles


static func mirror(c: Vector2i) -> Vector2i:
	return Vector2i(c.x, HEIGHT - 1 - c.y)


static func enemy_of(team: int) -> int:
	return TEAM_B if team == TEAM_A else TEAM_A


func can_deploy(team: int, c: Vector2i) -> bool:
	if not in_bounds(c) or is_neutral(c) or is_blocked(c):
		return false
	return (c.y < NEUTRAL_ROW) == (team == TEAM_A)


func deploy_cells(team: int) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	var rows := range(first_row(team), last_row(team))
	for y in rows:
		for x in WIDTH:
			var c := Vector2i(x, y)
			if not is_blocked(c):
				out.append(c)
	return out


func free_cells() -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	for y in HEIGHT:
		for x in WIDTH:
			var c := Vector2i(x, y)
			if is_empty(c):
				out.append(c)
	return out


func playable_cells() -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	for y in HEIGHT:
		for x in WIDTH:
			var c := Vector2i(x, y)
			if not is_blocked(c):
				out.append(c)
	return out


func half_capacity(team: int) -> int:
	# Counted from the deploy list, so a map with holes in it reports the tiles
	# a side really has rather than width times rows.
	return deploy_cells(team).size()


static func by_distance_to(cells: Array[Vector2i], centre: Vector2i) -> Array[Vector2i]:
	var out: Array[Vector2i] = cells.duplicate()
	out.sort_custom(func(a: Vector2i, b: Vector2i) -> bool:
		var da := tile_distance(a, centre)
		var db := tile_distance(b, centre)
		if da != db:
			return da < db
		if a.y != b.y:
			return a.y < b.y
		return a.x < b.x)
	return out


func free_deploy_cells(team: int) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	for c in deploy_cells(team):
		if is_empty(c):
			out.append(c)
	return out


func clear() -> void:
	_cells.clear()
	_sorted_dirty = true


func place(u: UnitInstance, c: Vector2i) -> bool:
	if not can_deploy(u.team, c) or not is_empty(c):
		return false
	_cells[c] = u
	u.cell = c
	u.move_from = c
	_sorted_dirty = true
	return true


func force_place(u: UnitInstance, c: Vector2i) -> bool:
	if not is_empty(c):
		return false
	_cells[c] = u
	u.cell = c
	_sorted_dirty = true
	return true


func remove(u: UnitInstance) -> void:
	if _cells.get(u.cell, null) == u:
		_cells.erase(u.cell)
		_sorted_dirty = true


func move_unit(u: UnitInstance, to: Vector2i) -> bool:
	if not in_bounds(to) or not is_empty(to):
		return false
	remove(u)
	_cells[to] = u
	u.cell = to
	_sorted_dirty = true
	return true


func swap_cells(a: Vector2i, b: Vector2i) -> bool:
	if not in_bounds(a) or not in_bounds(b):
		return false
	var ua := unit_at(a)
	var ub := unit_at(b)
	if ua == null or ub == null:
		return false
	if not can_deploy(ua.team, b) or not can_deploy(ub.team, a):
		return false
	_cells[a] = ub
	_cells[b] = ua
	ua.cell = b
	ub.cell = a
	ua.move_from = b
	ub.move_from = a
	return true


func trade_places(a: UnitInstance, b: UnitInstance) -> bool:
	# swap_cells() is the prep-phase version and honours the deploy halves. Once
	# the fighting starts there are no halves, so this is the same swap without
	# that check. Nothing else about it differs.
	if a == null or b == null or a == b:
		return false
	if _cells.get(a.cell, null) != a or _cells.get(b.cell, null) != b:
		return false
	var ca := a.cell
	var cb := b.cell
	_cells[ca] = b
	_cells[cb] = a
	a.cell = cb
	b.cell = ca
	a.move_from = ca
	b.move_from = cb
	_sorted_dirty = true
	return true


func push(u: UnitInstance, dir: Vector2i, tiles: int) -> int:
	var step := Vector2i(signi(dir.x), signi(dir.y))
	if step == Vector2i.ZERO or tiles <= 0:
		return 0
	var moved := 0
	for i in tiles:
		var next := u.cell + step
		if not in_bounds(next) or not is_empty(next):
			break
		move_unit(u, next)
		moved += 1
	return moved


func teleport(u: UnitInstance, to: Vector2i) -> bool:
	if not in_bounds(to) or not is_empty(to):
		return false
	return move_unit(u, to)


func configure_merges(pool: Array[UnitData], seed_value: int) -> void:
	merge_pool = pool
	team_merge_pools.clear()
	merge_rng.seed = seed_value


func set_team_pool(team: int, pool: Array[UnitData]) -> void:
	team_merge_pools[team] = pool


func pool_for(team: int) -> Array[UnitData]:
	var own: Array[UnitData] = team_merge_pools.get(team, [] as Array[UnitData])
	return own if not own.is_empty() else merge_pool


static func at_tier(base: UnitData, tier: int) -> UnitData:
	var cur := base
	while cur != null and cur.tier < tier:
		cur = cur.next_tier
	return cur if cur != null and cur.tier == tier else null


func roll_merge_result(from: UnitData, team: int = -1) -> UnitData:
	var target := from.tier + 1
	var pool := pool_for(team)
	if pool.is_empty():
		return from.next_tier
	var pick: UnitData = pool[merge_rng.randi_range(0, pool.size() - 1)]
	var out := at_tier(pick, target)
	return out if out != null else from.next_tier


func set_wild_merge(team: int, enabled: bool) -> void:
	wild_merge_teams[team] = enabled


func wild_merge_for(team: int) -> bool:
	return bool(wild_merge_teams.get(team, false))


func can_merge(a: UnitInstance, b: UnitInstance) -> bool:
	if a == null or b == null or a == b:
		return false
	if a.team != b.team or a.data.is_max_tier():
		return false
	if a.data == b.data:
		return true
	if a.data.tier != b.data.tier:
		return false
	return (wild_merge_for(a.team) or a.data.wild_merge or b.data.wild_merge)


static func magnet_of(a: UnitInstance, b: UnitInstance) -> UnitInstance:
	if a != null and a.data.merge_magnet:
		return a
	if b != null and b.data.merge_magnet:
		return b
	return null


func merge(a: UnitInstance, b: UnitInstance, at: Vector2i) -> UnitInstance:
	if not can_merge(a, b):
		return null
	var inherited: Array[StatModifier] = []
	if MERGE_INHERITS_BUFFS:
		inherited.append_array(a.modifiers)
		inherited.append_array(b.modifiers)
	var magnet := magnet_of(a, b)
	var next := (magnet.data.next_tier if magnet != null
		else roll_merge_result(a.data, a.team))
	if next == null:
		return null
	remove(a)
	remove(b)
	a.promote_to(next, inherited)
	_cells[at] = a
	a.cell = at
	a.move_from = at
	_sorted_dirty = true
	_roll_merge_procs(a)
	return a


func _roll_merge_procs(merged: UnitInstance) -> void:
	# Counts and lists, not flags. Holding the same proc buff at two rarities is
	# two independent rolls, so both can land on one merge.
	var extras: Array[UnitInstance] = []
	last_merge_procs = {extra_tiers = 0, extra_units = extras}
	var tb: TeamBuffs = team_buffs.get(merged.team, null)
	if tb == null:
		return
	for chance in tb.merge_extra_tier_chances():
		# Checked inside the loop, not before it: the first promotion can be what
		# puts the unit at max tier, and the second roll must see that.
		if merged.data.is_max_tier():
			break
		if chance > 0.0 and merge_rng.randf() < chance:
			merged.promote_to(merged.data.next_tier, [] as Array[StatModifier])
			last_merge_procs.extra_tiers = int(last_merge_procs.extra_tiers) + 1
	tb.apply_to(merged)
	for chance in tb.merge_extra_unit_chances():
		if chance <= 0.0 or merge_rng.randf() >= chance:
			continue
		# _summon_extra returns null when the board is full, and a second roll
		# landing on a full board is simply nothing — not an error, and not a
		# null in the list for the view to trip over.
		var made := _summon_extra(merged.team, tb)
		if made != null:
			extras.append(made)


func _summon_extra(team: int, tb: TeamBuffs) -> UnitInstance:
	var pool := pool_for(team)
	if pool.is_empty():
		return null
	var free := free_deploy_cells(team)
	if free.is_empty():
		return null
	var pick: UnitData = pool[merge_rng.randi_range(0, pool.size() - 1)]
	var u := UnitInstance.create(pick, team)
	tb.apply_to(u)
	var cell: Vector2i = free[merge_rng.randi_range(0, free.size() - 1)]
	if not place(u, cell):
		return null
	return u


func units_in_box(from: Vector2i, r: int, team: int = -1) -> Array[UnitInstance]:
	var out: Array[UnitInstance] = []
	for u in units_view():
		if not u.is_alive():
			continue
		if team >= 0 and u.team != team:
			continue
		var d := u.cell - from
		if absi(d.x) <= r and absi(d.y) <= r:
			out.append(u)
	return out


func units_in_range(from: Vector2i, r: int, team: int = -1) -> Array[UnitInstance]:
	var out: Array[UnitInstance] = []
	for u in units_view():
		if not u.is_alive():
			continue
		if team >= 0 and u.team != team:
			continue
		if tile_distance(from, u.cell) <= r:
			out.append(u)
	return out


func nearest_enemy(u: UnitInstance) -> UnitInstance:
	var best: UnitInstance = null
	var best_d := 1 << 30
	for other in units_view():
		if not other.is_alive() or other.team == u.team or other.is_hidden():
			continue
		var d := tile_distance(u.cell, other.cell)
		if d < best_d or (d == best_d and best != null and other.uid < best.uid):
			best = other
			best_d = d
	return best


func _ascii_terrain(c: Vector2i) -> String:
	if is_void(c):
		return " "
	if is_wall(c):
		return "#"
	if is_high(c):
		return "^"
	if is_stairs(c):
		return "/"
	return "~" if is_neutral(c) else "."


func to_ascii() -> String:
	var lines: PackedStringArray = []
	lines.append("   " + " ".join(PackedStringArray(range(WIDTH).map(func(x: int) -> String: return str(x)))))
	for y in HEIGHT:
		var row: PackedStringArray = []
		for x in WIDTH:
			var u := unit_at(Vector2i(x, y))
			if u == null:
				row.append(_ascii_terrain(Vector2i(x, y)))
			else:
				var glyph := String(u.data.id).substr(0, 1)
				row.append(glyph.to_upper() if u.team == TEAM_A else glyph.to_lower())
		var marker := "-" if is_neutral(Vector2i(0, y)) else " "
		lines.append("%s%2d %s" % [marker, y, " ".join(row)])
	return "\n".join(lines)
