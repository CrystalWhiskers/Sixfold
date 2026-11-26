extends SceneTree

## Builds only the Bannerman, its Rally Banner and its Colours buff, and adds it to
## the roster — no other generated file is touched.
##
##   godot --headless --script res://tools/build_bannerman.gd


func _initialize() -> void:
	print(DataBuilder.new().build_only([&"bannerman", &"rally_banner", &"colours"]))
	quit()
