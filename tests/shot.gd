extends Node
## Renders screenshots of the running game (needs a display, e.g. xvfb). Dev tool only.
var world
func snap(name: String) -> void:
	await get_tree().process_frame
	await get_tree().process_frame
	var img := get_viewport().get_texture().get_image()
	img.save_png("/tmp/shot_%s.png" % name)

func _ready() -> void:
	await get_tree().process_frame
	Game.new_game()
	world = load("res://scenes/game_world.tscn").instantiate()
	add_child(world)
	await get_tree().process_frame
	world.manual_step = true
	Economy.earn(60000, "Test funding", "bonus")
	Game.reputation = 40.0
	Upgrades.hire("server"); Upgrades.hire("cleaner")
	Upgrades.buy("food"); Upgrades.buy("seats"); Upgrades.buy("lobby")
	Upgrades.buy_decor("posters"); Upgrades.buy_decor("plants")
	world.sync_staff()
	for i in 1400:
		world.sim_step(0.1)
	world.zones.clear()
	world.focus(Vector2(800,560), 0.1)
	await snap("a_world")
	world.focus(Vector2(1000, 280), 1.4)
	world.select({"type": "hall", "hall": 0, "rect": Rect2(24 * 40, 40, 600, 280)})
	await snap("b_hall")
	world.focus(Vector2(820, 560), 0.9)
	world.select({})
	world.ui.open_screen("upgrades")
	await snap("c_upgrades")
	world.ui.open_screen("shows")
	await snap("d_shows")
	world.ui.open_screen("overview")
	await snap("e_overview")
	get_tree().quit()
