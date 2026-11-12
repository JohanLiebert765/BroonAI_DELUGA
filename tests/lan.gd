extends SceneTree
## Headless LAN test: one host and two clients on localhost, each its own process.
## Run: tests/run_lan.sh   (or: godot --headless --path . -s tests/lan.gd -- host|client_a|client_b [port])
## client_a tries to steal the host's character, plays through a few replicated actions;
## client_b disconnects mid-game and the session must carry on.

var _fails := 0
var role := "host"
var port := 24777
var GS: Node
var net: Node


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		role = args[0]
	if args.size() > 1:
		port = int(args[1])
	_run.call_deferred()


func check(cond: bool, what: String) -> void:
	print(("  ok    [%s] " % role if cond else "  FAIL  [%s] " % role) + what)
	if not cond:
		_fails += 1


func wait(sec: float) -> void:
	await create_timer(sec).timeout


func until(cond: Callable, timeout := 20.0) -> bool:
	var t := 0.0
	while t < timeout:
		if cond.call():
			return true
		await wait(0.1)
		t += 0.1
	return false


func finish() -> void:
	print("RESULT[%s]: %d failure(s)" % [role, _fails])
	quit(1 if _fails > 0 else 0)


func _run() -> void:
	GS = root.get_node("/root/GameState")
	net = root.get_node("/root/Net")
	GS.pending_load = {}
	if role == "host":
		await _host()
	else:
		await _client()
	finish()


func _host() -> void:
	check(net.host(port) == OK, "server opened on port %d" % port)
	change_scene_to_file("res://scenes/lobby/lobby.tscn")
	check(await until(func(): return net.lobby.size() == 3), "two clients joined the lobby")
	net.request_char.rpc_id(1, 0)
	check(await until(func(): return net.all_chosen()), "every player chose a character")
	var chars := {}
	for id in net.lobby:
		chars[net.lobby[id]["char"]] = true
	check(chars.size() == 3, "characters are unique")
	net.request_start.rpc_id(1)
	check(await until(func(): return GS.scene != null and GS.scene.player_nodes().size() == 3), "three players spawned")
	check(await until(func(): return GS.flag("doc_d_dispatch")), "client interaction validated by host (document)")
	check(await until(func(): return GS.flag("s_fueled")), "client fed the firebox")
	check(not GS.data["traveling"], "client lever refused: no course, players checked by host")
	check(not GS.flag("hacked"), "client cannot write host state directly")
	check(await until(func(): return GS.scene.player_nodes().size() == 2 and GS.pdata.size() == 2, 30.0), "disconnected client removed, session continues")
	root.get_node("/root/Actions").req_set_course.rpc_id(1)
	var w = GS.scene
	for p in w.player_nodes():
		if not w.is_on_train(w.player_pos(p.peer_id)):
			w.teleport_player(p.peer_id, Vector3(4, 1.2, 0))
	await wait(0.6)
	w.teleport_player(1, w.interactables["train_lever"].global_position + Vector3(0, 0.3, 0))
	await wait(0.2)
	w.request_interact.rpc_id(1, "train_lever")
	check(await until(func(): return GS.data["traveling"], 5.0), "host departs with remaining client aboard")
	GS.data["progress"] = 99.5
	check(await until(func(): return GS.loc_id() == "ravenwood" and not GS.data["traveling"], 10.0), "arrived at Ravenwood")
	await wait(3.0)


func _client() -> void:
	await wait(1.0 if role == "client_a" else 1.6)
	check(net.join("127.0.0.1", port) == OK, "connecting")
	change_scene_to_file("res://scenes/lobby/lobby.tscn")
	check(await until(func(): return net.lobby.has(net.my_id())), "registered in lobby")
	check(await until(func(): return net.lobby.has(1) and net.lobby[1]["char"] == 0), "host choice replicated")
	net.request_char.rpc_id(1, 0)
	await wait(0.5)
	check(net.lobby[net.my_id()]["char"] == -1, "duplicate character refused")
	net.request_start.rpc_id(1)
	var mine := 1 if role == "client_a" else 2
	net.request_char.rpc_id(1, mine)
	check(await until(func(): return net.lobby[net.my_id()]["char"] == mine), "own character accepted")
	check(await until(func(): return GS.scene != null and GS.local_player != null and GS.scene.player_nodes().size() == 3), "in game with three players")
	check(not GS.is_host(), "client is not authoritative")
	var w = GS.scene
	if role == "client_b":
		await wait(4.0)
		check(GS.flag("doc_d_dispatch"), "flag set by another client replicated")
		net.leave()
		await wait(0.5)
		return
	await wait(1.0)
	GS.local_player.teleport(w.interactables["train_doc_dispatch"].global_position + Vector3(0, 0.3, 0))
	await wait(0.5)
	w.request_interact.rpc_id(1, "train_doc_dispatch")
	check(await until(func(): return GS.flag("doc_d_dispatch"), 5.0), "document flag replicated back")
	GS.local_player.teleport(w.interactables["train_fuel_0"].global_position + Vector3(0, 0.3, 0))
	await wait(0.5)
	w.request_interact.rpc_id(1, "train_fuel_0")
	check(await until(func(): return GS.has_item(net.my_id(), "fuel"), 5.0), "picked up fuel: inventory replicated")
	# Too far away: the host must refuse.
	w.request_interact.rpc_id(1, "train_firebox")
	await wait(0.5)
	check(GS.has_item(net.my_id(), "fuel"), "out-of-range interaction refused by host")
	GS.local_player.teleport(w.interactables["train_firebox"].global_position + Vector3(0, 0.3, 0))
	await wait(0.5)
	w.request_interact.rpc_id(1, "train_firebox")
	check(await until(func(): return GS.flag("s_fueled"), 5.0), "firebox fed")
	GS.local_player.teleport(w.interactables["train_lever"].global_position + Vector3(0, 0.3, 0))
	await wait(0.5)
	w.request_interact.rpc_id(1, "train_lever")
	GS.set_flag("hacked", true)
	check(await until(func(): return w.player_nodes().size() == 2, 30.0), "other client's departure replicated")
	check(await until(func(): return GS.loc_id() == "ravenwood" and not GS.data["traveling"], 40.0), "travel and arrival replicated")
	check(await until(func(): return w.location != null and w.interactables.has("rw_power"), 5.0), "Ravenwood built on client")
