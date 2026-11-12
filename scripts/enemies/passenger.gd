extends Enemy
## THE PASSENGER - an apparition. Watches from a distance, vanishes when approached,
## and sometimes appears right behind a player. With config.mode == "train" it haunts
## the carriages while the train travels.

enum { HIDDEN, WATCH, STALK, VANISH }

const HIDE_Y := -60.0

var _timer := 12.0
var _target: Player = null
var _stare := 0.0
var _mats: Array = []
var _whisper: AudioStreamPlayer3D
var _body: Node3D


func _build() -> void:
	var coat := Mat.ghost(Color(0.16, 0.17, 0.2), 0.85)
	var pale := Mat.ghost(Color(0.75, 0.76, 0.72), 0.9)
	var dark := Mat.ghost(Color(0.03, 0.03, 0.04), 0.9)
	_mats = [coat, pale, dark]
	_body = Node3D.new()
	add_child(_body)
	Build.cyl(_body, Vector3(0, 0.8, 0), 0.42, 1.6, coat, false, Vector3.ZERO, 6, 0.26)
	Build.box(_body, Vector3(0, 1.85, 0), Vector3(0.58, 0.6, 0.3), coat, false)
	Build.box(_body, Vector3(-0.36, 1.5, 0), Vector3(0.14, 1.1, 0.16), coat, false)
	Build.box(_body, Vector3(0.36, 1.5, 0), Vector3(0.14, 1.1, 0.16), coat, false)
	Build.box(_body, Vector3(0, 2.32, 0), Vector3(0.24, 0.32, 0.24), pale, false)
	Build.box(_body, Vector3(-0.06, 2.36, -0.125), Vector3(0.05, 0.05, 0.01), dark, false)
	Build.box(_body, Vector3(0.06, 2.36, -0.125), Vector3(0.05, 0.05, 0.01), dark, false)
	Build.cyl(_body, Vector3(0, 2.5, 0), 0.3, 0.03, dark, false, Vector3.ZERO, 8)
	Build.cyl(_body, Vector3(0, 2.6, 0), 0.17, 0.2, dark, false, Vector3.ZERO, 8)
	Build.box(_body, Vector3(0.38, 0.75, 0), Vector3(0.14, 0.4, 0.55), Mat.ghost(Color(0.3, 0.2, 0.14), 0.85), false)
	_mats.append(_body.get_child(_body.get_child_count() - 1).material_override)
	_whisper = Audio.loop_on(self, "whisper_loop", -9.0, 18.0, "SFX", false)
	_whisper.position.y = 2.0
	if GameState.is_host():
		alpha = 0.0
		position.y = HIDE_Y
		_timer = float(config.get("delay", 14.0))


func force_appear() -> void:
	if state == HIDDEN:
		_timer = 0.0


func on_whistle() -> void:
	if state == WATCH or state == STALK:
		state = VANISH


func _in_train_mode() -> bool:
	return config.get("mode", "") == "train"


func _think(delta: float) -> void:
	_timer -= delta
	match state:
		HIDDEN:
			if _timer <= 0.0:
				_appear()
		WATCH:
			if _target == null or not is_instance_valid(_target):
				state = VANISH
				return
			face(ppos(_target), delta, 3.0)
			var near := nearest(6.0 if not _in_train_mode() else 3.5, true)
			var yaw := _target.rotation.y if _target.is_local() else _target.net_yaw
			var look := Vector3(-sin(yaw), 0, -cos(yaw))
			var to_me := (position - ppos(_target))
			to_me.y = 0
			if look.dot(to_me.normalized()) > 0.92:
				_stare += delta
			if near or _stare > 3.5 or _timer <= 0.0:
				state = VANISH
		STALK:
			if _target == null or not is_instance_valid(_target):
				state = VANISH
				return
			var yaw := _target.rotation.y if _target.is_local() else _target.net_yaw
			var look := Vector3(-sin(yaw), 0, -cos(yaw))
			var to_me := position - ppos(_target)
			to_me.y = 0
			if to_me.length() > 7.0:
				state = VANISH
			elif look.dot(to_me.normalized()) > 0.55:
				GameState.fx_to(_target.peer_id, "scare")
				state = VANISH
			elif _timer <= 0.0:
				strike(_target, 10.0)
				GameState.notify(_target.peer_id, "Something cold passes through you.", [], "warn")
				state = VANISH
		VANISH:
			alpha = move_toward(alpha, 0.0, delta * 1.8)
			if alpha <= 0.0:
				position.y = HIDE_Y
				_timer = randf_range(25.0, 55.0)
				state = HIDDEN
	if state == WATCH or state == STALK:
		alpha = move_toward(alpha, 1.0, delta * 1.2)


func _appear() -> void:
	var w := world()
	var pool := []
	for p in w.player_nodes():
		if w.is_on_train(ppos(p)) == _in_train_mode():
			pool.append(p)
	if pool.is_empty():
		_timer = 8.0
		return
	_target = pool[randi() % pool.size()]
	var tp := ppos(_target)
	_stare = 0.0
	if _in_train_mode():
		var x := clampf(tp.x + (7.0 if tp.x < 0.0 else -7.0), -32.0, 16.0)
		position = Vector3(x, Train.FLOOR, 0.0)
		_timer = 16.0
		state = WATCH
	elif randf() < 0.3:
		var yaw := _target.rotation.y if _target.is_local() else _target.net_yaw
		position = tp + Vector3(sin(yaw), 0, cos(yaw)) * 2.8
		position.y = tp.y
		_timer = 6.0
		state = STALK
	else:
		var spot := tp + Vector3(randf_range(-1, 1), 0, randf_range(-1, 1)).normalized() * 16.0
		var best := 1e9
		for pt in w.location.apparition_points:
			var d: float = pt.distance_to(tp)
			if d > 9.0 and d < 40.0 and d < best and w.player_nodes().all(func(q): return ppos(q).distance_to(pt) > 8.0):
				best = d
				spot = pt
		position = spot
		_timer = 14.0
		state = WATCH
	rotation.y = atan2(-(tp.x - position.x), -(tp.z - position.z))


func _animate(_delta: float, _speed: float) -> void:
	visible = alpha > 0.02
	var flick := 1.0 if randf() > 0.06 else 0.4
	for m in _mats:
		m.albedo_color.a = alpha * 0.85 * flick
	_body.position.y = sin(_anim_t * 0.8) * 0.04
	if visible and not _whisper.playing and _whisper.stream:
		_whisper.play()
	elif not visible and _whisper.playing:
		_whisper.stop()
