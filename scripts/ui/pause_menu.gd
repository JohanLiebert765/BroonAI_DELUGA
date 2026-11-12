extends GamePanel
## Pause menu: resume, save (host), settings, return to the main menu, quit.

signal leave_requested

var _main: Control
var _settings: SettingsPanel
var _saves: VBoxContainer
var _save_button: Button


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_main = Control.new()
	add_child(_main)
	var vb := UIKit.window(_main, "Paused", Vector2(340, 0))
	vb.add_child(UIKit.button("Resume", func(): close_requested.emit()))
	_save_button = UIKit.button("Save game", func(): _saves.visible = not _saves.visible)
	vb.add_child(_save_button)
	_saves = VBoxContainer.new()
	_saves.visible = false
	vb.add_child(_saves)
	vb.add_child(UIKit.button("Settings", func():
		_main.visible = false
		_settings.visible = true))
	vb.add_child(UIKit.button("Return to main menu", func(): leave_requested.emit()))
	vb.add_child(UIKit.button("Quit game", func(): get_tree().quit()))
	_settings = SettingsPanel.new()
	_settings.visible = false
	add_child(_settings)
	_settings.closed.connect(func():
		_settings.visible = false
		_main.visible = true)


func open(_args: Dictionary) -> void:
	_main.visible = true
	_settings.visible = false
	_saves.visible = false
	_save_button.disabled = not GameState.is_host()
	_save_button.text = "Save game" if GameState.is_host() else "Save game (host only)"
	_fill_saves()


func _fill_saves() -> void:
	UIKit.clear(_saves)
	for slot in ["slot1", "slot2", "slot3"]:
		var info := SaveSystem.info(slot)
		var text := tr(SaveSystem.SLOT_LABELS[slot])
		text += (" - %s, %s" % [tr(Quests.chapter(info["chapter"])["title"]), info["time"]]) if not info.is_empty() else (" - " + tr("empty"))
		var b := UIKit.button(text, _save.bind(slot))
		b.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
		_saves.add_child(b)


func _save(slot: String) -> void:
	var err := SaveSystem.save(slot)
	GameState.message.emit(tr(err) if err != "" else tr("Game saved."), "warn" if err != "" else "good")
	_fill_saves()
