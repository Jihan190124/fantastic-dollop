extends Node
## Central, data-driven configuration. Rebalance the game by editing the values below.

const VERSION := "1.0.0"
const SAVE_VERSION := 1
const CELL := 40
const GRID_W := 40
const GRID_H := 28
const WORLD_SIZE := Vector2(1600.0, 1120.0)

const START_CASH := 10000
const START_REPUTATION := 20.0
const GAME_MIN_PER_SEC := 2.0   # game minutes per real second at 1x speed
const DAY_START_HOUR := 9.5
const OPEN_HOUR := 10.0
const CLOSE_HOUR := 22.0
const FORCE_END_HOUR := 23.75
const BANKRUPT_LIMIT := -5000

const TICKET_PRICE := 150
const TICKET_MIN := 40
const TICKET_MAX := 400
const TICKET_STEP := 10
const SHOW_SLOTS := [10.5, 13.0, 15.5, 18.0, 20.5]
const SLOT_LEN_MIN := 150
const CLEAN_MIN := 15
const BOARDING_MIN := 25.0
const SALES_CLOSE_MIN := 15.0
const MAX_QUEUE := 6
const CLEANING_COST := 5
const MAX_LITTER := 40

const DAYS := ["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"]
const FACTORS := ["comfort", "clean", "price", "wait", "food", "projection", "audio", "facilities", "movie"]
const FACTOR_NAMES := {
	"comfort": "Seat comfort", "clean": "Cleanliness", "price": "Ticket price", "wait": "Waiting time",
	"food": "Food availability", "projection": "Projection", "audio": "Audio", "facilities": "Facilities", "movie": "Movie line-up"}
const FACTOR_TIPS := {
	"comfort": "Guests find the seats uncomfortable. Upgrade your seating.",
	"clean": "The cinema is dirty. Hire cleaners or renovate the lobby.",
	"price": "Tickets feel overpriced. Lower the price in Screenings or improve projection, audio and seats.",
	"wait": "Queues are too long. Hire another cashier or food server, or train your staff.",
	"food": "Snacks are unavailable. Restock the food counter and make sure a server is hired.",
	"projection": "The picture quality is weak. Upgrade the projector.",
	"audio": "The sound is weak. Upgrade the audio system.",
	"facilities": "The cinema feels bare. Add decorations, renovate the lobby or expand the food area.",
	"movie": "The movie line-up is weak. Schedule higher-quality films as your reputation unlocks them."}

# --- Layout constants (grid cells) ------------------------------------------------
const AISLE_X := 31
const TICKET_STATIONS := [Vector2i(4, 14), Vector2i(6, 14)]
const TICKET_SPOTS := [Vector2i(4, 16), Vector2i(6, 16)]
const TICKET_QUEUE := [Vector2i(5, 17), Vector2i(5, 18), Vector2i(5, 19), Vector2i(5, 20), Vector2i(5, 21), Vector2i(5, 22)]
const FOOD_STATIONS := [Vector2i(15, 14), Vector2i(18, 14)]
const FOOD_SPOTS := [Vector2i(15, 16), Vector2i(18, 16)]
const FOOD_QUEUE := [Vector2i(16, 17), Vector2i(16, 18), Vector2i(16, 19), Vector2i(16, 20), Vector2i(16, 21), Vector2i(16, 22)]
const ENTRY_CELL := Vector2i(11, 22)
const SPAWN_CELL := Vector2i(11, 27)
const TOILET_CELL := Vector2i(19, 4)
const STAFF_IDLE := [Vector2i(2, 4), Vector2i(7, 4), Vector2i(2, 5), Vector2i(7, 5), Vector2i(5, 5)]
const PLANT_CELLS := [Vector2i(1, 7), Vector2i(1, 13), Vector2i(1, 23), Vector2i(21, 13)]
const ARCADE_CELLS := [Vector2i(20, 10), Vector2i(21, 10), Vector2i(20, 11), Vector2i(21, 11)]
const COURT_TABLES := [Vector2i(11, 10), Vector2i(14, 10), Vector2i(17, 10)]

const HALLS := [
	{"name": "Hall 1", "rect": Rect2i(24, 1, 15, 7), "left": [28, 29, 30], "right": [32, 33, 34], "cost": 0, "build_sec": 0.0, "rep": 0},
	{"name": "Hall 2", "rect": Rect2i(24, 9, 15, 7), "left": [27, 28, 29, 30], "right": [32, 33, 34, 35], "cost": 15000, "build_sec": 25.0, "rep": 15},
	{"name": "Hall 3", "rect": Rect2i(24, 17, 15, 7), "left": [26, 27, 28, 29, 30], "right": [32, 33, 34, 35, 36], "cost": 40000, "build_sec": 35.0, "rep": 35},
]

# --- Movies (fictional) ------------------------------------------------------------
const MOVIES := [
	{"id": "neon_monsoon", "title": "Neon Monsoon", "genre": "Action", "pop": 0.85, "dur": 118, "quality": 0.80, "min_rep": 0},
	{"id": "the_last_chai_stall", "title": "The Last Chai Stall", "genre": "Comedy", "pop": 0.70, "dur": 105, "quality": 0.75, "min_rep": 0},
	{"id": "cartoon_kingdom", "title": "Cartoon Kingdom", "genre": "Animation", "pop": 0.75, "dur": 92, "quality": 0.70, "min_rep": 0},
	{"id": "whispers_of_rann", "title": "Whispers of Rann", "genre": "Horror", "pop": 0.60, "dur": 98, "quality": 0.65, "min_rep": 0},
	{"id": "love_in_lockdown_2", "title": "Love in Lockdown 2", "genre": "Romance", "pop": 0.65, "dur": 112, "quality": 0.60, "min_rep": 10},
	{"id": "galactic_gully_boys", "title": "Galactic Gully Boys", "genre": "Sci-Fi", "pop": 0.90, "dur": 125, "quality": 0.85, "min_rep": 25},
	{"id": "cricket_fever", "title": "Cricket Fever", "genre": "Drama", "pop": 0.75, "dur": 120, "quality": 0.80, "min_rep": 25},
	{"id": "masala_mansion", "title": "Mystery of Masala Mansion", "genre": "Thriller", "pop": 0.55, "dur": 95, "quality": 0.70, "min_rep": 40},
	{"id": "tiger_squad_returns", "title": "Tiger Squad Returns", "genre": "Action", "pop": 0.95, "dur": 130, "quality": 0.90, "min_rep": 55},
]

# --- Customers ---------------------------------------------------------------------
# w = satisfaction weights in FACTORS order
const CUSTOMER_TYPES := {
	"budget": {"name": "Budget visitor", "color": Color(0.45, 0.72, 0.95), "weight": 0.30, "budget": [200, 380], "party": [1, 1], "food": 0.35, "patience": 35.0, "genres": [], "w": [0.10, 0.12, 0.30, 0.12, 0.06, 0.08, 0.06, 0.04, 0.12]},
	"student": {"name": "Student", "color": Color(0.6, 0.85, 0.4), "weight": 0.25, "budget": [250, 500], "party": [1, 2], "food": 0.55, "patience": 40.0, "genres": ["Horror", "Sci-Fi", "Action"], "w": [0.10, 0.08, 0.24, 0.10, 0.10, 0.10, 0.10, 0.08, 0.10]},
	"family": {"name": "Family", "color": Color(0.98, 0.7, 0.35), "weight": 0.20, "budget": [900, 1600], "party": [2, 4], "food": 0.9, "patience": 30.0, "genres": ["Animation", "Comedy"], "w": [0.16, 0.18, 0.10, 0.12, 0.14, 0.06, 0.06, 0.10, 0.08]},
	"premium": {"name": "Premium guest", "color": Color(0.85, 0.5, 0.95), "weight": 0.10, "budget": [1200, 3000], "party": [1, 2], "food": 0.8, "patience": 22.0, "genres": ["Drama", "Thriller", "Romance"], "w": [0.22, 0.16, 0.04, 0.10, 0.10, 0.12, 0.12, 0.12, 0.04]},
	"enthusiast": {"name": "Movie enthusiast", "color": Color(0.95, 0.45, 0.5), "weight": 0.15, "budget": [500, 1100], "party": [1, 1], "food": 0.4, "patience": 45.0, "genres": ["Sci-Fi", "Action"], "w": [0.08, 0.06, 0.08, 0.08, 0.04, 0.24, 0.22, 0.04, 0.16]},
}

# --- Upgrades ----------------------------------------------------------------------
const TRACK_ORDER := ["seats", "projector", "audio", "lobby", "food", "training"]
const TRACKS := {
	"seats": {"name": "Seating", "levels": [
		{"name": "Plastic chairs", "cost": 0, "q": 0.25, "rep": 0, "desc": "Hard and wobbly."},
		{"name": "Upholstered seats", "cost": 500, "q": 0.55, "rep": 0, "desc": "Padded seats - clearly more comfortable."},
		{"name": "Recliners", "cost": 4500, "q": 0.80, "rep": 20, "desc": "Reclining seats guests love."},
		{"name": "VIP seating", "cost": 14000, "q": 1.0, "rep": 45, "desc": "Leather loungers with side tables."}]},
	"projector": {"name": "Projection", "levels": [
		{"name": "Basic projector", "cost": 0, "q": 0.30, "rep": 0, "desc": "Dim and fuzzy."},
		{"name": "HD projector", "cost": 3000, "q": 0.55, "rep": 0, "desc": "Sharp HD picture, bigger screen."},
		{"name": "4K projector", "cost": 9000, "q": 0.80, "rep": 25, "desc": "Crisp 4K picture."},
		{"name": "Premium large-format screen", "cost": 24000, "q": 1.0, "rep": 50, "desc": "A giant, curved premium screen."}]},
	"audio": {"name": "Audio", "levels": [
		{"name": "Basic speakers", "cost": 0, "q": 0.30, "rep": 0, "desc": "Tinny stereo."},
		{"name": "Surround sound", "cost": 2500, "q": 0.65, "rep": 0, "desc": "Surround speakers around the hall."},
		{"name": "Premium cinema audio", "cost": 9000, "q": 1.0, "rep": 30, "desc": "Full premium audio with subwoofers."}]},
	"lobby": {"name": "Lobby", "levels": [
		{"name": "Dirty lobby", "cost": 0, "q": 0.45, "rep": 0, "desc": "Stained floors and peeling paint."},
		{"name": "Clean lobby", "cost": 1500, "q": 0.70, "rep": 0, "desc": "Fresh paint and new tiles."},
		{"name": "Modern lobby", "cost": 6000, "q": 0.88, "rep": 20, "desc": "Modern finishes and lighting."},
		{"name": "Luxury lobby", "cost": 18000, "q": 1.0, "rep": 45, "desc": "Marble floors and gold trim."}]},
	"food": {"name": "Food", "levels": [
		{"name": "No food stand", "cost": 0, "q": 0.0, "rep": 0, "desc": ""},
		{"name": "Popcorn stand", "cost": 1500, "q": 1.0, "rep": 0, "desc": "Popcorn machine. Includes 20 free popcorn."},
		{"name": "Drinks counter", "cost": 1800, "q": 2.0, "rep": 0, "desc": "Cold drinks. Includes 20 free drinks."},
		{"name": "Snack counter", "cost": 4000, "q": 3.0, "rep": 10, "desc": "Nachos and snacks. Includes 20 free snacks."},
		{"name": "Food court", "cost": 12000, "q": 4.0, "rep": 30, "desc": "Combo meals and dining tables."}]},
	"training": {"name": "Staff training", "levels": [
		{"name": "Untrained staff", "cost": 0, "q": 1.0, "rep": 0, "desc": ""},
		{"name": "Basic training", "cost": 2000, "q": 1.25, "rep": 0, "desc": "Staff serve 25% faster."},
		{"name": "Pro training", "cost": 6000, "q": 1.5, "rep": 20, "desc": "Staff serve 50% faster."},
		{"name": "Expert training", "cost": 15000, "q": 1.8, "rep": 45, "desc": "Staff serve 80% faster."}]},
}

const FOOD_ORDER := ["popcorn", "drink", "snack", "meal"]
const FOOD := {
	"popcorn": {"name": "Popcorn", "price": 80, "cost": 20, "unlock": 1, "batch": 20, "start": 20, "bias": 0.85},
	"drink": {"name": "Cold drink", "price": 60, "cost": 15, "unlock": 2, "batch": 20, "start": 20, "bias": 0.75},
	"snack": {"name": "Nachos", "price": 100, "cost": 35, "unlock": 3, "batch": 20, "start": 20, "bias": 0.45},
	"meal": {"name": "Combo meal", "price": 220, "cost": 90, "unlock": 4, "batch": 10, "start": 0, "bias": 0.5},
}

const STAFF := {
	"cashier": {"name": "Cashier", "wage": 400, "hire": 200, "max": 2, "min": 1, "desc": "Sells tickets. More cashiers = shorter ticket queues."},
	"server": {"name": "Food server", "wage": 350, "hire": 200, "max": 2, "min": 0, "desc": "Serves the food counter. Required to sell food."},
	"cleaner": {"name": "Cleaner", "wage": 300, "hire": 150, "max": 3, "min": 0, "desc": "Cleans litter (Rs 5 supplies each). Keeps the cinema clean."},
}

const DECOR := {
	"posters": {"name": "Movie poster wall", "cost": 800, "fac": 0.10, "demand": 0.0},
	"plants": {"name": "Lobby plants", "cost": 600, "fac": 0.08, "demand": 0.0},
	"carpet": {"name": "Red carpet", "cost": 2500, "fac": 0.15, "demand": 0.0},
	"neon": {"name": "Neon marquee sign", "cost": 1500, "fac": 0.05, "demand": 0.08},
	"arcade": {"name": "Arcade corner", "cost": 3000, "fac": 0.12, "demand": 0.06},
}
const DECOR_ORDER := ["posters", "plants", "carpet", "neon", "arcade"]

const ACHIEVEMENTS := [
	{"id": "first_ticket", "name": "Box Office Open", "desc": "Sell your first ticket.", "reward": 200},
	{"id": "tickets_100", "name": "Hundred Club", "desc": "Sell 100 tickets.", "reward": 500},
	{"id": "tickets_1000", "name": "Blockbuster", "desc": "Sell 1,000 tickets.", "reward": 2500},
	{"id": "popcorn_50", "name": "Popcorn Pro", "desc": "Sell 50 popcorn.", "reward": 400},
	{"id": "profit_5000", "name": "Good Day", "desc": "Reach 5,000 profit in a single day.", "reward": 1000},
	{"id": "rep_50", "name": "Local Favourite", "desc": "Reach reputation 50.", "reward": 1500},
	{"id": "rep_80", "name": "Five-star Cinema", "desc": "Reach reputation 80.", "reward": 5000},
	{"id": "hall_2", "name": "Second Screen", "desc": "Open Hall 2.", "reward": 1000},
	{"id": "hall_3", "name": "Multiplex", "desc": "Open Hall 3.", "reward": 3000},
	{"id": "clean_90", "name": "Spotless", "desc": "End a day with cleanliness above 90%.", "reward": 800},
	{"id": "cash_100k", "name": "Tycoon", "desc": "Hold 100,000 in cash.", "reward": 0},
	{"id": "luxury", "name": "Luxury Complex", "desc": "Reach the Luxury Cinema Complex rank.", "reward": 5000},
]

var _movie_map := {}
var _seat_cache := {}
var _wall_cache := {}
var _furn_cache := {}
var _static_cache := {}

func _ready() -> void:
	for m in MOVIES:
		_movie_map[m.id] = m

func movie(id: String) -> Dictionary:
	return _movie_map.get(id, {})

func cell_center(c: Vector2i) -> Vector2:
	return (Vector2(c) + Vector2(0.5, 0.5)) * CELL

func cell_of(p: Vector2) -> Vector2i:
	return Vector2i(int(floor(p.x / CELL)), int(floor(p.y / CELL)))

func hall_door_cell(i: int) -> Vector2i:
	return Vector2i(23, HALLS[i].rect.position.y + 6)

func hall_seats(i: int) -> Array:
	if _seat_cache.has(i):
		return _seat_cache[i]
	var h: Dictionary = HALLS[i]
	var y0: int = h.rect.position.y
	var seats := []
	for row in 4:
		var y := y0 + 2 + row
		for block in 2:
			var cols: Array = h.left if block == 0 else h.right
			for x in cols:
				seats.append({"cell": Vector2i(x, y), "access": Vector2i(AISLE_X, y), "row": row, "block": block})
	_seat_cache[i] = seats
	return seats

func seat_pos(hall: int, idx: int) -> Vector2:
	return cell_center(hall_seats(hall)[idx].cell)

func wall_cells() -> Dictionary:
	if not _wall_cache.is_empty():
		return _wall_cache
	var s := {}
	for x in GRID_W:
		s[Vector2i(x, 0)] = true
		if x < 10 or x > 12:
			s[Vector2i(x, 24)] = true
	for y in range(0, 25):
		s[Vector2i(0, y)] = true
		s[Vector2i(GRID_W - 1, y)] = true
		s[Vector2i(23, y)] = true
	for i in 3:
		s.erase(hall_door_cell(i))
	for x in range(23, GRID_W):
		s[Vector2i(x, 8)] = true
		s[Vector2i(x, 16)] = true
	for x in range(0, 23):
		s[Vector2i(x, 6)] = true
	for dx in [4, 12, 19]:
		s.erase(Vector2i(dx, 6))
	for y in range(1, 6):
		s[Vector2i(9, y)] = true
		s[Vector2i(16, y)] = true
	_wall_cache = s
	return s

func furniture_cells() -> Dictionary:
	if not _furn_cache.is_empty():
		return _furn_cache
	var s := {}
	for x in range(3, 8):
		s[Vector2i(x, 15)] = true
	for x in range(14, 20):
		s[Vector2i(x, 15)] = true
	for x in range(18, 22):
		s[Vector2i(x, 22)] = true
	for x in range(1, 9):
		s[Vector2i(x, 1)] = true
	for x in range(3, 6):
		s[Vector2i(x, 3)] = true
	for x in range(10, 16):
		s[Vector2i(x, 1)] = true
		s[Vector2i(x, 2)] = true
	for x in range(17, 22):
		s[Vector2i(x, 1)] = true
		s[Vector2i(x, 2)] = true
	_furn_cache = s
	return s

func static_solids() -> Dictionary:
	if not _static_cache.is_empty():
		return _static_cache
	var s := wall_cells().duplicate()
	s.merge(furniture_cells())
	_static_cache = s
	return s

# --- Helpers -----------------------------------------------------------------------
func money(n: int) -> String:
	var s := str(absi(n))
	var out := ""
	var c := 0
	for i in range(s.length() - 1, -1, -1):
		out = s[i] + out
		c += 1
		if c % 3 == 0 and i > 0:
			out = "," + out
	return ("-" if n < 0 else "") + CURRENCY + out

const CURRENCY := "₹"

func fmt_time(h: float) -> String:
	var total := int(round(h * 60.0))
	return "%02d:%02d" % [(total / 60) % 24, total % 60]

func as_dict(v) -> Dictionary:
	return v if typeof(v) == TYPE_DICTIONARY else {}

func as_array(v) -> Array:
	return v if typeof(v) == TYPE_ARRAY else []

func pick_type(rep: float) -> String:
	var total := 0.0
	var weights := {}
	for id in CUSTOMER_TYPES:
		var w: float = CUSTOMER_TYPES[id].weight
		if id == "premium":
			w *= 0.3 + rep / 40.0
		elif id == "budget":
			w *= 1.4 - rep / 150.0
		weights[id] = w
		total += w
	var r := randf() * total
	for id in weights:
		r -= weights[id]
		if r <= 0.0:
			return id
	return "budget"
