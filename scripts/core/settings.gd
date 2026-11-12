extends Node
## Persistent user settings: audio, video, controls and language.

signal changed

const PATH := "user://settings.cfg"
const RESOLUTIONS: Array[Vector2i] = [Vector2i(1280, 720), Vector2i(1600, 900), Vector2i(1920, 1080), Vector2i(2560, 1440)]
const QUALITY_NAMES := ["Low", "Medium", "High"]
const DEFAULT_KEYS := {
	"move_forward": KEY_W, "move_back": KEY_S, "move_left": KEY_A, "move_right": KEY_D,
	"sprint": KEY_SHIFT, "crouch": KEY_CTRL, "jump": KEY_SPACE, "interact": KEY_E,
	"inventory": KEY_TAB, "flashlight": KEY_F, "reload": KEY_R,
}
const ACTION_LABELS := {
	"move_forward": "Move forward", "move_back": "Move back", "move_left": "Move left", "move_right": "Move right",
	"sprint": "Sprint", "crouch": "Crouch", "jump": "Jump", "interact": "Interact",
	"inventory": "Inventory", "flashlight": "Flashlight", "reload": "Reload flashlight",
}

var music_volume := 0.7
var sfx_volume := 0.8
var ambient_volume := 0.8
var resolution := 0
var fullscreen := false
var mouse_sensitivity := 1.0
var invert_y := false
var quality := 1
var language := "en"
var player_name := "Survivor"
var last_ip := "127.0.0.1"
var last_port := 24680
var keys := {}


func _ready() -> void:
	keys = DEFAULT_KEYS.duplicate()
	load_settings()
	_build_actions()
	apply()


func load_settings() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(PATH) != OK:
		if OS.get_locale_language() == "ru":
			language = "ru"
		return
	music_volume = cfg.get_value("audio", "music", music_volume)
	sfx_volume = cfg.get_value("audio", "sfx", sfx_volume)
	ambient_volume = cfg.get_value("audio", "ambient", ambient_volume)
	resolution = clampi(cfg.get_value("video", "resolution", resolution), 0, RESOLUTIONS.size() - 1)
	fullscreen = cfg.get_value("video", "fullscreen", fullscreen)
	quality = clampi(cfg.get_value("video", "quality", quality), 0, 2)
	mouse_sensitivity = cfg.get_value("controls", "sensitivity", mouse_sensitivity)
	invert_y = cfg.get_value("controls", "invert_y", invert_y)
	language = cfg.get_value("game", "language", language)
	player_name = cfg.get_value("game", "player_name", player_name)
	last_ip = cfg.get_value("game", "last_ip", last_ip)
	last_port = cfg.get_value("game", "last_port", last_port)
	for action in DEFAULT_KEYS:
		keys[action] = int(cfg.get_value("keys", action, DEFAULT_KEYS[action]))


func save_settings() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("audio", "music", music_volume)
	cfg.set_value("audio", "sfx", sfx_volume)
	cfg.set_value("audio", "ambient", ambient_volume)
	cfg.set_value("video", "resolution", resolution)
	cfg.set_value("video", "fullscreen", fullscreen)
	cfg.set_value("video", "quality", quality)
	cfg.set_value("controls", "sensitivity", mouse_sensitivity)
	cfg.set_value("controls", "invert_y", invert_y)
	cfg.set_value("game", "language", language)
	cfg.set_value("game", "player_name", player_name)
	cfg.set_value("game", "last_ip", last_ip)
	cfg.set_value("game", "last_port", last_port)
	for action in keys:
		cfg.set_value("keys", action, keys[action])
	cfg.save(PATH)


func apply() -> void:
	TranslationServer.set_locale(language)
	if DisplayServer.get_name() != "headless":
		var win := get_window()
		if fullscreen:
			win.mode = Window.MODE_FULLSCREEN
		else:
			win.mode = Window.MODE_WINDOWED
			win.size = RESOLUTIONS[resolution]
	var audio := get_node_or_null("/root/Audio")
	if audio:
		audio.apply_volumes()
	changed.emit()


func _build_actions() -> void:
	for action in keys:
		if not InputMap.has_action(action):
			InputMap.add_action(action)
		InputMap.action_erase_events(action)
		var ev := InputEventKey.new()
		ev.physical_keycode = keys[action]
		InputMap.action_add_event(action, ev)


func rebind(action: String, keycode: int) -> void:
	# Swap with whichever action already uses this key so no two actions collide.
	for other in keys:
		if other != action and keys[other] == keycode:
			keys[other] = keys[action]
	keys[action] = keycode
	_build_actions()
	save_settings()
	changed.emit()


func reset_keys() -> void:
	keys = DEFAULT_KEYS.duplicate()
	_build_actions()
	save_settings()
	changed.emit()


func key_name(action: String) -> String:
	return OS.get_keycode_string(keys.get(action, 0))


## Internal 3D resolution divisor used by the PS1 viewport.
func shrink() -> int:
	return [4, 3, 2][quality]
