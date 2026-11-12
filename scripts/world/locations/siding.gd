extends Location
## Chapter I - Blackmoor Siding. A small yard where the Vesper is found under steam.


func build() -> void:
	env = {
		"sky": Color(0.015, 0.02, 0.035), "fog_color": Color(0.07, 0.08, 0.11), "fog_density": 0.04,
		"ambient": Color(0.35, 0.4, 0.55), "ambient_energy": 0.45, "moon": 0.14,
		"ambient_sound": "wind_loop", "ambient_db": -14.0,
	}
	ground(80, 50)
	rails(-80, 80)
	rails(-80, 10, -6.0)
	var wood := Mat.tex("planks", Color(0.5, 0.45, 0.42))
	var roof := Mat.tex("roof", Color(0.45, 0.42, 0.45))

	# Buffer stop behind the train.
	Build.box(self, Vector3(-38, 0.7, 0), Vector3(0.5, 1.4, 2.6), Mat.tex("wood", Color(0.5, 0.2, 0.18)))
	Build.box(self, Vector3(-38.4, 0.4, 0), Vector3(0.4, 0.8, 3.0), Mat.tex("concrete", Color(0.5, 0.5, 0.5)))

	# Dispatcher's hut with a lit window, across from the passenger car.
	building(Vector3(8, 0, 9), Vector3(5, 2.6, 4), wood, roof, {"n": [[1.8, 2.8, 0, 2.05], [3.4, 4.4, 1.0, 1.8]]}, Mat.tex("planks", Color(0.4, 0.36, 0.33)), true)
	door("sd_hut_door", Vector3(9.8, 0, 9.1))
	Build.light(self, Vector3(10.5, 2.1, 11), Color(1.0, 0.7, 0.4), 0.9, 6.0)
	Build.box(self, Vector3(12, 0.45, 12.2), Vector3(1.4, 0.9, 0.7), wood)
	container("sd_hut_desk", Vector3(9.2, 0, 12.3), 180, [["bandage", 1], ["battery", 1]], "desk")
	Build.label(self, Vector3(10.5, 2.3, 8.93), "BLACKMOOR SIDING", 56, Color(0.8, 0.78, 0.65), Vector3(0, 180, 0))

	# Yard clutter and lamps.
	Build.lamp_post(self, Vector3(14, 0, 6))
	Build.lamp_post(self, Vector3(-12, 0, 6))
	Build.lamp_post(self, Vector3(-30, 0, -9), Color(0.7, 0.8, 1.0), 0.8)
	container("sd_crate", Vector3(-26, 0, 7), 20, [["scrap", 2], ["cloth", 1]])
	for i in 4:
		Build.box(self, Vector3(-16 + i * 1.1, 0.35, 8.5 + (i % 2) * 0.4), Vector3(0.9, 0.7, 0.9), wood)
	Build.box(self, Vector3(-14.9, 1.05, 8.6), Vector3(0.9, 0.7, 0.9), wood)

	# An abandoned wagon on the second track.
	Build.box(self, Vector3(-20, 1.6, -6), Vector3(9, 2.4, 2.7), Mat.tex("rust", Color(0.5, 0.45, 0.45)))
	Build.box(self, Vector3(-20, 0.4, -6), Vector3(8, 0.4, 2.0), Mat.tex("metal", Color(0.25, 0.25, 0.28)), false)

	fence(Vector3(-40, 0, 16), Vector3(30, 0, 16))
	fence(Vector3(-40, 0, -14), Vector3(30, 0, -14))
	var rng := RandomNumberGenerator.new()
	rng.seed = 13
	for i in 46:
		var side := 1.0 if i % 2 == 0 else -1.0
		var z := side * rng.randf_range(19, 46)
		Build.tree(self, Vector3(rng.randf_range(-75, 75), 0, z), rng.randf_range(6, 10), i % 5 == 0)
	apparition_points = [Vector3(22, 0, 14), Vector3(-34, 0, 12), Vector3(0, 0, -12)]
	bonus_points = [Vector3(-8, 0.1, 11), Vector3(16, 0.1, -8)]
