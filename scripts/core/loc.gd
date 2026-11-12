extends Node
## Localisation. English strings are the keys; other languages live in data/lang_<code>.json.

const LANGS := {"en": "English", "ru": "Русский"}


func _ready() -> void:
	for code in LANGS:
		if code == "en":
			continue
		var path := "res://data/lang_%s.json" % code
		if not FileAccess.file_exists(path):
			continue
		var parsed = JSON.parse_string(FileAccess.get_file_as_string(path))
		if typeof(parsed) != TYPE_DICTIONARY:
			push_warning("Bad translation file: " + path)
			continue
		var t := Translation.new()
		t.locale = code
		for key in parsed:
			t.add_message(key, parsed[key])
		TranslationServer.add_translation(t)


## Translates key and fills in args. String args starting with "@" are translated too.
func fmt(key: String, args: Array = []) -> String:
	var text := tr(key)
	if args.is_empty():
		return text
	var out := []
	for a in args:
		if a is String and a.begins_with("@"):
			out.append(tr(a.substr(1)))
		else:
			out.append(a)
	return text % out
