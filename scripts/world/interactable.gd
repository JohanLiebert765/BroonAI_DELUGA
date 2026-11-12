class_name Interactable
extends StaticBody3D
## Base class for everything the player can use with the interact key.
## State lives in GameState flags keyed by `id`, so it replicates and saves for free.
## local_interact() runs on the pressing client (UI only); server_interact() runs on the host.

var id := ""
var prompt := "Interact"
var active := true
var networked := true


func _init() -> void:
	collision_layer = 4
	collision_mask = 0


func _ready() -> void:
	GameState.flag_changed.connect(_on_flag_changed)
	if id != "" and GameState.scene:
		GameState.scene.register(self)
	refresh()


func _exit_tree() -> void:
	if id != "" and GameState.scene and is_instance_valid(GameState.scene):
		GameState.scene.unregister(self)


func add_shape(size: Vector3, offset := Vector3.ZERO) -> void:
	var cs := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = size
	cs.shape = shape
	cs.position = offset
	add_child(cs)


func _on_flag_changed(key: String, _value) -> void:
	if id != "" and key.begins_with(id):
		refresh()


func get_prompt() -> String:
	return tr(prompt)


func can_interact() -> bool:
	return active


func local_interact(_player: Node) -> void:
	pass


func server_interact(_peer: int) -> void:
	pass


## Re-reads state from GameState and updates visuals. Must be idempotent.
func refresh() -> void:
	pass
