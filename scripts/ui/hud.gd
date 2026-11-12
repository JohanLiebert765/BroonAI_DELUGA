class_name Hud
extends Control
## In-game HUD: health, stamina, flashlight, objective, compass, team, prompts, messages.

var _hp: ProgressBar
var _stamina: ProgressBar
var _flash: Label
var _objective: Label
var _prompt: Label
var _subtitle: Label
var _subtitle_box: PanelContainer
var _chapter: Label
var _chapter_sub: Label
var _team: VBoxContainer
var _toasts: VBoxContainer
var _compass: Compass
var _sub_serial := 0


class Compass:
	extends Control
	var heading := 0.0          # radians, clockwise from north (-Z)
	var markers: Array = []     # [{"bearing": float, "text": String, "color": Color}]

	func _draw() -> void:
		var w := size.x
		var font := get_theme_default_font()
		draw_rect(Rect2(Vector2.ZERO, size), Color(0.02, 0.02, 0.03, 0.6))
		draw_rect(Rect2(Vector2.ZERO, size), Color(0.4, 0.4, 0.38), false, 1.0)
		var span := deg_to_rad(110.0)
		for i in 24:
			var b := i * TAU / 24.0
			var rel := wrapf(b - heading, -PI, PI)
			if absf(rel) > span:
				continue
			var x := w * 0.5 + rel / span * w * 0.5
			var names := {0: "N", 6: "E", 12: "S", 18: "W"}
			if names.has(i):
				draw_string(font, Vector2(x - 5, 19), names[i], HORIZONTAL_ALIGNMENT_LEFT, -1, 15, UIKit.TEXT)
			else:
				draw_line(Vector2(x, 9), Vector2(x, 17), Color(0.5, 0.5, 0.48), 1.0)
		for m in markers:
			var rel := wrapf(m["bearing"] - heading, -PI, PI)
			var x := w * 0.5 + clampf(rel / span, -1.0, 1.0) * (w * 0.5 - 6.0)
			draw_string(font, Vector2(x - 5, size.y + 15), m["text"], HORIZONTAL_ALIGNMENT_LEFT, -1, 14, m["color"])
			draw_line(Vector2(x, size.y - 4), Vector2(x, size.y), m["color"], 2.0)
		draw_line(Vector2(w * 0.5, 0), Vector2(w * 0.5, 6), UIKit.RED, 2.0)


func _ready() -> void:
	theme = UIKit.theme()
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE

	var stats := GridContainer.new()
	stats.columns = 2
	stats.position = Vector2(18, 16)
	stats.add_theme_constant_override("h_separation", 10)
	add_child(stats)
	stats.add_child(UIKit.label("Health", 15))
	_hp = UIKit.bar(UIKit.RED)
	stats.add_child(_hp)
	stats.add_child(UIKit.label("Stamina", 15))
	_stamina = UIKit.bar(UIKit.GREEN)
	stats.add_child(_stamina)
	stats.add_child(UIKit.label("Flashlight", 15))
	_flash = UIKit.label("", 15)
	_flash.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	stats.add_child(_flash)

	_compass = Compass.new()
	_compass.custom_minimum_size = Vector2(360, 24)
	_compass.size = Vector2(360, 24)
	UIKit.place(_compass, Control.PRESET_CENTER_TOP, Vector2(0, 14))
	add_child(_compass)

	_team = VBoxContainer.new()
	_team.custom_minimum_size.x = 200
	_team.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	UIKit.place(_team, Control.PRESET_TOP_RIGHT, Vector2(-18, 16))
	add_child(_team)

	var obj_box := VBoxContainer.new()
	obj_box.custom_minimum_size = Vector2(360, 70)
	obj_box.grow_vertical = Control.GROW_DIRECTION_BEGIN
	UIKit.place(obj_box, Control.PRESET_BOTTOM_LEFT, Vector2(18, -18))
	add_child(obj_box)
	obj_box.add_child(UIKit.label("Objective:", 15, UIKit.AMBER))
	_objective = UIKit.label("", 16)
	_objective.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	_objective.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_objective.custom_minimum_size.x = 360
	obj_box.add_child(_objective)

	var dot := ColorRect.new()
	dot.color = Color(0.9, 0.9, 0.85, 0.7)
	dot.custom_minimum_size = Vector2(3, 3)
	UIKit.place(dot, Control.PRESET_CENTER)
	add_child(dot)

	_prompt = UIKit.label("", 18, Color(0.95, 0.92, 0.8))
	_prompt.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	_prompt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_prompt.custom_minimum_size.x = 600
	UIKit.place(_prompt, Control.PRESET_CENTER, Vector2(0, 52))
	_prompt.add_theme_color_override("font_outline_color", Color.BLACK)
	_prompt.add_theme_constant_override("outline_size", 5)
	add_child(_prompt)

	_toasts = VBoxContainer.new()
	_toasts.position = Vector2(18, 120)
	_toasts.custom_minimum_size.x = 460
	add_child(_toasts)

	_subtitle_box = PanelContainer.new()
	_subtitle_box.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_subtitle_box.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_subtitle_box.custom_minimum_size = Vector2(660, 0)
	UIKit.place(_subtitle_box, Control.PRESET_CENTER_BOTTOM, Vector2(0, -30))
	_subtitle_box.visible = false
	add_child(_subtitle_box)
	_subtitle = UIKit.label("", 18)
	_subtitle.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	_subtitle.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_subtitle.custom_minimum_size.x = 640
	_subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_subtitle_box.add_child(_subtitle)

	var card := VBoxContainer.new()
	card.grow_horizontal = Control.GROW_DIRECTION_BOTH
	card.custom_minimum_size = Vector2(800, 110)
	UIKit.place(card, Control.PRESET_CENTER, Vector2(0, -160))
	card.alignment = BoxContainer.ALIGNMENT_CENTER
	add_child(card)
	_chapter_sub = UIKit.label("", 20, UIKit.RED)
	_chapter_sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	card.add_child(_chapter_sub)
	_chapter = UIKit.label("", 46, Color(0.9, 0.87, 0.78))
	_chapter.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_chapter.add_theme_color_override("font_outline_color", Color.BLACK)
	_chapter.add_theme_constant_override("outline_size", 8)
	card.add_child(_chapter)
	card.modulate.a = 0.0

	GameState.message.connect(_toast)
	GameState.subtitle.connect(_show_subtitle)
	GameState.player_changed.connect(func(_p): _refresh_team())
	GameState.state_loaded.connect(_refresh_team)
	Quests.updated.connect(_refresh_objective)
	Settings.changed.connect(_refresh_objective)


func show_chapter(loc: int) -> void:
	var ch: Dictionary = Quests.chapter(loc)
	_chapter_sub.text = ch["number"]
	_chapter.text = ch["title"]
	var card: Control = _chapter.get_parent()
	var tw := create_tween()
	tw.tween_property(card, "modulate:a", 1.0, 1.2)
	tw.tween_interval(3.5)
	tw.tween_property(card, "modulate:a", 0.0, 1.5)


func _refresh_objective() -> void:
	_objective.text = Quests.current_text()


func _refresh_team() -> void:
	UIKit.clear(_team)
	for id in GameState.pdata:
		if id == GameState.my_id():
			continue
		var pd: Dictionary = GameState.pdata[id]
		var row := HBoxContainer.new()
		var name_label := UIKit.label("%s (%s)" % [pd["name"], tr(ItemDB.character(pd["char"])["name"])], 14)
		name_label.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
		name_label.custom_minimum_size.x = 120
		name_label.clip_text = true
		row.add_child(name_label)
		var b := UIKit.bar(UIKit.RED, Vector2(70, 8))
		b.max_value = pd["max_hp"]
		b.value = pd["hp"]
		b.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		row.add_child(b)
		_team.add_child(row)


func _toast(text: String, kind: String) -> void:
	var color := UIKit.TEXT
	match kind:
		"warn": color = UIKit.AMBER
		"good": color = Color(0.6, 0.8, 0.55)
	var l := UIKit.label(text, 16, color)
	l.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.custom_minimum_size.x = 460
	l.add_theme_color_override("font_outline_color", Color.BLACK)
	l.add_theme_constant_override("outline_size", 4)
	_toasts.add_child(l)
	while _toasts.get_child_count() > 6:
		var old := _toasts.get_child(0)
		_toasts.remove_child(old)
		old.queue_free()
	var tw := l.create_tween()
	tw.tween_interval(5.0)
	tw.tween_property(l, "modulate:a", 0.0, 1.0)
	tw.tween_callback(l.queue_free)


func _show_subtitle(speaker: String, text: String) -> void:
	_sub_serial += 1
	var serial := _sub_serial
	_subtitle.text = ("%s: %s" % [speaker, text]) if speaker != "" else text
	_subtitle_box.visible = true
	if speaker == tr("Radio"):
		Audio.ui("radio_blip", -8.0)
	await get_tree().create_timer(3.0 + text.length() * 0.045).timeout
	if serial == _sub_serial:
		_subtitle_box.visible = false


func _process(_delta: float) -> void:
	var me := GameState.me()
	if me.is_empty() or not is_instance_valid(GameState.local_player):
		return
	var p: Player = GameState.local_player
	_hp.max_value = me["max_hp"]
	_hp.value = me["hp"]
	_stamina.value = p.stamina
	var batteries := Inventory.count(me["inv"], "battery")
	if p.has_flashlight():
		var mode := tr("ON") if p.flash_on else tr("OFF")
		_flash.text = "%s  %d%%   %s x%d" % [mode, int(p.battery), tr("Battery"), batteries]
		_flash.add_theme_color_override("font_color", UIKit.AMBER if p.battery < 20.0 else UIKit.TEXT)
	else:
		_flash.text = tr("none")
	if p.hover and is_instance_valid(p.hover):
		_prompt.text = "[%s]  %s" % [Settings.key_name("interact"), p.hover.get_prompt()]
	else:
		_prompt.text = ""
	_compass.heading = -p.rotation.y + (randf_range(-3.0, 3.0) if p.disrupted > 0.0 else 0.0)
	var markers := []
	var pos := p.global_position
	if not GameState.scene.is_on_train(pos):
		markers.append({"bearing": atan2(11.0 - pos.x, pos.z), "text": "T", "color": Color(0.6, 0.8, 0.55)})
	var poi = GameState.get_flag("poi")
	if poi is Array and poi.size() == 2:
		markers.append({"bearing": atan2(poi[0] - pos.x, -(poi[1] - pos.z)), "text": "!", "color": UIKit.AMBER})
	_compass.markers = markers
	_compass.queue_redraw()
