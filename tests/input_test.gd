extends Node
func _ready() -> void:
	await get_tree().process_frame
	Game.new_game()
	var w = load("res://scenes/game_world.tscn").instantiate()
	add_child(w)
	await get_tree().process_frame
	w.sim_step(3.0)
	var z0: float = w.camera.zoom.x
	var ev := InputEventMouseButton.new()
	ev.button_index = MOUSE_BUTTON_WHEEL_UP
	ev.pressed = true
	w.on_touch_input(ev)
	print("zoom ", z0, " -> ", w.camera.zoom.x)
	# tap on ticket counter
	var wp := Vector2(5 * 40 + 20, 15 * 40 + 20)
	var sp: Vector2 = w.get_viewport().get_canvas_transform() * wp
	var d := InputEventMouseButton.new(); d.button_index = MOUSE_BUTTON_LEFT; d.pressed = true; d.position = sp
	w.on_touch_input(d)
	var u := InputEventMouseButton.new(); u.button_index = MOUSE_BUTTON_LEFT; u.pressed = false; u.position = sp
	w.on_touch_input(u)
	print("selected: ", w.selected.get("type"), " ctx visible=", w.ui.ctx.visible, " body=", w.ui.ctx_body.text.replace("\n", " | "))
	# drag pans
	var p0: Vector2 = w.camera.position
	var d2 := InputEventMouseButton.new(); d2.button_index = MOUSE_BUTTON_LEFT; d2.pressed = true; d2.position = Vector2(300, 300)
	w.on_touch_input(d2)
	var m := InputEventMouseMotion.new(); m.relative = Vector2(-80, -40); m.position = Vector2(220, 260)
	w.on_touch_input(m)
	print("pan moved: ", p0, " -> ", w.camera.position)
	for s in ["build", "upgrades", "staff", "food", "shows", "finance", "overview", "achievements", "settings", "menu"]:
		w.ui.open_screen(s)
		w.ui.close_screen()
	print("screens ok")
	get_tree().quit()
