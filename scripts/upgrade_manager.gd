extends Node
## Upgrade tracks, decorations, hall construction and staff hiring.

signal changed(kind: String, id: String)

var levels: Dictionary = {}
var decor: Dictionary = {}
var hall_state: Array = ["built", "locked", "locked"]
var build_left: Dictionary = {}
var staff: Dictionary = {}

func reset() -> void:
	levels = {}
	for t in Data.TRACK_ORDER:
		levels[t] = 0
	decor = {}
	hall_state = ["built", "locked", "locked"]
	build_left = {}
	staff = {}
	for r in Data.STAFF:
		staff[r] = 1 if r == "cashier" else 0

func level(track: String) -> int:
	return int(levels.get(track, 0))

func level_data(track: String) -> Dictionary:
	return Data.TRACKS[track].levels[level(track)]

func quality(track: String) -> float:
	return float(level_data(track).q)

## Daily upkeep of every installed tier (seats, lobby, food, projector).
func upkeep_total() -> int:
	var t := 0
	for track in Data.TRACK_ORDER:
		t += int(level_data(track).get("maint", 0))
	return t

## Daily electricity of projector and audio tiers.
func power_draw() -> int:
	return int(level_data("projector").get("power", 0)) + int(level_data("audio").get("power", 0))

func next_level(track: String) -> Dictionary:
	var lv: Array = Data.TRACKS[track].levels
	var n := level(track) + 1
	return lv[n] if n < lv.size() else {}

func check_buy(track: String) -> String:
	var nxt := next_level(track)
	if nxt.is_empty():
		return "Maxed out"
	if Game.reputation < float(nxt.rep):
		return "Needs reputation %d" % int(nxt.rep)
	var req: Dictionary = nxt.get("req", {})
	if req.has("halls") and hall_count() < int(req.halls):
		return "Needs %d halls open" % int(req.halls)
	if req.has("seats") and level("seats") < int(req.seats):
		return "Needs %s seating" % Data.TRACKS.seats.levels[int(req.seats)].name
	if Economy.cash < int(nxt.cost):
		return "Not enough cash"
	return ""

func buy(track: String) -> bool:
	if check_buy(track) != "":
		return false
	var nxt := next_level(track)
	if not Economy.spend(int(nxt.cost), "Upgrade: %s" % nxt.name, "upgrades"):
		return false
	levels[track] = level(track) + 1
	if track == "food":
		Inventory.on_food_level(level(track))
	changed.emit("track", track)
	return true

func check_decor(id: String) -> String:
	if decor.has(id):
		return "Owned"
	if Economy.cash < int(Data.DECOR[id].cost):
		return "Not enough cash"
	return ""

func buy_decor(id: String) -> bool:
	if check_decor(id) != "":
		return false
	if not Economy.spend(int(Data.DECOR[id].cost), "Decoration: %s" % Data.DECOR[id].name, "construction"):
		return false
	decor[id] = true
	changed.emit("decor", id)
	return true

func decor_facility() -> float:
	var t := 0.0
	for id in decor:
		t += float(Data.DECOR[id].fac)
	return t

func decor_demand() -> float:
	var t := 0.0
	for id in decor:
		t += float(Data.DECOR[id].demand)
	return t

func hall_ready(i: int) -> bool:
	return hall_state[i] == "built"

func hall_count() -> int:
	var n := 0
	for s in hall_state:
		if s == "built":
			n += 1
	return n

func check_build_hall(i: int) -> String:
	var h: Dictionary = Data.HALLS[i]
	if hall_state[i] == "built":
		return "Built"
	if hall_state[i] == "building":
		return "Under construction"
	if i > 0 and hall_state[i - 1] != "built":
		return "Build %s first" % Data.HALLS[i - 1].name
	if Game.reputation < float(h.rep):
		return "Needs reputation %d" % int(h.rep)
	if Economy.cash < int(h.cost):
		return "Not enough cash"
	return ""

func build_hall(i: int) -> bool:
	if check_build_hall(i) != "":
		return false
	if not Economy.spend(int(Data.HALLS[i].cost), "Construction: %s" % Data.HALLS[i].name, "construction"):
		return false
	hall_state[i] = "building"
	build_left[i] = float(Data.HALLS[i].build_sec)
	changed.emit("hall_start", str(i))
	return true

func tick(dt: float) -> void:
	for k in build_left.keys():
		build_left[k] = float(build_left[k]) - dt
		if build_left[k] <= 0.0:
			build_left.erase(k)
			hall_state[k] = "built"
			Screenings.on_hall_built(int(k))
			changed.emit("hall_done", str(k))

# --- Staff ---------------------------------------------------------------------------
func staff_count(role: String) -> int:
	return int(staff.get(role, 0))

func check_hire(role: String) -> String:
	var d: Dictionary = Data.STAFF[role]
	if staff_count(role) >= int(d.max):
		return "Team is full"
	if role == "server" and level("food") < 1:
		return "Build a food stand first"
	if role == "technician" and level("projector") < 2:
		return "Needs a Full HD projector"
	if Economy.cash < int(d.hire):
		return "Not enough cash"
	return ""

func hire(role: String) -> bool:
	if check_hire(role) != "":
		return false
	if not Economy.spend(int(Data.STAFF[role].hire), "Hiring fee: %s" % Data.STAFF[role].name, "staff"):
		return false
	staff[role] = staff_count(role) + 1
	changed.emit("staff", role)
	return true

func can_fire(role: String) -> bool:
	return staff_count(role) > int(Data.STAFF[role].min)

func fire(role: String) -> bool:
	if not can_fire(role):
		return false
	staff[role] = staff_count(role) - 1
	changed.emit("staff", role)
	return true

func daily_wages() -> int:
	var t := 0
	for r in Data.STAFF:
		t += staff_count(r) * int(Data.STAFF[r].wage)
	return t

func staff_speed() -> float:
	return float(level_data("training").q)

func to_dict() -> Dictionary:
	var bl := {}
	for k in build_left:
		bl[str(k)] = build_left[k]
	return {"levels": levels, "decor": decor, "hall_state": hall_state, "build_left": bl, "staff": staff}

func from_dict(d: Dictionary) -> void:
	reset()
	var lv := Data.as_dict(d.get("levels"))
	for t in Data.TRACK_ORDER:
		var maxl: int = Data.TRACKS[t].levels.size() - 1
		levels[t] = clampi(int(lv.get(t, 0)), 0, maxl)
	var dc := Data.as_dict(d.get("decor"))
	for id in dc:
		if Data.DECOR.has(id):
			decor[id] = true
	var hs := Data.as_array(d.get("hall_state"))
	for i in 3:
		if i < hs.size() and str(hs[i]) in ["built", "building", "locked"]:
			hall_state[i] = str(hs[i])
	hall_state[0] = "built"
	var bl := Data.as_dict(d.get("build_left"))
	for k in bl:
		if int(k) in [1, 2] and hall_state[int(k)] == "building":
			build_left[int(k)] = float(bl[k])
	for i in 3:
		if hall_state[i] == "building" and not build_left.has(i):
			build_left[i] = 5.0
	var st := Data.as_dict(d.get("staff"))
	for r in Data.STAFF:
		staff[r] = clampi(int(st.get(r, staff[r])), int(Data.STAFF[r].min), int(Data.STAFF[r].max))
