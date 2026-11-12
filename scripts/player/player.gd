class_name Player
extends CharacterBody3D
## First-person survivor. The owning peer simulates movement; position, facing, animation
## state and flashlight are replicated to everyone through a MultiplayerSynchronizer.

const WALK := 3.3
const SPRINT := 5.6
const CROUCH_SPEED := 1.6
const JUMP := 4.0
const GRAVITY := 12.0
const REACH := 3.0

var peer_id := 1
var char_idx := 0

# replicated
var net_pos := Vector3.ZERO
var net_yaw := 0.0
var pitch := 0.0
var anim := 0
var flash_on := false

# local only
var stamina := 100.0
var battery := 100.0
var controls := true
var hover: Interactable = null
var disrupted := 0.0      # seconds the flashlight is jammed (the Signal)
var _exhausted := false
var _step_dist := 0.0
var _last_pos := Vector3.ZERO
var _head: Node3D
var _camera: Camera3D
var _flash: SpotLight3D
var _model: CharacterModel
var _cfg: Dictionary


func _init() -> void:
	collision_layer = 2
	collision_mask = 65
	floor_max_angle = deg_to_rad(50.0)
	floor_snap_length = 0.35
	var cs := CollisionShape3D.new()
	var cap := CapsuleShape3D.new()
	cap.radius = 0.3
	cap.height = 1.75
	cs.shape = cap
	cs.position.y = 0.875
	add_child(cs)
	_head = Node3D.new()
	_head.position.y = 1.62
	add_child(_head)
	_camera = Camera3D.new()
	_camera.fov = 72.0
	_camera.near = 0.08
	_camera.far = 140.0
	_head.add_child(_camera)
	_flash = SpotLight3D.new()
	_flash.position = Vector3(0.18, -0.18, -0.1)
	_flash.light_color = Color(1.0, 0.93, 0.78)
	_flash.spot_attenuation = 0.8
	_flash.visible = false
	_head.add_child(_flash)
	var cfg := SceneReplicationConfig.new()
	for prop in ["net_pos", "net_yaw", "pitch", "anim", "flash_on"]:
		var path := NodePath(".:" + prop)
		cfg.add_property(path)
		cfg.property_set_spawn(path, true)
		var on_change: bool = prop == "anim" or prop == "flash_on"
		cfg.property_set_replication_mode(path, SceneReplicationConfig.REPLICATION_MODE_ON_CHANGE if on_change else SceneReplicationConfig.REPLICATION_MODE_ALWAYS)
	var sync := MultiplayerSynchronizer.new()
	sync.name = "Sync"
	sync.replication_config = cfg
	sync.replication_interval = 0.05
	sync.delta_interval = 0.05
	add_child(sync)


func _enter_tree() -> void:
	set_multiplayer_authority(peer_id)


func _ready() -> void:
	_cfg = ItemDB.character(char_idx)
	_model = CharacterModel.create(_cfg)
	add_child(_model)
	net_pos = position
	net_yaw = rotation.y
	_last_pos = position
	if is_local():
		_model.visible = false
		_camera.current = true
		GameState.local_player = self
		GameState.fx.connect(_on_fx)
		_flash.shadow_enabled = Settings.quality >= 2
	else:
		var tag := Build.label(self, Vector3(0, 2.05, 0), GameState.player_name(peer_id), 28, Color(0.8, 0.8, 0.75))
		tag.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		tag.no_depth_test = false


func is_local() -> bool:
	return peer_id == multiplayer.get_unique_id()


func has_flashlight() -> bool:
	return GameState.has_item(peer_id, "flashlight") or GameState.has_item(peer_id, "flashlight_plus")


func look(rel: Vector2) -> void:
	if not controls:
		return
	var k := 0.0022 * Settings.mouse_sensitivity
	rotation.y -= rel.x * k
	var dy := rel.y * k * (-1.0 if Settings.invert_y else 1.0)
	_head.rotation.x = clampf(_head.rotation.x - dy, -1.45, 1.45)


func toggle_flashlight() -> void:
	if not has_flashlight():
		GameState.message.emit(tr("You have no flashlight."), "warn")
		return
	if battery <= 0.0 and not flash_on:
		GameState.message.emit(tr("The flashlight is dead. Reload it with a battery."), "warn")
		return
	flash_on = not flash_on
	Audio.ui("switch", -8.0)


func try_interact() -> void:
	if hover == null or not is_instance_valid(hover) or not controls:
		return
	hover.local_interact(self)
	if hover.networked:
		GameState.scene.request_interact.rpc_id(1, hover.id)


func _on_fx(effect: String, _args: Dictionary) -> void:
	match effect:
		"reload":
			battery = 100.0
			Audio.ui("switch", -6.0)
			GameState.message.emit(tr("Flashlight reloaded."), "good")
		"toggle_flashlight":
			toggle_flashlight()


## Host -> owner: move this player (respawn in the medical car, boarding for departure).
@rpc("any_peer", "call_local", "reliable")
func teleport(pos: Vector3) -> void:
	var from := multiplayer.get_remote_sender_id()
	if from != 0 and from != 1:
		return
	position = pos
	velocity = Vector3.ZERO
	net_pos = pos
	_last_pos = pos


func _physics_process(delta: float) -> void:
	if not is_local():
		position = position.lerp(net_pos, minf(1.0, delta * 14.0)) if position.distance_to(net_pos) < 6.0 else net_pos
		rotation.y = lerp_angle(rotation.y, net_yaw, minf(1.0, delta * 14.0))
		_head.rotation.x = pitch
		_flash.visible = flash_on
	else:
		_simulate(delta)
	_model.anim = anim
	_model.pitch = pitch
	_head.position.y = lerpf(_head.position.y, 1.05 if anim >= 3 else 1.62, minf(1.0, delta * 10.0))
	_footsteps()


func _simulate(delta: float) -> void:
	var input := Vector2.ZERO
	var want_sprint := false
	var crouch := false
	var want_jump := false
	if controls:
		input = Input.get_vector("move_left", "move_right", "move_forward", "move_back")
		want_sprint = Input.is_action_pressed("sprint")
		crouch = Input.is_action_pressed("crouch")
		want_jump = Input.is_action_just_pressed("jump")
	var sprinting := want_sprint and input.y < -0.1 and not crouch and not _exhausted
	var speed := CROUCH_SPEED if crouch else (SPRINT if sprinting else WALK)
	var dir := (transform.basis * Vector3(input.x, 0, input.y)).normalized()
	var accel := 12.0 if is_on_floor() else 3.0
	velocity.x = move_toward(velocity.x, dir.x * speed, accel * delta * speed)
	velocity.z = move_toward(velocity.z, dir.z * speed, accel * delta * speed)
	if is_on_floor():
		if want_jump and stamina > 8.0 and not crouch:
			velocity.y = JUMP
			stamina -= 8.0
	else:
		velocity.y -= GRAVITY * delta
	move_and_slide()
	if position.y < -25.0:
		position = GameState.MEDICAL_SPAWN
		velocity = Vector3.ZERO

	var moving := Vector2(velocity.x, velocity.z).length() > 0.4
	if sprinting and moving:
		stamina = maxf(0.0, stamina - 16.0 * delta / float(_cfg["stamina"]))
		if stamina <= 0.0:
			_exhausted = true
	else:
		stamina = minf(100.0, stamina + (14.0 if moving else 22.0) * delta)
		if stamina > 25.0:
			_exhausted = false
	if crouch:
		anim = 4 if moving else 3
	elif moving:
		anim = 2 if sprinting else 1
	else:
		anim = 0

	var plus := GameState.has_item(peer_id, "flashlight_plus")
	if flash_on:
		battery = maxf(0.0, battery - delta * (100.0 / (420.0 if plus else 240.0)))
		if battery <= 0.0 or not has_flashlight():
			flash_on = false
	disrupted = maxf(0.0, disrupted - delta)
	var lit := flash_on
	if disrupted > 0.0:
		lit = flash_on and randf() < 0.15
	elif flash_on and battery < 12.0:
		lit = randf() > 0.08
	_flash.visible = lit
	_flash.spot_range = 27.0 if plus else 17.0
	_flash.spot_angle = 34.0 if plus else 26.0
	_flash.light_energy = 9.0 if plus else 6.0

	pitch = _head.rotation.x
	net_pos = position
	net_yaw = rotation.y
	_update_hover()


func _update_hover() -> void:
	hover = null
	if not controls:
		return
	var from := _camera.global_position
	var to := from - _camera.global_basis.z * REACH
	var q := PhysicsRayQueryParameters3D.create(from, to, 1 | 4 | 64)
	q.exclude = [get_rid()]
	var hit := get_world_3d().direct_space_state.intersect_ray(q)
	if hit.is_empty():
		return
	var n: Node = hit["collider"]
	while n != null and not (n is Interactable):
		n = n.get_parent()
	if n != null and (n as Interactable).can_interact():
		hover = n


func _footsteps() -> void:
	var moved := Vector2(position.x - _last_pos.x, position.z - _last_pos.z).length()
	_last_pos = position
	if anim == 0 or anim == 3 or moved > 2.0:
		return
	_step_dist += moved
	var stride := 2.3 if anim == 2 else (1.3 if anim == 4 else 1.8)
	if _step_dist < stride:
		return
	_step_dist = 0.0
	var on_train: bool = GameState.scene != null and GameState.scene.is_on_train(position)
	var sound := ("step_wood%d" % (randi() % 3 + 1)) if on_train else ("step%d" % (randi() % 4 + 1))
	var vol := -4.0 if anim == 2 else (-18.0 if anim == 4 else -10.0)
	vol += linear_to_db(float(_cfg["noise"]))
	Audio.at(sound, global_position + Vector3(0, 0.1, 0), vol, 16.0, randf_range(0.9, 1.1))


func play_action(action: String) -> void:
	_model.play_action(action)
	if action == "hurt":
		Audio.at("hurt", global_position + Vector3(0, 1.2, 0), -6.0, 14.0)


## How far (metres) enemies can hear this player right now.
func noise_radius() -> float:
	var base := 0.0
	match anim:
		1: base = 6.0
		2: base = 15.0
		4: base = 1.5
	return base * float(ItemDB.character(char_idx)["noise"])


func eye_position() -> Vector3:
	return global_position + Vector3(0, _head.position.y, 0)


func look_dir() -> Vector3:
	return -_head.global_basis.z
