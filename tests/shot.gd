extends SceneTree
## Dev tool: renders a few screenshots into /tmp/shots (needs a display, e.g. xvfb-run).
## Run: xvfb-run -a godot --path . -s tests/shot.gd -- [menu|game] [loc index]


func _initialize() -> void:
	_run.call_deferred()


func snap(name: String) -> void:
	await create_timer(0.5).timeout
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("/tmp/shots/%s.png" % name)
	print("saved ", name)


func _run() -> void:
	DirAccess.make_dir_recursive_absolute("/tmp/shots")
	var args := Array(OS.get_cmdline_user_args())
	var GS = root.get_node("/root/GameState")
	var Net = root.get_node("/root/Net")
	if "ru" in args:
		TranslationServer.set_locale("ru")
		args.erase("ru")
	if args.is_empty() or args[0] == "menu":
		change_scene_to_file("res://scenes/main_menu/main_menu.tscn")
		await create_timer(2.0).timeout
		await snap("menu")
		Net.start_single()
		change_scene_to_file("res://scenes/lobby/lobby.tscn")
		await create_timer(1.5).timeout
		await snap("lobby")
		quit()
		return
	Net.start_single()
	Net.request_char.rpc_id(1, 0)
	change_scene_to_file("res://scenes/game/game.tscn")
	await create_timer(3.0).timeout
	var loc := int(args[1]) if args.size() > 1 else 0
	if loc > 0:
		GS.set_travel(false, loc)
		await create_timer(2.0).timeout
	var p = GS.local_player
	GS.give(1, "flashlight", 1)
	var views: Array = [[Vector3(11, 1.0, 0), 90.0], [Vector3(20, 1.0, 0), -90.0], [Vector3(12, 0.2, 9), 20.0], [Vector3(34, 0.2, 10), 60.0]]
	var i := 2
	while i + 3 < args.size():
		views.append([Vector3(float(args[i]), float(args[i + 1]), float(args[i + 2])), float(args[i + 3])])
		i += 4
	var n := 0
	for v in views:
		p.teleport(v[0])
		p.rotation.y = deg_to_rad(v[1])
		p.flash_on = n % 2 == 1
		await snap("game_%d_%d" % [loc, n])
		n += 1
	quit()
