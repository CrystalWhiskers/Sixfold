## The 6x11 grid as pure data. No nodes, no drawing, no engine dependencies
## beyond Vector2i — which is why the whole game can be simulated headless.
##
## Row 5 is neutral: nobody deploys there, everybody has to cross it.
## Because HEIGHT is odd, mirror() maps that row to itself, so a mirror matchup
## is exactly symmetric. That makes it a reliable balance canary — if a mirror
## matchup doesn't sit near 50%, you have a bug, not a tuning problem.
class_name BoardModel
extends RefCounted

const WIDTH := 6
const HEIGHT := 11
const NEUTRAL_ROW := HEIGHT / 2  ## Integer division -> 5.

const TEAM_A := 0  ## Deploys rows 0..4 (top).
const TEAM_B := 1  ## Deploys rows 6..10 (bottom).

## Diagonals count as distance 1. Flip this and DIAGONAL_MOVEMENT together if you
## want strict lanes instead — on a 6-wide board it changes the feel a lot.
const DIAGONAL_MOVEMENT := true

## Whether a merged unit keeps the modifiers its two inputs were carrying.
## Balance decision, deliberately surfaced as a constant:
##   false — merging is a clean reset; buffs are a reason NOT to merge.
##   true  — merging compounds; buffed units snowball.
const MERGE_INHERITS_BUFFS := false

var _cells: Dictionary = {}  ## Vector2i -> UnitInstance
var _sorted: Array[UnitInstance] = []  ## all_units() cache, uid order.
var _sorted_dirty := true

## The merge lottery. Two identical units still merge, but WHAT comes out is
## drawn at random from this pool at one tier up — two Wardens can hand you an
## Archer II. Set it to the loadout's tier-1 units via configure_merges().
##
## Leave it empty and merging falls back to deterministic promotion along
## next_tier, which is what the tests for the merge chain rely on.
var merge_pool: Array[UnitData] = []
var merge_rng := RandomNumberGenerator.new()


# ---------------------------------------------------------------- queries

func in_bounds(c: Vector2i) -> bool:
	return c.x >= 0 and c.x < WIDTH and c.y >= 0 and c.y < HEIGHT


func is_neutral(c: Vector2i) -> bool:
	return c.y == NEUTRAL_ROW


func is_empty(c: Vector2i) -> bool:
	return in_bounds(c) and not _cells.has(c)


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


## A SNAPSHOT, safe to hold while the board changes underneath you.
##
## The sort is cached, so this is cheap; the duplicate() is what makes it safe.
## Returning the cache itself was a real bug: the sim held the array, units died,
## the cache rebuilt shorter, and the sim's indices ran off the end.
func all_units() -> Array[UnitInstance]:
	_ensure_sorted()
	return _sorted.duplicate()


## The LIVE cache, for hot read-only loops inside one tick.
## Never hold the result across anything that adds or removes a unit.
func units_view() -> Array[UnitInstance]:
	_ensure_sorted()
	return _sorted


## Counts without allocating. _check_over() runs every tick.
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


## Chebyshev when diagonals are allowed, Manhattan otherwise.
## Attack ranges are expressed in this same metric.
static func tile_distance(a: Vector2i, b: Vector2i) -> int:
	var d := (a - b).abs()
	if DIAGONAL_MOVEMENT:
		return maxi(d.x, d.y)
	return d.x + d.y


## Exact, because HEIGHT is odd: the neutral row maps onto itself.
static func mirror(c: Vector2i) -> Vector2i:
	return Vector2i(c.x, HEIGHT - 1 - c.y)


static func enemy_of(team: int) -> int:
	return TEAM_B if team == TEAM_A else TEAM_A


# ---------------------------------------------------------------- deployment

func can_deploy(team: int, c: Vector2i) -> bool:
	if not in_bounds(c) or is_neutral(c):
		return false
	return (c.y < NEUTRAL_ROW) == (team == TEAM_A)


func deploy_cells(team: int) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	var rows := range(0, NEUTRAL_ROW) if team == TEAM_A else range(NEUTRAL_ROW + 1, HEIGHT)
	for y in rows:
		for x in WIDTH:
			out.append(Vector2i(x, y))
	return out


func free_deploy_cells(team: int) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	for c in deploy_cells(team):
		if is_empty(c):
			out.append(c)
	return out


# ---------------------------------------------------------------- mutation

func clear() -> void:
	_cells.clear()
	_sorted_dirty = true


## Prep-phase placement. Enforces deploy zones.
func place(u: UnitInstance, c: Vector2i) -> bool:
	if not can_deploy(u.team, c) or not is_empty(c):
		return false
	_cells[c] = u
	u.cell = c
	u.move_from = c
	_sorted_dirty = true
	return true


## Combat placement. Ignores deploy zones — units cross the neutral row.
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


## Moves a unit to an empty tile. Used by both drag-and-drop and the sim.
func move_unit(u: UnitInstance, to: Vector2i) -> bool:
	if not in_bounds(to) or not is_empty(to):
		return false
	remove(u)
	_cells[to] = u
	u.cell = to
	_sorted_dirty = true
	return true


## Prep-phase drag onto an occupied tile: the two units trade places.
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


# ---------------------------------------------------------------- merging

## Turns on the merge lottery. `pool` should be the tier-1 units of the loadout.
func configure_merges(pool: Array[UnitData], seed_value: int) -> void:
	merge_pool = pool
	merge_rng.seed = seed_value


## The UnitData in `base`'s chain at the given tier, or null if it doesn't go
## that far.
static func at_tier(base: UnitData, tier: int) -> UnitData:
	var cur := base
	while cur != null and cur.tier < tier:
		cur = cur.next_tier
	return cur if cur != null and cur.tier == tier else null


## Rolls the merge outcome. CONSUMES rng, so call it exactly once per merge —
## never from can_merge(), or the check would change the result.
##
## Assumes every unit in the pool has a chain at least as long as the merging
## unit's; falls back to straight promotion if the roll can't reach the tier.
func roll_merge_result(from: UnitData) -> UnitData:
	var target := from.tier + 1
	if merge_pool.is_empty():
		return from.next_tier
	var pick: UnitData = merge_pool[merge_rng.randi_range(0, merge_pool.size() - 1)]
	var out := at_tier(pick, target)
	return out if out != null else from.next_tier


func can_merge(a: UnitInstance, b: UnitInstance) -> bool:
	if a == null or b == null or a == b:
		return false
	if a.team != b.team:
		return false
	return a.data == b.data and not a.data.is_max_tier()


## Consumes both inputs, returns the merged unit standing on `at`.
## `at` should be the tile the player dropped onto.
##
## What comes out is a roll, not a promotion — see roll_merge_result().
func merge(a: UnitInstance, b: UnitInstance, at: Vector2i) -> UnitInstance:
	if not can_merge(a, b):
		return null
	var inherited: Array[StatModifier] = []
	if MERGE_INHERITS_BUFFS:
		inherited.append_array(a.modifiers)
		inherited.append_array(b.modifiers)
	var next := roll_merge_result(a.data)
	if next == null:
		return null
	remove(a)
	remove(b)
	a.promote_to(next, inherited)
	_cells[at] = a
	a.cell = at
	a.move_from = at
	_sorted_dirty = true
	return a


# ---------------------------------------------------------------- range queries

## Living units within `r` tiles of `from`. Pass team = -1 for either side.
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


## Nearest living enemy. Ties break on uid so the sim stays deterministic —
## never resolve a tie with rng unless the rng is seeded.
func nearest_enemy(u: UnitInstance) -> UnitInstance:
	var best: UnitInstance = null
	var best_d := 1 << 30
	for other in units_view():
		if not other.is_alive() or other.team == u.team:
			continue
		var d := tile_distance(u.cell, other.cell)
		if d < best_d or (d == best_d and best != null and other.uid < best.uid):
			best = other
			best_d = d
	return best


# ---------------------------------------------------------------- debugging

## Dump the board to the Output panel. Build this early and trust it over the
## screen — if the ASCII and the visuals disagree, the visuals are wrong.
func to_ascii() -> String:
	var lines: PackedStringArray = []
	lines.append("   " + " ".join(PackedStringArray(range(WIDTH).map(func(x: int) -> String: return str(x)))))
	for y in HEIGHT:
		var row: PackedStringArray = []
		for x in WIDTH:
			var u := unit_at(Vector2i(x, y))
			if u == null:
				row.append("~" if y == NEUTRAL_ROW else ".")
			else:
				var glyph := String(u.data.id).substr(0, 1)
				row.append(glyph.to_upper() if u.team == TEAM_A else glyph.to_lower())
		var marker := "-" if y == NEUTRAL_ROW else " "
		lines.append("%s%2d %s" % [marker, y, " ".join(row)])
	return "\n".join(lines)
