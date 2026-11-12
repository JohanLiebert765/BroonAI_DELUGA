class_name TrainSystem
extends Node
## Host-side train simulation: fuel, engine, electrics, boiler temperature, running gear,
## travel between stops, and the server logic of every train device.

const LEG := 100.0           # distance units between two stops
const FUEL_TO_LEAVE := 30.0
const ENGINE_TO_LEAVE := 30.0

var _sync_t := 0.0
var _horn_cd := 0.0
var _rest_cd := {}


static func pressure(d: Dictionary) -> float:
	var t: Dictionary = d["train"]
	var base: float = clampf((t["temp"] - 25.0) * 0.9, 0.0, 100.0)
	if d["traveling"] and not d["halted"]:
		base = minf(100.0, base + (18.0 if int(d["throttle"]) >= 2 else 8.0))
	return base


func _t() -> Dictionary:
	return GameState.data["train"]


func _physics_process(delta: float) -> void:
	if not GameState.is_host() or GameState.data.is_empty():
		return
	var d: Dictionary = GameState.data
	var t := _t()
	d["stats"]["time"] = float(d["stats"]["time"]) + delta
	_horn_cd = maxf(0.0, _horn_cd - delta)
	for peer in _rest_cd:
		_rest_cd[peer] = maxf(0.0, _rest_cd[peer] - delta)
	if d["traveling"]:
		_travel_tick(d, t, delta)
	else:
		t["temp"] = move_toward(t["temp"], 30.0, 3.0 * delta)
		if GameState.loc_id() == "village" and t["engine"] >= 60.0:
			GameState.set_flag("vl_engine", true)
	_sync_t += delta
	if _sync_t >= 0.25:
		_sync_t = 0.0
		GameState.sync_train()
		GameState.train_changed.emit()


func _travel_tick(d: Dictionary, t: Dictionary, delta: float) -> void:
	if d["halted"]:
		t["temp"] = move_toward(t["temp"], 30.0, 2.0 * delta)
		return
	var full: bool = int(d["throttle"]) >= 2 and t["systems"] >= 30.0
	if not full:
		d["throttle"] = 1
	d["progress"] = float(d["progress"]) + (3.0 if full else 1.7) * delta
	t["fuel"] = maxf(0.0, t["fuel"] - (0.85 if full else 0.36) * delta)
	var target: float = (112.0 if full else 62.0) + (100.0 - t["engine"]) * 0.25
	t["temp"] = move_toward(t["temp"], target, (2.2 if full else 1.2) * delta)
	t["engine"] = maxf(0.0, t["engine"] - ((0.22 if full else 0.12) + (0.2 if t["temp"] > 90.0 else 0.0)) * delta)
	t["electric"] = maxf(0.0, t["electric"] - 0.05 * delta)
	t["systems"] = maxf(0.0, t["systems"] - 0.06 * delta)
	if t["fuel"] <= 0.0:
		_halt("The firebox is empty. The train rolls to a stop in the dark.")
	elif t["temp"] >= 100.0:
		t["engine"] = maxf(0.0, t["engine"] - 6.0)
		_halt("The boiler is overheating! Vent the steam valve, then pull the lever.")
	elif d["progress"] >= LEG:
		_arrive()


func _halt(msg: String) -> void:
	GameState.data["halted"] = true
	GameState.sound("valve", Vector3(22, 2, 0), 0.0, 40.0)
	GameState.notify_all(msg, [], "warn")
	GameState.sync_train()


func _arrive() -> void:
	var loc := int(GameState.data["loc"])
	if loc >= Quests.LOCS.size() - 1:
		var junction := GameState.flag("tn_junction")
		var truth := GameState.flag("doc_d_truth")
		GameState.finish("terminus" if junction and truth else ("passengers" if junction else "bypass"))
		GameState.data["traveling"] = false
		return
	GameState.set_flag("train_moving", false)
	GameState.sound("valve", Vector3(22, 2, 0), -2.0, 40.0)
	if Quests.LOCS[loc + 1] == "village":
		_t()["engine"] = minf(_t()["engine"], 22.0)
	GameState.set_travel(false, loc + 1)
	GameState.sync_train()


# --- devices (called on the host through Mechanism.custom) --------------------

func use_lever(peer: int) -> void:
	var d: Dictionary = GameState.data
	var t := _t()
	GameState.sound("lever", Vector3(21.5, 1.8, 0.95), -2.0, 16.0)
	GameState.scene.player_action(peer, "interact")
	if not d["traveling"]:
		_try_depart(peer)
		return
	if d["halted"]:
		if t["fuel"] <= 0.0:
			GameState.notify(peer, "No fuel. Feed the firebox first.", [], "warn")
		elif t["temp"] >= 85.0:
			GameState.notify(peer, "The boiler is still too hot. Vent the steam valve.", [], "warn")
		else:
			d["halted"] = false
			GameState.notify_all("The train shudders and moves again.", [], "good")
		return
	if int(d["throttle"]) < 2:
		if t["systems"] < 30.0:
			GameState.notify(peer, "The running gear is too worn for full speed.", [], "warn")
			return
		d["throttle"] = 2
		GameState.notify_all("Throttle: FULL. Watch the temperature.")
	else:
		d["throttle"] = 1
		GameState.notify_all("Throttle: SLOW.")


func _try_depart(peer: int) -> void:
	var t := _t()
	var blocking := Quests.blocking_objective()
	if blocking != "":
		GameState.notify(peer, "The train cannot leave yet: %s", ["@" + blocking], "warn")
		return
	if t["fuel"] < FUEL_TO_LEAVE:
		GameState.notify(peer, "Not enough fuel to reach the next stop (30% needed).", [], "warn")
		return
	if t["engine"] < ENGINE_TO_LEAVE:
		GameState.notify(peer, "The engine is too damaged to move. Service it first.", [], "warn")
		return
	if not GameState.flag("course_%d" % int(GameState.data["loc"])):
		GameState.notify(peer, "No course set. Study the route map in the cab first.", [], "warn")
		return
	var missing := []
	for p in GameState.scene.player_nodes():
		if not GameState.scene.is_on_train(GameState.scene.player_pos(p.peer_id)):
			missing.append(GameState.player_name(p.peer_id))
	if not missing.is_empty():
		GameState.notify_all("Cannot depart - still outside: %s", [", ".join(missing)], "warn")
		return
	var loc := int(GameState.data["loc"])
	GameState.set_flag("left_%d" % loc, true)
	GameState.set_flag("train_moving", true)
	for id in Train.EXT_DOORS:
		GameState.set_flag(id, false)
	GameState.data["throttle"] = 1
	GameState.sound("horn", Vector3(26, 3.5, 0), 0.0, 90.0)
	if loc >= Quests.LOCS.size() - 1:
		GameState.notify_all("The Vesper rolls through the gate, into the last tunnel...", [], "good")
	else:
		GameState.notify_all("The Vesper pulls away. Next stop: %s", ["@" + Quests.stops[loc + 1]], "good")
	GameState.set_travel(true, loc)


func _repair_with(peer: int, key: String, options: Array, label: String) -> bool:
	var t := _t()
	if t[key] >= 99.5:
		GameState.notify(peer, "%s: nothing to repair.", ["@" + label])
		return true
	for opt in options:
		if GameState.take(peer, opt[0], 1):
			var gain: float = opt[1] * float(GameState.char_of(peer)["repair"])
			t[key] = minf(100.0, t[key] + gain)
			GameState.sound("repair", GameState.scene.player_pos(peer), -2.0, 18.0)
			GameState.scene.player_action(peer, "use")
			GameState.scene.noise(GameState.scene.player_pos(peer), 10.0)
			GameState.notify_all("%s repaired: %s is now at %d%%", [GameState.player_name(peer), "@" + label, int(t[key])], "good")
			GameState.sync_train()
			return true
	return false


func use_firebox(peer: int) -> void:
	var t := _t()
	if GameState.take(peer, "fuel", 1):
		t["fuel"] = minf(100.0, t["fuel"] + 26.0)
		GameState.set_flag("s_fueled", true)
		GameState.sound("clunk", Vector3(22, 1.4, 0), -2.0, 16.0)
		GameState.scene.player_action(peer, "use")
		GameState.notify_all("%s feeds the firebox. Fuel: %d%%", [GameState.player_name(peer), int(t["fuel"])], "good")
	elif t["fuel"] < FUEL_TO_LEAVE:
		t["fuel"] += 6.0
		t["engine"] = maxf(0.0, t["engine"] - 2.0)
		GameState.sound("clunk", Vector3(22, 1.4, 0), -6.0, 16.0)
		GameState.notify(peer, "You scrape coal dust out of the bunker. It burns badly. Fuel: %d%%", [int(t["fuel"])], "warn")
	else:
		GameState.notify(peer, "You need: %s", ["@Fuel Can"], "warn")
	GameState.sync_train()


func use_engine(peer: int) -> void:
	var t := _t()
	if _repair_with(peer, "engine", [["engine_part", 40.0], ["repair_kit", 25.0], ["spare_part", 15.0]], "Engine"):
		return
	if t["engine"] < ENGINE_TO_LEAVE:
		t["engine"] = ENGINE_TO_LEAVE
		t["systems"] = maxf(0.0, t["systems"] - 10.0)
		GameState.sound("repair", Vector3(21.7, 1.2, -0.9), -2.0, 18.0)
		GameState.notify(peer, "You tighten what you can by hand. It will hold - barely.", [], "warn")
		GameState.sync_train()
	else:
		GameState.notify(peer, "You need an Engine Part, a Repair Kit or a Spare Part.", [], "warn")


func use_fusebox(peer: int) -> void:
	if not _repair_with(peer, "electric", [["fuse", 40.0], ["battery", 20.0], ["wires", 10.0]], "Electrics"):
		GameState.notify(peer, "You need a Fuse, a Battery or Wires.", [], "warn")


func use_gear(peer: int) -> void:
	if not _repair_with(peer, "systems", [["spare_part", 35.0], ["repair_kit", 25.0], ["bolts", 8.0]], "Running gear"):
		GameState.notify(peer, "You need a Spare Part, a Repair Kit or Bolts.", [], "warn")


func use_valve(peer: int) -> void:
	var t := _t()
	t["temp"] = maxf(30.0, t["temp"] - 30.0)
	GameState.sound("valve", Vector3(22, 1.8, -1), -2.0, 30.0)
	GameState.scene.player_action(peer, "interact")
	GameState.scene.noise(Vector3(22, 1, 0), 20.0)
	GameState.notify_all("%s vents the boiler. Temperature: %d", [GameState.player_name(peer), int(t["temp"])])
	GameState.sync_train()


func use_lights(peer: int) -> void:
	var t := _t()
	t["lights"] = not t["lights"]
	GameState.sound("switch", Vector3(20.6, 2.2, -1.3), 0.0, 10.0)
	if t["lights"] and t["electric"] < 10.0:
		GameState.notify(peer, "Nothing. The electrics are dead - service the fuse box.", [], "warn")
	GameState.sync_train()


func use_horn(_peer: int) -> void:
	if _horn_cd > 0.0:
		return
	_horn_cd = 5.0
	GameState.sound("horn", Vector3(26, 3.5, 0), 2.0, 110.0)
	GameState.scene.noise(Vector3(24, 1, 0), 70.0)
	for e in GameState.scene.enemies.get_children():
		if e.has_method("on_whistle"):
			e.on_whistle()


func use_bed(peer: int) -> void:
	if _rest_cd.get(peer, 0.0) > 0.0:
		GameState.notify(peer, "You cannot rest again so soon.")
		return
	var pd: Dictionary = GameState.pdata[peer]
	if pd["hp"] >= pd["max_hp"] * 0.7:
		GameState.notify(peer, "You are well enough. Rest only helps the badly hurt.")
		return
	_rest_cd[peer] = 45.0
	GameState.heal(peer, 30.0)
	GameState.notify(peer, "You rest for a moment. The carriage creaks around you.", [], "good")
