extends GamePanel
## Four-digit code lock. The host checks the code.

var _lock_id := ""
var _code := ""
var _display: Label
var _hint: Label


func _ready() -> void:
	var vb := UIKit.window(self, "Code lock", Vector2(300, 0))
	_display = UIKit.label("_ _ _ _", 34, UIKit.AMBER)
	_display.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	_display.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vb.add_child(_display)
	var grid := GridContainer.new()
	grid.columns = 3
	vb.add_child(grid)
	for key in ["1", "2", "3", "4", "5", "6", "7", "8", "9", "C", "0", "OK"]:
		var b := UIKit.button(key, _press.bind(key))
		b.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
		b.custom_minimum_size = Vector2(88, 52)
		grid.add_child(b)
	_hint = UIKit.label("", 14, UIKit.DIM)
	_hint.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	_hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_hint.custom_minimum_size.x = 270
	vb.add_child(_hint)
	vb.add_child(UIKit.button("Close", func(): close_requested.emit(), 120))
	GameState.flag_changed.connect(func(key, _v):
		if visible and key == _lock_id + "_unlocked":
			close_requested.emit())


func open(args: Dictionary) -> void:
	_lock_id = args.get("id", "")
	_code = ""
	_hint.text = (tr("Heard on the radio: %s") % str(GameState.data["code"])) if GameState.flag("vl_code") else tr("Four digits. Someone must know them.")
	_update()


func _press(key: String) -> void:
	Audio.ui("keypad_beep", -8.0)
	if key == "C":
		_code = ""
	elif key == "OK":
		if _code.length() == 4:
			Actions.req_keypad.rpc_id(1, _lock_id, _code)
			_code = ""
	elif _code.length() < 4:
		_code += key
	_update()


func _update() -> void:
	var shown := []
	for i in 4:
		shown.append(_code[i] if i < _code.length() else "_")
	_display.text = " ".join(shown)
