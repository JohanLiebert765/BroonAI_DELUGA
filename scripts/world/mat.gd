class_name Mat
## Cached PS1-style materials: tiny nearest-filtered textures projected triplanar,
## so procedurally built boxes need no UV work.

static var _cache := {}


static func tex(texture: String, tint := Color.WHITE, scale := 0.5) -> StandardMaterial3D:
	var key := "t:%s:%s:%s" % [texture, tint.to_html(), scale]
	if _cache.has(key):
		return _cache[key]
	var m := StandardMaterial3D.new()
	var path := "res://assets/textures/%s.png" % texture
	if ResourceLoader.exists(path):
		m.albedo_texture = load(path)
	# The generated textures are dark; lift them so lamps and torches read on screen.
	m.albedo_color = Color(minf(tint.r * 1.8, 1.0), minf(tint.g * 1.8, 1.0), minf(tint.b * 1.8, 1.0), tint.a)
	m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	m.uv1_triplanar = true
	m.uv1_world_triplanar = true
	m.uv1_scale = Vector3.ONE * scale
	m.roughness = 1.0
	m.metallic_specular = 0.0
	_cache[key] = m
	return m


static func flat(color: Color) -> StandardMaterial3D:
	var key := "f:" + color.to_html()
	if _cache.has(key):
		return _cache[key]
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.roughness = 1.0
	m.metallic_specular = 0.0
	_cache[key] = m
	return m


static func glow(color: Color, energy := 2.0) -> StandardMaterial3D:
	var key := "g:%s:%s" % [color.to_html(), energy]
	if _cache.has(key):
		return _cache[key]
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.emission_enabled = true
	m.emission = color
	m.emission_energy_multiplier = energy
	_cache[key] = m
	return m


## Semi-transparent material for apparitions. Not cached: callers animate its alpha.
static func ghost(color: Color, alpha := 0.7) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(color.r, color.g, color.b, alpha)
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.roughness = 1.0
	m.metallic_specular = 0.0
	m.emission_enabled = true
	m.emission = color * 0.25
	return m
