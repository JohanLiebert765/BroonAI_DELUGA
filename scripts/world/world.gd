class_name World
extends Node3D
## Root of the 3D game world: train, current location, replicated players / enemies / drops,
## and the host-validated interaction entry point.

const PLAYER_SCENE := preload("res://scenes/player/player.tscn")
const PICKUP_SCENE := preload("res://scenes/items/pickup.tscn")
const SEATS := [Vector3(13.0, 1.0, 0.0), Vector3(11.5, 1.0, 0.0), Vector3(10.0, 1.0, 0.0), Vector3(8.5, 1.0, 0.0)]

var interactables := {}
var train: Train
var system: TrainSystem
var director: EventDirector
var location: Node3D = null
var players: Node3D
var enemies: Node3D
var drops: Node3D
var _player_spawner: MultiplayerSpawner
var _enemy_spawner: MultiplayerSpawner
var _drop_spawner: MultiplayerSpawner
var _env: Environment
var _moon: DirectionalLight3D
var _nav: NavigationRegion3D
var _begun := false
var _drop_seq := 0
var _load_serial := 0


func _enter_tree() -> void:
	GameState.scene = self


func _exit_tree() -> void:
	if GameState.scene == self:
		GameState.scene = null
		GameState.local_player = null


func _ready() -> void:
	players = _holder("Players")
	enemies = _holder("Enemies")
	drops = _holder("Drops")
	_player_spawner = _spawner("PlayerSpawner", players, _spawn_player)
	_enemy_spawner = _spawner("EnemySpawner", enemies, _spawn_enemy)
	_drop_spawner = _spawner("DropSpawner", drops, _spawn_drop)

	var we := WorldEnvironment.new()
	_env = Environment.new()
	_env.background_mode = Environment.BG_COLOR
	_env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	_env.fog_enabled = true
	_env.tonemap_mode = Environment.TONE_MAPPER_LINEAR
	we.environment = _env
	add_child(we)
	_moon = DirectionalLight3D.new()
	_moon.rotation_degrees = Vector3(-55, 35, 0)
	_moon.light_color = Color(0.55, 0.65, 0.9)
	_moon.shadow_enabled = false
	add_child(_moon)

	train = preload("res://scenes/train/train.tscn").instantiate()
	train.name = "Train"
	add_child(train)
	train.add_to_group("nav_source")
	system = TrainSystem.new()
	system.name = "TrainSystem"
	add_child(system)
	train.bind(system)
	director = EventDirector.new()
	director.name = "EventDirector"
	add_child(director)

	GameState.location_changed.connect(_load_location)
	GameState.fx.connect(_on_fx)
	Net.player_left.connect(_on_player_left)
	# Readiness goes through the Net autoload: it exists on the host even while the
	# host is still loading this scene, so a fast client cannot be missed.
	Net.peer_ready.connect(_try_begin)
	# Deferred so the HUD and panels (readied after this node) are listening when the
	# host starts the session in the same frame.
	(func(): Net.report_ready.rpc_id(1)).call_deferred()


func _holder(node_name: String) -> Node3D:
	var n := Node3D.new()
	n.name = node_name
	add_child(n)
	return n


func _spawner(node_name: String, target: Node, fn: Callable) -> MultiplayerSpawner:
	var s := MultiplayerSpawner.new()
	s.name = node_name
	add_child(s)
	s.spawn_path = s.get_path_to(target)
	s.spawn_function = fn
	return s


# --- session start ---------------------------------------------------------


func _try_begin() -> void:
	if not GameState.is_host():
		return
	if _begun:
		return
	for id in Net.lobby:
		if not Net.ready_peers.has(id):
			return
	if Net.lobby.is_empty():
		return
	_begun = true
	GameState.host_begin()
	var i := 0
	for id in Net.lobby:
		_player_spawner.spawn({"id": id, "char": Net.lobby[id]["char"], "pos": SEATS[i % SEATS.size()], "yaw": PI * 0.5})
		i += 1
	for d in GameState.data["drops"]:
		spawn_drop(d["item"], int(d["n"]), Vector3(d["pos"][0], d["pos"][1], d["pos"][2]))
	GameState.data["drops"] = []
	print("[game] started with %d player(s) at %s" % [Net.lobby.size(), GameState.loc_id()])


func _on_player_left(id: int) -> void:
	if not GameState.is_host():
		return
	if not _begun:
		_try_begin()
		return
	GameState.remove_player(id)
	var node := players.get_node_or_null(str(id))
	if node:
		node.queue_free()


# --- spawn functions (run on every peer) -----------------------------------

func _spawn_player(d: Dictionary) -> Node:
	var p: Player = PLAYER_SCENE.instantiate()
	p.peer_id = d["id"]
	p.char_idx = d["char"]
	p.name = str(d["id"])
	p.position = d["pos"]
	p.rotation.y = d["yaw"]
	return p


func _spawn_enemy(d: Dictionary) -> Node:
	var scene: PackedScene = load("res://scenes/enemies/%s.tscn" % d["type"])
	var e: Node3D = scene.instantiate()
	e.position = d["pos"]
	e.set("config", d)
	return e


func _spawn_drop(d: Dictionary) -> Node:
	var p: Pickup = PICKUP_SCENE.instantiate()
	p.is_drop = true
	p.id = d["id"]
	p.item = d["item"]
	p.count = d["n"]
	p.position = d["pos"]
	return p


func spawn_drop(item: String, n: int, pos: Vector3) -> void:
	if not GameState.is_host():
		return
	_drop_seq += 1
	_drop_spawner.spawn({"id": "drop_%d" % _drop_seq, "item": item, "n": n, "pos": pos})


func spawn_enemy(type: String, pos: Vector3, extra: Dictionary = {}) -> Node:
	if not GameState.is_host():
		return null
	var d := {"type": type, "pos": pos}
	d.merge(extra)
	return _enemy_spawner.spawn(d)


func collect_drops() -> Array:
	var out := []
	for d in drops.get_children():
		if d is Pickup and not d.is_queued_for_deletion():
			out.append({"item": d.item, "n": d.count, "pos": [d.position.x, d.position.y, d.position.z]})
	return out


# --- registry and interaction ----------------------------------------------

func register(it: Interactable) -> void:
	interactables[it.id] = it


func unregister(it: Interactable) -> void:
	if interactables.get(it.id) == it:
		interactables.erase(it.id)


## Client -> host: use an interactable. The host checks existence, state and reach.
@rpc("any_peer", "call_local", "reliable")
func request_interact(id: String) -> void:
	if not GameState.is_host():
		return
	var peer := Net.sender()
	if not GameState.pdata.has(peer):
		return
	var it = interactables.get(id)
	if it == null or not is_instance_valid(it) or not it.can_interact():
		return
	if player_pos(peer).distance_to(it.global_position) > 6.5:
		return
	it.server_interact(peer)


# --- player helpers --------------------------------------------------------

func player_nodes() -> Array:
	return players.get_children().filter(func(p): return p is Player and not p.is_queued_for_deletion())


func player_node(peer: int) -> Player:
	return players.get_node_or_null(str(peer)) as Player


func player_pos(peer: int) -> Vector3:
	var p := player_node(peer)
	if p == null:
		return GameState.MEDICAL_SPAWN
	return p.position if p.is_local() else p.net_pos


func player_forward(peer: int) -> Vector3:
	var p := player_node(peer)
	if p == null:
		return Vector3.FORWARD
	var yaw := p.rotation.y if p.is_local() else p.net_yaw
	return Vector3(-sin(yaw), 0, -cos(yaw))


func is_on_train(pos: Vector3) -> bool:
	return train != null and train.is_inside(pos)


func teleport_player(peer: int, pos: Vector3) -> void:
	var p := player_node(peer)
	if p == null:
		return
	if peer == multiplayer.get_unique_id():
		p.teleport(pos)
	else:
		p.teleport.rpc_id(peer, pos)


## Host: play a one-shot character animation on every peer.
func player_action(peer: int, action: String) -> void:
	_rpc_action.rpc(peer, action)


@rpc("authority", "call_local", "unreliable")
func _rpc_action(peer: int, action: String) -> void:
	var p := player_node(peer)
	if p:
		p.play_action(action)


## Host: something made a sound enemies may react to.
func noise(pos: Vector3, radius: float) -> void:
	if not GameState.is_host():
		return
	for e in enemies.get_children():
		if e.has_method("hear"):
			e.hear(pos, radius)


func _on_fx(effect: String, args: Dictionary) -> void:
	if effect == "sound":
		Audio.at(args["name"], args["pos"], args.get("vol", 0.0), args.get("dist", 28.0))


# --- location loading ------------------------------------------------------

func _load_location() -> void:
	_load_serial += 1
	var serial := _load_serial
	if location:
		remove_child(location)
		location.queue_free()
		location = null
	if _nav:
		_nav.queue_free()
		_nav = null
	if GameState.is_host():
		for e in enemies.get_children():
			e.queue_free()
		for d in drops.get_children():
			if not is_on_train(d.position):
				d.queue_free()
	var traveling: bool = GameState.data.get("traveling", false)
	location = TravelScenery.new() if traveling else Location.create(GameState.loc_id())
	location.name = "Location"
	add_child(location)
	location.add_to_group("nav_source")
	_apply_env(location.env)
	train.set_travel_mode(traveling)
	if not GameState.is_host():
		return
	# Let the new colliders register before baking navigation and spawning enemies.
	await get_tree().physics_frame
	await get_tree().physics_frame
	if serial != _load_serial:
		return
	if not traveling:
		_bake_navigation()
		for spawn in location.enemy_spawns:
			spawn_enemy(spawn["type"], spawn["pos"], spawn)
	director.on_location_loaded(traveling)


func _bake_navigation() -> void:
	_nav = NavigationRegion3D.new()
	var mesh := NavigationMesh.new()
	mesh.geometry_parsed_geometry_type = NavigationMesh.PARSED_GEOMETRY_STATIC_COLLIDERS
	mesh.geometry_collision_mask = 1
	mesh.geometry_source_geometry_mode = NavigationMesh.SOURCE_GEOMETRY_GROUPS_WITH_CHILDREN
	mesh.geometry_source_group_name = "nav_source"
	mesh.cell_size = 0.25
	mesh.cell_height = 0.25
	mesh.agent_radius = 0.5
	mesh.agent_height = 1.75
	mesh.agent_max_climb = 0.25
	mesh.agent_max_slope = 40.0
	_nav.navigation_mesh = mesh
	add_child(_nav)
	_nav.bake_navigation_mesh(false)


## Path for enemies on the baked navmesh (empty if none).
func nav_path(from: Vector3, to: Vector3) -> PackedVector3Array:
	var map := get_world_3d().navigation_map
	return NavigationServer3D.map_get_path(map, from, to, true)


func _apply_env(e: Dictionary) -> void:
	_env.background_color = e.get("sky", Color(0.02, 0.025, 0.04))
	_env.fog_light_color = e.get("fog_color", Color(0.06, 0.07, 0.1))
	_env.fog_density = e.get("fog_density", 0.035) * 0.55
	_env.ambient_light_color = e.get("ambient", Color(0.35, 0.4, 0.55))
	_env.ambient_light_energy = e.get("ambient_energy", 0.45) * 4.2
	_moon.light_energy = e.get("moon", 0.12) * 9.0
	Audio.ambient(e.get("ambient_sound", "wind_loop"), e.get("ambient_db", -14.0))
