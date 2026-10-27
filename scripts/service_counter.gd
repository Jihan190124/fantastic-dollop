extends RefCounted
## A staffed counter (tickets or food) with a waiting queue and service slots.

var role := "cashier"
var spots: Array = []
var queue_cells: Array = []
var queue: Array = []
var slots: Array = []
var staff_list: Array = []
var served_today := 0

func setup(r: String, spot_cells: Array, qcells: Array) -> void:
	role = r
	spots = spot_cells
	queue_cells = qcells
	slots = []
	for i in spot_cells.size():
		slots.append({"c": null, "t": -1.0, "dur": 1.0})

func has_staff() -> bool:
	for s in staff_list:
		if s.at_station:
			return true
	return false

func join(c) -> bool:
	if not has_staff() or queue.size() >= queue_cells.size():
		return false
	queue.append(c)
	return true

func leave(c) -> void:
	queue.erase(c)
	for s in slots:
		if s.c == c:
			s.c = null
			s.t = -1.0

func busy_count() -> int:
	var n := queue.size()
	for s in slots:
		if s.c != null:
			n += 1
	return n

func update(dt: float) -> void:
	for i in slots.size():
		var s: Dictionary = slots[i]
		var st = staff_list[i] if i < staff_list.size() else null
		var active: bool = st != null and st.at_station
		if s.c != null and not is_instance_valid(s.c):
			s.c = null
			s.t = -1.0
		if s.c == null:
			if active and not queue.is_empty():
				var c = queue.pop_front()
				s.c = c
				s.t = -1.0
				c.assign_spot(self, spots[i])
		elif st == null:
			# staff was removed: put the guest back at the front of the line
			var c2 = s.c
			s.c = null
			s.t = -1.0
			c2.has_spot = false
			c2.last_q_cell = Vector2i(-1, -1)
			queue.push_front(c2)
		else:
			var c3 = s.c
			if s.t < 0.0:
				if c3.at_dest and active:
					c3.on_service_start(self)
					s.t = 0.0
					s.dur = c3.service_time(role) / maxf(0.1, Upgrades.staff_speed())
			else:
				if active:
					s.t += dt
				if s.t >= s.dur:
					s.c = null
					s.t = -1.0
					served_today += 1
					c3.on_service_done(self)
