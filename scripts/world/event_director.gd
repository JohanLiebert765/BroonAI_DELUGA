class_name EventDirector
extends Node
## Host-side director: chapter intros and random events. Events add tension and variety
## but never block progress.

var _timer := 60.0
var _intro_serial := 0
var _visited := {}


func _physics_process(delta: float) -> void:
	if not GameState.is_host() or GameState.data.is_empty() or GameState.scene == null:
		return
	_timer -= delta
	if _timer <= 0.0:
		_timer = randf_range(55.0, 110.0)
		_fire(_pick())


func on_location_loaded(traveling: bool) -> void:
	_timer = randf_range(40.0, 70.0)
	var w: World = GameState.scene
	if traveling:
		GameState.set_flag("poi", false)
		if GameState.data["train"]["electric"] < 40.0 or randf() < 0.35:
			w.spawn_enemy("passenger", Vector3(0, -60, 0), {"mode": "train", "delay": randf_range(8.0, 20.0)})
		return
	var loc := int(GameState.data["loc"])
	if _visited.has(loc):
		return
	_visited[loc] = true
	_intro(loc)


func _intro(loc: int) -> void:
	_intro_serial += 1
	var serial := _intro_serial
	var chapter: Dictionary = Quests.chapter(loc)
	GameState.fx_all("chapter", {"loc": loc})
	await get_tree().create_timer(1.0).timeout
	if serial != _intro_serial or GameState.data.is_empty():
		return
	if loc > 0 or GameState.flag_count("left_0") == 0:
		var err := SaveSystem.save("auto")
		if err == "":
			GameState.notify_all("Progress saved.")
	var speakers := GameState.pdata.keys()
	var i := 0
	for line in chapter.get("intro", []):
		await get_tree().create_timer(4.0).timeout
		if serial != _intro_serial or GameState.data.is_empty() or speakers.is_empty():
			return
		var who: int = speakers[i % speakers.size()]
		if GameState.pdata.has(who):
			GameState.say(GameState.char_of(who)["name"], line)
		i += 1


func _pick() -> String:
	var traveling: bool = GameState.data["traveling"]
	var pool := ["lights_out", "radio", "silhouette", "car_noise"]
	if traveling:
		pool += ["damage", "damage", "car_noise"]
	else:
		pool += ["footsteps", "footsteps", "poi", "resource"]
	return pool[randi() % pool.size()]


func _fire(event: String) -> void:
	var w: World = GameState.scene
	var t: Dictionary = GameState.data["train"]
	match event:
		"lights_out":
			t["electric"] = maxf(0.0, t["electric"] - 16.0)
			GameState.fx_all("lights_flicker")
			GameState.notify_all("The carriage lights gutter. Something is draining the electrics.", [], "warn")
		"radio":
			GameState.sound("static_loop", Vector3(20, 2, 0), -6.0, 30.0)
			GameState.say("Radio", Quests.radio_lines[randi() % Quests.radio_lines.size()])
		"silhouette":
			var found := false
			for e in w.enemies.get_children():
				if e.has_method("force_appear"):
					e.force_appear()
					found = true
			if not found:
				var mode := "train" if GameState.data["traveling"] else ""
				w.spawn_enemy("passenger", Vector3(0, -60, 0), {"mode": mode, "delay": 1.0})
		"damage":
			var key: String = "engine" if randf() < 0.5 else "systems"
			t[key] = maxf(0.0, t[key] - (10.0 if key == "engine" else 14.0))
			GameState.sound("bang", Vector3(randf_range(-30, 20), 0.5, 0), 0.0, 40.0)
			GameState.notify_all("Something strikes the undercarriage. Check the engine and the running gear.", [], "warn")
		"car_noise":
			var cars := Train.CARS.keys()
			var car: String = cars[randi() % cars.size()]
			GameState.sound("bang", w.train.car_center(car) + Vector3(0, 2.6, 0), -2.0, 30.0)
			GameState.sound("creak2", w.train.car_center(car) + Vector3(0, 1.0, 0), -4.0, 30.0)
		"footsteps":
			var out := w.player_nodes().filter(func(p): return not w.is_on_train(w.player_pos(p.peer_id)))
			if out.is_empty():
				return
			var p: Player = out[randi() % out.size()]
			var back := -w.player_forward(p.peer_id)
			var base := w.player_pos(p.peer_id) + back * 8.0 + Vector3(randf_range(-3, 3), 0, randf_range(-3, 3))
			for i in 4:
				GameState.sound("creature_step%d" % (i % 2 + 1), base + back * (-1.2 * i), -6.0, 26.0)
				await get_tree().create_timer(0.55).timeout
				if GameState.data.is_empty():
					return
		"poi", "resource":
			var points: Array = w.location.bonus_points if w.location else []
			if points.is_empty():
				return
			var pt: Vector3 = points[randi() % points.size()]
			var loot: Array = [["scrap", 2], ["battery", 1], ["bandage", 1], ["wires", 2], ["bolts", 2], ["fuel", 1], ["med_supplies", 1], ["components", 1], ["electronics", 2]]
			var pick: Array = loot[randi() % loot.size()]
			w.spawn_drop(pick[0], pick[1], pt)
			if event == "poi":
				w.spawn_drop("cloth", 1, pt + Vector3(0.5, 0, 0.3))
				GameState.set_flag("poi", [pt.x, pt.z])
				GameState.notify_all("Something glints out in the dark. A new mark appears on your compass.", [], "good")
			else:
				GameState.notify_all("You have the feeling you missed something in the buildings.")
