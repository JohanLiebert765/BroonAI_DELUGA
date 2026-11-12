class_name Mechanism
extends Interactable
## Generic device: generator, fuse box, lever, valve, switch...
## Activation can require items (consumed), a tool (kept) and other flags.
## Flag `id` is true once activated (or toggles when once == false).

var needs := {}             # item id -> count, consumed on activation
var tool_item := ""
var need_flags: Array = []
var need_msg := "Nothing happens."
var done_msg := ""          # announced to everyone on activation
var once := true
var sets: Array = []        # additional flags set on activation
var count_flag := ""
var sound_name := "clunk"
var prompt_done := ""       # prompt shown once activated ("" hides the prompt)
var noise_radius := 9.0
var on_changed := Callable()   # func(active: bool) - visuals, called on every peer
var custom := Callable()       # func(peer: int) - replaces the default host logic


func get_prompt() -> String:
	if GameState.flag(id) and once:
		return tr(prompt_done)
	return tr(prompt)


func can_interact() -> bool:
	return active and (not once or not GameState.flag(id) or prompt_done != "")


func refresh() -> void:
	if on_changed.is_valid():
		on_changed.call(GameState.flag(id))


func server_interact(peer: int) -> void:
	if custom.is_valid():
		custom.call(peer)
		return
	var state := GameState.flag(id)
	if once and state:
		return
	if not state:
		for f in need_flags:
			if not GameState.flag(f):
				GameState.sound("error", global_position, -8.0, 12.0)
				GameState.notify(peer, need_msg, [], "warn")
				return
		if tool_item != "" and not GameState.has_item(peer, tool_item):
			GameState.notify(peer, "You need: %s", ["@" + ItemDB.item_name(tool_item)], "warn")
			return
		for item in needs:
			if not GameState.has_item(peer, item, int(needs[item])):
				GameState.notify(peer, "You need: %s", ["@" + ItemDB.item_name(item)], "warn")
				return
		for item in needs:
			GameState.take(peer, item, int(needs[item]))
	GameState.set_flag(id, not state)
	if not state:
		for f in sets:
			GameState.set_flag(f, true)
		if count_flag != "":
			GameState.inc_flag(count_flag)
		if done_msg != "":
			GameState.notify_all(done_msg, [], "good")
	GameState.sound(sound_name, global_position, -2.0, 24.0)
	GameState.scene.noise(global_position, noise_radius)
	GameState.scene.player_action(peer, "interact")
