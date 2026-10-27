extends Node
## Food stock: quantity, restocking, sales and profit tracking per item.

var stock: Dictionary = {}

func reset() -> void:
	stock = {}
	for id in Data.FOOD_ORDER:
		stock[id] = {"qty": 0, "sold": 0, "revenue": 0, "auto": false}

func unlocked(id: String) -> bool:
	return Upgrades.level("food") >= int(Data.FOOD[id].unlock)

func unlocked_items() -> Array:
	return Data.FOOD_ORDER.filter(func(i): return unlocked(i))

func available_items() -> Array:
	return Data.FOOD_ORDER.filter(func(i): return unlocked(i) and qty(i) > 0)

func qty(id: String) -> int:
	return int(stock[id].qty)

func cheapest_available() -> int:
	var best := -1
	for id in available_items():
		var p: int = Data.FOOD[id].price
		if best < 0 or p < best:
			best = p
	return best

func take(id: String, n: int = 1) -> bool:
	if not unlocked(id) or qty(id) < n:
		return false
	stock[id].qty -= n
	stock[id].sold += n
	stock[id].revenue += n * int(Data.FOOD[id].price)
	return true

func restock_cost(id: String, batches: int = 1) -> int:
	return int(Data.FOOD[id].batch) * int(Data.FOOD[id].cost) * batches

func restock(id: String, batches: int = 1) -> String:
	if not unlocked(id):
		return "Not unlocked"
	var cost := restock_cost(id, batches)
	if not Economy.spend(cost, "Restock: %s" % Data.FOOD[id].name, "supplies"):
		return "Not enough cash"
	stock[id].qty += int(Data.FOOD[id].batch) * batches
	return ""

func profit(id: String) -> int:
	return int(stock[id].sold) * (int(Data.FOOD[id].price) - int(Data.FOOD[id].cost))

func on_food_level(lvl: int) -> void:
	for id in Data.FOOD_ORDER:
		if int(Data.FOOD[id].unlock) == lvl:
			stock[id].qty += int(Data.FOOD[id].start)

func hourly_auto() -> void:
	for id in unlocked_items():
		if stock[id].auto and qty(id) < int(Data.FOOD[id].batch) / 2 and Economy.cash > restock_cost(id) + 1000:
			restock(id)

func total_stock() -> int:
	var t := 0
	for id in Data.FOOD_ORDER:
		t += qty(id)
	return t

func to_dict() -> Dictionary:
	return {"stock": stock}

func from_dict(d: Dictionary) -> void:
	reset()
	var s := Data.as_dict(d.get("stock"))
	for id in Data.FOOD_ORDER:
		var e := Data.as_dict(s.get(id))
		stock[id] = {"qty": maxi(0, int(e.get("qty", 0))), "sold": int(e.get("sold", 0)),
			"revenue": int(e.get("revenue", 0)), "auto": bool(e.get("auto", false))}
