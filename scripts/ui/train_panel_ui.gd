extends GamePanel
## The locomotive's instrument panel: every train parameter and the current running state.

const ROWS := [["fuel", "Fuel"], ["engine", "Engine"], ["electric", "Electrics"], ["systems", "Running gear"], ["temp", "Boiler temperature"], ["pressure", "Steam pressure"]]

var _bars := {}
var _values := {}
var _state: Label
var _lights: Label


func _ready() -> void:
	var vb := UIKit.window(self, "Instrument panel", Vector2(520, 0))
	var grid := GridContainer.new()
	grid.columns = 3
	grid.add_theme_constant_override("h_separation", 12)
	vb.add_child(grid)
	for row in ROWS:
		grid.add_child(UIKit.label(row[1], 16))
		var b := UIKit.bar(UIKit.GREEN, Vector2(240, 14))
		b.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		grid.add_child(b)
		var v := UIKit.label("", 16)
		v.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
		v.custom_minimum_size.x = 60
		grid.add_child(v)
		_bars[row[0]] = b
		_values[row[0]] = v
	_lights = UIKit.label("", 16)
	_lights.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	vb.add_child(_lights)
	_state = UIKit.label("", 16, UIKit.AMBER)
	_state.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	_state.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_state.custom_minimum_size.x = 480
	vb.add_child(_state)
	var help := UIKit.label("Fuel: firebox. Engine: service hatch in the cab. Electrics and running gear: workshop car. Overheating: vent the steam valve.", 13, UIKit.DIM)
	help.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	help.custom_minimum_size.x = 480
	vb.add_child(help)
	vb.add_child(UIKit.button("Close", func(): close_requested.emit(), 120))
	GameState.train_changed.connect(_refresh)


func open(_args: Dictionary) -> void:
	_refresh()


func _refresh() -> void:
	if not visible or GameState.data.is_empty():
		return
	var d: Dictionary = GameState.data
	var t: Dictionary = d["train"]
	for row in ROWS:
		var key: String = row[0]
		var value: float = TrainSystem.pressure(d) if key == "pressure" else t[key]
		var bad: bool = value >= 85.0 if key == "temp" or key == "pressure" else value < 30.0
		_bars[key].value = clampf(value, 0.0, 100.0) if key != "temp" else clampf(value - 20.0, 0.0, 100.0)
		_bars[key].add_theme_stylebox_override("fill", UIKit.box(UIKit.RED if bad else UIKit.GREEN, Color.BLACK, 0, 0))
		_values[key].text = ("%d°" % int(value)) if key == "temp" else ("%d%%" % int(value))
	_lights.text = "%s: %s" % [tr("Carriage lights"), tr("ON") if t["lights"] and t["electric"] >= 10.0 else tr("OFF")]
	if not d["traveling"]:
		_state.text = tr("Stopped at: %s") % tr(Quests.stops[int(d["loc"])])
	elif d["halted"]:
		_state.text = tr("HALTED between stops. Fix the cause, then pull the lever.")
	else:
		_state.text = "%s  %d%%   %s: %s" % [tr("Under way."), int(d["progress"]), tr("Throttle"), tr("FULL") if int(d["throttle"]) >= 2 else tr("SLOW")]
