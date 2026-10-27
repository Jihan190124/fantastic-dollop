extends Node2D
## Static world rendering (floors, walls, furniture, upgrades). Redrawn only when something changes.

const C := 40
var world
var font: Font = ThemeDB.fallback_font

func _r(x: float, y: float, w: float, h: float) -> Rect2:
	return Rect2(x * C, y * C, w * C, h * C)

func screen_rect(hi: int) -> Rect2:
	var r: Rect2i = Data.HALLS[hi].rect
	var cells: float = [6.0, 7.0, 9.0, 11.0][Upgrades.level("projector")]
	var cx: float = r.position.x + r.size.x * 0.5
	return Rect2((cx - cells * 0.5) * C, r.position.y * C + 8, cells * C, 1.5 * C)

func _text(p: Vector2, s: String, size: int, col: Color) -> void:
	draw_string(font, p, s, HORIZONTAL_ALIGNMENT_LEFT, -1, size, col)

func _draw() -> void:
	var lobby: int = Upgrades.level("lobby")
	# outside
	draw_rect(Rect2(0, 0, 1600, 1120), Color(0.16, 0.2, 0.17))
	draw_rect(_r(0, 25, 40, 3), Color(0.5, 0.5, 0.54))
	for x in range(0, 40, 4):
		draw_rect(_r(x + 1, 26.7, 2, 0.15), Color(0.9, 0.85, 0.3))
	# lobby floor
	var ca: Color = [Color(0.42, 0.36, 0.3), Color(0.8, 0.74, 0.62), Color(0.88, 0.9, 0.93), Color(0.93, 0.85, 0.7)][lobby]
	var cb: Color = [Color(0.37, 0.32, 0.27), Color(0.75, 0.69, 0.57), Color(0.8, 0.84, 0.9), Color(0.87, 0.78, 0.62)][lobby]
	for x in range(1, 23):
		for y in range(7, 24):
			draw_rect(_r(x, y, 1, 1), ca if (x + y) % 2 == 0 else cb)
			if lobby == 0 and (x * 7 + y * 13) % 11 == 0:
				draw_circle(Vector2((x + 0.5) * C, (y + 0.5) * C), 9, Color(0.25, 0.2, 0.15, 0.5))
	if lobby == 3:
		draw_rect(_r(1, 7, 22, 0.1), Color(0.85, 0.7, 0.3))
		draw_rect(_r(1, 23.9, 22, 0.1), Color(0.85, 0.7, 0.3))
	if Upgrades.decor.has("carpet"):
		draw_rect(_r(10, 15.5, 3, 8.5), Color(0.7, 0.1, 0.15))
		draw_rect(_r(10, 15.5, 0.1, 8.5), Color(0.95, 0.8, 0.3))
		draw_rect(_r(12.9, 15.5, 0.1, 8.5), Color(0.95, 0.8, 0.3))
	# rooms
	draw_rect(_r(1, 1, 8, 5), Color(0.55, 0.65, 0.78))
	draw_rect(_r(10, 1, 6, 5), Color(0.7, 0.6, 0.45))
	draw_rect(_r(17, 1, 6, 5), Color(0.72, 0.86, 0.9))
	for x in range(17, 23):
		for y in range(1, 6):
			if (x + y) % 2 == 0:
				draw_rect(_r(x, y, 1, 1), Color(0.66, 0.8, 0.85))
	# walls (pseudo-3D)
	var wcol: Color = [Color(0.3, 0.26, 0.24), Color(0.5, 0.45, 0.4), Color(0.45, 0.5, 0.6), Color(0.55, 0.4, 0.3)][lobby]
	var walls: Dictionary = Data.wall_cells()
	for c in walls:
		var p := Vector2(c.x * C, c.y * C)
		draw_rect(Rect2(p, Vector2(C, C)), wcol.darkened(0.25))
		if not walls.has(Vector2i(c.x, c.y - 1)):
			draw_rect(Rect2(p, Vector2(C, 8)), wcol.lightened(0.2))
		if not walls.has(Vector2i(c.x, c.y + 1)):
			draw_rect(Rect2(p.x, p.y + C, C, 6), Color(0, 0, 0, 0.25))
	# door mat / entrance
	draw_rect(_r(10, 24, 3, 1), Color(0.55, 0.8, 0.95, 0.6))
	draw_rect(_r(10, 23.2, 3, 0.8), Color(0.3, 0.2, 0.2))
	_text(Vector2(10.1 * C, 25.65 * C), "ENTRANCE", 18, Color(1, 1, 1, 0.85))
	_text(Vector2(2.2 * C, 24.65 * C), "THEATRE EMPIRE", 20, Color(1.0, 0.85, 0.4))
	if Upgrades.decor.has("neon"):
		draw_rect(_r(7.5, 24.05, 8, 0.9), Color(1, 0.2, 0.6, 0.35))
		_text(Vector2(8.4 * C, 24.75 * C), "NOW SHOWING", 20, Color(1.0, 0.5, 0.85))
	# room labels
	_text(Vector2(1.2 * C, 5.7 * C), "STAFF ONLY", 14, Color(0.15, 0.2, 0.3))
	_text(Vector2(10.2 * C, 5.7 * C), "STORAGE", 14, Color(0.3, 0.2, 0.1))
	_text(Vector2(17.2 * C, 5.7 * C), "TOILETS", 14, Color(0.1, 0.3, 0.4))
	_draw_rooms()
	_draw_counters()
	_draw_decor()
	for i in 3:
		_draw_hall(i)

func _draw_rooms() -> void:
	for x in range(1, 9):
		draw_rect(_r(x, 1, 0.95, 1.4), Color(0.3, 0.38, 0.55))
		draw_rect(_r(x + 0.4, 1.5, 0.1, 0.3), Color(0.9, 0.9, 0.9))
	draw_rect(_r(3, 3, 3, 1), Color(0.5, 0.35, 0.2))
	draw_rect(_r(3, 3, 3, 0.2), Color(0.7, 0.5, 0.3))
	# storage shelves with stock-dependent boxes
	draw_rect(_r(10, 1, 6, 2), Color(0.4, 0.28, 0.18))
	var boxes := mini(12, Inventory.total_stock() / 8)
	for i in 12:
		var bx := 10.15 + (i % 6) * 0.98
		var by := 1.1 if i < 6 else 2.05
		draw_rect(_r(bx, by, 0.8, 0.75), Color(0.85, 0.65, 0.35) if i < boxes else Color(0.3, 0.2, 0.12))
	for x in range(17, 22):
		draw_rect(_r(x + 0.08, 1, 0.84, 2), Color(0.95, 0.95, 0.97))
		draw_rect(_r(x + 0.4, 2.2, 0.2, 0.2), Color(0.5, 0.5, 0.55))
	for x in range(18, 22):
		draw_rect(_r(x, 22, 1, 1), Color(0.45, 0.28, 0.18))
		draw_rect(_r(x, 22, 1, 0.25), Color(0.65, 0.42, 0.25))
	_text(Vector2(18.2 * C, 23.7 * C), "WAITING", 12, Color(0.2, 0.1, 0.05))

func _draw_counters() -> void:
	# ticket counter
	draw_rect(_r(3, 15, 5, 1), Color(0.45, 0.3, 0.2))
	draw_rect(_r(3, 15, 5, 0.3), Color(0.75, 0.55, 0.35))
	draw_rect(_r(3.2, 15.4, 4.6, 0.4), Color(0.6, 0.85, 0.95, 0.5))
	_text(Vector2(3.4 * C, 15.95 * C), "TICKETS", 14, Color(1, 0.95, 0.7))
	# food counters
	var fl: int = Upgrades.level("food")
	var segs := [{"x": 14, "n": "POPCORN", "c": Color(0.8, 0.2, 0.2)}, {"x": 16, "n": "DRINKS", "c": Color(0.2, 0.4, 0.8)},
		{"x": 18, "n": "SNACKS", "c": Color(0.9, 0.55, 0.15)}]
	for i in 3:
		var s: Dictionary = segs[i]
		var open: bool = fl > i
		draw_rect(_r(s.x, 15, 2, 1), s.c if open else Color(0.35, 0.35, 0.38))
		draw_rect(_r(s.x, 15, 2, 0.3), Color(1, 1, 1, 0.35))
		_text(Vector2((s.x + 0.1) * C, 15.95 * C), s.n if open else "CLOSED", 13, Color.WHITE)
		if open:
			match i:
				0:
					draw_rect(_r(14.3, 14.35, 1.4, 0.65), Color(1, 0.95, 0.6, 0.8))
					for k in 5:
						draw_circle(Vector2((14.55 + k * 0.22) * C, 14.8 * C), 5, Color(1, 0.97, 0.85))
				1:
					for k in 3:
						draw_rect(_r(16.3 + k * 0.5, 14.5, 0.3, 0.5), Color(0.9, 0.9, 0.95))
				2:
					draw_rect(_r(18.2, 14.6, 1.6, 0.4), Color(0.95, 0.8, 0.3))
	if fl >= 4:
		_text(Vector2(10 * C, 9.4 * C), "FOOD COURT", 16, Color(1.0, 0.7, 0.3))
		for t in Data.COURT_TABLES:
			var c := Data.cell_center(t)
			draw_circle(c, 15, Color(0.85, 0.85, 0.9))
			draw_circle(c, 11, Color(0.95, 0.4, 0.3))
			for o in [Vector2(-24, 0), Vector2(24, 0), Vector2(0, -24), Vector2(0, 24)]:
				draw_circle(c + o, 7, Color(0.3, 0.3, 0.4))

func _draw_decor() -> void:
	if Upgrades.decor.has("posters"):
		for i in 6:
			var col := Color.from_hsv(i * 0.17, 0.6, 0.9)
			draw_rect(_r(3.2 + i * 3.0, 6.1, 1.2, 1.5), Color(0.1, 0.1, 0.1))
			draw_rect(_r(3.28 + i * 3.0, 6.2, 1.04, 1.3), col)
	if Upgrades.decor.has("plants"):
		for c in Data.PLANT_CELLS:
			var p := Data.cell_center(c)
			draw_rect(Rect2(p + Vector2(-9, 4), Vector2(18, 14)), Color(0.55, 0.3, 0.2))
			for a in 5:
				draw_circle(p + Vector2(cos(a * 1.26) * 9, -4 + sin(a * 1.26) * 7), 8, Color(0.2, 0.65, 0.3))
	if Upgrades.decor.has("arcade"):
		for i in 2:
			var x := 20.0 + i
			draw_rect(_r(x + 0.05, 10, 0.9, 2), Color(0.15, 0.1, 0.35))
			draw_rect(_r(x + 0.15, 10.15, 0.7, 0.7), Color(0.3, 0.9, 0.95))
			draw_rect(_r(x + 0.2, 11.1, 0.6, 0.3), Color(0.9, 0.3, 0.4))

func _draw_hall(i: int) -> void:
	var r: Rect2i = Data.HALLS[i].rect
	var hs: String = Upgrades.hall_state[i]
	var rp := Rect2(r.position * C, r.size * C)
	if hs != "built":
		draw_rect(rp, Color(0.1, 0.1, 0.13))
		_text(rp.position + Vector2(24, 100), "%s - %s" % [Data.HALLS[i].name, "UNDER CONSTRUCTION" if hs == "building" else "FOR SALE"], 22, Color(0.8, 0.8, 0.85))
		if hs == "locked":
			_text(rp.position + Vector2(24, 136), "Open the Build menu to expand (%s)" % Data.money(Data.HALLS[i].cost), 16, Color(0.6, 0.6, 0.7))
		return
	draw_rect(rp, Color(0.22, 0.1, 0.16))
	draw_rect(Rect2(rp.position.x, rp.position.y + 2 * C, rp.size.x, 5 * C), Color(0.2, 0.09, 0.14))
	draw_rect(Rect2((Data.AISLE_X) * C, rp.position.y + 2 * C, C, 5 * C), Color(0.3, 0.13, 0.2))
	draw_rect(Rect2(23.1 * C, (r.position.y + 6) * C, 8.9 * C, C), Color(0.28, 0.12, 0.19))
	_text(rp.position + Vector2(8, rp.size.y - 6), Data.HALLS[i].name.to_upper(), 12, Color(1, 1, 1, 0.5))
	# screen frame
	var sr := screen_rect(i)
	var lvl: int = Upgrades.level("projector")
	draw_rect(sr.grow(6), [Color(0.3, 0.3, 0.3), Color(0.35, 0.4, 0.55), Color(0.2, 0.3, 0.6), Color(0.85, 0.7, 0.3)][lvl])
	draw_rect(sr, Color(0.05, 0.05, 0.08))
	# speakers
	var al: int = Upgrades.level("audio")
	var sp: int = [2, 4, 6][al]
	for k in sp:
		var sx: float = rp.position.x + 10 + k * (rp.size.x - 40) / maxf(1.0, sp - 1.0)
		draw_rect(Rect2(sx, rp.position.y + 2, 14, 20 + al * 4), Color(0.1, 0.1, 0.12))
		draw_circle(Vector2(sx + 7, rp.position.y + 12), 4, Color(0.4, 0.4, 0.45))
	# seats
	var sl: int = Upgrades.level("seats")
	for s in Data.hall_seats(i):
		var c := Data.cell_center(s.cell)
		_draw_seat(c, sl)

func _draw_seat(c: Vector2, lvl: int) -> void:
	match lvl:
		0:
			draw_rect(Rect2(c + Vector2(-11, -8), Vector2(22, 16)), Color(0.6, 0.6, 0.64))
			draw_rect(Rect2(c + Vector2(-11, 6), Vector2(22, 5)), Color(0.45, 0.45, 0.5))
		1:
			draw_rect(Rect2(c + Vector2(-12, -9), Vector2(24, 18)), Color(0.72, 0.2, 0.2))
			draw_rect(Rect2(c + Vector2(-12, 6), Vector2(24, 7)), Color(0.5, 0.12, 0.12))
		2:
			draw_rect(Rect2(c + Vector2(-15, -10), Vector2(30, 21)), Color(0.5, 0.1, 0.15))
			draw_rect(Rect2(c + Vector2(-11, -8), Vector2(22, 14)), Color(0.7, 0.18, 0.22))
			draw_rect(Rect2(c + Vector2(-15, 8), Vector2(30, 5)), Color(0.35, 0.07, 0.1))
		_:
			draw_rect(Rect2(c + Vector2(-16, -11), Vector2(32, 23)), Color(0.12, 0.1, 0.09))
			draw_rect(Rect2(c + Vector2(-12, -8), Vector2(24, 15)), Color(0.2, 0.16, 0.14))
			draw_rect(Rect2(c + Vector2(-16, -11), Vector2(32, 2)), Color(0.9, 0.75, 0.3))
			draw_rect(Rect2(c + Vector2(-16, 9), Vector2(32, 2)), Color(0.9, 0.75, 0.3))
