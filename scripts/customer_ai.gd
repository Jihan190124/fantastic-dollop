extends Node2D
## One guest (or party) driven by a state machine.

enum S { SPAWNING, ENTERING, DECIDING, JOINING_QUEUE, PURCHASING_TICKET, BUYING_FOOD, WAITING_SHOW,
	NAVIGATING_TO_HALL, FINDING_SEAT, WATCHING_MOVIE, EXITING, DESPAWNING }
const STATE_LABEL := ["Arriving", "Entering", "Deciding", "Queueing for tickets", "Buying tickets", "Buying snacks",
	"Waiting for the show", "Heading to the hall", "Finding a seat", "Watching the movie", "Leaving", "Gone"]
const FOOD_FACTOR := {"stock": 0.0, "staff": 0.0, "queue": 0.2, "budget": 0.55}

var world
var uid := 0
var type_id := "budget"
var tdata: Dictionary = {}
var party := 1
var budget := 0
var state: int = S.SPAWNING
var timer := 0.0
var path := PackedVector2Array()
var path_i := 0
var at_dest := true
var speed := 105.0
var bob := 0.0
var show: Dictionary = {}
var hall_idx := -1
var seat_idx: Array = []
var seated := false
var wants_food := false
var food_failed := ""
var food_plan: Array = []
var got_food := false
var wait_min := 0.0
var q_wait := 0.0
var patience := 30.0
var ticket_price := 0
var leave_reason := ""
var counter = null
var has_spot := false
var serving := false
var last_q_cell := Vector2i(-1, -1)
var sub := ""
var seat_offsets: Array = []
var icon := ""
var icon_t := 0.0
var experienced := false
var mood := -1.0
var color := Color.WHITE
var skin := Color.WHITE
var toilet_plan := false
var wait_cell := Vector2i.ZERO

func setup(w, t_id: String, id: int) -> void:
	world = w
	uid = id
	type_id = t_id
	tdata = Data.CUSTOMER_TYPES[t_id]
	color = Color(tdata.color).lerp(Color.from_hsv(randf(), 0.5, 0.9), 0.25)
	skin = [Color(0.96, 0.8, 0.66), Color(0.85, 0.65, 0.5), Color(0.6, 0.42, 0.3), Color(0.45, 0.3, 0.22)].pick_random()
	party = randi_range(tdata.party[0], tdata.party[1])
	budget = randi_range(tdata.budget[0], tdata.budget[1])
	patience = float(tdata.patience) * randf_range(0.8, 1.2)
	speed = randf_range(95.0, 120.0)
	wants_food = randf() < float(tdata.food)
	toilet_plan = randf() < 0.3
	z_index = 0

# --- Movement --------------------------------------------------------------------------
func go_to_cell(cell: Vector2i) -> void:
	var p: PackedVector2Array = world.nav.find_path(position, cell)
	if p.is_empty():
		world.nav_failures += 1
		position = Data.cell_center(cell)
		path = PackedVector2Array()
		at_dest = true
	else:
		path = p
		path_i = 0
		at_dest = false

func go_via(first: Vector2, cell: Vector2i) -> void:
	var p: PackedVector2Array = world.nav.find_path(first, cell)
	path = PackedVector2Array([first])
	path.append_array(p)
	path_i = 0
	at_dest = false

func go_to_pos(p: Vector2) -> void:
	path = PackedVector2Array([p])
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

# --- State machine -----------------------------------------------------------------------
func step(dt: float) -> void:
	_move(dt)
	if icon_t > 0.0:
		icon_t -= dt
		if icon_t <= 0.0:
			icon = ""
	match state:
		S.SPAWNING:
			timer += dt
			if timer >= 0.4:
				state = S.ENTERING
				go_to_cell(Data.ENTRY_CELL)
		S.ENTERING:
			if at_dest:
				state = S.DECIDING
				timer = 0.0
		S.DECIDING:
			timer += dt
			if timer >= 0.9:
				_decide()
		S.JOINING_QUEUE, S.BUYING_FOOD:
			_queue_tick(dt)
		S.WAITING_SHOW:
			_waiting(dt)
		S.NAVIGATING_TO_HALL:
			if at_dest:
				state = S.FINDING_SEAT
				go_to_pos(Data.seat_pos(hall_idx, seat_idx[0]))
		S.FINDING_SEAT:
			if at_dest:
				_sit()
		S.WATCHING_MOVIE:
			if show.state == "done":
				_end_movie()
		S.EXITING:
			if at_dest:
				state = S.DESPAWNING
	queue_redraw()

func _decide() -> void:
	var r: Dictionary = Screenings.pick(party, budget, tdata, Game.clock)
	if r.show.is_empty():
		leave_reason = r.reason
		_leave()
		return
	show = r.show
	if world.ticket_counter.join(self):
		counter = world.ticket_counter
		state = S.JOINING_QUEUE
		q_wait = 0.0
		has_spot = false
		last_q_cell = Vector2i(-1, -1)
	else:
		leave_reason = "queue_full"
		_leave()

func _queue_tick(dt: float) -> void:
	if serving or counter == null:
		return
	var gm := dt * Data.GAME_MIN_PER_SEC
	wait_min += gm
	if has_spot:
		return
	q_wait += gm
	var idx: int = counter.queue.find(self)
	if idx >= 0:
		var qc: Vector2i = counter.queue_cells[mini(idx, counter.queue_cells.size() - 1)]
		if qc != last_q_cell:
			last_q_cell = qc
			go_to_cell(qc)
	if q_wait > patience:
		counter.leave(self)
		counter = null
		if state == S.JOINING_QUEUE:
			leave_reason = "queue"
			_leave()
		else:
			food_failed = "queue"
			_go_wait()

func assign_spot(cnt, cell: Vector2i) -> void:
	has_spot = true
	go_to_cell(cell)

func on_service_start(cnt) -> void:
	serving = true
	if cnt.role == "cashier":
		state = S.PURCHASING_TICKET
	else:
		_plan_food()

func service_time(role: String) -> float:
	if role == "cashier":
		return 3.0
	var n := 0
	for it in food_plan:
		n += int(it.qty)
	return 1.6 + 0.5 * minf(float(n), 6.0)

func on_service_done(cnt) -> void:
	serving = false
	has_spot = false
	counter = null
	if cnt.role == "cashier":
		_ticket_done()
	else:
		_food_done()

func _ticket_done() -> void:
	var now: float = Game.clock
	if not Screenings.can_sell(show, party, now):
		var r: Dictionary = Screenings.pick(party, budget, tdata, now)
		if r.show.is_empty():
			leave_reason = "soldout"
			_leave()
			return
		show = r.show
	seat_idx = Screenings.reserve(show, party, uid)
	if seat_idx.is_empty():
		leave_reason = "soldout"
		_leave()
		return
	var price: int = int(Screenings.halls[show.hall].price)
	var cost := price * party
	if cost > budget:
		Screenings.release(show, seat_idx)
		seat_idx = []
		leave_reason = "price"
		_leave()
		return
	ticket_price = price
	budget -= cost
	Economy.earn(cost, "Tickets: %s x%d" % [Data.movie(show.movie).title, party], "tickets")
	Screenings.record_sale(show, party, cost)
	world.fx_money(position + Vector2(0, -34), cost)
	icon = "ticket"
	icon_t = 2.0
	hall_idx = int(show.hall)
	_after_ticket()

func _after_ticket() -> void:
	if wants_food and Upgrades.level("food") >= 1:
		var cheapest: int = Inventory.cheapest_available()
		if cheapest < 0:
			food_failed = "stock"
		elif cheapest > budget:
			food_failed = "budget"
		elif not world.food_counter.has_staff():
			food_failed = "staff"
		elif world.food_counter.join(self):
			counter = world.food_counter
			state = S.BUYING_FOOD
			q_wait = 0.0
			has_spot = false
			last_q_cell = Vector2i(-1, -1)
			return
		else:
			food_failed = "queue"
	_go_wait()

func _plan_food() -> void:
	food_plan = []
	var remaining := budget
	for id in Inventory.available_items():
		var d: Dictionary = Data.FOOD[id]
		var chance: float = float(d.bias) * (0.5 + float(tdata.food) * 0.7)
		if randf() > chance:
			continue
		var qty: int = party if id in ["drink", "meal"] else int(ceil(party / 2.0))
		while qty > 0 and (qty * int(d.price) > remaining or qty > Inventory.qty(id)):
			qty -= 1
		if qty > 0:
			food_plan.append({"id": id, "qty": qty})
			remaining -= qty * int(d.price)
	if food_plan.is_empty():
		var best := ""
		for id in Inventory.available_items():
			if int(Data.FOOD[id].price) <= budget and (best == "" or Data.FOOD[id].price < Data.FOOD[best].price):
				best = id
		if best != "":
			food_plan.append({"id": best, "qty": 1})

func _food_done() -> void:
	var total := 0
	for it in food_plan:
		var d: Dictionary = Data.FOOD[it.id]
		for i in int(it.qty):
			if Inventory.take(it.id, 1):
				Economy.earn(int(d.price), "Food: %s" % d.name, "food")
				budget -= int(d.price)
				total += int(d.price)
				Game.stats.food_items = int(Game.stats.food_items) + 1
				Game.day_stats.food_items += 1
	if total > 0:
		got_food = true
		icon = "food"
		icon_t = 2.0
		world.fx_money(position + Vector2(0, -34), total)
		if randf() < 0.3:
			world.add_litter(position + Vector2(randf_range(-14, 14), 22))
	else:
		food_failed = "stock"
	_go_wait()

func _go_wait() -> void:
	state = S.WAITING_SHOW
	timer = 0.0
	if toilet_plan:
		sub = "toilet"
		go_to_cell(Data.TOILET_CELL)
	else:
		sub = "bench"
		_go_bench()

func _go_bench() -> void:
	wait_cell = Vector2i(randi_range(18, 21), randi_range(19, 21))
	go_to_cell(wait_cell)

func _waiting(dt: float) -> void:
	if Game.clock >= float(show.start) - Data.BOARDING_MIN / 60.0:
		state = S.NAVIGATING_TO_HALL
		go_to_cell(Data.hall_seats(hall_idx)[seat_idx[0]].access)
		return
	if sub == "toilet" and at_dest:
		timer += dt
		if timer >= 3.0:
			sub = "bench"
			_go_bench()

func _sit() -> void:
	state = S.WATCHING_MOVIE
	seated = true
	position = Data.seat_pos(hall_idx, seat_idx[0])
	seat_offsets = []
	for i in range(1, seat_idx.size()):
		seat_offsets.append(Data.seat_pos(hall_idx, seat_idx[i]) - position)
	Screenings.set_seated(show, seat_idx, true)

func _end_movie() -> void:
	if got_food and randf() < 0.7:
		world.add_litter(position + Vector2(randf_range(-10, 10), 4))
	_finish_experience(true)
	seated = false
	seat_offsets = []
	state = S.EXITING
	icon = "happy" if mood >= 0.5 else "sad"
	icon_t = 3.0
	go_via(Data.cell_center(Data.hall_seats(hall_idx)[seat_idx[0]].access), Data.SPAWN_CELL)

func _leave() -> void:
	_finish_experience(false)
	Game.day_stats.walkouts += 1
	state = S.EXITING
	icon = "sad"
	icon_t = 3.0
	go_to_cell(Data.SPAWN_CELL)

## Called by the world when the day is force-ended while this guest is still inside.
func force_finish() -> void:
	_finish_experience(seated)

func _finish_experience(watched: bool) -> void:
	if experienced:
		return
	experienced = true
	var f := {}
	f["comfort"] = Upgrades.quality("seats") if watched else 0.5
	f["clean"] = Game.cleanliness()
	if ticket_price > 0:
		f["price"] = clampf(1.25 - 0.75 * ticket_price / Game.fair_price(), 0.0, 1.0)
	else:
		f["price"] = 0.0 if leave_reason == "price" else 0.5
	f["wait"] = clampf(1.0 - wait_min / (patience * 1.4), 0.0, 1.0)
	if Upgrades.level("food") == 0:
		f["food"] = 0.35
	elif got_food:
		f["food"] = 1.0
	elif food_failed != "":
		f["food"] = FOOD_FACTOR[food_failed]
	else:
		f["food"] = 0.75
	f["projection"] = Upgrades.quality("projector") if watched else 0.5
	f["audio"] = Upgrades.quality("audio") if watched else 0.5
	f["facilities"] = Game.facilities_score()
	f["movie"] = float(Data.movie(show.movie).quality) if watched else 0.5
	var tw := 0.0
	var tot := 0.0
	for i in Data.FACTORS.size():
		var w: float = tdata.w[i]
		tw += w
		tot += w * float(f[Data.FACTORS[i]])
	tot /= tw
	if not watched:
		tot *= 0.55
	mood = tot
	Game.record_experience(party, f, tot)

func info_text() -> String:
	var s := "%s (party of %d)\nBudget left: %s\nStatus: %s" % [tdata.name, party, Data.money(budget), STATE_LABEL[state]]
	if not show.is_empty():
		s += "\nMovie: %s at %s" % [Data.movie(show.movie).title, Data.fmt_time(show.start)]
	if mood >= 0.0:
		s += "\nSatisfaction: %d%%" % int(mood * 100.0)
	return s

# --- Drawing ----------------------------------------------------------------------------
func _person(off: Vector2, col: Color, sc: float, by: float) -> void:
	draw_circle(off + Vector2(0, 9 * sc), 8.0 * sc, Color(0, 0, 0, 0.2))
	draw_rect(Rect2(off + Vector2(-6 * sc, -6 * sc + by), Vector2(12 * sc, 14 * sc)), col)
	draw_circle(off + Vector2(0, -12 * sc + by), 6.0 * sc, skin)
	draw_rect(Rect2(off + Vector2(-6 * sc, -18 * sc + by), Vector2(12 * sc, 4 * sc)), col.darkened(0.5))

func _draw() -> void:
	var by := 0.0
	if not at_dest and state != S.SPAWNING:
		by = -absf(sin(bob)) * 2.5
	for i in range(1, party):
		var off: Vector2 = seat_offsets[i - 1] if seated and i - 1 < seat_offsets.size() else Vector2(-12.0 * i, 6.0 - 3.0 * i)
		_person(off, color.darkened(0.12 * i), 0.8, by)
	_person(Vector2.ZERO, color, 1.0, by)
	match icon:
		"ticket":
			draw_rect(Rect2(-9, -40, 18, 10), Color.WHITE)
			draw_rect(Rect2(-3, -40, 6, 10), Color(0.9, 0.3, 0.3))
		"food":
			draw_rect(Rect2(-7, -40, 14, 11), Color(0.9, 0.2, 0.2))
			draw_circle(Vector2(0, -41), 6.0, Color(1.0, 0.95, 0.7))
		"happy", "sad":
			var c := Color(0.4, 0.9, 0.4) if icon == "happy" else Color(0.95, 0.35, 0.3)
			draw_circle(Vector2(0, -38), 8.0, c)
			draw_circle(Vector2(-3, -40), 1.2, Color.BLACK)
			draw_circle(Vector2(3, -40), 1.2, Color.BLACK)
			if icon == "happy":
				draw_arc(Vector2(0, -38), 4.5, 0.3, PI - 0.3, 8, Color.BLACK, 1.5)
			else:
				draw_arc(Vector2(0, -34), 4.5, PI + 0.3, TAU - 0.3, 8, Color.BLACK, 1.5)
