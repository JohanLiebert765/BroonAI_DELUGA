class_name Crafting
## Recipe checks shared by the crafting UI (availability) and the host (validation).


## Returns "" if the recipe can be crafted from slots, otherwise the reason.
static func check(slots: Array, recipe: Dictionary) -> String:
	if not Inventory.has_all(slots, recipe["needs"]):
		return "Not enough materials."
	var tool: String = recipe.get("tool", "")
	if tool != "" and Inventory.count(slots, tool) < 1:
		return "You need the right tool."
	var trial: Array = slots.duplicate(true)
	_consume(trial, recipe)
	if Inventory.add(trial, recipe["result"], int(recipe["count"])) > 0:
		return "No room in the inventory."
	return ""


static func apply(slots: Array, recipe: Dictionary) -> void:
	_consume(slots, recipe)
	Inventory.add(slots, recipe["result"], int(recipe["count"]))


static func _consume(slots: Array, recipe: Dictionary) -> void:
	for id in recipe["needs"]:
		Inventory.remove(slots, id, int(recipe["needs"][id]))
