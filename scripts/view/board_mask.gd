class_name BoardMask
extends Control

## A board bigger than its window has to be cut off somewhere. The board is a
## Node2D in the world and the HUD is a CanvasLayer over it, so painting the
## four bands around the window — under the HUD, over the board — is the
## cheapest honest clip available without moving the board into a SubViewport.

const BACKDROP := Color(0.055, 0.07, 0.095)
const EDGE := Color(0.26, 0.30, 0.37, 0.75)

var window := Rect2()


func set_window(r: Rect2) -> void:
	window = r
	queue_redraw()


func _draw() -> void:
	if window.size.x <= 0.0 or window.size.y <= 0.0:
		return
	var w := size.x
	var h := size.y
	draw_rect(Rect2(0.0, 0.0, w, window.position.y), BACKDROP, true)
	draw_rect(Rect2(0.0, window.end.y, w, h - window.end.y), BACKDROP, true)
	draw_rect(Rect2(0.0, window.position.y, window.position.x, window.size.y),
		BACKDROP, true)
	draw_rect(Rect2(window.end.x, window.position.y, w - window.end.x,
		window.size.y), BACKDROP, true)
	draw_rect(window, EDGE, false, 1.0)
