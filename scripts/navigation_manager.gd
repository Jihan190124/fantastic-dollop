extends RefCounted
## Lightweight grid navigation on top of AStarGrid2D.

var grid := AStarGrid2D.new()

func _init() -> void:
	grid.region = Rect2i(0, 0, Data.GRID_W, Data.GRID_H)
	grid.cell_size = Vector2(Data.CELL, Data.CELL)
	grid.offset = Vector2(Data.CELL, Data.CELL) * 0.5
	grid.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_ONLY_IF_NO_OBSTACLES
	grid.default_compute_heuristic = AStarGrid2D.HEURISTIC_OCTILE
	grid.default_estimate_heuristic = AStarGrid2D.HEURISTIC_OCTILE
	grid.update()
	rebuild()

func rebuild() -> void:
	grid.fill_solid_region(grid.region, false)
	for c in Data.static_solids():
		grid.set_point_solid(c, true)
	for i in 3:
		var r: Rect2i = Data.HALLS[i].rect
		if Upgrades.hall_state[i] == "built":
			for s in Data.hall_seats(i):
				grid.set_point_solid(s.cell, true)
			for x in range(r.position.x, r.end.x):
				grid.set_point_solid(Vector2i(x, r.position.y), true)
				grid.set_point_solid(Vector2i(x, r.position.y + 1), true)
		else:
			for x in range(r.position.x, r.end.x):
				for y in range(r.position.y, r.end.y):
					grid.set_point_solid(Vector2i(x, y), true)
			grid.set_point_solid(Data.hall_door_cell(i), true)
	if Upgrades.decor.has("plants"):
		for c in Data.PLANT_CELLS:
			grid.set_point_solid(c, true)
	if Upgrades.decor.has("arcade"):
		for c in Data.ARCADE_CELLS:
			grid.set_point_solid(c, true)
	if Upgrades.level("food") >= 4:
		for c in Data.COURT_TABLES:
			grid.set_point_solid(c, true)

func is_solid(c: Vector2i) -> bool:
	return grid.region.has_point(c) and grid.is_point_solid(c)

func nearest_free(c: Vector2i) -> Vector2i:
	c = Vector2i(clampi(c.x, 0, Data.GRID_W - 1), clampi(c.y, 0, Data.GRID_H - 1))
	if not grid.is_point_solid(c):
		return c
	for r in range(1, 6):
		for dy in range(-r, r + 1):
			for dx in range(-r, r + 1):
				if maxi(absi(dx), absi(dy)) != r:
					continue
				var n := Vector2i(c.x + dx, c.y + dy)
				if grid.region.has_point(n) and not grid.is_point_solid(n):
					return n
	return c

func find_path(from: Vector2, to_cell: Vector2i) -> PackedVector2Array:
	var a := nearest_free(Data.cell_of(from))
	var b := nearest_free(to_cell)
	return grid.get_point_path(a, b)
