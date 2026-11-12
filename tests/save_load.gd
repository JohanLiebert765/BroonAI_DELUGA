extends SceneTree
## Headless save/load test: progress to Ravenwood, save, quit to a fresh session, load.
## Run: godot --headless --path . -s tests/save_load.gd

var _fails := 0
var GS: Node
var net: Node


func _initialize() -> void:
	_run.call_deferred()


func check(cond: bool, what: String) -> void:
	print(("  ok    " if cond else "  FAIL  ") + what)
	if not cond:
		_fails += 1


func wait(sec: float) -> void:
	await create_timer(sec).timeout


func use(id: String) -> void:
	var w = GS.scene
	w.teleport_player(1, w.interactables[id].global_position + Vector3(0, 0.3, 0))
	await wait(0.12)
	w.request_interact.rpc_id(1, id)
	await wait(0.12)


func start(char_idx: int) -> void:
	net.start_single()
	change_scene_to_file("res://scenes/lobby/lobby.tscn")
	await wait(0.5)
	net.request_char.rpc_id(1, char_idx)
	await wait(0.2)
	net.request_start.rpc_id(1)
	await wait(3.0)


func _run() -> void:
	GS = root.get_node("/root/GameState")
	net = root.get_node("/root/Net")
	var saves = root.get_node("/root/SaveSystem")
	GS.pending_load = {}
	await start(1)
	await use("train_doc_dispatch")
	await use("train_fuel_0")
	await use("train_firebox")
	root.get_node("/root/Actions").req_set_course.rpc_id(1)
	await use("train_lever")
	check(GS.data["traveling"], "departed")
	check(saves.save("test_moving") != "" or not saves.exists("test_moving"), "manual save refused while moving")
	GS.data["progress"] = 99.5
	await wait(2.5)
	check(GS.loc_id() == "ravenwood", "at Ravenwood")
	await use("rw_office_desk")
	await use("rw_yard_crate")
	GS.hurt(1, 30.0)
	var hp: float = GS.pdata[1]["hp"]
	var fuel: float = GS.data["train"]["fuel"]
	var code: String = str(GS.data["code"])
	saves.save("test_slot")
	check(saves.exists("test_slot"), "save file written")
	var info: Dictionary = saves.info("test_slot")
	print("  save info: ", info)

	# Leave completely, then load.
	net.leave()
	GS.reset()
	change_scene_to_file("res://scenes/main_menu/main_menu.tscn")
	await wait(1.0)
	check(GS.data.is_empty(), "state cleared after leaving")
	var payload: Dictionary = saves.read("test_slot")
	check(not payload.is_empty(), "save file readable")
	GS.pending_load = payload
	await start(1)
	check(GS.loc_id() == "ravenwood" and not GS.data["traveling"], "loaded at Ravenwood")
	check(GS.scene.location != null and GS.scene.interactables.has("rw_power"), "Ravenwood rebuilt")
	check(GS.flag("rw_key") and GS.flag("doc_d_dispatch") and GS.flag("s_fueled"), "quest flags restored")
	check(GS.has_item(1, "key_warehouse"), "inventory restored")
	check(is_equal_approx(GS.pdata[1]["hp"], hp), "health restored (%s)" % GS.pdata[1]["hp"])
	check(absf(GS.data["train"]["fuel"] - fuel) < 1.0, "train fuel restored")
	check(str(GS.data["code"]) == code, "cellar code restored")
	check(GS.flag("rw_office_desk") and not GS.scene.interactables["rw_office_desk"].can_interact() or GS.scene.interactables["rw_office_desk"].get_prompt() == "Empty", "searched container stays empty")
	check(GS.docs_count() >= 1 if GS.has_method("docs_count") else GS.data["docs"].size() >= 1, "documents restored")
	saves.delete("test_slot")
	check(not saves.exists("test_slot"), "save deleted")
	print("RESULT: %d failure(s)" % _fails)
	quit(1 if _fails > 0 else 0)
