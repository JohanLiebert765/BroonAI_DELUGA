extends Node
## Client -> host requests for inventory, crafting, stash and keypad actions.
## Every handler runs on the host only and validates before changing GameState.

const REACH := 5.5


func _player(peer: int) -> Dictionary:
	return GameState.pdata.get(peer, {})


func _near(peer: int, interactable_id: String) -> Node:
	var world = GameState.scene
	if world == null:
		return null
	var it = world.interactables.get(interactable_id)
	if it == null or not is_instance_valid(it):
		return null
	if world.player_pos(peer).distance_to(it.global_position) > REACH:
		return null
	return it


func _take_from_slot(inv: Array, slot: int, n := 1) -> void:
	var s = inv[slot]
	s["n"] = int(s["n"]) - n
	if int(s["n"]) <= 0:
		inv[slot] = null


@rpc("any_peer", "call_local", "reliable")
func req_use(slot: int) -> void:
	if not GameState.is_host():
		return
	var peer := Net.sender()
	var pd := _player(peer)
	if pd.is_empty() or slot < 0 or slot >= pd["inv"].size() or pd["inv"][slot] == null:
		return
	var id: String = pd["inv"][slot]["id"]
	var def: Dictionary = ItemDB.items[id]
	if def.has("heal"):
		if pd["hp"] >= pd["max_hp"]:
			GameState.notify(peer, "You are not hurt.")
			return
		_take_from_slot(pd["inv"], slot)
		GameState.scene.player_action(peer, "use")
		GameState.heal(peer, float(def["heal"]))
	elif id == "battery":
		req_reload_for(peer)
	elif id == "radio":
		_use_radio(peer)
	elif id == "map":
		GameState.fx_to(peer, "open_map")
	elif id == "flashlight" or id == "flashlight_plus":
		GameState.fx_to(peer, "toggle_flashlight")
	else:
		GameState.notify(peer, "Use it on the right device: look at it and press the interact key.")


@rpc("any_peer", "call_local", "reliable")
func req_reload() -> void:
	if GameState.is_host():
		req_reload_for(Net.sender())


func req_reload_for(peer: int) -> void:
	var pd := _player(peer)
	if pd.is_empty():
		return
	if not (GameState.has_item(peer, "flashlight") or GameState.has_item(peer, "flashlight_plus")):
		GameState.notify(peer, "You have no flashlight.")
		return
	if not GameState.take(peer, "battery", 1):
		GameState.notify(peer, "No batteries.", [], "warn")
		return
	GameState.scene.player_action(peer, "use")
	GameState.fx_to(peer, "reload")


@rpc("any_peer", "call_local", "reliable")
func req_drop(slot: int) -> void:
	if not GameState.is_host():
		return
	var peer := Net.sender()
	var pd := _player(peer)
	if pd.is_empty() or slot < 0 or slot >= pd["inv"].size() or pd["inv"][slot] == null:
		return
	var s: Dictionary = pd["inv"][slot]
	pd["inv"][slot] = null
	GameState.sync_player(peer)
	var world = GameState.scene
	world.spawn_drop(s["id"], int(s["n"]), world.player_pos(peer) + world.player_forward(peer) * 0.9 + Vector3(0, 0.15, 0))
	world.player_action(peer, "interact")


@rpc("any_peer", "call_local", "reliable")
func req_move(from: int, to: int) -> void:
	if not GameState.is_host():
		return
	var peer := Net.sender()
	var pd := _player(peer)
	if pd.is_empty():
		return
	Inventory.move(pd["inv"], from, to)
	GameState.sync_player(peer)


@rpc("any_peer", "call_local", "reliable")
func req_craft(recipe_id: String, station_id: String) -> void:
	if not GameState.is_host():
		return
	var peer := Net.sender()
	var pd := _player(peer)
	var recipe := ItemDB.recipe(recipe_id)
	var station := _near(peer, station_id)
	if pd.is_empty() or recipe.is_empty() or station == null or station.get("station") != recipe["station"]:
		return
	var msg := Crafting.check(pd["inv"], recipe)
	if msg != "":
		GameState.notify(peer, msg, [], "warn")
		return
	Crafting.apply(pd["inv"], recipe)
	GameState.sync_player(peer)
	GameState.notify(peer, "Crafted: %s", ["@" + ItemDB.item_name(recipe["result"])], "good")
	GameState.sound("craft", station.global_position, -4.0)
	GameState.scene.player_action(peer, "use")
	GameState.scene.noise(station.global_position, 10.0)


## Moves a whole stack between the player's inventory and a shared train stash.
@rpc("any_peer", "call_local", "reliable")
func req_stash(stash_id: String, to_stash: bool, slot: int) -> void:
	if not GameState.is_host():
		return
	var peer := Net.sender()
	var pd := _player(peer)
	if pd.is_empty() or not GameState.data["stash"].has(stash_id) or _near(peer, "train_stash_" + stash_id) == null:
		return
	var stash: Array = GameState.data["stash"][stash_id]
	var from: Array = pd["inv"] if to_stash else stash
	var to: Array = stash if to_stash else pd["inv"]
	if slot < 0 or slot >= from.size() or from[slot] == null:
		return
	var s: Dictionary = from[slot]
	var left := Inventory.add(to, s["id"], int(s["n"]))
	if left > 0:
		s["n"] = left
	else:
		from[slot] = null
	GameState.sync_player(peer)
	GameState.sync_stash()


@rpc("any_peer", "call_local", "reliable")
func req_keypad(lock_id: String, code: String) -> void:
	if not GameState.is_host():
		return
	var peer := Net.sender()
	var it := _near(peer, lock_id)
	if it == null or GameState.flag(lock_id + "_unlocked"):
		return
	if code == str(GameState.data["code"]):
		GameState.set_flag(lock_id + "_unlocked", true)
		GameState.sound("clunk", it.global_position)
		GameState.notify(peer, "The lock releases.", [], "good")
	else:
		GameState.sound("error", it.global_position, -6.0)
		GameState.notify(peer, "Wrong code.", [], "warn")


func _use_radio(peer: int) -> void:
	var world = GameState.scene
	GameState.sound("static_loop", world.player_pos(peer), -8.0, 14.0)
	if GameState.loc_id() == "village" and not GameState.data["traveling"]:
		var c := str(GameState.data["code"])
		GameState.say("Radio", "...Voss to anyone on the line... the numbers are the lock... %s... %s... %s... %s... I repeat...", [c[0], c[1], c[2], c[3]])
		GameState.set_flag("vl_code", true)
	else:
		GameState.say("Radio", Quests.radio_lines[randi() % Quests.radio_lines.size()])


## Sets the course for the next stop on the route map; the lever will not release without it.
@rpc("any_peer", "call_local", "reliable")
func req_set_course() -> void:
	if not GameState.is_host() or GameState.data.is_empty() or GameState.data["traveling"]:
		return
	var peer := Net.sender()
	if not GameState.pdata.has(peer):
		return
	var loc := int(GameState.data["loc"])
	if GameState.flag("course_%d" % loc):
		return
	GameState.set_flag("course_%d" % loc, true)
	var next := "Hollowgate" if loc >= Quests.LOCS.size() - 1 else str(Quests.stops[loc + 1])
	GameState.notify_all("%s set the course: %s", [GameState.player_name(peer), "@" + next], "good")
