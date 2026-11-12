extends Node
## Root of the game scene: PS1 viewport with the World inside, HUD, panels, input routing,
## screen effects and music.

const PANELS := {
	"inventory": "res://scenes/interface/inventory.tscn",
	"craft": "res://scenes/interface/crafting.tscn",
	"route_map": "res://scenes/interface/route_map.tscn",
	"train_panel": "res://scenes/interface/train_panel.tscn",
	"document": "res://scenes/interface/document.tscn",
	"keypad": "res://scenes/interface/keypad.tscn",
	"pause": "res://scenes/interface/pause_menu.tscn",
	"ending": "res://scenes/interface/ending.tscn",
}

var view: Ps1View
var world: World
var hud: Hud
var _panels := {}
var _open := ""
var _glitch := 0.0
var _damage := 0.0
var _fade := 1.0
var _ended := false
var _poll := 0.0
var _loading: Label
var _heart: AudioStreamPlayer


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	view = Ps1View.new()
	view.name = "View"
	view.sub.name = "Sub"
	view.process_mode = Node.PROCESS_MODE_PAUSABLE
	add_child(view)
	world = preload("res://scenes/game/world.tscn").instantiate()
	world.name = "World"
	view.sub.add_child(world)

	var layer := CanvasLayer.new()
	add_child(layer)
	hud = preload("res://scenes/interface/hud.tscn").instantiate()
	layer.add_child(hud)
	for key in PANELS:
		var p: GamePanel = load(PANELS[key]).instantiate()
		p.visible = false
		layer.add_child(p)
		p.close_requested.connect(close_panel)
		if p.has_signal("leave_requested"):
			p.connect("leave_requested", leave_game)
		_panels[key] = p
	_loading = UIKit.label("Waiting for all players...", 24)
	_loading.theme = UIKit.theme()
	UIKit.place(_loading, Control.PRESET_CENTER, Vector2(0, 80))
	layer.add_child(_loading)
	_heart = AudioStreamPlayer.new()
	_heart.stream = Audio.stream("heartbeat_loop")
	_heart.bus = "SFX"
	_heart.volume_db = -8.0
	add_child(_heart)

	GameState.fx.connect(_on_fx)
	GameState.state_loaded.connect(func(): _loading.visible = false)
	GameState.ending_reached.connect(_on_ending)
	Net.player_left.connect(_on_player_left)
	Audio.music("")
	_capture(true)


func _capture(on: bool) -> void:
	if DisplayServer.get_name() == "headless":
		return
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED if on else Input.MOUSE_MODE_VISIBLE


func _player() -> Player:
	var p = GameState.local_player
	return p if p != null and is_instance_valid(p) else null


# --- panels -------------------------------------------------------------------

func open_panel(key: String, args: Dictionary = {}) -> void:
	if _ended and key != "ending":
		return
	if _open != "":
		_panels[_open].visible = false
		_panels[_open].closed()
	_open = key
	_panels[key].visible = true
	_panels[key].open(args)
	_capture(false)
	var p := _player()
	if p:
		p.controls = false
	get_tree().paused = key == "pause" and not Net.online


func close_panel() -> void:
	if _open == "" or _ended:
		return
	_panels[_open].visible = false
	_panels[_open].closed()
	_open = ""
	get_tree().paused = false
	_capture(true)
	var p := _player()
	if p:
		p.controls = true


func leave_game() -> void:
	get_tree().paused = false
	Net.leave()
	GameState.reset()
	SceneFlow.to_menu()


# --- input --------------------------------------------------------------------

func _input(event: InputEvent) -> void:
	if _ended:
		return
	var p := _player()
	if event is InputEventMouseMotion:
		if p and _open == "" and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
			p.look(event.relative)
		return
	if not (event is InputEventKey) or not event.pressed or event.echo:
		return
	if event.keycode == KEY_ESCAPE:
		if _open != "":
			close_panel()
		else:
			open_panel("pause")
		get_viewport().set_input_as_handled()
		return
	if _open != "":
		if _open == "inventory" and event.is_action_pressed("inventory"):
			close_panel()
			get_viewport().set_input_as_handled()
		return
	if p == null:
		return
	if event.is_action_pressed("inventory"):
		open_panel("inventory")
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("interact"):
		p.try_interact()
	elif event.is_action_pressed("flashlight"):
		p.toggle_flashlight()
	elif event.is_action_pressed("reload"):
		Actions.req_reload.rpc_id(1)


# --- effects --------------------------------------------------------------------

func _on_fx(effect: String, args: Dictionary) -> void:
	var p := _player()
	match effect:
		"open_ui":
			match args["ui"]:
				"craft": open_panel("craft", args)
				"stash": open_panel("inventory", {"stash": args["station"]})
				"train_panel": open_panel("train_panel")
				"route_map": open_panel("route_map")
		"open_map":
			open_panel("route_map")
		"read_doc":
			open_panel("document", args)
		"open_keypad":
			open_panel("keypad", args)
		"chapter":
			hud.show_chapter(args["loc"])
			Audio.ui("bell", -12.0)
		"glitch":
			_glitch = maxf(_glitch, args.get("power", 0.5))
		"signal":
			_glitch = maxf(_glitch, 0.25 + args.get("power", 0.5) * 0.75)
			if p:
				p.disrupted = 1.2
			Audio.ui("radio_blip", -14.0 + args.get("power", 0.5) * 8.0)
		"hurt":
			_damage = 1.0
		"heal":
			Audio.ui("heal", -8.0)
		"scare":
			_glitch = maxf(_glitch, 0.45)
			Audio.ui("scare", -8.0)
		"collapse":
			_fade = 0.0
			Audio.ui("scare", -10.0)
		"lights_flicker":
			Audio.ui("switch", -14.0)


func _process(delta: float) -> void:
	_glitch = maxf(0.0, _glitch - delta * 0.9)
	_damage = maxf(0.0, _damage - delta * 1.2)
	_fade = minf(1.0, _fade + delta * 0.35)
	var me := GameState.me()
	var low := 0.0
	if not me.is_empty():
		var frac: float = me["hp"] / me["max_hp"]
		low = clampf((0.4 - frac) * 1.6, 0.0, 0.6)
		if frac < 0.3 and not _heart.playing and _heart.stream:
			_heart.play()
		elif frac >= 0.3 and _heart.playing:
			_heart.stop()
	view.set_fx("glitch", _glitch)
	view.set_fx("damage", maxf(_damage, low))
	view.set_fx("fade", _fade)
	_poll -= delta
	if _poll <= 0.0:
		_poll = 0.5
		_update_music()


func _update_music() -> void:
	if _ended or GameState.data.is_empty():
		return
	var p := _player()
	var hunted := false
	if p and world:
		for e in world.enemies.get_children():
			if e.get("threat") == true and e.global_position.distance_to(p.global_position) < 32.0:
				hunted = true
	if hunted:
		Audio.music("chase_theme_loop", -9.0)
	elif GameState.data.get("traveling", false):
		Audio.music("travel_theme_loop", -14.0)
	else:
		Audio.music("")


func _on_ending(id: String, stats: Dictionary) -> void:
	if _open != "":
		close_panel()
	_ended = true
	var p := _player()
	if p:
		p.controls = false
	Audio.music("ending_theme_loop", -8.0)
	Audio.ambient("")
	_capture(false)
	_open = "ending"
	_panels["ending"].visible = true
	_panels["ending"].open({"id": id, "stats": stats})
	print("[game] ending reached: %s" % id)


## A dedicated host returns to its lobby when the last player leaves.
func _on_player_left(_id: int) -> void:
	if Net.dedicated and Net.lobby.is_empty():
		GameState.reset()
		Net.in_game = false
		multiplayer.multiplayer_peer.refuse_new_connections = false
		SceneFlow.goto(SceneFlow.LOBBY)
