extends GamePanel
## Inventory (grid slots, details, use / drop / move), the shared journal of documents,
## and - when opened from a train stash - a second grid to store and take items.

const SLOT := Vector2(72, 72)

var _stash_id := ""
var _selected := -1
var _grid: GridContainer
var _stash_box: VBoxContainer
var _stash_grid: GridContainer
var _stash_title: Label
var _icon: TextureRect
var _name: Label
var _desc: Label
var _use: Button
var _drop: Button
var _store: Button
var _docs: VBoxContainer
var _items_page: Control
var _docs_page: Control


func _ready() -> void:
	var vb := UIKit.window(self, "Inventory", Vector2(760, 0))
	var tabs := HBoxContainer.new()
	vb.add_child(tabs)
	tabs.add_child(UIKit.button("Items", func(): _show_page(true), 120))
	tabs.add_child(UIKit.button("Documents", func(): _show_page(false), 120))

	_items_page = HBoxContainer.new()
	_items_page.add_theme_constant_override("separation", 16)
	vb.add_child(_items_page)
	var left := VBoxContainer.new()
	_items_page.add_child(left)
	_grid = GridContainer.new()
	_grid.columns = 4
	left.add_child(_grid)
	_stash_box = VBoxContainer.new()
	left.add_child(_stash_box)
	_stash_title = UIKit.label("", 16, UIKit.AMBER)
	_stash_box.add_child(_stash_title)
	_stash_grid = GridContainer.new()
	_stash_grid.columns = 8
	_stash_box.add_child(_stash_grid)

	var detail := VBoxContainer.new()
	detail.custom_minimum_size = Vector2(300, 300)
	_items_page.add_child(detail)
	_icon = TextureRect.new()
	_icon.custom_minimum_size = Vector2(96, 96)
	_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	detail.add_child(_icon)
	_name = UIKit.label("", 20, Color(0.92, 0.88, 0.74))
	detail.add_child(_name)
	_desc = UIKit.label("", 15, UIKit.DIM)
	_desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_desc.custom_minimum_size = Vector2(300, 90)
	detail.add_child(_desc)
	var buttons := HBoxContainer.new()
	detail.add_child(buttons)
	_use = UIKit.button("Use", _on_use, 90)
	_drop = UIKit.button("Drop", _on_drop, 90)
	_store = UIKit.button("Store", _on_store, 90)
	buttons.add_child(_use)
	buttons.add_child(_drop)
	buttons.add_child(_store)

	_docs_page = ScrollContainer.new()
	_docs_page.custom_minimum_size = Vector2(700, 340)
	_docs_page.visible = false
	vb.add_child(_docs_page)
	_docs = VBoxContainer.new()
	_docs.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_docs_page.add_child(_docs)

	var hint := UIKit.label("Click a slot to select it, click another slot to move or merge. Stash slots are taken with one click.", 13, UIKit.DIM)
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vb.add_child(hint)
	vb.add_child(UIKit.button("Close", func(): close_requested.emit(), 120))

	GameState.player_changed.connect(func(_p): _refresh())
	GameState.stash_changed.connect(_refresh)
	GameState.docs_changed.connect(_refresh_docs)


func open(args: Dictionary) -> void:
	_stash_id = args.get("stash", "")
	_selected = -1
	_show_page(true)
	_refresh()
	_refresh_docs()


func _show_page(items: bool) -> void:
	_items_page.visible = items
	_docs_page.visible = not items


func _slot_button(slot, selected: bool, on_press: Callable, size := SLOT) -> Button:
	var b := Button.new()
	b.custom_minimum_size = size
	b.focus_mode = Control.FOCUS_NONE
	b.expand_icon = true
	b.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
	b.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	if selected:
		b.add_theme_stylebox_override("normal", UIKit.box(Color(0.25, 0.1, 0.08), UIKit.AMBER, 2, 6))
	if slot != null:
		b.icon = ItemDB.icon(slot["id"])
		b.tooltip_text = tr(ItemDB.item_name(slot["id"]))
		if int(slot["n"]) > 1:
			var n := UIKit.label("x%d" % int(slot["n"]), 14, Color.WHITE)
			n.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
			n.grow_horizontal = Control.GROW_DIRECTION_BEGIN
			n.grow_vertical = Control.GROW_DIRECTION_BEGIN
			UIKit.place(n, Control.PRESET_BOTTOM_RIGHT, Vector2(-5, -2))
			n.mouse_filter = Control.MOUSE_FILTER_IGNORE
			b.add_child(n)
	b.pressed.connect(on_press)
	return b


func _refresh() -> void:
	if not visible:
		return
	var inv: Array = GameState.me().get("inv", [])
	if _selected >= inv.size() or (_selected >= 0 and inv[_selected] == null):
		_selected = -1
	UIKit.clear(_grid)
	for i in inv.size():
		_grid.add_child(_slot_button(inv[i], i == _selected, _on_slot.bind(i)))
	var has_stash: bool = _stash_id != "" and GameState.data["stash"].has(_stash_id)
	_stash_box.visible = has_stash
	_store.visible = has_stash
	if has_stash:
		_stash_title.text = "Supply crate (shared)" if _stash_id == "cargo" else "Medicine cabinet (shared)"
		UIKit.clear(_stash_grid)
		var stash: Array = GameState.data["stash"][_stash_id]
		for i in stash.size():
			_stash_grid.add_child(_slot_button(stash[i], false, _on_stash_slot.bind(i), Vector2(48, 48)))
	var s = inv[_selected] if _selected >= 0 else null
	_icon.texture = ItemDB.icon(s["id"]) if s != null else null
	_name.text = ItemDB.item_name(s["id"]) if s != null else "Select an item"
	_desc.text = ItemDB.desc(s["id"]) if s != null else ""
	_use.disabled = s == null
	_drop.disabled = s == null
	_store.disabled = s == null


func _refresh_docs() -> void:
	if _docs == null:
		return
	UIKit.clear(_docs)
	var found: Array = GameState.data.get("docs", [])
	if found.is_empty():
		_docs.add_child(UIKit.label("No documents found yet.", 15, UIKit.DIM))
	for id in found:
		var doc: Dictionary = Quests.documents[id]
		var b := UIKit.button(doc["title"], func(): GameState.fx.emit("read_doc", {"id": id}))
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		_docs.add_child(b)


func _on_slot(i: int) -> void:
	Audio.ui("ui_click", -12.0)
	var inv: Array = GameState.me().get("inv", [])
	if _selected == -1:
		if inv[i] != null:
			_selected = i
	elif _selected == i:
		_selected = -1
	else:
		Actions.req_move.rpc_id(1, _selected, i)
		_selected = -1
	_refresh()


func _on_stash_slot(i: int) -> void:
	Audio.ui("pickup", -10.0)
	Actions.req_stash.rpc_id(1, _stash_id, false, i)


func _on_use() -> void:
	if _selected >= 0:
		Actions.req_use.rpc_id(1, _selected)


func _on_drop() -> void:
	if _selected >= 0:
		Actions.req_drop.rpc_id(1, _selected)
		_selected = -1


func _on_store() -> void:
	if _selected >= 0 and _stash_id != "":
		Actions.req_stash.rpc_id(1, _stash_id, true, _selected)
		_selected = -1
