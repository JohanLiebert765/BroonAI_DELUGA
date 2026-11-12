extends Location
## Chapter V - The Last Tunnel. Power the portal, rebuild the gate winch, raise the gate
## and choose the junction: Hollowgate platform or the service bypass.

const GATE_X := 44.0
var _gate: Node3D
var _gate_shown := false
var _portal_lights: Array = []
var _junction_label: Label3D
var _junction_lamp: MeshInstance3D
var _gen_sound: AudioStreamPlayer3D


func build() -> void:
	env = {
		"sky": Color(0.008, 0.008, 0.012), "fog_color": Color(0.04, 0.04, 0.05), "fog_density": 0.06,
		"ambient": Color(0.35, 0.38, 0.5), "ambient_energy": 0.48, "moon": 0.08,
		"ambient_sound": "tunnel_loop", "ambient_db": -10.0,
	}
	ground(100, 55, "gravel", Color(0.4, 0.4, 0.42))
	rails(-100, 96)
	var rock := Mat.tex("stone", Color(0.32, 0.32, 0.34), 0.2)
	var conc := Mat.tex("concrete", Color(0.45, 0.45, 0.45))
	var wood := Mat.tex("planks", Color(0.42, 0.38, 0.36))
	var roof := Mat.tex("roof", Color(0.36, 0.36, 0.4))
	var metal := Mat.tex("metal", Color(0.4, 0.42, 0.45))
	var rust := Mat.tex("rust", Color(0.5, 0.46, 0.44))

	# The hill and the tunnel bore (7 m wide, 6 m high) running east from the portal.
	Build.box(self, Vector3(72, 9, 29.25), Vector3(56, 18, 51.5), rock)
	Build.box(self, Vector3(72, 9, -29.25), Vector3(56, 18, 51.5), rock)
	Build.box(self, Vector3(72, 12, 0), Vector3(56, 12, 7), rock)
	Build.box(self, Vector3(96, 3, 0), Vector3(1, 6, 7), Mat.flat(Color(0, 0, 0)))
	Build.box(self, Vector3(43.6, 3, 3.9), Vector3(1.0, 6.4, 0.8), conc)
	Build.box(self, Vector3(43.6, 3, -3.9), Vector3(1.0, 6.4, 0.8), conc)
	Build.box(self, Vector3(43.6, 6.5, 0), Vector3(1.0, 0.8, 8.6), conc)
	Build.label(self, Vector3(43.05, 6.5, 0), "HOLLOWGATE", 80, Color(0.7, 0.68, 0.6), Vector3(0, -90, 0))

	# Welded gate across the line.
	_gate = Node3D.new()
	_gate.position = Vector3(GATE_X, 0, 0)
	add_child(_gate)
	Build.box(_gate, Vector3(0, 3, 0), Vector3(0.2, 6, 7), Mat.flat(Color(0, 0, 0, 0)), true).visible = false
	for i in 12:
		Build.box(_gate, Vector3(0, 3, -3.2 + i * 0.58), Vector3(0.1, 6, 0.1), rust, false)
	for y in [0.4, 2.2, 4.0, 5.7]:
		Build.box(_gate, Vector3(0, y, 0), Vector3(0.14, 0.18, 7), rust, false)
	Build.box(_gate, Vector3(-0.1, 2.9, 0), Vector3(0.05, 1.0, 2.6), Mat.tex("metal", Color(0.6, 0.55, 0.2)), false)
	Build.label(_gate, Vector3(-0.14, 2.9, 0), "NO THROUGH LINE\nN.V.R. WORKS DEPT", 30, Color(0.1, 0.1, 0.1), Vector3(0, -90, 0))

	# Works office: the order that sealed the tunnel.
	var off := Vector3(-14, 0, 9)
	building(off, Vector3(6.5, 2.8, 5), wood, roof, {"n": [[1.0, 2.0, 0, 2.05], [3.4, 5.4, 1.0, 2.0]]}, Mat.tex("planks", Color(0.36, 0.33, 0.3)))
	ndoor("tn_office_door", off, 1.0)
	Build.label(self, Vector3(-10.8, 2.45, 8.9), "WORKS DEPT", 40, Color(0.8, 0.78, 0.65), Vector3(0, 180, 0))
	Build.light(self, Vector3(-10.8, 2.3, 11.5), Color(1.0, 0.7, 0.4), 0.35, 6.0)
	Build.box(self, Vector3(-9.6, 0.4, 13.2), Vector3(1.6, 0.8, 0.7), wood)
	document("tn_doc_gate", "d_gate", Vector3(-9.6, 0.81, 13.2), 12)
	container("tn_office_locker", Vector3(-13.4, 0, 12.8), 90, [["fuse", 1], ["crowbar", 1]], "locker")
	container("tn_office_desk", Vector3(-12.2, 0, 10.2), 180, [["battery", 1], ["bandage", 1]], "desk")
	pickup("tn_fuel_a", "fuel", Vector3(-8.2, 0.05, 10.2))

	# Generator shed.
	var gen := Vector3(12, 0, 9)
	building(gen, Vector3(5.5, 2.8, 4.5), conc, roof, {"n": [[0.8, 1.8, 0, 2.05]]}, Mat.tex("concrete", Color(0.35, 0.35, 0.35)))
	ndoor("tn_gen_door", gen, 0.8, {"material": Mat.tex("metal", Color(0.4, 0.4, 0.42))})
	Build.label(self, Vector3(15.6, 2.45, 8.9), "GENERATOR", 40, Color(0.8, 0.78, 0.65), Vector3(0, 180, 0))
	Build.box(self, Vector3(15.6, 0.6, 12.2), Vector3(2.2, 1.2, 1.0), rust)
	Build.cyl(self, Vector3(16.4, 1.9, 12.2), 0.1, 1.5, metal)
	_gen_sound = Audio.loop_on(self, "generator_loop", -4.0, 30.0, "SFX", false)
	_gen_sound.position = Vector3(15.6, 0.8, 12.2)
	var gen_lamp := Build.box(self, Vector3(14.7, 1.26, 11.8), Vector3(0.12, 0.12, 0.12), Mat.flat(Color(0.2, 0.05, 0.05)), false)
	mechanism("tn_power", "Start the portal generator", Vector3(15.6, 0.7, 12.0), Vector3(2.4, 1.4, 1.4), {
		"needs": {"fuse": 1, "fuel": 1}, "done_msg": "The portal generator roars. Lamps wake along the tunnel mouth.",
		"sound_name": "repair", "noise_radius": 35.0,
		"on_changed": func(on: bool) -> void:
			gen_lamp.material_override = Mat.glow(Color(0.2, 1.0, 0.3), 2.0) if on else Mat.flat(Color(0.2, 0.05, 0.05))
			for l in _portal_lights:
				l.visible = on
			if on and not _gen_sound.playing:
				_gen_sound.play()
			elif not on:
				_gen_sound.stop()})
	container("tn_gen_crate", Vector3(13.0, 0, 12.6), 0, [["wires", 2], ["scrap", 2]])

	# Winch at the portal: needs the valve wheel and the gear the works men removed.
	Build.box(self, Vector3(41.5, 0.6, 5.2), Vector3(1.2, 1.2, 1.0), metal)
	var wheel := Build.cyl(self, Vector3(41.5, 1.0, 4.62), 0.32, 0.06, Mat.flat(Color(0.7, 0.1, 0.1)), false, Vector3(90, 0, 0), 10)
	var gear := Build.cyl(self, Vector3(40.8, 0.7, 5.2), 0.28, 0.1, Mat.tex("metal", Color(0.6, 0.6, 0.62)), false, Vector3(0, 0, 90), 10)
	mechanism("tn_gate", "Fit the winch and raise the gate", Vector3(41.5, 0.8, 5.0), Vector3(1.6, 1.6, 1.4), {
		"needs": {"valve_wheel": 1, "gate_gear": 1}, "need_flags": ["tn_power"],
		"need_msg": "The winch motor is dead. Restore power to the tunnel first.",
		"done_msg": "The gate tears free of its welds and rises. The tunnel is open.", "sound_name": "bang", "noise_radius": 50.0,
		"on_changed": func(on: bool) -> void:
			wheel.visible = on
			gear.visible = on
			_show_gate(on)})

	# Stores on the far side of the line: valve wheel.
	var store := Vector3(18, 0, -14)
	building(store, Vector3(5, 2.6, 4.5), wood, roof, {"s": [[2.0, 3.0, 0, 2.05]]}, Mat.tex("planks", Color(0.36, 0.33, 0.3)))
	door("tn_store_door", Vector3(20, 0, -9.6))
	Build.label(self, Vector3(20.5, 2.3, -9.4), "STORES", 40, Color(0.8, 0.78, 0.65))
	Build.box(self, Vector3(20.5, 0.4, -13.2), Vector3(3.0, 0.8, 0.7), wood)
	pickup("tn_wheel", "valve_wheel", Vector3(20.0, 0.85, -13.2), 1, "", "tn_parts")
	container("tn_store_crate", Vector3(22.2, 0, -11.2), 15, [["bolts", 2], ["fuel", 1]])
	Build.lamp_post(self, Vector3(16.5, 0, -8), Color(0.8, 0.9, 1.0), 0.4, 3.0)

	# A tipped works wagon far down the yard: the gear.
	Build.box(self, Vector3(-52, 1.1, -9), Vector3(7, 2.0, 2.6), rust, true, Vector3(24, 8, 0))
	container("tn_wagon_crate", Vector3(-50, 0, -5.4), 20, [["gate_gear", 1], ["scrap", 2]], "crate", {"count_flag": "tn_parts"})
	container("tn_wagon_barrel", Vector3(-55, 0, -5.8), 0, [["med_supplies", 2]], "barrel")
	Build.lamp_post(self, Vector3(-47, 0, -6.5), Color(1.0, 0.6, 0.3), 0.35, 2.8)

	# Watchman's hut, nailed shut: the manifest of train 13.
	var hut := Vector3(27, 0, 9)
	building(hut, Vector3(4.5, 2.5, 4), wood, roof, {"n": [[1.6, 2.6, 0, 2.05]]}, Mat.tex("planks", Color(0.36, 0.33, 0.3)), true)
	ndoor("tn_hut_door", hut, 1.6, {"tool_item": "crowbar", "locked_msg": "Nailed shut with sleeper spikes. A crowbar would open it."})
	Build.light(self, Vector3(29.2, 2.0, 11), Color(0.6, 0.75, 1.0), 0.3, 5.0)
	Build.box(self, Vector3(30.4, 0.4, 12.3), Vector3(1.4, 0.8, 0.7), wood)
	document("tn_doc_truth", "d_truth", Vector3(30.4, 0.81, 12.3), 6)
	Build.box(self, Vector3(28.0, 0.5, 12.4), Vector3(0.5, 1.0, 0.3), Mat.flat(Color(0.08, 0.08, 0.12)), false)
	Build.box(self, Vector3(28.0, 1.08, 12.4), Vector3(0.34, 0.14, 0.3), Mat.flat(Color(0.08, 0.08, 0.12)), false)

	# Portal lamps, dark until the generator runs.
	for z in [-3.2, 3.2]:
		_portal_lights.append(Build.light(self, Vector3(42.6, 5.2, z), Color(1.0, 0.8, 0.5), 1.0, 14.0))
	for i in 4:
		_portal_lights.append(Build.light(self, Vector3(50.0 + i * 12.0, 5.4, 0), Color(1.0, 0.75, 0.45), 0.6, 12.0))
	for l in _portal_lights:
		l.visible = false

	# Junction lever inside the bore, beyond the gate.
	Build.box(self, Vector3(54, 0.2, 2.6), Vector3(0.7, 0.4, 0.5), metal)
	var lever := Build.box(self, Vector3(54, 0.95, 2.6), Vector3(0.07, 1.3, 0.07), Mat.flat(Color(0.75, 0.7, 0.2)), false, Vector3(0, 0, 28))
	_junction_lamp = Build.box(self, Vector3(54, 2.3, 3.4), Vector3(0.3, 0.3, 0.08), Mat.glow(Color(1.0, 0.6, 0.1), 2.0), false)
	_junction_label = Build.label(self, Vector3(54, 1.9, 3.42), "", 40, Color(0.85, 0.82, 0.7), Vector3(0, 180, 0))
	Build.box(self, Vector3(64, 0.12, 2.2), Vector3(10, 0.12, 0.08), rust, false, Vector3(0, -10, 0))
	Build.box(self, Vector3(74, 2.6, 3.45), Vector3(5, 5.2, 0.1), Mat.flat(Color(0, 0, 0)), false)
	Build.label(self, Vector3(74, 4.0, 3.38), "SERVICE BYPASS", 44, Color(0.6, 0.58, 0.5), Vector3(0, 180, 0))
	mechanism("tn_junction", "Throw the junction lever", Vector3(54, 0.8, 2.6), Vector3(1.0, 1.6, 1.0), {
		"once": false, "sound_name": "lever", "noise_radius": 20.0,
		"custom": func(peer: int) -> void:
			var to_platform := not GameState.flag("tn_junction")
			GameState.set_flag("tn_junction", to_platform)
			GameState.sound("lever", Vector3(54, 1, 2.6), 0.0, 30.0)
			GameState.scene.player_action(peer, "interact")
			GameState.notify_all("Junction set for: %s", ["@HOLLOWGATE PLATFORM" if to_platform else "@SERVICE BYPASS"], "good"),
		"on_changed": func(on: bool) -> void:
			lever.rotation_degrees.z = -28.0 if on else 28.0
			_junction_label.text = "JUNCTION: HOLLOWGATE" if on else "JUNCTION: BYPASS"
			_junction_lamp.material_override = Mat.glow(Color(0.2, 1.0, 0.3), 2.0) if on else Mat.glow(Color(1.0, 0.6, 0.1), 2.0)})

	# Yard dressing.
	for i in 5:
		Build.box(self, Vector3(-30 + i * 2.3, 0.12, -8 + (i % 2) * 0.3), Vector3(2.2, 0.24, 0.26), wood, false, Vector3(0, 4 * i, 0))
	Build.box(self, Vector3(2, 0.5, 9.5), Vector3(1.6, 1.0, 1.0), rock)
	Build.box(self, Vector3(36, 0.7, -7.5), Vector3(2.4, 1.4, 1.8), rock, true, Vector3(0, 30, 0))
	container("tn_yard_crate", Vector3(4, 0, -7), 40, [["scrap", 2], ["cloth", 1]])
	fence(Vector3(-60, 0, 18), Vector3(40, 0, 18))
	fence(Vector3(-60, 0, -20), Vector3(40, 0, -20))
	scatter_trees(45, 40, 50, [[Vector3(-10, 0, 0), 26.0]], 2, 61)

	enemy_spawns = [
		{"type": "hollow", "pos": Vector3(-40, 0, 14),
			"points": [Vector3(-40, 0, 14), Vector3(-20, 0, -14), Vector3(8, 0, 15), Vector3(34, 0, -12), Vector3(-58, 0, -12), Vector3(36, 0, 15), Vector3(-30, 0, 30)]},
		{"type": "signal", "pos": Vector3(38, 0, -5), "delay": 40.0,
			"points": [Vector3(38, 0, -5), Vector3(48, 0, 0), Vector3(-6, 0, 7), Vector3(24, 0, -8), Vector3(-44, 0, -4)]},
	]
	apparition_points = [Vector3(40, 0, 2), Vector3(60, 0, -1.5), Vector3(-20, 0, 8), Vector3(10, 0, -10)]
	bonus_points = [Vector3(6, 0.1, 7), Vector3(-24, 0.1, -6)]


func _show_gate(open: bool) -> void:
	if open == _gate_shown:
		return
	_gate_shown = open
	for body in _gate.find_children("*", "CollisionShape3D", true, false):
		body.set_deferred("disabled", open)
	var tw := create_tween()
	tw.tween_property(_gate, "position:y", 6.6 if open else 0.0, 4.0)
