extends Node
## Sound manager: buses, cached streams, UI / positional one-shots, music and ambience.

const BUSES := ["Music", "SFX", "Ambient"]

var _cache := {}
var _music: AudioStreamPlayer
var _music_name := ""
var _ambient: AudioStreamPlayer
var _ambient_name := ""


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for bus in BUSES:
		if AudioServer.get_bus_index(bus) == -1:
			AudioServer.add_bus()
			var idx := AudioServer.bus_count - 1
			AudioServer.set_bus_name(idx, bus)
			AudioServer.set_bus_send(idx, "Master")
	var sfx := AudioServer.get_bus_index("SFX")
	if AudioServer.get_bus_effect_count(sfx) == 0:
		var reverb := AudioEffectReverb.new()
		reverb.room_size = 0.35
		reverb.damping = 0.6
		reverb.wet = 0.1
		reverb.dry = 1.0
		AudioServer.add_bus_effect(sfx, reverb)
	_music = AudioStreamPlayer.new()
	_music.bus = "Music"
	add_child(_music)
	_ambient = AudioStreamPlayer.new()
	_ambient.bus = "Ambient"
	add_child(_ambient)
	apply_volumes()


func apply_volumes() -> void:
	_set_bus("Music", Settings.music_volume)
	_set_bus("SFX", Settings.sfx_volume)
	_set_bus("Ambient", Settings.ambient_volume)


func _set_bus(bus: String, linear: float) -> void:
	var idx := AudioServer.get_bus_index(bus)
	if idx == -1:
		return
	AudioServer.set_bus_mute(idx, linear <= 0.001)
	AudioServer.set_bus_volume_db(idx, linear_to_db(maxf(linear, 0.001)))


func stream(sound: String) -> AudioStream:
	if _cache.has(sound):
		return _cache[sound]
	var res: AudioStream = null
	for dir in ["sounds", "music"]:
		var path := "res://assets/%s/%s.wav" % [dir, sound]
		if ResourceLoader.exists(path):
			res = load(path)
			break
	if res is AudioStreamWAV and sound.ends_with("_loop"):
		var wav := res as AudioStreamWAV
		var bytes_per_frame := (2 if wav.format == AudioStreamWAV.FORMAT_16_BITS else 1) * (2 if wav.stereo else 1)
		wav.loop_mode = AudioStreamWAV.LOOP_FORWARD
		wav.loop_begin = 0
		wav.loop_end = wav.data.size() / bytes_per_frame
	_cache[sound] = res
	return res


## Non-positional one-shot (UI, feedback to the local player).
func ui(sound: String, volume_db := -6.0) -> void:
	var s := stream(sound)
	if s == null:
		return
	var p := AudioStreamPlayer.new()
	p.stream = s
	p.bus = "SFX"
	p.volume_db = volume_db
	add_child(p)
	p.play()
	p.finished.connect(p.queue_free)


## Positional one-shot in the game world.
func at(sound: String, pos: Vector3, volume_db := 0.0, max_dist := 28.0, pitch := 1.0) -> void:
	var s := stream(sound)
	var world: Node = GameState.scene
	if s == null or world == null or not is_instance_valid(world):
		return
	var p := AudioStreamPlayer3D.new()
	p.stream = s
	p.bus = "SFX"
	p.volume_db = volume_db
	p.max_distance = max_dist
	p.unit_size = 4.0
	p.pitch_scale = pitch
	p.attenuation_filter_cutoff_hz = 6000.0
	world.add_child(p)
	p.global_position = pos
	p.play()
	if sound.ends_with("_loop"):
		get_tree().create_timer(3.5).timeout.connect(p.queue_free)
	else:
		p.finished.connect(p.queue_free)


## Looping positional emitter attached to a node. The caller owns the returned player.
func loop_on(node: Node3D, sound: String, volume_db := 0.0, max_dist := 24.0, bus := "Ambient", autoplay := true) -> AudioStreamPlayer3D:
	var p := AudioStreamPlayer3D.new()
	p.stream = stream(sound)
	p.bus = bus
	p.volume_db = volume_db
	p.max_distance = max_dist
	p.unit_size = 4.0
	node.add_child(p)
	if autoplay and p.stream != null:
		p.play()
	return p


func music(track: String, volume_db := -8.0) -> void:
	if track == _music_name:
		return
	_music_name = track
	var tw := create_tween()
	if _music.playing:
		tw.tween_property(_music, "volume_db", -50.0, 1.0)
	tw.tween_callback(func():
		_music.stop()
		if track == "":
			return
		_music.stream = stream(track)
		_music.volume_db = -50.0
		if _music.stream:
			_music.play())
	if track != "":
		tw.tween_property(_music, "volume_db", volume_db, 1.5)


func ambient(track: String, volume_db := -10.0) -> void:
	if track == _ambient_name:
		_ambient.volume_db = volume_db
		return
	_ambient_name = track
	_ambient.stop()
	if track == "":
		return
	_ambient.stream = stream(track)
	_ambient.volume_db = volume_db
	if _ambient.stream:
		_ambient.play()
