extends SceneTree
## Headless single-player smoke test: lobby -> game -> tutorial objectives -> departure.
## Run: godot --headless --path . -s tests/smoke_single.gd

var _fails := 0


func _initialize() -> void:
	_run.call_deferred()


func check(cond: bool, what: String) -> void:
	print(("  ok    " if cond else "  FAIL  ") + what)
	if not cond:
		_fails += 1


func wait(sec: float) -> void:
	await create_timer(sec).timeout


func use(id: String) -> void:
	var w = root.get_node("/root/GameState").scene
	var it = w.interactables.get(id)
	if it == null:
		check(false, "interactable exists: " + id)
		return
	w.teleport_player(1, it.global_position + Vector3(0, 0.3, 0))
	await wait(0.15)
	w.request_interact.rpc_id(1, id)
	await wait(0.15)


func _run() -> void:
	var GS = root.get_node("/root/GameState")
	var Net = root.get_node("/root/Net")
	GS.pending_load = {}
	Net.start_single()
	change_scene_to_file("res://scenes/lobby/lobby.tscn")
	await wait(0.5)
	Net.request_char.rpc_id(1, 2)
	await wait(0.2)
	check(Net.all_chosen(), "character chosen")
	Net.request_start.rpc_id(1)
	await wait(3.0)
	check(not GS.data.is_empty(), "game state created")
	check(GS.scene != null and GS.scene.player_nodes().size() == 1, "player spawned")
	check(GS.local_player != null, "local player set")
	check(GS.scene.location != null, "location loaded")
	print("  interactables: ", GS.scene.interactables.size())
	await use("train_doc_dispatch")
	check(GS.flag("doc_d_dispatch"), "document read -> flag")
	await use("train_flash_0")
	check(GS.has_item(1, "flashlight"), "flashlight picked up")
	await use("train_fuel_0")
	check(GS.has_item(1, "fuel"), "fuel picked up")
	var before: float = GS.data["train"]["fuel"]
	await use("train_firebox")
	check(GS.data["train"]["fuel"] > before and GS.flag("s_fueled"), "firebox fed")
	await use("train_toolbox")
	check(GS.has_item(1, "hammer"), "toolbox searched")
	root.get_node("/root/Actions").req_stash.rpc_id(1, "cargo", false, 0)
	await use("train_stash_cargo")
	root.get_node("/root/Actions").req_stash.rpc_id(1, "cargo", false, 0)
	root.get_node("/root/Actions").req_stash.rpc_id(1, "cargo", false, 1)
	await wait(0.1)
	check(GS.has_item(1, "scrap", 2) and GS.has_item(1, "bolts"), "took items from stash")
	await use("train_workbench")
	root.get_node("/root/Actions").req_craft.rpc_id(1, "repair_kit", "train_workbench")
	await wait(0.1)
	check(GS.has_item(1, "repair_kit"), "crafted repair kit")
	await use("train_lever")
	check(not GS.data["traveling"], "lever refuses without course")
	root.get_node("/root/Actions").req_set_course.rpc_id(1)
	await use("train_lever")
	check(GS.data["traveling"], "train departs")
	await wait(1.0)
	check(GS.data["progress"] > 0.5, "travel progresses")
	check(root.get_node("/root/SaveSystem").exists("auto"), "autosave written")
	print("RESULT: %d failure(s)" % _fails)
	quit(1 if _fails > 0 else 0)
