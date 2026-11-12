class_name LootContainer
extends Interactable
## Searchable crate / cabinet / desk. Its contents go straight to the searching player.

var loot: Array = []       # [[item_id, count], ...]
var style := "crate"       # crate, cabinet, desk, barrel, locker
var tool_item := ""
var quest_flag := ""
var count_flag := ""
var _lid: Node3D


func _ready() -> void:
	prompt = "Search"
	var wood := Mat.tex("planks", Color(0.55, 0.45, 0.36))
	var metal := Mat.tex("metal", Color(0.45, 0.48, 0.5))
	match style:
		"cabinet":
			Build.box(self, Vector3(0, 0.9, 0), Vector3(0.9, 1.8, 0.4), wood)
			_lid = Build.box(self, Vector3(0, 0.9, 0.22), Vector3(0.8, 1.6, 0.04), Mat.tex("wood", Color(0.5, 0.4, 0.3)), false)
			add_shape(Vector3(1.0, 1.8, 0.6), Vector3(0, 0.9, 0.05))
		"locker":
			Build.box(self, Vector3(0, 0.95, 0), Vector3(0.6, 1.9, 0.45), metal)
			_lid = Build.box(self, Vector3(0, 0.95, 0.24), Vector3(0.52, 1.75, 0.03), Mat.tex("rust", Color(0.6, 0.6, 0.6)), false)
			add_shape(Vector3(0.7, 1.9, 0.6), Vector3(0, 0.95, 0.05))
		"desk":
			Build.box(self, Vector3(0, 0.74, 0), Vector3(1.4, 0.08, 0.7), wood)
			Build.box(self, Vector3(-0.45, 0.36, 0), Vector3(0.45, 0.68, 0.64), wood)
			Build.box(self, Vector3(0.62, 0.36, 0), Vector3(0.08, 0.68, 0.64), wood)
			_lid = Build.box(self, Vector3(-0.45, 0.5, 0.34), Vector3(0.38, 0.22, 0.04), Mat.tex("wood", Color(0.45, 0.36, 0.28)), false)
			add_shape(Vector3(1.5, 0.9, 0.9), Vector3(0, 0.45, 0.05))
		"barrel":
			Build.cyl(self, Vector3(0, 0.5, 0), 0.38, 1.0, Mat.tex("rust", Color(0.6, 0.55, 0.5)), true)
			_lid = Build.cyl(self, Vector3(0, 1.02, 0), 0.36, 0.04, metal)
			add_shape(Vector3(0.9, 1.1, 0.9), Vector3(0, 0.55, 0))
		_:
			Build.box(self, Vector3(0, 0.35, 0), Vector3(0.9, 0.7, 0.7), wood)
			_lid = Build.box(self, Vector3(0, 0.73, 0), Vector3(0.94, 0.06, 0.74), Mat.tex("wood", Color(0.5, 0.4, 0.3)), false)
			add_shape(Vector3(1.0, 0.85, 0.8), Vector3(0, 0.42, 0))
	super()


func get_prompt() -> String:
	return tr("Empty") if GameState.flag(id) else tr(prompt)


func refresh() -> void:
	if _lid == null:
		return
	var opened := GameState.flag(id)
	match style:
		"cabinet", "locker":
			_lid.rotation_degrees.y = -70.0 if opened else 0.0
			_lid.position.x = -0.3 if opened else 0.0
		"desk":
			_lid.position.z = 0.55 if opened else 0.34
		_:
			_lid.rotation_degrees.z = 24.0 if opened else 0.0
			_lid.position.y = (0.86 if style == "crate" else 1.12) if opened else (0.73 if style == "crate" else 1.02)


func server_interact(peer: int) -> void:
	if GameState.flag(id):
		GameState.notify(peer, "There is nothing left here.")
		return
	if tool_item != "" and not GameState.has_item(peer, tool_item):
		GameState.sound("door_locked", global_position, -4.0, 14.0)
		GameState.notify(peer, "Nailed shut. You need: %s", ["@" + ItemDB.item_name(tool_item)], "warn")
		return
	GameState.set_flag(id, true)
	GameState.sound("creak1", global_position, -4.0, 16.0)
	GameState.scene.noise(global_position, 7.0)
	GameState.scene.player_action(peer, "interact")
	var bonus: float = GameState.char_of(peer)["loot"]
	if loot.is_empty():
		GameState.notify(peer, "Nothing useful.")
	for entry in loot:
		var n := int(entry[1])
		if ItemDB.items[entry[0]]["type"] == "resource" and randf() < bonus:
			n += 1
		GameState.give(peer, entry[0], n)
		GameState.notify(peer, "Found: %s x%d", ["@" + ItemDB.item_name(entry[0]), n], "good")
	if quest_flag != "":
		GameState.set_flag(quest_flag, true)
	if count_flag != "":
		GameState.inc_flag(count_flag)
