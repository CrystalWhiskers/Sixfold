class_name AbilityFx
extends Node2D

## What an ability looked like, drawn over the units.
##
## Every ability in the game ends in a label, a flashed tile, or nothing, and a label
## says THAT something happened without saying what or to whom. This layer is the what:
## a small icon for each ability that pops over the unit it happened to — a shield over
## the Warden, a spear over the Lancer — and, where the ability has a shape, the shape
## itself: the lance running through everything it pierced, the horn's ring going out,
## the siphon's tether from victim to drinker.
##
## A separate node rather than more drawing in BoardView, because BoardView's own
## drawing sits UNDER the unit views (a child always renders above its parent) and an
## icon hidden behind the unit it belongs to is no icon at all. `z_index` lifts it
## above its siblings without touching the tiles below.
##
## Purely visual and event-driven. Nothing here reads the simulation; BattlePlayer
## hands it positions in board space, already worked out, and each effect lives for a
## fixed span of playback time and then goes.

## One icon per ability id, and its colour. Keyed by id rather than by kind because
## several abilities share a kind and mean different things — the Pyre's Cinder Lance
## and the Reaver's Execute are both FOCUS_BURST, and a flame over an execution would
## be the wrong answer to "what just happened".
const GLYPHS := {
	&"bulwark_shield": ["shield", Color(0.53, 0.79, 0.95)],
	&"impale": ["spear", Color(0.95, 0.58, 0.42)],
	&"quickdraw": ["chevrons", Color(0.98, 0.85, 0.42)],
	&"blight": ["droplet", Color(0.56, 0.86, 0.38)],
	&"arrest": ["snowflake", Color(0.70, 0.90, 1.00)],
	&"cinder_lance": ["flame", Color(1.00, 0.56, 0.24)],
	&"execute": ["axe", Color(0.92, 0.32, 0.30)],
	&"shadowstep": ["dagger", Color(0.70, 0.52, 0.92)],
	&"war_horn": ["horn", Color(0.95, 0.84, 0.44)],
	&"second_wind": ["wings", Color(0.94, 0.92, 0.70)],
	&"benediction": ["plus", Color(0.48, 0.90, 0.68)],
	&"call_wisp": ["sparkle", Color(0.74, 0.62, 0.96)],
	&"raise_host": ["tower", Color(0.62, 0.78, 0.98)],
	&"assemble": ["gear", Color(0.78, 0.76, 0.66)],
	&"onslaught": ["ram", Color(0.98, 0.64, 0.30)],
	&"usurpation": ["eye", Color(0.72, 0.48, 0.90)],
	&"retribution": ["mirror", Color(0.86, 0.80, 0.98)],
	&"last_stand": ["banner", Color(0.95, 0.40, 0.36)],
	&"lament": ["skull", Color(0.76, 0.84, 0.94)],
	&"gorge": ["fangs", Color(0.86, 0.30, 0.42)],
	&"undermine": ["pick", Color(0.88, 0.74, 0.44)],
	&"bulwark_raise": ["brick", Color(0.70, 0.74, 0.84)],
	&"bombardment": ["crosshair", Color(1.00, 0.68, 0.30)],
	&"siphon": ["siphon", Color(0.82, 0.36, 0.62)],
	&"vertigo": ["spiral", Color(0.92, 0.86, 0.50)],
	&"martyrdom": ["heart", Color(1.00, 0.32, 0.30)],
	&"slow_match": ["bomb", Color(1.00, 0.62, 0.22)],
	&"triage": ["plus", Color(0.96, 0.86, 0.62)],
	&"overflow": ["mana", Color(0.46, 0.72, 1.00)],
	&"rally_banner": ["banner", Color(0.95, 0.80, 0.35)],
}

## The fallback for an ability nobody gave an icon: by kind, so a new ability still
## shows SOMETHING the day it is added rather than nothing until someone notices.
const KIND_GLYPHS := {
	AbilityData.Kind.HASTE: "chevrons",
	AbilityData.Kind.SHIELD: "shield",
	AbilityData.Kind.DOT: "droplet",
	AbilityData.Kind.FOCUS_BURST: "flame",
	AbilityData.Kind.PIERCE: "spear",
	AbilityData.Kind.BLINK_STRIKE: "dagger",
	AbilityData.Kind.SPEED_AURA: "horn",
	AbilityData.Kind.REVIVE: "wings",
	AbilityData.Kind.BURST_HEAL: "plus",
	AbilityData.Kind.SUMMON: "sparkle",
	AbilityData.Kind.MANA_AURA: "mana",
	AbilityData.Kind.TAUNT: "banner",
	AbilityData.Kind.REFLECT: "mirror",
	AbilityData.Kind.RAISE: "skull",
	AbilityData.Kind.ASCEND: "fangs",
	AbilityData.Kind.SAP: "pick",
	AbilityData.Kind.BUILD: "brick",
	AbilityData.Kind.SHELL: "crosshair",
	AbilityData.Kind.DRAIN: "siphon",
	AbilityData.Kind.FREEZE: "snowflake",
	AbilityData.Kind.CHARGE: "ram",
	AbilityData.Kind.POSSESS: "eye",
	AbilityData.Kind.FRENZY: "heart",
	AbilityData.Kind.DISORIENT: "spiral",
	AbilityData.Kind.MEND: "plus",
	AbilityData.Kind.FUSE: "bomb",
	AbilityData.Kind.BANNER: "banner",
}

## Every shape _draw_shape knows how to draw. The tests hold the tables above to it.
const SHAPES := [
	"shield", "spear", "chevrons", "droplet", "snowflake", "flame", "axe", "dagger",
	"horn", "wings", "plus", "sparkle", "tower", "gear", "ram", "eye", "mirror",
	"banner", "skull", "fangs", "pick", "brick", "crosshair", "siphon", "spiral",
	"heart", "bomb", "mana", "star",
]

const GLYPH_LIFE := 0.95
const OUTLINE := Color(0.04, 0.05, 0.08, 0.92)
const BADGE := Color(0.06, 0.08, 0.12, 0.78)

var tile_size := 64.0
var _fx: Array[Dictionary] = []


func _init() -> void:
	z_index = 20
	set_process(false)


static func glyph_for(id: StringName, kind: int) -> String:
	## The icon for an ability, by id first and by kind when the id has none.
	var row: Array = GLYPHS.get(id, [])
	if not row.is_empty():
		return String(row[0])
	return String(KIND_GLYPHS.get(kind, "star"))


static func color_for(id: StringName) -> Color:
	var row: Array = GLYPHS.get(id, [])
	if not row.is_empty():
		return row[1]
	return Color(0.98, 0.85, 0.42)


static func glyph_of(ab: AbilityData) -> String:
	if ab == null:
		return "star"
	return glyph_for(ab.id, ab.kind)


static func color_of(ab: AbilityData) -> Color:
	if ab == null:
		return color_for(&"")
	return color_for(ab.id)


func count() -> int:
	return _fx.size()


func clear() -> void:
	_fx.clear()
	set_process(false)
	queue_redraw()


# --- spawning ---------------------------------------------------------------------
#
# Positions are in pixels, in this node's own space — the same space BoardView's
# children live in. `follow` is an optional UnitView whose position replaces `pos`
# every frame, so an icon over a unit that is walking stays over it.

func glyph(shape: String, pos: Vector2, color: Color, life := GLYPH_LIFE,
		follow: Node2D = null, big := false) -> void:
	_add({type = "glyph", shape = shape, pos = pos, color = color,
		follow = follow, big = big}, life)


func lance(from: Vector2, to: Vector2, color: Color, life := 0.55) -> void:
	## A spear thrown along a line, running through everything on it and a little past.
	var dir := to - from
	if dir.length() < 0.01:
		return
	var past := to + dir.normalized() * tile_size * 0.6
	_add({type = "lance", from = from, to = past, color = color}, life)


func ring(pos: Vector2, from_r: float, to_r: float, color: Color, life := 0.6) -> void:
	_add({type = "ring", pos = pos, r0 = from_r, r1 = to_r, color = color}, life)


func tether(a: Vector2, b: Vector2, color: Color, life := 0.7,
		follow_a: Node2D = null, follow_b: Node2D = null) -> void:
	## A beam between two units that flows from `a` to `b`: what was taken and where
	## it went, for the siphon, the heal and the possession.
	_add({type = "tether", a = a, b = b, color = color,
		follow_a = follow_a, follow_b = follow_b}, life)


func streak(from: Vector2, to: Vector2, color: Color, life := 0.4) -> void:
	## An afterimage from one tile to another, for anything that moved too fast to
	## be seen moving — the Assassin's step, the end of a charge.
	_add({type = "streak", from = from, to = to, color = color}, life)


func impact(pos: Vector2, color: Color, life := 0.35) -> void:
	## A starburst where something connected.
	_add({type = "impact", pos = pos, color = color}, life)


func _add(fx: Dictionary, life: float) -> void:
	fx.left = maxf(life, 0.05)
	fx.total = fx.left
	_fx.append(fx)
	set_process(true)
	queue_redraw()


func _process(delta: float) -> void:
	var i := _fx.size() - 1
	while i >= 0:
		_fx[i].left -= delta
		if _fx[i].left <= 0.0:
			_fx.remove_at(i)
		i -= 1
	if _fx.is_empty():
		set_process(false)
	queue_redraw()


static func _where(fx: Dictionary, key: String, follow_key: String) -> Vector2:
	var node: Variant = fx.get(follow_key, null)
	if node != null and is_instance_valid(node):
		return (node as Node2D).position
	return fx[key]


# --- drawing ----------------------------------------------------------------------

func _draw() -> void:
	for fx in _fx:
		var t: float = 1.0 - clampf(fx.left / fx.total, 0.0, 1.0)
		match String(fx.type):
			"glyph":
				_draw_glyph(fx, t)
			"lance":
				_draw_lance(fx, t)
			"ring":
				_draw_ring(fx, t)
			"tether":
				_draw_tether(fx, t)
			"streak":
				_draw_streak(fx, t)
			"impact":
				_draw_impact(fx, t)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


func _draw_glyph(fx: Dictionary, t: float) -> void:
	# Pops in a touch oversized, settles, then rises and fades over its last half.
	# Fast in, slow out: you need to SEE it arrive and have time to read it.
	var pop := 1.0
	if t < 0.08:
		pop = lerpf(0.4, 1.25, t / 0.08)
	elif t < 0.2:
		pop = lerpf(1.25, 1.0, (t - 0.08) / 0.12)
	var fade: float = 1.0 if t < 0.5 else clampf(1.0 - (t - 0.5) / 0.5, 0.0, 1.0)
	var base := _where(fx, "pos", "follow")
	# On the body rather than above it: above is where the health bar and the floating
	# labels live, and an icon there hid both.
	var at := base + Vector2(0.0, -tile_size * (0.04 + 0.12 * t))
	var r := tile_size * (0.26 if bool(fx.get("big", false)) else 0.2) * pop
	var col: Color = fx.color
	col.a = fade
	var badge := BADGE
	badge.a *= fade
	draw_circle(at, r * 1.32, badge)
	draw_arc(at, r * 1.32, 0.0, TAU, 28, Color(col, 0.85 * fade), maxf(r * 0.12, 1.5))
	draw_set_transform(at, 0.0, Vector2(r, r))
	_draw_shape(String(fx.shape), col, fade, r)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


func _draw_lance(fx: Dictionary, t: float) -> void:
	# The head covers the whole line in the first 60%, then the shaft hangs there and
	# fades, so the line it took is still readable after it has gone through.
	var from: Vector2 = fx.from
	var to: Vector2 = fx.to
	var run: float = clampf(t / 0.6, 0.0, 1.0)
	run = 1.0 - (1.0 - run) * (1.0 - run)
	var fade: float = 1.0 if t < 0.6 else clampf(1.0 - (t - 0.6) / 0.4, 0.0, 1.0)
	var dir := (to - from).normalized()
	var head := from.lerp(to, run)
	var shaft := tile_size * 0.85
	var tail := head - dir * shaft
	if (tail - from).dot(dir) < 0.0:
		tail = from
	var col: Color = fx.color
	# The wake: everything the head has already passed through.
	draw_line(from, head, Color(col, 0.35 * fade), tile_size * 0.05)
	draw_line(tail, head, Color(OUTLINE, fade), tile_size * 0.11)
	draw_line(tail, head, Color(0.86, 0.78, 0.62, fade), tile_size * 0.06)
	var side := Vector2(-dir.y, dir.x)
	var tip := head + dir * tile_size * 0.26
	var barb := head - dir * tile_size * 0.04
	var pts := PackedVector2Array([tip, barb + side * tile_size * 0.12,
		head + dir * tile_size * 0.02, barb - side * tile_size * 0.12])
	draw_colored_polygon(pts, Color(col, fade))
	pts.append(tip)
	draw_polyline(pts, Color(OUTLINE, fade), 2.0)


func _draw_ring(fx: Dictionary, t: float) -> void:
	var ease_t: float = 1.0 - (1.0 - t) * (1.0 - t)
	var r: float = lerpf(float(fx.r0), float(fx.r1), ease_t)
	var col: Color = fx.color
	var a: float = 1.0 - t
	draw_arc(fx.pos, r, 0.0, TAU, 48, Color(col, 0.85 * a), maxf(tile_size * 0.07 * a, 1.5))
	draw_circle(fx.pos, r, Color(col, 0.10 * a))


func _draw_tether(fx: Dictionary, t: float) -> void:
	var a := _where(fx, "a", "follow_a")
	var b := _where(fx, "b", "follow_b")
	var col: Color = fx.color
	var fade: float = 1.0 if t < 0.6 else clampf(1.0 - (t - 0.6) / 0.4, 0.0, 1.0)
	draw_line(a, b, Color(col, 0.35 * fade), tile_size * 0.12)
	draw_line(a, b, Color(col, 0.9 * fade), tile_size * 0.035)
	# Beads running from a to b, so the direction of flow is readable at a glance.
	for k in 3:
		var p: float = fmod(t * 2.2 + float(k) / 3.0, 1.0)
		draw_circle(a.lerp(b, p), tile_size * 0.06, Color(1, 1, 1, 0.85 * fade))


func _draw_streak(fx: Dictionary, t: float) -> void:
	var col: Color = fx.color
	var a: float = 1.0 - t
	var from: Vector2 = fx.from
	var to: Vector2 = fx.to
	draw_line(from, to, Color(col, 0.25 * a), tile_size * 0.42 * a + 2.0)
	draw_line(from, to, Color(col, 0.7 * a), tile_size * 0.08)
	for k in 3:
		draw_circle(from.lerp(to, float(k) / 3.0), tile_size * 0.16 * a,
			Color(col, 0.25 * a))


func _draw_impact(fx: Dictionary, t: float) -> void:
	var col: Color = fx.color
	var a: float = 1.0 - t
	var r: float = tile_size * (0.18 + 0.32 * t)
	for k in 8:
		var ang := float(k) * TAU / 8.0 + 0.2
		var d := Vector2(cos(ang), sin(ang))
		draw_line(fx.pos + d * r * 0.45, fx.pos + d * r, Color(col, a), maxf(4.0 * a, 1.5))


# --- the icons --------------------------------------------------------------------
#
# Drawn in a unit box: the transform is already centred on the icon and scaled so 1.0
# is its radius. Line widths are therefore given in units and divided back by `r`
# where a real pixel width is wanted. Each one is a fill in the ability's colour with
# a dark edge, so it reads over any portrait and on either team's tiles.

func _poly(pts: PackedVector2Array, col: Color, fade: float, r: float) -> void:
	draw_colored_polygon(pts, col)
	var ring := pts.duplicate()
	ring.append(pts[0])
	draw_polyline(ring, Color(OUTLINE, fade), 2.0 / r)


func _stroke(pts: PackedVector2Array, col: Color, fade: float, r: float, w := 0.16) -> void:
	draw_polyline(pts, Color(OUTLINE, fade), w + 3.0 / r)
	draw_polyline(pts, col, w)


func _dot(at: Vector2, rad: float, col: Color, fade: float, r: float) -> void:
	draw_circle(at, rad + 1.5 / r, Color(OUTLINE, fade))
	draw_circle(at, rad, col)


func _draw_shape(shape: String, col: Color, fade: float, r: float) -> void:
	var dark := Color(OUTLINE, fade)
	match shape:
		"shield":
			_poly(PackedVector2Array([Vector2(-0.7, -0.75), Vector2(0.7, -0.75),
				Vector2(0.7, -0.05), Vector2(0.0, 0.85), Vector2(-0.7, -0.05)]), col, fade, r)
			draw_line(Vector2(0.0, -0.6), Vector2(0.0, 0.6), dark, 0.12)
			draw_line(Vector2(-0.55, -0.2), Vector2(0.55, -0.2), dark, 0.12)
		"spear":
			_stroke(PackedVector2Array([Vector2(-0.75, 0.75), Vector2(0.3, -0.3)]), col, fade, r, 0.18)
			_poly(PackedVector2Array([Vector2(0.8, -0.8), Vector2(0.45, -0.1),
				Vector2(0.25, -0.25), Vector2(0.1, -0.45)]), col, fade, r)
		"chevrons":
			for k in 2:
				var x := -0.45 + 0.5 * float(k)
				_stroke(PackedVector2Array([Vector2(x - 0.2, -0.55), Vector2(x + 0.25, 0.0),
					Vector2(x - 0.2, 0.55)]), col, fade, r, 0.22)
		"droplet", "mana", "siphon":
			_poly(_droplet(), col, fade, r)
			if shape == "mana":
				draw_colored_polygon(_star(Vector2(0.0, 0.25), 0.32, 0.1, 4), Color(1, 1, 1, fade))
			elif shape == "siphon":
				# A drop of blood being drawn OUT: an arrow up through it.
				draw_line(Vector2(0.0, 0.6), Vector2(0.0, -0.2), Color(1, 1, 1, fade), 0.14)
				draw_colored_polygon(PackedVector2Array([Vector2(0.0, -0.45),
					Vector2(0.25, -0.12), Vector2(-0.25, -0.12)]), Color(1, 1, 1, fade))
			else:
				draw_circle(Vector2(-0.15, 0.3), 0.12, Color(1, 1, 1, 0.6 * fade))
		"snowflake":
			for k in 3:
				var ang := float(k) * PI / 3.0 + PI / 2.0
				var d := Vector2(cos(ang), sin(ang)) * 0.85
				_stroke(PackedVector2Array([-d, d]), col, fade, r, 0.14)
			for k in 6:
				var ang := float(k) * PI / 3.0 + PI / 2.0
				var d := Vector2(cos(ang), sin(ang))
				var s := Vector2(-d.y, d.x) * 0.2
				draw_line(d * 0.55, d * 0.55 + d * 0.15 + s, col, 0.1)
				draw_line(d * 0.55, d * 0.55 + d * 0.15 - s, col, 0.1)
		"flame":
			_poly(PackedVector2Array([Vector2(0.0, -0.9), Vector2(0.35, -0.35),
				Vector2(0.62, 0.1), Vector2(0.5, 0.6), Vector2(0.0, 0.85),
				Vector2(-0.5, 0.6), Vector2(-0.62, 0.1), Vector2(-0.25, -0.2),
				Vector2(-0.2, 0.15), Vector2(0.05, -0.3)]), col, fade, r)
			draw_colored_polygon(PackedVector2Array([Vector2(0.0, -0.1), Vector2(0.28, 0.35),
				Vector2(0.0, 0.62), Vector2(-0.28, 0.35)]), Color(1, 0.95, 0.7, fade))
		"axe":
			_stroke(PackedVector2Array([Vector2(-0.6, 0.85), Vector2(0.35, -0.6)]), Color(0.78, 0.62, 0.42, fade), fade, r, 0.16)
			_poly(PackedVector2Array([Vector2(0.05, -0.55), Vector2(0.55, -0.9),
				Vector2(0.9, -0.3), Vector2(0.55, 0.05), Vector2(0.3, -0.2)]), col, fade, r)
		"dagger":
			_poly(PackedVector2Array([Vector2(0.0, -0.95), Vector2(0.2, -0.65),
				Vector2(0.16, 0.25), Vector2(-0.16, 0.25), Vector2(-0.2, -0.65)]), col, fade, r)
			_stroke(PackedVector2Array([Vector2(-0.5, 0.3), Vector2(0.5, 0.3)]), col, fade, r, 0.16)
			_stroke(PackedVector2Array([Vector2(0.0, 0.35), Vector2(0.0, 0.85)]), Color(0.6, 0.48, 0.36, fade), fade, r, 0.16)
		"horn":
			_poly(PackedVector2Array([Vector2(-0.85, -0.12), Vector2(0.35, -0.6),
				Vector2(0.35, 0.6), Vector2(-0.85, 0.12)]), col, fade, r)
			draw_arc(Vector2(0.4, 0.0), 0.35, -0.9, 0.9, 10, col, 0.1)
			draw_arc(Vector2(0.4, 0.0), 0.6, -0.8, 0.8, 12, col, 0.1)
		"wings":
			_stroke(PackedVector2Array([Vector2(0.0, 0.8), Vector2(0.0, -0.55)]), col, fade, r, 0.2)
			_stroke(PackedVector2Array([Vector2(-0.4, -0.15), Vector2(0.0, -0.6),
				Vector2(0.4, -0.15)]), col, fade, r, 0.2)
			draw_arc(Vector2(0.0, -0.75), 0.35, PI, TAU, 12, col, 0.1)
			_stroke(PackedVector2Array([Vector2(-0.25, 0.4), Vector2(-0.85, 0.0), Vector2(-0.7, 0.55)]), col, fade, r, 0.12)
			_stroke(PackedVector2Array([Vector2(0.25, 0.4), Vector2(0.85, 0.0), Vector2(0.7, 0.55)]), col, fade, r, 0.12)
		"plus":
			_poly(PackedVector2Array([Vector2(-0.22, -0.8), Vector2(0.22, -0.8),
				Vector2(0.22, -0.22), Vector2(0.8, -0.22), Vector2(0.8, 0.22),
				Vector2(0.22, 0.22), Vector2(0.22, 0.8), Vector2(-0.22, 0.8),
				Vector2(-0.22, 0.22), Vector2(-0.8, 0.22), Vector2(-0.8, -0.22),
				Vector2(-0.22, -0.22)]), col, fade, r)
		"sparkle", "star":
			_poly(_star(Vector2.ZERO, 0.9, 0.28, 4), col, fade, r)
			if shape == "sparkle":
				draw_colored_polygon(_star(Vector2(0.6, -0.6), 0.3, 0.1, 4), Color(1, 1, 1, fade))
		"tower":
			_poly(PackedVector2Array([Vector2(0.0, -0.95), Vector2(0.32, -0.55),
				Vector2(0.4, 0.8), Vector2(-0.4, 0.8), Vector2(-0.32, -0.55)]), col, fade, r)
			draw_circle(Vector2(0.0, -0.3), 0.14, Color(1, 1, 1, fade))
		"gear":
			var teeth := PackedVector2Array()
			for k in 16:
				var ang := float(k) * TAU / 16.0
				var rad := 0.85 if k % 2 == 0 else 0.62
				teeth.append(Vector2(cos(ang), sin(ang)) * rad)
			_poly(teeth, col, fade, r)
			draw_circle(Vector2.ZERO, 0.25, dark)
		"ram":
			_poly(PackedVector2Array([Vector2(-0.85, -0.3), Vector2(0.15, -0.3),
				Vector2(0.15, -0.7), Vector2(0.9, 0.0), Vector2(0.15, 0.7),
				Vector2(0.15, 0.3), Vector2(-0.85, 0.3)]), col, fade, r)
		"eye":
			var lid := PackedVector2Array()
			for k in 13:
				var a := PI * float(k) / 12.0
				lid.append(Vector2(-cos(a) * 0.9, -sin(a) * 0.5))
			for k in range(1, 12):
				var a := PI * float(k) / 12.0
				lid.append(Vector2(cos(a) * 0.9, sin(a) * 0.5))
			_poly(lid, col, fade, r)
			_dot(Vector2.ZERO, 0.26, dark, fade, r)
			draw_circle(Vector2(0.08, -0.08), 0.08, Color(1, 1, 1, fade))
		"mirror":
			draw_arc(Vector2.ZERO, 0.62, -PI * 0.9, -PI * 0.1, 14, col, 0.16)
			draw_arc(Vector2.ZERO, 0.62, PI * 0.1, PI * 0.9, 14, col, 0.16)
			_poly(PackedVector2Array([Vector2(0.62, -0.05), Vector2(0.9, -0.42),
				Vector2(0.35, -0.42)]), col, fade, r)
			_poly(PackedVector2Array([Vector2(-0.62, 0.05), Vector2(-0.9, 0.42),
				Vector2(-0.35, 0.42)]), col, fade, r)
		"banner":
			_stroke(PackedVector2Array([Vector2(-0.55, 0.9), Vector2(-0.55, -0.85)]), Color(0.78, 0.66, 0.5, fade), fade, r, 0.14)
			_poly(PackedVector2Array([Vector2(-0.5, -0.82), Vector2(0.85, -0.55),
				Vector2(-0.5, -0.1)]), col, fade, r)
			_dot(Vector2(0.3, 0.45), 0.13, col, fade, r)
		"skull":
			_dot(Vector2(0.0, -0.15), 0.62, col, fade, r)
			_poly(PackedVector2Array([Vector2(-0.35, 0.3), Vector2(0.35, 0.3),
				Vector2(0.3, 0.75), Vector2(-0.3, 0.75)]), col, fade, r)
			draw_circle(Vector2(-0.24, -0.15), 0.17, dark)
			draw_circle(Vector2(0.24, -0.15), 0.17, dark)
			draw_line(Vector2(-0.1, 0.45), Vector2(-0.1, 0.72), dark, 0.07)
			draw_line(Vector2(0.1, 0.45), Vector2(0.1, 0.72), dark, 0.07)
		"fangs":
			# An open maw, two long teeth hanging from the top of it.
			var maw := PackedVector2Array([Vector2(-0.85, -0.45), Vector2(0.85, -0.45)])
			for k in range(1, 12):
				var a := PI * float(k) / 12.0
				maw.append(Vector2(cos(a) * 0.85, -0.45 + sin(a) * 1.15))
			_poly(maw, col, fade, r)
			for x in [-0.42, 0.42]:
				_poly(PackedVector2Array([Vector2(x - 0.2, -0.45), Vector2(x + 0.2, -0.45),
					Vector2(x, 0.3)]), Color(1, 1, 1, fade), fade, r)
		"pick":
			# A miner's pick: the handle, and a curved head pointed at both ends.
			_stroke(PackedVector2Array([Vector2(-0.55, 0.85), Vector2(0.15, -0.5)]),
				Color(0.78, 0.62, 0.42, fade), fade, r, 0.16)
			var head := PackedVector2Array()
			for k in 9:
				var a := PI * (1.12 + 0.76 * float(k) / 8.0)
				head.append(Vector2(0.12, 0.2) + Vector2(cos(a), sin(a)) * 0.95)
			for k in range(7, 0, -1):
				var a := PI * (1.12 + 0.76 * float(k) / 8.0)
				var thick := 0.95 - 0.28 * sin(PI * float(k) / 8.0)
				head.append(Vector2(0.12, 0.2) + Vector2(cos(a), sin(a)) * thick)
			_poly(head, col, fade, r)
		"brick":
			# Two below, one laid across the joint above: a wall, not a grid.
			for b in [Vector2(-0.82, 0.08), Vector2(0.04, 0.08), Vector2(-0.39, -0.5)]:
				var x: float = b.x
				var y: float = b.y
				_poly(PackedVector2Array([Vector2(x, y), Vector2(x + 0.78, y),
					Vector2(x + 0.78, y + 0.5), Vector2(x, y + 0.5)]), col, fade, r)
		"crosshair":
			draw_arc(Vector2.ZERO, 0.6, 0.0, TAU, 24, Color(OUTLINE, fade), 0.3)
			draw_arc(Vector2.ZERO, 0.6, 0.0, TAU, 24, col, 0.16)
			for d in [Vector2.UP, Vector2.DOWN, Vector2.LEFT, Vector2.RIGHT]:
				_stroke(PackedVector2Array([d * 0.3, d * 0.95]), col, fade, r, 0.14)
			_dot(Vector2.ZERO, 0.12, col, fade, r)
		"spiral":
			var curl := PackedVector2Array()
			for k in 30:
				var a := float(k) * 0.42
				curl.append(Vector2(cos(a), sin(a)) * (0.08 + 0.027 * float(k)))
			_stroke(curl, col, fade, r, 0.13)
		"heart":
			_poly(_heart(), col, fade, r)
			_stroke(PackedVector2Array([Vector2(0.05, -0.45), Vector2(-0.15, -0.1),
				Vector2(0.12, 0.15), Vector2(-0.05, 0.5)]), dark, fade, r, 0.08)
		"bomb":
			_dot(Vector2(-0.1, 0.15), 0.62, col, fade, r)
			_stroke(PackedVector2Array([Vector2(0.25, -0.3), Vector2(0.45, -0.6),
				Vector2(0.7, -0.65)]), Color(0.78, 0.66, 0.5, fade), fade, r, 0.1)
			draw_colored_polygon(_star(Vector2(0.75, -0.7), 0.28, 0.09, 5), Color(1, 0.9, 0.5, fade))
			draw_circle(Vector2(-0.3, -0.05), 0.12, Color(1, 1, 1, 0.55 * fade))
		_:
			_poly(_star(Vector2.ZERO, 0.9, 0.35, 5), col, fade, r)


static func _star(c: Vector2, outer: float, inner: float, points: int) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for k in points * 2:
		var a := float(k) * PI / float(points) - PI / 2.0
		var rad := outer if k % 2 == 0 else inner
		pts.append(c + Vector2(cos(a), sin(a)) * rad)
	return pts


static func _droplet() -> PackedVector2Array:
	var pts := PackedVector2Array([Vector2(0.0, -0.95)])
	for k in 15:
		var a := -PI * 0.15 + PI * 1.3 * float(k) / 14.0
		pts.append(Vector2(0.0, 0.25) + Vector2(cos(a), sin(a)) * 0.58)
	return pts


static func _heart() -> PackedVector2Array:
	var pts := PackedVector2Array()
	for k in 28:
		var t := TAU * float(k) / 28.0
		var x := 16.0 * pow(sin(t), 3.0)
		var y := -(13.0 * cos(t) - 5.0 * cos(2.0 * t) - 2.0 * cos(3.0 * t) - cos(4.0 * t))
		pts.append(Vector2(x, y) / 18.0)
	return pts
