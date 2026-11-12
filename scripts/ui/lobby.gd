extends Control
## Lobby: player list, character selection (all four survivors visible, no duplicates),
## save selection for the host, start and leave. Also used for single-player.

var _models: Array = []
var _cards: Array = []
var _players: VBoxContainer
var _start: Button
var _info: Label
var _save_option: OptionButton
var _slots: Array = []
var _t := 0.0


func _ready() -> void:
	theme = UIKit.theme()
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	var view := Ps1View.new()
	add_child(view)
	_build_stage(view.sub)
	Audio.music("menu_theme_loop", -9.0)

	var head := UIKit.label("Lobby - choose your survivor", 30, Color(0.88, 0.85, 0.76))
	head.position = Vector2(40, 24)
	head.add_theme_color_override("font_outline_color", Color.BLACK)
	head.add_theme_constant_override("outline_size", 5)
	add_child(head)

	var side := PanelContainer.new()
	side.position = Vector2(40, 80)
	side.custom_minimum_size = Vector2(300, 0)
	add_child(side)
	var sv := VBoxContainer.new()
	side.add_child(sv)
	sv.add_child(UIKit.label("Players", 18, UIKit.AMBER))
	_players = VBoxContainer.new()
	sv.add_child(_players)
	_info = UIKit.label("", 14, UIKit.DIM)
	_info.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	_info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_info.custom_minimum_size.x = 280
	sv.add_child(_info)
	if Net.is_host():
		sv.add_child(UIKit.label("Game", 16, UIKit.AMBER))
		_save_option = OptionButton.new()
		_save_option.focus_mode = Control.FOCUS_NONE
		_save_option.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
		_save_option.add_item(tr("New game"))
		_slots = [""]
		for slot in SaveSystem.SLOTS:
			var info := SaveSystem.info(slot)
			if not info.is_empty():
				_save_option.add_item("%s: %s - %s" % [tr("Load"), tr(SaveSystem.SLOT_LABELS[slot]), tr(Quests.chapter(info["chapter"])["title"])])
				_slots.append(slot)
		if not GameState.pending_load.is_empty():
			# Arrived from Continue / Load Game: keep that save selected.
			_save_option.add_item(tr("Load the selected save"))
			_slots.append("__pending__")
			_save_option.select(_slots.size() - 1)
		sv.add_child(_save_option)
		_start = UIKit.button("Start Game", _on_start)
		sv.add_child(_start)
	sv.add_child(UIKit.button("Leave Lobby", _on_leave))

	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 18)
	add_child(row)
	for i in ItemDB.characters.size():
		var c: Dictionary = ItemDB.characters[i]
		var card := PanelContainer.new()
		card.custom_minimum_size = Vector2(250, 160)
		row.add_child(card)
		var cv := VBoxContainer.new()
		card.add_child(cv)
		cv.add_child(UIKit.label(c["name"], 22, Color(0.92, 0.88, 0.74)))
		cv.add_child(UIKit.label(c["role"], 15, UIKit.AMBER))
		var bonus := UIKit.label(c["bonus"], 14, UIKit.DIM)
		bonus.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		bonus.custom_minimum_size = Vector2(230, 40)
		cv.add_child(bonus)
		var b := UIKit.button("Select", _on_pick.bind(i))
		b.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
		cv.add_child(b)
		_cards.append(b)
	UIKit.place(row, Control.PRESET_BOTTOM_WIDE, Vector2(0, -24))

	Net.lobby_changed.connect(_refresh)
	Net.connection_failed.connect(func(reason): SceneFlow.to_menu(reason))
	_refresh()


func _build_stage(root: Node) -> void:
	var stage := Node3D.new()
	root.add_child(stage)
	var we := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.03, 0.035, 0.05)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.4, 0.42, 0.55)
	env.ambient_light_energy = 1.6
	env.fog_enabled = true
	env.fog_light_color = Color(0.07, 0.08, 0.11)
	env.fog_density = 0.06
	we.environment = env
	stage.add_child(we)
	Build.box(stage, Vector3(0, -0.1, 0), Vector3(30, 0.2, 12), Mat.tex("planks", Color(0.45, 0.42, 0.42)), false)
	Build.box(stage, Vector3(0, 2.0, -3.5), Vector3(30, 4.4, 0.3), Mat.tex("brick", Color(0.42, 0.4, 0.42)), false)
	Build.box(stage, Vector3(0, 1.5, -3.3), Vector3(2.2, 1.0, 0.05), Mat.tex("paper", Color(0.6, 0.58, 0.5), 1.0), false)
	Build.label(stage, Vector3(0, 3.3, -3.3), "RAVENWOOD", 96, Color(0.75, 0.72, 0.6))
	Build.light(stage, Vector3(0, 3.2, 1.5), Color(1.0, 0.8, 0.55), 2.2, 10.0)
	Build.light(stage, Vector3(-4, 2.0, 2.5), Color(0.5, 0.6, 1.0), 0.8, 8.0)
	for i in ItemDB.characters.size():
		var m := CharacterModel.create(ItemDB.characters[i])
		m.position = Vector3(-2.7 + i * 1.8, 0, 0)
		m.rotation.y = PI
		stage.add_child(m)
		_models.append(m)
	var cam := Camera3D.new()
	cam.fov = 40.0
	cam.position = Vector3(0, 1.45, 7.4)
	stage.add_child(cam)
	cam.look_at(Vector3(0, 1.15, 0))
	cam.current = true


func _process(delta: float) -> void:
	_t += delta
	for i in _models.size():
		var mine: bool = Net.lobby.get(Net.my_id(), {}).get("char", -1) == i
		_models[i].rotation.y = PI + sin(_t * 0.6 + i) * 0.12
		_models[i].position.z = lerpf(_models[i].position.z, 0.9 if mine else 0.0, delta * 5.0)


func _refresh() -> void:
	UIKit.clear(_players)
	for id in Net.lobby:
		var entry: Dictionary = Net.lobby[id]
		var who := tr(ItemDB.characters[entry["char"]]["name"]) if entry["char"] >= 0 else "..."
		var text := "%s - %s%s" % [entry["name"], who, "  " + tr("(host)") if id == 1 else ""]
		var l := UIKit.label(text, 16, UIKit.TEXT if id != Net.my_id() else Color(0.95, 0.9, 0.7))
		l.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
		_players.add_child(l)
	var my_char: int = Net.lobby.get(Net.my_id(), {}).get("char", -1)
	for i in _cards.size():
		var b: Button = _cards[i]
		var owner_name := ""
		for id in Net.lobby:
			if Net.lobby[id]["char"] == i and id != Net.my_id():
				owner_name = Net.lobby[id]["name"]
		if my_char == i:
			b.text = tr("Selected - click to release")
			b.disabled = false
		elif owner_name != "":
			b.text = tr("Taken by %s") % owner_name
			b.disabled = true
		else:
			b.text = tr("Select")
			b.disabled = false
	if Net.online:
		if Net.is_host():
			var ips := Net.local_ips()
			_info.text = tr("Hosting on port %d.\nYour LAN address: %s\nUp to %d players.") % [Settings.last_port, ", ".join(ips) if not ips.is_empty() else "127.0.0.1", Net.MAX_PLAYERS]
		else:
			_info.text = tr("Connected. Waiting for the host to start.") if not Net.dedicated else ""
	else:
		_info.text = tr("Single player. Pick a survivor and start.")
	if _start:
		_start.disabled = not Net.all_chosen()


func _on_pick(i: int) -> void:
	var my_char: int = Net.lobby.get(Net.my_id(), {}).get("char", -1)
	Net.request_char.rpc_id(1, -1 if my_char == i else i)


func _on_start() -> void:
	var slot: String = _slots[_save_option.selected]
	if slot == "":
		GameState.pending_load = {}
	elif slot != "__pending__":
		GameState.pending_load = SaveSystem.read(slot)
	Net.request_start.rpc_id(1)


func _on_leave() -> void:
	Net.leave()
	GameState.reset()
	SceneFlow.to_menu()
