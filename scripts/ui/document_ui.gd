extends GamePanel
## Document reader.

var _title: Label
var _text: RichTextLabel


func _ready() -> void:
	var vb := UIKit.window(self, "Document", Vector2(680, 0))
	_title = vb.get_child(0)
	var paper := PanelContainer.new()
	paper.add_theme_stylebox_override("panel", UIKit.box(Color(0.78, 0.74, 0.62), Color(0.4, 0.36, 0.28), 2, 18))
	vb.add_child(paper)
	_text = RichTextLabel.new()
	_text.custom_minimum_size = Vector2(640, 400)
	_text.add_theme_color_override("default_color", Color(0.12, 0.1, 0.08))
	_text.add_theme_font_size_override("normal_font_size", 17)
	_text.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	paper.add_child(_text)
	vb.add_child(UIKit.button("Close", func(): close_requested.emit(), 120))


func open(args: Dictionary) -> void:
	var doc: Dictionary = Quests.documents.get(args.get("id", ""), {})
	_title.text = doc.get("title", "Document")
	_text.text = tr(doc.get("text", ""))
	_text.scroll_to_line(0)
	Audio.ui("pickup", -12.0)
