@tool
extends EditorScript


func _run() -> void:
	print(DataBuilder.new().build())
	EditorInterface.get_resource_filesystem().scan()
