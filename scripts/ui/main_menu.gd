extends Control
## Main menu: continue / new game / load, LAN multiplayer (host or join), settings, credits.

const CREDITS := "GHOST TRAIN: THE LAST ROUTE\n\nDesign, code, models, textures, sound and music:\nmade for this project, generated procedurally (see tools/).\nAll original assets are released under CC0.\n\nBuilt with Godot Engine 4 (MIT licence).\nGodot Engine (c) Juan Linietsky, Ariel Manzur and contributors.\n\nNo third-party assets are used. See assets/LICENSES.md."

var _pages := {}
var _status: Label
var _name_edit: LineEdit
var _port_edit: LineEdit
var _ip_edit: LineEdit
var _join_port_edit: LineEdit
var _load_list: VBoxContainer
var _continue: Button
var _settings: SettingsPanel


func _ready() -> void:
	theme = UIKit.theme()
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	get_tree().paused = false
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	Net.leave()
	GameState.reset()
	var view := Ps1View.new()
	add_child(view)
	view.sub.add_child(MenuBackdrop.new())
	Audio.music("menu_theme_loop", -7.0)
	Audio.ambient("wind_loop", -16.0)

	var shade := ColorRect.new()
	shade.color = Color(0, 0, 0, 0.35)
	shade.custom_minimum_size.x = 470
	shade.set_anchors_and_offsets_preset(Control.PRESET_LEFT_WIDE, Control.PRESET_MODE_MINSIZE)
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(shade)

	var title := VBoxContainer.new()
	title.position = Vector2(48, 40)
	add_child(title)
	var t1 := UIKit.label("GHOST TRAIN", 64, Color(0.86, 0.84, 0.78))
	t1.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	t1.add_theme_color_override("font_outline_color", Color.BLACK)
	t1.add_theme_constant_override("outline_size", 6)
	title.add_child(t1)
	var t2 := UIKit.label("—  THE LAST ROUTE", 28, UIKit.RED)
	t2.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	title.add_child(t2)

	_page("main", [
		["Continue", _on_continue], ["New Game", _on_new_game], ["Load Game", func(): _show("load")],
		["Multiplayer", func(): _show("multi")], ["Settings", _open_settings], ["Credits", func(): _show("credits")],
		["Exit", func(): get_tree().quit()],
	])
	_continue = _pages["main"].get_child(0)
	_build_load()
	_build_multi()
	_build_credits()

	_status = UIKit.label("", 16, UIKit.AMBER)
	_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_status.custom_minimum_size.x = 420
	_status.grow_vertical = Control.GROW_DIRECTION_BEGIN
	UIKit.place(_status, Control.PRESET_BOTTOM_LEFT, Vector2(48, -56))
	add_child(_status)
	var version := UIKit.label("v1.0  -  LAN co-op for 1-4 players  -  works offline", 13, UIKit.DIM)
	UIKit.place(version, Control.PRESET_BOTTOM_LEFT, Vector2(48, -20))
	add_child(version)

	_settings = SettingsPanel.new()
	_settings.visible = false
	add_child(_settings)
	_settings.closed.connect(func():
		_settings.visible = false
		_show("main"))

	Net.connection_failed.connect(_on_net_error)
	Net.joined.connect(func(): SceneFlow.goto(SceneFlow.LOBBY))
	_show("main")
	if SceneFlow.menu_message != "":
		_status.text = SceneFlow.menu_message
		SceneFlow.menu_message = ""


func _page(key: String, entries: Array) -> VBoxContainer:
	var vb := VBoxContainer.new()
	vb.position = Vector2(48, 190)
	vb.custom_minimum_size.x = 300
	vb.add_theme_constant_override("separation", 6)
	add_child(vb)
	for e in entries:
		var b := UIKit.button(e[0], e[1], 300)
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.add_theme_font_size_override("font_size", 20)
		vb.add_child(b)
	_pages[key] = vb
	return vb


func _show(key: String) -> void:
	for k in _pages:
		_pages[k].visible = k == key
	_continue.disabled = not SaveSystem.has_any()
	if key == "load":
		_fill_load()
	if key != "multi":
		_status.text = ""


func _open_settings() -> void:
	for k in _pages:
		_pages[k].visible = false
	_settings.visible = true


func _field(parent: Control, caption: String, value: String, width := 300.0) -> LineEdit:
	parent.add_child(UIKit.label(caption, 15, UIKit.DIM))
	var e := LineEdit.new()
	e.text = value
	e.custom_minimum_size.x = width
	e.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	parent.add_child(e)
	return e


func _build_load() -> void:
	var vb := _page("load", [])
	vb.add_child(UIKit.label("Load Game", 22, UIKit.AMBER))
	_load_list = VBoxContainer.new()
	vb.add_child(_load_list)
	vb.add_child(UIKit.button("Back", func(): _show("main"), 300))


func _fill_load() -> void:
	UIKit.clear(_load_list)
	for slot in SaveSystem.SLOTS:
		var info := SaveSystem.info(slot)
		var text := tr(SaveSystem.SLOT_LABELS[slot])
		if info.is_empty():
			text += " - " + tr("empty")
		else:
			text += " - %s, %s" % [tr(Quests.chapter(info["chapter"])["title"]), info["time"]]
		var b := UIKit.button(text, _load_slot.bind(slot), 400)
		b.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.disabled = info.is_empty()
		_load_list.add_child(b)


func _build_multi() -> void:
	var vb := _page("multi", [])
	vb.add_child(UIKit.label("Multiplayer (LAN)", 22, UIKit.AMBER))
	_name_edit = _field(vb, "Your name", Settings.player_name)
	_name_edit.max_length = 16
	vb.add_child(UIKit.label("Create Game", 18))
	_port_edit = _field(vb, "Port", str(Settings.last_port))
	vb.add_child(UIKit.button("Host Game", _on_host, 300))
	vb.add_child(UIKit.label("Join Game", 18))
	_ip_edit = _field(vb, "Host IP address", Settings.last_ip)
	_join_port_edit = _field(vb, "Port", str(Settings.last_port))
	vb.add_child(UIKit.button("Join Game", _on_join, 300))
	vb.add_child(UIKit.button("Back", func(): _show("main"), 300))


func _build_credits() -> void:
	var vb := _page("credits", [])
	var l := UIKit.label(CREDITS, 15)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.custom_minimum_size.x = 400
	vb.add_child(l)
	var endings := UIKit.label("%s: %d / %d" % [tr("Endings discovered"), SaveSystem.endings_unlocked().size(), Quests.endings.size()], 15, UIKit.AMBER)
	endings.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	vb.add_child(endings)
	vb.add_child(UIKit.button("Back", func(): _show("main"), 300))


# --- actions --------------------------------------------------------------------

func _save_name() -> void:
	var n := _name_edit.text.strip_edges()
	Settings.player_name = n if n != "" else "Survivor"
	Settings.save_settings()


func _on_new_game() -> void:
	GameState.pending_load = {}
	Net.start_single()
	SceneFlow.goto(SceneFlow.LOBBY)


func _on_continue() -> void:
	_load_slot(SaveSystem.latest())


func _load_slot(slot: String) -> void:
	var payload := SaveSystem.read(slot)
	if payload.is_empty():
		_status.text = tr("That save cannot be read.")
		return
	GameState.pending_load = payload
	Net.start_single()
	SceneFlow.goto(SceneFlow.LOBBY)


func _port(edit: LineEdit) -> int:
	var p := int(edit.text)
	return p if p >= 1024 and p <= 65535 else -1


func _on_host() -> void:
	_save_name()
	var port := _port(_port_edit)
	if port < 0:
		_status.text = tr("Enter a port between 1024 and 65535.")
		return
	GameState.pending_load = {}
	var err := Net.host(port)
	if err != OK:
		_status.text = tr("Could not open port %d. It may already be in use.") % port
		return
	Settings.last_port = port
	Settings.save_settings()
	SceneFlow.goto(SceneFlow.LOBBY)


func _on_join() -> void:
	_save_name()
	var port := _port(_join_port_edit)
	var ip := _ip_edit.text.strip_edges()
	if port < 0 or ip == "":
		_status.text = tr("Enter the host's IP address and a valid port.")
		return
	var err := Net.join(ip, port)
	if err != OK:
		_status.text = tr("Could not start the connection. Check the address.")
		return
	Settings.last_ip = ip
	Settings.last_port = port
	Settings.save_settings()
	_status.text = tr("Connecting to %s:%d ...") % [ip, port]


func _on_net_error(reason: String) -> void:
	_status.text = tr(reason)
	_show("multi")
