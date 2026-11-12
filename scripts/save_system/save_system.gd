extends Node
## Local save files (user://saves/*.json) and the persistent profile (unlocked endings).

const DIR := "user://saves"
const SLOTS := ["auto", "slot1", "slot2", "slot3"]
const SLOT_LABELS := {"auto": "Autosave", "slot1": "Slot 1", "slot2": "Slot 2", "slot3": "Slot 3"}
const PROFILE := "user://profile.cfg"
const VERSION := 1


func _path(slot: String) -> String:
	return "%s/%s.json" % [DIR, slot]


## Host only. Returns "" on success or an (untranslated) error message.
func save(slot: String) -> String:
	if not GameState.is_host() or GameState.data.is_empty():
		return "Only the host can save."
	if GameState.data.get("traveling", false):
		return "Cannot save while the train is moving."
	DirAccess.make_dir_recursive_absolute(DIR)
	var state: Dictionary = GameState.data.duplicate(true)
	state["drops"] = GameState.scene.collect_drops() if GameState.scene else []
	var players := {}
	for id in GameState.pdata:
		var pd: Dictionary = GameState.pdata[id]
		players[ItemDB.character(pd["char"])["id"]] = {"hp": pd["hp"], "inv": pd["inv"].duplicate(true)}
	var payload := {
		"version": VERSION, "time": Time.get_datetime_string_from_system(false, true),
		"chapter": int(state["loc"]), "data": state, "players": players,
	}
	var f := FileAccess.open(_path(slot), FileAccess.WRITE)
	if f == null:
		return "Could not write the save file."
	f.store_string(JSON.stringify(payload, "\t"))
	f.close()
	return ""


func exists(slot: String) -> bool:
	return FileAccess.file_exists(_path(slot))


func has_any() -> bool:
	for s in SLOTS:
		if exists(s):
			return true
	return false


## Slot with the most recent save ("" if none).
func latest() -> String:
	var best := ""
	var best_time := 0
	for s in SLOTS:
		if exists(s):
			var t := FileAccess.get_modified_time(_path(s))
			if t >= best_time:
				best_time = t
				best = s
	return best


func info(slot: String) -> Dictionary:
	var payload := read(slot)
	if payload.is_empty():
		return {}
	return {"time": payload.get("time", ""), "chapter": int(payload.get("chapter", 0))}


func read(slot: String) -> Dictionary:
	if not exists(slot):
		return {}
	var parsed = JSON.parse_string(FileAccess.get_file_as_string(_path(slot)))
	if typeof(parsed) != TYPE_DICTIONARY or not parsed.has("data"):
		return {}
	return _normalize(parsed)


func delete(slot: String) -> void:
	if exists(slot):
		DirAccess.remove_absolute(_path(slot))


## JSON turns every number into a float; restore integers where the game expects them.
func _normalize(v):
	match typeof(v):
		TYPE_DICTIONARY:
			for k in v:
				v[k] = _normalize(v[k])
			if v.has("train"):
				for k in v["train"]:
					if v["train"][k] is int:
						v["train"][k] = float(v["train"][k])
			return v
		TYPE_ARRAY:
			for i in v.size():
				v[i] = _normalize(v[i])
			return v
		TYPE_FLOAT:
			return int(v) if v == floorf(v) and absf(v) < 1e9 else v
	return v


# --- profile ---------------------------------------------------------------

func endings_unlocked() -> Array:
	var cfg := ConfigFile.new()
	cfg.load(PROFILE)
	return cfg.get_value("profile", "endings", [])


func unlock_ending(id: String) -> void:
	var cfg := ConfigFile.new()
	cfg.load(PROFILE)
	var list: Array = cfg.get_value("profile", "endings", [])
	if id not in list:
		list.append(id)
	cfg.set_value("profile", "endings", list)
	cfg.save(PROFILE)
