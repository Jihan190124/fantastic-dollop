extends Node
## Per-hall screening schedules, ticket prices, seat reservations and show lifecycle.

signal show_started(show: Dictionary)
signal show_ended(show: Dictionary)

var halls: Array = []

func reset() -> void:
	halls = []
	for i in 3:
		halls.append({"price": Data.TICKET_PRICE, "slots": ["", "", "", "", ""], "shows": []})
	set_default_slots(0)

func set_default_slots(hi: int) -> void:
	var ids := ["neon_monsoon", "the_last_chai_stall", "cartoon_kingdom", "whispers_of_rann"]
	for s in 5:
		halls[hi].slots[s] = ids[(s + hi * 2) % ids.size()]

func _make_show(hi: int, slot: int, mid: String) -> Dictionary:
	var m: Dictionary = Data.movie(mid)
	var n: int = Data.hall_seats(hi).size()
	var owners := []
	owners.resize(n)
	owners.fill(0)
	var seated := []
	seated.resize(n)
	seated.fill(false)
	var start: float = Data.SHOW_SLOTS[slot]
	return {"hall": hi, "slot": slot, "movie": mid, "start": start, "end": start + float(m.dur) / 60.0,
		"state": "scheduled", "owners": owners, "seated": seated, "sold": 0, "revenue": 0, "cap": n}

func _gen_hall(hi: int, from_clock: float) -> void:
	var h: Dictionary = halls[hi]
	h.shows = []
	if not Upgrades.hall_ready(hi):
		return
	for s in Data.SHOW_SLOTS.size():
		var mid: String = h.slots[s]
		if mid == "":
			continue
		var sh := _make_show(hi, s, mid)
		if from_clock >= 0.0 and float(sh.start) - Data.BOARDING_MIN / 60.0 < from_clock:
			sh.state = "done"
		h.shows.append(sh)

func generate_day(from_clock: float = -1.0) -> void:
	for hi in halls.size():
		_gen_hall(hi, from_clock)

func on_hall_built(hi: int) -> void:
	set_default_slots(hi)
	_gen_hall(hi, Game.clock)

func movie_unlocked(id: String) -> bool:
	return Game.reputation >= float(Data.movie(id).get("min_rep", 999))

func assign(hi: int, slot: int, mid: String) -> String:
	if mid != "":
		var m: Dictionary = Data.movie(mid)
		if m.is_empty():
			return "Unknown movie"
		if not movie_unlocked(mid):
			return "Movie locked: needs reputation %d" % int(m.min_rep)
		if int(m.dur) + Data.CLEAN_MIN > Data.SLOT_LEN_MIN:
			return "Movie too long for the slot"
	halls[hi].slots[slot] = mid
	for sh in halls[hi].shows.duplicate():
		if int(sh.slot) == slot:
			if int(sh.sold) == 0 and sh.state == "scheduled":
				if mid == "":
					halls[hi].shows.erase(sh)
				else:
					sh.movie = mid
					sh.end = float(sh.start) + float(Data.movie(mid).dur) / 60.0
				return "Schedule updated"
			return "Saved - applies from tomorrow (tickets already sold)"
	if mid != "" and Game.clock < float(Data.SHOW_SLOTS[slot]) - Data.BOARDING_MIN / 60.0 and Upgrades.hall_ready(hi):
		halls[hi].shows.append(_make_show(hi, slot, mid))
		halls[hi].shows.sort_custom(func(a, b): return a.start < b.start)
		return "Schedule updated"
	return "Saved - applies from tomorrow"

func set_price(hi: int, price: int) -> void:
	halls[hi].price = clampi(int(round(price / float(Data.TICKET_STEP))) * Data.TICKET_STEP, Data.TICKET_MIN, Data.TICKET_MAX)

func avg_price() -> float:
	var t := 0.0
	var n := 0
	for hi in halls.size():
		if Upgrades.hall_ready(hi):
			t += float(halls[hi].price)
			n += 1
	return t / maxf(1.0, float(n))

func update(now: float) -> void:
	for hi in halls.size():
		for sh in halls[hi].shows:
			if sh.state == "scheduled" and now >= float(sh.start) - Data.BOARDING_MIN / 60.0:
				sh.state = "boarding"
			if sh.state == "boarding" and now >= float(sh.start):
				sh.state = "running"
				show_started.emit(sh)
			if sh.state == "running" and now >= float(sh.end):
				sh.state = "done"
				show_ended.emit(sh)

func free_seats(sh: Dictionary) -> int:
	var n := 0
	for o in sh.owners:
		if o == 0:
			n += 1
	return n

func can_sell(sh: Dictionary, party: int, now: float) -> bool:
	return (sh.state == "scheduled" or sh.state == "boarding") \
		and now < float(sh.start) - Data.SALES_CLOSE_MIN / 60.0 and free_seats(sh) >= party

func any_sellable(now: float) -> bool:
	for hi in halls.size():
		for sh in halls[hi].shows:
			if can_sell(sh, 1, now + 0.4):
				return true
	return false

func any_active() -> bool:
	for hi in halls.size():
		for sh in halls[hi].shows:
			if sh.state == "boarding" or sh.state == "running":
				return true
	return false

## Chooses a show for a party. Returns {"show": Dictionary (empty if none), "reason": String}.
func pick(party: int, budget: int, tdata: Dictionary, now: float) -> Dictionary:
	var best := {}
	var best_score := -1.0
	var saw_show := false
	for hi in halls.size():
		var price: int = halls[hi].price
		for sh in halls[hi].shows:
			if not can_sell(sh, party, now + 0.4):
				continue
			if float(sh.start) - now > 2.5:
				continue
			saw_show = true
			if price * party > int(budget * 0.9):
				continue
			var m: Dictionary = Data.movie(sh.movie)
			var score: float = float(m.pop) * 0.5 + (0.25 if m.genre in tdata.genres else 0.0) \
				+ (1.0 - minf(1.0, (float(sh.start) - now) / 2.5)) * 0.35 + randf() * 0.1 \
				+ float(m.quality) * (0.2 if tdata.w[8] > 0.1 else 0.0)
			if score > best_score:
				best_score = score
				best = sh
	if best.is_empty():
		return {"show": {}, "reason": "price" if saw_show else "none"}
	return {"show": best, "reason": "ok"}

func reserve(sh: Dictionary, party: int, uid: int) -> Array:
	if free_seats(sh) < party:
		return []
	var seats: Array = Data.hall_seats(sh.hall)
	var owners: Array = sh.owners
	for row in [1, 2, 0, 3]:
		for block in 2:
			var run: Array = []
			for i in seats.size():
				var s: Dictionary = seats[i]
				if s.row != row or s.block != block:
					continue
				if owners[i] == 0:
					run.append(i)
					if run.size() == party:
						for k in run:
							owners[k] = uid
						return run
				else:
					run.clear()
	var pick_idx: Array = []
	for i in seats.size():
		if owners[i] == 0:
			pick_idx.append(i)
			if pick_idx.size() == party:
				break
	for k in pick_idx:
		owners[k] = uid
	return pick_idx

func release(sh: Dictionary, idxs: Array) -> void:
	for k in idxs:
		sh.owners[k] = 0
		sh.seated[k] = false

func record_sale(sh: Dictionary, party: int, amount: int) -> void:
	sh.sold += party
	sh.revenue += amount
	Game.on_tickets_sold(party, amount)

func set_seated(sh: Dictionary, idxs: Array, v: bool) -> void:
	for k in idxs:
		sh.seated[k] = v

func current_show(hi: int) -> Dictionary:
	var nxt := {}
	var last := {}
	for sh in halls[hi].shows:
		if sh.state == "running" or sh.state == "boarding":
			return sh
		if sh.state == "scheduled" and (nxt.is_empty() or sh.start < nxt.start):
			nxt = sh
		if sh.state == "done":
			last = sh
	return nxt if not nxt.is_empty() else last

func status_text(sh: Dictionary) -> String:
	match sh.state:
		"scheduled":
			return "Scheduled - %d/%d sold" % [sh.sold, sh.cap]
		"boarding":
			return "Boarding - %d/%d sold" % [sh.sold, sh.cap]
		"running":
			return "Now showing - %d/%d" % [sh.sold, sh.cap]
		_:
			return "Finished - %d/%d, %s" % [sh.sold, sh.cap, Data.money(sh.revenue)]

## True if no two shows in a hall overlap (including cleaning time).
func validate() -> bool:
	for hi in halls.size():
		var shows: Array = halls[hi].shows.duplicate()
		shows.sort_custom(func(a, b): return a.start < b.start)
		for i in range(1, shows.size()):
			if float(shows[i - 1].end) + Data.CLEAN_MIN / 60.0 > float(shows[i].start):
				return false
	return true

func to_dict() -> Dictionary:
	var out := []
	for h in halls:
		out.append({"price": h.price, "slots": h.slots})
	return {"halls": out}

func from_dict(d: Dictionary) -> void:
	reset()
	var hs := Data.as_array(d.get("halls"))
	for i in mini(3, hs.size()):
		var e := Data.as_dict(hs[i])
		set_price(i, int(e.get("price", Data.TICKET_PRICE)))
		var sl := Data.as_array(e.get("slots"))
		for s in 5:
			if s < sl.size():
				var mid := str(sl[s])
				if mid == "" or not Data.movie(mid).is_empty():
					halls[i].slots[s] = mid
