extends Node
## Authoritative game state. The host mutates it; every change is replicated to clients by RPC.
## Clients never write here directly - they send requests (see Actions and World.request_interact).

signal state_loaded
signal flag_changed(key: String, value)
signal train_changed
signal player_changed(peer: int)
signal message(text: String, kind: String)
signal subtitle(speaker: String, text: String)
signal docs_changed
signal location_changed
signal stash_changed
signal ending_reached(id: String, stats: Dictionary)
signal fx(effect: String, args: Dictionary)

const INV_SIZE := 12
const STASH_SIZE := 16
const MEDICAL_SPAWN := Vector3(-2.0, 1.0, 0.0)

var data := {}
var pdata := {}               # peer id -> {"char", "name", "hp", "max_hp", "inv"}
var scene: Node = null        # the World node while a game is running
var local_player: Node = null
var pending_load := {}        # host: save payload to restore when the game scene starts


func is_host() -> bool:
	return multiplayer.is_server()


func my_id() -> int:
	return multiplayer.get_unique_id()


func me() -> Dictionary:
	return pdata.get(my_id(), {})


func loc_id() -> String:
	return Quests.LOCS[clampi(int(data.get("loc", 0)), 0, Quests.LOCS.size() - 1)]


func reset() -> void:
	data = {}
	pdata = {}
	scene = null
	local_player = null


# --- host: session start ---------------------------------------------------

func new_state() -> Dictionary:
	var cargo := Inventory.make(STASH_SIZE)
	for pair in [["scrap", 4], ["bolts", 4], ["wires", 2], ["battery", 2], ["components", 2]]:
		Inventory.add(cargo, pair[0], pair[1])
	var medical := Inventory.make(STASH_SIZE)
	for pair in [["bandage", 2], ["med_supplies", 2], ["cloth", 2]]:
		Inventory.add(medical, pair[0], pair[1])
	return {
		"loc": 0, "traveling": false, "progress": 0.0, "throttle": 1, "halted": false,
		"train": {"fuel": 34.0, "engine": 78.0, "electric": 72.0, "temp": 30.0, "systems": 80.0, "lights": true},
		"flags": {}, "docs": [], "code": "%04d" % (randi() % 9000 + 1000),
		"stash": {"cargo": cargo, "medical": medical},
		"stats": {"collapses": 0, "time": 0.0}, "drops": [],
	}


## Called by the host once every peer has loaded the game scene.
func host_begin() -> void:
	var saved_players := {}
	var state: Dictionary
	if pending_load.is_empty():
		state = new_state()
	else:
		state = pending_load["data"]
		saved_players = pending_load.get("players", {})
		state["traveling"] = false
		state["halted"] = false
		state["progress"] = 0.0
	pending_load = {}
	var players := {}
	var used_chars := []
	for id in Net.lobby:
		var c: Dictionary = ItemDB.character(Net.lobby[id]["char"])
		var saved: Dictionary = saved_players.get(c["id"], {})
		used_chars.append(c["id"])
		var inv: Array = saved.get("inv", Inventory.make(INV_SIZE))
		inv.resize(INV_SIZE)
		players[id] = {
			"char": Net.lobby[id]["char"], "name": Net.lobby[id]["name"],
			"hp": clampf(float(saved.get("hp", c["max_hp"])), 1.0, float(c["max_hp"])), "max_hp": float(c["max_hp"]), "inv": inv,
		}
	# Items carried by characters nobody picked this time go to the cargo stash.
	for cid in saved_players:
		if cid in used_chars:
			continue
		for s in saved_players[cid].get("inv", []):
			if s != null:
				var left := Inventory.add(state["stash"]["cargo"], s["id"], int(s["n"]))
				if left > 0:
					state["drops"].append({"item": s["id"], "n": left, "pos": [-28.0, 1.0, 0.0]})
	_rpc_full.rpc(state, players)


@rpc("authority", "call_local", "reliable")
func _rpc_full(state: Dictionary, players: Dictionary) -> void:
	data = state
	pdata = players
	state_loaded.emit()
	location_changed.emit()
	train_changed.emit()


# --- flags -----------------------------------------------------------------

func get_flag(key: String, default = null):
	return data.get("flags", {}).get(key, default)


func flag(key: String) -> bool:
	var v = get_flag(key)
	if v == null:
		return false
	if v is bool:
		return v
	if v is int or v is float:
		return v != 0
	return true


func flag_count(key: String) -> int:
	var v = get_flag(key, 0)
	if v is bool:
		return 1 if v else 0
	return int(v)


func set_flag(key: String, value = true) -> void:
	if not is_host():
		return
	if data["flags"].has(key) and typeof(data["flags"][key]) == typeof(value) and data["flags"][key] == value:
		return
	_rpc_flag.rpc(key, value)


func inc_flag(key: String, by := 1) -> void:
	set_flag(key, flag_count(key) + by)


@rpc("authority", "call_local", "reliable")
func _rpc_flag(key: String, value) -> void:
	data["flags"][key] = value
	flag_changed.emit(key, value)


# --- players ---------------------------------------------------------------

func player_name(peer: int) -> String:
	return pdata[peer]["name"] if pdata.has(peer) else "?"


func char_of(peer: int) -> Dictionary:
	return ItemDB.character(pdata[peer]["char"]) if pdata.has(peer) else ItemDB.character(0)


func inv(peer: int) -> Array:
	return pdata[peer]["inv"] if pdata.has(peer) else []


func has_item(peer: int, id: String, n := 1) -> bool:
	return Inventory.count(inv(peer), id) >= n


func sync_player(peer: int) -> void:
	if is_host():
		_rpc_player.rpc(peer, pdata.get(peer, {}))


@rpc("authority", "call_local", "reliable")
func _rpc_player(peer: int, pd: Dictionary) -> void:
	if pd.is_empty():
		pdata.erase(peer)
	else:
		pdata[peer] = pd
	player_changed.emit(peer)


## Host: gives items; whatever does not fit is dropped at the player's feet.
func give(peer: int, id: String, n := 1) -> void:
	if not pdata.has(peer) or n <= 0:
		return
	var left := Inventory.add(pdata[peer]["inv"], id, n)
	sync_player(peer)
	if left > 0 and scene:
		scene.spawn_drop(id, left, scene.player_pos(peer) + Vector3(0, 0.2, 0))
		notify(peer, "Inventory full - %s dropped.", ["@" + ItemDB.item_name(id)], "warn")


func take(peer: int, id: String, n := 1) -> bool:
	if not pdata.has(peer):
		return false
	var ok := Inventory.remove(pdata[peer]["inv"], id, n)
	if ok:
		sync_player(peer)
	return ok


func heal(peer: int, amount: float) -> void:
	if not pdata.has(peer):
		return
	var pd: Dictionary = pdata[peer]
	pd["hp"] = minf(pd["max_hp"], pd["hp"] + amount)
	sync_player(peer)
	fx_to(peer, "heal")


func hurt(peer: int, amount: float) -> void:
	if not is_host() or not pdata.has(peer):
		return
	var pd: Dictionary = pdata[peer]
	pd["hp"] = maxf(0.0, pd["hp"] - amount)
	fx_to(peer, "hurt", {"amount": amount})
	if scene:
		scene.player_action(peer, "hurt")
	if pd["hp"] <= 0.0:
		# The train does not let its passengers go: a collapsed survivor wakes up in the medical car.
		data["stats"]["collapses"] = int(data["stats"]["collapses"]) + 1
		pd["hp"] = 40.0
		if scene:
			scene.teleport_player(peer, MEDICAL_SPAWN)
		fx_to(peer, "collapse")
		notify_all("%s collapsed... and woke up in the medical car.", [pd["name"]], "warn")
	sync_player(peer)


## Host: a player left mid-game. Their items are dropped so nothing important is lost.
func remove_player(peer: int) -> void:
	if not pdata.has(peer):
		return
	var pos := MEDICAL_SPAWN
	if scene:
		pos = scene.player_pos(peer)
		for s in pdata[peer]["inv"]:
			if s != null:
				scene.spawn_drop(s["id"], int(s["n"]), pos + Vector3(randf_range(-0.5, 0.5), 0.2, randf_range(-0.5, 0.5)))
	notify_all("%s left the game.", [pdata[peer]["name"]], "warn")
	pdata.erase(peer)
	_rpc_player.rpc(peer, {})


# --- messages / effects ----------------------------------------------------

func notify(peer: int, key: String, args: Array = [], kind := "info") -> void:
	if peer == my_id():
		_rpc_msg(key, args, kind)
	elif peer in multiplayer.get_peers():
		_rpc_msg.rpc_id(peer, key, args, kind)


func notify_all(key: String, args: Array = [], kind := "info") -> void:
	_rpc_msg.rpc(key, args, kind)


@rpc("authority", "call_local", "reliable")
func _rpc_msg(key: String, args: Array, kind: String) -> void:
	message.emit(Loc.fmt(key, args), kind)


## Host: spoken line / radio transmission shown as a subtitle to everyone.
func say(speaker: String, key: String, args: Array = []) -> void:
	_rpc_say.rpc(speaker, key, args)


@rpc("authority", "call_local", "reliable")
func _rpc_say(speaker: String, key: String, args: Array) -> void:
	subtitle.emit(tr(speaker) if speaker != "" else "", Loc.fmt(key, args))


func fx_all(effect: String, args: Dictionary = {}) -> void:
	_rpc_fx.rpc(effect, args)


func fx_to(peer: int, effect: String, args: Dictionary = {}) -> void:
	if peer == my_id():
		_rpc_fx(effect, args)
	elif peer in multiplayer.get_peers():
		_rpc_fx.rpc_id(peer, effect, args)


@rpc("authority", "call_local", "reliable")
func _rpc_fx(effect: String, args: Dictionary) -> void:
	fx.emit(effect, args)


## Host: positional sound heard by everyone.
func sound(sound_name: String, pos: Vector3, volume_db := 0.0, max_dist := 28.0) -> void:
	fx_all("sound", {"name": sound_name, "pos": pos, "vol": volume_db, "dist": max_dist})


# --- documents, stash, train, travel ---------------------------------------

func found_doc(id: String) -> void:
	if not is_host() or id in data["docs"]:
		return
	_rpc_doc.rpc(id)
	set_flag("doc_" + id, true)


@rpc("authority", "call_local", "reliable")
func _rpc_doc(id: String) -> void:
	if id not in data["docs"]:
		data["docs"].append(id)
	docs_changed.emit()


func sync_stash() -> void:
	_rpc_stash.rpc(data["stash"])


@rpc("authority", "call_local", "reliable")
func _rpc_stash(stash: Dictionary) -> void:
	data["stash"] = stash
	stash_changed.emit()


func sync_train() -> void:
	_rpc_train.rpc(data["train"], data["progress"], data["throttle"], data["halted"])


@rpc("authority", "call_remote", "unreliable_ordered")
func _rpc_train(train: Dictionary, progress: float, throttle: int, halted: bool) -> void:
	data["train"] = train
	data["progress"] = progress
	data["throttle"] = throttle
	data["halted"] = halted
	train_changed.emit()


## Host: switch between "stopped at location" and "travelling".
func set_travel(traveling: bool, loc: int) -> void:
	_rpc_travel.rpc(traveling, loc)


@rpc("authority", "call_local", "reliable")
func _rpc_travel(traveling: bool, loc: int) -> void:
	data["traveling"] = traveling
	data["loc"] = loc
	data["progress"] = 0.0
	data["halted"] = false
	location_changed.emit()
	train_changed.emit()


func finish(ending_id: String) -> void:
	_rpc_ending.rpc(ending_id, data["stats"], data["docs"].size())


@rpc("authority", "call_local", "reliable")
func _rpc_ending(ending_id: String, stats: Dictionary, docs: int) -> void:
	stats["docs"] = docs
	SaveSystem.unlock_ending(ending_id)
	ending_reached.emit(ending_id, stats)
