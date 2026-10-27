extends Node
## Local JSON save with atomic write, backup and corruption handling.

const PATH := "user://cinema_save.json"
const TMP := "user://cinema_save.tmp"
const BAK := "user://cinema_save.bak"
## Copy of the untouched version 1 save, made once before the first migration.
const V1_ARCHIVE := "user://cinema_save_v1_archive.json"

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
	if int(d.get("version", 1)) < Data.SAVE_VERSION and FileAccess.file_exists(PATH) and not FileAccess.file_exists(V1_ARCHIVE):
		DirAccess.copy_absolute(PATH, V1_ARCHIVE)
	d = migrate(d)
	return Game.load_from(d)

## Upgrades an older save in memory. Nothing is written until the next autosave,
## and the first migration keeps an untouched archive copy.
## v1 -> v2: tier lists were extended, so old level numbers are remapped to the same tier.
func migrate(d: Dictionary) -> Dictionary:
	var v := int(d.get("version", 1))
	if v >= Data.SAVE_VERSION:
		return d
	var up := Data.as_dict(d.get("upgrades"))
	var lv := Data.as_dict(up.get("levels"))
	var maps := {"seats": [0, 1, 3, 5], "projector": [0, 1, 3, 5], "audio": [0, 2, 4]}
	for t in maps:
		var m: Array = maps[t]
		lv[t] = int(m[clampi(int(lv.get(t, 0)), 0, m.size() - 1)])
	up["levels"] = lv
	d["upgrades"] = up
	d["version"] = Data.SAVE_VERSION
	return d

func delete_save() -> void:
	for p in [PATH, BAK, TMP]:
		if FileAccess.file_exists(p):
			DirAccess.remove_absolute(p)
