class_name TipPanel
extends RefCounted

const DEFAULT_WIDTH := 300.0


static func build(text: String, width := DEFAULT_WIDTH, font_size := 13) -> Control:
	var panel := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.07, 0.08, 0.11, 0.98)
	style.border_color = Color(0.34, 0.38, 0.46)
	style.set_border_width_all(1)
	style.set_corner_radius_all(6)
	style.set_content_margin_all(10)
	panel.add_theme_stylebox_override("panel", style)

	var label := Label.new()
	label.text = text
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.custom_minimum_size = Vector2(width, 0.0)
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", Color(0.86, 0.89, 0.94))
	panel.add_child(label)
	return panel
