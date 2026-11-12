class_name MenuBackdrop
extends Node3D
## 3D backdrop for the main menu and lobby: the Vesper standing at a night platform,
## drifting fog banks, chimney smoke, a failing lamp and a slowly swaying camera.

var camera: Camera3D
var _fog: Array = []
var _smoke: Array = []
var _lamp: OmniLight3D
var _t := 0.0
var _cam_base := Vector3.ZERO


func _ready() -> void:
	var we := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.02, 0.025, 0.045)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.35, 0.4, 0.6)
	env.ambient_light_energy = 1.4
	env.fog_enabled = true
	env.fog_light_color = Color(0.08, 0.09, 0.13)
	env.fog_density = 0.035
	we.environment = env
	add_child(we)
	var moon := DirectionalLight3D.new()
	moon.rotation_degrees = Vector3(-50, 40, 0)
	moon.light_color = Color(0.55, 0.65, 0.9)
	moon.light_energy = 0.9
	add_child(moon)

	Build.box(self, Vector3(0, -0.5, 0), Vector3(200, 1, 120), Mat.tex("dirt", Color(0.5, 0.5, 0.52), 0.25), false)
	Build.box(self, Vector3(0, 0.03, 0), Vector3(200, 0.06, 3.2), Mat.tex("gravel", Color(0.6, 0.6, 0.62), 0.5), false)
	for z in [-0.75, 0.75]:
		Build.box(self, Vector3(0, 0.12, z), Vector3(200, 0.12, 0.08), Mat.tex("metal", Color(0.5, 0.5, 0.55)), false)
	Build.box(self, Vector3(20, 0.4, 5.2), Vector3(60, 0.8, 6.4), Mat.tex("concrete", Color(0.5, 0.5, 0.52)), false)
	Build.box(self, Vector3(14, 2.4, 11.5), Vector3(14, 4.0, 5), Mat.tex("brick", Color(0.5, 0.45, 0.45)), false)
	Build.box(self, Vector3(14, 4.6, 11.5), Vector3(15, 0.4, 6), Mat.tex("roof", Color(0.4, 0.4, 0.45)), false)
	Build.box(self, Vector3(12, 2.3, 8.98), Vector3(1.4, 1.2, 0.05), Mat.glow(Color(0.9, 0.6, 0.3), 0.8), false)
	Build.label(self, Vector3(16, 3.6, 8.95), "BLACKMOOR", 64, Color(0.8, 0.78, 0.65), Vector3(0, 180, 0))
	_lamp = Build.lamp_post(self, Vector3(33, 0.8, 4.2))
	Build.lamp_post(self, Vector3(8, 0.8, 4.2), Color(1.0, 0.75, 0.45), 0.9)
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	for i in 40:
		var side := 1.0 if i % 3 != 0 else -1.0
		Build.tree(self, Vector3(rng.randf_range(-40, 90), 0, side * rng.randf_range(18, 50) + (0.0 if side > 0 else -6.0)), rng.randf_range(6, 11), i % 6 == 0)
	add_child(preload("res://scenes/train/train.tscn").instantiate())

	for i in 7:
		var bank := Build.box(self, Vector3(rng.randf_range(10, 60), rng.randf_range(0.6, 2.4), rng.randf_range(-6, 12)), Vector3(rng.randf_range(10, 18), 0.02, rng.randf_range(4, 8)), Mat.ghost(Color(0.5, 0.55, 0.65), 0.08), false)
		_fog.append(bank)
	for i in 6:
		var puff := Build.box(self, Vector3(28.4, 4.4 + i * 0.8, 0), Vector3.ONE * 0.6, Mat.ghost(Color(0.3, 0.3, 0.33), 0.25), false)
		_smoke.append(puff)

	camera = Camera3D.new()
	camera.fov = 58.0
	_cam_base = Vector3(40.5, 2.0, 6.2)
	camera.position = _cam_base
	add_child(camera)
	camera.look_at(Vector3(27, 2.6, 0.5))
	camera.current = true


func _process(delta: float) -> void:
	_t += delta
	camera.position = _cam_base + Vector3(sin(_t * 0.13) * 0.5, sin(_t * 0.2) * 0.12, cos(_t * 0.11) * 0.4)
	camera.look_at(Vector3(27, 2.6, 0.5))
	for i in _fog.size():
		_fog[i].position.x += delta * (0.25 + i * 0.05)
		if _fog[i].position.x > 66.0:
			_fog[i].position.x = 4.0
	for i in _smoke.size():
		var puff: MeshInstance3D = _smoke[i]
		puff.position.y += delta * 0.9
		puff.position.x -= delta * 0.5
		puff.scale = Vector3.ONE * (0.6 + (puff.position.y - 4.4) * 0.35)
		if puff.position.y > 9.2:
			puff.position = Vector3(28.4, 4.4, 0)
	_lamp.light_energy = 4.2 if randf() > 0.03 else 0.6
