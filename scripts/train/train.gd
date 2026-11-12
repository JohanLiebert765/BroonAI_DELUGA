class_name Train
extends Node3D
## The Vesper: locomotive, passenger, medical, workshop and cargo cars, built procedurally.
## Geometry and interactables live here; the simulation is in TrainSystem (host).

const FLOOR := 0.8
const HALF_W := 1.45
const HEIGHT := 2.4
const CARS := {"loco": [18.0, 22.4], "passenger": [5.0, 17.0], "medical": [-8.0, 4.0], "workshop": [-21.0, -9.0], "cargo": [-34.0, -22.0]}
const EXT_DOORS := ["train_ext_cab", "train_ext_pass_a", "train_ext_pass_b", "train_ext_med", "train_ext_cargo"]

var system: TrainSystem
var _lamps: Array = []          # {"light", "mesh", "primary"}
var _needles := {}
var _headlamp: SpotLight3D
var _fire_light: OmniLight3D
var _lever_arm: Node3D
var _steps: Array = []
var _engine_snd: AudioStreamPlayer3D
var _wheel_snd: AudioStreamPlayer3D
var _flicker := 0.0
var _wood: Material
var _metal: Material


func _ready() -> void:
	_wood = Mat.tex("planks", Color(0.5, 0.42, 0.36))
	_metal = Mat.tex("metal", Color(0.42, 0.44, 0.48))
	_build_locomotive()
	_build_passenger()
	_build_medical()
	_build_workshop()
	_build_cargo()
	for x in [17.0, 4.0, -9.0, -22.0]:
		_gangway(x)
	_engine_snd = Audio.loop_on(self, "engine_loop", -6.0, 40.0, "SFX", false)
	_engine_snd.position = Vector3(24, 2, 0)
	_wheel_snd = Audio.loop_on(self, "wheels_loop", -10.0, 30.0, "SFX", false)
	_wheel_snd.position = Vector3(0, 0.5, 0)
	GameState.train_changed.connect(_refresh)
	GameState.fx.connect(_on_fx)


## Called by World once the TrainSystem exists: wires the devices to the host logic.
func bind(sys: TrainSystem) -> void:
	system = sys
	_devices()


func is_inside(pos: Vector3) -> bool:
	return pos.x > -34.3 and pos.x < 22.6 and absf(pos.z) < HALF_W + 0.1 and pos.y > FLOOR - 0.4 and pos.y < FLOOR + HEIGHT + 0.3


func car_center(car: String) -> Vector3:
	return Vector3((CARS[car][0] + CARS[car][1]) * 0.5, FLOOR, 0)


func set_travel_mode(traveling: bool) -> void:
	for s in _steps:
		s.visible = not traveling


# --- car shells -------------------------------------------------------------

func _shell(x0: float, x1: float, wall: Material, windows: bool, doors_pos: Array, doors_neg: Array, open_ends := [true, true], floor_mat: Material = null) -> void:
	var length := x1 - x0
	var mid := (x0 + x1) * 0.5
	Build.box(self, Vector3(mid, FLOOR - 0.1, 0), Vector3(length, 0.2, HALF_W * 2.0), floor_mat if floor_mat else _wood)
	Build.box(self, Vector3(mid, 0.42, 0), Vector3(length - 1.0, 0.36, 2.2), Mat.flat(Color(0.07, 0.07, 0.08)), false)
	for wx in [x0 + 1.6, x0 + 3.0, x1 - 3.0, x1 - 1.6]:
		for wz in [-1.0, 1.0]:
			Build.cyl(self, Vector3(wx, 0.42, wz), 0.42, 0.14, _metal, false, Vector3(90, 0, 0), 10)
	for side in [1.0, -1.0]:
		var doors: Array = doors_pos if side > 0 else doors_neg
		var openings := []
		for d in doors:
			openings.append([d["u"], d["u"] + d["w"], 0.0, 2.05])
		if windows:
			var u := 0.9
			while u + 1.0 < length - 0.6:
				var clear := true
				for d in doors:
					if u < d["u"] + d["w"] + 0.3 and u + 1.0 > d["u"] - 0.3:
						clear = false
				if clear:
					openings.append([u, u + 1.0, 1.0, 1.95])
					Build.box(self, Vector3(x0 + u + 0.5, FLOOR + 1.475, side * (HALF_W - 0.05)), Vector3(1.0, 0.95, 0.03), Mat.ghost(Color(0.5, 0.6, 0.7), 0.12))
				u += 1.6
		Build.wall(self, Vector3(x0, FLOOR, side * (HALF_W - 0.05)), "x", length, HEIGHT, 0.1, wall, openings)
		for d in doors:
			var hinge := Vector3(x0 + d["u"], FLOOR, side * (HALF_W - 0.05))
			var door := Door.new()
			door.id = d["id"]
			door.position = hinge
			door.size = Vector3(d["w"], 2.05, 0.07)
			door.open_angle = -100.0 * side
			door.lock_flag = "train_moving"
			door.material = Mat.tex("metal", Color(0.4, 0.2, 0.18))
			add_child(door)
			var xm: float = x0 + d["u"] + d["w"] * 0.5
			_steps.append(Build.ramp(self, Vector3(xm, 0.0, side * (HALF_W + 2.3)), Vector3(xm, FLOOR, side * (HALF_W + 0.05)), d["w"] + 0.3, _wood))
	var end_open := [[0.95, 1.95, 0.0, 2.05]]
	Build.wall(self, Vector3(x0 + 0.05, FLOOR, -HALF_W), "z", HALF_W * 2.0, HEIGHT, 0.1, wall, end_open if open_ends[0] else [])
	Build.wall(self, Vector3(x1 - 0.05, FLOOR, -HALF_W), "z", HALF_W * 2.0, HEIGHT, 0.1, wall, end_open if open_ends[1] else [])
	var roof := Mat.tex("metal", Color(0.2, 0.2, 0.23))
	Build.box(self, Vector3(mid, FLOOR + HEIGHT + 0.06, 0), Vector3(length + 0.1, 0.12, HALF_W * 2.0 + 0.2), roof)
	Build.box(self, Vector3(mid, FLOOR + HEIGHT + 0.2, 0), Vector3(length - 0.2, 0.16, HALF_W * 1.4), roof, false)


func _gangway(x: float) -> void:
	var dark := Mat.tex("fabric", Color(0.18, 0.18, 0.2))
	Build.box(self, Vector3(x + 0.5, FLOOR - 0.1, 0), Vector3(1.0, 0.2, 1.3), _metal)
	Build.box(self, Vector3(x + 0.5, FLOOR + 1.05, -0.6), Vector3(1.0, 2.1, 0.1), dark)
	Build.box(self, Vector3(x + 0.5, FLOOR + 1.05, 0.6), Vector3(1.0, 2.1, 0.1), dark)
	Build.box(self, Vector3(x + 0.5, FLOOR + 2.15, 0), Vector3(1.0, 0.1, 1.3), dark)
	var door := Door.new()
	door.id = "train_door_%d" % int(x)
	door.position = Vector3(x + 0.95, FLOOR, -0.5)
	door.rotation_degrees.y = -90.0
	door.size = Vector3(1.0, 2.05, 0.06)
	door.open_angle = -95.0
	add_child(door)


func _lamp(pos: Vector3, primary: bool) -> void:
	var mesh := Build.box(self, pos, Vector3(0.22, 0.1, 0.22), Mat.glow(Color(1.0, 0.8, 0.5), 2.0), false)
	var light := Build.light(self, pos - Vector3(0, 0.25, 0), Color(1.0, 0.78, 0.5), 1.1, 6.5)
	_lamps.append({"light": light, "mesh": mesh, "primary": primary})


func _car_lamps(car: String) -> void:
	var x0: float = CARS[car][0]
	var x1: float = CARS[car][1]
	_lamp(Vector3(lerpf(x0, x1, 0.28), FLOOR + HEIGHT - 0.08, 0), true)
	_lamp(Vector3(lerpf(x0, x1, 0.72), FLOOR + HEIGHT - 0.08, 0), false)


# --- individual cars --------------------------------------------------------

func _build_locomotive() -> void:
	var black := Mat.tex("metal", Color(0.16, 0.16, 0.18))
	_shell(18.0, 22.4, Mat.tex("metal", Color(0.22, 0.22, 0.25)), true, [{"u": 0.5, "w": 1.0, "id": "train_ext_cab"}], [], [true, false])
	_lamp(Vector3(20.2, FLOOR + HEIGHT - 0.08, 0), true)
	# Boiler, smokebox, chimney, dome, running gear.
	Build.cyl(self, Vector3(26.0, 2.1, 0), 1.15, 7.2, black, false, Vector3(0, 0, 90), 10)
	Build.box(self, Vector3(26.0, 1.6, 0), Vector3(7.4, 3.2, 2.5), black).visible = false
	Build.cyl(self, Vector3(29.75, 2.1, 0), 1.2, 0.3, Mat.tex("rust", Color(0.4, 0.38, 0.38)), false, Vector3(0, 0, 90), 10)
	Build.cyl(self, Vector3(28.4, 3.75, 0), 0.3, 1.1, black, false, Vector3.ZERO, 8, 0.42)
	Build.cyl(self, Vector3(25.6, 3.4, 0), 0.45, 0.6, Mat.tex("metal", Color(0.45, 0.36, 0.2)), false, Vector3.ZERO, 8, 0.3)
	Build.box(self, Vector3(26.0, 0.7, 0), Vector3(8.0, 0.4, 2.7), black, false)
	for wx in [23.6, 25.6, 27.6]:
		for wz in [-1.25, 1.25]:
			Build.cyl(self, Vector3(wx, 0.8, wz), 0.8, 0.16, Mat.tex("metal", Color(0.3, 0.12, 0.1)), false, Vector3(90, 0, 0), 12)
	Build.box(self, Vector3(25.6, 0.8, 1.38), Vector3(4.4, 0.1, 0.08), _metal, false)
	Build.box(self, Vector3(25.6, 0.8, -1.38), Vector3(4.4, 0.1, 0.08), _metal, false)
	Build.box(self, Vector3(30.6, 0.5, 0), Vector3(1.4, 0.7, 2.6), black, true, Vector3(0, 0, 28))
	Build.box(self, Vector3(29.9, 2.75, 0), Vector3(0.3, 0.4, 0.4), Mat.glow(Color(1.0, 0.9, 0.6), 3.0), false)
	_headlamp = Build.spot(self, Vector3(30.1, 2.75, 0), Vector3(-8, -90, 0), Color(1.0, 0.9, 0.65), 5.0, 45.0, 28.0)
	# Backhead with firebox door.
	Build.box(self, Vector3(22.2, FLOOR + 1.2, 0), Vector3(0.3, 2.4, 2.4), black, false)
	Build.box(self, Vector3(22.03, FLOOR + 0.55, 0), Vector3(0.06, 0.6, 0.8), Mat.glow(Color(1.0, 0.4, 0.1), 1.6), false)
	_fire_light = Build.light(self, Vector3(21.6, FLOOR + 0.6, 0), Color(1.0, 0.45, 0.15), 0.9, 4.0)
	# Gauges: fuel, temperature, pressure.
	var i := 0
	for g in ["fuel", "temp", "pressure"]:
		var z := -0.7 + i * 0.7
		Build.cyl(self, Vector3(22.02, FLOOR + 1.55, z), 0.2, 0.05, Mat.flat(Color(0.82, 0.8, 0.7)), false, Vector3(0, 0, 90), 12)
		var pivot := Node3D.new()
		pivot.position = Vector3(21.98, FLOOR + 1.55, z)
		add_child(pivot)
		Build.box(pivot, Vector3(0, 0.08, 0), Vector3(0.012, 0.17, 0.02), Mat.flat(Color(0.7, 0.08, 0.05)), false)
		_needles[g] = pivot
		Build.label(self, Vector3(21.97, FLOOR + 1.87, z), ["FUEL", "TEMP", "PRESS"][i], 20, Color(0.85, 0.8, 0.6), Vector3(0, -90, 0))
		i += 1
	# Control stand with the lever.
	Build.box(self, Vector3(21.5, FLOOR + 0.45, 0.95), Vector3(0.5, 0.9, 0.4), _metal)
	_lever_arm = Node3D.new()
	_lever_arm.position = Vector3(21.5, FLOOR + 0.9, 0.95)
	add_child(_lever_arm)
	Build.box(_lever_arm, Vector3(0, 0.3, 0), Vector3(0.05, 0.6, 0.05), Mat.flat(Color(0.6, 0.1, 0.08)), false)
	Build.box(_lever_arm, Vector3(0, 0.62, 0), Vector3(0.1, 0.1, 0.1), Mat.flat(Color(0.1, 0.1, 0.1)), false)
	# Valve wheel, light switch, horn cord, route map, engine hatch.
	Build.cyl(self, Vector3(22.0, FLOOR + 1.0, -1.0), 0.2, 0.05, Mat.flat(Color(0.65, 0.1, 0.08)), false, Vector3(0, 0, 90), 10)
	Build.box(self, Vector3(20.6, FLOOR + 1.4, -1.33), Vector3(0.16, 0.24, 0.06), Mat.flat(Color(0.75, 0.72, 0.6)), false)
	Build.box(self, Vector3(21.2, FLOOR + 2.0, 0.55), Vector3(0.02, 0.7, 0.02), Mat.flat(Color(0.7, 0.6, 0.3)), false)
	Build.box(self, Vector3(21.2, FLOOR + 1.62, 0.55), Vector3(0.08, 0.08, 0.08), Mat.flat(Color(0.6, 0.1, 0.08)), false)
	Build.box(self, Vector3(19.3, FLOOR + 1.5, -1.36), Vector3(1.2, 0.8, 0.03), Mat.tex("paper", Color(0.9, 0.85, 0.7), 1.0), false)
	Build.label(self, Vector3(19.3, FLOOR + 2.0, -1.33), "ROUTE", 22, Color(0.8, 0.75, 0.55))
	Build.box(self, Vector3(21.7, FLOOR + 0.3, -0.95), Vector3(0.7, 0.6, 0.5), Mat.tex("rust", Color(0.5, 0.48, 0.48)))


func _build_passenger() -> void:
	_shell(5.0, 17.0, Mat.tex("planks", Color(0.36, 0.3, 0.3)), true,
		[{"u": 10.4, "w": 1.0, "id": "train_ext_pass_a"}], [{"u": 10.4, "w": 1.0, "id": "train_ext_pass_b"}])
	_car_lamps("passenger")
	var fabric := Mat.tex("fabric", Color(0.75, 0.3, 0.28), 1.0)
	var frame := Mat.tex("wood", Color(0.36, 0.28, 0.22))
	for i in 6:
		var x := 6.2 + i * 1.5
		for side in [-1.0, 1.0]:
			Build.box(self, Vector3(x, FLOOR + 0.23, side * 0.95), Vector3(0.55, 0.46, 0.9), fabric)
			Build.box(self, Vector3(x + 0.3, FLOOR + 0.6, side * 0.95), Vector3(0.1, 1.2, 0.9), frame)
	for side in [-1.0, 1.0]:
		Build.box(self, Vector3(10.0, FLOOR + 2.0, side * 1.15), Vector3(8.6, 0.05, 0.45), frame, false)
	for sc in [[6.5, 1.15, 0.5], [8.8, -1.15, 0.6], [12.4, 1.15, 0.45], [13.6, -1.15, 0.55]]:
		Build.box(self, Vector3(sc[0], FLOOR + 2.16, sc[1]), Vector3(sc[2] + 0.2, 0.26, 0.38), Mat.tex("fabric", Color(0.4, 0.3, 0.2), 2.0), false)
	Build.box(self, Vector3(6.9, FLOOR + 0.2, 0.25), Vector3(0.7, 0.4, 0.3), Mat.tex("fabric", Color(0.3, 0.22, 0.16), 2.0))


func _build_medical() -> void:
	_shell(-8.0, 4.0, Mat.tex("plaster", Color(0.6, 0.62, 0.6)), true, [{"u": 10.4, "w": 1.0, "id": "train_ext_med"}], [], [true, true], Mat.tex("tiles", Color(0.6, 0.62, 0.62), 1.0))
	_car_lamps("medical")
	var white := Mat.tex("fabric", Color(0.8, 0.8, 0.78), 1.0)
	for x in [-6.0, -3.2]:
		Build.box(self, Vector3(x, FLOOR + 0.3, -0.9), Vector3(2.0, 0.6, 0.85), _metal)
		Build.box(self, Vector3(x, FLOOR + 0.66, -0.9), Vector3(1.96, 0.14, 0.8), white, false)
		Build.box(self, Vector3(x - 0.8, FLOOR + 0.78, -0.9), Vector3(0.4, 0.1, 0.5), white, false)
	Build.box(self, Vector3(0.0, FLOOR + 0.45, -1.0), Vector3(1.6, 0.9, 0.6), Mat.tex("metal", Color(0.6, 0.62, 0.62)))
	Build.box(self, Vector3(0.3, FLOOR + 0.98, -1.0), Vector3(0.3, 0.16, 0.2), Mat.flat(Color(0.6, 0.12, 0.1)), false)
	Build.box(self, Vector3(-0.3, FLOOR + 1.0, -1.05), Vector3(0.08, 0.2, 0.08), Mat.flat(Color(0.5, 0.35, 0.2)), false)
	Build.box(self, Vector3(-5.0, FLOOR + 1.0, 1.18), Vector3(1.2, 2.0, 0.4), Mat.tex("metal", Color(0.7, 0.72, 0.7)))
	Build.box(self, Vector3(-5.0, FLOOR + 1.4, 0.97), Vector3(0.3, 0.1, 0.02), Mat.flat(Color(0.7, 0.1, 0.08)), false)
	Build.box(self, Vector3(-5.0, FLOOR + 1.4, 0.97), Vector3(0.1, 0.3, 0.02), Mat.flat(Color(0.7, 0.1, 0.08)), false)


func _build_workshop() -> void:
	_shell(-21.0, -9.0, Mat.tex("planks", Color(0.32, 0.28, 0.26)), false, [], [])
	_car_lamps("workshop")
	Build.box(self, Vector3(-15.0, FLOOR + 0.82, -1.0), Vector3(3.2, 0.1, 0.7), Mat.tex("wood", Color(0.5, 0.4, 0.3)))
	for x in [-16.4, -13.6]:
		Build.box(self, Vector3(x, FLOOR + 0.39, -1.0), Vector3(0.12, 0.78, 0.6), _wood)
	Build.box(self, Vector3(-15.0, FLOOR + 1.7, -1.34), Vector3(3.0, 1.0, 0.04), _wood, false)
	for t in 6:
		Build.box(self, Vector3(-16.2 + t * 0.48, FLOOR + 1.7, -1.3), Vector3(0.06, 0.5 + (t % 3) * 0.12, 0.03), _metal, false)
	Build.box(self, Vector3(-14.0, FLOOR + 0.98, -1.0), Vector3(0.5, 0.22, 0.3), Mat.flat(Color(0.55, 0.12, 0.1)), false)
	Build.box(self, Vector3(-16.0, FLOOR + 1.06, -1.05), Vector3(0.14, 0.36, 0.14), Mat.glow(Color(1.0, 0.75, 0.4), 1.2), false)
	Build.box(self, Vector3(-18.5, FLOOR + 1.0, 1.2), Vector3(2.4, 2.0, 0.4), _wood)
	for s in 3:
		for k in 4:
			Build.box(self, Vector3(-19.4 + k * 0.6, FLOOR + 0.5 + s * 0.6, 0.98), Vector3(0.3, 0.2, 0.1), Mat.tex("rust", Color(0.5 + k * 0.05, 0.5, 0.5)), false)
	Build.box(self, Vector3(-11.0, FLOOR + 1.3, 1.34), Vector3(0.7, 0.9, 0.12), Mat.tex("metal", Color(0.3, 0.33, 0.3)), false)
	Build.label(self, Vector3(-11.0, FLOOR + 1.9, 1.27), "FUSES", 20, Color(0.85, 0.8, 0.6), Vector3(0, 180, 0))
	Build.box(self, Vector3(-12.6, FLOOR + 0.45, 1.1), Vector3(1.0, 0.9, 0.5), Mat.tex("rust", Color(0.45, 0.42, 0.42)))
	Build.label(self, Vector3(-12.6, FLOOR + 1.1, 1.27), "RUNNING GEAR", 16, Color(0.85, 0.8, 0.6), Vector3(0, 180, 0))


func _build_cargo() -> void:
	_shell(-34.0, -22.0, Mat.tex("planks", Color(0.3, 0.2, 0.18)), false, [{"u": 5.4, "w": 1.3, "id": "train_ext_cargo"}], [], [false, true])
	_car_lamps("cargo")
	for c in [[-33.2, -0.9, 0.9], [-33.2, 0.2, 0.8], [-32.1, -0.95, 0.7], [-25.0, -1.0, 0.8], [-23.9, -1.0, 0.6]]:
		Build.box(self, Vector3(c[0], FLOOR + c[2] * 0.5, c[1]), Vector3(0.9, c[2], 0.8), _wood)
	Build.box(self, Vector3(-33.2, FLOOR + 1.2, -0.9), Vector3(0.7, 0.6, 0.7), _wood)
	Build.cyl(self, Vector3(-31.0, FLOOR + 0.5, 1.0), 0.36, 1.0, Mat.tex("rust", Color(0.55, 0.3, 0.25)), true)
	Build.cyl(self, Vector3(-30.2, FLOOR + 0.5, 1.05), 0.36, 1.0, Mat.tex("rust", Color(0.4, 0.4, 0.45)), true)
	Build.box(self, Vector3(-29.0, FLOOR + 0.9, -1.2), Vector3(2.6, 0.06, 0.4), _wood)
	Build.box(self, Vector3(-29.0, FLOOR + 0.45, -1.2), Vector3(2.5, 0.9, 0.06), _wood, false)


# --- interactables ----------------------------------------------------------

func _device(id: String, prompt: String, pos: Vector3, size: Vector3, fn: Callable) -> Mechanism:
	var m := Mechanism.new()
	m.id = id
	m.prompt = prompt
	m.once = false
	m.custom = fn
	m.position = pos
	m.add_shape(size)
	add_child(m)
	return m


func _station(id: String, prompt: String, pos: Vector3, size: Vector3, ui: String, station := "") -> UiStation:
	var s := UiStation.new()
	s.id = id
	s.prompt = prompt
	s.ui = ui
	s.station = station
	s.position = pos
	s.add_shape(size)
	add_child(s)
	return s


func _pickup(id: String, item: String, pos: Vector3, quest_flag := "") -> void:
	var p := Pickup.new()
	p.id = id
	p.item = item
	p.quest_flag = quest_flag
	p.position = pos
	p.rotation.y = pos.x
	add_child(p)


func _devices() -> void:
	# Cab.
	_device("train_firebox", "Feed the firebox", Vector3(22.0, FLOOR + 0.55, 0), Vector3(0.3, 0.7, 0.9), system.use_firebox)
	_device("train_lever", "Control lever", Vector3(21.5, FLOOR + 1.2, 0.95), Vector3(0.4, 0.8, 0.4), system.use_lever)
	_device("train_valve", "Vent steam (cools the boiler)", Vector3(21.95, FLOOR + 1.0, -1.0), Vector3(0.25, 0.5, 0.5), system.use_valve)
	_device("train_lights", "Carriage lights switch", Vector3(20.6, FLOOR + 1.4, -1.28), Vector3(0.3, 0.4, 0.2), system.use_lights)
	_device("train_horn", "Sound the whistle", Vector3(21.2, FLOOR + 1.7, 0.55), Vector3(0.25, 0.6, 0.25), system.use_horn)
	_device("train_engine", "Service the engine", Vector3(21.7, FLOOR + 0.3, -0.95), Vector3(0.8, 0.7, 0.6), system.use_engine)
	_station("train_panel", "Read the instruments", Vector3(21.95, FLOOR + 1.6, 0), Vector3(0.2, 0.6, 2.0), "train_panel")
	_station("train_map", "Study the route map", Vector3(19.3, FLOOR + 1.5, -1.3), Vector3(1.3, 0.9, 0.2), "route_map")
	# Passenger car: the first documents.
	var note := DocumentItem.new()
	note.id = "train_doc_dispatch"
	note.doc = "d_dispatch"
	note.position = Vector3(9.2, FLOOR + 0.47, 0.95)
	add_child(note)
	var ticket := DocumentItem.new()
	ticket.id = "train_doc_ticket"
	ticket.doc = "d_ticket"
	ticket.position = Vector3(13.7, FLOOR + 0.47, -0.95)
	add_child(ticket)
	# Medical car.
	_device("train_bed", "Rest on the cot", Vector3(-4.6, FLOOR + 0.7, -0.9), Vector3(4.6, 0.5, 0.9), system.use_bed)
	_station("train_medstation", "Medical station (craft)", Vector3(0.0, FLOOR + 0.9, -1.0), Vector3(1.6, 0.6, 0.6), "craft", "medical")
	_station("train_stash_medical", "Medicine cabinet (shared)", Vector3(-5.0, FLOOR + 1.0, 1.1), Vector3(1.2, 2.0, 0.5), "stash", "medical")
	# Workshop car.
	_station("train_workbench", "Workbench (craft)", Vector3(-15.0, FLOOR + 1.0, -1.0), Vector3(3.2, 0.7, 0.7), "craft", "workbench")
	_device("train_fusebox", "Service the fuse box", Vector3(-11.0, FLOOR + 1.3, 1.25), Vector3(0.8, 1.0, 0.3), system.use_fusebox)
	_device("train_gear", "Service the running gear", Vector3(-12.6, FLOOR + 0.5, 1.05), Vector3(1.0, 1.0, 0.6), system.use_gear)
	var toolbox := LootContainer.new()
	toolbox.id = "train_toolbox"
	toolbox.loot = [["hammer", 1], ["bolts", 2]]
	toolbox.position = Vector3(-19.6, FLOOR, -0.95)
	toolbox.rotation_degrees.y = 90.0
	add_child(toolbox)
	# Cargo car.
	_station("train_stash_cargo", "Supply crate (shared)", Vector3(-25.0, FLOOR + 0.5, -1.0), Vector3(0.95, 0.9, 0.85), "stash", "cargo")
	for i in 4:
		_pickup("train_flash_%d" % i, "flashlight", Vector3(-30.0 + i * 0.55, FLOOR + 0.94, -1.2), "s_flash")
	_pickup("train_fuel_0", "fuel", Vector3(-26.4, FLOOR + 0.02, -1.0))
	_pickup("train_map_item", "map", Vector3(-28.0, FLOOR + 0.94, -1.2))


# --- live visuals -------------------------------------------------------------

func _on_fx(effect: String, _args: Dictionary) -> void:
	if effect == "lights_flicker":
		_flicker = 2.5


func _refresh() -> void:
	var d: Dictionary = GameState.data
	if d.is_empty():
		return
	var t: Dictionary = d["train"]
	_needles["fuel"].rotation.x = lerpf(-2.2, 2.2, clampf(t["fuel"] / 100.0, 0, 1))
	_needles["temp"].rotation.x = lerpf(-2.2, 2.2, clampf((t["temp"] - 20.0) / 100.0, 0, 1))
	_needles["pressure"].rotation.x = lerpf(-2.2, 2.2, clampf(TrainSystem.pressure(d) / 100.0, 0, 1))
	var moving: bool = d["traveling"] and not d["halted"]
	_lever_arm.rotation.z = lerpf(_lever_arm.rotation.z, (-0.5 if int(d["throttle"]) >= 2 else -0.25) if moving else 0.4, 0.5)
	_fire_light.light_energy = 1.0 + 3.0 * clampf(t["fuel"] / 40.0, 0, 1)
	if moving != _engine_snd.playing and _engine_snd.stream:
		if moving:
			_engine_snd.play()
			_wheel_snd.play()
		else:
			_engine_snd.stop()
			_wheel_snd.stop()
	_engine_snd.pitch_scale = 1.25 if int(d["throttle"]) >= 2 else 1.0
	_wheel_snd.pitch_scale = _engine_snd.pitch_scale


func _process(delta: float) -> void:
	var d: Dictionary = GameState.data
	if d.is_empty():
		return
	var t: Dictionary = d["train"]
	_flicker = maxf(0.0, _flicker - delta)
	var power: float = t["electric"]
	var on: bool = t["lights"] and power >= 10.0
	for lamp in _lamps:
		var lit: bool = on and (lamp["primary"] or power >= 30.0)
		if lit and (power < 45.0 or _flicker > 0.0):
			lit = randf() > (0.5 if _flicker > 0.0 else 0.04)
		lamp["light"].visible = lit
		lamp["mesh"].visible = lit
	_headlamp.visible = on
