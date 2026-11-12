class_name Build

## Scene lights are authored in "lamp units"; this converts them to renderer energy.
const LIGHT_SCALE := 6.0
## Low-poly geometry helpers. Everything in the game world is assembled from these primitives.


static func box(parent: Node3D, pos: Vector3, size: Vector3, mat: Material, collide := true, rot_deg := Vector3.ZERO) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = size
	mi.mesh = mesh
	mi.material_override = mat
	mi.position = pos
	mi.rotation_degrees = rot_deg
	parent.add_child(mi)
	if collide:
		var body := StaticBody3D.new()
		var cs := CollisionShape3D.new()
		var shape := BoxShape3D.new()
		shape.size = size
		cs.shape = shape
		body.add_child(cs)
		mi.add_child(body)
	return mi


static func cyl(parent: Node3D, pos: Vector3, radius: float, height: float, mat: Material, collide := false, rot_deg := Vector3.ZERO, sides := 8, top_radius := -1.0) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var mesh := CylinderMesh.new()
	mesh.bottom_radius = radius
	mesh.top_radius = radius if top_radius < 0.0 else top_radius
	mesh.height = height
	mesh.radial_segments = sides
	mesh.rings = 1
	mi.mesh = mesh
	mi.material_override = mat
	mi.position = pos
	mi.rotation_degrees = rot_deg
	parent.add_child(mi)
	if collide:
		var body := StaticBody3D.new()
		var cs := CollisionShape3D.new()
		var shape := CylinderShape3D.new()
		shape.radius = radius
		shape.height = height
		cs.shape = shape
		body.add_child(cs)
		mi.add_child(body)
	return mi


## Wall along +X ("x") or +Z ("z") starting at origin (base, centre of thickness), with
## rectangular openings [u0, u1, v0, v1] (u along the wall, v up from the base).
static func wall(parent: Node3D, origin: Vector3, axis: String, length: float, height: float, thick: float, mat: Material, openings: Array = []) -> void:
	var dir := Vector3.RIGHT if axis == "x" else Vector3.BACK
	var sorted := openings.duplicate()
	sorted.sort_custom(func(a, b): return a[0] < b[0])
	var cursor := 0.0
	for op in sorted:
		if op[0] > cursor:
			_wall_piece(parent, origin, dir, axis, cursor, op[0], 0.0, height, thick, mat)
		if op[2] > 0.0:
			_wall_piece(parent, origin, dir, axis, op[0], op[1], 0.0, op[2], thick, mat)
		if op[3] < height:
			_wall_piece(parent, origin, dir, axis, op[0], op[1], op[3], height, thick, mat)
		cursor = op[1]
	if cursor < length:
		_wall_piece(parent, origin, dir, axis, cursor, length, 0.0, height, thick, mat)


static func _wall_piece(parent: Node3D, origin: Vector3, dir: Vector3, axis: String, u0: float, u1: float, v0: float, v1: float, thick: float, mat: Material) -> void:
	if u1 - u0 < 0.01 or v1 - v0 < 0.01:
		return
	var center := origin + dir * ((u0 + u1) * 0.5) + Vector3.UP * ((v0 + v1) * 0.5)
	var size := Vector3(u1 - u0, v1 - v0, thick) if axis == "x" else Vector3(thick, v1 - v0, u1 - u0)
	box(parent, center, size, mat)


## Walkable ramp from `low` (ground point) up to `high`, `width` wide.
static func ramp(parent: Node3D, low: Vector3, high: Vector3, width: float, mat: Material) -> MeshInstance3D:
	var mid := (low + high) * 0.5
	var length := low.distance_to(high)
	var mi := box(parent, mid, Vector3(width, 0.12, length), mat)
	mi.look_at_from_position(mid, high, Vector3.UP)
	mi.position -= mi.basis.y * 0.06
	return mi


static func light(parent: Node3D, pos: Vector3, color: Color, energy := 1.0, radius := 8.0, shadows := false) -> OmniLight3D:
	var l := OmniLight3D.new()
	l.light_color = color
	l.light_energy = energy * LIGHT_SCALE
	l.omni_range = radius
	l.omni_attenuation = 1.4
	l.shadow_enabled = shadows
	l.position = pos
	parent.add_child(l)
	return l


static func spot(parent: Node3D, pos: Vector3, rot_deg: Vector3, color: Color, energy := 2.0, radius := 20.0, angle := 30.0) -> SpotLight3D:
	var l := SpotLight3D.new()
	l.light_color = color
	l.light_energy = energy * LIGHT_SCALE
	l.spot_range = radius
	l.spot_angle = angle
	l.position = pos
	l.rotation_degrees = rot_deg
	parent.add_child(l)
	return l


static func label(parent: Node3D, pos: Vector3, text: String, px := 48, color := Color(0.85, 0.82, 0.7), rot_deg := Vector3.ZERO) -> Label3D:
	var l := Label3D.new()
	l.text = text
	l.font_size = px
	l.pixel_size = 0.005
	l.modulate = color
	l.outline_size = 0
	l.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	l.position = pos
	l.rotation_degrees = rot_deg
	parent.add_child(l)
	return l


## Lamp post with a light; returns the OmniLight3D so callers can switch it.
static func lamp_post(parent: Node3D, pos: Vector3, color := Color(1.0, 0.75, 0.45), energy := 1.2, height := 3.6) -> OmniLight3D:
	cyl(parent, pos + Vector3(0, height * 0.5, 0), 0.06, height, Mat.tex("metal", Color(0.35, 0.35, 0.38)), true)
	box(parent, pos + Vector3(0, height + 0.12, 0), Vector3(0.3, 0.24, 0.3), Mat.glow(color, 1.5), false)
	return light(parent, pos + Vector3(0, height - 0.1, 0), color, energy, 9.0)


## Low-poly conifer: trunk + two cones. Collision on the trunk only.
static func tree(parent: Node3D, pos: Vector3, height := 7.0, dead := false) -> void:
	var trunk := Mat.tex("bark", Color(0.5, 0.45, 0.42))
	cyl(parent, pos + Vector3(0, height * 0.5, 0), 0.22, height, trunk, true, Vector3.ZERO, 5, 0.1)
	if dead:
		for i in 3:
			var y := height * (0.45 + 0.18 * i)
			box(parent, pos + Vector3(0, y, 0), Vector3(1.6 - i * 0.4, 0.07, 0.07), trunk, false, Vector3(0, 60.0 * i + pos.x * 37.0, 18))
		return
	var leaves := Mat.tex("leaves", Color(0.55, 0.62, 0.6))
	cyl(parent, pos + Vector3(0, height * 0.55, 0), 1.7, height * 0.5, leaves, false, Vector3.ZERO, 6, 0.3)
	cyl(parent, pos + Vector3(0, height * 0.85, 0), 1.1, height * 0.4, leaves, false, Vector3.ZERO, 6, 0.0)
