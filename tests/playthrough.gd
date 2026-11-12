extends SceneTree
## Headless full playthrough: every chapter's objectives through the real interactables,
## then one of the three endings.
## Run: godot --headless --path . -s tests/playthrough.gd -- terminus|bypass|passengers

var _fails := 0
var GS: Node
var ending := "terminus"
var _got_ending := ""


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if not args.is_empty():
		ending = args[0]
	_run.call_deferred()


func check(cond: bool, what: String) -> void:
	print(("  ok    " if cond else "  FAIL  ") + what)
	if not cond:
		_fails += 1


func wait(sec: float) -> void:
	await create_timer(sec).timeout


func use(id: String) -> void:
	var w = GS.scene
	var it = w.interactables.get(id)
	if it == null:
		check(false, "interactable exists: " + id)
		return
	w.teleport_player(1, it.global_position + Vector3(0, 0.3, 0))
	await wait(0.12)
	w.request_interact.rpc_id(1, id)
	await wait(0.12)


## Stows everything except `keep` so later pickups always fit (a player would use the stash).
func stow(keep: Array) -> void:
	var inv: Array = GS.inv(1)
	for i in inv.size():
		if inv[i] != null and not keep.has(inv[i]["id"]):
			inv[i] = null
	GS.sync_player(1)


func depart(next_loc: String) -> void:
	var w = GS.scene
	root.get_node("/root/Actions").req_set_course.rpc_id(1)
	GS.data["train"]["fuel"] = maxf(GS.data["train"]["fuel"], 60.0)
	await use("train_lever")
	check(GS.data["traveling"], "departed toward " + next_loc)
	if not GS.data["traveling"]:
		return
	await wait(0.5)
	GS.data["progress"] = 99.5
	await wait(2.5)
	if next_loc != "":
		check(GS.loc_id() == next_loc and not GS.data["traveling"], "arrived at " + next_loc)
		check(w.location != null and w.location.get_child_count() > 20, "location built: " + next_loc)
		print("  interactables: %d, enemies: %d" % [w.interactables.size(), w.enemies.get_child_count()])


func _run() -> void:
	GS = root.get_node("/root/GameState")
	var net = root.get_node("/root/Net")
	GS.pending_load = {}
	GS.ending_reached.connect(func(id, _stats): _got_ending = id)
	net.start_single()
	change_scene_to_file("res://scenes/lobby/lobby.tscn")
	await wait(0.5)
	net.request_char.rpc_id(1, 0)
	await wait(0.2)
	net.request_start.rpc_id(1)
	await wait(3.0)
	check(GS.scene != null and GS.loc_id() == "siding", "game started at the siding")

	print("== Chapter I")
	await use("train_doc_dispatch")
	await use("train_fuel_0")
	await use("train_firebox")
	check(root.get_node("/root/Quests").blocking_objective() == "", "siding objectives complete")
	await depart("ravenwood")

	print("== Chapter II")
	await use("train_lever")
	check(not GS.data["traveling"], "cannot pass the red signal")
	await use("rw_warehouse_door")
	check(not GS.flag("rw_warehouse_door"), "warehouse locked without key")
	await use("rw_office_desk")
	check(GS.flag("rw_key") and GS.has_item(1, "key_warehouse"), "warehouse key found")
	await use("rw_warehouse_door")
	check(GS.flag("rw_warehouse_door"), "warehouse opens with key")
	await use("rw_fuel_a")
	check(GS.flag("rw_fuel"), "reserve fuel found")
	await use("rw_fuse_a")
	await use("rw_power")
	check(not GS.flag("rw_power"), "lever dead without generator and fuse")
	await use("rw_generator")
	await use("rw_fusebox")
	check(GS.flag("rw_generator") and GS.flag("rw_fusebox"), "generator fuelled, fuse fitted")
	await use("rw_power")
	check(GS.flag("rw_power"), "signal power restored")
	await use("rw_box_locker")
	await use("rw_records_door")
	check(GS.flag("rw_records_door"), "records room opens with key")
	await use("rw_doc_logbook")
	check(GS.flag("doc_d_logbook"), "logbook read")
	await use("rw_wrench")
	stow(["wrench"])
	await depart("forest")

	print("== Chapter III")
	await use("fr_hut_door")
	check(not GS.flag("fr_hut_door"), "hut barred without crowbar")
	await use("fr_crowbar")
	await use("fr_hut_door")
	check(GS.flag("fr_hut_door"), "hut forced with crowbar")
	await use("fr_rod")
	await use("fr_switch")
	check(not GS.flag("fr_switch"), "switch needs both parts")
	GS.scene.teleport_player(1, Vector3(-24, 0.5, -56))
	await wait(1.0)
	check(GS.flag("fr_camp"), "camp discovered by trigger")
	await use("fr_lever")
	check(GS.flag_count("fr_parts") == 2, "both switch parts counted")
	await use("fr_camp_crate")
	await use("fr_camp_barrel")
	await use("fr_cart_crate")
	check(GS.flag_count("fr_mats") >= 3, "materials counted")
	await use("fr_switch")
	check(GS.flag("fr_switch"), "switch restored")
	stow(["wrench", "crowbar", "scrap"])
	await depart("village")

	print("== Chapter IV")
	check(GS.data["train"]["engine"] <= 22.0, "engine failed on arrival")
	await use("train_lever")
	check(not GS.data["traveling"], "cannot leave with a broken engine")
	await use("vl_radio_item")
	check(GS.flag("vl_radio"), "radio found")
	var slot := -1
	var inv: Array = GS.inv(1)
	for i in inv.size():
		if inv[i] != null and inv[i]["id"] == "radio":
			slot = i
	root.get_node("/root/Actions").req_use.rpc_id(1, slot)
	await wait(0.2)
	check(GS.flag("vl_code"), "radio gives the cellar code")
	GS.scene.teleport_player(1, GS.scene.interactables["vl_cellar_door"].global_position + Vector3(0, 0.3, -0.5))
	await wait(0.15)
	root.get_node("/root/Actions").req_keypad.rpc_id(1, "vl_cellar_door", "0000")
	await wait(0.1)
	check(not GS.flag("vl_cellar_door_unlocked"), "wrong code rejected")
	root.get_node("/root/Actions").req_keypad.rpc_id(1, "vl_cellar_door", str(GS.data["code"]))
	await wait(0.1)
	check(GS.flag("vl_cellar_door_unlocked"), "cellar unlocked with code")
	await use("vl_doc_confession")
	await use("vl_engine_part")
	await use("vl_comp_a")
	await use("vl_comp_b")
	check(GS.flag_count("vl_parts") == 3, "locomotive parts counted")
	await use("train_engine")
	check(GS.data["train"]["engine"] >= 60.0, "engine repaired with the engine part")
	await wait(0.3)
	check(GS.flag("vl_engine"), "engine objective complete")
	stow(["crowbar"])
	await depart("tunnel")

	print("== Chapter V")
	await use("tn_office_locker")
	await use("tn_fuel_a")
	await use("tn_wheel")
	await use("tn_wagon_crate")
	check(GS.flag_count("tn_parts") == 2, "gate parts counted")
	await use("tn_gate")
	check(not GS.flag("tn_gate"), "winch dead without power")
	await use("tn_power")
	check(GS.flag("tn_power"), "tunnel power restored")
	await use("tn_gate")
	check(GS.flag("tn_gate"), "gate raised")
	if ending == "terminus":
		await use("tn_hut_door")
		check(GS.flag("tn_hut_door"), "watchman's hut forced")
		await use("tn_doc_truth")
		check(GS.flag("doc_d_truth"), "manifest read")
	if ending != "bypass":
		await use("tn_junction")
		check(GS.flag("tn_junction"), "junction set for Hollowgate")
		await use("tn_junction")
		check(not GS.flag("tn_junction"), "junction toggles back")
		await use("tn_junction")
	await depart("")
	check(_got_ending == ending, "ending reached: %s (got '%s')" % [ending, _got_ending])
	check(root.get_node("/root/SaveSystem").endings_unlocked().has(ending), "ending recorded in profile")
	print("RESULT: %d failure(s)" % _fails)
	quit(1 if _fails > 0 else 0)
