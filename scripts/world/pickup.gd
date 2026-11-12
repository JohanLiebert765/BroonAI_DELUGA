class_name Pickup
extends Interactable
## An item lying in the world. Level pickups are tracked by a flag; dropped items are
## spawned by the host through the MultiplayerSpawner and freed when taken.

var item := ""
var count := 1
var quest_flag := ""   # set when picked up
var count_flag := ""   # incremented when picked up
var is_drop := false


func _ready() -> void:
	add_child(ItemModels.make(item))
	add_shape(Vector3(0.55, 0.45, 0.55), Vector3(0, 0.15, 0))
	super()


func get_prompt() -> String:
	var text := "%s: %s" % [tr("Pick up"), tr(ItemDB.item_name(item))]
	if count > 1:
		text += " x%d" % count
	return text


func refresh() -> void:
	if is_drop:
		return
	var taken := GameState.flag(id)
	visible = not taken
	active = not taken
	collision_layer = 0 if taken else 4


func server_interact(peer: int) -> void:
	if not active or is_queued_for_deletion() or (not is_drop and GameState.flag(id)):
		return
	var inv := GameState.inv(peer)
	var trial: Array = inv.duplicate(true)
	var left := Inventory.add(trial, item, count)
	if left == count:
		GameState.notify(peer, "Your inventory is full.", [], "warn")
		return
	Inventory.add(inv, item, count - left)
	GameState.sync_player(peer)
	var world = GameState.scene
	if left > 0:
		world.spawn_drop(item, left, global_position)
	if is_drop:
		active = false
		queue_free()
	else:
		GameState.set_flag(id, true)
	if quest_flag != "":
		GameState.set_flag(quest_flag, true)
	if count_flag != "":
		GameState.inc_flag(count_flag)
	GameState.sound("pickup", global_position, -6.0, 12.0)
	world.player_action(peer, "interact")
	GameState.notify(peer, "Picked up: %s", ["@" + ItemDB.item_name(item)])
