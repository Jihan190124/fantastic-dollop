extends Control
## Boot screen: New Game, Continue, Settings, Credits, version.

const K = preload("res://scripts/ui/ui_kit.gd")
var menu_box: VBoxContainer
var info: Label
var modal: PanelContainer
var modal_body: VBoxContainer
var t := 0.0

func _ready() -> void:
	theme = K.make_theme(float(Game.settings.ui_scale))
	Game.in_game = false
	var center := VBoxContainer.new()
	K.anchor(center, 0.5, 0.5, 0.5, 0.5, -230, -250, 230, 250)
	center.add_theme_constant_override("separation", 12)
	add_child(center)
	var t1 := K.label("CINEMA TYCOON", 56, Color(1, 0.85, 0.35))
	t1.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	center.add_child(t1)
	var t2 := K.label("THEATRE EMPIRE", 34, Color(0.95, 0.5, 0.55))
	t2.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	center.add_child(t2)
	menu_box = center
	var saved: Dictionary = SaveSys.peek()
	var cont := K.button("Continue", _continue, 0, 68)
	cont.disabled = saved.is_empty()
	center.add_child(cont)
	center.add_child(K.button("New Game", _new_pressed, 0, 68))
	center.add_child(K.button("Settings", _settings, 0, 60))
	center.add_child(K.button("Credits", _credits, 0, 60))
	info = K.label("", 18, Color(0.7, 0.75, 0.9))
	info.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	if not saved.is_empty():
		var g := Data.as_dict(saved.game)
		info.text = "Saved game: Day %d, %s" % [int(g.get("day", 1)), Data.money(int(Data.as_dict(saved.economy).get("cash", 0)))]
	center.add_child(info)
	var ver := K.label("Version %s  |  Fully offline" % Data.VERSION, 16, Color(0.55, 0.6, 0.75))
	K.anchor(ver, 0, 1, 0, 1, 12, -34, 300, -6)
	add_child(ver)
	modal = PanelContainer.new()
	K.anchor(modal, 0.5, 0.5, 0.5, 0.5, -330, -230, 330, 230)
	modal.visible = false
	add_child(modal)
	modal_body = VBoxContainer.new()
	modal.add_child(modal_body)

func _process(delta: float) -> void:
	t += delta
	queue_redraw()

func _draw() -> void:
	var s := size
	draw_rect(Rect2(Vector2.ZERO, s), Color(0.07, 0.06, 0.14))
	for i in 60:
		var x := fposmod(float(i) * 97.3 + t * (4.0 + i % 5), s.x)
		var y := fposmod(float(i) * 53.7, s.y * 0.7)
		draw_circle(Vector2(x, y), 1.0 + i % 3 * 0.6, Color(1, 1, 1, 0.35 + 0.25 * sin(t * 2.0 + i)))
	var base := s.y * 0.88
	for i in 14:
		var w := s.x / 14.0
		var h := 60.0 + float((i * 37) % 5) * 28.0
		draw_rect(Rect2(i * w, base - h, w - 4, h + s.y), Color(0.12, 0.1, 0.22))
		for k in 4:
			if (i * 3 + k) % 3 != 0:
				draw_rect(Rect2(i * w + 8 + k * 14, base - h + 12 + (k % 2) * 20, 8, 10), Color(1, 0.85, 0.4, 0.6))

func _continue() -> void:
	if SaveSys.load_game():
		get_tree().change_scene_to_file("res://scenes/game_world.tscn")
	else:
		info.text = "Save could not be loaded."

func _new_pressed() -> void:
	if SaveSys.has_save():
		_open_modal("Start a new game?")
		modal_body.add_child(K.label("Your existing save is kept until the new game autosaves over it.", 20, Color(1, 0.85, 0.5), true))
		modal_body.add_child(K.button("Start new game", _start_new, 0, 60))
		modal_body.add_child(K.button("Cancel", func(): modal.visible = false, 0, 60))
	else:
		_start_new()

func _start_new() -> void:
	Game.new_game()
	get_tree().change_scene_to_file("res://scenes/game_world.tscn")

func _open_modal(title: String) -> void:
	K.clear(modal_body)
	modal_body.add_child(K.label(title, 30, Color(1, 0.9, 0.5)))
	modal.visible = true

func _settings() -> void:
	_open_modal("Settings")
	var cb := CheckBox.new()
	cb.text = "Autosave"
	cb.button_pressed = Game.settings.autosave
	cb.toggled.connect(func(v): Game.settings.autosave = v; Game.save_settings())
	modal_body.add_child(cb)
	var cb2 := CheckBox.new()
	cb2.text = "Floating money text"
	cb2.button_pressed = Game.settings.fx
	cb2.toggled.connect(func(v): Game.settings.fx = v; Game.save_settings())
	modal_body.add_child(cb2)
	modal_body.add_child(K.label("Maximum guests inside at once", 20))
	var ob := OptionButton.new()
	var opts := [25, 45, 70]
	for o in opts:
		ob.add_item("%d guests" % o)
	ob.select(opts.find(int(Game.settings.max_customers)) if int(Game.settings.max_customers) in opts else 1)
	ob.item_selected.connect(func(i): Game.settings.max_customers = opts[i]; Game.save_settings())
	modal_body.add_child(ob)
	modal_body.add_child(K.button("Close", func(): modal.visible = false, 0, 60))

func _credits() -> void:
	_open_modal("Credits")
	modal_body.add_child(K.label("Cinema Tycoon: Theatre Empire\nMade with Godot 4 and GDScript.\nAll graphics are drawn procedurally; all movie titles are fictional.\nNo internet, accounts or ads.", 22, Color.WHITE, true))
	modal_body.add_child(K.button("Close", func(): modal.visible = false, 0, 60))
