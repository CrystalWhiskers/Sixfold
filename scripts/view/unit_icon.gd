class_name UnitIcon
extends Control

## The unit's own sprite when it has one, and the board's placeholder look when
## it does not — same accent, same initial, same tier chip, so a slot in the
## menu and a tile on the board read as the same unit.

var unit: UnitData = null
var show_tier := true


func set_unit(d: UnitData) -> void:
	unit = d
	queue_redraw()


func _draw() -> void:
	var body := Rect2(Vector2.ZERO, size).grow(-1.0)
	if unit == null:
		draw_rect(body, Color(0.12, 0.13, 0.17), true)
		draw_rect(body, Color(0.30, 0.33, 0.40), false, 1.0)
		return

	var art := UnitView.portrait_for(unit)
	if art != null:
		draw_rect(body, Color(0.10, 0.11, 0.15), true)
		var tex := art.get_size()
		var fit: float = minf(body.size.x / maxf(tex.x, 1.0),
			body.size.y / maxf(tex.y, 1.0))
		var span := tex * fit
		draw_texture_rect(art,
			Rect2(body.get_center() - span * 0.5, span), false)
	else:
		draw_rect(body, unit.accent, true)
		var font := ThemeDB.fallback_font
		var initial := String(unit.display_name).substr(0, 1).to_upper()
		var pt := int(maxf(body.size.y * 0.52, 10.0))
		var w := font.get_string_size(initial, HORIZONTAL_ALIGNMENT_LEFT, -1, pt).x
		draw_string(font, body.get_center() + Vector2(-w * 0.5, pt * 0.36),
			initial, HORIZONTAL_ALIGNMENT_LEFT, -1, pt, Color(0, 0, 0, 0.62))

	var tint := UnitView.tier_color(unit.tier)
	draw_rect(body, Color(tint, 0.75), false, 2.0)

	if not show_tier or unit.tier <= 1:
		return
	var chip := Rect2(body.position + Vector2(2.0, 2.0), Vector2(15.0, 12.0))
	draw_rect(chip, tint, true)
	var tf := ThemeDB.fallback_font
	var tt := "%d" % unit.tier
	var tw := tf.get_string_size(tt, HORIZONTAL_ALIGNMENT_LEFT, -1, 10).x
	draw_string(tf, chip.position + Vector2((chip.size.x - tw) * 0.5, 9.5), tt,
		HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color(0.06, 0.07, 0.10))
