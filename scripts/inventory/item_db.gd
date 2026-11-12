extends Node
## Item, recipe and character definitions loaded from res://data.

var items := {}
var recipes: Array = []
var characters: Array = []
var _icons := {}


func _ready() -> void:
	items = _load("res://data/items.json", {})
	recipes = _load("res://data/recipes.json", [])
	characters = _load("res://data/characters.json", [])


func _load(path: String, fallback):
	var parsed = JSON.parse_string(FileAccess.get_file_as_string(path))
	if parsed == null:
		push_error("Cannot parse " + path)
		return fallback
	return parsed


func has(id: String) -> bool:
	return items.has(id)


func item_name(id: String) -> String:
	return items[id]["name"] if items.has(id) else id


func desc(id: String) -> String:
	return items[id]["desc"] if items.has(id) else ""


func stack(id: String) -> int:
	return int(items[id]["stack"]) if items.has(id) else 1


func color(id: String) -> Color:
	return Color(items[id]["color"]) if items.has(id) else Color.GRAY


func icon(id: String) -> Texture2D:
	if _icons.has(id):
		return _icons[id]
	var path := "res://assets/ui/icons/%s.png" % id
	var tex: Texture2D = null
	if ResourceLoader.exists(path):
		tex = load(path)
	else:
		var img := Image.create(32, 32, false, Image.FORMAT_RGBA8)
		img.fill(color(id))
		tex = ImageTexture.create_from_image(img)
	_icons[id] = tex
	return tex


func recipe(id: String) -> Dictionary:
	for r in recipes:
		if r["id"] == id:
			return r
	return {}


func character(idx: int) -> Dictionary:
	return characters[clampi(idx, 0, characters.size() - 1)]
