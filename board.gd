extends Node2D

# Component und Block sind über class_name global verfügbar – kein preload nötig.

# Core Cocker - Spielfeld (Board)
# 6x4-Raster. Jede Zelle enthält einen Block (fester Eingang links, Ausgang
# rechts) oder null. Jede ZEILE ist eine eigene "Lane": liegt in Spalte 0 ein
# Block, startet dort ein Paket und fließt nach rechts durch die lückenlose
# Kette, bis eine Lücke oder der rechte Rand kommt (siehe simulate_lanes()).

# board[Zeile][Spalte] = Block oder null
var board: Array = []

const BOARD_WIDTH: int = 6
const BOARD_HEIGHT: int = 4


func _ready() -> void:
	_init_board()


func _init_board() -> void:
	board.clear()
	for _row in range(BOARD_HEIGHT):
		var new_row: Array = []
		for _col in range(BOARD_WIDTH):
			new_row.append(null)
		board.append(new_row)


# ---- Hilfen ----

func _is_in_bounds(col: int, row: int) -> bool:
	return col >= 0 and col < BOARD_WIDTH and row >= 0 and row < BOARD_HEIGHT


# Gibt den Block an (col,row) zurück oder null.
func get_block(col: int, row: int):
	if not _is_in_bounds(col, row):
		return null
	return board[row][col]


# Gibt den Typ (Component.ComponentType) an (col,row) zurück oder null.
# Wird für Nachbar-Synergien (Hitze) genutzt.
func get_component(col: int, row: int):
	var b = get_block(col, row)
	return b.type if b != null else null


# ---- Platzierung / Entfernung ----

# Platziert einen Block eines Typs (Eingang links, Ausgang rechts – fest).
# Gibt true bei Erfolg zurück.
func place_component(col: int, row: int, type: int) -> bool:
	if not _is_in_bounds(col, row):
		push_warning("Platzierung außerhalb des Bretts: (%d,%d)" % [col, row])
		return false
	if board[row][col] != null:
		return false
	board[row][col] = Block.new(type)
	return true


# Tauscht die Blöcke zweier Felder (fürs Drag-Verschieben auf ein belegtes Feld).
func swap_blocks(c1: int, r1: int, c2: int, r2: int) -> void:
	if not _is_in_bounds(c1, r1) or not _is_in_bounds(c2, r2):
		return
	var tmp = board[r1][c1]
	board[r1][c1] = board[r2][c2]
	board[r2][c2] = tmp


# Entfernt den Block an (col,row). Gibt den entfernten Typ zurück oder -1.
func remove_component(col: int, row: int) -> int:
	if not _is_in_bounds(col, row) or board[row][col] == null:
		return -1
	var removed_type = board[row][col].type
	board[row][col] = null
	return removed_type


func clear_board() -> void:
	_init_board()


# Anzahl belegter Felder.
func placed_count() -> int:
	var n := 0
	for row in range(BOARD_HEIGHT):
		for col in range(BOARD_WIDTH):
			if board[row][col] != null:
				n += 1
	return n


# ---- Hitze ----

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


# ---- Paket-Routing: Lanes (jede Zeile fließt links -> rechts) ----

# Simuliert EINE Zeile als Lane. Ein Paket startet in Spalte 0 (falls dort ein
# Block liegt) und läuft nach rechts durch die lückenlose Kette. Gibt {} zurück,
# wenn die Zeile keinen Startblock in Spalte 0 hat (inaktive Lane).
# {
#   "row": int,
#   "value": int,           # aufgesammelter Endwert
#   "path": Array,          # [{col,row,before,after,type}] für die Animation
#   "reached_end": bool,    # Kette reicht bis zur letzten Spalte (Durchbruch)
#   "stop_col": int,        # erste leere Spalte (oder BOARD_WIDTH)
# }
func simulate_lane(row: int, start_value: int = 1) -> Dictionary:
	if get_block(0, row) == null:
		return {}

	var value := start_value
	var col := 0
	var prev_type := -1
	var path: Array = []

	while col < BOARD_WIDTH and board[row][col] != null:
		var b = board[row][col]
		var before: int = value
		var idx: int = path.size()  # Anzahl bereits durchlaufener Blöcke in DIESER Lane
		match b.type:
			Component.ComponentType.CACHE:
				# Cache wiederholt den Effekt des vorherigen Blocks
				if prev_type != -1:
					value = Component.process_packet(prev_type, value)
			Component.ComponentType.RAM:
				# RAM: +2 je bereits durchlaufenem Block
				value += 2 * idx
			_:
				value = Component.process_packet(b.type, value)
		prev_type = b.type
		path.append({"col": col, "row": row, "before": before, "after": value, "type": b.type})
		col += 1

	return {
		"row": row,
		"value": value,
		"path": path,
		"reached_end": col == BOARD_WIDTH,  # bis über die letzte Spalte gelaufen -> Durchbruch
		"stop_col": col,
	}


# Simuliert alle aktiven Lanes (Zeilen mit Startblock in Spalte 0).
# Gibt ein Array von Lane-Dictionaries zurück (siehe simulate_lane).
func simulate_all_lanes(start_value: int = 1) -> Array:
	var lanes: Array = []
	for row in range(BOARD_HEIGHT):
		var lane := simulate_lane(row, start_value)
		if not lane.is_empty():
			lanes.append(lane)
	return lanes
