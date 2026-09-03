extends SceneTree


func _initialize() -> void:
	print(DataBuilder.new().build())
	quit()
