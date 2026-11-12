extends Location
## Chapter IV - The Empty Village. The engine has failed; parts are in the workshop,
## the houses and Inspector Voss's locked cellar. The Conductor walks the lane.


func build() -> void:
	env = {
		"sky": Color(0.02, 0.018, 0.025), "fog_color": Color(0.1, 0.09, 0.1), "fog_density": 0.05,
		"ambient": Color(0.45, 0.4, 0.45), "ambient_energy": 0.55, "moon": 0.12,
		"ambient_sound": "wind_loop", "ambient_db": -12.0,
	}
	ground(90, 60)
	rails(-90, 90)
	var plaster := Mat.tex("plaster", Color(0.6, 0.56, 0.5))
	var brick := Mat.tex("brick", Color(0.5, 0.42, 0.4))
	var stone := Mat.tex("stone", Color(0.45, 0.45, 0.45))
	var roof := Mat.tex("roof", Color(0.42, 0.36, 0.36))
	var wood := Mat.tex("planks", Color(0.48, 0.42, 0.38))
	var floor_mat := Mat.tex("planks", Color(0.38, 0.34, 0.3))

	# Halt platform and the lane.
	Build.box(self, Vector3(0, 0.03, 6.2), Vector3(40, 0.06, 4.0), Mat.tex("concrete", Color(0.5, 0.5, 0.5)), false)
	Build.label(self, Vector3(0, 2.2, 8.4), "HARROW HALT", 64, Color(0.8, 0.78, 0.65), Vector3(0, 180, 0))
	Build.cyl(self, Vector3(-2.2, 1.1, 8.4), 0.05, 2.2, wood)
	Build.cyl(self, Vector3(2.2, 1.1, 8.4), 0.05, 2.2, wood)
	Build.box(self, Vector3(0, 0.02, 14), Vector3(120, 0.04, 4.5), Mat.tex("asphalt", Color(0.4, 0.4, 0.42)), false)
	for x in [-36.0, -12.0, 12.0, 36.0]:
		Build.lamp_post(self, Vector3(x, 0, 11.2), Color(1.0, 0.75, 0.45), 0.7)

	# Shop.
	var shop := Vector3(-14, 0, 18)
	building(shop, Vector3(9, 3.0, 6.5), brick, roof, {"n": [[4.0, 5.0, 0, 2.05], [1.0, 3.2, 0.9, 2.1], [5.8, 8.0, 0.9, 2.1]]}, floor_mat, true)
	ndoor("vl_shop_door", shop, 4.0)
	Build.label(self, Vector3(-9.5, 2.65, 17.9), "PROVISIONS", 48, Color(0.8, 0.78, 0.65), Vector3(0, 180, 0))
	Build.light(self, Vector3(-9.5, 2.5, 21), Color(1.0, 0.75, 0.45), 0.6, 8.0)
	Build.box(self, Vector3(-9.5, 0.5, 22.2), Vector3(6.0, 1.0, 0.7), wood)
	document("vl_doc_shop", "d_shop", Vector3(-8.2, 1.01, 22.2), 10)
	pickup("vl_radio_item", "radio", Vector3(-10.8, 1.02, 22.2), 1, "vl_radio")
	Build.light(self, Vector3(-10.8, 1.3, 22.0), Color(0.4, 1.0, 0.5), 0.15, 2.5)
	container("vl_shop_cabinet", Vector3(-13.3, 0, 21), 90, [["fuel", 1], ["battery", 1]], "cabinet")
	container("vl_shop_crate", Vector3(-6.0, 0, 19.2), -20, [["cloth", 2], ["med_supplies", 1]])

	# Workshop.
	var ws := Vector3(8, 0, 18)
	building(ws, Vector3(10, 3.2, 7), wood, roof, {"n": [[2.0, 3.0, 0, 2.05], [5.5, 8.5, 0, 2.6]]}, Mat.tex("concrete", Color(0.4, 0.4, 0.4)))
	ndoor("vl_workshop_door", ws, 2.0)
	Build.label(self, Vector3(13, 2.9, 17.9), "SMITH & WHEELWRIGHT", 40, Color(0.8, 0.78, 0.65), Vector3(0, 180, 0))
	Build.light(self, Vector3(13, 2.7, 21.5), Color(1.0, 0.7, 0.4), 0.5, 9.0)
	Build.box(self, Vector3(13, 0.45, 24.3), Vector3(5.0, 0.9, 0.8), wood)
	pickup("vl_comp_a", "components", Vector3(11.6, 0.95, 24.2), 1, "", "vl_parts")
	pickup("vl_comp_b", "components", Vector3(14.2, 0.95, 24.3), 1, "", "vl_parts")
	pickup("vl_wrench", "wrench", Vector3(12.9, 0.95, 24.4))
	container("vl_ws_crate", Vector3(9.2, 0, 23.6), 12, [["scrap", 3], ["bolts", 2]])
	container("vl_ws_locker", Vector3(17.3, 0, 22), -90, [["wires", 2], ["fuse", 1]], "locker")
	Build.box(self, Vector3(16, 0.4, 19.6), Vector3(1.0, 0.8, 0.6), Mat.tex("rust", Color(0.5, 0.5, 0.5)))

	# Voss's cellar: a stone store behind a code lock.
	var cel := Vector3(21, 0, 19)
	building(cel, Vector3(4.5, 2.3, 4.5), stone, Mat.tex("stone", Color(0.35, 0.35, 0.35)), {"n": [[1.7, 2.7, 0, 2.05]]}, Mat.tex("stone", Color(0.3, 0.3, 0.3)))
	ndoor("vl_cellar_door", cel, 1.7, {"keypad": true, "material": Mat.tex("metal", Color(0.35, 0.36, 0.4))})
	Build.box(self, Vector3(24.0, 1.3, 18.95), Vector3(0.25, 0.35, 0.06), Mat.glow(Color(0.9, 0.2, 0.1), 1.0), false)
	Build.label(self, Vector3(23.2, 2.15, 18.9), "T. VOSS - KEEP OUT", 30, Color(0.8, 0.78, 0.65), Vector3(0, 180, 0))
	Build.light(self, Vector3(23.2, 1.9, 21.4), Color(1.0, 0.55, 0.3), 0.3, 5.0)
	Build.box(self, Vector3(23.2, 0.4, 22.9), Vector3(1.6, 0.8, 0.7), wood)
	document("vl_doc_confession", "d_confession", Vector3(23.2, 0.81, 22.9), -8)
	pickup("vl_engine_part", "engine_part", Vector3(21.8, 0.1, 22.4), 1, "", "vl_parts")
	container("vl_cellar_locker", Vector3(24.9, 0, 21), -90, [["medkit", 1], ["fuel", 1]], "locker")

	# Houses with lit windows and nobody home.
	var houses := [
		[Vector3(-34, 0, 18), "vl_house_a", [["cloth", 2], ["bolts", 1]], plaster],
		[Vector3(-24, 0, 19), "vl_house_b", [["med_supplies", 1], ["scrap", 1]], brick],
		[Vector3(30, 0, 18.5), "vl_house_c", [["electronics", 2]], plaster],
		[Vector3(40, 0, 18), "vl_house_d", [["scrap", 2], ["bandage", 1]], brick],
	]
	for h in houses:
		var o: Vector3 = h[0]
		building(o, Vector3(7, 2.8, 6), h[3], roof, {"n": [[1.0, 2.0, 0, 2.05], [3.6, 5.6, 1.0, 2.0]]}, floor_mat, true)
		ndoor(h[1] + "_door", o, 1.0)
		Build.light(self, o + Vector3(3.5, 2.3, 3), Color(1.0, 0.72, 0.4), 0.45, 6.5)
		Build.box(self, o + Vector3(4.6, 0.38, 3.2), Vector3(1.6, 0.76, 1.0), wood)
		Build.box(self, o + Vector3(4.6, 0.8, 3.2), Vector3(0.3, 0.04, 0.3), Mat.flat(Color(0.8, 0.8, 0.75)), false)
		container(h[1] + "_cabinet", o + Vector3(6.3, 0, 4.4), -90, h[2], "cabinet")
	pickup("vl_comp_c", "components", Vector3(-19.6, 0.8, 22.2), 1, "", "vl_parts")
	pickup("vl_house_fuel", "fuel", Vector3(35.5, 0.05, 23.2))

	# Houses across the tracks, dark.
	for i in 3:
		var o := Vector3(-30.0 + i * 24.0, 0, -22)
		building(o, Vector3(7, 2.8, 6), plaster if i % 2 == 0 else brick, roof, {"s": [[3.0, 4.0, 0, 2.05]]}, floor_mat, true)
		container("vl_far_%d" % i, o + Vector3(1.0, 0, 1.2), 90, [["scrap", 1], ["wires", 1]] if i != 1 else [["repair_kit", 1]], "cabinet")
	# Well in the lane, fences, trees.
	Build.cyl(self, Vector3(2, 0.4, 14), 0.9, 0.8, stone, true, Vector3.ZERO, 10)
	Build.box(self, Vector3(2, 2.0, 14), Vector3(2.2, 0.1, 0.1), wood, false)
	Build.cyl(self, Vector3(1.0, 1.0, 14), 0.05, 2.0, wood)
	Build.cyl(self, Vector3(3.0, 1.0, 14), 0.05, 2.0, wood)
	fence(Vector3(-45, 0, 27), Vector3(50, 0, 27))
	fence(Vector3(-45, 0, -30), Vector3(50, 0, -30))
	scatter_trees(60, 85, 56, [[Vector3(0, 0, 18), 52.0], [Vector3(0, 0, -20), 44.0]], 3, 5)

	enemy_spawns = [{"type": "conductor", "pos": Vector3(44, 0, 14),
		"points": [Vector3(44, 0, 14), Vector3(18, 0, 14.5), Vector3(-8, 0, 13.5), Vector3(-38, 0, 14), Vector3(-20, 0, -14), Vector3(20, 0, -14)]}]
	apparition_points = [Vector3(-28, 0, 15.5), Vector3(26, 0, 16), Vector3(4, 0, -16), Vector3(46, 0, 12)]
	bonus_points = [Vector3(6, 0.1, 15.5), Vector3(-18, 0.1, 15.5), Vector3(-6, 0.1, -10)]
