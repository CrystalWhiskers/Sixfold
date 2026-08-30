## Editor entry point for the data generator.
##
## Open this file in the Script editor and press File > Run (Ctrl+Shift+X).
## No terminal, no PATH, no arguments — this exists because needing a command
## line to retune a stat block is a bad way to spend an afternoon.
##
## It rebuilds every .tres in res://data/ from the tables in DataBuilder, and
## deletes any file those tables no longer produce.
@tool
extends EditorScript


func _run() -> void:
	print(DataBuilder.new().build())
	EditorInterface.get_resource_filesystem().scan()
