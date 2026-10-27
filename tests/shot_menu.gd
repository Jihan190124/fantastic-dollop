extends Node
func _ready() -> void:
	var m = load("res://scenes/main_menu.tscn").instantiate()
	add_child(m)
	for i in 4:
		await get_tree().process_frame
	get_viewport().get_texture().get_image().save_png("/tmp/shot_menu.png")
	get_tree().quit()
