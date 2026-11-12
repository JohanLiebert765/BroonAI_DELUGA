class_name Location
extends Node3D
## Base class for explorable locations. Subclasses implement build() and place geometry
## and interactables with the helpers below. The train always sits on the X axis at z = 0
## (x from -34 to 30, floor 0.8 m above the ground); its doors face +Z and -Z.

const SCRIPTS := {
	"siding": "res://scripts/world/locations/siding.gd",
	"ravenwood": "res://scripts/world/locations/ravenwood.gd",
	"forest": "res://scripts/world/locations/dead_forest.gd",
	"village": "res://scripts/world/locations/empty_village.gd",
	"tunnel": "res://scripts/world/locations/last_tunnel.gd",
}

var env := {}
var enemy_spawns: Array = []       # [{"type": String, "pos": Vector3, "points": Array[Vector3]}]
var apparition_points: Array = []  # where the Passenger may appear
var signal_points: Array = []      # where the Signal may manifest
var bonus_points: Array = []       # where random events may place extra supplies


static func create(loc: String) -> Location:
	return load(SCRIPTS[loc]).new()


func _ready() -> void:
	GameState.flag_changed.connect(_flag_changed)
	build()
	for key in GameState.data.get("flags", {}):
		on_flag(key, GameState.data["flags"][key])


func _flag_changed(key: String, value) -> void:
	on_flag(key, value)


## Override: create the level.
func build() -> void:
	pass


## Override: react to replicated flag changes (lights, gates, signals). Also called for
## every existing flag right after build(), so it must be idempotent.
func on_flag(_key: String, _value) -> void:
	pass


# --- geometry helpers ------------------------------------------------------

func ground(half_x: float, half_z: float, texture := "dirt", tint := Color(0.55, 0.55, 0.55)) -> void:
	Build.box(self, Vector3(0, -0.5, 0), Vector3(half_x * 2.0, 1.0, half_z * 2.0), Mat.tex(texture, tint, 0.25))


## Track bed, sleepers and rails along X.
func rails(x0: float, x1: float, z := 0.0) -> void:
	var length := x1 - x0
	var mid := (x0 + x1) * 0.5
	Build.box(self, Vector3(mid, 0.03, z), Vector3(length, 0.06, 3.2), Mat.tex("gravel", Color(0.6, 0.6, 0.62), 0.5), false)
	var steel := Mat.tex("metal", Color(0.5, 0.5, 0.55))
	Build.box(self, Vector3(mid, 0.12, z - 0.75), Vector3(length, 0.12, 0.08), steel, false)
	Build.box(self, Vector3(mid, 0.12, z + 0.75), Vector3(length, 0.12, 0.08), steel, false)
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	var sleeper := BoxMesh.new()
	sleeper.size = Vector3(0.24, 0.1, 2.3)
	mm.mesh = sleeper
	var n := int(length / 0.9)
	mm.instance_count = n
	for i in n:
		mm.set_instance_transform(i, Transform3D(Basis(), Vector3(x0 + 0.45 + i * 0.9, 0.07, z)))
	var mmi := MultiMeshInstance3D.new()
	mmi.multimesh = mm
	mmi.material_override = Mat.tex("wood", Color(0.38, 0.32, 0.28))
	add_child(mmi)


## Rectangular building. `origin` is the min-x/min-z corner at ground level, `size` is
## (width along X, wall height, depth along Z). `openings` maps a side ("n" = min z,
## "s" = max z, "w" = min x, "e" = max x) to a list of [u0, u1, v0, v1] holes, with u
## measured from the min corner of that wall.
func building(origin: Vector3, size: Vector3, wall: Material, roof: Material, openings: Dictionary = {}, floor_mat: Material = null, gable := false) -> void:
	var t := 0.2
	Build.wall(self, origin + Vector3(0, 0, t * 0.5), "x", size.x, size.y, t, wall, openings.get("n", []))
	Build.wall(self, origin + Vector3(0, 0, size.z - t * 0.5), "x", size.x, size.y, t, wall, openings.get("s", []))
	Build.wall(self, origin + Vector3(t * 0.5, 0, 0), "z", size.z, size.y, t, wall, openings.get("w", []))
	Build.wall(self, origin + Vector3(size.x - t * 0.5, 0, 0), "z", size.z, size.y, t, wall, openings.get("e", []))
	var center := origin + Vector3(size.x * 0.5, 0, size.z * 0.5)
	if floor_mat:
		Build.box(self, center + Vector3(0, 0.02, 0), Vector3(size.x, 0.04, size.z), floor_mat, false)
	Build.box(self, center + Vector3(0, size.y + 0.1, 0), Vector3(size.x + 0.6, 0.2, size.z + 0.6), roof)
	if gable:
		for i in 3:
			var f := 1.0 - (i + 1) * 0.28
			Build.box(self, center + Vector3(0, size.y + 0.35 + i * 0.3, 0), Vector3(size.x + 0.6, 0.3, (size.z + 0.6) * f), roof, false)


func fence(from: Vector3, to: Vector3, height := 1.1) -> void:
	var wood := Mat.tex("wood", Color(0.4, 0.35, 0.32))
	var length := from.distance_to(to)
	var mid := (from + to) * 0.5
	var yaw := rad_to_deg(atan2(-(to.z - from.z), to.x - from.x))
	Build.box(self, mid + Vector3(0, height * 0.75, 0), Vector3(length, 0.1, 0.06), wood, false, Vector3(0, yaw, 0))
	Build.box(self, mid + Vector3(0, height * 0.4, 0), Vector3(length, 0.1, 0.06), wood, false, Vector3(0, yaw, 0))
	Build.box(self, mid + Vector3(0, height * 0.5, 0), Vector3(length, height, 0.12), Mat.flat(Color(0, 0, 0, 0)), true, Vector3(0, yaw, 0)).visible = false
	var posts := int(length / 2.0) + 1
	for i in posts + 1:
		Build.box(self, from.lerp(to, float(i) / float(posts)) + Vector3(0, height * 0.5, 0), Vector3(0.1, height, 0.1), wood, false)


# --- interactable helpers ---------------------------------------------------

func _apply(node: Object, opts: Dictionary) -> void:
	for k in opts:
		node.set(k, opts[k])


func pickup(id: String, item: String, pos: Vector3, n := 1, quest_flag := "", count_flag := "") -> Pickup:
	var p := Pickup.new()
	p.id = id
	p.item = item
	p.count = n
	p.quest_flag = quest_flag
	p.count_flag = count_flag
	p.position = pos
	p.rotation.y = pos.x * 1.7 + pos.z
	add_child(p)
	return p


## Door hinged at `pos`; at yaw 0 the leaf extends toward +X. opts: any Door property.
func door(id: String, pos: Vector3, yaw_deg := 0.0, opts: Dictionary = {}) -> Door:
	var d := Door.new()
	d.id = id
	d.position = pos
	d.rotation_degrees.y = yaw_deg
	_apply(d, opts)
	add_child(d)
	return d


## loot: [[item_id, count], ...]. style: crate, cabinet, desk, barrel, locker.
func container(id: String, pos: Vector3, yaw_deg: float, loot: Array, style := "crate", opts: Dictionary = {}) -> LootContainer:
	var c := LootContainer.new()
	c.id = id
	c.loot = loot
	c.style = style
	c.position = pos
	c.rotation_degrees.y = yaw_deg
	_apply(c, opts)
	add_child(c)
	return c


func document(id: String, doc: String, pos: Vector3, yaw_deg := 0.0) -> DocumentItem:
	var d := DocumentItem.new()
	d.id = id
	d.doc = doc
	d.position = pos
	d.rotation_degrees.y = yaw_deg
	add_child(d)
	return d


## Invisible-bodied device; add visuals as children of the returned node or next to it.
func mechanism(id: String, prompt: String, pos: Vector3, shape_size: Vector3, opts: Dictionary = {}) -> Mechanism:
	var m := Mechanism.new()
	m.id = id
	m.prompt = prompt
	m.position = pos
	m.add_shape(shape_size)
	_apply(m, opts)
	add_child(m)
	return m


func trigger(flag: String, pos: Vector3, half: Vector3, message := "") -> TriggerZone:
	var t := TriggerZone.new()
	t.flag = flag
	t.half = half
	t.message = message
	t.position = pos
	add_child(t)
	return t


## Door in the track-facing ("n") wall of a building() whose opening starts at u0.
func ndoor(id: String, origin: Vector3, u0: float, opts: Dictionary = {}) -> Door:
	return door(id, Vector3(origin.x + u0, 0, origin.z + 0.1), 0.0, opts)


## Glowing window pane with a dim light behind it.
func lit_window(pos: Vector3, size: Vector3, color := Color(1.0, 0.72, 0.4), energy := 0.5) -> void:
	Build.box(self, pos, size, Mat.glow(color, 1.2), false)
	Build.light(self, pos + Vector3(0, 0, -1.2), color, energy, 6.0)


## Scatter trees deterministically, skipping the track corridor and the `clear` circles
## ([Vector3 centre, radius]).
func scatter_trees(count: int, half_x: float, half_z: float, clear: Array, dead_every := 3, seed_value := 7) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var placed := 0
	var tries := 0
	while placed < count and tries < count * 6:
		tries += 1
		var p := Vector3(rng.randf_range(-half_x, half_x), 0, rng.randf_range(-half_z, half_z))
		if absf(p.z) < 7.0:
			continue
		var blocked := false
		for c in clear:
			if p.distance_to(c[0]) < float(c[1]):
				blocked = true
				break
		if blocked:
			continue
		Build.tree(self, p, rng.randf_range(6, 11), dead_every > 0 and placed % dead_every != 0)
		placed += 1
