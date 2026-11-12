class_name SettingsPanel
extends Control
## Settings window shared by the main menu and the pause menu. Changes apply and save at once.

signal closed

var _listening := ""
var _key_buttons := {}
var _built := false


func _ready() -> void:
	_build()


func _build() -> void:
	UIKit.clear(self)
	var vb := UIKit.window(self, "Settings", Vector2(720, 0))
	var cols := HBoxContainer.new()
	cols.add_theme_constant_override("separation", 28)
	vb.add_child(cols)
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 14)
	grid.add_theme_constant_override("v_separation", 8)
	cols.add_child(grid)

	_slider(grid, "Music volume", Settings.music_volume, 0.0, 1.0, func(v): Settings.music_volume = v)
	_slider(grid, "Sound effects volume", Settings.sfx_volume, 0.0, 1.0, func(v): Settings.sfx_volume = v)
	_slider(grid, "Ambient volume", Settings.ambient_volume, 0.0, 1.0, func(v): Settings.ambient_volume = v)
	_slider(grid, "Mouse sensitivity", Settings.mouse_sensitivity, 0.2, 3.0, func(v): Settings.mouse_sensitivity = v)

	var res_names := []
	for r in Settings.RESOLUTIONS:
		res_names.append("%d x %d" % [r.x, r.y])
	_option(grid, "Resolution", res_names, Settings.resolution, func(i): Settings.resolution = i, false)
	_option(grid, "Graphics quality", Settings.QUALITY_NAMES, Settings.quality, func(i): Settings.quality = i, true)
	var codes := Loc.LANGS.keys()
	var names := []
	for c in codes:
		names.append(Loc.LANGS[c])
	_option(grid, "Interface language", names, maxi(0, codes.find(Settings.language)), func(i): Settings.language = codes[i], false)
	_check(grid, "Fullscreen", Settings.fullscreen, func(on): Settings.fullscreen = on)
	_check(grid, "Invert mouse Y", Settings.invert_y, func(on): Settings.invert_y = on)

	var keys := VBoxContainer.new()
	cols.add_child(keys)
	keys.add_child(UIKit.label("Controls (click to rebind)", 16, UIKit.AMBER))
	var kgrid := GridContainer.new()
	kgrid.columns = 2
	kgrid.add_theme_constant_override("h_separation", 14)
	keys.add_child(kgrid)
	_key_buttons.clear()
	for action in Settings.DEFAULT_KEYS:
		kgrid.add_child(UIKit.label(Settings.ACTION_LABELS[action], 15))
		var b := UIKit.button(Settings.key_name(action), _listen.bind(action), 130)
		b.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
		kgrid.add_child(b)
		_key_buttons[action] = b
	keys.add_child(UIKit.button("Reset controls", _reset_keys, 200))
	vb.add_child(UIKit.button("Back", func(): closed.emit(), 120))
	_built = true


func _commit() -> void:
	Settings.save_settings()
	Settings.apply()


func _slider(grid: GridContainer, text: String, value: float, lo: float, hi: float, setter: Callable) -> void:
	grid.add_child(UIKit.label(text, 16))
	var s := HSlider.new()
	s.min_value = lo
	s.max_value = hi
	s.step = 0.01
	s.value = value
	s.custom_minimum_size = Vector2(200, 20)
	s.focus_mode = Control.FOCUS_NONE
	s.value_changed.connect(func(v):
		setter.call(v)
		_commit())
	grid.add_child(s)


func _option(grid: GridContainer, text: String, items: Array, selected: int, setter: Callable, translate: bool) -> void:
	grid.add_child(UIKit.label(text, 16))
	var o := OptionButton.new()
	o.focus_mode = Control.FOCUS_NONE
	if not translate:
		o.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	for it in items:
		o.add_item(it)
	o.select(selected)
	o.item_selected.connect(func(i):
		setter.call(i)
		_commit())
	grid.add_child(o)


func _check(grid: GridContainer, text: String, value: bool, setter: Callable) -> void:
	grid.add_child(UIKit.label(text, 16))
	var c := CheckBox.new()
	c.button_pressed = value
	c.focus_mode = Control.FOCUS_NONE
	c.toggled.connect(func(on):
		setter.call(on)
		_commit())
	grid.add_child(c)


func _listen(action: String) -> void:
	_listening = action
	_key_buttons[action].text = "..."


func _refresh_keys() -> void:
	for action in _key_buttons:
		_key_buttons[action].text = Settings.key_name(action)


func _input(event: InputEvent) -> void:
	if _listening == "" or not is_visible_in_tree():
		return
	if event is InputEventKey and event.pressed and not event.echo:
		get_viewport().set_input_as_handled()
		if event.keycode != KEY_ESCAPE:
			Settings.rebind(_listening, event.physical_keycode if event.physical_keycode != 0 else event.keycode)
		_listening = ""
		_refresh_keys()


func _reset_keys() -> void:
	Settings.reset_keys()
	_refresh_keys()
