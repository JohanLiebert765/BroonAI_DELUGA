class_name DocumentItem
extends Interactable
## A readable note. Reading opens the document viewer locally and logs it in the shared journal.

var doc := ""


func _ready() -> void:
	Build.box(self, Vector3(0, 0.012, 0), Vector3(0.26, 0.02, 0.36), Mat.tex("paper", Color(1, 1, 1), 2.0), false, Vector3(0, 14, 0))
	Build.box(self, Vector3(0.02, 0.03, 0.01), Vector3(0.24, 0.012, 0.34), Mat.tex("paper", Color(0.85, 0.82, 0.75), 2.0), false, Vector3(0, -8, 0))
	add_shape(Vector3(0.6, 0.4, 0.6), Vector3(0, 0.15, 0))
	super()


func get_prompt() -> String:
	return "%s: %s" % [tr("Read"), tr(Quests.documents[doc]["title"])]


func local_interact(_player: Node) -> void:
	GameState.fx.emit("read_doc", {"id": doc})


func server_interact(peer: int) -> void:
	if doc not in GameState.data["docs"]:
		GameState.notify_all("%s found a document: %s", [GameState.player_name(peer), "@" + Quests.documents[doc]["title"]], "good")
	GameState.found_doc(doc)
