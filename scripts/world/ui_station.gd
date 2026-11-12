class_name UiStation
extends Interactable
## Interactable that only opens a local UI panel (workbench, route map, stash...).
## The panel itself sends validated requests to the host.

var ui := ""
var station := ""


func _init() -> void:
	super()
	networked = false


func local_interact(_player: Node) -> void:
	GameState.fx.emit("open_ui", {"ui": ui, "id": id, "station": station})
