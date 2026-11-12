extends GamePanel
## Ending sequence: the conclusion text line by line, the run's statistics, back to the menu.

signal leave_requested

var _vb: VBoxContainer


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	theme = UIKit.theme()
	var bg := ColorRect.new()
	bg.color = Color(0, 0, 0, 0.93)
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	_vb = VBoxContainer.new()
	_vb.custom_minimum_size.x = 760
	_vb.add_theme_constant_override("separation", 12)
	center.add_child(_vb)


func open(args: Dictionary) -> void:
	UIKit.clear(_vb)
	var ending: Dictionary = Quests.endings[args["id"]]
	var stats: Dictionary = args.get("stats", {})
	var kind := UIKit.label(ending["kind"], 18, UIKit.RED)
	kind.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_vb.add_child(kind)
	var title := UIKit.label(ending["title"], 48, Color(0.92, 0.88, 0.76))
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_vb.add_child(title)
	var lines := []
	for line in ending["text"]:
		var l := UIKit.label(line, 19)
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		l.custom_minimum_size.x = 760
		l.modulate.a = 0.0
		_vb.add_child(l)
		lines.append(l)
	var minutes := int(float(stats.get("time", 0.0)) / 60.0)
	var summary := UIKit.label("%s: %d   %s: %d / %d   %s: %d" % [tr("Minutes on the line"), minutes, tr("Documents found"), int(stats.get("docs", 0)), Quests.documents.size(), tr("Collapses"), int(stats.get("collapses", 0))], 15, UIKit.DIM)
	summary.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	summary.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	summary.modulate.a = 0.0
	_vb.add_child(summary)
	var unlocked := UIKit.label("%s: %d / %d" % [tr("Endings discovered"), SaveSystem.endings_unlocked().size(), Quests.endings.size()], 15, UIKit.DIM)
	unlocked.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	unlocked.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	unlocked.modulate.a = 0.0
	_vb.add_child(unlocked)
	var back := UIKit.button("Return to main menu", func(): leave_requested.emit(), 260)
	back.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	back.modulate.a = 0.0
	_vb.add_child(back)
	var tw := create_tween()
	tw.tween_interval(1.0)
	for l in lines:
		tw.tween_property(l, "modulate:a", 1.0, 1.2)
		tw.tween_interval(2.2)
	tw.tween_property(summary, "modulate:a", 1.0, 0.8)
	tw.tween_property(unlocked, "modulate:a", 1.0, 0.8)
	tw.tween_property(back, "modulate:a", 1.0, 0.8)
