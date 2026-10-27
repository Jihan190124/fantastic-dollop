extends Node
## Global game state: clock, day cycle, reputation, satisfaction, achievements, settings.

signal day_started(day: int)
signal day_ended(summary: Dictionary)
signal reputation_changed(rep: float)
signal achievement_unlocked(id: String)
signal toast(msg: String, color: Color)

const SETTINGS_PATH := "user://settings.json"

var in_game := false
var day := 1
var clock := 9.5
var phase := "prep"          # prep, open, closing
var speed := 1
var summary_open := false
var reputation := 20.0
var litter_count := 0
var settings := {"autosave": true, "fx": true, "max_customers": 45, "ui_scale": 1.0}
var stats := {}
var day_stats := {}
var achievements := {}
var records: Array = []
var _last_hour := -1
var campaign: Dictionary = {}        # {"id": String, "left": days remaining}; empty = none running
var today_event := "none"            # id from Data.EVENTS, or "none"
var events_seen := 0
var campaigns_run := 0

func _ready() -> void:
	load_settings()

# --- Settings ------------------------------------------------------------------------
func load_settings() -> void:
	if not FileAccess.file_exists(SETTINGS_PATH):
		return
	var f := FileAccess.open(SETTINGS_PATH, FileAccess.READ)
	if f == null:
		return
	var j := JSON.new()
	var ok := j.parse(f.get_as_text()) == OK
	f.close()
	var p = j.data
	if ok and typeof(p) == TYPE_DICTIONARY:
		settings["autosave"] = bool(p.get("autosave", true))
		settings["fx"] = bool(p.get("fx", true))
		settings["max_customers"] = clampi(int(p.get("max_customers", 45)), 15, 80)
		settings["ui_scale"] = clampf(float(p.get("ui_scale", 1.0)), 0.8, 1.4)

func save_settings() -> void:
	var f := FileAccess.open(SETTINGS_PATH, FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify(settings))
		f.close()

# --- Lifecycle -----------------------------------------------------------------------
func _reset_state() -> void:
	Economy.reset()
	Upgrades.reset()
	Inventory.reset()
	Screenings.reset()
	day = 1
	reputation = Data.START_REPUTATION
	stats = {"tickets": 0, "customers": 0, "food_items": 0, "best_profit": 0, "clean_day": false,
		"best_revenue": 0, "best_sat": 0.0, "profit_days": 0}
	campaign = {}
	today_event = "none"
	events_seen = 0
	campaigns_run = 0
	achievements = {}
	records = []
	speed = 1

func new_game() -> void:
	_reset_state()
	litter_count = 8
	in_game = true
	begin_day("none")

## ev: "__roll__" picks today's event at random; a saved id is restored without charging again.
func begin_day(ev: String = "__roll__", restore: bool = false) -> void:
	clock = Data.DAY_START_HOUR
	phase = "prep"
	_last_hour = -1
	day_stats = {"arrived": 0, "served": 0, "tickets": 0, "sat_sum": 0.0, "sat_n": 0,
		"rep_start": reputation, "walkouts": 0, "food_items": 0}
	if ev == "__roll__":
		ev = _roll_event()
	_set_event(ev, not restore)
	Screenings.generate_day()
	day_started.emit(day)

func load_from(d: Dictionary) -> bool:
	_reset_state()
	var g := Data.as_dict(d.get("game"))
	Economy.from_dict(Data.as_dict(d.get("economy")))
	Upgrades.from_dict(Data.as_dict(d.get("upgrades")))
	Inventory.from_dict(Data.as_dict(d.get("inventory")))
	Screenings.from_dict(Data.as_dict(d.get("screenings")))
	day = maxi(1, int(g.get("day", 1)))
	clock = clampf(float(g.get("clock", Data.DAY_START_HOUR)), Data.DAY_START_HOUR, Data.FORCE_END_HOUR)
	reputation = clampf(float(g.get("reputation", Data.START_REPUTATION)), 0.0, 100.0)
	litter_count = clampi(int(g.get("litter", 0)), 0, Data.MAX_LITTER)
	var st := Data.as_dict(g.get("stats"))
	for k in stats:
		if st.has(k):
			stats[k] = st[k]
	achievements = Data.as_dict(g.get("achievements"))
	campaign = Data.as_dict(g.get("campaign"))
	events_seen = int(g.get("events_seen", 0))
	campaigns_run = int(g.get("campaigns_run", 0))
	records = []
	begin_day(str(g.get("event", "none")), true)
	clock = clampf(float(g.get("clock", Data.DAY_START_HOUR)), Data.DAY_START_HOUR, Data.FORCE_END_HOUR)
	Screenings.generate_day(clock)
	phase = "prep" if clock < Data.OPEN_HOUR else ("open" if clock < Data.CLOSE_HOUR else "closing")
	in_game = true
	return true

func to_dict() -> Dictionary:
	return {"day": day, "clock": clock, "reputation": reputation, "litter": litter_count,
		"stats": stats, "achievements": achievements, "campaign": campaign, "event": today_event,
		"events_seen": events_seen, "campaigns_run": campaigns_run}

# --- Simulation clock ----------------------------------------------------------------
func tick(dt: float) -> void:
	clock += dt * Data.GAME_MIN_PER_SEC / 60.0
	if phase == "prep" and clock >= Data.OPEN_HOUR:
		phase = "open"
		toast.emit("The cinema is open!", Color(0.5, 0.9, 0.5))
	if phase == "open" and clock >= Data.CLOSE_HOUR:
		phase = "closing"
		toast.emit("Closing time - no new guests", Color(1.0, 0.8, 0.4))
	Screenings.update(clock)
	Upgrades.tick(dt)
	var h := int(clock)
	if h != _last_hour:
		_last_hour = h
		Inventory.hourly_auto()
		stats.best_profit = maxi(int(stats.best_profit), Economy.profit_today())
		check_achievements()

func weekday() -> String:
	return Data.DAYS[(day - 1) % 7]

# --- Derived business values ----------------------------------------------------------
func cleanliness() -> float:
	return clampf(Upgrades.quality("lobby") - minf(0.5, litter_count * 0.02), 0.0, 1.0)

func facilities_score() -> float:
	var f := 0.08 + 0.35 * Upgrades.quality("lobby") + Upgrades.decor_facility() + 0.07 * (Upgrades.hall_count() - 1)
	if Upgrades.level("food") >= 4:
		f += 0.1
	return clampf(f, 0.0, 1.0)

func fair_price() -> float:
	var q := (Upgrades.quality("projector") + Upgrades.quality("audio") + Upgrades.quality("seats")) / 3.0
	return 80.0 + 120.0 * q

func hour_factor(h: float) -> float:
	if h < 12.0:
		return 0.6
	if h < 15.0:
		return 0.9
	if h < 18.0:
		return 1.0
	return 1.5

func demand_multiplier() -> float:
	return 0.4 + reputation / 100.0 * 1.6

func arrival_rate() -> float:
	var base := 3.0 + 0.12 * reputation
	var halls := 1.0 + 0.45 * (Upgrades.hall_count() - 1)
	var r := Screenings.avg_price() / fair_price()
	var price_f := clampf(1.7 - 0.9 * r, 0.2, 1.4)
	var weekend := 1.3 if (day - 1) % 7 >= 5 else 1.0
	return base * hour_factor(clock) * halls * price_f * weekend * (1.0 + Upgrades.decor_demand()) \
		* (1.0 + campaign_boost()) * event_demand_mult()

func rank_title() -> String:
	var h := Upgrades.hall_count()
	if h >= 3 and Upgrades.level("lobby") >= 3 and Upgrades.level("seats") >= 3 and Upgrades.level("food") >= 4:
		return "Luxury Cinema Complex"
	if h >= 3:
		return "Multiplex"
	if h == 2:
		return "Two-Screen Cinema"
	return "Single-Screen Cinema"

# --- Customer feedback -----------------------------------------------------------------
func on_tickets_sold(party: int, _amount: int) -> void:
	stats.tickets = int(stats.tickets) + party
	day_stats.tickets += party

func record_experience(party: int, factors: Dictionary, total: float) -> void:
	var drep := (total - 0.5) * 0.6 * sqrt(float(party))
	if drep > 0.0:
		drep *= (1.0 - reputation / 120.0)
	reputation = clampf(reputation + drep, 0.0, 100.0)
	day_stats.sat_sum += total
	day_stats.sat_n += 1
	day_stats.served += 1
	stats.customers = int(stats.customers) + 1
	records.append({"f": factors, "t": total})
	if records.size() > 60:
		records.pop_front()
	reputation_changed.emit(reputation)

func factor_averages() -> Dictionary:
	var out := {}
	if records.is_empty():
		return out
	for f in Data.FACTORS:
		var t := 0.0
		for r in records:
			t += float(r.f.get(f, 0.5))
		out[f] = t / records.size()
	return out

func top_advice() -> String:
	if records.size() < 4:
		return "Open for business to gather guest feedback."
	var avg := factor_averages()
	var worst := ""
	var low := 2.0
	for f in avg:
		if avg[f] < low:
			low = avg[f]
			worst = f
	if low > 0.75:
		return "Guests are happy! Keep expanding."
	return Data.FACTOR_TIPS[worst]

# --- Day end ---------------------------------------------------------------------------
func end_day() -> Dictionary:
	var halls := Upgrades.hall_count()
	var elec := 200 + 100 * halls + Upgrades.power_draw()
	var maint := 50 + 40 * halls + Upgrades.upkeep_total()
	Economy.spend(Upgrades.daily_wages(), "Staff wages", "wages", true)
	Economy.spend(elec, "Electricity bill", "electricity", true)
	Economy.spend(maint, "Equipment maintenance", "maintenance", true)
	stats.best_revenue = maxi(int(stats.best_revenue), Economy.income_sum())
	if Economy.profit_today() > 0:
		stats.profit_days = int(stats.profit_days) + 1
	if int(day_stats.sat_n) >= 10:
		stats.best_sat = maxf(float(stats.best_sat), float(day_stats.sat_sum) / int(day_stats.sat_n))
	if cleanliness() > 0.9:
		stats.clean_day = true
	stats.best_profit = maxi(int(stats.best_profit), Economy.profit_today())
	check_achievements()
	var sat_n: int = maxi(1, int(day_stats.sat_n))
	var extra := {"weekday": weekday(), "arrived": day_stats.arrived, "served": day_stats.served,
		"tickets": day_stats.tickets, "walkouts": day_stats.walkouts, "food_items": day_stats.food_items,
		"avg_sat": float(day_stats.sat_sum) / sat_n, "rep": reputation,
		"rep_change": reputation - float(day_stats.rep_start), "cleanliness": cleanliness(),
		"bankrupt": Economy.cash < Data.BANKRUPT_LIMIT, "advice": top_advice()}
	var summary := Economy.archive_day(day, extra)
	_tick_campaign()
	day += 1
	begin_day()
	if settings.autosave and not summary.bankrupt:
		SaveSys.save_game()
	summary_open = true
	day_ended.emit(summary)
	return summary

# --- Achievements ----------------------------------------------------------------------
func _cond(id: String) -> bool:
	match id:
		"first_ticket": return int(stats.tickets) >= 1
		"tickets_100": return int(stats.tickets) >= 100
		"tickets_1000": return int(stats.tickets) >= 1000
		"popcorn_50": return int(Inventory.stock["popcorn"].sold) >= 50
		"profit_5000": return int(stats.best_profit) >= 5000
		"rep_50": return reputation >= 50.0
		"rep_80": return reputation >= 80.0
		"hall_2": return Upgrades.hall_state[1] == "built"
		"hall_3": return Upgrades.hall_state[2] == "built"
		"clean_90": return bool(stats.clean_day)
		"cash_100k": return Economy.cash >= 100000
		"luxury": return rank_title() == "Luxury Cinema Complex"
		"first_profit_day": return int(stats.profit_days) >= 1
		"first_campaign": return campaigns_run >= 1
		"revenue_20k": return int(stats.best_revenue) >= 20000
		"sat_90": return float(stats.best_sat) >= 0.9
		"premium_projector": return Upgrades.level("projector") >= 5
		"vip_seats": return Upgrades.level("seats") >= 5
		"survive_events": return events_seen >= 3
	return false

func check_achievements() -> void:
	for a in Data.ACHIEVEMENTS:
		if not achievements.has(a.id) and _cond(a.id):
			achievements[a.id] = day
			if int(a.reward) > 0:
				Economy.earn(int(a.reward), "Achievement: %s" % a.name, "bonus")
			toast.emit("Achievement: %s" % a.name, Color(1.0, 0.85, 0.3))
			achievement_unlocked.emit(a.id)

# --- Business events -------------------------------------------------------------------
func _roll_event() -> String:
	if day < 2 or randf() > 0.3:
		return "none"
	return str(Data.EVENTS[randi() % Data.EVENTS.size()].id)

## fresh = true at the start of a real day (charges and announces); false when restoring a save.
func _set_event(ev: String, fresh: bool) -> void:
	today_event = ev
	if ev == "none":
		return
	if fresh:
		events_seen += 1
		var cost := int(event_def().get("cost", 0))
		if ev == "breakdown":
			if Upgrades.staff_count("technician") > 0:
				cost = cost / 2
			Economy.spend(cost, "Repair: projector breakdown", "maintenance", true)
		toast.emit("Today: %s" % event_def().get("name", ""), Color(1.0, 0.85, 0.4))

func event_def() -> Dictionary:
	for e in Data.EVENTS:
		if e.id == today_event:
			return e
	return {}

func event_demand_mult() -> float:
	return float(event_def().get("demand", 1.0))

func event_food_mult() -> float:
	return float(event_def().get("food", 1.0))

# --- Marketing campaigns -----------------------------------------------------------------
func _campaign_by_id(id: String) -> Dictionary:
	for c in Data.CAMPAIGNS:
		if c.id == id:
			return c
	return {}

func campaign_def() -> Dictionary:
	return _campaign_by_id(str(campaign.get("id", "")))

func campaign_boost() -> float:
	if campaign.is_empty():
		return 0.0
	return float(campaign_def().get("boost", 0.0))

func campaign_target() -> String:
	if campaign.is_empty():
		return ""
	return str(campaign_def().get("target", ""))

func campaign_check(id: String) -> String:
	if not campaign.is_empty():
		return "A campaign is already running"
	var d := _campaign_by_id(id)
	if d.is_empty():
		return "Unknown campaign"
	if Upgrades.hall_count() < int(d.get("min_halls", 1)):
		return "Needs %d halls open" % int(d.min_halls)
	if Economy.cash < int(d.cost):
		return "Not enough cash"
	return ""

func start_campaign(id: String) -> bool:
	if campaign_check(id) != "":
		return false
	var d := _campaign_by_id(id)
	if not Economy.spend(int(d.cost), "Marketing: %s" % d.name, "marketing"):
		return false
	campaign = {"id": id, "left": int(d.days)}
	campaigns_run += 1
	toast.emit("Campaign launched: %s" % d.name, Color(0.6, 0.9, 1.0))
	return true

func _tick_campaign() -> void:
	if campaign.is_empty():
		return
	campaign.left = int(campaign.left) - 1
	if int(campaign.left) <= 0:
		toast.emit("Campaign finished: %s" % campaign_def().get("name", ""), Color(0.8, 0.8, 1.0))
		campaign = {}

func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_PAUSED or what == NOTIFICATION_WM_CLOSE_REQUEST:
		if in_game and settings.autosave and not summary_open:
			SaveSys.save_game()
