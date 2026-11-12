extends CanvasLayer
## Scene transitions with a fade, plus command-line entry points (dedicated server).

const MENU := "res://scenes/main_menu/main_menu.tscn"
const LOBBY := "res://scenes/lobby/lobby.tscn"
const GAME := "res://scenes/game/game.tscn"

var menu_message := ""  # shown by the main menu after being sent back (e.g. host left)
var _fade: ColorRect
var _busy := false
var _queued := ""


func _ready() -> void:
	layer = 100
	process_mode = Node.PROCESS_MODE_ALWAYS
	_fade = ColorRect.new()
	_fade.color = Color(0, 0, 0, 0)
	_fade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_fade)
	var args := OS.get_cmdline_user_args() + OS.get_cmdline_args()
	if "--server" in args:
		var port := Net.DEFAULT_PORT
		var i := args.find("--port")
		if i != -1 and i + 1 < args.size():
			port = int(args[i + 1])
		_start_dedicated.call_deferred(port)


func _start_dedicated(port: int) -> void:
	var err := Net.host(port, true)
	if err != OK:
		push_error("Dedicated server failed to start on port %d (error %d)" % [port, err])
		get_tree().quit(1)
		return
	print("[server] dedicated host listening on port %d" % port)
	get_tree().change_scene_to_file(LOBBY)


func goto(path: String) -> void:
	if _busy:
		_queued = path
		return
	_busy = true
	get_tree().paused = false
	var tw := create_tween()
	tw.tween_property(_fade, "color:a", 1.0, 0.35)
	await tw.finished
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	get_tree().change_scene_to_file(path)
	await get_tree().process_frame
	await get_tree().process_frame
	var tw2 := create_tween()
	tw2.tween_property(_fade, "color:a", 0.0, 0.5)
	_busy = false
	if _queued != "":
		var next := _queued
		_queued = ""
		goto(next)


func to_menu(message := "") -> void:
	menu_message = message
	goto(MENU)
