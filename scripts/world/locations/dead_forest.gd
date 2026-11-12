extends Location
## Chapter III - The Dead Forest. The railway switch was dismantled; its parts are in
## the trackwalker's hut and at the search party's camp.


func build() -> void:
	env = {
		"sky": Color(0.012, 0.018, 0.02), "fog_color": Color(0.06, 0.08, 0.08), "fog_density": 0.07,
		"ambient": Color(0.35, 0.45, 0.45), "ambient_energy": 0.5, "moon": 0.1,
		"ambient_sound": "forest_loop", "ambient_db": -10.0,
	}
	ground(100, 75, "grass", Color(0.35, 0.4, 0.36))
	rails(-100, 100)
	var wood := Mat.tex("planks", Color(0.42, 0.38, 0.35))
	var roof := Mat.tex("roof", Color(0.35, 0.36, 0.36))
	var metal := Mat.tex("metal", Color(0.4, 0.42, 0.45))
	var canvas := Mat.tex("fabric", Color(0.42, 0.44, 0.36))

	# The switch, 8 m ahead of the locomotive, with the branch line rusting away.
	Build.box(self, Vector3(52, 0.12, 3.0), Vector3(24, 0.12, 0.08), Mat.tex("rust", Color(0.5, 0.45, 0.4)), false, Vector3(0, -12, 0))
	Build.box(self, Vector3(52, 0.12, 4.5), Vector3(24, 0.12, 0.08), Mat.tex("rust", Color(0.5, 0.45, 0.4)), false, Vector3(0, -12, 0))
	Build.box(self, Vector3(38, 0.25, 2.6), Vector3(0.8, 0.5, 0.6), metal)
	var lever := Build.box(self, Vector3(38, 1.0, 2.6), Vector3(0.07, 1.3, 0.07), Mat.flat(Color(0.75, 0.7, 0.2)), false, Vector3(0, 0, 30))
	var rod := Build.box(self, Vector3(38, 0.2, 1.6), Vector3(0.06, 0.06, 1.8), metal, false)
	var lamp := Build.box(self, Vector3(38, 0.62, 2.6), Vector3(0.2, 0.2, 0.2), Mat.flat(Color(0.1, 0.02, 0.02)), false)
	mechanism("fr_switch", "Rebuild the switch", Vector3(38, 0.7, 2.6), Vector3(1.2, 1.6, 1.2), {
		"needs": {"switch_lever": 1, "switch_rod": 1}, "tool_item": "wrench",
		"done_msg": "The switch blades slam across. The line to the village is set.", "sound_name": "lever", "noise_radius": 30.0,
		"on_changed": func(on: bool) -> void:
			lever.visible = on
			rod.visible = on
			lamp.material_override = Mat.glow(Color(0.2, 1.0, 0.3), 2.5) if on else Mat.flat(Color(0.1, 0.02, 0.02))})
	Build.label(self, Vector3(38, 1.9, 3.2), "HOLLOWGATE LINE", 36, Color(0.8, 0.78, 0.65), Vector3(0, 180, 0))

	# Trackwalker's hut, barred from the inside.
	var hut := Vector3(28, 0, 9)
	building(hut, Vector3(4.5, 2.5, 4), wood, roof, {"n": [[1.6, 2.6, 0, 2.05]]}, Mat.tex("planks", Color(0.36, 0.33, 0.3)), true)
	ndoor("fr_hut_door", hut, 1.6, {"tool_item": "crowbar", "locked_msg": "Barred from the inside. A crowbar would shift it."})
	Build.light(self, Vector3(30.2, 2.0, 11.2), Color(1.0, 0.6, 0.3), 0.3, 5.0)
	Build.box(self, Vector3(31.6, 0.4, 12.3), Vector3(1.2, 0.8, 0.7), wood)
	document("fr_doc_guard", "d_guard", Vector3(31.6, 0.81, 12.3), 15)
	pickup("fr_rod", "switch_rod", Vector3(29.0, 0.1, 12.4), 1, "", "fr_parts")
	container("fr_hut_locker", Vector3(28.6, 0, 10.4), 90, [["fuel", 1], ["bandage", 1]], "locker", {"count_flag": "fr_mats"})

	# A derailed handcar beside the train: the crowbar is here.
	Build.box(self, Vector3(-8, 0.5, -7.5), Vector3(2.4, 0.2, 1.6), wood, true, Vector3(0, 20, 14))
	Build.cyl(self, Vector3(-7.2, 0.35, -6.6), 0.35, 0.1, metal, false, Vector3(70, 20, 0))
	pickup("fr_crowbar", "crowbar", Vector3(-8.6, 0.1, -6.2))
	Build.lamp_post(self, Vector3(-6, 0, -9.5), Color(0.8, 0.9, 1.0), 0.35, 2.6)

	# Trail north to the search party's camp, marked with rag flags.
	for i in 9:
		var t := float(i) / 8.0
		var p := Vector3(-8, 0, -11).lerp(Vector3(-22, 0, -50), t) + Vector3(sin(i * 1.3) * 1.5, 0, 0)
		Build.box(self, p + Vector3(0, 0.02, 0), Vector3(2.2, 0.04, 5.4), Mat.tex("dirt", Color(0.4, 0.38, 0.36)), false, Vector3(0, 20, 0))
		if i % 2 == 0:
			Build.cyl(self, p + Vector3(1.6, 0.8, 0), 0.03, 1.6, wood)
			Build.box(self, p + Vector3(1.75, 1.45, 0), Vector3(0.3, 0.2, 0.02), Mat.flat(Color(0.6, 0.12, 0.1)), false)
	var camp := Vector3(-24, 0, -56)
	trigger("fr_camp", camp, Vector3(9, 3, 8), "You found the search party's camp. Nobody has been here for a long time.")
	for i in 3:
		var tp := camp + Vector3(-5.0 + i * 5.0, 0, -3.0 - (i % 2) * 1.5)
		Build.box(self, tp + Vector3(-0.55, 0.7, 0), Vector3(1.7, 0.05, 2.6), canvas, false, Vector3(0, 0, 55))
		Build.box(self, tp + Vector3(0.55, 0.7, 0), Vector3(1.7, 0.05, 2.6), canvas, false, Vector3(0, 0, -55))
		Build.box(self, tp + Vector3(0, 0.6, -1.3), Vector3(1.6, 1.2, 0.05), canvas)
	Build.cyl(self, camp + Vector3(0, 0.08, 1.5), 0.7, 0.16, Mat.tex("stone", Color(0.35, 0.35, 0.35)), false)
	Build.box(self, camp + Vector3(0, 0.2, 1.5), Vector3(0.9, 0.12, 0.12), Mat.flat(Color(0.05, 0.04, 0.04)), false, Vector3(0, 40, 0))
	Build.light(self, camp + Vector3(2.4, 1.0, 0.5), Color(1.0, 0.65, 0.3), 0.35, 7.0)
	Build.box(self, camp + Vector3(2.4, 0.25, 0.5), Vector3(0.5, 0.5, 0.5), wood)
	Build.box(self, camp + Vector3(2.4, 0.62, 0.5), Vector3(0.14, 0.22, 0.14), Mat.glow(Color(1.0, 0.65, 0.3), 1.5), false)
	document("fr_doc_camp", "d_camp", camp + Vector3(-3.2, 0.05, 1.2), 30)
	pickup("fr_lever", "switch_lever", camp + Vector3(4.2, 0.1, 2.2), 1, "", "fr_parts")
	container("fr_camp_crate", camp + Vector3(-5.5, 0, 2.5), 25, [["wrench", 1], ["scrap", 2]], "crate", {"count_flag": "fr_mats"})
	container("fr_camp_barrel", camp + Vector3(5.8, 0, -0.5), 0, [["fuel", 1], ["cloth", 2]], "barrel", {"count_flag": "fr_mats"})
	pickup("fr_camp_med", "med_supplies", camp + Vector3(-0.2, 0.1, -3.0), 2)

	# Other things lost in the wood.
	Build.box(self, Vector3(-52, 0.6, 24), Vector3(3.2, 0.25, 1.8), wood, true, Vector3(8, -30, 10))
	container("fr_cart_crate", Vector3(-50, 0, 26), -30, [["bolts", 3], ["wires", 1]], "crate", {"count_flag": "fr_mats"})
	for i in 4:
		Build.cyl(self, Vector3(55 + (i % 2) * 1.6, 1.6, -30 + (i / 2) * 1.6), 0.07, 3.2, wood, true)
	Build.box(self, Vector3(55.8, 3.2, -29.2), Vector3(2.2, 0.1, 2.2), wood, false)
	container("fr_stand_crate", Vector3(55.8, 0, -27.2), 0, [["battery", 1], ["components", 1], ["scrap", 1]], "crate", {"count_flag": "fr_mats"})
	container("fr_stump_barrel", Vector3(10, 0, 32), 0, [["electronics", 1], ["scrap", 2]], "barrel", {"count_flag": "fr_mats"})
	Build.lamp_post(self, Vector3(34, 0, 6.5), Color(1.0, 0.7, 0.4), 0.45, 3.0)

	scatter_trees(210, 95, 70, [[camp, 9.0], [Vector3(30, 0, 11), 6.0], [Vector3(-8, 0, -8), 4.0],
		[Vector3(-50, 0, 25), 4.0], [Vector3(56, 0, -29), 4.5], [Vector3(10, 0, 32), 3.0], [Vector3(38, 0, 4), 5.0]], 4, 99)

	enemy_spawns = [{"type": "hollow", "pos": Vector3(30, 0, -48),
		"points": [Vector3(30, 0, -48), Vector3(-45, 0, -30), Vector3(0, 0, -30), Vector3(50, 0, 30), Vector3(-30, 0, 40),
			Vector3(-60, 0, -55), Vector3(15, 0, 45), Vector3(60, 0, -12), Vector3(-10, 0, -62), Vector3(-70, 0, 12)]}]
	apparition_points = [Vector3(-14, 0, -24), Vector3(20, 0, 14), Vector3(-30, 0, -44), Vector3(44, 0, -10)]
	bonus_points = [Vector3(-2, 0.1, 9), Vector3(18, 0.1, -9), Vector3(-16, 0.1, -30)]
