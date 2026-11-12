extends Enemy
## THE CONDUCTOR - patrols a route, investigates noise, searches, and chases on sight.

enum { PATROL, INVESTIGATE, CHASE, SEARCH }

var _points: Array = []
var _point_i := 0
var _wait := 0.0
var _noise_pos := Vector3.ZERO
var _last_seen := Vector3.ZERO
var _target: Player = null
var _lost := 0.0
var _timer := 0.0
var _attack_cd := 0.0
var _listen := 0.0
var _search_goal := Vector3.ZERO
var _legs: Array = []
var _arms: Array = []
var _body: Node3D
var _lantern: OmniLight3D


func _build() -> void:
	_points = config.get("points", [position])
	var coat := Mat.tex("fabric", Color(0.2, 0.24, 0.42), 2.0)
	var dark := Mat.flat(Color(0.05, 0.05, 0.07))
	var pale := Mat.flat(Color(0.72, 0.74, 0.7))
	var brass := Mat.flat(Color(0.7, 0.58, 0.25))
	_body = Node3D.new()
	add_child(_body)
	for sx in [-0.12, 0.12]:
		var leg := Node3D.new()
		leg.position = Vector3(sx, 0.95, 0)
		_body.add_child(leg)
		Build.box(leg, Vector3(0, -0.47, 0), Vector3(0.18, 0.95, 0.2), dark, false)
		_legs.append(leg)
	Build.box(_body, Vector3(0, 1.3, 0), Vector3(0.56, 0.9, 0.3), coat, false)
	Build.box(_body, Vector3(0, 0.75, 0), Vector3(0.6, 0.5, 0.34), coat, false)
	for by in [1.1, 1.3, 1.5]:
		Build.box(_body, Vector3(0, by, -0.16), Vector3(0.05, 0.05, 0.02), brass, false)
	for sx in [-0.36, 0.36]:
		var arm := Node3D.new()
		arm.position = Vector3(sx, 1.68, 0)
		_body.add_child(arm)
		Build.box(arm, Vector3(0, -0.4, 0), Vector3(0.14, 0.8, 0.16), coat, false)
		Build.box(arm, Vector3(0, -0.85, 0), Vector3(0.1, 0.12, 0.1), pale, false)
		_arms.append(arm)
	Build.box(_body, Vector3(0, 1.92, 0), Vector3(0.26, 0.3, 0.26), pale, false)
	Build.box(_body, Vector3(0, 2.1, 0), Vector3(0.32, 0.12, 0.32), coat, false)
	Build.box(_body, Vector3(0, 2.05, -0.2), Vector3(0.28, 0.03, 0.14), dark, false)
	Build.box(_body, Vector3(0, 2.1, -0.165), Vector3(0.1, 0.06, 0.01), brass, false)
	# Lantern in the right hand.
	Build.box(_arms[1], Vector3(0, -1.05, -0.05), Vector3(0.14, 0.22, 0.14), Mat.glow(Color(0.9, 0.3, 0.15), 2.0), false)
	_lantern = Build.light(_arms[1], Vector3(0, -1.05, -0.05), Color(0.9, 0.35, 0.2), 0.9, 6.0)


func hear(pos: Vector3, radius: float) -> void:
	if state == CHASE or position.distance_to(pos) > radius:
		return
	_noise_pos = pos
	state = INVESTIGATE


func _spot() -> Player:
	var best: Player = null
	var best_d := 1e9
	for p in targets():
		var d := position.distance_to(ppos(p))
		var view := 15.0 + (7.0 if p.flash_on else 0.0)
		if p.anim >= 3:
			view *= 0.5
		var close := 1.3 if p.anim >= 3 else 2.6
		if (d < close or sees(p, view, 115.0)) and d < best_d:
			best = p
			best_d = d
	return best


func _think(delta: float) -> void:
	_attack_cd = maxf(0.0, _attack_cd - delta)
	_listen -= delta
	if _listen <= 0.0:
		_listen = 0.5
		for p in targets():
			var r: float = p.noise_radius()
			if r > 0.0 and position.distance_to(ppos(p)) <= r:
				hear(ppos(p), r)
	var seen := _spot()
	if seen and state != CHASE:
		state = CHASE
		_lost = 0.0
	match state:
		PATROL:
			if _wait > 0.0:
				_wait -= delta
			elif walk_to(_points[_point_i], 1.5, delta):
				_point_i = (_point_i + 1) % _points.size()
				_wait = 2.5
		INVESTIGATE:
			if walk_to(_noise_pos, 2.5, delta, 1.2):
				_last_seen = _noise_pos
				_timer = 6.0
				_search_goal = position
				state = SEARCH
		CHASE:
			if seen:
				_target = seen
				_last_seen = ppos(seen)
				_lost = 0.0
			else:
				_lost += delta
			var reached := walk_to(_last_seen, 4.3, delta, 1.3)
			if seen and position.distance_to(ppos(seen)) < 1.7 and _attack_cd <= 0.0:
				_attack_cd = 1.7
				strike(seen, 22.0)
			if _lost > 4.0 or (reached and not seen):
				_timer = 7.0
				_search_goal = position
				state = SEARCH
		SEARCH:
			_timer -= delta
			if walk_to(_search_goal, 2.0, delta, 0.6):
				_search_goal = _last_seen + Vector3(randf_range(-5, 5), 0, randf_range(-5, 5))
			if _timer <= 0.0:
				state = PATROL
	threat = state == CHASE


func _on_state(_from: int, to: int) -> void:
	threat = to == CHASE
	if to == CHASE:
		Audio.at("growl", global_position + Vector3(0, 1.6, 0), -2.0, 30.0)
	elif to == INVESTIGATE:
		Audio.at("bell", global_position + Vector3(0, 1.6, 0), -14.0, 22.0, 0.7)


func _animate(delta: float, speed: float) -> void:
	var stride := clampf(speed / 4.0, 0.0, 1.0)
	var s := sin(_anim_t * (4.0 + speed * 1.6)) * (0.25 + 0.35 * stride) * (1.0 if speed > 0.2 else 0.0)
	_legs[0].rotation.x = s
	_legs[1].rotation.x = -s
	_arms[0].rotation.x = 1.2 if state == CHASE else 0.0
	_arms[1].rotation.x = 0.9 if state == CHASE else 0.25
	_body.rotation.x = lerpf(_body.rotation.x, -0.2 if state == CHASE else 0.0, delta * 4.0)
	_lantern.light_energy = 2.8 + sin(_anim_t * 9.0) * 0.5
	_step_accum += speed * delta
	if _step_accum > 1.5:
		_step_accum = 0.0
		Audio.at("creature_step%d" % (randi() % 2 + 1), global_position, -8.0 if state == CHASE else -14.0, 22.0)
