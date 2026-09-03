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
static var _edges: Dictionary = {}

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
	_edges = m.edge_keys()
	for y in HEIGHT:
		for x in WIDTH:
			var c := Vector2i(x, y)
			if m.is_wall(c):
				_walls[c] = true
			elif m.is_void(c):
				_voids[c] = true
			elif m.is_high(c):
				_high[c] = true


static func reset_map() -> void:
	WIDTH = DEFAULT_WIDTH
	HEIGHT = DEFAULT_HEIGHT
	HAS_NEUTRAL = true
	NEUTRAL_ROW = DEFAULT_HEIGHT / 2
	map_name = "Standard"
	_walls = {}
	_voids = {}
	_high = {}
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
	return _walls.has(c)


static func is_void(c: Vector2i) -> bool:
	return _voids.has(c)


static func is_high(c: Vector2i) -> bool:
	return _high.has(c)


static func is_blocked(c: Vector2i) -> bool:
	return _walls.has(c) or _voids.has(c)


static func is_playable(c: Vector2i) -> bool:
	return (c.x >= 0 and c.x < WIDTH and c.y >= 0 and c.y < HEIGHT
		and not is_blocked(c))


static func blocks_sight(c: Vector2i) -> bool:
	# Solid walls stop a shot. Holes in the board do not — you can fire across a
	# gap, you just cannot stand in it. Barriers are waist-high: they stop bodies
	# and nothing else.
	return _walls.has(c)


static func line_of_fire(from: Vector2i, to: Vector2i) -> bool:
	if from == to or _walls.is_empty():
		return true
	# Walk the line from a fixed end, so "A can shoot B" and "B can shoot A" can
	# never disagree over a tie.
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
		if c != a and c != b and blocks_sight(c):
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
		and _high.is_empty() and _edges.is_empty())


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
	last_merge_procs = {extra_tier = false, extra_unit = null}
	var tb: TeamBuffs = team_buffs.get(merged.team, null)
	if tb == null:
		return
	var tier_chance := tb.merge_extra_tier_chance()
	if tier_chance > 0.0 and merge_rng.randf() < tier_chance \
			and not merged.data.is_max_tier():
		merged.promote_to(merged.data.next_tier, [] as Array[StatModifier])
		last_merge_procs.extra_tier = true
	tb.apply_to(merged)
	var unit_chance := tb.merge_extra_unit_chance()
	if unit_chance > 0.0 and merge_rng.randf() < unit_chance:
		last_merge_procs.extra_unit = _summon_extra(merged.team, tb)


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
