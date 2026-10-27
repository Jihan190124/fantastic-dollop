extends Node2D
## The cinema: builds the map, runs the simulation loop, handles camera + selection.

const C := 40
const NavGrid = preload("res://scripts/navigation_manager.gd")
const ServiceCounter = preload("res://scripts/service_counter.gd")
const WorldView = preload("res://scripts/world_view.gd")
const LiveLayer = preload("res://scripts/live_layer.gd")
const FxLayer = preload("res://scripts/fx_layer.gd")
const GameUI = preload("res://scripts/ui/game_ui.gd")
const CustomerScene = preload("res://scenes/customer.tscn")
const StaffScene = preload("res://scenes/staff_member.tscn")

var nav
var view
var live
var actors: Node2D
var fx
var camera: Camera2D
var ui
var ticket_counter
var food_counter
var customers: Array = []
var staff_nodes: Array = []
var litter: Array = []
var zones: Array = []
var selected: Dictionary = {}
var spawn_acc := 0.0
var next_uid := 1
var nav_failures := 0
var manual_step := false

var touches := {}
var pinch_last := 0.0
var press_pos := Vector2.ZERO
var pressing := false
var dragged := 0.0

func _ready() -> void:
	if not Game.in_game:
		Game.new_game()
	nav = NavGrid.new()
	view = WorldView.new()
	view.world = self
	add_child(view)
	live = LiveLayer.new()
	live.world = self
	add_child(live)
	actors = Node2D.new()
	actors.y_sort_enabled = true
	add_child(actors)
	fx = FxLayer.new()
	add_child(fx)
	fx.set_process(false)
	camera = Camera2D.new()
	add_child(camera)
	ticket_counter = ServiceCounter.new()
	ticket_counter.setup("cashier", Data.TICKET_SPOTS, Data.TICKET_QUEUE)
	food_counter = ServiceCounter.new()
	food_counter.setup("server", Data.FOOD_SPOTS, Data.FOOD_QUEUE)
	var n: int = Game.litter_count
	Game.litter_count = 0
	for i in n:
		add_litter(_random_lobby_pos())
	sync_staff()
	ui = GameUI.new()
	ui.world = self
	add_child(ui)
	Upgrades.changed.connect(_on_upgrade)
	Game.day_started.connect(func(_d): spawn_acc = 0.0)
	camera.make_current()
	camera.position = Vector2(820, 560)
	camera.zoom = Vector2.ONE * maxf(_min_zoom(), 0.72)
	_clamp_camera()
	get_tree().root.size_changed.connect(_clamp_camera)

func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_GO_BACK_REQUEST and ui:
		ui.open_screen("menu")

# --- Simulation ---------------------------------------------------------------------------
func _process(delta: float) -> void:
	if manual_step:
		return
	if Game.speed > 0 and not Game.summary_open:
		sim_step(minf(delta, 0.1) * Game.speed)
	for z in zones:
		z.t += delta
	var done := zones.filter(func(z): return z.t >= z.dur)
	for z in done:
		fx.burst(z.rect.get_center(), Color(1, 0.85, 0.3), 24)
		fx.add_text(z.rect.get_center(), "Done!", Color(0.6, 1, 0.6), 26)
		view.queue_redraw()
	zones = zones.filter(func(z): return z.t < z.dur)

func sim_step(dt: float) -> void:
	var rem := dt
	while rem > 0.0:
		var h := minf(rem, 0.1)
		rem -= h
		_sim(h)

func _sim(dt: float) -> void:
	Game.tick(dt)
	_spawn(dt)
	ticket_counter.update(dt)
	food_counter.update(dt)
	for c in customers:
		c.step(dt)
	for s in staff_nodes:
		s.step(dt)
	for i in range(customers.size() - 1, -1, -1):
		if customers[i].state == 11:
			customers[i].queue_free()
			customers.remove_at(i)
	_check_day_end()

func _spawn(dt: float) -> void:
	if Game.phase != "open" or not Screenings.any_sellable(Game.clock):
		return
	spawn_acc = minf(spawn_acc + Game.arrival_rate() * dt * Data.GAME_MIN_PER_SEC / 60.0, 2.0)
	if spawn_acc >= 1.0 and customers.size() < int(Game.settings.max_customers):
		spawn_acc -= 1.0
		spawn_customer()

func spawn_customer() -> void:
	var c = CustomerScene.instantiate()
	actors.add_child(c)
	c.setup(self, Data.pick_type(Game.reputation, Game.campaign_target()), next_uid)
	next_uid += 1
	c.position = Data.cell_center(Data.SPAWN_CELL) + Vector2(randf_range(-30, 30), 20)
	customers.append(c)
	Game.day_stats.arrived += 1

func _check_day_end() -> void:
	if Game.phase != "closing":
		return
	if (customers.is_empty() and not Screenings.any_active()) or Game.clock >= Data.FORCE_END_HOUR:
		for c in customers:
			c.force_finish()
			c.queue_free()
		customers.clear()
		ticket_counter.queue.clear()
		food_counter.queue.clear()
		for s in ticket_counter.slots + food_counter.slots:
			s.c = null
			s.t = -1.0
		Game.end_day()

# --- Litter -----------------------------------------------------------------------------
func _random_lobby_pos() -> Vector2:
	for i in 20:
		var cell := Vector2i(randi_range(2, 21), randi_range(8, 22))
		if not nav.is_solid(cell):
			return Data.cell_center(cell) + Vector2(randf_range(-10, 10), randf_range(-10, 10))
	return Data.cell_center(Data.ENTRY_CELL)

func add_litter(pos: Vector2) -> void:
	if litter.size() >= Data.MAX_LITTER:
		return
	litter.append({"pos": pos, "claimed": false, "k": randi() % 3, "cell": nav.nearest_free(Data.cell_of(pos))})
	Game.litter_count = litter.size()

func claim_litter(from: Vector2):
	var best = null
	var bd := INF
	for l in litter:
		if l.claimed:
			continue
		var d: float = from.distance_squared_to(l.pos)
		if d < bd:
			bd = d
			best = l
	if best != null:
		best.claimed = true
	return best

func remove_litter(l) -> void:
	litter.erase(l)
	Game.litter_count = litter.size()

# --- Staff --------------------------------------------------------------------------------
func sync_staff() -> void:
	for role in ["cashier", "server", "cleaner", "technician"]:
		var want: int = Upgrades.staff_count(role)
		var have: Array = staff_nodes.filter(func(s): return s.role == role)
		while have.size() < want:
			var s = StaffScene.instantiate()
			actors.add_child(s)
			s.setup(self, role, have.size())
			staff_nodes.append(s)
			have.append(s)
		while have.size() > want:
			var s2 = have.pop_back()
			if s2.target_litter != null:
				s2.target_litter.claimed = false
			staff_nodes.erase(s2)
			s2.queue_free()
	ticket_counter.staff_list = staff_nodes.filter(func(s): return s.role == "cashier")
	food_counter.staff_list = staff_nodes.filter(func(s): return s.role == "server")

# --- Upgrade feedback -----------------------------------------------------------------------
func _zone(rect: Rect2, label: String, dur: float = 2.5) -> void:
	zones.append({"rect": rect, "t": 0.0, "dur": dur, "label": label})

func _on_upgrade(kind: String, id: String) -> void:
	match kind:
		"track":
			match id:
				"seats":
					for i in 3:
						if Upgrades.hall_ready(i):
							var r: Rect2i = Data.HALLS[i].rect
							_zone(Rect2((r.position.x + 1) * C, (r.position.y + 2) * C, (r.size.x - 2) * C, 4 * C), "INSTALLING SEATS")
				"projector", "audio":
					for i in 3:
						if Upgrades.hall_ready(i):
							var r2: Rect2i = Data.HALLS[i].rect
							_zone(Rect2(r2.position.x * C, r2.position.y * C, r2.size.x * C, 2 * C), "INSTALLING %s" % id.to_upper())
				"lobby":
					_zone(Rect2(1 * C, 7 * C, 22 * C, 17 * C), "RENOVATING LOBBY")
				"food":
					_zone(Rect2(14 * C, 14 * C, 6 * C, 3 * C), "BUILDING FOOD AREA")
					if Upgrades.level("food") >= 4:
						_zone(Rect2(10 * C, 9 * C, 9 * C, 3 * C), "BUILDING FOOD COURT")
				"training":
					_zone(Rect2(1 * C, 1 * C, 8 * C, 5 * C), "TRAINING")
			nav.rebuild()
		"decor":
			var rects := {"posters": Rect2(3 * C, 6 * C, 18 * C, 2 * C), "plants": Rect2(1 * C, 7 * C, 21 * C, 17 * C),
				"carpet": Rect2(10 * C, 15 * C, 3 * C, 9 * C), "neon": Rect2(7 * C, 24 * C, 9 * C, 1 * C),
				"arcade": Rect2(19 * C, 9 * C, 3 * C, 3 * C)}
			_zone(rects[id], "INSTALLING")
			nav.rebuild()
		"hall_done":
			var i2 := int(id)
			var rr: Rect2i = Data.HALLS[i2].rect
			fx.burst(Vector2(rr.get_center()) * C, Color(1, 0.85, 0.3), 30)
			fx.add_text(Vector2(rr.get_center()) * C, "%s OPEN!" % Data.HALLS[i2].name, Color(0.6, 1, 0.6), 30)
			Game.toast.emit("%s is now open for business!" % Data.HALLS[i2].name, Color(0.5, 0.9, 0.5))
			nav.rebuild()
		"hall_start":
			nav.rebuild()
		"staff":
			sync_staff()
	view.queue_redraw()

func fx_money(pos: Vector2, amount: int) -> void:
	fx.add_text(pos, "+" + Data.money(amount), Color(0.4, 1.0, 0.4), 20)

# --- Selection -----------------------------------------------------------------------------
func pick_at(p: Vector2) -> Dictionary:
	var best = null
	var bd := 28.0
	for c in customers:
		var d: float = c.position.distance_to(p + Vector2(0, 6))
		if d < bd:
			bd = d
			best = c
	if best != null:
		return {"type": "customer", "node": best, "rect": Rect2(best.position - Vector2(16, 30), Vector2(32, 44))}
	for s in staff_nodes:
		if s.position.distance_to(p + Vector2(0, 6)) < 24.0:
			return {"type": "staff", "node": s, "rect": Rect2(s.position - Vector2(16, 30), Vector2(32, 44))}
	var cell := Data.cell_of(p)
	for i in 3:
		var r: Rect2i = Data.HALLS[i].rect
		if r.has_point(cell):
			if Upgrades.hall_ready(i):
				var seats: Array = Data.hall_seats(i)
				for si in seats.size():
					if seats[si].cell == cell:
						return {"type": "seat", "hall": i, "seat": si, "rect": Rect2(cell * C, Vector2(C, C))}
			return {"type": "hall", "hall": i, "rect": Rect2(r.position * C, r.size * C)}
	if Rect2i(3, 14, 5, 3).has_point(cell):
		return {"type": "tickets", "rect": Rect2(3 * C, 14 * C, 5 * C, 3 * C)}
	if Rect2i(14, 14, 6, 3).has_point(cell):
		return {"type": "food", "rect": Rect2(14 * C, 14 * C, 6 * C, 3 * C)}
	if Rect2i(17, 1, 6, 5).has_point(cell):
		return {"type": "toilets", "rect": Rect2(17 * C, 1 * C, 6 * C, 5 * C)}
	if Rect2i(10, 1, 6, 5).has_point(cell):
		return {"type": "storage", "rect": Rect2(10 * C, 1 * C, 6 * C, 5 * C)}
	if Rect2i(1, 1, 8, 5).has_point(cell):
		return {"type": "staffroom", "rect": Rect2(1 * C, 1 * C, 8 * C, 5 * C)}
	return {}

func select(sel: Dictionary) -> void:
	selected = sel
	ui.show_context(sel)

# --- Camera & input --------------------------------------------------------------------------
func _min_zoom() -> float:
	var vp := get_viewport_rect().size
	return minf(vp.x / Data.WORLD_SIZE.x, (vp.y - 150.0) / Data.WORLD_SIZE.y)

func _clamp_camera() -> void:
	if camera == null:
		return
	var vp := get_viewport_rect().size
	camera.zoom = Vector2.ONE * clampf(camera.zoom.x, _min_zoom(), 2.6)
	var half := vp / (2.0 * camera.zoom.x)
	var pos := camera.position
	pos.x = Data.WORLD_SIZE.x * 0.5 if half.x * 2.0 >= Data.WORLD_SIZE.x else clampf(pos.x, half.x, Data.WORLD_SIZE.x - half.x)
	pos.y = Data.WORLD_SIZE.y * 0.5 if half.y * 2.0 >= Data.WORLD_SIZE.y else clampf(pos.y, half.y - 75.0 / camera.zoom.x, Data.WORLD_SIZE.y - half.y + 80.0 / camera.zoom.x)
	camera.position = pos

func zoom_by(f: float) -> void:
	camera.zoom = Vector2.ONE * clampf(camera.zoom.x * f, _min_zoom(), 2.6)
	_clamp_camera()

func focus(p: Vector2, z: float = 1.1) -> void:
	camera.zoom = Vector2.ONE * clampf(z, _min_zoom(), 2.6)
	camera.position = p
	_clamp_camera()

func _pinch_dist() -> float:
	var v := touches.values()
	return (v[0] as Vector2).distance_to(v[1])

func _input(event: InputEvent) -> void:
	if ui == null or ui.modal_open():
		return
	if event is InputEventScreenTouch:
		if event.pressed:
			touches[event.index] = event.position
		else:
			touches.erase(event.index)
		if touches.size() == 2:
			pinch_last = _pinch_dist()
			dragged = 999.0
	elif event is InputEventScreenDrag:
		touches[event.index] = event.position
		if touches.size() == 2:
			var d := _pinch_dist()
			if pinch_last > 1.0:
				zoom_by(d / pinch_last)
			pinch_last = d

## Receives events from the full-screen touch layer in the UI (single finger / mouse).
func on_touch_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP and event.pressed:
			zoom_by(1.1)
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN and event.pressed:
			zoom_by(1.0 / 1.1)
		elif event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed:
				pressing = true
				press_pos = event.position
				dragged = 0.0
			else:
				if pressing and dragged < 14.0 and touches.size() < 2:
					var wp: Vector2 = get_viewport().get_canvas_transform().affine_inverse() * event.position
					select(pick_at(wp))
				pressing = false
	elif event is InputEventMouseMotion and pressing and touches.size() < 2:
		dragged += event.relative.length()
		if dragged >= 14.0:
			camera.position -= event.relative / camera.zoom.x
			_clamp_camera()
