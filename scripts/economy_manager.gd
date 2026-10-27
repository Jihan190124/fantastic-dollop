extends Node
## Central economy: every transaction goes through earn()/spend() with a reason + category.

signal cash_changed(cash: int)
signal transaction(amount: int, reason: String, category: String)

var cash: int = 0
var income_today: Dictionary = {}
var expense_today: Dictionary = {}
var income_total: int = 0
var expense_total: int = 0
var history: Array = []
var ledger: Array = []

func reset() -> void:
	cash = Data.START_CASH
	income_today = {}
	expense_today = {}
	income_total = 0
	expense_total = 0
	history = []
	ledger = []
	cash_changed.emit(cash)

func can_afford(amount: int) -> bool:
	return amount <= cash

func earn(amount: int, reason: String, category: String) -> void:
	if amount <= 0 or reason == "":
		return
	cash += amount
	income_total += amount
	income_today[category] = int(income_today.get(category, 0)) + amount
	_record(amount, reason, category)

## Returns false (and changes nothing) if the player cannot afford it, unless force is set
## (used only for mandatory bills such as wages and electricity).
func spend(amount: int, reason: String, category: String, force: bool = false) -> bool:
	if reason == "":
		return false
	if amount <= 0:
		return true
	if amount > cash and not force:
		return false
	cash -= amount
	expense_total += amount
	expense_today[category] = int(expense_today.get(category, 0)) + amount
	_record(-amount, reason, category)
	return true

func _record(amount: int, reason: String, category: String) -> void:
	ledger.push_front({"a": amount, "r": reason, "c": category, "d": Game.day})
	if ledger.size() > 60:
		ledger.resize(60)
	cash_changed.emit(cash)
	transaction.emit(amount, reason, category)

func _sum(d: Dictionary) -> int:
	var t := 0
	for k in d:
		t += int(d[k])
	return t

func income_sum() -> int:
	return _sum(income_today)

func expense_sum() -> int:
	return _sum(expense_today)

func profit_today() -> int:
	return income_sum() - expense_sum()

func archive_day(day: int, extra: Dictionary) -> Dictionary:
	var s := {"day": day, "income": income_today.duplicate(), "expense": expense_today.duplicate(),
		"income_sum": income_sum(), "expense_sum": expense_sum(), "profit": profit_today(), "cash": cash}
	s.merge(extra)
	history.append(s)
	if history.size() > 30:
		history.pop_front()
	income_today = {}
	expense_today = {}
	return s

func to_dict() -> Dictionary:
	return {"cash": cash, "income_today": income_today, "expense_today": expense_today,
		"income_total": income_total, "expense_total": expense_total, "history": history, "ledger": ledger}

func from_dict(d: Dictionary) -> void:
	cash = int(d.get("cash", Data.START_CASH))
	income_today = _ints(Data.as_dict(d.get("income_today")))
	expense_today = _ints(Data.as_dict(d.get("expense_today")))
	income_total = int(d.get("income_total", 0))
	expense_total = int(d.get("expense_total", 0))
	history = Data.as_array(d.get("history"))
	ledger = Data.as_array(d.get("ledger"))
	cash_changed.emit(cash)

func _ints(d: Dictionary) -> Dictionary:
	var o := {}
	for k in d:
		o[str(k)] = int(d[k])
	return o
