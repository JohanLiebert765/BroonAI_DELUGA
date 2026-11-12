extends Node
## LAN session management (ENet host/client), lobby roster and character selection.
## The host (peer 1) owns the lobby; clients only send requests.

signal lobby_changed
signal connection_failed(reason: String)
signal joined
signal player_left(id: int)
signal peer_ready

const DEFAULT_PORT := 24680
const MAX_PLAYERS := 4
const MAX_CLIENTS := 4  # a dedicated host accepts four clients; a playing host accepts three

var lobby := {}        # peer id -> {"name": String, "char": int (-1 = none)}
var dedicated := false
var online := false    # true while an ENet session exists
var in_game := false
var ready_peers := {}  # host: peers whose game scene has finished loading
var _join_timer: SceneTreeTimer = null


func _ready() -> void:
	multiplayer.peer_connected.connect(_on_peer_connected)
	multiplayer.peer_disconnected.connect(_on_peer_disconnected)
	multiplayer.connected_to_server.connect(_on_connected)
	multiplayer.connection_failed.connect(_on_connection_failed)
	multiplayer.server_disconnected.connect(_on_server_disconnected)


func is_host() -> bool:
	return multiplayer.is_server()


func my_id() -> int:
	return multiplayer.get_unique_id()


## Peer that sent the RPC being handled (our own id for local calls).
func sender() -> int:
	var id := multiplayer.get_remote_sender_id()
	return id if id != 0 else multiplayer.get_unique_id()


func start_single() -> void:
	leave()
	lobby = {1: {"name": Settings.player_name, "char": -1}}
	lobby_changed.emit()


func host(port: int, as_dedicated := false) -> Error:
	leave()
	var peer := ENetMultiplayerPeer.new()
	var err := peer.create_server(port, MAX_CLIENTS)
	if err != OK:
		return err
	multiplayer.multiplayer_peer = peer
	online = true
	dedicated = as_dedicated
	lobby = {}
	if not dedicated:
		lobby[1] = {"name": Settings.player_name, "char": -1}
	lobby_changed.emit()
	return OK


func join(ip: String, port: int) -> Error:
	leave()
	var peer := ENetMultiplayerPeer.new()
	var err := peer.create_client(ip, port)
	if err != OK:
		return err
	multiplayer.multiplayer_peer = peer
	online = true
	_join_timer = get_tree().create_timer(8.0)
	_join_timer.timeout.connect(_on_join_timeout.bind(_join_timer))
	return OK


func leave() -> void:
	ready_peers = {}
	_join_timer = null
	if online and multiplayer.multiplayer_peer:
		multiplayer.multiplayer_peer.close()
	multiplayer.multiplayer_peer = OfflineMultiplayerPeer.new()
	online = false
	dedicated = false
	in_game = false
	lobby = {}


func local_ips() -> Array:
	var out := []
	for a in IP.get_local_addresses():
		if a.count(".") == 3 and not a.begins_with("127.") and not a.begins_with("169.254."):
			out.append(a)
	return out


func char_taken(idx: int, except := 0) -> bool:
	for id in lobby:
		if id != except and lobby[id]["char"] == idx:
			return true
	return false


func all_chosen() -> bool:
	if lobby.is_empty():
		return false
	for id in lobby:
		if lobby[id]["char"] < 0:
			return false
	return true


# --- connection events -----------------------------------------------------

func _on_join_timeout(timer: SceneTreeTimer) -> void:
	if timer != _join_timer:
		return
	_join_timer = null
	if online and not is_host() and not lobby.has(my_id()):
		leave()
		connection_failed.emit("Connection timed out. Check the address, the port and the host's firewall.")


func _on_connected() -> void:
	_register.rpc_id(1, Settings.player_name)


func _on_connection_failed() -> void:
	_join_timer = null
	leave()
	connection_failed.emit("Could not connect to the host.")


func _on_server_disconnected() -> void:
	var was_in_game := in_game
	leave()
	if was_in_game:
		SceneFlow.to_menu("The host closed the game.")
	else:
		connection_failed.emit("Disconnected from the host.")


func _on_peer_connected(_id: int) -> void:
	pass  # the client introduces itself with _register


func _on_peer_disconnected(id: int) -> void:
	if not is_host():
		return
	if lobby.has(id):
		print("[net] player %d (%s) left" % [id, lobby[id]["name"]])
		lobby.erase(id)
		_lobby_state.rpc(lobby, dedicated)
		lobby_changed.emit()
		player_left.emit(id)


# --- lobby RPCs ------------------------------------------------------------

@rpc("any_peer", "call_remote", "reliable")
func _register(player_name: String) -> void:
	if not is_host():
		return
	var id := multiplayer.get_remote_sender_id()
	if in_game:
		_rejected.rpc_id(id, "The game is already in progress.")
		return
	if lobby.size() >= MAX_PLAYERS:
		_rejected.rpc_id(id, "The lobby is full.")
		return
	var clean := player_name.strip_edges().left(16)
	if clean == "":
		clean = "Survivor"
	lobby[id] = {"name": clean, "char": -1}
	print("[net] player %d (%s) joined" % [id, clean])
	_lobby_state.rpc(lobby, dedicated)
	lobby_changed.emit()


@rpc("authority", "call_remote", "reliable")
func _rejected(reason: String) -> void:
	leave()
	connection_failed.emit(reason)


@rpc("authority", "call_remote", "reliable")
func _lobby_state(state: Dictionary, host_dedicated: bool) -> void:
	dedicated = host_dedicated
	var first := not lobby.has(my_id())
	lobby = state
	if first and lobby.has(my_id()):
		_join_timer = null
		joined.emit()
	lobby_changed.emit()


## Client -> host: pick a character (-1 clears the choice). Duplicates are refused.
@rpc("any_peer", "call_local", "reliable")
func request_char(idx: int) -> void:
	if not is_host() or in_game:
		return
	var id := sender()
	if not lobby.has(id) or idx < -1 or idx >= ItemDB.characters.size():
		return
	if idx >= 0 and char_taken(idx, id):
		return
	lobby[id]["char"] = idx
	if online:
		_lobby_state.rpc(lobby, dedicated)
	lobby_changed.emit()


## Client -> host: start the game. Only the hosting player may start (anyone on a dedicated host).
@rpc("any_peer", "call_local", "reliable")
func request_start() -> void:
	if not is_host() or in_game:
		return
	if not dedicated and sender() != 1:
		return
	if not all_chosen():
		return
	if online:
		multiplayer.multiplayer_peer.refuse_new_connections = true
	ready_peers = {}
	_begin_game.rpc()


@rpc("authority", "call_local", "reliable")
func _begin_game() -> void:
	in_game = true
	SceneFlow.goto(SceneFlow.GAME)


## Every peer reports here once its game scene is loaded; the host starts when all have.
@rpc("any_peer", "call_local", "reliable")
func report_ready() -> void:
	if not is_host():
		return
	ready_peers[sender()] = true
	peer_ready.emit()
