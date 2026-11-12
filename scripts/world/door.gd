class_name Door
extends Interactable
## Hinged or sliding door. Flags: `id` (open), `id_unlocked`.
## Can be locked by a key item, a tool (forced), another flag, a keypad or a global lock flag.

var size := Vector3(1.0, 2.05, 0.08)
var sliding := false
var open_angle := 105.0
var key_item := ""
var tool_item := ""
var need_flag := ""
var keypad := false
var lock_flag := ""          # while this flag is set the door stays shut (train doors in motion)
var locked_msg := "It is locked."
var open_flag := ""          # quest flag set the first time the door opens
var material: Material = null

var _leaf: StaticBody3D
var _shown_open := false
var _first := true


func _ready() -> void:
	collision_layer = 0
	_leaf = StaticBody3D.new()
	_leaf.collision_layer = 68
	add_child(_leaf)
	var mat: Material = material if material else Mat.tex("planks", Color(0.5, 0.42, 0.36))
	var mi := Build.box(_leaf, Vector3(size.x * 0.5, size.y * 0.5, 0), size, mat, false)
	Build.box(mi, Vector3(size.x * 0.38, 0, 0), Vector3(0.06, 0.06, size.z + 0.1), Mat.flat(Color(0.6, 0.55, 0.35)), false)
	var cs := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = size
	cs.shape = shape
	cs.position = Vector3(size.x * 0.5, size.y * 0.5, 0)
	_leaf.add_child(cs)
	super()


func needs_unlock() -> bool:
	return (key_item != "" or tool_item != "" or need_flag != "" or keypad) and not GameState.flag(id + "_unlocked")


func is_held_shut() -> bool:
	return lock_flag != "" and GameState.flag(lock_flag)


func get_prompt() -> String:
	if GameState.flag(id):
		return tr("Close door")
	if is_held_shut() or needs_unlock():
		return tr("Enter code") if keypad and not is_held_shut() else tr("Locked door")
	return tr("Open door")


func refresh() -> void:
	var open := GameState.flag(id)
	if _leaf == null or (open == _shown_open and not _first):
		return
	_shown_open = open
	var target_rot := deg_to_rad(open_angle) if open and not sliding else 0.0
	var target_pos := Vector3(size.x * 0.92, 0, 0) if open and sliding else Vector3.ZERO
	if _first or not is_inside_tree():
		_first = false
		_leaf.rotation.y = target_rot
		_leaf.position = target_pos
		return
	# No collision while the leaf swings so nobody gets shoved through a wall.
	_leaf.collision_layer = 4
	var tw := create_tween().set_parallel(true)
	tw.tween_property(_leaf, "rotation:y", target_rot, 0.45)
	tw.tween_property(_leaf, "position", target_pos, 0.45)
	tw.chain().tween_callback(func(): _leaf.collision_layer = 68)


func local_interact(_player: Node) -> void:
	if keypad and needs_unlock() and not is_held_shut():
		GameState.fx.emit("open_keypad", {"id": id})


func server_interact(peer: int) -> void:
	var open := GameState.flag(id)
	if not open:
		if is_held_shut():
			GameState.sound("door_locked", global_position, -4.0, 14.0)
			GameState.notify(peer, "The doors stay shut while the train is moving.", [], "warn")
			return
		if needs_unlock():
			if keypad:
				return
			if need_flag != "" and GameState.flag(need_flag):
				pass
			elif key_item != "" and GameState.has_item(peer, key_item):
				GameState.notify(peer, "Unlocked with: %s", ["@" + ItemDB.item_name(key_item)], "good")
			elif tool_item != "" and GameState.has_item(peer, tool_item):
				GameState.notify(peer, "Forced open with: %s", ["@" + ItemDB.item_name(tool_item)], "good")
				GameState.scene.noise(global_position, 16.0)
			else:
				GameState.sound("door_locked", global_position, -4.0, 14.0)
				GameState.notify(peer, locked_msg, [], "warn")
				return
			GameState.set_flag(id + "_unlocked", true)
	GameState.set_flag(id, not open)
	if not open and open_flag != "":
		GameState.set_flag(open_flag, true)
	GameState.sound("door_close" if open else "door_open", global_position, -3.0, 18.0)
	GameState.scene.noise(global_position, 9.0)
	GameState.scene.player_action(peer, "interact")
