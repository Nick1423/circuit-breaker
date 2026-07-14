extends Node2D

# Component und Block sind über class_name global verfügbar – kein preload nötig.

# Core Cocker - Spielfeld (Board)
# 6 Spalten x 5 Zeilen. Jede Zelle enthält einen Block (nur Ausgang, drehbar) oder
# null. Es gibt GENAU einen Eingang (linker Rand, mittlere Zeile) und einen
# Ausgang (rechter Rand, mittlere Zeile). Ein einzelnes Paket startet am Eingang,
# läuft nach Osten in die erste Zelle und folgt danach immer der Ausgangsrichtung
# des Blocks in der aktuellen Zelle – bis es den Ausgang erreicht (Treffer), eine
# leere Zelle/den Rand trifft (verloren) oder in eine Schleife läuft. Weil jede
# Zelle nur einen Ausgang hat, ist der Weg eindeutig (siehe simulate_route()).

# board[Zeile][Spalte] = Block oder null
var board: Array = []

const BOARD_WIDTH: int = 6
const BOARD_HEIGHT: int = 5
# Mittlere Zeile (Ein-/Ausgang). Bei ungerader Höhe eindeutig -> Zeile 2.
const MID_ROW: int = 2


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

# Platziert einen neuen Block eines Typs (Standard-Ausgang: Osten).
# Gibt true bei Erfolg zurück.
func place_component(col: int, row: int, type: int, dir: int = Block.Dir.EAST, tier: int = 0) -> bool:
	if not _is_in_bounds(col, row):
		push_warning("Platzierung außerhalb des Bretts: (%d,%d)" % [col, row])
		return false
	if board[row][col] != null:
		return false
	board[row][col] = Block.new(type, dir, tier)
	return true


# Setzt eine EXISTIERENDE Block-Instanz ein (behält deren Ausgangsrichtung).
# Für das Verschieben auf ein leeres Feld.
func put_block(col: int, row: int, block) -> bool:
	if not _is_in_bounds(col, row) or block == null or board[row][col] != null:
		return false
	board[row][col] = block
	return true


# Nimmt die Block-Instanz an (col,row) heraus und leert das Feld. Gibt sie zurück
# (oder null). Behält Ausgangsrichtung – für Verschieben ohne Drehungsverlust.
func take_block(col: int, row: int):
	if not _is_in_bounds(col, row):
		return null
	var b = board[row][col]
	board[row][col] = null
	return b


# Tauscht die Blöcke zweier Felder (Ausrichtung wandert mit).
func swap_blocks(c1: int, r1: int, c2: int, r2: int) -> void:
	if not _is_in_bounds(c1, r1) or not _is_in_bounds(c2, r2):
		return
	var tmp = board[r1][c1]
	board[r1][c1] = board[r2][c2]
	board[r2][c2] = tmp


# Dreht den Ausgang des Blocks an (col,row) im Uhrzeigersinn. Gibt true bei Erfolg.
func rotate_block(col: int, row: int) -> bool:
	var b = get_block(col, row)
	if b == null:
		return false
	b.rotate_cw()
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
				var nb = get_block(col + d[1], row + d[0])
				if nb != null and nb.type == Component.ComponentType.HEATSINK:
					h -= Component.cooler_strength(nb.tier)
			total += max(0, h)
	return total


# Bonus aufs Hitze-Limit durch platzierte Netzteile (+3 je PSU, mehr bei Übertaktung).
func get_power_bonus() -> int:
	var bonus = 0
	for row in range(BOARD_HEIGHT):
		for col in range(BOARD_WIDTH):
			var b = board[row][col]
			if b != null and b.type == Component.ComponentType.PSU:
				bonus += Component.psu_bonus(b.tier)
	return bonus


# Endschaden-Multiplikator durch platzierte Mainboards (+50% je Stück, mehr bei Übertaktung).
func get_board_multiplier() -> float:
	var mult = 1.0
	for row in range(BOARD_HEIGHT):
		for col in range(BOARD_WIDTH):
			var b = board[row][col]
			if b != null and b.type == Component.ComponentType.MAINBOARD:
				mult += Component.mainboard_bonus(b.tier)
	return mult


# ---- Paket-Routing: EIN Paket folgt den Ausgangsrichtungen ----

# Simuliert den kompletten Weg des Pakets. Es startet am Eingang (links, MID_ROW)
# in Richtung Osten, betritt Zelle (0, MID_ROW) und folgt dann immer dem Ausgang
# des jeweiligen Blocks. Ergebnis:
# {
#   "value": int,           # aufgesammelter Endwert
#   "path": Array,          # [{col,row,before,after,type,dir}] für die Animation
#   "delivered": bool,      # Paket hat den Ausgang (rechts, MID_ROW) erreicht
#   "reason": String,       # "delivered" | "empty" | "offgrid" | "loop"
#   "end_col": int, "end_row": int,  # Zelle, aus der das Paket austritt/stoppt
# }
func simulate_route(start_value: int = 1) -> Dictionary:
	var path: Array = []
	var value := start_value
	var col := 0
	var row := MID_ROW
	var prev_type := -1
	var prev_tier := 0
	var visited := {}
	var delivered := false
	var reason := "empty"

	while true:
		if not _is_in_bounds(col, row):
			# Rechts über die mittlere Zeile hinaus -> am Ausgang angekommen.
			if col == BOARD_WIDTH and row == MID_ROW:
				delivered = true
				reason = "delivered"
			else:
				reason = "offgrid"
			break

		var key := Vector2i(col, row)
		if visited.has(key):
			reason = "loop"
			break

		var b = board[row][col]
		if b == null:
			reason = "empty"
			break

		visited[key] = true
		var before: int = value
		var idx: int = path.size()  # Anzahl bereits durchlaufener Blöcke
		match b.type:
			Component.ComponentType.CACHE:
				# Cache wiederholt den Effekt des vorherigen Blocks (tier = wie oft).
				if prev_type != -1:
					for _i in range(Component.cache_repeats(b.tier)):
						value = Component.process_packet(prev_type, value, prev_tier)
			Component.ComponentType.RAM:
				# RAM: +2 (bzw. mehr bei Übertaktung) je bereits durchlaufenem Baustein.
				value += Component.ram_per(b.tier) * idx
			_:
				value = Component.process_packet(b.type, value, b.tier)
		prev_type = b.type
		prev_tier = b.tier
		path.append({
			"col": col, "row": row, "before": before, "after": value,
			"type": b.type, "dir": b.out_dir, "tier": b.tier,
		})

		var d := Block.dir_delta(b.out_dir)
		col += d.x
		row += d.y

	return {
		"value": value,
		"path": path,
		"delivered": delivered,
		"reason": reason,
		"end_col": col,
		"end_row": row,
	}
