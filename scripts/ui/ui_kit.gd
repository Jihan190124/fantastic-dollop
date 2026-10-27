extends RefCounted
## Small helpers for building touch-friendly UI in code.

static func box(col: Color, radius: int = 10, border: Color = Color(0, 0, 0, 0), bw: int = 0) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = col
	s.set_corner_radius_all(radius)
	s.set_content_margin_all(10)
	if bw > 0:
		s.border_color = border
		s.set_border_width_all(bw)
	return s

static func make_theme(scale: float) -> Theme:
	var t := Theme.new()
	t.default_font_size = int(22 * scale)
	t.set_stylebox("normal", "Button", box(Color(0.22, 0.25, 0.4), 12))
	t.set_stylebox("hover", "Button", box(Color(0.28, 0.32, 0.5), 12))
	t.set_stylebox("pressed", "Button", box(Color(0.35, 0.55, 0.9), 12))
	t.set_stylebox("disabled", "Button", box(Color(0.18, 0.18, 0.24), 12))
	t.set_stylebox("focus", "Button", box(Color(0, 0, 0, 0), 12))
	t.set_color("font_color", "Button", Color(1, 1, 1))
	t.set_color("font_disabled_color", "Button", Color(0.55, 0.55, 0.62))
	t.set_stylebox("panel", "PanelContainer", box(Color(0.09, 0.1, 0.17, 0.96), 14, Color(0.3, 0.34, 0.55), 2))
	t.set_stylebox("background", "ProgressBar", box(Color(0.15, 0.15, 0.22), 6))
	t.set_stylebox("fill", "ProgressBar", box(Color(0.35, 0.8, 0.5), 6))
	t.set_color("font_color", "Label", Color(0.95, 0.95, 1.0))
	t.set_constant("separation", "VBoxContainer", 8)
	t.set_constant("separation", "HBoxContainer", 8)
	return t

static func label(text: String, size: int = -1, col: Color = Color(0.95, 0.95, 1.0), wrap: bool = false) -> Label:
	var l := Label.new()
	l.text = text
	if size > 0:
		l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", col)
	if wrap:
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return l

static func button(text: String, cb: Callable, min_w: float = 0.0, min_h: float = 56.0) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(min_w, min_h)
	b.pressed.connect(cb)
	return b

static func anchor(c: Control, l: float, t: float, r: float, b: float, ol: float, ot: float, orr: float, ob: float) -> void:
	c.anchor_left = l
	c.anchor_top = t
	c.anchor_right = r
	c.anchor_bottom = b
	c.offset_left = ol
	c.offset_top = ot
	c.offset_right = orr
	c.offset_bottom = ob

static func clear(n: Node) -> void:
	for c in n.get_children():
		n.remove_child(c)
		c.queue_free()
