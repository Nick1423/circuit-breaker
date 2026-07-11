extends Node2D

# Component und Block sind über class_name global verfügbar – kein preload nötig.

# Circuit Breaker - Spielfeld (Board)
# 6x4-Raster. Jede Zelle enthält einen Block (mit Ein-/Ausgang) oder null.
# Pakete betreten das Board am linken Rand und suchen sich über die Ports
# ihren Weg nach rechts (siehe simulate_path()).

# board[Zeile][Spalte] = Block oder null
var board: Array = []

const BOARD_WIDTH: int = 6
const BOARD_HEIGHT: int = 4

# Watt-Budget (nur noch informativ, kein hartes Limit mehr)
var watt_budget: int = 10


func _ready() -> void:
	_init_board()


func _init_board() -> void:
	board.clear()
	for _row in range(BOARD_HEIGHT):
		var new_row: Array = []
		for _col in range(BOARD_WIDTH):
			new_row.append(null)
		board.append(new_row)


func print_board() -> void:
	print("=== Spielfeld (", BOARD_WIDTH, "x", BOARD_HEIGHT, ") ===")
	print("Hitze: ", get_total_heat())
	for row in range(BOARD_HEIGHT):
		var line: String = ""
		for col in range(BOARD_WIDTH):
			var b = board[row][col]
			line += (Component.get_display_char(b.type) if b != null else ".") + " "
		print(line)


# ---- Hilfen ----

func _is_in_bounds(col: int, row: int) -> bool:
	return col >= 0 and col < BOARD_WIDTH and row >= 0 and row < BOARD_HEIGHT


# Gibt den Block an (col,row) zurück oder null.
func get_block(col: int, row: int):
	if not _is_in_bounds(col, row):
		return null
	return board[row][col]


# Kompatibilität: gibt den Typ (Component.ComponentType) an (col,row) zurück
# oder null. Wird von component.gd (Nachbar-Synergien, Hitze) genutzt.
func get_component(col: int, row: int):
	var b = get_block(col, row)
	return b.type if b != null else null


# ---- Platzierung / Entfernung ----

# Platziert einen Block eines Typs. Standard-Ports: Eingang links, Ausgang rechts.
# Gibt true bei Erfolg zurück.
func place_component(col: int, row: int, type: int) -> bool:
	if not _is_in_bounds(col, row):
		push_warning("Platzierung außerhalb des Bretts: (%d,%d)" % [col, row])
		return false
	if board[row][col] != null:
		return false
	board[row][col] = Block.new(type)
	return true


# Entfernt den Block an (col,row). Gibt den entfernten Typ zurück oder -1.
func remove_component(col: int, row: int) -> int:
	if not _is_in_bounds(col, row) or board[row][col] == null:
		return -1
	var removed_type = board[row][col].type
	board[row][col] = null
	return removed_type


func clear_board() -> void:
	_init_board()


# ---- Watt / Hitze ----

func get_used_watt() -> int:
	var total = 0
	for row in range(BOARD_HEIGHT):
		for col in range(BOARD_WIDTH):
			var b = board[row][col]
			if b != null:
				total += Component.get_watt_cost(b.type)
	return total


# Gesamte Hitze. Jeder benachbarte Kühler senkt die Hitze eines Blocks.
func get_total_heat() -> int:
	var total = 0
	var deltas = [[-1, 0], [1, 0], [0, -1], [0, 1]]
	for row in range(BOARD_HEIGHT):
		for col in range(BOARD_WIDTH):
			var b = board[row][col]
			if b == null:
				continue
			var h = Component.get_heat(b.type)
			for d in deltas:
				if get_component(col + d[1], row + d[0]) == Component.ComponentType.HEATSINK:
					h -= Component.COOLER_STRENGTH
			total += max(0, h)
	return total


# Bonus aufs Hitze-Limit durch platzierte Netzteile (+3 je PSU).
func get_power_bonus() -> int:
	var count = 0
	for row in range(BOARD_HEIGHT):
		for col in range(BOARD_WIDTH):
			var b = board[row][col]
			if b != null and b.type == Component.ComponentType.PSU:
				count += 1
	return count * Component.PSU_HEAT_BONUS


# Endschaden-Multiplikator durch platzierte Mainboards (+50% je Stück).
func get_board_multiplier() -> float:
	var count = 0
	for row in range(BOARD_HEIGHT):
		for col in range(BOARD_WIDTH):
			var b = board[row][col]
			if b != null and b.type == Component.ComponentType.MAINBOARD:
				count += 1
	return 1.0 + count * Component.MAINBOARD_BONUS


# ---- Paket-Routing (links rein, rechts raus) ----

# Simuliert den Weg eines Pakets. Rückgabe:
# {
#   "value": int,           # aufgesammelter Wert
#   "path": Array,          # [{col,row,before,after,type}]
#   "reached_end": bool,    # true, wenn das Paket den rechten Rand verlässt
#   "error": String         # leer, oder Grund für Abbruch
# }
func simulate_path(start_value: int = 1) -> Dictionary:
	var result := {"value": 0, "path": [], "reached_end": false, "error": ""}

	# Startblock finden: Spalte 0, Eingang nach links, oberster.
	var start_row := -1
	for row in range(BOARD_HEIGHT):
		var b = board[row][0]
		if b != null and b.in_dir == Block.Dir.LEFT:
			start_row = row
			break
	if start_row == -1:
		result.error = "Kein Startblock: setze in Spalte 0 einen Block mit Eingang nach links."
		return result

	var value := start_value
	var col := 0
	var row := start_row
	var prev_type := -1
	var visited := {}

	while true:
		var b = board[row][col]
		if b == null:
			result.error = "Interner Fehler: leeres Feld im Pfad."
			break

		# Effekt anwenden (LOOP wiederholt den vorherigen Block-Effekt)
		var before: int = value
		var prior: int = result.path.size()  # Anzahl bereits durchlaufener Bausteine
		match b.type:
			Component.ComponentType.CACHE:
				# Cache wiederholt den Effekt des vorherigen Bausteins
				if prev_type != -1:
					value = Component.process_packet(prev_type, value)
			Component.ComponentType.RAM:
				# RAM: +2 je bereits durchlaufenem Baustein
				value += 2 * prior
			_:
				value = Component.process_packet(b.type, value)
		prev_type = b.type

		result.path.append({
			"col": col, "row": row, "before": before, "after": value, "type": b.type
		})
		visited[Vector2i(col, row)] = true

		# Nächstes Feld anhand des Ausgangs
		var d: Vector2i = Block.delta(b.out_dir)
		var nc := col + d.x
		var nr := row + d.y

		# Rand verlassen?
		if not _is_in_bounds(nc, nr):
			result.reached_end = (b.out_dir == Block.Dir.RIGHT and col == BOARD_WIDTH - 1)
			if not result.reached_end:
				result.error = "Sackgasse: der Ausgang zeigt aus dem Board (nicht am rechten Rand)."
			break

		var nb = board[nr][nc]
		if nb == null:
			result.error = "Sackgasse: das nächste Feld (%d,%d) ist leer." % [nc, nr]
			break
		if nb.in_dir != Block.opposite(b.out_dir):
			result.error = "Ports passen nicht: (%d,%d) nimmt das Paket nicht an." % [nc, nr]
			break
		if visited.has(Vector2i(nc, nr)):
			result.error = "Schleife erkannt – der Pfad läuft im Kreis."
			break

		col = nc
		row = nr

	result.value = value
	return result


# ---- Listen ----

func get_all_components() -> Array:
	var items = []
	for row in range(BOARD_HEIGHT):
		for col in range(BOARD_WIDTH):
			var b = board[row][col]
			if b != null:
				items.append({"type": b.type, "col": col, "row": row})
	return items


func get_available_positions() -> Array:
	var positions = []
	for row in range(BOARD_HEIGHT):
		for col in range(BOARD_WIDTH):
			if board[row][col] == null:
				positions.append({"col": col, "row": row})
	return positions
