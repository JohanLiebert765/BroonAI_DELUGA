extends Enemy
## THE SIGNAL - manifests at railway signal lamps. Jams flashlights and the compass,
## floods the radio with static, bleeds power from the train and burns at close range.

enum { DORMANT, MANIFEST }

const HIDE_Y := -60.0
const RADIUS := 14.0

var _points: Array = []
var _timer := 20.0
var _pulse := 0.0
var _drained := false
var _core: MeshInstance3D
var _shards: Array = []
var _light: OmniLight3D
var _hum: AudioStreamPlayer3D
var _figure: StandardMaterial3D


func _build() -> void:
	_points = config.get("points", [position])
	var red := Mat.glow(Color(1.0, 0.08, 0.05), 4.0)
	_core = Build.cyl(self, Vector3(0, 2.4, 0), 0.26, 0.26, red, false, Vector3(90, 0, 0), 8)
	for i in 6:
		var shard := Node3D.new()
		shard.position = Vector3(0, 2.4, 0)
		shard.rotation = Vector3(i * 1.1, i * 0.7, i * 0.4)
		add_child(shard)
		Build.box(shard, Vector3(0.55 + (i % 3) * 0.12, 0, 0), Vector3(0.5, 0.04, 0.06), Mat.flat(Color(0.02, 0.02, 0.02)), false)
		_shards.append(shard)
	_figure = Mat.ghost(Color(0.3, 0.02, 0.02), 0.35)
	Build.box(self, Vector3(0, 1.1, 0), Vector3(0.3, 2.2, 0.12), _figure, false)
	_light = Build.light(self, Vector3(0, 2.4, 0), Color(1.0, 0.1, 0.05), 2.0, 12.0)
	_hum = Audio.loop_on(self, "signal_hum_loop", -3.0, 26.0, "SFX", false)
	_hum.position.y = 2.4
	if GameState.is_host():
		position.y = HIDE_Y
		alpha = 0.0
		_timer = float(config.get("delay", 25.0))


func _think(delta: float) -> void:
	_timer -= delta
	match state:
		DORMANT:
			if _timer > 0.0:
				return
			var pool := targets()
			if pool.is_empty() or _points.is_empty():
				_timer = 10.0
				return
			var tp := ppos(pool[randi() % pool.size()])
			var spot: Vector3 = _points[0]
			var best := 1e9
			for pt in _points:
				var d: float = pt.distance_to(tp)
				if d < best:
					best = d
					spot = pt
			position = spot
			alpha = 1.0
			_drained = false
			_timer = randf_range(13.0, 19.0)
			state = MANIFEST
		MANIFEST:
			_pulse -= delta
			if _pulse <= 0.0:
				_pulse = 0.5
				for p in world().player_nodes():
					var d := position.distance_to(ppos(p))
					if d < RADIUS:
						GameState.fx_to(p.peer_id, "signal", {"power": 1.0 - d / RADIUS})
						if d < 4.0:
							GameState.hurt(p.peer_id, 3.0)
				if not _drained and absf(position.z) < 16.0 and position.x > -40.0 and position.x < 36.0:
					_drained = true
					var t: Dictionary = GameState.data["train"]
					t["electric"] = maxf(0.0, t["electric"] - 12.0)
					GameState.fx_all("lights_flicker")
					GameState.notify_all("The red light bleeds into the train's wiring. The lamps dim.", [], "warn")
			if _timer <= 0.0:
				alpha = 0.0
				position.y = HIDE_Y
				_timer = randf_range(28.0, 50.0)
				state = DORMANT


func _animate(delta: float, _speed: float) -> void:
	visible = alpha > 0.5
	for i in _shards.size():
		_shards[i].rotate_y(delta * (1.5 + i * 0.4))
		_shards[i].rotate_x(delta * 0.7)
	_light.light_energy = 5.0 + sin(_anim_t * 13.0) * 2.5 + randf() * 2.0
	_figure.albedo_color.a = 0.15 + randf() * 0.3
	_core.scale = Vector3.ONE * (1.0 + sin(_anim_t * 6.0) * 0.15)
	if visible and not _hum.playing and _hum.stream:
		_hum.play()
	elif not visible and _hum.playing:
		_hum.stop()
