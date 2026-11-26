class_name UnitView
extends Node2D

## The tier at which a unit stops being a merge result and starts being the thing you
## built the whole round for. Only tier 6 gets the halo.
const APEX_TIER := 6

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


## Whether unit art is drawn at all. Lives HERE, in the view layer, rather than
## on the settings autoload: UnitView and UnitIcon are the two things that draw a
## unit, and the headless model suite loads both. An autoload does not exist in
## `--script` mode, so reaching for one from here stops those scripts compiling
## and silently skips every test that touches them — which is exactly what
## happened when this was tried the other way round.
##
## GameSetup owns the SETTING and writes it down to here; this is where the
## drawing reads it. Off by default, matching GameSetup.portraits.
static var portraits_on := false


static func portrait_for(d: UnitData) -> Texture2D:
	## The one place anything asks whether a unit has art to draw. Returning null
	## rather than a flag is deliberate: null is already what "this unit has no
	## art" means everywhere downstream, so switching portraits off takes the
	## exact path an art-less unit takes and there is no second placeholder look
	## to keep in step with the first.
	if not portraits_on or d == null:
		return null
	return d.sprite


## Short names that are not simply the first three letters, because those would
## clash (PARiah / PARagon) or read badly.
const SHORT_OVERRIDES := {
	&"assassin": "ASN", &"paragon": "PGN", &"powderkeg": "KEG",
	&"transcendence": "TRN", &"bannerman": "BNR", &"crystal": "", &"crimson_shade": "SHD",
}


static func short_name(d: UnitData) -> String:
	## The unit's label on a coloured block: three letters, unique across the roster.
	if d == null:
		return ""
	if SHORT_OVERRIDES.has(d.id):
		return SHORT_OVERRIDES[d.id]
	return String(d.id).substr(0, 3).to_upper()


## The boss defence's summoned shade (BossFight.MINION_ID), drawn as an icon.
const SHADE_ID := &"crimson_shade"
const SHADE_HOOD := [
	Vector2(0.0, -0.80), Vector2(0.36, -0.62), Vector2(0.54, -0.22), Vector2(0.58, 0.22),
	Vector2(0.66, 0.74), Vector2(0.40, 0.50), Vector2(0.22, 0.78), Vector2(0.0, 0.54),
	Vector2(-0.22, 0.78), Vector2(-0.40, 0.50), Vector2(-0.66, 0.74), Vector2(-0.58, 0.22),
	Vector2(-0.54, -0.22), Vector2(-0.36, -0.62),
]


func _draw_shade(body: Rect2, alpha: float) -> void:
	## A hooded wraith: a ragged dark cloak, a hollow face and two burning eyes.
	var c := body.get_center()
	var s := body.size.x * 0.5 * 0.92
	var hood := PackedVector2Array()
	for p: Vector2 in SHADE_HOOD:
		hood.append(c + p * s)
	draw_colored_polygon(hood, Color(0.10, 0.02, 0.05, 0.92 * alpha))
	var rim := hood.duplicate()
	rim.append(hood[0])
	draw_polyline(rim, Color(1.0, 0.42, 0.50, 0.75 * alpha), maxf(s * 0.06, 1.0), true)
	# The hollow under the hood.
	var face := PackedVector2Array()
	for i in 16:
		var a := TAU * float(i) / 16.0
		face.append(c + Vector2(cos(a) * 0.27, sin(a) * 0.30 - 0.14) * s)
	draw_colored_polygon(face, Color(0.0, 0.0, 0.0, alpha))
	# The eyes, with a glow that pulses a little with the apex clock everything shares.
	var glow := 0.75 + 0.25 * sin(Time.get_ticks_msec() * 0.006)
	for side in [-1.0, 1.0]:
		var eye := c + Vector2(0.11 * side, -0.14) * s
		draw_circle(eye, s * 0.11, Color(1.0, 0.25, 0.20, 0.30 * glow * alpha))
		draw_circle(eye, s * 0.055, Color(1.0, 0.55, 0.40, alpha))


## The boss's retreat summons (BossMinion ids), each with its own picture.
const THORN_ID := &"scarlet_thorn"
const CHALICE_ID := &"blood_chalice"
const HEADHUNTER_ID := &"headhunter"
const BERSERKER_ID := &"berserker"
const THRALL_ID := &"thrall"
const STALKER_ID := &"stalker"


static func is_summon_icon(id: StringName) -> bool:
	return id in [SHADE_ID, THORN_ID, CHALICE_ID, HEADHUNTER_ID, BERSERKER_ID, THRALL_ID, STALKER_ID]


func _draw_summon_tier(body: Rect2, alpha: float) -> void:
	## Her summons have tiers too: shown as small diamonds along the bottom edge, in
	## the tier's colour, one per tier.
	var tier := unit.data.tier
	var s := maxf(body.size.x * 0.07, 2.5)
	var gap := s * 2.4
	var x0 := body.get_center().x - gap * float(tier - 1) * 0.5
	var y := body.end.y - s * 1.6
	var ink := tier_ink(tier)
	for i in tier:
		var c := Vector2(x0 + gap * float(i), y)
		var d := PackedVector2Array([c + Vector2(0, -s), c + Vector2(s, 0), c + Vector2(0, s), c + Vector2(-s, 0)])
		draw_colored_polygon(d, Color(0, 0, 0, 0.8 * alpha))
		draw_colored_polygon(PackedVector2Array([c + Vector2(0, -s * 0.7), c + Vector2(s * 0.7, 0),
			c + Vector2(0, s * 0.7), c + Vector2(-s * 0.7, 0)]), Color(ink, alpha))


func _draw_headhunter(body: Rect2, alpha: float) -> void:
	## Headhunter: a crosshair over a dark disc — it hunts your highest tier.
	var c := body.get_center()
	var s := body.size.x * 0.5 * 0.9
	var red := Color(1.0, 0.30, 0.25, alpha)
	draw_circle(c, s * 0.82, Color(0.08, 0.02, 0.03, 0.92 * alpha))
	draw_arc(c, s * 0.55, 0.0, TAU, 28, red, maxf(s * 0.09, 1.5), true)
	for dir in [Vector2.UP, Vector2.DOWN, Vector2.LEFT, Vector2.RIGHT]:
		draw_line(c + dir * s * 0.25, c + dir * s * 0.8, red, maxf(s * 0.08, 1.5))
	draw_circle(c, s * 0.1, Color(1.0, 0.85, 0.6, alpha))


func _draw_stalker(body: Rect2, alpha: float) -> void:
	## Crimson Stalker, the flanker that hunts your bows: two crossed daggers on violet.
	var c := body.get_center()
	var s := body.size.x * 0.5 * 0.9
	draw_circle(c, s * 0.82, Color(0.14, 0.04, 0.18, 0.92 * alpha))
	for side in [-1.0, 1.0]:
		var a := c + Vector2(-0.45 * side, 0.5) * s
		var b := c + Vector2(0.45 * side, -0.55) * s
		draw_line(a, a.lerp(b, 0.3), Color(0.35, 0.2, 0.1, alpha), maxf(s * 0.12, 1.5))
		draw_line(a.lerp(b, 0.3), b, Color(0.85, 0.75, 1.0, alpha), maxf(s * 0.09, 1.5))


func _draw_thrall(body: Rect2, alpha: float) -> void:
	## Crimson Thrall, her fodder: a small horned head, two pinprick eyes — one of many.
	var c := body.get_center() + Vector2(0, body.size.y * 0.05)
	var s := body.size.x * 0.5 * 0.75
	var skin := Color(0.45, 0.08, 0.10, 0.95 * alpha)
	for side in [-1.0, 1.0]:
		draw_colored_polygon(PackedVector2Array([c + Vector2(0.35 * side, -0.45) * s,
			c + Vector2(0.75 * side, -1.05) * s, c + Vector2(0.6 * side, -0.25) * s]),
			Color(0.85, 0.75, 0.6, alpha))
	draw_circle(c, s * 0.7, skin)
	for side in [-1.0, 1.0]:
		draw_circle(c + Vector2(0.25 * side, -0.1) * s, s * 0.1, Color(1.0, 0.85, 0.3, alpha))
	draw_line(c + Vector2(-0.25, 0.3) * s, c + Vector2(0.25, 0.3) * s, Color(0.1, 0, 0, alpha), maxf(s * 0.08, 1.0))


func _draw_berserker(body: Rect2, alpha: float) -> void:
	## Berserker: two crossed axes — it cleaves through crowds.
	var c := body.get_center()
	var s := body.size.x * 0.5 * 0.9
	draw_circle(c, s * 0.82, Color(0.10, 0.03, 0.02, 0.92 * alpha))
	for side in [-1.0, 1.0]:
		var a := c + Vector2(-0.55 * side, 0.6) * s
		var b := c + Vector2(0.45 * side, -0.55) * s
		draw_line(a, b, Color(0.55, 0.35, 0.20, alpha), maxf(s * 0.1, 1.5))
		var head := b + Vector2(-0.05 * side, 0.1) * s
		draw_colored_polygon(PackedVector2Array([head, head + Vector2(0.4 * side, -0.15) * s,
			head + Vector2(0.35 * side, 0.35) * s]), Color(0.95, 0.55, 0.30, alpha))


func _draw_thorn(body: Rect2, alpha: float) -> void:
	## Scarlet Thorn, her archer: a thorned bow drawn back on an arrow.
	var c := body.get_center()
	var s := body.size.x * 0.5 * 0.9
	var dark := Color(0.12, 0.02, 0.04, alpha)
	var red := Color(1.0, 0.40, 0.45, alpha)
	draw_circle(c, s * 0.78, Color(0.10, 0.02, 0.05, 0.85 * alpha))
	# The bow: an arc on the left, thorns along its back.
	var arc := PackedVector2Array()
	for i in 13:
		var a := lerpf(PI * 0.62, PI * 1.38, float(i) / 12.0)
		arc.append(c + Vector2(cos(a) * 0.55 + 0.12, sin(a) * 0.62) * s)
	draw_polyline(arc, red, maxf(s * 0.10, 1.5), true)
	for i in [3, 6, 9]:
		var p: Vector2 = arc[i]
		var out := (p - (c + Vector2(0.12, 0.0) * s)).normalized()
		var side := Vector2(-out.y, out.x) * s * 0.07
		draw_colored_polygon(PackedVector2Array([p + side, p - side, p + out * s * 0.17]), red)
	# The string, drawn back to the nock, and the arrow pointing at you.
	var nock := c + Vector2(0.32, 0.0) * s
	draw_polyline(PackedVector2Array([arc[0], nock, arc[12]]),
		Color(1.0, 0.85, 0.80, 0.8 * alpha), maxf(s * 0.04, 1.0), true)
	var tip := c + Vector2(-0.62, 0.0) * s
	draw_line(nock, tip, Color(0.95, 0.90, 0.85, alpha), maxf(s * 0.06, 1.0))
	draw_colored_polygon(PackedVector2Array([tip + Vector2(-0.12, 0) * s,
		tip + Vector2(0.06, -0.10) * s, tip + Vector2(0.06, 0.10) * s]), red)
	draw_circle(nock, s * 0.05, dark)


func _draw_chalice(body: Rect2, alpha: float) -> void:
	## Blood Chalice, which mends her: a cup brimming red, glowing while it stands.
	var c := body.get_center()
	var s := body.size.x * 0.5 * 0.9
	var gold := Color(0.95, 0.78, 0.40, alpha)
	var deep := Color(0.14, 0.03, 0.05, 0.9 * alpha)
	draw_circle(c, s * 0.80, deep)
	var glow := 0.7 + 0.3 * sin(Time.get_ticks_msec() * 0.004)
	draw_circle(c + Vector2(0, -0.30) * s, s * 0.5, Color(0.5, 1.0, 0.6, 0.14 * glow * alpha))
	# The bowl.
	var bowl := PackedVector2Array()
	for i in 13:
		var a := lerpf(0.0, PI, float(i) / 12.0)
		bowl.append(c + Vector2(cos(a) * 0.46, sin(a) * 0.38 - 0.30) * s)
	draw_colored_polygon(bowl, gold)
	# The blood at its brim.
	var top := PackedVector2Array()
	for i in 16:
		var a := TAU * float(i) / 16.0
		top.append(c + Vector2(cos(a) * 0.42, sin(a) * 0.09 - 0.30) * s)
	draw_colored_polygon(top, Color(0.85, 0.08, 0.15, alpha))
	# Stem and foot.
	draw_rect(Rect2(c + Vector2(-0.06, 0.06) * s, Vector2(0.12, 0.34) * s), gold)
	var foot := PackedVector2Array()
	for i in 16:
		var a := TAU * float(i) / 16.0
		foot.append(c + Vector2(cos(a) * 0.30, sin(a) * 0.08 + 0.44) * s)
	draw_colored_polygon(foot, gold)
	# A drop running over the lip.
	draw_circle(c + Vector2(0.40, -0.12) * s, s * 0.06, Color(0.85, 0.08, 0.15, alpha))


static func tier_color(tier: int) -> Color:
	return TIER_COLORS[clampi(tier - 1, 0, TIER_COLORS.size() - 1)]


## Bold tier markings: the tier is told by the colour of a unit's LETTERS, a badge with
## its number, and a full-strength tier rim, rather than only a small corner digit and
## the pips. A Settings switch (GameSetup.bold_tiers writes it here); on by default, and
## true here too so the board draws it before that setter has ever run.
static var bold_tiers := true
## The old look: the tier as a row of bright squares along the bottom of every unit,
## large enough to read on the smallest tiles. One of the Tier markings settings.
static var tier_squares := false

## Text colours for the tiers: TIER_COLORS pushed bright and apart so that letters in
## them read against any unit's plate behind a black outline. White, green, sky blue,
## violet, gold, red — the same order as the rims.
const TIER_INKS: Array[Color] = [
	Color(0.96, 0.96, 0.96),
	Color(0.40, 1.00, 0.45),
	Color(0.35, 0.80, 1.00),
	Color(0.86, 0.55, 1.00),
	Color(1.00, 0.84, 0.15),
	Color(1.00, 0.38, 0.28),
]


static func tier_ink(tier: int) -> Color:
	return TIER_INKS[clampi(tier - 1, 0, TIER_INKS.size() - 1)]


func _bold() -> bool:
	## Bold tier markings for this unit: the setting is on, and it is a unit with a
	## tier to show — not the boss, a crystal, or one of her summons, which are drawn
	## as pictures.
	if not bold_tiers or unit == null or unit.boss or unit.structure:
		return false
	var id := unit.data.id
	return not is_summon_icon(id)

## Set by the board on every zoom. A setter, not a plain field: a unit only repaints
## when something asks it to, so a unit standing still kept drawing itself at the OLD
## size after a zoom out — giant blocks spilling over their neighbours until it next
## took a hit or moved.
@export var tile_size := 84.0:
	set(value):
		if is_equal_approx(value, tile_size):
			return
		tile_size = value
		queue_redraw()

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

## Whether this unit is visibly stunned or frozen right now, and for how much
## longer. Driven ENTIRELY by the event log, never read off the unit.
##
## That distinction is the whole reason these fields exist. The simulation resolves
## the entire round before the first frame is drawn, so `unit.stun_left` during
## playback is whatever it was when the battle ENDED — usually zero. A mark drawn
## from `unit.is_held()` would be a mark that almost never appeared, and when it did
## appear would show the wrong unit at the wrong time. The same trap as `unit.cell`.
enum { HELD_NONE, HELD_STUNNED, HELD_FROZEN }
var held := HELD_NONE
var held_left := 0.0

## The Martyr's window: zero health and still standing. Driven off the "frenzy" and
## "frenzy_end" events with a clock of its own, for exactly the reason the `held`
## fields above exist — during playback `unit.frenzy_left` is the unit's state at the
## END of the round, so reading it would light up every Martyr from the first frame.
var frenzied := false
var frenzy_secs := 0.0
var frenzy_t := 0.0

## Reeling: wandering, not swinging. Event-driven with its own clock, like every other
## condition here — during playback `unit.disorient_left` is the END-of-round value.
var reeling := false
var reeling_secs := 0.0
var reeling_t := 0.0

## The Hospitaller in melee mode: an enemy is next to it, the mending has stopped
## and its swings are heavy. Event-driven ("mend_mode"), because during playback
## `unit.mend_engaged` is the END-of-round value.
var engaged := false

## Running from a lit Powderkeg: the direction away from the keg's CURRENT tile, or
## zero when not fleeing. Set by BattlePlayer every frame off the views' live
## positions rather than off the model, which during playback is end-of-round state.
var flee_dir := Vector2.ZERO


func set_flee_dir(dir: Vector2) -> void:
	if dir.is_equal_approx(flee_dir):
		return
	flee_dir = dir
	queue_redraw()

## Whether an Usurper is currently inside this unit.
##
## Event-driven, like every other condition here. The simulation flips the host's `team`
## the moment it is taken, so the board already recolours it — but a recoloured unit just
## looks like one of yours, and there is nothing on it to say the body is stolen and
## comes back if you kill whatever is wearing it.
var possessed := false
var possessed_t := 0.0

## Animation phase for a tier 6's halo. Kept here rather than derived from a global clock
## so that two tier 6s side by side are not locked in step, which reads as one effect
## drawn twice rather than two units.
var apex_t := 0.0

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


## The Pariah's isolation meter in boss defence: -1 for none, else how full it is;
## `isolation_charging` while the charge it buys is running down.
var isolation := -1.0
var isolation_charging := false


func set_isolation(fill: float, charging: bool) -> void:
	isolation = clampf(fill, 0.0, 1.0)
	isolation_charging = charging
	queue_redraw()


func set_mana(value: float) -> void:
	mana = clampf(value, 0.0, UnitInstance.MANA_MAX)
	queue_redraw()


func hp_fraction() -> float:
	if unit == null:
		return 0.0
	return clampf(hp_cur / hp_max, 0.0, 1.0)


func _process(delta: float) -> void:
	# A held unit's ring turns, so it is repainted every frame while it lasts.
	if held != HELD_NONE:
		held_left -= delta
		if held_left <= 0.0:
			held = HELD_NONE
			held_left = 0.0
		queue_redraw()
	if frenzied:
		frenzy_secs -= delta
		frenzy_t = fmod(frenzy_t + delta * 9.0, TAU)
		if frenzy_secs <= 0.0:
			end_frenzy()
		queue_redraw()
	if reeling:
		reeling_secs -= delta
		reeling_t = fmod(reeling_t + delta * 4.0, TAU)
		if reeling_secs <= 0.0:
			end_reeling()
		queue_redraw()
	if possessed:
		possessed_t = fmod(possessed_t + delta * 2.2, TAU)
		queue_redraw()
	if unit != null and unit.sealed:
		# The Central Crystal's seal turns.
		queue_redraw()
	if unit != null and unit.data != null and (unit.data.id == SHADE_ID or unit.data.id == CHALICE_ID
			or (unit.boss and boss_phase >= 2) or (unit.isolated and unit.data.alone_hp_damage > 0.0)):
		# Its eyes burn.
		queue_redraw()
	if unit != null and unit.data != null and unit.data.tier >= APEX_TIER:
		apex_t = fmod(apex_t + delta * 1.1, TAU)
		queue_redraw()
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


func hold(kind: int, seconds: float) -> void:
	## Marks the unit as stunned or frozen for `seconds` of playback time. A freeze
	## outranks a stun when both land, because a freeze is the stronger condition —
	## it also amplifies damage and cancels what the victim would have done on death.
	if kind == HELD_NONE or seconds <= 0.0:
		return
	if held == HELD_FROZEN and kind == HELD_STUNNED:
		held_left = maxf(held_left, seconds)
		return
	held = kind
	held_left = maxf(held_left if held == kind else 0.0, seconds)
	queue_redraw()


func begin_reeling(seconds: float) -> void:
	## Sent reeling for `seconds` of playback time. Overwrites rather than takes the
	## longest, because the ability RESETS the count rather than extending it — the view
	## has to agree with the simulation about that or a re-application looks like it did
	## nothing.
	if seconds <= 0.0:
		return
	reeling = true
	reeling_secs = seconds
	queue_redraw()


func set_engaged(on: bool) -> void:
	engaged = on
	queue_redraw()


func end_reeling() -> void:
	reeling = false
	reeling_secs = 0.0
	queue_redraw()


func begin_frenzy(seconds: float) -> void:
	## Opens the window. `seconds` is already in playback time — the caller divides by
	## the speed multiplier, the same as hold() above.
	if seconds <= 0.0:
		return
	frenzied = true
	frenzy_secs = seconds
	queue_redraw()


func end_frenzy() -> void:
	frenzied = false
	frenzy_secs = 0.0
	queue_redraw()


func release(kind: int) -> void:
	## The matching end event. Only lets go if it is the condition being ended, so a
	## thaw does not clear a stun that landed on top of it.
	if held != kind:
		return
	held = HELD_NONE
	held_left = 0.0
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


func _draw_crystal() -> void:
	## A crystal: a faceted gem on the tile and a wide health bar under it. The
	## Central Crystal is gold and, while sealed, sits inside a ring.
	var half := tile_size * 0.5
	var alpha := 1.0
	if dying:
		alpha = death_t
	var col := unit.data.accent
	var r := half * 0.72
	var gem := PackedVector2Array([Vector2(0, -r), Vector2(r * 0.7, 0), Vector2(0, r),
		Vector2(-r * 0.7, 0)])
	draw_colored_polygon(gem, Color(col.darkened(0.35), 0.95 * alpha))
	var face := PackedVector2Array([Vector2(0, -r), Vector2(r * 0.7, 0), Vector2(0, r * 0.2)])
	draw_colored_polygon(face, Color(col.lightened(0.25), 0.95 * alpha))
	gem.append(gem[0])
	draw_polyline(gem, Color(1, 1, 1, 0.85 * alpha), 2.0)
	if flash > 0.0:
		draw_colored_polygon(PackedVector2Array(gem.slice(0, 4)),
			Color(1, 1, 1, 0.6 * flash))
	if unit.sealed:
		var spin: float = float(Time.get_ticks_msec()) * 0.002
		for i in 6:
			var from: float = spin + float(i) * TAU / 6.0
			draw_arc(Vector2.ZERO, half - 2.0, from, from + 0.6, 6,
				Color(0.98, 0.88, 0.50, 0.9 * alpha), 2.5)
	if dying:
		return
	var bar := Rect2(-half + 3.0, half - 8.0, tile_size - 6.0, 6.0)
	draw_rect(bar.grow(1.0), Color(0.02, 0.03, 0.05, 0.9), true)
	var filled := bar
	filled.size.x = bar.size.x * display_hp
	draw_rect(filled, Color(0.55, 0.90, 1.0) if not unit.sealed else Color(0.98, 0.86, 0.46), true)


## Which of her phases the boss is in, 0-3. Set by BattlePlayer off the "boss_start"
## and "boss_phase" events, and it changes how she looks: she picks up her second
## blade, then her crown, and ends wreathed in fire with every blade she owns.
var boss_phase := 0:
	set(value):
		boss_phase = clampi(value, 0, 3)
		queue_redraw()

## The colours of her four forms, from lacquered red to near-black crimson.
const BOSS_PLATES := [Color(0.80, 0.12, 0.14), Color(0.72, 0.08, 0.12),
	Color(0.52, 0.04, 0.10), Color(0.30, 0.02, 0.06)]
## How far past her tile she spills, a share of the tile, per phase: she grows.
const BOSS_GROWTH := [0.0, 0.08, 0.16, 0.26]


func _boss_blade(from: Vector2, to: Vector2, w: float, alpha: float, glow := 0.0) -> void:
	## One blade: a pale edge with a gold guard and hilt, optionally burning red.
	var dir := (to - from).normalized()
	var side := Vector2(-dir.y, dir.x)
	if glow > 0.0:
		draw_line(from, to, Color(1.0, 0.30, 0.15, 0.30 * glow * alpha), w * 1.5)
	var guard := from + (to - from) * 0.22
	draw_colored_polygon(PackedVector2Array([guard + side * w * 0.55, to,
		guard - side * w * 0.55]), Color(0.96, 0.94, 0.92, alpha))
	draw_line(guard + side * w * 1.4, guard - side * w * 1.4, Color(0.92, 0.72, 0.30, alpha),
		maxf(w * 0.6, 1.5))
	draw_line(from, guard, Color(0.40, 0.16, 0.10, alpha), maxf(w * 0.7, 1.5))


func _boss_crown(top: float, width: float, spikes: int, alpha: float) -> void:
	## A crown sitting on the top edge of her plate, `spikes` points.
	var pts := PackedVector2Array([Vector2(-width * 0.5, top)])
	for i in spikes:
		var x0 := -width * 0.5 + width * float(i) / float(spikes)
		var x1 := -width * 0.5 + width * (float(i) + 0.5) / float(spikes)
		pts.append(Vector2(x0, top))
		pts.append(Vector2(x1, top - width * 0.32))
	pts.append(Vector2(width * 0.5, top))
	pts.append(Vector2(width * 0.5, top + width * 0.10))
	pts.append(Vector2(-width * 0.5, top + width * 0.10))
	draw_colored_polygon(pts, Color(0.95, 0.76, 0.32, alpha))
	for i in spikes:
		var x := -width * 0.5 + width * (float(i) + 0.5) / float(spikes)
		draw_circle(Vector2(x, top - width * 0.30), maxf(width * 0.035, 1.5),
			Color(1.0, 0.25, 0.20, alpha))


func _draw_boss() -> void:
	## The boss fills its tile and spills over it, and changes with every phase:
	##   First Blade    — a lacquered red plate, one blade and her spear behind it.
	##   Twin Blades    — a second blade crossing the first, gold trim, a little larger.
	##   Rending Arts   — darker, larger, crowned, glowing claw marks across the plate.
	##   Crimson Finale — near-black, largest, a crown of five, fire licking round her
	##                    and a fan of every blade she has kept.
	## A thin bar of her own rides on top (the HUD carries the big one).
	var half := tile_size * 0.5
	var alpha := death_t if dying else 1.0
	var ph := boss_phase
	var t := Time.get_ticks_msec() * 0.001
	var grow: float = tile_size * float(BOSS_GROWTH[ph])
	var body := Rect2(-half + 1.0, -half + 1.0, tile_size - 2.0, tile_size - 2.0).grow(grow)
	var h := body.size.x * 0.5
	var plate: Color = BOSS_PLATES[ph]
	var w := maxf(tile_size * 0.07, 2.5)

	# Behind her: the aura, and in the finale the fire and the fan of blades.
	if ph >= 2:
		var pulse := 0.75 + 0.25 * sin(t * 3.0)
		draw_circle(Vector2.ZERO, h * (1.45 + 0.08 * pulse),
			Color(0.95, 0.12, 0.10, (0.10 if ph == 2 else 0.18) * pulse * alpha))
	if ph >= 3:
		for i in 6:
			var a := lerpf(-PI * 0.85, -PI * 0.15, float(i) / 5.0)
			var dir := Vector2(cos(a), sin(a))
			_boss_blade(dir * h * 0.95, dir * h * 1.85, w * 0.8, alpha, 0.6 + 0.4 * sin(t * 4.0 + i))
		for i in 10:
			var a := TAU * float(i) / 10.0 + t * 0.6
			var flick := 0.5 + 0.5 * sin(t * 9.0 + float(i) * 1.7)
			var at := Vector2(cos(a), sin(a)) * h * 1.12
			draw_colored_polygon(PackedVector2Array([at + Vector2(cos(a + 1.57), sin(a + 1.57)) * h * 0.14,
				at + Vector2(cos(a), sin(a)) * h * (0.32 + 0.22 * flick),
				at - Vector2(cos(a + 1.57), sin(a + 1.57)) * h * 0.14]),
				Color(1.0, 0.35 + 0.35 * flick, 0.10, 0.75 * alpha))

	# The plate.
	draw_rect(body.grow(3.0), Color(plate.darkened(0.6), 0.85 * alpha), true)
	draw_rect(body, Color(plate, alpha), true)
	var trim := Color(1.0, 0.78, 0.55, alpha) if ph == 0 else Color(0.98, 0.76, 0.30, alpha)
	draw_rect(body, trim, false, 3.0 + float(ph))
	if ph >= 1:
		draw_rect(body.grow(-5.0 - float(ph)), Color(trim, 0.5 * alpha), false, 1.5)

	# Claw marks, glowing, from the Rending Arts on.
	if ph >= 2:
		var glow := Color(1.0, 0.45, 0.25, (0.55 + 0.35 * sin(t * 5.0)) * alpha)
		for k in 3:
			var off := (float(k) - 1.0) * h * 0.28
			draw_line(Vector2(-h * 0.55 + off, -h * 0.7), Vector2(-h * 0.15 + off, h * 0.7),
				glow, maxf(w * 0.4, 1.5))

	if ph == 0:
		# Her spear, across the plate the other way and out past its corner.
		draw_line(Vector2(h * 0.80, h * 0.80), Vector2(-h * 1.0, -h * 1.0),
			Color(0.50, 0.26, 0.14, alpha), maxf(w * 0.55, 2.0))
		draw_colored_polygon(PackedVector2Array([Vector2(-h * 1.32, -h * 1.32),
			Vector2(-h * 0.92, -h * 1.10), Vector2(-h * 1.10, -h * 0.92)]),
			Color(0.92, 0.92, 0.95, alpha))
	# Her blades: one, then two crossed.
	_boss_blade(Vector2(-h * 0.62, h * 0.62), Vector2(h * 0.70, -h * 0.70), w, alpha,
		0.5 if ph >= 2 else 0.0)
	if ph >= 1:
		_boss_blade(Vector2(h * 0.62, h * 0.62), Vector2(-h * 0.70, -h * 0.70), w, alpha,
			0.5 if ph >= 2 else 0.0)

	# Crowned from the Rending Arts on; five points at the end.
	if ph >= 2:
		_boss_crown(body.position.y + 2.0, body.size.x * 0.62, 3 if ph == 2 else 5, alpha)
	# In the finale her eyes burn through the plate.
	if ph >= 3:
		for side in [-1.0, 1.0]:
			var eye := Vector2(h * 0.22 * side, -h * 0.28)
			draw_circle(eye, h * 0.11, Color(1.0, 0.30, 0.15, 0.45 * alpha))
			draw_circle(eye, h * 0.055, Color(1.0, 0.90, 0.60, alpha))
	if held != HELD_NONE:
		draw_rect(body.grow(5.0), Color(0.60, 0.82, 0.95, 0.9 * alpha), false, 2.0)
	if flash > 0.0:
		draw_rect(body, Color(1, 1, 1, 0.5 * flash), true)
	if dying:
		return
	# Under her rather than over: the crown sits on top from the third phase.
	var bar := Rect2(body.position.x + 1.0, body.end.y + 4.0, body.size.x - 2.0, 5.0)
	draw_rect(bar.grow(1.0), Color(0.02, 0.03, 0.05, 0.9), true)
	var filled := bar
	filled.size.x = bar.size.x * display_hp
	draw_rect(filled, Color(0.95, 0.25, 0.22), true)


func _draw_tier_pips(body: Rect2, tier: int, tint: Color, alpha: float, big := false) -> void:
	# One pip per tier along the bottom edge: countable without reading.
	var pip := maxf(tile_size * (0.11 if big else 0.055), 4.0 if big else 3.0)
	if big:
		# As big as the row will fit across the tile.
		pip = minf(pip, body.size.x / (float(tier) * 1.75 + 0.25))
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
	if unit.structure:
		_draw_crystal()
		return
	if unit.boss:
		_draw_boss()
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
	# Asked once and reused, so the plate and the art can never disagree about
	# whether there is a portrait — which would leave the muted "there is art
	# here" ground with nothing standing on it.
	var art_tex := portrait_for(unit.data)
	var fill: Color = unit.data.accent.lerp(tint, 0.06 * float(tier - 1))
	if art_tex != null:
		# Behind art, the accent has to stop competing with it: pulled most of the
		# way to grey and darkened well below the portrait's own midtones. It is
		# there to say whose unit this is and what tier, not to be looked at.
		fill = fill.lerp(Color(0.16, 0.17, 0.20), 0.62).darkened(0.15)
	fill.a = alpha
	draw_rect(body, fill, true)

	if art_tex != null:
		# Inset inside the plate so a rim of the muted ground shows all the way
		# round, and drawn HERE — after the plate, before the ring and the bars —
		# so nothing readable ends up underneath it.
		var art := body.grow(-4.0)
		draw_texture_rect(art_tex, art, false, Color(1, 1, 1, alpha))
	elif unit.data.id == SHADE_ID:
		# The boss's shades get a picture, not letters: "CRI" next to the army's own
		# three-letter units read as one more of yours.
		_draw_shade(body, alpha)
		_draw_summon_tier(body, alpha)
	elif unit.data.id == THORN_ID:
		_draw_thorn(body, alpha)
		_draw_summon_tier(body, alpha)
	elif unit.data.id == CHALICE_ID:
		_draw_chalice(body, alpha)
		_draw_summon_tier(body, alpha)
	elif unit.data.id == HEADHUNTER_ID:
		_draw_headhunter(body, alpha)
		_draw_summon_tier(body, alpha)
	elif unit.data.id == BERSERKER_ID:
		_draw_berserker(body, alpha)
		_draw_summon_tier(body, alpha)
	elif unit.data.id == THRALL_ID:
		_draw_thrall(body, alpha)
		_draw_summon_tier(body, alpha)
	elif unit.data.id == STALKER_ID:
		_draw_stalker(body, alpha)
		_draw_summon_tier(body, alpha)
	else:
		# Its short name, not an initial: with seven units starting "S" a single
		# letter told nobody anything. Unique across the roster — see short_name().
		var initial := short_name(unit.data)
		var font := ThemeDB.fallback_font
		var size := clampi(int(tile_size * 0.34), 8, 26)
		var w := font.get_string_size(initial, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
		# Light letters with a dark outline: they read on any accent colour, and on
		# a small tile they stay legible where dark ink on a dark plate did not.
		var ink := Color(0.98, 0.97, 0.94, 0.95 * alpha)
		var edge := Color(0.02, 0.02, 0.04, 0.9 * alpha)
		var edge_w := maxi(size / 4, 2)
		if _bold():
			# Boss defence: the letters THEMSELVES carry the tier, in a bright text
			# colour per tier and a heavier outline so each reads on any plate.
			ink = Color(tier_ink(tier), 0.98 * alpha)
			edge = Color(0.0, 0.0, 0.0, 0.95 * alpha)
			edge_w = maxi(size / 3, 3)
		if unit.team == player_team:
			draw_string_outline(font, Vector2(-w * 0.5, size * 0.36), initial,
				HORIZONTAL_ALIGNMENT_LEFT, -1, size, edge_w, edge)
			draw_string(font, Vector2(-w * 0.5, size * 0.36), initial,
				HORIZONTAL_ALIGNMENT_LEFT, -1, size, ink)
		else:
			# Rotated about the tile's own centre rather than the text baseline,
			# or the letter walks off the square. draw_set_transform replaces the
			# canvas transform outright, so it has to be reset afterwards — the
			# health bar and everything below draw in plain local space.
			draw_set_transform(Vector2.ZERO, PI, Vector2.ONE)
			draw_string_outline(font, Vector2(-w * 0.5, size * 0.36), initial,
				HORIZONTAL_ALIGNMENT_LEFT, -1, size, edge_w, edge)
			draw_string(font, Vector2(-w * 0.5, size * 0.36), initial,
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
	if tier >= APEX_TIER:
		# The apex halo. A tier 6 is the most expensive thing on the board — thirty-two
		# tier 1s — and until now it was distinguishable from a tier 5 only by a badge
		# reading "T6" and one extra pip, which is a lot of investment to express as a
		# number. Drawn OUTSIDE the team ring and the tier rim so it reads at a glance,
		# and in the tier colour so it says which tier rather than just "special".
		var halo := tint
		var pulse := 0.5 + 0.5 * sin(apex_t)
		# Two rings breathing against each other rather than one, so it does not read as
		# the empowered outline below, which is a single steady gold rectangle.
		halo.a = (0.30 + 0.30 * pulse) * alpha
		draw_arc(Vector2.ZERO, half + 2.0 + pulse * 2.0, 0.0, TAU, 40, halo, 2.5)
		halo.a = (0.14 + 0.16 * (1.0 - pulse)) * alpha
		draw_arc(Vector2.ZERO, half + 6.0 - pulse * 2.0, 0.0, TAU, 40, halo, 2.0)
		# Four slow motes turning around it. Motion is what separates "this unit is
		# important" from "this unit has a thicker border": a static glow stops being
		# visible after a minute of looking at the board.
		for i in 4:
			var ang: float = apex_t + float(i) * TAU / 4.0
			var at := Vector2(cos(ang), sin(ang)) * (half + 4.0)
			draw_circle(at, maxf(tile_size * 0.035, 2.0),
				Color(tint.lightened(0.45), (0.55 + 0.35 * pulse) * alpha))

	if unit.isolated and unit.data.alone_hp_damage > 0.0 and not dying:
		# Alone, and stronger for it: a calm pale ring, breathing slowly — it has found
		# its room.
		var calm := 0.5 + 0.5 * sin(Time.get_ticks_msec() * 0.003)
		draw_arc(Vector2.ZERO, half + 3.0 + calm * 2.0, 0.0, TAU, 32,
			Color(0.70, 0.85, 1.0, (0.35 + 0.35 * calm) * alpha), 2.0)

	if possessed:
		# Somebody else is driving. The team ring has already changed colour, so this has
		# to say something the colour cannot: that the body is on loan and goes back if
		# you kill what is inside it.
		var grip := Color(0.78, 0.50, 1.00, (0.85 + 0.15 * sin(possessed_t)) * alpha)
		# Corner brackets rather than another ring. Every other condition on this unit is
		# drawn as a ring or an outline, and a fourth one would be indistinguishable from
		# the other three at a glance.
		#
		# Drawn OUTSIDE the body rather than on it. The first version put them on the body
		# edge, where they sat on top of the portrait and under the tier rim, and a
		# screenshot showed them as a faint discolouration of a border that was already
		# two colours. Out here there is nothing else on that ring.
		var claws := body.grow(4.0)
		var claw := tile_size * 0.26
		var corners := [claws.position,
			Vector2(claws.end.x, claws.position.y),
			Vector2(claws.position.x, claws.end.y), claws.end]
		for i in corners.size():
			var c: Vector2 = corners[i]
			var sx := 1.0 if i == 0 or i == 2 else -1.0
			var sy := 1.0 if i < 2 else -1.0
			draw_line(c, c + Vector2(claw * sx, 0.0), grip, 3.0)
			draw_line(c, c + Vector2(0.0, claw * sy), grip, 3.0)
		# One mote at the centre: the thing inside it.
		draw_circle(body.get_center(), maxf(tile_size * 0.05, 3.0),
			Color(0.78, 0.56, 0.98, 0.55 * alpha))

	if unit.is_taunting():
		# A ring outside everything: it is the loudest thing on the board while
		# it lasts, and it should read that way.
		draw_arc(Vector2.ZERO, half - 1.0, 0.0, TAU, 28,
			Color(0.98, 0.78, 0.30, 0.90 * alpha), 3.0)

	# Held: stunned or frozen. Nothing on the unit itself said so before, and the
	# stun read as broken because of it — the tile flashed once when the charge
	# landed and then there was no way at all to tell that the unit standing there
	# was missing its turns. The two states get their own colour because they are
	# not the same thing: a freeze also amplifies damage and cancels what the victim
	# would have done on death.
	if held != HELD_NONE:
		var cold := held == HELD_FROZEN
		var mark := Color(0.60, 0.82, 0.95) if cold else Color(1.00, 0.86, 0.46)
		mark.a = 0.95 * alpha
		# A broken ring rather than a solid one, so it cannot be mistaken for the
		# taunt ring above it, and it spins so a held unit is never mistaken for a
		# unit that is simply idle.
		var spin: float = float(Time.get_ticks_msec()) * 0.004
		for i in 4:
			var from: float = spin + float(i) * TAU / 4.0
			draw_arc(Vector2.ZERO, half + 1.5, from, from + 0.55, 6, mark, 2.5)
		# Two pips above the body: stunned is one, frozen is two, so the difference
		# is readable without relying on colour alone.
		var pips := 2 if cold else 1
		for i in pips:
			draw_circle(Vector2((float(i) - float(pips - 1) * 0.5) * 6.0,
				-half - 7.0), 2.2, mark)

	if frenzied:
		# An empty health bar on a unit that is still swinging looks exactly like a
		# bug, so the tile has to say what is happening. Hot, moving, and drawn
		# OUTSIDE the team ring, because for these few seconds it is the most
		# important thing on the board.
		var beat := 0.55 + 0.45 * sin(frenzy_t)
		draw_rect(body.grow(2.0 + beat * 4.0),
			Color(1.00, 0.30, 0.26, (0.55 + 0.40 * beat) * alpha), false, 3.0)
		draw_rect(body, Color(0.95, 0.20, 0.22, 0.20 * beat * alpha), true)
		# Three turning spokes. A pulse alone would read as a buff; something that
		# turns reads as a clock, which is what this is.
		for i in 3:
			var ang: float = frenzy_t * 0.5 + float(i) * TAU / 3.0
			var dir := Vector2(cos(ang), sin(ang))
			draw_line(dir * (half - 2.0), dir * (half + 5.0 + beat * 3.0),
				Color(1.00, 0.46, 0.30, 0.9 * alpha), 2.5)

	if hidden_unit:
		draw_rect(body.grow(3.0), Color(0.62, 0.52, 0.85, 0.75 * alpha), false, 2.0)
	if engaged and not dying:
		# Crossed blades in the lower corner and a hot rim: "not healing right now,
		# fighting". A corner mark rather than a ring, because rings already mean
		# held, frenzied or reviving.
		draw_rect(body.grow(1.5), Color(0.98, 0.58, 0.32, 0.85 * alpha), false, 2.5)
		var c := Vector2(body.end.x - tile_size * 0.17, body.end.y - tile_size * 0.17)
		var r := maxf(tile_size * 0.11, 5.0)
		draw_circle(c, r + 2.0, Color(0.08, 0.06, 0.04, 0.80 * alpha))
		var blade := Color(1.00, 0.70, 0.40, alpha)
		draw_line(c + Vector2(-r, -r), c + Vector2(r, r), blade, 2.5)
		draw_line(c + Vector2(r, -r), c + Vector2(-r, r), blade, 2.5)
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
	# The tier, tiny, in the corner: the name in the middle is what identifies the
	# unit; the tier is a detail, and the pips along the edge say it again. Just the
	# digit in its tier colour with a thin dark outline — no chip behind it.
	var tt := str(tier)
	if _bold():
		# A badge: the tier's colour, its number in black, on the top-left corner and
		# hanging slightly off it so nothing on the tile covers it. The rim goes full
		# strength in the same colour.
		var ink := tier_ink(tier)
		draw_rect(body.grow(-1.0), Color(ink, 0.95 * alpha), false, 1.5 + 0.4 * float(tier))
		var r := clampf(tile_size * 0.2, 5.0, 14.0)
		# Centred nearly on the corner itself, so on the small tiles of the full field
		# it sits off the letters instead of on them.
		var at := body.position + Vector2(r * 0.15, r * 0.15)
		draw_circle(at, r + 1.2, Color(0, 0, 0, 0.9 * alpha))
		draw_circle(at, r, Color(ink, alpha))
		var bfs := maxi(roundi(r * 1.5), 7)
		var bw := tfont.get_string_size(tt, HORIZONTAL_ALIGNMENT_LEFT, -1, bfs).x
		draw_string(tfont, at + Vector2(-bw * 0.5, bfs * 0.36), tt,
			HORIZONTAL_ALIGNMENT_LEFT, -1, bfs, Color(0.02, 0.02, 0.04, alpha))
	else:
		var tfs := clampi(roundi(tile_size * 0.17), 7, 9)
		var chip := tint
		chip.a = alpha
		draw_string_outline(tfont, Vector2(-half + 3.0, -half + 2.0 + float(tfs)), tt,
			HORIZONTAL_ALIGNMENT_LEFT, -1, tfs, 2, Color(0.04, 0.05, 0.08, 0.9 * alpha))
		draw_string(tfont, Vector2(-half + 3.0, -half + 2.0 + float(tfs)), tt,
			HORIZONTAL_ALIGNMENT_LEFT, -1, tfs, chip)

	# On a small tile the pips would sit on the name; the corner number says it.
	if tier_squares and not unit.boss and not unit.structure and not is_summon_icon(unit.data.id):
		# The squares as the main look: big, bright, along the bottom, on any tile size.
		_draw_tier_pips(body, tier, tier_ink(tier), alpha, true)
	elif tile_size >= 44.0:
		_draw_tier_pips(body, tier, tint, alpha)

	if reeling:
		# Lost. Drawn as birds going round its head rather than as another ring: this unit
		# is not held in place — it is walking about — and a ring reads as "pinned",
		# which is what the stun and freeze marks already mean.
		#
		# LAST in the whole function, and that is not a style choice. The first version
		# drew it with the other conditions, up where the health bar and the damage
		# numbers go — and the bar is painted later, so it covered the motes completely.
		# A screenshot showed a unit with no mark on it at all.
		var swirl := Color(0.96, 0.88, 0.40, (0.80 + 0.20 * sin(reeling_t * 2.0)) * alpha)
		# Named for what it is rather than "ring" — the team ring already owns that name
		# further up this function, and reusing it does not shadow, it fails to compile.
		# A FLAT ellipse across the unit's middle, not a ring above its head. Above the
		# head was the obvious place and it is already occupied: the health readout and
		# the floating damage numbers live there, and a screenshot showed the motes
		# disappearing behind them completely. Across the body there is nothing else, and
		# a squashed orbit that passes in front of the portrait cannot be confused with
		# the tier 6 halo, which is a true circle outside the tile.
		var wide := half * 0.86
		var tall := half * 0.34
		for i in 3:
			var ang: float = reeling_t + float(i) * TAU / 3.0
			var at := body.get_center() + Vector2(cos(ang) * wide, sin(ang) * tall)
			# Each mote carries its own dark backing, because it is drawn over portrait
			# art rather than over a flat plate and a bare dot vanishes into a light one.
			draw_circle(at, maxf(tile_size * 0.075, 3.5),
				Color(0.08, 0.07, 0.04, 0.70 * alpha))
			draw_circle(at, maxf(tile_size * 0.055, 2.5), swirl)

	if flee_dir != Vector2.ZERO and not dying:
		# Running from a lit keg: two chevrons on the body, stacked one behind the
		# other and pointing AWAY from the keg's current tile, which BattlePlayer
		# re-aims every frame as the keg walks. Drawn on the body, late, for the same
		# reason the reeling motes are — up top is where the bar and the numbers go.
		var fwd := flee_dir.normalized()
		var side := Vector2(-fwd.y, fwd.x)
		var arm := tile_size * 0.16
		var ink := Color(1.00, 0.62, 0.26, 0.95 * alpha)
		for i in 2:
			var tip := body.get_center() + fwd * (tile_size * (0.04 + 0.17 * float(i)))
			var back := tip - fwd * arm
			for p in [back + side * arm, back - side * arm]:
				draw_line(p, tip, Color(0.06, 0.04, 0.02, 0.75 * alpha), 6.0)
				draw_line(p, tip, ink, 3.0)

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

	if isolation >= 0.0:
		# Isolation: fills while it stands alone, then runs down orange while it charges.
		var ib := Rect2(-half + BAR_INSET, -half - 3.0 + (4.5 if has_ability else 0.0),
			tile_size - BAR_INSET * 2.0, 3.5)
		draw_rect(ib, Color(0.08, 0.09, 0.14, 0.85 * alpha), true)
		var ifl := ib
		ifl.size.x = ib.size.x * isolation
		var icol := Color(1.0, 0.55, 0.30) if isolation_charging else Color(0.80, 0.62, 0.95)
		icol.a = alpha
		draw_rect(ifl, icol, true)

	var font := ThemeDB.fallback_font
	var hp_text := _compact(hp_cur)
	if shield > 0.0:
		hp_text += "+" + _compact(shield)
	var tw := font.get_string_size(hp_text, HORIZONTAL_ALIGNMENT_LEFT, -1, 13).x
	draw_string(font, Vector2(-tw * 0.5, -half - BAR_HEIGHT - 7.0), hp_text,
		HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color(0.80, 0.85, 0.92, alpha))
