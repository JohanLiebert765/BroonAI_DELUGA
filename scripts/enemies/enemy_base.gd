class_name Enemy
extends Node3D
## Shared base for the four entities. The host runs the state machine (_think) and moves the
## node; position, facing, state and opacity replicate through a MultiplayerSynchronizer and
## every peer animates / plays sounds locally from that state.

var config := {}

# replicated
var net_pos := Vector3.ZERO
var net_yaw := 0.0
var state := 0
var alpha := 1.0

var threat := false          # true while actively hunting (drives chase music on clients)
var _path := PackedVector3Array()
var _path_i := 0
var _path_target := Vector3.INF
var _repath := 0.0
var _shown_state := -1
var _step_accum := 0.0
var _prev_pos := Vector3.ZERO
var _anim_t := 0.0


func _init() -> void:
	var cfg := SceneReplicationConfig.new()
	for prop in ["net_pos", "net_yaw", "state", "alpha"]:
		var path := NodePath(".:" + prop)
		cfg.add_property(path)
		cfg.property_set_spawn(path, true)
		cfg.property_set_replication_mode(path, SceneReplicationConfig.REPLICATION_MODE_ALWAYS if prop.begins_with("net_") else SceneReplicationConfig.REPLICATION_MODE_ON_CHANGE)
	var sync := MultiplayerSynchronizer.new()
	sync.name = "Sync"
	sync.replication_config = cfg
	sync.replication_interval = 0.066
	sync.delta_interval = 0.066
	add_child(sync)


func _ready() -> void:
	net_pos = position
	net_yaw = rotation.y
	_prev_pos = position
	_build()


func _physics_process(delta: float) -> void:
	if GameState.is_host():
		if not GameState.data.is_empty():
			_think(delta)
		net_pos = position
		net_yaw = rotation.y
	else:
		position = net_pos if position.distance_to(net_pos) > 5.0 else position.lerp(net_pos, minf(1.0, delta * 12.0))
		rotation.y = lerp_angle(rotation.y, net_yaw, minf(1.0, delta * 10.0))
	var moved := Vector2(position.x - _prev_pos.x, position.z - _prev_pos.z).length()
	_prev_pos = position
	_anim_t += delta
	if state != _shown_state:
		_on_state(_shown_state, state)
		_shown_state = state
	_animate(delta, moved / maxf(delta, 0.001))


# --- overridables -----------------------------------------------------------

func _build() -> void:
	pass


func _think(_delta: float) -> void:
	pass


func _animate(_delta: float, _speed: float) -> void:
	pass


func _on_state(_from: int, _to: int) -> void:
	pass


func hear(_pos: Vector3, _radius: float) -> void:
	pass


func on_whistle() -> void:
	pass


# --- host helpers -------------------------------------------------------------

func world() -> World:
	return GameState.scene as World


## Players that can be targeted (by default not those sheltering on the train).
func targets(include_train := false) -> Array:
	var out := []
	var w := world()
	if w == null:
		return out
	for p in w.player_nodes():
		if include_train or not w.is_on_train(ppos(p)):
			out.append(p)
	return out


func ppos(p: Player) -> Vector3:
	return p.position if p.is_local() else p.net_pos


func nearest(max_dist := 1e9, include_train := false) -> Player:
	var best: Player = null
	var best_d := max_dist
	for p in targets(include_train):
		var d := position.distance_to(ppos(p))
		if d < best_d:
			best_d = d
			best = p
	return best


func has_los(point: Vector3) -> bool:
	var q := PhysicsRayQueryParameters3D.create(global_position + Vector3(0, 1.6, 0), point, 65)
	return get_world_3d().direct_space_state.intersect_ray(q).is_empty()


func sees(p: Player, view_range: float, fov_deg: float) -> bool:
	var to := ppos(p) + Vector3(0, 1.2, 0) - (position + Vector3(0, 1.6, 0))
	if to.length() > view_range:
		return false
	var fwd := -global_basis.z
	var flat := Vector3(to.x, 0, to.z).normalized()
	if fwd.dot(flat) < cos(deg_to_rad(fov_deg * 0.5)):
		return false
	return has_los(ppos(p) + Vector3(0, 1.2, 0))


## True when a player's lit flashlight is pointed at this entity.
func lit_by(p: Player, max_dist := 20.0) -> bool:
	if not p.flash_on:
		return false
	var to := position + Vector3(0, 1.2, 0) - (ppos(p) + Vector3(0, 1.5, 0))
	if to.length() > max_dist:
		return false
	var yaw := p.rotation.y if p.is_local() else p.net_yaw
	var look := Vector3(-sin(yaw) * cos(p.pitch), sin(p.pitch), -cos(yaw) * cos(p.pitch))
	return look.dot(to.normalized()) > 0.9 and has_los(ppos(p) + Vector3(0, 1.5, 0))


func face(point: Vector3, delta := 1.0, rate := 8.0) -> void:
	var to := point - position
	if Vector2(to.x, to.z).length() < 0.05:
		return
	rotation.y = lerp_angle(rotation.y, atan2(-to.x, -to.z), minf(1.0, delta * rate))


## Walks toward target along the navmesh (straight line if no path). Returns true on arrival.
func walk_to(target: Vector3, speed: float, delta: float, arrive := 0.8) -> bool:
	var flat_dist := Vector2(target.x - position.x, target.z - position.z).length()
	if flat_dist <= arrive:
		return true
	_repath -= delta
	if _repath <= 0.0 or _path_target.distance_to(target) > 1.5:
		_repath = 0.7
		_path_target = target
		_path = world().nav_path(position, target)
		_path_i = 1
	var next := target
	if _path.size() > 1 and _path_i < _path.size():
		next = _path[_path_i]
		if Vector2(next.x - position.x, next.z - position.z).length() < 0.4:
			_path_i += 1
			return false
	var dir := Vector3(next.x - position.x, 0, next.z - position.z)
	if dir.length() < 0.01:
		return false
	position += dir.normalized() * minf(speed * delta, dir.length())
	position.y = move_toward(position.y, maxf(0.0, next.y - 0.25), 3.0 * delta)
	face(next, delta)
	return false


func strike(p: Player, damage: float) -> void:
	GameState.hurt(p.peer_id, damage)
	GameState.fx_to(p.peer_id, "glitch", {"power": 0.6})
