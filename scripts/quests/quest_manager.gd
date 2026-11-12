extends Node
## Chapter / objective tracking. Objectives are data (res://data/quests.json) evaluated against
## the replicated flags in GameState, so every peer sees the same quest state.

signal updated

var LOCS: Array = []
var stops: Array = []
var chapters: Array = []
var radio_lines: Array = []
var endings := {}
var documents := {}


func _ready() -> void:
	var q = JSON.parse_string(FileAccess.get_file_as_string("res://data/quests.json"))
	LOCS = q["locations"]
	stops = q["stops"]
	chapters = q["chapters"]
	radio_lines = q["radio"]
	endings = q["endings"]
	documents = JSON.parse_string(FileAccess.get_file_as_string("res://data/documents.json"))
	GameState.flag_changed.connect(func(_k, _v): updated.emit())
	GameState.location_changed.connect(func(): updated.emit())
	GameState.state_loaded.connect(func(): updated.emit())


func chapter(idx := -1) -> Dictionary:
	if idx < 0:
		idx = int(GameState.data.get("loc", 0))
	return chapters[clampi(idx, 0, chapters.size() - 1)]


func is_done(obj: Dictionary) -> bool:
	return GameState.flag_count(obj["flag"]) >= int(obj.get("count", 1))


func progress_text(obj: Dictionary) -> String:
	var text := tr(obj["text"])
	var need := int(obj.get("count", 1))
	if need > 1:
		text += " (%d/%d)" % [mini(GameState.flag_count(obj["flag"]), need), need]
	return text


## Objectives of a chapter as [{obj, done}], in order.
func objectives(idx := -1) -> Array:
	var out := []
	for obj in chapter(idx)["objectives"]:
		out.append({"obj": obj, "done": is_done(obj)})
	return out


func current_text() -> String:
	if GameState.data.is_empty():
		return ""
	if GameState.data.get("traveling", false):
		return tr("Keep the train running until the next stop")
	for entry in objectives():
		if not entry["done"]:
			return progress_text(entry["obj"])
	return tr("Return to the train and depart")


## First required objective that is still open ("" when the train may leave).
func blocking_objective() -> String:
	for entry in objectives():
		if entry["obj"].get("required", false) and not entry["done"]:
			return entry["obj"]["text"]
	return ""
