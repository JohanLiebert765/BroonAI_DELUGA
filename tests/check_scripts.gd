extends SceneTree
## Loads every script and scene in the project and reports the ones that fail to compile.
## Run: godot --headless --path . -s tests/check_scripts.gd


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var failed := 0
	var count := 0
	for path in _walk("res://scripts") + _walk("res://scenes"):
		count += 1
		var res = load(path)
		if res == null or (res is GDScript and not res.can_instantiate()):
			failed += 1
			print("FAILED: ", path)
	print("checked %d files, %d failed" % [count, failed])
	quit(1 if failed > 0 else 0)


func _walk(dir: String) -> Array:
	var out := []
	var d := DirAccess.open(dir)
	if d == null:
		return out
	for f in d.get_files():
		if f.ends_with(".gd") or f.ends_with(".tscn"):
			out.append(dir + "/" + f)
	for sub in d.get_directories():
		out += _walk(dir + "/" + sub)
	return out
