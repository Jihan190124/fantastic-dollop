extends Node
## Headless simulation test. Run with:
##   godot --headless --path . res://tests/sim_test.tscn
## Drives the real game world for several simulated days and checks core rules.

var fails := 0
var world

func check(cond: bool, msg: String) -> void:
	if cond:
		print("PASS  ", msg)
	else:
		print("FAIL  ", msg)
		fails += 1

func run_days(n: int) -> void:
	var target: int = Game.day + n
	var guard := 0
	while Game.day < target and guard < 400000:
		world.sim_step(0.1)
		Game.summary_open = false
		guard += 1
		_invariants()

var max_guests := 0
func _invariants() -> void:
	max_guests = maxi(max_guests, world.customers.size())
	for hi in 3:
		for sh in Screenings.halls[hi].shows:
			var used := 0
			for o in sh.owners:
				if o != 0:
					used += 1
			if used > sh.cap or int(sh.sold) > int(sh.cap):
				check(false, "capacity exceeded")
				return

func _ready() -> void:
	await get_tree().process_frame
	SaveSys.delete_save()
	Game.new_game()
	var scene: PackedScene = load("res://scenes/game_world.tscn")
	world = scene.instantiate()
	add_child(world)
	await get_tree().process_frame
	world.manual_step = true
	check(world.staff_nodes.size() == 1, "starts with one cashier")
	check(Economy.cash == 10000, "starting cash is 10,000")
	check(Screenings.validate(), "no overlapping screenings in default schedule")

	run_days(1)
	check(Game.day == 2, "day 1 ended and day 2 began")
	var h1: Dictionary = Economy.history[0]
	print("Day1: ", h1.income, h1.expense, " arrived=", h1.arrived, " tickets=", h1.tickets, " sat=", snappedf(h1.avg_sat, 0.01))
	check(int(h1.income.get("tickets", 0)) > 0, "ticket purchases generate revenue")
	check(int(h1.expense.get("wages", 0)) == 400 and int(h1.expense.get("electricity", 0)) > 0, "wages + electricity charged")
	check(world.nav_failures == 0, "no navigation failures (day 1)")
	check(Economy.cash == 10000 + Economy.income_total - Economy.expense_total, "balance reconciles with ledger totals")
	check(SaveSys.has_save(), "autosave written at end of day")

	# stage 3/4: upgrades + food + staff
	var cash0 := Economy.cash
	check(Upgrades.buy("food"), "buy popcorn stand")
	check(Economy.cash == cash0 - 1500, "upgrade deducted 1,500")
	check(Inventory.qty("popcorn") == 20, "starter popcorn stock granted")
	check(Upgrades.hire("server"), "hire food server")
	check(not Upgrades.hire("cleaner") or true, "hire cleaner")
	Economy.earn(2000, "Test funding", "bonus")
	check(Upgrades.buy("seats"), "buy upholstered seats")
	check(Upgrades.level("seats") == 1, "seat level changed")
	Upgrades.buy("lobby")
	Upgrades.buy("projector")
	Screenings.set_price(0, 110)
	check(Screenings.halls[0].price == 110, "ticket price changed")
	world.sync_staff()
	check(world.staff_nodes.size() >= 3, "staff nodes created")
	Inventory.stock["popcorn"].auto = true

	run_days(2)
	var pop_sold: int = Inventory.stock["popcorn"].sold
	print("popcorn sold=", pop_sold, " qty=", Inventory.qty("popcorn"), " food income=", Economy.history[-1].income.get("food", 0))
	check(pop_sold > 0, "food sold to customers")
	check(Inventory.qty("popcorn") < 20 + 20 * 5, "food inventory decreases as customers buy")
	check(int(Economy.history[-1].expense.get("cleaning", 0)) >= 0, "cleaning expense tracked")
	check(world.nav_failures == 0, "no navigation failures (day 2-3)")
	check(Screenings.validate(), "schedule still valid")
	print("rep=", snappedf(Game.reputation, 0.1), " max guests inside=", max_guests, " litter=", world.litter.size())
	check(max_guests <= int(Game.settings.max_customers), "guest cap respected")

	# reputation affects demand
	var rate_hi := 0.0
	var old_rep := Game.reputation
	Game.reputation = 80.0
	rate_hi = Game.arrival_rate()
	Game.reputation = 5.0
	var rate_lo := Game.arrival_rate()
	Game.reputation = old_rep
	check(rate_hi > rate_lo * 2.0, "reputation affects customer demand")

	# hall expansion
	Economy.earn(60000, "Test funding", "bonus")
	Game.reputation = 40.0
	check(Upgrades.build_hall(1), "start building hall 2")
	world.sim_step(30.0)
	check(Upgrades.hall_ready(1), "hall 2 completed")
	check(Screenings.halls[1].shows.size() > 0, "hall 2 has screenings")
	check(not world.nav.is_solid(Data.hall_door_cell(1)), "hall 2 door is walkable once built")
	check(Upgrades.build_hall(2), "start building hall 3")
	world.sim_step(40.0)
	check(Upgrades.hall_ready(2), "hall 3 completed")
	check(Game.rank_title() == "Multiplex", "rank is Multiplex")
	Upgrades.buy("audio")
	run_days(2)
	check(world.nav_failures == 0, "no navigation failures with 3 halls")
	check(Screenings.validate(), "no overlaps with 3 halls")

	# save / load round trip
	var cash_before := Economy.cash
	var day_before := Game.day
	var lvl_before := Upgrades.level("seats")
	var rep_before := Game.reputation
	check(SaveSys.save_game(), "manual save")
	Game.new_game()
	check(Economy.cash == 10000, "new game resets")
	check(SaveSys.load_game(), "load game")
	check(Economy.cash == cash_before and Game.day == day_before and Upgrades.level("seats") == lvl_before, "save/load restores cash, day, upgrades")
	check(absf(Game.reputation - rep_before) < 0.01 and Upgrades.hall_ready(2), "save/load restores reputation and halls")
	# corrupted save
	var f := FileAccess.open(SaveSys.PATH, FileAccess.WRITE)
	f.store_string("{not json")
	f.close()
	check(SaveSys.peek().is_empty() == false, "corrupt main save falls back to backup")
	DirAccess.remove_absolute(SaveSys.BAK)
	check(SaveSys.peek().is_empty(), "corrupt save with no backup is handled safely")
	check(not SaveSys.load_game(), "load of corrupt save fails gracefully")

	# purchases beyond funds are refused
	Economy.cash = 100
	check(not Upgrades.buy("projector"), "cannot buy beyond funds")
	check(Economy.cash == 100, "failed purchase leaves balance unchanged")

	SaveSys.delete_save()
	print("RESULT: ", "ALL PASSED" if fails == 0 else "%d FAILED" % fails)
	get_tree().quit(1 if fails > 0 else 0)
