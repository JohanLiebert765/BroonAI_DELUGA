class_name TravelScenery
extends Node3D
## What is seen from the train while it travels: the train itself never moves, the night
## scrolls past it. Speed follows the replicated throttle / halted state.

var env := {
	"sky": Color(0.012, 0.015, 0.028), "fog_color": Color(0.05, 0.06, 0.09), "fog_density": 0.045,
	"ambient": Color(0.3, 0.36, 0.5), "ambient_energy": 0.35, "moon": 0.1,
	"ambient_sound": "wind_loop", "ambient_db": -10.0,
}
var enemy_spawns: Array = []
var apparition_points: Array = []
var signal_points: Array = []
var bonus_points: Array = []
var _scroll: Array = []
var _speed := 0.0


func _ready() -> void:
	Build.box(self, Vector3(0, -0.5, 0), Vector3(320, 1.0, 160), Mat.tex("dirt", Color(0.4, 0.42, 0.45), 0.25))
	Build.box(self, Vector3(0, 0.03, 0), Vector3(320, 0.06, 3.2), Mat.tex("gravel", Color(0.6, 0.6, 0.62), 0.5), false)
	var steel := Mat.tex("metal", Color(0.5, 0.5, 0.55))
	Build.box(self, Vector3(0, 0.12, -0.75), Vector3(320, 0.12, 0.08), steel, false)
	Build.box(self, Vector3(0, 0.12, 0.75), Vector3(320, 0.12, 0.08), steel, false)
	var rng := RandomNumberGenerator.new()
	rng.seed = 1961
	var trunk := Mat.tex("bark", Color(0.5, 0.45, 0.42))
	var leaves := Mat.tex("leaves", Color(0.5, 0.58, 0.58))
	for i in 70:
		var holder := Node3D.new()
		var side := -1.0 if i % 2 == 0 else 1.0
		holder.position = Vector3(rng.randf_range(-120, 120), 0, side * rng.randf_range(7, 46))
		add_child(holder)
		var h := rng.randf_range(5.0, 9.0)
		if i % 9 == 0:
			# telegraph pole close to the line
			holder.position.z = side * 4.2
			Build.cyl(holder, Vector3(0, 3.0, 0), 0.09, 6.0, trunk)
			Build.box(holder, Vector3(0, 5.4, 0), Vector3(0.1, 0.1, 1.6), trunk, false)
		else:
			Build.cyl(holder, Vector3(0, h * 0.5, 0), 0.2, h, trunk, false, Vector3.ZERO, 5, 0.08)
			Build.cyl(holder, Vector3(0, h * 0.6, 0), 1.6, h * 0.55, leaves, false, Vector3.ZERO, 6, 0.0)
		_scroll.append(holder)


func _process(delta: float) -> void:
	var d: Dictionary = GameState.data
	var target := 0.0
	if d.get("traveling", false) and not d.get("halted", false):
		target = 17.0 if int(d.get("throttle", 1)) >= 2 else 10.0
	_speed = move_toward(_speed, target, delta * 4.0)
	for n in _scroll:
		n.position.x -= _speed * delta
		if n.position.x < -120.0:
			n.position.x += 240.0
