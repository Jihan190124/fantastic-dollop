extends Node
## Local JSON save with atomic write, backup and corruption handling.

const PATH := "user://cinema_save.json"
const TMP := "user://cinema_save.tmp"
const BAK := "user://cinema_save.bak"

func has_save() -> bool:
	return not peek().is_empty()

func _read(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {}
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		return {}
	var txt := f.get_as_text()
	f.close()
	var j := JSON.new()
	if j.parse(txt) != OK:
		return {}
	return j.data if typeof(j.data) == TYPE_DICTIONARY else {}

func _valid(d: Dictionary) -> bool:
	if d.is_empty() or int(d.get("version", 0)) < 1:
		return false
	for k in ["economy", "upgrades", "inventory", "screenings", "game"]:
		if typeof(d.get(k)) != TYPE_DICTIONARY:
			return false
	return true

## Returns the newest valid save (main file, then backup) or {} if none.
func peek() -> Dictionary:
	var d := _read(PATH)
	if _valid(d):
		return d
	d = _read(BAK)
	return d if _valid(d) else {}

func save_game() -> bool:
	if not Game.in_game:
		return false
	var d := {"version": Data.SAVE_VERSION, "saved_at": Time.get_unix_time_from_system(),
		"economy": Economy.to_dict(), "upgrades": Upgrades.to_dict(), "inventory": Inventory.to_dict(),
		"screenings": Screenings.to_dict(), "game": Game.to_dict()}
	var f := FileAccess.open(TMP, FileAccess.WRITE)
	if f == null:
		return false
	f.store_string(JSON.stringify(d))
	f.close()
	if FileAccess.file_exists(PATH):
		DirAccess.copy_absolute(PATH, BAK)
		DirAccess.remove_absolute(PATH)
	return DirAccess.rename_absolute(TMP, PATH) == OK

func load_game() -> bool:
	var d := peek()
	if d.is_empty():
		return false
	return Game.load_from(d)

func delete_save() -> void:
	for p in [PATH, BAK, TMP]:
		if FileAccess.file_exists(p):
			DirAccess.remove_absolute(p)
