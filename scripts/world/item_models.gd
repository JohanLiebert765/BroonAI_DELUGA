class_name ItemModels
## Small low-poly world models for items, built from the "model" kind in items.json.


static func make(item_id: String) -> Node3D:
	var root := Node3D.new()
	var def: Dictionary = ItemDB.items.get(item_id, {})
	var c := Color(def.get("color", "808080"))
	var m := Mat.flat(c)
	var dark := Mat.flat(c.darkened(0.45))
	match def.get("model", "box"):
		"can":
			Build.box(root, Vector3(0, 0.16, 0), Vector3(0.24, 0.32, 0.14), m, false)
			Build.cyl(root, Vector3(0.07, 0.36, 0), 0.03, 0.08, dark)
			Build.box(root, Vector3(-0.03, 0.35, 0), Vector3(0.12, 0.03, 0.04), dark, false)
		"tool":
			Build.box(root, Vector3(0, 0.04, 0), Vector3(0.46, 0.05, 0.06), m, false)
			Build.box(root, Vector3(0.2, 0.05, 0), Vector3(0.1, 0.08, 0.14), dark, false)
		"key":
			Build.box(root, Vector3(0, 0.02, 0), Vector3(0.14, 0.02, 0.03), m, false)
			Build.cyl(root, Vector3(-0.09, 0.02, 0), 0.04, 0.02, m)
		"paper":
			Build.box(root, Vector3(0, 0.01, 0), Vector3(0.24, 0.015, 0.32), Mat.tex("paper", Color.WHITE, 2.0), false, Vector3(0, 12, 0))
		"roll":
			Build.cyl(root, Vector3(0, 0.07, 0), 0.09, 0.14, m)
			Build.cyl(root, Vector3(0, 0.07, 0), 0.03, 0.15, dark)
		"gear":
			Build.cyl(root, Vector3(0, 0.03, 0), 0.16, 0.06, m, false, Vector3.ZERO, 8)
			Build.cyl(root, Vector3(0, 0.05, 0), 0.06, 0.1, dark)
		"cyl":
			Build.cyl(root, Vector3(0, 0.06, 0), 0.06, 0.2, m, false, Vector3(0, 0, 90))
			Build.cyl(root, Vector3(0.1, 0.06, 0), 0.04, 0.03, dark, false, Vector3(0, 0, 90))
		"board":
			Build.box(root, Vector3(0, 0.02, 0), Vector3(0.3, 0.035, 0.2), m, false, Vector3(0, 20, 0))
			Build.box(root, Vector3(0.03, 0.05, 0.02), Vector3(0.2, 0.03, 0.12), dark, false, Vector3(0, -25, 0))
		"light":
			Build.cyl(root, Vector3(0, 0.05, 0), 0.04, 0.22, m, false, Vector3(0, 0, 90))
			Build.cyl(root, Vector3(0.13, 0.05, 0), 0.06, 0.06, dark, false, Vector3(0, 0, 90))
		_:
			Build.box(root, Vector3(0, 0.1, 0), Vector3(0.3, 0.2, 0.22), m, false)
			Build.box(root, Vector3(0, 0.21, 0), Vector3(0.12, 0.02, 0.04), dark, false)
	return root
