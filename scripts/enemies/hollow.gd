extends Enemy
## THE HOLLOW - a thin forest creature. It lurks between the trees and watches. A torch
## beam drives it back; noise (running) agitates it until it hunts. Light staggers a hunt.

enum { LURK, RETREAT, HUNT, FLEE }

var agitation := 0.0
var _points: Array = []
var _goal := Vector3.ZERO
var _timer := 0.0
var _stagger := 0.0
var _target: Player = null
var _limbs: Array = []
var _body: Node3D
var _eyes: Array = []


func _build() -> void:
	_points = config.get("points", [position])
	_goal = position
	var skin := Mat.flat(Color(0.05, 0.05, 0.06))
	var eye := Mat.glow(Color(0.9, 0.9, 0.8), 3.0)
	_body = Node3D.new()
	add_child(_body)
	Build.box(_body, Vector3(0, 1.75, 0.05), Vector3(0.3, 0.95, 0.2), skin, false, Vector3(12, 0, 0))
	Build.box(_body, Vector3(0, 1.25, 0), Vector3(0.24, 0.3, 0.18), skin, false)
	Build.box(_body, Vector3(0, 2.42, -0.1), Vector3(0.2, 0.3, 0.22), skin, false, Vector3(-18, 0, 12))
	for sx in [-0.05, 0.05]:
		_eyes.append(Build.box(_body, Vector3(sx, 2.46, -0.22), Vector3(0.03, 0.03, 0.02), eye, false))
	# Arms reach below the knees; legs bend the wrong way.
	for sx in [-0.24, 0.24]:
		var arm := Node3D.new()
		arm.position = Vector3(sx, 2.15, 0)
		_body.add_child(arm)
		Build.box(arm, Vector3(0, -0.5, 0), Vector3(0.08, 1.0, 0.08), skin, false)
		Build.box(arm, Vector3(0, -1.35, -0.12), Vector3(0.07, 0.8, 0.07), skin, false, Vector3(18, 0, 0))
		Build.box(arm, Vector3(0, -1.8, -0.26), Vector3(0.14, 0.2, 0.04), skin, false)
		_limbs.append(arm)
	for sx in [-0.1, 0.1]:
		var leg := Node3D.new()
		leg.position = Vector3(sx, 1.15, 0)
		_body.add_child(leg)
		Build.box(leg, Vector3(0, -0.3, 0.1), Vector3(0.1, 0.65, 0.1), skin, false, Vector3(-22, 0, 0))
		Build.box(leg, Vector3(0, -0.85, 0.08), Vector3(0.08, 0.65, 0.08), skin, false, Vector3(24, 0, 0))
		_limbs.append(leg)


func hear(pos: Vector3, radius: float) -> void:
	if position.distance_to(pos) <= radius:
		agitation += 14.0


func on_whistle() -> void:
	agitation = 0.0
	_timer = 6.0
	_goal = _farthest_point(position)
	state = FLEE


func _lit() -> bool:
	for p in world().player_nodes():
		if lit_by(p):
			return true
	return false


func _farthest_point(from: Vector3) -> Vector3:
	var best := position
	var best_d := -1.0
	for pt in _points:
		var d: float = pt.distance_to(from)
		if d > best_d and d < 70.0:
			best_d = d
			best = pt
	return best


func _lurk_point(around: Vector3) -> Vector3:
	var options := []
	for pt in _points:
		var d: float = pt.distance_to(around)
		if d > 12.0 and d < 26.0:
			options.append(pt)
	if options.is_empty():
		return _farthest_point(around)
	return options[randi() % options.size()]


func _think(delta: float) -> void:
	_timer -= delta
	_target = nearest(70.0)
	var lit := _lit()
	match state:
		LURK:
			if _target == null:
				agitation = maxf(0.0, agitation - 3.0 * delta)
				walk_to(_goal, 2.0, delta)
				return
			var tp := ppos(_target)
			var dist := position.distance_to(tp)
			if dist < 32.0:
				agitation += 0.5 * delta
			var r: float = _target.noise_radius()
			if r > 0.0 and dist < r + 10.0:
				agitation += (7.0 if _target.anim == 2 else 1.5) * delta
			if lit:
				agitation = maxf(0.0, agitation - 6.0 * delta)
				_goal = _farthest_point(tp)
				_timer = 3.0
				state = RETREAT
				return
			if _timer <= 0.0 or _goal.distance_to(tp) > 30.0 or _goal.distance_to(tp) < 9.0:
				_goal = _lurk_point(tp)
				_timer = randf_range(6.0, 11.0)
			if walk_to(_goal, 3.2, delta):
				face(tp, delta, 4.0)
			if agitation >= 100.0:
				_timer = 14.0
				_stagger = 0.0
				state = HUNT
		RETREAT:
			walk_to(_goal, 5.0, delta)
			if _timer <= 0.0:
				_timer = 0.0
				state = LURK
		HUNT:
			if _target == null or _timer <= 0.0:
				on_whistle()
				return
			var tp := ppos(_target)
			var speed := 6.3
			if lit:
				speed = 1.4
				_stagger += delta
				if _stagger > 2.5:
					on_whistle()
					return
			walk_to(tp, speed, delta, 1.2)
			if position.distance_to(tp) < 1.7:
				strike(_target, 28.0)
				on_whistle()
		FLEE:
			walk_to(_goal, 7.0, delta)
			if _timer <= 0.0:
				state = LURK
	threat = state == HUNT


func _on_state(_from: int, to: int) -> void:
	threat = to == HUNT
	if to == HUNT:
		Audio.at("hollow_cry", global_position + Vector3(0, 2.0, 0), 0.0, 45.0)
	elif to == RETREAT or to == FLEE:
		Audio.at("hollow_cry", global_position + Vector3(0, 2.0, 0), -12.0, 30.0, 1.4)


func _animate(delta: float, speed: float) -> void:
	# Stop-motion gait: limb angles snap between a few poses.
	var rate := 3.0 + speed * 1.4
	var raw := sin(_anim_t * rate)
	var s := snappedf(raw, 0.5) * (0.9 if speed > 0.3 else 0.08)
	_limbs[0].rotation.x = s * 0.9
	_limbs[1].rotation.x = -s * 0.9
	_limbs[2].rotation.x = -s
	_limbs[3].rotation.x = s
	_body.rotation.z = snappedf(sin(_anim_t * 0.7), 0.5) * 0.06
	_body.rotation.x = lerpf(_body.rotation.x, -0.35 if state == HUNT else 0.0, delta * 5.0)
	_body.position.y = -0.12 * absf(s)
	_step_accum += speed * delta
	if _step_accum > 2.2:
		_step_accum = 0.0
		Audio.at("creature_step%d" % (randi() % 2 + 1), global_position, -10.0, 24.0, 1.3)
