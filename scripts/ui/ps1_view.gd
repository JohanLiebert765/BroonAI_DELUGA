class_name Ps1View
extends SubViewportContainer
## Renders the 3D world at a low internal resolution and upscales it with nearest-neighbour
## filtering through the PS1 post shader. The UI is drawn on top at native resolution.

var sub: SubViewport
var _mat: ShaderMaterial


func _init() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	stretch = true
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_mat = ShaderMaterial.new()
	_mat.shader = preload("res://shaders/ps1_post.gdshader")
	material = _mat
	sub = SubViewport.new()
	sub.audio_listener_enable_3d = true
	sub.msaa_3d = Viewport.MSAA_DISABLED
	sub.screen_space_aa = Viewport.SCREEN_SPACE_AA_DISABLED
	sub.positional_shadow_atlas_size = 1024
	add_child(sub)


func _ready() -> void:
	Settings.changed.connect(apply_quality)
	resized.connect(_update_resolution)
	apply_quality()


func apply_quality() -> void:
	stretch_shrink = Settings.shrink()
	_mat.set_shader_parameter("color_depth", [14.0, 20.0, 28.0][Settings.quality])
	_update_resolution()


func _update_resolution() -> void:
	_mat.set_shader_parameter("resolution", size / float(stretch_shrink))


func set_fx(param: String, value: float) -> void:
	_mat.set_shader_parameter(param, value)
