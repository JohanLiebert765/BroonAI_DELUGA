extends GamePanel
## Workbench / medical station crafting. Shows every recipe of the station, what it needs,
## what the player has, and asks the host to craft.

var _station := ""
var _station_id := ""
var _recipe := {}
var _list: VBoxContainer
var _icon: TextureRect
var _name: Label
var _desc: Label
var _needs: VBoxContainer
var _status: Label
var _craft: Button
var _title: Label


func _ready() -> void:
	var vb := UIKit.window(self, "Crafting", Vector2(760, 0))
	_title = vb.get_child(0)
	var hb := HBoxContainer.new()
	hb.add_theme_constant_override("separation", 16)
	vb.add_child(hb)
	_list = VBoxContainer.new()
	_list.custom_minimum_size = Vector2(260, 320)
	hb.add_child(_list)
	var detail := VBoxContainer.new()
	detail.custom_minimum_size = Vector2(420, 320)
	hb.add_child(detail)
	_icon = TextureRect.new()
	_icon.custom_minimum_size = Vector2(80, 80)
	_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	detail.add_child(_icon)
	_name = UIKit.label("", 20, Color(0.92, 0.88, 0.74))
	detail.add_child(_name)
	_desc = UIKit.label("", 15, UIKit.DIM)
	_desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_desc.custom_minimum_size.x = 400
	detail.add_child(_desc)
	detail.add_child(UIKit.label("Materials:", 15, UIKit.AMBER))
	_needs = VBoxContainer.new()
	detail.add_child(_needs)
	_status = UIKit.label("", 15, UIKit.AMBER)
	detail.add_child(_status)
	_craft = UIKit.button("Craft", _on_craft, 140)
	detail.add_child(_craft)
	vb.add_child(UIKit.button("Close", func(): close_requested.emit(), 120))
	GameState.player_changed.connect(func(_p): _refresh())


func open(args: Dictionary) -> void:
	_station = args.get("station", "workbench")
	_station_id = args.get("id", "")
	_title.text = "Workbench" if _station == "workbench" else "Medical station"
	UIKit.clear(_list)
	_recipe = {}
	for r in ItemDB.recipes:
		if r["station"] != _station:
			continue
		if _recipe.is_empty():
			_recipe = r
		var b := UIKit.button(ItemDB.item_name(r["result"]), _select.bind(r))
		b.icon = ItemDB.icon(r["result"])
		b.expand_icon = true
		b.custom_minimum_size.y = 40
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		_list.add_child(b)
	_refresh()


func _select(r: Dictionary) -> void:
	_recipe = r
	_refresh()


func _refresh() -> void:
	if not visible or _recipe.is_empty():
		return
	var inv: Array = GameState.me().get("inv", [])
	_icon.texture = ItemDB.icon(_recipe["result"])
	_name.text = ItemDB.item_name(_recipe["result"])
	_desc.text = _recipe["desc"]
	UIKit.clear(_needs)
	for id in _recipe["needs"]:
		var have := Inventory.count(inv, id)
		var need := int(_recipe["needs"][id])
		var l := UIKit.label("%s  %d / %d" % [tr(ItemDB.item_name(id)), have, need], 15, UIKit.GREEN if have >= need else UIKit.RED)
		l.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
		_needs.add_child(l)
	var tool: String = _recipe.get("tool", "")
	if tool != "":
		var ok := Inventory.count(inv, tool) > 0
		var l := UIKit.label("%s: %s" % [tr("Tool"), tr(ItemDB.item_name(tool))], 15, UIKit.GREEN if ok else UIKit.RED)
		l.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
		_needs.add_child(l)
	var problem := Crafting.check(inv, _recipe)
	_status.text = problem
	_craft.disabled = problem != ""


func _on_craft() -> void:
	if not _recipe.is_empty():
		Actions.req_craft.rpc_id(1, _recipe["id"], _station_id)
