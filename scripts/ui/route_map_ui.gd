extends GamePanel
## Route map: the line and its stops, the objectives of the current stop, the departure
## checklist, and the "set course" control for the next destination.

var _line: RouteLine
var _objectives: VBoxContainer
var _checks: VBoxContainer
var _course: Button
var _chapter: Label


class RouteLine:
	extends Control

	func _draw() -> void:
		var d: Dictionary = GameState.data
		if d.is_empty():
			return
		var font := get_theme_default_font()
		var n := Quests.stops.size()
		var loc := int(d["loc"])
		var pad := 50.0
		var step := (size.x - pad * 2.0) / float(n - 1)
		var y := 46.0
		draw_rect(Rect2(Vector2.ZERO, size), Color(0.05, 0.07, 0.1))
		for gx in range(0, int(size.x), 24):
			draw_line(Vector2(gx, 0), Vector2(gx, size.y), Color(0.09, 0.12, 0.16), 1.0)
		for gy in range(0, int(size.y), 24):
			draw_line(Vector2(0, gy), Vector2(size.x, gy), Color(0.09, 0.12, 0.16), 1.0)
		for i in n - 1:
			var done := i < loc
			draw_line(Vector2(pad + i * step, y), Vector2(pad + (i + 1) * step, y), Color(0.75, 0.72, 0.6) if done else Color(0.35, 0.35, 0.35), 2.0)
		for i in n:
			var p := Vector2(pad + i * step, y)
			var color := Color(0.75, 0.72, 0.6) if i <= loc else Color(0.4, 0.4, 0.4)
			if i == n - 1:
				color = UIKit.RED
			draw_circle(p, 7.0, Color(0.05, 0.07, 0.1))
			draw_arc(p, 7.0, 0, TAU, 16, color, 2.0)
			var text := tr(Quests.stops[i])
			var tw := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, 13).x
			draw_string(font, p + Vector2(-tw * 0.5, 30 + (16 if i % 2 == 1 else 0)), text, HORIZONTAL_ALIGNMENT_LEFT, -1, 13, color)
		var tx := pad + loc * step
		if d["traveling"]:
			tx += step * clampf(float(d["progress"]) / TrainSystem.LEG, 0.0, 1.0)
		draw_rect(Rect2(tx - 9, y - 22, 18, 10), UIKit.AMBER)
		draw_rect(Rect2(tx + 3, y - 27, 4, 6), UIKit.AMBER)


func _ready() -> void:
	var vb := UIKit.window(self, "Route map - Northern Vale Railway", Vector2(820, 0))
	_line = RouteLine.new()
	_line.custom_minimum_size = Vector2(800, 110)
	vb.add_child(_line)
	var hb := HBoxContainer.new()
	hb.add_theme_constant_override("separation", 24)
	vb.add_child(hb)
	var left := VBoxContainer.new()
	left.custom_minimum_size.x = 420
	hb.add_child(left)
	_chapter = UIKit.label("", 18, UIKit.AMBER)
	_chapter.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	left.add_child(_chapter)
	_objectives = VBoxContainer.new()
	left.add_child(_objectives)
	var right := VBoxContainer.new()
	right.custom_minimum_size.x = 340
	hb.add_child(right)
	right.add_child(UIKit.label("Departure checklist", 18, UIKit.AMBER))
	_checks = VBoxContainer.new()
	right.add_child(_checks)
	_course = UIKit.button("Set course", func(): Actions.req_set_course.rpc_id(1), 240)
	right.add_child(_course)
	vb.add_child(UIKit.button("Close", func(): close_requested.emit(), 120))
	GameState.flag_changed.connect(func(_k, _v): _refresh())
	GameState.train_changed.connect(_refresh)


func open(_args: Dictionary) -> void:
	_refresh()


func _check(box: VBoxContainer, ok: bool, text: String) -> void:
	var l := UIKit.label(("[x] " if ok else "[ ] ") + text, 15, UIKit.TEXT if ok else UIKit.DIM)
	l.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.custom_minimum_size.x = 330
	box.add_child(l)


func _refresh() -> void:
	if not visible or GameState.data.is_empty():
		return
	_line.queue_redraw()
	var d: Dictionary = GameState.data
	var t: Dictionary = d["train"]
	var loc := int(d["loc"])
	var ch: Dictionary = Quests.chapter()
	_chapter.text = "%s - %s" % [tr(ch["number"]), tr(ch["title"])]
	UIKit.clear(_objectives)
	for entry in Quests.objectives():
		var text := Quests.progress_text(entry["obj"])
		if entry["obj"].get("required", false):
			text += "  *"
		_check(_objectives, entry["done"], text)
	var note := UIKit.label("* required before the train can leave", 13, UIKit.DIM)
	_objectives.add_child(note)
	UIKit.clear(_checks)
	var next := "Hollowgate" if loc >= Quests.LOCS.size() - 1 else str(Quests.stops[loc + 1])
	var course := GameState.flag("course_%d" % loc)
	_check(_checks, Quests.blocking_objective() == "", tr("Required objectives complete"))
	_check(_checks, t["fuel"] >= TrainSystem.FUEL_TO_LEAVE, tr("Fuel at 30%% or more (now %d%%)") % int(t["fuel"]))
	_check(_checks, t["engine"] >= TrainSystem.ENGINE_TO_LEAVE, tr("Engine at 30%% or more (now %d%%)") % int(t["engine"]))
	_check(_checks, course, tr("Course set: %s") % tr(next))
	_check(_checks, false, tr("Everyone aboard, then pull the control lever"))
	_course.text = tr("Set course: %s") % tr(next)
	_course.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	_course.disabled = course or d["traveling"]
