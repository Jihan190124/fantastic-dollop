extends Node2D
## Dynamic overlays: litter, screens, show boards, seat reservations, construction, selection.

const C := 40
var world
var font: Font = ThemeDB.fallback_font
var t := 0.0

func _process(delta: float) -> void:
	t += delta
	queue_redraw()

func _text(p: Vector2, s: String, size: int, col: Color) -> void:
	draw_string(font, p, s, HORIZONTAL_ALIGNMENT_LEFT, -1, size, col)

func _draw() -> void:
	for l in world.litter:
		var p: Vector2 = l.pos
		match int(l.k):
			0: draw_circle(p, 5, Color(0.9, 0.85, 0.7))
			1: draw_rect(Rect2(p - Vector2(5, 3), Vector2(10, 6)), Color(0.85, 0.3, 0.3))
			_: draw_circle(p, 4, Color(0.4, 0.6, 0.9))
	for hi in 3:
		var hs: String = Upgrades.hall_state[hi]
		var r: Rect2i = Data.HALLS[hi].rect
		var rp := Rect2(r.position * C, r.size * C)
		if hs == "building":
			var total: float = Data.HALLS[hi].build_sec
			var left: float = float(Upgrades.build_left.get(hi, 0.0))
			_scaffold(rp, 1.0 - left / maxf(0.1, total), "BUILDING %s" % Data.HALLS[hi].name)
		elif hs == "built":
			_draw_screen(hi, rp)
	for z in world.zones:
		var rr: Rect2 = z.rect
		_scaffold(rr, clampf(float(z.t) / float(z.dur), 0.0, 1.0), z.label)
	var sel: Dictionary = world.selected
	if not sel.is_empty() and sel.has("rect"):
		var rc: Rect2 = sel.rect
		draw_rect(rc.grow(2), Color(1, 0.9, 0.3, 0.25 + 0.15 * sin(t * 6.0)), true)
		draw_rect(rc.grow(2), Color(1, 0.9, 0.3), false, 2.0)

func _scaffold(rr: Rect2, prog: float, label: String) -> void:
	draw_rect(rr, Color(0, 0, 0, 0.5))
	var y := 0.0
	var k := 0
	while y < rr.size.y:
		if k % 2 == 0:
			draw_rect(Rect2(rr.position.x, rr.position.y + y, rr.size.x, minf(8.0, rr.size.y - y)), Color(1.0, 0.65, 0.1, 0.5))
		y += 8.0
		k += 1
	var cx := rr.position.x + rr.size.x * 0.5
	var cy := rr.position.y + rr.size.y * 0.5
	draw_string(font, Vector2(rr.position.x, cy - 8), label, HORIZONTAL_ALIGNMENT_CENTER, rr.size.x, 18, Color.WHITE)
	var bw := minf(rr.size.x - 20.0, 200.0)
	draw_rect(Rect2(cx - bw * 0.5, cy + 4, bw, 10), Color(0.1, 0.1, 0.1))
	draw_rect(Rect2(cx - bw * 0.5, cy + 4, bw * prog, 10), Color(0.4, 0.9, 0.4))
	var sx := rr.position.x + fmod(t * 120.0, rr.size.x)
	draw_circle(Vector2(sx, rr.position.y + 6), 3, Color(1, 0.9, 0.4))

func _draw_screen(hi: int, rp: Rect2) -> void:
	var sr: Rect2 = world.view.screen_rect(hi)
	var sh: Dictionary = Screenings.current_show(hi)
	var title := "- no screening -"
	var sub := ""
	var running := false
	if not sh.is_empty():
		title = Data.movie(sh.movie).title
		match sh.state:
			"running":
				running = true
				var prog := clampf((Game.clock - float(sh.start)) / (float(sh.end) - float(sh.start)), 0.0, 1.0)
				sub = "%d%%" % int(prog * 100.0)
			"scheduled", "boarding":
				sub = "%s  %d/%d" % [Data.fmt_time(sh.start), sh.sold, sh.cap]
			_:
				sub = "Finished"
	if running:
		var h := fmod(t * 0.2, 1.0)
		draw_rect(sr, Color.from_hsv(h, 0.5, 0.55))
		draw_rect(Rect2(sr.position, Vector2(sr.size.x * 0.5, sr.size.y)), Color.from_hsv(fmod(h + 0.3, 1.0), 0.6, 0.5, 0.6))
		var lvl: int = Upgrades.level("projector")
		draw_rect(Rect2(sr.position.x, sr.end.y - 4, sr.size.x * clampf((Game.clock - float(sh.start)) / (float(sh.end) - float(sh.start)), 0, 1), 4), Color(1, 1, 1, 0.9))
		if lvl >= 2:
			draw_rect(sr, Color(1, 1, 1, 0.06 + 0.04 * sin(t * 4.0)))
	draw_string(font, Vector2(sr.position.x, sr.position.y + 22), title, HORIZONTAL_ALIGNMENT_CENTER, sr.size.x, 15, Color(1, 1, 1))
	draw_string(font, Vector2(sr.position.x, sr.position.y + 40), sub, HORIZONTAL_ALIGNMENT_CENTER, sr.size.x, 13, Color(1, 0.95, 0.6))
	# seat reservations
	if not sh.is_empty() and sh.state != "done":
		var seats: Array = Data.hall_seats(hi)
		for i in seats.size():
			if sh.owners[i] != 0 and not sh.seated[i]:
				draw_circle(Data.cell_center(seats[i].cell) + Vector2(0, -2), 4, Color(1, 0.85, 0.2))
