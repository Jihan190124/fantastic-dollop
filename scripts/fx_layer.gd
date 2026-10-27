extends Node2D
## Floating text and particle bursts (purely visual).

var texts: Array = []
var parts: Array = []

func add_text(pos: Vector2, text: String, col: Color, size: int = 22) -> void:
	if not Game.settings.fx and size < 24:
		return
	if texts.size() > 40:
		texts.pop_front()
	texts.append({"p": pos, "s": text, "c": col, "t": 0.0, "z": size})
	set_process(true)

func burst(pos: Vector2, col: Color, n: int = 14) -> void:
	for i in mini(n, 30):
		if parts.size() > 150:
			parts.pop_front()
		var a := randf() * TAU
		parts.append({"p": pos, "v": Vector2(cos(a), sin(a) - 0.5) * randf_range(40, 120), "t": 0.0, "c": col})
	set_process(true)

func _process(delta: float) -> void:
	for t in texts:
		t.t += delta
		t.p.y -= 28.0 * delta
	for p in parts:
		p.t += delta
		p.p += p.v * delta
		p.v.y += 120.0 * delta
	texts = texts.filter(func(t): return t.t < 1.4)
	parts = parts.filter(func(p): return p.t < 0.9)
	queue_redraw()
	if texts.is_empty() and parts.is_empty():
		set_process(false)

func _draw() -> void:
	var font := ThemeDB.fallback_font
	for t in texts:
		var a := clampf(1.6 - t.t, 0.0, 1.0)
		var col: Color = t.c
		col.a = a
		draw_string_outline(font, t.p - Vector2(100, 0), t.s, HORIZONTAL_ALIGNMENT_CENTER, 200, t.z, 4, Color(0, 0, 0, a * 0.8))
		draw_string(font, t.p - Vector2(100, 0), t.s, HORIZONTAL_ALIGNMENT_CENTER, 200, t.z, col)
	for p in parts:
		var c: Color = p.c
		c.a = clampf(1.0 - p.t / 0.9, 0.0, 1.0)
		draw_circle(p.p, 3.0, c)
