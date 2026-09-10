class_name UnitView
extends Node2D

const BAR_HEIGHT := 9.0
const BAR_INSET := 6.0
const DEATH_TIME := 0.35
const POP_TIME := 0.36
const POP_SCALE := 1.30

# A colour per tier, so a board of six tiers reads at a glance instead of
# forcing you to read six little numbers.
const TIER_COLORS: Array[Color] = [
	Color(0.80, 0.84, 0.90),
	Color(0.53, 0.84, 0.55),
	Color(0.42, 0.70, 0.97),
	Color(0.76, 0.56, 0.96),
	Color(1.00, 0.86, 0.32),
	Color(0.98, 0.48, 0.40),
]


static func tier_color(tier: int) -> Color:
	return TIER_COLORS[clampi(tier - 1, 0, TIER_COLORS.size() - 1)]

@export var tile_size := 84.0

var unit: UnitInstance = null
var hp_cur := 0.0
var hp_max := 1.0
var shield := 0.0
var mana := 0.0
var has_ability := false
var display_hp := 1.0
var flash := 0.0
var dimmed := false
var hidden_unit := false
var reviving := false
var revive_t := 0.0
var dying := false
var death_t := 0.0
var casting := false
var cast_left := 0.0
var cast_total := 1.0
var cast_label := ""
var cast_guarded := false
var pop_t := 0.0
var merge_target := false

# Whose side the person watching is on. The enemy's letters are drawn upside
# down, which turns out to read faster than colour alone: at a glance the board
# separates into "letters I can read" and "letters I cannot".
var player_team := BoardModel.TEAM_B

@onready var _sprite: Sprite2D = $Sprite


func _ready() -> void:
	_refresh_sprite()
	set_process(true)


func bind(p_unit: UnitInstance) -> void:
	unit = p_unit
	hp_max = maxf(p_unit.stat(StatModifier.Stat.MAX_HP), 1.0)
	hp_cur = p_unit.current_hp
	shield = p_unit.shield
	mana = p_unit.mana
	has_ability = p_unit.data.ability != null
	display_hp = hp_fraction()
	if is_node_ready():
		_refresh_sprite()
	queue_redraw()


func _refresh_sprite() -> void:
	if _sprite == null:
		return
	# The portrait is NOT drawn by this Sprite2D. It is drawn inside _draw(), so
	# it can sit between the plate and the team ring; a child node always renders
	# above its parent's own drawing, and z_index cannot fix that without also
	# dropping it behind the board's tiles — which is exactly what happened when
	# this tried to. The node stays for scenes that set a custom `view_scene`.
	_sprite.visible = false


func set_hp(cur: float, maxv: float) -> void:
	hp_cur = cur
	hp_max = maxf(maxv, 1.0)


func set_shield(value: float) -> void:
	shield = maxf(value, 0.0)
	queue_redraw()


func set_mana(value: float) -> void:
	mana = clampf(value, 0.0, UnitInstance.MANA_MAX)
	queue_redraw()


func hp_fraction() -> float:
	if unit == null:
		return 0.0
	return clampf(hp_cur / hp_max, 0.0, 1.0)


func _process(delta: float) -> void:
	if reviving:
		revive_t = fmod(revive_t + delta * 2.4, TAU)
		queue_redraw()
	if casting:
		cast_left = maxf(cast_left - delta, 0.0)
		if cast_left <= 0.0:
			end_cast()
		queue_redraw()
	if pop_t > 0.0:
		pop_t = maxf(pop_t - delta / POP_TIME, 0.0)
		var k := 1.0 + (POP_SCALE - 1.0) * pop_t
		scale = Vector2(k, k)
		queue_redraw()
	if dying:
		death_t = maxf(death_t - delta / DEATH_TIME, 0.0)
		display_hp = 0.0
		queue_redraw()
		return
	var target := hp_fraction()
	if not is_equal_approx(display_hp, target):
		display_hp = move_toward(display_hp, target, delta * 4.0)
		queue_redraw()
	if flash > 0.0:
		flash = maxf(flash - delta * 4.0, 0.0)
		queue_redraw()


func hit() -> void:
	flash = 1.0
	queue_redraw()


func begin_revive() -> void:
	dying = false
	death_t = 0.0
	reviving = true
	revive_t = 0.0
	display_hp = 0.0
	hp_cur = 0.0
	queue_redraw()


func end_revive() -> void:
	reviving = false
	revive_t = 0.0
	queue_redraw()


func begin_cast(duration: float, label := "", guarded := false) -> void:
	cast_total = maxf(duration, 0.05)
	cast_left = cast_total
	cast_label = label
	cast_guarded = guarded
	casting = true
	queue_redraw()


func merge_pop() -> void:
	pop_t = 1.0
	scale = Vector2(POP_SCALE, POP_SCALE)
	queue_redraw()


func end_cast() -> void:
	casting = false
	cast_left = 0.0
	cast_label = ""
	cast_guarded = false
	queue_redraw()


func cast_progress() -> float:
	if not casting:
		return 0.0
	return clampf(1.0 - cast_left / maxf(cast_total, 0.001), 0.0, 1.0)


func die() -> void:
	if dying:
		return
	end_cast()
	dying = true
	death_t = 1.0
	display_hp = 0.0
	queue_redraw()


func is_gone() -> bool:
	return dying and death_t <= 0.0


static func _compact(v: float) -> String:
	var n := maxf(v, 0.0)
	if n < 10000.0:
		return "%d" % ceili(n)
	if n < 1000000.0:
		return "%.1fk" % (n / 1000.0)
	return "%.1fM" % (n / 1000000.0)


func team_color() -> Color:
	if unit == null:
		return Color.GRAY
	return Color(0.38, 0.66, 0.69) if unit.team == BoardModel.TEAM_A else Color(0.83, 0.63, 0.39)


func _draw_cast(body: Rect2, alpha: float) -> void:
	var p := cast_progress()
	var centre := body.get_center()
	var radius := tile_size * 0.34

	# A ring that closes in as the cast completes: the wind-up you can read.
	var incoming := radius * (1.9 - 0.9 * p)
	draw_arc(centre, incoming, 0.0, TAU, 28,
		Color(0.98, 0.80, 0.38, (0.16 + 0.42 * p) * alpha), 2.5)

	if cast_guarded:
		# Nothing can touch it while this is up, so it should look like armour.
		var shell := body.grow(5.0)
		draw_rect(shell, Color(0.62, 0.84, 0.98, (0.55 + 0.35 * p) * alpha), false, 3.0)
		draw_rect(body, Color(0.55, 0.78, 0.96, 0.16 * alpha), true)

	# The charge arc itself fills clockwise from the top.
	var start := -PI * 0.5
	draw_arc(centre, radius, start, start + TAU * p, 30,
		Color(1.0, 0.88, 0.50, 0.85 * alpha), 3.0)
	draw_arc(centre, radius, start, start + TAU, 30,
		Color(0.30, 0.26, 0.18, 0.55 * alpha), 1.5)

	if cast_label.is_empty():
		return
	var font := ThemeDB.fallback_font
	var size := 11
	var w := font.get_string_size(cast_label, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
	var at := Vector2(-w * 0.5, body.position.y - 16.0)
	draw_rect(Rect2(at.x - 4.0, at.y - 11.0, w + 8.0, 15.0),
		Color(0.06, 0.05, 0.04, 0.78 * alpha), true)
	draw_string(font, at, cast_label, HORIZONTAL_ALIGNMENT_LEFT, -1, size,
		Color(1.0, 0.90, 0.58, alpha))


func _draw_tier_pips(body: Rect2, tier: int, tint: Color, alpha: float) -> void:
	# One pip per tier along the bottom edge: countable without reading.
	var pip := maxf(tile_size * 0.055, 3.0)
	var gap := pip * 0.75
	var span := float(tier) * pip + float(tier - 1) * gap
	var x := body.get_center().x - span * 0.5
	var y := body.position.y + body.size.y - pip - 3.0
	for i in tier:
		var r := Rect2(x, y, pip, pip)
		draw_rect(r.grow(1.0), Color(0.04, 0.05, 0.08, 0.75 * alpha), true)
		draw_rect(r, Color(tint, alpha), true)
		x += pip + gap


func _draw() -> void:
	if unit == null:
		return
	var half := tile_size * 0.5
	var body := Rect2(-half + 5.0, -half + 5.0, tile_size - 10.0, tile_size - 10.0)
	var alpha := 0.45 if dimmed else 1.0
	if hidden_unit:
		alpha *= 0.4
	if reviving:
		alpha *= 0.55
	if dying:
		alpha *= death_t
		var shrink := (1.0 - death_t) * tile_size * 0.22
		body = body.grow(-shrink)

	var tier := unit.data.tier
	var tint := tier_color(tier)

	# The plate the unit sits on, drawn whether or not there is a portrait. With a
	# portrait it is the muted ground the art reads against; without one it is the
	# unit's whole colour. Same rect either way, so a unit that gains art later
	# keeps its footprint exactly.
	var fill: Color = unit.data.accent.lerp(tint, 0.06 * float(tier - 1))
	if unit.data.sprite != null:
		# Behind art, the accent has to stop competing with it: pulled most of the
		# way to grey and darkened well below the portrait's own midtones. It is
		# there to say whose unit this is and what tier, not to be looked at.
		fill = fill.lerp(Color(0.16, 0.17, 0.20), 0.62).darkened(0.15)
	fill.a = alpha
	draw_rect(body, fill, true)

	if unit.data.sprite != null:
		# Inset inside the plate so a rim of the muted ground shows all the way
		# round, and drawn HERE — after the plate, before the ring and the bars —
		# so nothing readable ends up underneath it.
		var art := body.grow(-4.0)
		draw_texture_rect(unit.data.sprite, art, false, Color(1, 1, 1, alpha))
	else:
		var initial := String(unit.data.display_name).substr(0, 1).to_upper()
		var font := ThemeDB.fallback_font
		var size := 30
		var w := font.get_string_size(initial, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
		var ink := Color(0, 0, 0, 0.65 * alpha)
		if unit.team == player_team:
			draw_string(font, Vector2(-w * 0.5, 10.0), initial,
				HORIZONTAL_ALIGNMENT_LEFT, -1, size, ink)
		else:
			# Rotated about the tile's own centre rather than the text baseline,
			# or the letter walks off the square. draw_set_transform replaces the
			# canvas transform outright, so it has to be reset afterwards — the
			# health bar and everything below draw in plain local space.
			draw_set_transform(Vector2.ZERO, PI, Vector2.ONE)
			draw_string(font, Vector2(-w * 0.5, 10.0), initial,
				HORIZONTAL_ALIGNMENT_LEFT, -1, size, ink)
			draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

	var ring := team_color()
	ring.a = alpha
	draw_rect(body, ring, false, 3.0)

	# Inside the team ring, so team and tier never fight for the same edge.
	var rim := tint
	rim.a = (0.30 + 0.13 * float(tier - 1)) * alpha
	draw_rect(body.grow(-3.5), rim, false, 1.0 + 0.7 * float(tier - 1))

	# An empowered unit has to look different from an ordinary one of the same
	# name and tier, because it is the same name and tier — the difference is
	# entirely in the stats, so the board has to say so.
	if unit.empowered:
		var glow := Color(1.00, 0.86, 0.42, 0.85 * alpha)
		draw_rect(body.grow(2.5), glow, false, 2.0)
		draw_rect(body.grow(5.0), Color(glow, 0.35 * alpha), false, 2.0)
	if unit.is_taunting():
		# A ring outside everything: it is the loudest thing on the board while
		# it lasts, and it should read that way.
		draw_arc(Vector2.ZERO, half - 1.0, 0.0, TAU, 28,
			Color(0.98, 0.78, 0.30, 0.90 * alpha), 3.0)

	if hidden_unit:
		draw_rect(body.grow(3.0), Color(0.62, 0.52, 0.85, 0.75 * alpha), false, 2.0)
	if reviving:
		var pulse := 0.5 + 0.5 * sin(revive_t)
		draw_rect(body.grow(2.0 + pulse * 5.0),
			Color(0.55, 0.88, 0.62, 0.35 + 0.55 * pulse), false, 2.5)
		var spinner := body.get_center() + Vector2(cos(revive_t), sin(revive_t)) * 12.0
		draw_circle(spinner, 3.5, Color(0.66, 0.94, 0.70, 0.9))

	if casting:
		_draw_cast(body, alpha)
	if pop_t > 0.0:
		draw_rect(body.grow(4.0 + pop_t * 10.0),
			Color(1.0, 0.90, 0.52, 0.85 * pop_t), false, 3.0)
		draw_rect(body, Color(1.0, 0.95, 0.70, 0.30 * pop_t), true)
	if merge_target:
		draw_rect(body.grow(3.0), Color(1.0, 0.88, 0.48, 0.95), false, 3.0)
		draw_rect(body, Color(1.0, 0.92, 0.60, 0.16), true)

	if flash > 0.0:
		draw_rect(body, Color(1, 1, 1, 0.55 * flash), true)

	var tfont := ThemeDB.fallback_font
	var badge := Rect2(-half + 5.0, -half + 4.0, 24.0, 17.0)
	var chip := tint
	chip.a = alpha
	draw_rect(badge.grow(1.0), Color(0.04, 0.05, 0.08, 0.85 * alpha), true)
	draw_rect(badge, chip, true)
	var tt := "T%d" % tier
	var tw2 := tfont.get_string_size(tt, HORIZONTAL_ALIGNMENT_LEFT, -1, 12).x
	draw_string(tfont, Vector2(badge.position.x + (badge.size.x - tw2) * 0.5,
		badge.position.y + 13.0), tt, HORIZONTAL_ALIGNMENT_LEFT, -1, 12,
		Color(0.06, 0.07, 0.10, alpha))

	_draw_tier_pips(body, tier, tint, alpha)

	if dying:
		var k := body.grow(-body.size.x * 0.28)
		var cross := Color(0.88, 0.34, 0.30, alpha)
		draw_line(k.position, k.position + k.size, cross, 3.0)
		draw_line(Vector2(k.position.x + k.size.x, k.position.y),
			Vector2(k.position.x, k.position.y + k.size.y), cross, 3.0)
		return

	var bar := Rect2(-half + BAR_INSET, -half - BAR_HEIGHT - 3.0,
		tile_size - BAR_INSET * 2.0, BAR_HEIGHT)
	draw_rect(bar.grow(1.5), Color(0.02, 0.03, 0.05, 0.9 * alpha), true)
	draw_rect(bar, Color(0.16, 0.10, 0.11, alpha), true)
	var filled := bar
	filled.size.x = bar.size.x * display_hp
	var hp_col := Color(0.42, 0.74, 0.46)
	if display_hp <= 0.6:
		hp_col = Color(0.85, 0.72, 0.30)
	if display_hp <= 0.28:
		hp_col = Color(0.86, 0.36, 0.31)
	hp_col.a = alpha
	if display_hp > 0.0:
		draw_rect(filled, hp_col, true)

	if shield > 0.0:
		var frac: float = clampf(shield / hp_max, 0.0, 1.0)
		var sh := bar
		sh.size.x = bar.size.x * frac
		sh.position.x = bar.position.x + bar.size.x - sh.size.x
		draw_rect(sh, Color(0.53, 0.79, 0.92, alpha), true)

	if has_ability:
		var mb := Rect2(-half + BAR_INSET, -half - 3.0,
			tile_size - BAR_INSET * 2.0, 3.5)
		draw_rect(mb, Color(0.08, 0.09, 0.14, 0.85 * alpha), true)
		var mf := mb
		mf.size.x = mb.size.x * clampf(mana / UnitInstance.MANA_MAX, 0.0, 1.0)
		var full := mana >= UnitInstance.MANA_MAX
		var mana_col := Color(0.98, 0.85, 0.42) if full else Color(0.42, 0.62, 0.92)
		mana_col.a = alpha
		draw_rect(mf, mana_col, true)

	var font := ThemeDB.fallback_font
	var hp_text := _compact(hp_cur)
	if shield > 0.0:
		hp_text += "+" + _compact(shield)
	var tw := font.get_string_size(hp_text, HORIZONTAL_ALIGNMENT_LEFT, -1, 13).x
	draw_string(font, Vector2(-tw * 0.5, -half - BAR_HEIGHT - 7.0), hp_text,
		HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color(0.80, 0.85, 0.92, alpha))
