class_name UIKit
## Shared PS1-style theme and small widget factories for every menu and panel.

const BG := Color(0.035, 0.04, 0.055, 0.94)
const BORDER := Color(0.45, 0.45, 0.42)
const TEXT := Color(0.84, 0.82, 0.74)
const DIM := Color(0.55, 0.54, 0.5)
const RED := Color(0.72, 0.16, 0.13)
const GREEN := Color(0.35, 0.62, 0.32)
const AMBER := Color(0.85, 0.62, 0.22)

static var _theme: Theme


static func box(bg: Color, border: Color, width := 1, margin := 8.0) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.border_color = border
	sb.set_border_width_all(width)
	sb.set_content_margin_all(margin)
	return sb


static func theme() -> Theme:
	if _theme:
		return _theme
	var t := Theme.new()
	t.default_font_size = 17
	t.set_stylebox("panel", "PanelContainer", box(BG, BORDER))
	t.set_stylebox("panel", "Panel", box(BG, BORDER))
	t.set_stylebox("normal", "Button", box(Color(0.08, 0.09, 0.11, 0.9), Color(0.3, 0.3, 0.3), 1, 6))
	t.set_stylebox("hover", "Button", box(Color(0.16, 0.1, 0.1, 0.95), RED, 1, 6))
	t.set_stylebox("pressed", "Button", box(Color(0.3, 0.08, 0.07, 0.95), RED, 1, 6))
	t.set_stylebox("disabled", "Button", box(Color(0.05, 0.05, 0.06, 0.8), Color(0.18, 0.18, 0.18), 1, 6))
	t.set_stylebox("focus", "Button", box(Color(0, 0, 0, 0), AMBER, 1, 6))
	t.set_color("font_color", "Button", TEXT)
	t.set_color("font_hover_color", "Button", Color.WHITE)
	t.set_color("font_disabled_color", "Button", Color(0.35, 0.35, 0.35))
	t.set_color("font_color", "Label", TEXT)
	t.set_color("default_color", "RichTextLabel", TEXT)
	t.set_stylebox("normal", "LineEdit", box(Color(0.02, 0.02, 0.03), BORDER, 1, 6))
	t.set_stylebox("focus", "LineEdit", box(Color(0.02, 0.02, 0.03), AMBER, 1, 6))
	t.set_color("font_color", "LineEdit", TEXT)
	t.set_stylebox("background", "ProgressBar", box(Color(0.02, 0.02, 0.03, 0.85), Color(0.3, 0.3, 0.3), 1, 0))
	t.set_stylebox("fill", "ProgressBar", box(RED, RED, 0, 0))
	for cls in ["OptionButton", "CheckBox", "CheckButton"]:
		t.set_color("font_color", cls, TEXT)
	t.set_stylebox("normal", "OptionButton", box(Color(0.08, 0.09, 0.11, 0.9), Color(0.3, 0.3, 0.3), 1, 6))
	t.set_stylebox("hover", "OptionButton", box(Color(0.16, 0.1, 0.1, 0.95), RED, 1, 6))
	t.set_stylebox("panel", "PopupMenu", box(BG, BORDER))
	_theme = t
	return t


static func label(text: String, size := 17, color := TEXT) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	return l


static func button(text: String, on_press: Callable, min_width := 0.0) -> Button:
	var b := Button.new()
	b.text = text
	b.focus_mode = Control.FOCUS_NONE
	if min_width > 0.0:
		b.custom_minimum_size.x = min_width
	b.pressed.connect(func():
		Audio.ui("ui_click", -10.0)
		on_press.call())
	b.mouse_entered.connect(func(): Audio.ui("ui_hover", -22.0))
	return b


static func bar(color: Color, min_size := Vector2(180, 12)) -> ProgressBar:
	var p := ProgressBar.new()
	p.show_percentage = false
	p.custom_minimum_size = min_size
	p.add_theme_stylebox_override("fill", box(color, color, 0, 0))
	return p


## Centered window: returns the VBox to fill. `owner_ctrl` gets a dimmed full-rect backdrop.
static func window(owner_ctrl: Control, title: String, min_size := Vector2(520, 0)) -> VBoxContainer:
	owner_ctrl.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	owner_ctrl.theme = theme()
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.55)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	owner_ctrl.add_child(dim)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	owner_ctrl.add_child(center)
	var panel := PanelContainer.new()
	panel.custom_minimum_size = min_size
	center.add_child(panel)
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 8)
	panel.add_child(vb)
	if title != "":
		var head := label(title, 22, Color(0.9, 0.86, 0.72))
		vb.add_child(head)
		var line := ColorRect.new()
		line.color = RED
		line.custom_minimum_size.y = 2
		vb.add_child(line)
	return vb


static func clear(node: Node) -> void:
	for c in node.get_children():
		node.remove_child(c)
		c.queue_free()


## Anchors a control to a preset at its minimum size, then shifts it by `shift` pixels.
static func place(c: Control, preset: Control.LayoutPreset, shift := Vector2.ZERO) -> void:
	c.set_anchors_and_offsets_preset(preset, Control.PRESET_MODE_MINSIZE)
	c.offset_left += shift.x
	c.offset_right += shift.x
	c.offset_top += shift.y
	c.offset_bottom += shift.y
