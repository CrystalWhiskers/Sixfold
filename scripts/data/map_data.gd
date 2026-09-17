class_name MapData
extends Resource

## Terrain glyphs, one character per tile, top row first.
const OPEN := "."
const WALL := "#"
const VOID := "X"
const HIGH := "^"

## Stone a Sapper can chew through. It behaves exactly like WALL for movement,
## sight and deployment — the only difference is that it can stop existing
## mid-battle. A map that wants some walls to be permanent uses WALL for those,
## which is why this is a second glyph rather than a flag on the first.
const RUBBLE := "%"

## The only way onto high ground on foot. An ordinary tile in every other
## respect — you can stand on it, shoot from it and be hit on it exactly as if it
## were open ground — but a unit may only step ONTO a HIGH tile from a STAIRS
## tile or from another HIGH one. Without a set of these, a plateau is scenery.
const STAIRS := "/"

## A gate. Ordinary ground in every respect — you stand on it, shoot from it and are
## hit on it like anywhere else — except that a unit which steps onto it is standing
## on the OTHER gate instead.
##
## Gates come in pairs and the pairing is positional, not written down: a map's gates
## are matched to their own mirror images, which is the only rule that can hold given
## that every map has to be mirror-symmetric anyway. So a gate in your half always
## leads to the matching tile in theirs, and there is no way to author a pair that is
## unfair or a gate that leads nowhere.
##
## They exist to answer the Spire. A rooted caster behind a wall of its own bodies is
## unreachable on a big board unless you brought an Assassin, and "bring an Assassin
## or lose" is not a decision. A gate is the other answer, and unlike the Assassin it
## is on the map rather than in the loadout — so it is a reason to pick a board.
const GATE := "O"

const GLYPHS := ".#X^%/O"

@export var id: StringName = &""
@export var display_name: String = "Map"

## Where this map sits in the picker. Files load alphabetically, which buries
## Standard in the middle of the list, so the builder stamps the table's own
## order here and the menu sorts by it.
@export var rank: int = 0
@export var width: int = 6
@export var height: int = 11

## A neutral row down the middle that nobody can deploy into. Only works on an
## odd height — an even board splits evenly on its own and needs no divider.
@export var has_neutral: bool = true

## One string per row. Empty means a plain open rectangle.
@export var rows: PackedStringArray = []

## Walls that sit on the line between two tiles rather than on a tile: nothing
## can step across, but both tiles stay usable. Packed as (ax, ay, bx, by).
@export var lines: Array[Vector4i] = []

@export_multiline var note: String = ""


func half_rows() -> int:
	return height / 2


func tiles() -> int:
	return width * height


func glyph(c: Vector2i) -> String:
	if c.y < 0 or c.y >= rows.size():
		return OPEN
	var row := rows[c.y]
	if c.x < 0 or c.x >= row.length():
		return OPEN
	return row[c.x]


func is_wall(c: Vector2i) -> bool:
	var g := glyph(c)
	return g == WALL or g == RUBBLE


func is_breakable(c: Vector2i) -> bool:
	return glyph(c) == RUBBLE


func is_void(c: Vector2i) -> bool:
	return glyph(c) == VOID


func is_high(c: Vector2i) -> bool:
	return glyph(c) == HIGH


func is_stairs(c: Vector2i) -> bool:
	return glyph(c) == STAIRS


func is_gate(c: Vector2i) -> bool:
	return glyph(c) == GATE


func gate_pairs() -> Dictionary:
	## Every gate mapped to the tile a unit standing on it arrives at.
	##
	## Paired by mirror image, and a gate whose mirror is not also a gate is dropped
	## rather than guessed at — is_valid() refuses such a map, so this never has to
	## invent a destination. A gate on the centre line would pair with itself, which
	## is a gate that does nothing; those are dropped too.
	var out := {}
	for y in height:
		for x in width:
			var c := Vector2i(x, y)
			if not is_gate(c):
				continue
			var other := mirror(c)
			if other == c or not is_gate(other):
				continue
			out[c] = other
	return out


func blocked(c: Vector2i) -> bool:
	var g := glyph(c)
	return g == WALL or g == VOID or g == RUBBLE


func mirror(c: Vector2i) -> Vector2i:
	return Vector2i(c.x, height - 1 - c.y)


static func edge_key(a: Vector2i, b: Vector2i) -> String:
	# Order-free, so a wall reads the same from either side of it.
	if b.y < a.y or (b.y == a.y and b.x < a.x):
		return "%d,%d|%d,%d" % [b.x, b.y, a.x, a.y]
	return "%d,%d|%d,%d" % [a.x, a.y, b.x, b.y]


func edge_keys() -> Dictionary:
	var out := {}
	for e in lines:
		out[edge_key(Vector2i(e.x, e.y), Vector2i(e.z, e.w))] = true
	return out


func playable_cells(first_row: int, last_row: int) -> int:
	var n := 0
	for y in range(first_row, last_row):
		for x in width:
			if not blocked(Vector2i(x, y)):
				n += 1
	return n


func half_tiles() -> int:
	# What a side can actually deploy onto, which is not width x rows once the
	# map has holes in it.
	return playable_cells(0, half_rows())


func shape() -> String:
	return "%d x %d" % [width, height]


func has_terrain() -> bool:
	return not rows.is_empty() or not lines.is_empty()


func summary() -> String:
	var parts: PackedStringArray = [shape()]
	parts.append("divided" if has_neutral else "no divider")
	parts.append("%d tiles a side" % half_tiles())
	return "  ·  ".join(parts)


func terrain_note() -> String:
	var counts := {WALL: 0, VOID: 0, HIGH: 0, RUBBLE: 0, STAIRS: 0}
	for y in height:
		for x in width:
			var g := glyph(Vector2i(x, y))
			if counts.has(g):
				counts[g] += 1
	var parts: PackedStringArray = []
	if counts[VOID] > 0:
		parts.append("%d tiles missing" % counts[VOID])
	if counts[WALL] > 0:
		parts.append("%d walls" % counts[WALL])
	if not lines.is_empty():
		parts.append("%d barriers" % lines.size())
	if counts[RUBBLE] > 0:
		parts.append("%d breakable" % counts[RUBBLE])
	if counts[HIGH] > 0:
		parts.append("%d high ground" % counts[HIGH])
	if counts[STAIRS] > 0:
		parts.append("%d stairs" % counts[STAIRS])
	return ", ".join(parts)


func invalid_reason() -> String:
	if width < 2 or height < 4:
		return "%s is too small to play on" % shape()
	# The divider is what makes an odd board fair, and its absence is what makes
	# an even one fair. Any other combination hands one side an extra row.
	if has_neutral != (height % 2 == 1):
		return "a %s board %s a divider gives one side an extra row" % [
			"odd" if height % 2 == 1 else "even",
			"with" if has_neutral else "without"]

	if not rows.is_empty():
		if rows.size() != height:
			return "%d terrain rows for a board %d tall" % [rows.size(), height]
		for y in height:
			if rows[y].length() != width:
				return "row %d is %d wide, the board is %d" % [
					y, rows[y].length(), width]
			for x in width:
				if not GLYPHS.contains(rows[y][x]):
					return "row %d uses '%s', which is not terrain" % [y, rows[y][x]]

	# Both halves must be the same board upside down, or one side is handed a
	# better position before a single unit is placed.
	for y in height:
		for x in width:
			var c := Vector2i(x, y)
			if glyph(c) != glyph(mirror(c)):
				return "%s and %s do not match — the halves are not mirrors" % [
					c, mirror(c)]

	var keys := edge_keys()
	for e in lines:
		var a := Vector2i(e.x, e.y)
		var b := Vector2i(e.z, e.w)
		if not _on_board(a) or not _on_board(b):
			return "a barrier runs off the board at %s-%s" % [a, b]
		if (absi(a.x - b.x) + absi(a.y - b.y)) != 1:
			return "%s and %s are not neighbours, so nothing sits between them" % [a, b]
		if blocked(a) and blocked(b):
			return "a barrier at %s-%s sits between two tiles nobody can reach" % [a, b]
		if not keys.has(edge_key(mirror(a), mirror(b))):
			return "the barrier at %s-%s has no mirror on the other half" % [a, b]

	# A gate is a link between the two halves, so one that mirrors onto itself links
	# nothing. It cannot happen on an even board — there is no self-mirroring row —
	# but the check costs nothing and the alternative is a tile that silently does
	# not work.
	for y in height:
		for x in width:
			var c := Vector2i(x, y)
			if is_gate(c) and mirror(c) == c:
				return "the gate at %s is its own mirror, so it leads nowhere" % c

	if half_tiles() < 8:
		return "only %d usable tiles a side" % half_tiles()
	return ""


func is_valid() -> bool:
	return invalid_reason().is_empty()


func _on_board(c: Vector2i) -> bool:
	return c.x >= 0 and c.x < width and c.y >= 0 and c.y < height
