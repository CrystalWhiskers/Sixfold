## Command-line entry point for the data generator.
##
##   godot --headless --script res://tools/generate_data.gd
##
## All the tables and logic live in DataBuilder (tools/data_builder.gd) so the
## editor button and the command line run exactly the same code.
extends SceneTree


func _initialize() -> void:
	print(DataBuilder.new().build())
	quit()
