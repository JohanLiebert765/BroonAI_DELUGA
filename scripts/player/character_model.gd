class_name CharacterModel
extends Node3D
## Procedural low-poly survivor: box body parts with per-character clothing colours and
## code-driven animation (idle, walk, run, crouch, interact, use item, hurt).

var anim := 0          # 0 idle, 1 walk, 2 run, 3 crouch idle, 4 crouch walk
var pitch := 0.0
var _torso: Node3D
var _head: Node3D
var _arm_l: Node3D
var _arm_r: Node3D
var _leg_l: Node3D
var _leg_r: Node3D
var _t := 0.0
var _action := ""
var _action_t := 0.0
var _blend := 0.0


static func create(cfg: Dictionary) -> CharacterModel:
	var m := CharacterModel.new()
	m._build(cfg)
	return m


func _build(cfg: Dictionary) -> void:
	var jacket := Mat.tex("fabric", Color(cfg["jacket"]).lightened(0.25), 2.0)
	var pants := Mat.tex("fabric", Color(cfg["pants"]).lightened(0.2), 2.0)
	var skin := Mat.flat(Color(cfg["skin"]))
	var shirt := Mat.flat(Color(cfg["shirt"]))
	var gear := Mat.flat(Color(cfg["headcolor"]))
	var shoe := Mat.flat(Color(0.08, 0.07, 0.07))

	_leg_l = _limb(Vector3(-0.11, 0.86, 0), Vector3(0.17, 0.78, 0.19), pants)
	_leg_r = _limb(Vector3(0.11, 0.86, 0), Vector3(0.17, 0.78, 0.19), pants)
	for leg in [_leg_l, _leg_r]:
		Build.box(leg, Vector3(0, -0.81, -0.04), Vector3(0.18, 0.1, 0.28), shoe, false)

	_torso = Node3D.new()
	_torso.position = Vector3(0, 0.86, 0)
	add_child(_torso)
	Build.box(_torso, Vector3(0, 0.3, 0), Vector3(0.46, 0.62, 0.26), jacket, false)
	Build.box(_torso, Vector3(0, 0.34, -0.132), Vector3(0.12, 0.5, 0.02), shirt, false)
	Build.box(_torso, Vector3(0, 0.02, 0), Vector3(0.47, 0.08, 0.27), Mat.flat(Color(cfg["jacket"]).darkened(0.4)), false)

	_arm_l = _limb(Vector3(-0.3, 0.56, 0), Vector3(0.13, 0.6, 0.15), jacket, _torso)
	_arm_r = _limb(Vector3(0.3, 0.56, 0), Vector3(0.13, 0.6, 0.15), jacket, _torso)
	for arm in [_arm_l, _arm_r]:
		Build.box(arm, Vector3(0, -0.65, 0), Vector3(0.1, 0.11, 0.11), skin, false)

	_head = Node3D.new()
	_head.position = Vector3(0, 0.63, 0)
	_torso.add_child(_head)
	Build.box(_head, Vector3(0, 0.14, 0), Vector3(0.24, 0.27, 0.24), skin, false)
	Build.box(_head, Vector3(-0.06, 0.17, -0.122), Vector3(0.04, 0.03, 0.01), shoe, false)
	Build.box(_head, Vector3(0.06, 0.17, -0.122), Vector3(0.04, 0.03, 0.01), shoe, false)
	match cfg["head"]:
		"cap":
			Build.box(_head, Vector3(0, 0.3, 0), Vector3(0.27, 0.09, 0.27), gear, false)
			Build.box(_head, Vector3(0, 0.27, -0.19), Vector3(0.22, 0.025, 0.14), gear, false)
		"longhair":
			Build.box(_head, Vector3(0, 0.29, 0.01), Vector3(0.28, 0.08, 0.28), gear, false)
			Build.box(_head, Vector3(0, 0.08, 0.13), Vector3(0.28, 0.42, 0.07), gear, false)
			Build.box(_head, Vector3(-0.135, 0.1, 0.02), Vector3(0.03, 0.34, 0.2), gear, false)
			Build.box(_head, Vector3(0.135, 0.1, 0.02), Vector3(0.03, 0.34, 0.2), gear, false)
		"hood":
			Build.box(_head, Vector3(0, 0.3, 0.02), Vector3(0.32, 0.08, 0.32), gear, false)
			Build.box(_head, Vector3(0, 0.12, 0.15), Vector3(0.32, 0.36, 0.06), gear, false)
			Build.box(_head, Vector3(-0.15, 0.13, 0.01), Vector3(0.04, 0.34, 0.28), gear, false)
			Build.box(_head, Vector3(0.15, 0.13, 0.01), Vector3(0.04, 0.34, 0.28), gear, false)
		_:
			Build.box(_head, Vector3(0, 0.29, 0.01), Vector3(0.26, 0.07, 0.26), gear, false)
			Build.box(_head, Vector3(0, 0.2, 0.12), Vector3(0.26, 0.16, 0.04), gear, false)


func _limb(pivot: Vector3, size: Vector3, mat: Material, parent: Node3D = null) -> Node3D:
	var n := Node3D.new()
	n.position = pivot
	(parent if parent else self).add_child(n)
	Build.box(n, Vector3(0, -size.y * 0.5, 0), size, mat, false)
	return n


func play_action(action: String) -> void:
	_action = action
	_action_t = 0.0


func _process(delta: float) -> void:
	var moving := anim == 1 or anim == 2 or anim == 4
	var crouch := anim >= 3
	var rate := 12.5 if anim == 2 else 8.0
	var amp := 0.95 if anim == 2 else (0.55 if anim == 1 else 0.35)
	_blend = move_toward(_blend, 1.0 if moving else 0.0, delta * 6.0)
	_t += delta * (rate if moving else 1.6)
	var swing := sin(_t) * amp * _blend
	var breathe := sin(_t) * 0.03 * (1.0 - _blend)
	_leg_l.rotation.x = swing + (0.9 if crouch else 0.0)
	_leg_r.rotation.x = -swing + (0.9 if crouch else 0.0)
	_arm_l.rotation.x = -swing * 0.8
	_arm_r.rotation.x = swing * 0.8
	_arm_l.rotation.z = -0.06 - breathe
	_arm_r.rotation.z = 0.06 + breathe
	_torso.position.y = lerpf(_torso.position.y, 0.5 if crouch else 0.86, delta * 10.0)
	_leg_l.position.y = _torso.position.y
	_leg_r.position.y = _torso.position.y
	_torso.rotation.x = (-0.12 if anim == 2 else 0.0) + (-0.3 if crouch else 0.0)
	_head.rotation.x = clampf(pitch, -0.9, 0.9) - _torso.rotation.x
	if _action != "":
		_action_t += delta
		var dur := 0.55
		var env := sin(clampf(_action_t / dur, 0.0, 1.0) * PI)
		match _action:
			"interact":
				_arm_r.rotation.x = lerpf(_arm_r.rotation.x, 1.45, env)
			"use":
				_arm_r.rotation.x = lerpf(_arm_r.rotation.x, 1.1, env)
				_arm_l.rotation.x = lerpf(_arm_l.rotation.x, 1.1, env)
				_arm_r.rotation.z = -0.4 * env
				_arm_l.rotation.z = 0.4 * env
			"hurt":
				_torso.rotation.x += 0.45 * env
				_arm_l.rotation.z = -0.7 * env
				_arm_r.rotation.z = 0.7 * env
		if _action_t >= dur:
			_action = ""
