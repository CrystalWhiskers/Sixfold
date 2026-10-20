extends SceneTree

## Renders every ability icon, and the shapes that go with them, to a PNG so a change to
## AbilityFx can be looked at rather than guessed at. Godot cannot render in --headless,
## so run it with a window:
##
##     godot --path . --script res://tools/icon_gallery.gd
##
## It writes user://icon_gallery.png and quits.

const OUT_PATH := "user://icon_gallery.png"
const COLS := 4


func _initialize() -> void:
	# The project's own 720x1280 canvas, which the window is stretched to.
	var bg := ColorRect.new()
	bg.color = Color(0.10, 0.12, 0.16)
	bg.size = Vector2(720, 1280)
	root.add_child(bg)
	var fx := AbilityFx.new()
	fx.tile_size = 150.0
	root.add_child(fx)
	var font := ThemeDB.fallback_font
	var ids: Array = AbilityFx.GLYPHS.keys()
	ids.sort()
	var i := 0
	for id in ids:
		var at := Vector2(100 + (i % COLS) * 175, 115 + (i / COLS) * 150)
		fx.glyph(AbilityFx.GLYPHS[id][0], at, AbilityFx.GLYPHS[id][1], 10.0)
		var label := Label.new()
		label.text = String(id)
		label.position = at + Vector2(-70, 14)
		label.size = Vector2(140, 20)
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.add_theme_font_size_override("font_size", 12)
		root.add_child(label)
		i += 1
	# The moving shapes, caught part way through.
	var y := 1170.0
	fx.lance(Vector2(30, y), Vector2(260, y), AbilityFx.color_for(&"impale"), 10.0)
	fx.ring(Vector2(330, y), 20, 60, AbilityFx.color_for(&"war_horn"), 10.0)
	fx.tether(Vector2(400, y), Vector2(520, y), AbilityFx.color_for(&"siphon"), 10.0)
	fx.streak(Vector2(550, y + 20), Vector2(630, y - 30), AbilityFx.color_for(&"shadowstep"), 10.0)
	fx.impact(Vector2(680, y), AbilityFx.color_for(&"onslaught"), 10.0)
	# Glyphs settled (past the pop), the spear about half way down its line.
	fx._process(2.6)
	_shoot.call_deferred()


func _shoot() -> void:
	for k in 4:
		await RenderingServer.frame_post_draw
	var img := root.get_texture().get_image()
	var err := img.save_png(OUT_PATH)
	print("gallery: %s (%d)" % [ProjectSettings.globalize_path(OUT_PATH), err])
	quit()
