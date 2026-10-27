extends Node2D
## Cashier / food server / cleaner.

var world
var role := "cashier"
var idx := 0
var at_station := false
var path := PackedVector2Array()
var path_i := 0
var at_dest := true
var speed := 100.0
var state := "walking"
var target_litter = null
var timer := 0.0
var bob := 0.0
var home := Vector2i.ZERO

func setup(w, r: String, i: int) -> void:
	world = w
	role = r
	idx = i
	position = Data.cell_center(Vector2i(4, 5))
	match role:
		"cashier":
			home = Data.TICKET_STATIONS[i]
		"server":
			home = Data.FOOD_STATIONS[i]
		_:
			home = Data.STAFF_IDLE[i % Data.STAFF_IDLE.size()]
	_go(home)
	state = "walking"

func _go(cell: Vector2i) -> void:
	var p: PackedVector2Array = world.nav.find_path(position, cell)
	if p.is_empty():
		position = Data.cell_center(cell)
		at_dest = true
	else:
		path = p
		path_i = 0
		at_dest = false

func _move(dt: float) -> void:
	if at_dest:
		return
	var step := speed * dt
	while step > 0.0 and not at_dest:
		var d: Vector2 = path[path_i] - position
		var l := d.length()
		if l <= step:
			position = path[path_i]
			step -= l
			path_i += 1
			if path_i >= path.size():
				at_dest = true
		else:
			position += d / l * step
			step = 0.0
	bob += dt * 12.0

func step(dt: float) -> void:
	_move(dt)
	match state:
		"walking":
			if at_dest:
				if role == "cleaner":
					state = "idle"
				else:
					state = "station"
					at_station = true
		"idle":
			var l = world.claim_litter(position)
			if l != null:
				target_litter = l
				_go(l.cell)
				state = "to_litter"
		"to_litter":
			if at_dest:
				state = "cleaning"
				timer = 0.0
		"cleaning":
			timer += dt * Upgrades.staff_speed()
			if timer >= 2.0:
				Economy.spend(Data.CLEANING_COST, "Cleaning supplies", "cleaning", true)
				world.remove_litter(target_litter)
				target_litter = null
				state = "idle"
				if world.litter.is_empty():
					_go(home)
					state = "walking"
	queue_redraw()

func info_text() -> String:
	return "%s\nWage: %s per day\nSpeed: x%.2f" % [Data.STAFF[role].name, Data.money(Data.STAFF[role].wage), Upgrades.staff_speed()]

func _draw() -> void:
	var col: Color = {"cashier": Color(0.2, 0.5, 0.9), "server": Color(0.9, 0.35, 0.3), "cleaner": Color(0.3, 0.75, 0.4), "technician": Color(0.6, 0.4, 0.9)}.get(role, Color(0.7, 0.7, 0.7))
	var by := 0.0
	if not at_dest:
		by = -absf(sin(bob)) * 2.5
	draw_circle(Vector2(0, 9), 9.0, Color(0, 0, 0, 0.22))
	draw_rect(Rect2(-7, -6 + by, 14, 15), col)
	draw_circle(Vector2(0, -12 + by), 6.5, Color(0.95, 0.8, 0.65))
	draw_rect(Rect2(-6, -19 + by, 12, 4), Color(0.2, 0.15, 0.1))
	draw_rect(Rect2(-4, -2 + by, 8, 3), Color.WHITE)
	if state == "cleaning":
		draw_line(Vector2(8, 4), Vector2(18 + sin(timer * 14.0) * 4.0, 14), Color(0.6, 0.4, 0.2), 3.0)
	elif state == "station" and world.ticket_counter.busy_count() + world.food_counter.busy_count() > 0:
		draw_circle(Vector2(0, -28), 2.5, Color(1, 1, 0.5))
