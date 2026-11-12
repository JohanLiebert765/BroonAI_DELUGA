class_name TriggerZone
extends Node3D
## Host-side box trigger: sets a flag the first time any player walks into it.

var flag := ""
var half := Vector3(3, 2, 3)
var message := ""     # optional announcement
var _t := 0.0


func _physics_process(delta: float) -> void:
	if not GameState.is_host() or flag == "" or GameState.scene == null:
		return
	_t += delta
	if _t < 0.4:
		return
	_t = 0.0
	if GameState.flag(flag):
		set_physics_process(false)
		return
	for p in GameState.scene.player_nodes():
		var d: Vector3 = (p.global_position - global_position).abs()
		if d.x <= half.x and d.y <= half.y and d.z <= half.z:
			GameState.set_flag(flag, true)
			if message != "":
				GameState.notify_all(message, [], "good")
			return
