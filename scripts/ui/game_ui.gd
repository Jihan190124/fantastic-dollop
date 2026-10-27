extends CanvasLayer
## In-game HUD, toolbar, management screens and context panel.

const K = preload("res://scripts/ui/ui_kit.gd")

var world
var root: Control
var touch: Control
var panel: PanelContainer
var content: VBoxContainer
var scroll: ScrollContainer
var title_lbl: Label
var close_btn: Button
var ctx: PanelContainer
var ctx_title: Label
var ctx_body: Label
var ctx_actions: HBoxContainer
var toast_box: VBoxContainer
var lbl_cash: Label
var lbl_rep: Label
var bar_rep: ProgressBar
var lbl_guests: Label
var lbl_profit: Label
var lbl_time: Label
var speed_btns: Array = []
var screen := ""
var screen_arg = null
var ctx_sel: Dictionary = {}
var acc := 0.0
var acc2 := 0.0
var saved_speed := 1

func _ready() -> void:
	layer = 10
	root = Control.new()
	root.theme = K.make_theme(float(Game.settings.ui_scale))
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	K.anchor(root, 0, 0, 1, 1, 0, 0, 0, 0)
	add_child(root)
	touch = Control.new()
	K.anchor(touch, 0, 0, 1, 1, 0, 0, 0, 0)
	touch.mouse_filter = Control.MOUSE_FILTER_STOP
	touch.gui_input.connect(world.on_touch_input)
	root.add_child(touch)
	_build_top()
	_build_toolbar()
	_build_panel()
	_build_context()
	toast_box = VBoxContainer.new()
	toast_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	K.anchor(toast_box, 0.5, 0, 0.5, 0, -230, 68, 230, 68)
	root.add_child(toast_box)
	root.move_child(toast_box, panel.get_index())
	Game.toast.connect(toast)
	Economy.transaction.connect(_on_tx)
	Game.day_ended.connect(func(s): open_screen("summary", s))
	Upgrades.changed.connect(func(_k, _i): _refresh_screen())
	_update_top()

func modal_open() -> bool:
	return panel.visible

# --- Top bar ----------------------------------------------------------------------------------
func _chip(parent: Control, w: float) -> Label:
	var l := K.label("", 22)
	l.custom_minimum_size.x = w
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	parent.add_child(l)
	return l

func _build_top() -> void:
	var pc := PanelContainer.new()
	K.anchor(pc, 0, 0, 1, 0, 6, 6, -6, 62)
	root.add_child(pc)
	var h := HBoxContainer.new()
	pc.add_child(h)
	lbl_cash = _chip(h, 150)
	lbl_rep = _chip(h, 80)
	bar_rep = ProgressBar.new()
	bar_rep.custom_minimum_size = Vector2(90, 20)
	bar_rep.show_percentage = false
	bar_rep.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	h.add_child(bar_rep)
	lbl_guests = _chip(h, 110)
	lbl_profit = _chip(h, 160)
	lbl_time = _chip(h, 170)
	var sp := Control.new()
	sp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h.add_child(sp)
	var labels := ["II", "1x", "2x", "3x"]
	for i in 4:
		var b := K.button(labels[i], _set_speed.bind(i), 52, 44)
		h.add_child(b)
		speed_btns.append(b)
	h.add_child(K.button("Menu", func(): open_screen("menu"), 90, 44))

func _set_speed(s: int) -> void:
	Game.speed = s
	_update_top()

func _update_top() -> void:
	lbl_cash.text = Data.money(Economy.cash)
	lbl_cash.add_theme_color_override("font_color", Color(1, 0.5, 0.5) if Economy.cash < 0 else Color(0.6, 1, 0.6))
	lbl_rep.text = "Rep %d" % int(Game.reputation)
	bar_rep.value = Game.reputation
	lbl_guests.text = "Guests %d" % world.customers.size()
	var p := Economy.profit_today()
	lbl_profit.text = "Today %s" % Data.money(p)
	lbl_profit.add_theme_color_override("font_color", Color(1, 0.55, 0.5) if p < 0 else Color(0.8, 1, 0.8))
	lbl_time.text = "%s D%d %s" % [Game.weekday(), Game.day, Data.fmt_time(Game.clock)]
	for i in speed_btns.size():
		speed_btns[i].modulate = Color(1, 1, 0.5) if Game.speed == i else Color.WHITE

# --- Toolbar -----------------------------------------------------------------------------------
func _build_toolbar() -> void:
	var pc := PanelContainer.new()
	K.anchor(pc, 0, 1, 1, 1, 6, -74, -6, -6)
	root.add_child(pc)
	var h := HBoxContainer.new()
	h.alignment = BoxContainer.ALIGNMENT_CENTER
	pc.add_child(h)
	for e in [["Build", "build"], ["Upgrades", "upgrades"], ["Staff", "staff"], ["Food", "food"],
			["Screenings", "shows"], ["Finance", "finance"], ["Overview", "overview"]]:
		var b := K.button(e[0], open_screen.bind(e[1]), 0, 58)
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		h.add_child(b)

# --- Management panel ---------------------------------------------------------------------------
func _build_panel() -> void:
	panel = PanelContainer.new()
	K.anchor(panel, 0.04, 0, 0.96, 1, 0, 68, 0, -80)
	panel.visible = false
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	root.add_child(panel)
	var v := VBoxContainer.new()
	panel.add_child(v)
	var hd := HBoxContainer.new()
	v.add_child(hd)
	title_lbl = K.label("", 30, Color(1, 0.9, 0.5))
	title_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hd.add_child(title_lbl)
	close_btn = K.button("Close", close_screen, 120, 52)
	hd.add_child(close_btn)
	scroll = ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	v.add_child(scroll)
	content = VBoxContainer.new()
	content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(content)

func open_screen(name: String, arg = null) -> void:
	if name == "menu" and not panel.visible:
		saved_speed = Game.speed
		Game.speed = 0
	screen = name
	screen_arg = arg
	panel.visible = true
	ctx.visible = false
	close_btn.visible = name != "summary"
	scroll.scroll_vertical = 0
	_refresh_screen()

func close_screen() -> void:
	if screen == "menu" and Game.speed == 0:
		Game.speed = saved_speed
	if screen == "summary":
		Game.summary_open = false
	panel.visible = false
	screen = ""
	_update_top()

func _refresh_screen() -> void:
	if not panel.visible or screen == "":
		return
	var keep := scroll.scroll_vertical
	K.clear(content)
	var titles := {"build": "Build & Decorate", "upgrades": "Upgrade Shop", "staff": "Employees", "food": "Food Inventory",
		"shows": "Screening Schedule", "finance": "Financial Report", "overview": "Cinema Overview",
		"achievements": "Achievements", "settings": "Settings", "menu": "Paused", "summary": "Day Summary"}
	title_lbl.text = titles.get(screen, "")
	call("_screen_" + screen, content)
	scroll.set_deferred("scroll_vertical", keep)

func _card(vb: Control, title: String, desc: String, btns: Array, col: Color = Color(0.95, 0.95, 1.0)) -> Array:
	var pc := PanelContainer.new()
	pc.add_theme_stylebox_override("panel", K.box(Color(0.14, 0.16, 0.26), 12))
	vb.add_child(pc)
	var h := HBoxContainer.new()
	pc.add_child(h)
	var v := VBoxContainer.new()
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	v.custom_minimum_size.x = 300
	v.add_theme_constant_override("separation", 2)
	h.add_child(v)
	v.add_child(K.label(title, 24, col, true))
	if desc != "":
		v.add_child(K.label(desc, 19, Color(0.75, 0.78, 0.9), true))
	var out := []
	for b in btns:
		var bt := K.button(b[0], b[1], 190, 60)
		bt.disabled = b[2] if b.size() > 2 else false
		h.add_child(bt)
		out.append(bt)
	return out

func _head(vb: Control, text: String) -> void:
	vb.add_child(K.label(text, 26, Color(1, 0.85, 0.4)))

func _msg(text: String, good: bool = true) -> void:
	toast(text, Color(0.6, 1, 0.6) if good else Color(1, 0.6, 0.5))

# --- Screens -------------------------------------------------------------------------------------
func _screen_upgrades(vb: Control) -> void:
	for t in Data.TRACK_ORDER:
		var cur: Dictionary = Upgrades.level_data(t)
		var nxt: Dictionary = Upgrades.next_level(t)
		var title: String = "%s: %s" % [Data.TRACKS[t].name, cur.name]
		if nxt.is_empty():
			_card(vb, title, "Fully upgraded.", [["MAX", func(): pass, true]], Color(0.6, 1, 0.7))
		else:
			var why := Upgrades.check_buy(t)
			var d := "Next: %s - %s" % [nxt.name, nxt.desc]
			if why != "":
				d += "\n" + why
			_card(vb, title, d, [[Data.money(nxt.cost), _buy_track.bind(t), why != ""]])

func _buy_track(t: String) -> void:
	var nm: String = Upgrades.next_level(t).name
	if Upgrades.buy(t):
		_msg("Installed: %s" % nm)

func _screen_build(vb: Control) -> void:
	_head(vb, "Cinema halls")
	for i in range(1, 3):
		var h: Dictionary = Data.HALLS[i]
		var st: String = Upgrades.hall_state[i]
		var seats: int = Data.hall_seats(i).size()
		var d := "%d seats, a separate screening schedule." % seats
		var btn_text := Data.money(h.cost)
		var dis := false
		if st == "built":
			d = "Open. " + d
			btn_text = "Built"
			dis = true
		elif st == "building":
			d = "Construction %d%% complete" % int((1.0 - float(Upgrades.build_left.get(i, 0.0)) / float(h.build_sec)) * 100.0)
			btn_text = "Building..."
			dis = true
		else:
			var why := Upgrades.check_build_hall(i)
			if why != "":
				d += "\n" + why
				dis = true
		_card(vb, h.name, d, [[btn_text, _build_hall.bind(i), dis]])
	_head(vb, "Decorations (comfort and appeal)")
	for id in Data.DECOR_ORDER:
		var dd: Dictionary = Data.DECOR[id]
		var why2 := Upgrades.check_decor(id)
		var d2 := "+%d%% facilities" % int(dd.fac * 100.0)
		if dd.demand > 0.0:
			d2 += ", +%d%% guest demand" % int(dd.demand * 100.0)
		_card(vb, dd.name, d2 + "  (decoration)", [["Owned" if why2 == "Owned" else Data.money(dd.cost), _buy_decor.bind(id), why2 != ""]])

func _build_hall(i: int) -> void:
	if Upgrades.build_hall(i):
		_msg("Construction of %s started" % Data.HALLS[i].name)

func _buy_decor(id: String) -> void:
	if Upgrades.buy_decor(id):
		_msg("Installed: %s" % Data.DECOR[id].name)

func _screen_staff(vb: Control) -> void:
	vb.add_child(K.label("Daily wages: %s" % Data.money(Upgrades.daily_wages()), 24, Color(1, 0.85, 0.5)))
	for role in Data.STAFF:
		var d: Dictionary = Data.STAFF[role]
		var n := Upgrades.staff_count(role)
		var why := Upgrades.check_hire(role)
		var desc := "%s\nWage %s/day, hiring fee %s" % [d.desc, Data.money(d.wage), Data.money(d.hire)]
		if why != "":
			desc += "\n" + why
		_card(vb, "%s x%d" % [d.name, n], desc, [["Hire", _hire.bind(role), why != ""], ["Fire", _fire.bind(role), not Upgrades.can_fire(role)]])
	vb.add_child(K.label("Staff speed: x%.2f (see Upgrades for training)" % Upgrades.staff_speed(), 20, Color(0.75, 0.8, 0.9)))

func _hire(role: String) -> void:
	if Upgrades.hire(role):
		_msg("Hired a %s" % Data.STAFF[role].name)

func _fire(role: String) -> void:
	if Upgrades.fire(role):
		_msg("%s let go" % Data.STAFF[role].name, false)

func _screen_food(vb: Control) -> void:
	if Upgrades.level("food") == 0:
		vb.add_child(K.label("No food stand yet. Buy a popcorn machine in Upgrades > Food.", 22, Color(1, 0.8, 0.5), true))
	for id in Data.FOOD_ORDER:
		var d: Dictionary = Data.FOOD[id]
		if not Inventory.unlocked(id):
			_card(vb, d.name, "Unlocks with food upgrade level %d" % d.unlock, [["Locked", func(): pass, true]], Color(0.6, 0.6, 0.7))
			continue
		var s: Dictionary = Inventory.stock[id]
		var desc := "Stock %d | Sold %d | Price %s | Cost %s | Profit %s" % [s.qty, s.sold, Data.money(d.price), Data.money(d.cost), Data.money(Inventory.profit(id))]
		var col := Color(1, 0.5, 0.4) if int(s.qty) == 0 else Color(0.95, 0.95, 1.0)
		var bs := _card(vb, d.name, desc, [["+%d  %s" % [d.batch, Data.money(Inventory.restock_cost(id))], _restock.bind(id, 1)],
			["Auto: %s" % ("ON" if s.auto else "OFF"), _toggle_auto.bind(id)]], col)
		bs[0].disabled = Economy.cash < Inventory.restock_cost(id)

func _restock(id: String, n: int) -> void:
	var e := Inventory.restock(id, n)
	_msg("Restocked %s" % Data.FOOD[id].name if e == "" else e, e == "")
	_refresh_screen()

func _toggle_auto(id: String) -> void:
	Inventory.stock[id].auto = not Inventory.stock[id].auto
	_refresh_screen()

func _screen_shows(vb: Control) -> void:
	for hi in 3:
		if not Upgrades.hall_ready(hi):
			continue
		var h: Dictionary = Screenings.halls[hi]
		_head(vb, "%s  (%d seats)" % [Data.HALLS[hi].name, Data.hall_seats(hi).size()])
		var pr := HBoxContainer.new()
		vb.add_child(pr)
		pr.add_child(K.label("Ticket price", 22))
		pr.add_child(K.button("-", _price.bind(hi, -Data.TICKET_STEP), 64, 52))
		pr.add_child(K.label(Data.money(h.price), 26, Color(0.6, 1, 0.6)))
		pr.add_child(K.button("+", _price.bind(hi, Data.TICKET_STEP), 64, 52))
		pr.add_child(K.label("Fair price now: %s" % Data.money(int(Game.fair_price())), 19, Color(0.75, 0.8, 0.9)))
		for s in Data.SHOW_SLOTS.size():
			var row := HBoxContainer.new()
			vb.add_child(row)
			row.add_child(K.label(Data.fmt_time(Data.SHOW_SLOTS[s]), 22, Color(1, 0.9, 0.5)))
			var ob := OptionButton.new()
			ob.custom_minimum_size = Vector2(330, 52)
			ob.add_item("- no screening -", 0)
			ob.set_item_metadata(0, "")
			var sel := 0
			for mi in Data.MOVIES.size():
				var m: Dictionary = Data.MOVIES[mi]
				var ok := Screenings.movie_unlocked(m.id)
				ob.add_item("%s%s" % [m.title, "" if ok else " (rep %d)" % m.min_rep], mi + 1)
				ob.set_item_metadata(mi + 1, m.id)
				ob.set_item_disabled(mi + 1, not ok)
				if m.id == h.slots[s]:
					sel = mi + 1
			ob.select(sel)
			ob.item_selected.connect(_assign.bind(ob, hi, s))
			row.add_child(ob)
			var stl := K.label("", 19, Color(0.75, 0.8, 0.9), true)
			for sh in h.shows:
				if int(sh.slot) == s:
					stl.text = Screenings.status_text(sh)
			row.add_child(stl)

func _price(hi: int, d: int) -> void:
	Screenings.set_price(hi, int(Screenings.halls[hi].price) + d)
	_refresh_screen()

func _assign(idx: int, ob: OptionButton, hi: int, slot: int) -> void:
	var res := Screenings.assign(hi, slot, str(ob.get_item_metadata(idx)))
	_msg(res, not res.begins_with("Movie"))
	call_deferred("_refresh_screen")

func _screen_finance(vb: Control) -> void:
	vb.add_child(K.label("Balance: %s" % Data.money(Economy.cash), 32, Color(0.6, 1, 0.6)))
	var g := GridContainer.new()
	g.columns = 2
	g.add_theme_constant_override("h_separation", 40)
	vb.add_child(g)
	var inc := VBoxContainer.new()
	var exp := VBoxContainer.new()
	inc.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	exp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	g.add_child(inc)
	g.add_child(exp)
	inc.add_child(K.label("Income today: %s" % Data.money(Economy.income_sum()), 24, Color(0.7, 1, 0.7)))
	for k in Economy.income_today:
		inc.add_child(K.label("%s  %s" % [str(k).capitalize(), Data.money(Economy.income_today[k])], 20))
	exp.add_child(K.label("Expenses today: %s" % Data.money(Economy.expense_sum()), 24, Color(1, 0.7, 0.6)))
	for k in Economy.expense_today:
		exp.add_child(K.label("%s  %s" % [str(k).capitalize(), Data.money(Economy.expense_today[k])], 20))
	vb.add_child(K.label("Wages, electricity and maintenance are charged when the day ends.", 18, Color(0.7, 0.75, 0.9), true))
	_head(vb, "Recent days")
	var hist := Economy.history.duplicate()
	hist.reverse()
	for s in hist.slice(0, 7):
		vb.add_child(K.label("Day %d: income %s, expenses %s, profit %s" % [s.day, Data.money(s.income_sum), Data.money(s.expense_sum), Data.money(s.profit)], 20))
	_head(vb, "Latest transactions")
	for e in Economy.ledger.slice(0, 12):
		vb.add_child(K.label("%s  %s  (%s)" % [Data.money(e.a), e.r, e.c], 19, Color(0.6, 1, 0.6) if int(e.a) > 0 else Color(1, 0.65, 0.55)))

func _screen_overview(vb: Control) -> void:
	vb.add_child(K.label("%s - Reputation %d/100" % [Game.rank_title(), int(Game.reputation)], 28, Color(1, 0.9, 0.5)))
	vb.add_child(K.label("Guest demand: x%.2f   Cleanliness: %d%%   Facilities: %d%%" % [Game.demand_multiplier(), int(Game.cleanliness() * 100), int(Game.facilities_score() * 100)], 21))
	vb.add_child(K.label("Advice: " + Game.top_advice(), 22, Color(1, 0.85, 0.5), true))
	_head(vb, "Guest satisfaction (last %d guests)" % Game.records.size())
	var avg := Game.factor_averages()
	for f in Data.FACTORS:
		var row := HBoxContainer.new()
		vb.add_child(row)
		var l := K.label(Data.FACTOR_NAMES[f], 20)
		l.custom_minimum_size.x = 220
		row.add_child(l)
		var pb := ProgressBar.new()
		pb.max_value = 1.0
		pb.value = avg.get(f, 0.0)
		pb.show_percentage = false
		pb.custom_minimum_size = Vector2(300, 22)
		pb.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		var v: float = avg.get(f, 0.0)
		pb.add_theme_stylebox_override("fill", K.box(Color(0.9, 0.35, 0.3).lerp(Color(0.35, 0.85, 0.45), v), 6))
		row.add_child(pb)
	_head(vb, "Halls")
	for hi in 3:
		var txt := "%s: %s" % [Data.HALLS[hi].name, "locked" if Upgrades.hall_state[hi] == "locked" else Upgrades.hall_state[hi]]
		if Upgrades.hall_ready(hi):
			var sh: Dictionary = Screenings.current_show(hi)
			if not sh.is_empty():
				txt += "  |  %s  |  %s" % [Data.movie(sh.movie).title, Screenings.status_text(sh)]
		vb.add_child(K.label(txt, 20, Color(0.85, 0.88, 1.0), true))
	vb.add_child(K.button("Achievements", open_screen.bind("achievements"), 0, 56))

func _screen_achievements(vb: Control) -> void:
	for a in Data.ACHIEVEMENTS:
		var got: bool = Game.achievements.has(a.id)
		_card(vb, ("[x] " if got else "[ ] ") + a.name, "%s  Reward: %s" % [a.desc, Data.money(a.reward)], [], Color(0.6, 1, 0.7) if got else Color(0.7, 0.7, 0.8))

func _screen_summary(vb: Control) -> void:
	var s: Dictionary = screen_arg if screen_arg != null else {}
	if s.is_empty():
		return
	vb.add_child(K.label("Day %d (%s) complete" % [s.day, s.weekday], 30, Color(1, 0.9, 0.5)))
	var pc := Color(0.6, 1, 0.6) if int(s.profit) >= 0 else Color(1, 0.5, 0.4)
	vb.add_child(K.label("Profit: %s    (income %s, expenses %s)" % [Data.money(s.profit), Data.money(s.income_sum), Data.money(s.expense_sum)], 26, pc, true))
	for k in s.income:
		vb.add_child(K.label("+ %s: %s" % [str(k).capitalize(), Data.money(s.income[k])], 20, Color(0.7, 1, 0.7)))
	for k in s.expense:
		vb.add_child(K.label("- %s: %s" % [str(k).capitalize(), Data.money(s.expense[k])], 20, Color(1, 0.7, 0.6)))
	vb.add_child(K.label("Guests arrived %d, tickets sold %d, snacks sold %d, walkouts %d" % [s.arrived, s.tickets, s.food_items, s.walkouts], 21, Color.WHITE, true))
	vb.add_child(K.label("Average satisfaction %d%%, reputation %d (%+.1f)" % [int(s.avg_sat * 100), int(s.rep), s.rep_change], 21, Color.WHITE, true))
	vb.add_child(K.label("Advice: " + s.advice, 21, Color(1, 0.85, 0.5), true))
	if s.bankrupt:
		vb.add_child(K.label("You are deeply in debt - the cinema is bankrupt! Start a new game or keep trying to recover.", 22, Color(1, 0.5, 0.4), true))
	vb.add_child(K.button("Start next day", close_screen, 0, 64))
	if s.bankrupt:
		vb.add_child(K.button("New game", _new_game, 0, 60))

func _new_game() -> void:
	Game.new_game()
	Game.summary_open = false
	get_tree().reload_current_scene()

func _screen_menu(vb: Control) -> void:
	vb.add_child(K.button("Resume", close_screen, 0, 64))
	vb.add_child(K.button("Save game", func(): _msg("Game saved" if SaveSys.save_game() else "Save failed", SaveSys.has_save()), 0, 64))
	vb.add_child(K.button("Achievements", open_screen.bind("achievements"), 0, 64))
	vb.add_child(K.button("Settings", open_screen.bind("settings"), 0, 64))
	vb.add_child(K.button("Save and exit to main menu", _to_menu, 0, 64))

func _to_menu() -> void:
	SaveSys.save_game()
	Game.in_game = false
	Game.speed = 1
	get_tree().change_scene_to_file("res://scenes/main_menu.tscn")

func _screen_settings(vb: Control) -> void:
	var cb := CheckBox.new()
	cb.text = "Autosave (end of day and when app is paused)"
	cb.button_pressed = Game.settings.autosave
	cb.toggled.connect(func(v): Game.settings.autosave = v; Game.save_settings())
	vb.add_child(cb)
	var cb2 := CheckBox.new()
	cb2.text = "Floating money text"
	cb2.button_pressed = Game.settings.fx
	cb2.toggled.connect(func(v): Game.settings.fx = v; Game.save_settings())
	vb.add_child(cb2)
	vb.add_child(K.label("Performance: maximum guests inside at once", 21))
	var ob := OptionButton.new()
	var opts := [25, 45, 70]
	for o in opts:
		ob.add_item("%d guests" % o)
	ob.select(opts.find(int(Game.settings.max_customers)) if int(Game.settings.max_customers) in opts else 1)
	ob.item_selected.connect(func(i): Game.settings.max_customers = opts[i]; Game.save_settings())
	vb.add_child(ob)
	vb.add_child(K.label("UI size (applies fully after reopening the game)", 21))
	var ob2 := OptionButton.new()
	var sizes := [0.85, 1.0, 1.25]
	for t in ["Small", "Normal", "Large"]:
		ob2.add_item(t)
	ob2.select(1)
	for i in 3:
		if absf(sizes[i] - float(Game.settings.ui_scale)) < 0.05:
			ob2.select(i)
	ob2.item_selected.connect(func(i): Game.settings.ui_scale = sizes[i]; Game.save_settings(); root.theme = K.make_theme(sizes[i]))
	vb.add_child(ob2)
	vb.add_child(K.button("Save game now", func(): _msg("Game saved" if SaveSys.save_game() else "Save failed"), 0, 60))
	vb.add_child(K.label("Cinema Tycoon: Theatre Empire v%s" % Data.VERSION, 18, Color(0.6, 0.65, 0.8)))

# --- Context panel ---------------------------------------------------------------------------------
func _build_context() -> void:
	ctx = PanelContainer.new()
	K.anchor(ctx, 0, 1, 0, 1, 8, -90, 430, -84)
	ctx.grow_vertical = Control.GROW_DIRECTION_BEGIN
	ctx.visible = false
	root.add_child(ctx)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 4)
	ctx.add_child(v)
	var hd := HBoxContainer.new()
	v.add_child(hd)
	ctx_title = K.label("", 26, Color(1, 0.9, 0.5))
	ctx_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hd.add_child(ctx_title)
	hd.add_child(K.button("X", func(): world.select({}), 52, 44))
	ctx_body = K.label("", 20, Color.WHITE, true)
	v.add_child(ctx_body)
	ctx_actions = HBoxContainer.new()
	v.add_child(ctx_actions)

func show_context(sel: Dictionary) -> void:
	ctx_sel = sel
	if sel.is_empty() or panel.visible:
		ctx.visible = false
		return
	ctx.visible = true
	K.clear(ctx_actions)
	var acts := {"tickets": ["Hire staff", "staff"], "food": ["Food menu", "food"], "storage": ["Food menu", "food"],
		"staffroom": ["Employees", "staff"], "toilets": ["Decorate", "build"], "hall": ["Screenings", "shows"]}
	if sel.type == "hall" and not Upgrades.hall_ready(sel.hall):
		acts["hall"] = ["Build", "build"]
	if acts.has(sel.type):
		ctx_actions.add_child(K.button(acts[sel.type][0], open_screen.bind(acts[sel.type][1]), 0, 52))
	_update_context()

func _update_context() -> void:
	var sel := ctx_sel
	if sel.is_empty():
		return
	if sel.has("node") and not is_instance_valid(sel.node):
		world.select({})
		return
	var t := ""
	var b := ""
	match sel.type:
		"customer":
			t = "Guest"
			b = sel.node.info_text()
		"staff":
			t = "Employee"
			b = sel.node.info_text()
		"tickets":
			t = "Ticket counter"
			b = "Cashiers: %d   Queue: %d\nTickets sold today: %d" % [Upgrades.staff_count("cashier"), world.ticket_counter.busy_count(), Game.day_stats.tickets]
		"food":
			t = "Food counter"
			b = "Servers: %d   Queue: %d\nFood level: %s" % [Upgrades.staff_count("server"), world.food_counter.busy_count(), Upgrades.level_data("food").name]
			for id in Inventory.unlocked_items():
				b += "\n%s: %d in stock" % [Data.FOOD[id].name, Inventory.qty(id)]
		"storage":
			t = "Storage"
			b = "Total items in stock: %d" % Inventory.total_stock()
		"staffroom":
			t = "Staff area"
			b = "Cashiers %d, servers %d, cleaners %d\nWages: %s/day" % [Upgrades.staff_count("cashier"), Upgrades.staff_count("server"), Upgrades.staff_count("cleaner"), Data.money(Upgrades.daily_wages())]
		"toilets":
			t = "Toilets"
			b = "Cleanliness: %d%%\nLitter around the cinema: %d" % [int(Game.cleanliness() * 100), world.litter.size()]
		"hall":
			var hi: int = sel.hall
			t = Data.HALLS[hi].name
			if not Upgrades.hall_ready(hi):
				b = "Not built yet (%s)." % Upgrades.check_build_hall(hi) if Upgrades.check_build_hall(hi) != "" else "Ready to build."
			else:
				var sh: Dictionary = Screenings.current_show(hi)
				b = "Ticket %s (fair %s)\n" % [Data.money(Screenings.halls[hi].price), Data.money(int(Game.fair_price()))]
				b += "%s\n%s" % [Data.movie(sh.movie).title, Screenings.status_text(sh)] if not sh.is_empty() else "No screening scheduled"
		"seat":
			t = "Seat"
			var sh2: Dictionary = Screenings.current_show(sel.hall)
			var st := "free"
			if not sh2.is_empty() and sh2.owners[sel.seat] != 0:
				st = "occupied" if sh2.seated[sel.seat] else "reserved"
			b = "%s, row %d\nType: %s\nComfort: %d%%\nStatus: %s" % [Data.HALLS[sel.hall].name, Data.hall_seats(sel.hall)[sel.seat].row + 1, Upgrades.level_data("seats").name, int(Upgrades.quality("seats") * 100), st]
	ctx_title.text = t
	ctx_body.text = b

# --- Toasts ---------------------------------------------------------------------------------------
func toast(msg: String, col: Color = Color.WHITE) -> void:
	var pc := PanelContainer.new()
	pc.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var l := K.label(msg, 20, col)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	pc.add_child(l)
	toast_box.add_child(pc)
	while toast_box.get_child_count() > 3:
		var old := toast_box.get_child(0)
		toast_box.remove_child(old)
		old.queue_free()
	var tw := pc.create_tween()
	tw.tween_interval(2.4)
	tw.tween_property(pc, "modulate:a", 0.0, 0.5)
	tw.tween_callback(pc.queue_free)

func _on_tx(amount: int, reason: String, category: String) -> void:
	if amount < 0 and category in ["upgrades", "construction", "supplies", "staff"]:
		toast("%s  %s" % [Data.money(amount), reason], Color(1, 0.65, 0.55))

func _process(delta: float) -> void:
	acc += delta
	if acc >= 0.25:
		acc = 0.0
		_update_top()
		if ctx.visible:
			_update_context()
	acc2 += delta
	if acc2 >= 1.0:
		acc2 = 0.0
		if panel.visible and screen in ["shows", "finance", "overview", "food", "build"] and not _popup_open():
			_refresh_screen()

func _popup_open() -> bool:
	for n in content.find_children("*", "OptionButton", true, false):
		if (n as OptionButton).get_popup().visible:
			return true
	return false
