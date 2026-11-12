class_name GamePanel
extends Control
## Base for in-game windows (inventory, crafting, map...). The Game node opens and closes them.

signal close_requested


func open(_args: Dictionary) -> void:
	pass


func closed() -> void:
	pass
