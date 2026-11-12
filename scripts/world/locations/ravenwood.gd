extends Location
## Chapter II - Ravenwood Station. The signal ahead is dead; power it from the signal box.

var _signal_red: MeshInstance3D
var _signal_green: MeshInstance3D
var _signal_light: OmniLight3D
var _gen_sound: AudioStreamPlayer3D


func build() -> void:
	env = {
		"sky": Color(0.02, 0.02, 0.03), "fog_color": Color(0.09, 0.09, 0.1), "fog_density": 0.045,
		"ambient": Color(0.4, 0.4, 0.5), "ambient_energy": 0.55, "moon": 0.12,
		"ambient_sound": "rain_loop", "ambient_db": -16.0,
	}
	ground(90, 60)
	rails(-90, 90)
	var brick := Mat.tex("brick", Color(0.55, 0.45, 0.42))
	var plaster := Mat.tex("plaster", Color(0.6, 0.58, 0.52))
	var roof := Mat.tex("roof", Color(0.4, 0.38, 0.42))
	var wood := Mat.tex("planks", Color(0.5, 0.45, 0.42))
	var metal := Mat.tex("metal", Color(0.4, 0.42, 0.45))
	var floor_mat := Mat.tex("tiles", Color(0.45, 0.45, 0.42))

	# Platform and canopy.
	Build.box(self, Vector3(-2, 0.03, 7.4), Vector3(74, 0.06, 6.4), Mat.tex("concrete", Color(0.5, 0.5, 0.5)), false)
	for i in 5:
		var x := -24.0 + i * 12.0
		Build.cyl(self, Vector3(x, 1.6, 9.6), 0.09, 3.2, metal, true)
		Build.box(self, Vector3(x, 0.45, 9.0), Vector3(1.8, 0.08, 0.5), wood)
	Build.box(self, Vector3(0, 3.3, 8.6), Vector3(54, 0.12, 3.4), roof, false)
	Build.lamp_post(self, Vector3(-18, 0, 5.2), Color(1.0, 0.8, 0.5), 0.9)
	Build.lamp_post(self, Vector3(16, 0, 5.2), Color(1.0, 0.8, 0.5), 0.6)
	Build.label(self, Vector3(0, 2.9, 10.9), "RAVENWOOD", 96, Color(0.85, 0.82, 0.7), Vector3(0, 180, 0))

	# Station building: waiting hall, station master's office, records room.
	var st := Vector3(-9, 0, 11)
	building(st, Vector3(18, 3.4, 9), brick, roof, {"n": [[8.5, 9.5, 0, 2.05], [2, 4, 1, 2.2], [14, 16, 1, 2.2]]}, floor_mat, true)
	ndoor("rw_hall_door", st, 8.5)
	Build.wall(self, Vector3(3, 0, 11.2), "z", 8.6, 3.4, 0.15, plaster, [[2.8, 3.8, 0, 2.05]])
	door("rw_office_door", Vector3(3, 0, 14.0), -90)
	Build.wall(self, Vector3(3.1, 0, 16.5), "x", 5.7, 3.4, 0.15, plaster, [[2.0, 3.0, 0, 2.05]])
	door("rw_records_door", Vector3(5.1, 0, 16.5), 0, {"key_item": "key_records", "locked_msg": "RECORDS. Locked - the key is not here."})
	Build.label(self, Vector3(5.6, 2.3, 16.4), "RECORDS", 40, Color(0.8, 0.78, 0.65), Vector3(0, 180, 0))
	Build.light(self, Vector3(-3, 2.9, 15.5), Color(1.0, 0.75, 0.5), 0.5, 9.0)
	Build.light(self, Vector3(6, 2.8, 13.8), Color(0.7, 1.0, 0.7), 0.35, 5.0)
	# Hall: benches, stopped clock, ticket counter.
	for i in 3:
		Build.box(self, Vector3(-6.5 + i * 2.6, 0.45, 18.6), Vector3(2.0, 0.1, 0.5), wood)
		Build.box(self, Vector3(-6.5 + i * 2.6, 0.9, 18.85), Vector3(2.0, 0.8, 0.08), wood, false)
	Build.cyl(self, Vector3(-3, 2.6, 19.7), 0.45, 0.08, Mat.flat(Color(0.85, 0.82, 0.7)), false, Vector3(90, 0, 0), 12)
	Build.label(self, Vector3(-3, 2.6, 19.62), "22:07", 40, Color(0.1, 0.1, 0.1), Vector3(0, 180, 0))
	Build.box(self, Vector3(1.2, 0.55, 15.5), Vector3(1.2, 1.1, 3.0), wood)
	document("rw_doc_telegram", "d_telegram", Vector3(1.2, 1.11, 15.2), 20)
	container("rw_hall_cabinet", Vector3(-8.2, 0, 15), 90, [["cloth", 2], ["bandage", 1]], "cabinet")
	# Office.
	container("rw_office_desk", Vector3(7.2, 0, 12.6), 180, [["key_warehouse", 1], ["battery", 1]], "desk", {"quest_flag": "rw_key"})
	container("rw_office_locker", Vector3(8.5, 0, 15.6), -90, [["med_supplies", 2]], "locker")
	# Records room.
	container("rw_records_cabinet", Vector3(8.3, 0, 18.5), -90, [["components", 1], ["electronics", 1]], "cabinet")
	Build.box(self, Vector3(4.2, 0.4, 19.2), Vector3(1.4, 0.8, 0.7), wood)
	document("rw_doc_logbook", "d_logbook", Vector3(4.2, 0.81, 19.2), -12)

	# Warehouse (locked) with the reserve fuel.
	var wh := Vector3(-36, 0, 11)
	building(wh, Vector3(11, 3.6, 8), wood, roof, {"n": [[5.0, 6.0, 0, 2.05]]}, Mat.tex("concrete", Color(0.4, 0.4, 0.4)))
	ndoor("rw_warehouse_door", wh, 5.0, {"key_item": "key_warehouse", "locked_msg": "The warehouse is padlocked. The station master kept the key."})
	Build.label(self, Vector3(-30.5, 2.6, 10.9), "GOODS", 56, Color(0.8, 0.78, 0.65), Vector3(0, 180, 0))
	Build.light(self, Vector3(-30.5, 3.0, 15), Color(0.8, 0.85, 1.0), 0.3, 8.0)
	pickup("rw_fuel_a", "fuel", Vector3(-34.5, 0.05, 17.5), 1, "rw_fuel")
	pickup("rw_fuel_b", "fuel", Vector3(-33.6, 0.05, 17.8), 1, "rw_fuel")
	pickup("rw_fuse_a", "fuse", Vector3(-27.2, 0.95, 17.6))
	Build.box(self, Vector3(-27.2, 0.45, 17.8), Vector3(2.2, 0.9, 0.8), wood)
	container("rw_wh_crate_a", Vector3(-26.4, 0, 13.2), 10, [["scrap", 3], ["bolts", 2]])
	container("rw_wh_crate_b", Vector3(-34.4, 0, 13.0), -15, [["wires", 2], ["scrap", 1]])
	container("rw_wh_barrel", Vector3(-30.4, 0, 18.2), 0, [["cloth", 1], ["bolts", 1]], "barrel")
	pickup("rw_wrench", "wrench", Vector3(-27.9, 0.95, 17.9))

	# Signal box: generator, fuse panel, signal lever.
	var sb := Vector3(26, 0, 8)
	building(sb, Vector3(6, 2.8, 4.5), brick, roof, {"n": [[0.6, 1.6, 0, 2.05], [3.0, 5.0, 1.0, 2.0]]}, Mat.tex("planks", Color(0.4, 0.36, 0.33)))
	ndoor("rw_box_door", sb, 0.6)
	Build.label(self, Vector3(29.5, 2.45, 7.9), "SIGNAL BOX", 40, Color(0.8, 0.78, 0.65), Vector3(0, 180, 0))
	Build.box(self, Vector3(30.6, 0.5, 11.4), Vector3(1.6, 1.0, 0.9), Mat.tex("rust", Color(0.5, 0.5, 0.5)))
	_gen_sound = Audio.loop_on(self, "generator_loop", -6.0, 22.0, "SFX", false)
	_gen_sound.position = Vector3(30.6, 0.6, 11.4)
	var gen_lamp := Build.box(self, Vector3(30.6, 1.06, 11.0), Vector3(0.1, 0.1, 0.1), Mat.flat(Color(0.2, 0.05, 0.05)), false)
	mechanism("rw_generator", "Fuel the generator", Vector3(30.6, 0.6, 11.3), Vector3(1.8, 1.2, 1.2), {
		"needs": {"fuel": 1}, "done_msg": "The generator coughs and catches.", "sound_name": "repair", "noise_radius": 18.0,
		"on_changed": func(on: bool) -> void:
			gen_lamp.material_override = Mat.glow(Color(0.2, 1.0, 0.3), 2.0) if on else Mat.flat(Color(0.2, 0.05, 0.05))
			if on and not _gen_sound.playing:
				_gen_sound.play()
			elif not on:
				_gen_sound.stop()})
	Build.box(self, Vector3(27.6, 1.5, 12.25), Vector3(0.7, 0.9, 0.15), metal, false)
	mechanism("rw_fusebox", "Fit a fuse", Vector3(27.6, 1.5, 12.1), Vector3(0.8, 1.0, 0.4), {
		"needs": {"fuse": 1}, "done_msg": "The fuse seats with a snap.", "sound_name": "switch"})
	var lever := Build.box(self, Vector3(29.0, 0.7, 9.0), Vector3(0.08, 1.2, 0.08), Mat.flat(Color(0.7, 0.1, 0.1)), false, Vector3(0, 0, 25))
	Build.box(self, Vector3(29.0, 0.15, 9.0), Vector3(0.5, 0.3, 0.3), metal)
	mechanism("rw_power", "Pull the signal lever", Vector3(29.0, 0.8, 9.0), Vector3(0.7, 1.4, 0.6), {
		"need_flags": ["rw_generator", "rw_fusebox"], "need_msg": "Dead. The signal circuit needs a running generator and a fuse.",
		"done_msg": "The signal clears to green. The line to the forest is open.", "sound_name": "lever", "noise_radius": 16.0,
		"on_changed": func(on: bool) -> void:
			lever.rotation_degrees.z = -25.0 if on else 25.0
			_set_signal(on)})
	container("rw_box_locker", Vector3(31.4, 0, 8.6), -90, [["key_records", 1], ["pliers", 1]], "locker")

	# The signal itself.
	Build.cyl(self, Vector3(42, 2.6, 3.2), 0.08, 5.2, metal, true)
	Build.box(self, Vector3(42, 4.9, 3.2), Vector3(0.4, 1.0, 0.4), Mat.flat(Color(0.05, 0.05, 0.05)), false)
	_signal_red = Build.box(self, Vector3(41.78, 5.15, 3.2), Vector3(0.06, 0.26, 0.26), Mat.glow(Color(1, 0.08, 0.05), 3.0), false)
	_signal_green = Build.box(self, Vector3(41.78, 4.65, 3.2), Vector3(0.06, 0.26, 0.26), Mat.flat(Color(0.02, 0.1, 0.03)), false)
	_signal_light = Build.light(self, Vector3(41.4, 4.9, 3.2), Color(1, 0.1, 0.05), 0.8, 14.0)
	_set_signal(GameState.flag("rw_power"))

	# Yard dressing.
	fence(Vector3(-45, 0, 22), Vector3(40, 0, 22))
	fence(Vector3(-45, 0, -12), Vector3(50, 0, -12))
	Build.box(self, Vector3(-48, 1.5, -6), Vector3(8, 2.2, 2.6), Mat.tex("rust", Color(0.45, 0.42, 0.42)))
	container("rw_yard_crate", Vector3(14, 0, 12.5), 30, [["scrap", 2], ["fuel", 1]])
	container("rw_far_barrel", Vector3(-44, 0, -9), 0, [["wires", 1], ["electronics", 1]], "barrel")
	scatter_trees(50, 85, 55, [[Vector3(-5, 0, 14), 44.0]], 4, 21)

	enemy_spawns = [{"type": "signal", "pos": Vector3(38, 0, 6), "delay": 35.0,
		"points": [Vector3(38, 0, 6), Vector3(-20, 0, 6.5), Vector3(8, 0, -8), Vector3(-40, 0, 8), Vector3(20, 0, 16)]}]
	apparition_points = [Vector3(-12, 0, 9), Vector3(12, 0, 18), Vector3(-30, 0, 20), Vector3(34, 0, -8)]
	bonus_points = [Vector3(-14, 0.1, 9.2), Vector3(20, 0.1, -6)]


func _set_signal(green: bool) -> void:
	if _signal_red == null:
		return
	_signal_red.material_override = Mat.flat(Color(0.12, 0.02, 0.02)) if green else Mat.glow(Color(1, 0.08, 0.05), 3.0)
	_signal_green.material_override = Mat.glow(Color(0.1, 1.0, 0.3), 3.0) if green else Mat.flat(Color(0.02, 0.1, 0.03))
	_signal_light.light_color = Color(0.1, 1.0, 0.3) if green else Color(1, 0.1, 0.05)
