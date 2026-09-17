extends Node

## Renders a screen to a PNG so a visual change can be LOOKED at instead of guessed at.
##
## This exists because three real bugs in the title screen were invisible to a passing
## test suite and obvious in the first screenshot: the board was fitted to the window's
## height and overflowed a portrait window sideways, the grid was drawn loud enough to
## compete with the menu, and the darkening meant to sit behind the buttons peaked at the
## centre of the screen and left the title sitting on top of a unit. None of those are
## things a check can assert; all three took one look.
##
## Run it with a virtual display, because Godot cannot render in --headless:
##
##     xvfb-run -a godot --path . tools/screenshot.tscn
##
## It writes to OUT_PATH and quits.

const SCENE := "res://scenes/menu.tscn"
const OUT_PATH := "user://screenshot.png"

## Seconds of simulated time to run the menu backdrop before the shot, so the picture
## shows a battle in progress rather than two untouched lines on the opening bell.
const WARM_SECONDS := 4.5

var _screen: Control = null


func _ready() -> void:
	var packed := load(SCENE) as PackedScene
	if packed == null:
		push_error("Could not load %s" % SCENE)
		get_tree().quit()
		return
	_screen = packed.instantiate() as Control
	add_child(_screen)
	await get_tree().process_frame
	await get_tree().process_frame
	_warm()
	# Waiting on frame_post_draw rather than process_frame: the viewport's texture is only
	# what you think it is AFTER the draw, and grabbing it a frame early gives a blank or
	# half-built image.
	for i in 4:
		await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	var err := img.save_png(OUT_PATH)
	print("screenshot: %s (%d)" % [ProjectSettings.globalize_path(OUT_PATH), err])
	get_tree().quit()


func _warm() -> void:
	## Drives the backdrop by hand. It cannot be done by waiting for frames: off a virtual
	## display the frames run as fast as the machine allows, so a hundred of them are a
	## few milliseconds of battle and nothing has moved.
	for child in _screen.get_children():
		if not (child is MenuBackdrop):
			continue
		var backdrop := child as MenuBackdrop
		for i in int(WARM_SECONDS / 0.1):
			backdrop._process(0.1)
		backdrop.queue_redraw()
