## One unit on screen. Reads a UnitInstance, owns no rules.
##
## SPRITES: drop a Texture2D into the unit's .tres (UnitData -> Presentation ->
## sprite) and it renders here automatically, scaled to fit the tile. Until then
## you get a coloured block with the unit's initial. Nothing else needs changing.
class_name UnitView
extends Node2D

const BAR_HEIGHT := 9.0
const BAR_INSET := 6.0
## How long a unit takes to visibly die. Without this it vanishes between frames
## and you can't tell a kill from a unit that walked off somewhere.
const DEATH_TIME := 0.35

@export var tile_size := 84.0

var unit: UnitInstance = null
## Health as the VIEW believes it, never read live off the instance.
##
## During playback the simulation has already run to completion, so the
## instance's current_hp is its end-of-battle value. Reading that live meant
## every bar showed its final state from the first frame of the replay.
## These are driven from the event log instead.
var hp_cur := 0.0
var hp_max := 1.0
var shield := 0.0        ## Drawn as a distinct segment; never healed.
var mana := 0.0          ## 0..UnitInstance.MANA_MAX
var has_ability := false
var display_hp := 1.0     ## Eased toward hp_cur so bars slide.
var flash := 0.0          ## 0..1, drives the hit flash.
var dimmed := false       ## Fog of war, or a unit being dragged elsewhere.
var dying := false
var death_t := 0.0        ## 1 -> 0 across DEATH_TIME.

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
	if unit != null and unit.data.sprite != null:
		_sprite.texture = unit.data.sprite
		_sprite.visible = true
		var tex_size := _sprite.texture.get_size()
		var fit := (tile_size - 10.0) / maxf(maxf(tex_size.x, tex_size.y), 1.0)
		_sprite.scale = Vector2(fit, fit)
	else:
		_sprite.visible = false


## Set by BattlePlayer from the event log during a replay.
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
	if dying:
		death_t = maxf(death_t - delta / DEATH_TIME, 0.0)
		display_hp = 0.0
		queue_redraw()
		return
	var target := hp_fraction()
	if not is_equal_approx(display_hp, target):
		# Fast enough that the bar has caught up before the unit dies. A slow
		# ease is what made it look like full-health units were vanishing.
		display_hp = move_toward(display_hp, target, delta * 4.0)
		queue_redraw()
	if flash > 0.0:
		flash = maxf(flash - delta * 4.0, 0.0)
		queue_redraw()


func hit() -> void:
	flash = 1.0
	queue_redraw()


## Starts the death animation. The view stays in the tree until it finishes,
## so the kill is something you actually see happen.
func die() -> void:
	if dying:
		return
	dying = true
	death_t = 1.0
	display_hp = 0.0
	queue_redraw()


func is_gone() -> bool:
	return dying and death_t <= 0.0


func team_color() -> Color:
	if unit == null:
		return Color.GRAY
	return Color(0.38, 0.66, 0.69) if unit.team == BoardModel.TEAM_A else Color(0.83, 0.63, 0.39)


func _draw() -> void:
	if unit == null:
		return
	var half := tile_size * 0.5
	var body := Rect2(-half + 5.0, -half + 5.0, tile_size - 10.0, tile_size - 10.0)
	var alpha := 0.45 if dimmed else 1.0
	if dying:
		# Shrink and fade together, so a death reads even at 4x playback speed.
		alpha *= death_t
		var shrink := (1.0 - death_t) * tile_size * 0.22
		body = body.grow(-shrink)

	# Fallback block, only when there's no sprite yet.
	if unit.data.sprite == null:
		var fill: Color = unit.data.accent
		fill.a = alpha
		draw_rect(body, fill, true)
		var initial := String(unit.data.display_name).substr(0, 1).to_upper()
		var font := ThemeDB.fallback_font
		var size := 30
		var w := font.get_string_size(initial, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
		draw_string(font, Vector2(-w * 0.5, 10.0), initial,
			HORIZONTAL_ALIGNMENT_LEFT, -1, size, Color(0, 0, 0, 0.65 * alpha))

	# Team ring. This is how you tell sides apart before art exists.
	var ring := team_color()
	ring.a = alpha
	draw_rect(body, ring, false, 3.0)

	# Hit flash.
	if flash > 0.0:
		draw_rect(body, Color(1, 1, 1, 0.55 * flash), true)

	# Tier pips, top-left. One dot per tier above 1.
	for i in maxi(unit.data.tier - 1, 0):
		draw_circle(Vector2(-half + 12.0 + i * 10.0, -half + 12.0), 3.5,
			Color(1, 1, 1, 0.9 * alpha))

	if dying:
		# A clear cross, so a corpse is never mistaken for a live unit mid-fade.
		var k := body.grow(-body.size.x * 0.28)
		var cross := Color(0.88, 0.34, 0.30, alpha)
		draw_line(k.position, k.position + k.size, cross, 3.0)
		draw_line(Vector2(k.position.x + k.size.x, k.position.y),
			Vector2(k.position.x, k.position.y + k.size.y), cross, 3.0)
		return

	# Health bar, sitting ABOVE the unit rather than tucked inside its bottom
	# edge — it was previously easy to mistake for part of the art.
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

	# Shield rides on the right-hand end of the same bar, in a colour nothing
	# else uses. It has to be legible at a glance that a Warden's front half is
	# temporary hit points that no healing will bring back.
	if shield > 0.0:
		var frac: float = clampf(shield / hp_max, 0.0, 1.0)
		var sh := bar
		sh.size.x = bar.size.x * frac
		sh.position.x = bar.position.x + bar.size.x - sh.size.x
		draw_rect(sh, Color(0.53, 0.79, 0.92, alpha), true)

	# Mana, a thin strip under the health bar. Only for units that have an
	# ability — an empty track on everyone else would just be noise.
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

	# Numeric HP above the bar. Removes any doubt about whether something is
	# clinging on at 3 health or already gone.
	var font := ThemeDB.fallback_font
	var hp_text := "%d" % maxi(ceili(hp_cur), 0)
	if shield > 0.0:
		hp_text += "+%d" % roundi(shield)
	var tw := font.get_string_size(hp_text, HORIZONTAL_ALIGNMENT_LEFT, -1, 13).x
	draw_string(font, Vector2(-tw * 0.5, -half - BAR_HEIGHT - 7.0), hp_text,
		HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color(0.80, 0.85, 0.92, alpha))
