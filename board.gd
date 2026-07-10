extends Node2D

const Component = preload("res://component.gd")

# Circuit Breaker - Spielfeld (Board)
# Das Brett ist 6x4. Jede Zelle kann ein Bauteil (ComponentType) oder null (leer) enthalten.

# Das Spielbrett als 2D-Array
# board[Zeile][Spalte] = null (leer) oder ComponentType
# Zeilen: 0 (oben) bis 3 (unten)
# Spalten: 0 (links) bis 5 (rechts)
var board: Array = []

# Breite (Spalten) und Höhe (Zeilen) des Bretts
const BOARD_WIDTH: int = 6
const BOARD_HEIGHT: int = 4

# Watt-Budget für den aktuellen Run
var watt_budget: int = 10


func _ready() -> void:
	# Leeres 2D-Array anlegen
	_init_board()
	
	# Brett in der Konsole ausgeben
	print_board()


# Erzeugt ein 2D-Array mit BOARD_HEIGHT Zeilen und BOARD_WIDTH Spalten.
# Jedes Feld bekommt den Wert null (= leer).
func _init_board() -> void:
	board.clear()
	for row in range(BOARD_HEIGHT):
		var new_row: Array = []
		for col in range(BOARD_WIDTH):
			new_row.append(null)
		board.append(new_row)


# Gibt das gesamte Brett Zeile für Zeile in der Konsole aus.
# Ein leerer Platz wird als "." dargestellt, Bauteile als Buchstabe.
func print_board() -> void:
	print("=== Spielfeld (", BOARD_WIDTH, "x", BOARD_HEIGHT, ") ===")
	print("Watt-Budget: ", get_used_watt(), "/", watt_budget)
	print()
	
	for row in range(BOARD_HEIGHT):
		var line: String = ""
		for col in range(BOARD_WIDTH):
			var cell = board[row][col]
			if cell == null:
				line += ". "
			else:
				line += Component.get_display_char(cell) + " "
		print(line)
	
	print()


# ---- Platzierung / Entfernung ----

# Platziert ein Bauteil an Position (col, row).
# Gibt true zurück bei Erfolg, false bei Misserfolg.
func place_component(col: int, row: int, type: Component.ComponentType) -> bool:
	if not _is_in_bounds(col, row):
		print("FEHLER: Position (", col, ", ", row, ") ist außerhalb des Bretts!")
		return false
	
	if board[row][col] != null:
		print("FEHLER: Feld (", col, ", ", row, ") ist bereits belegt!")
		return false
	
	if get_used_watt() + Component.get_watt_cost(type) > watt_budget:
		print("FEHLER: Nicht genug Watt! (", get_used_watt(), " + ", Component.get_watt_cost(type), " > ", watt_budget, ")")
		return false
	
	board[row][col] = type
	print("Platziert: ", Component.get_type_name(type), " bei (", col, ", ", row, ")")
	return true


# Entfernt ein Bauteil von Position (col, row).
# Gibt true zurück bei Erfolg, false wenn das Feld leer war.
func remove_component(col: int, row: int) -> bool:
	if not _is_in_bounds(col, row):
		print("FEHLER: Position (", col, ", ", row, ") ist außerhalb des Bretts!")
		return false
	
	if board[row][col] == null:
		print("FEHLER: Feld (", col, ", ", row, ") ist bereits leer!")
		return false
	
	var removed = board[row][col]
	board[row][col] = null
	print("Entfernt: ", Component.get_type_name(removed), " von (", col, ", ", row, ")")
	return true


# Gibt den Bauteil-Typ an Position (col, row) zurück (oder null).
func get_component(col: int, row: int):
	if not _is_in_bounds(col, row):
		return null
	return board[row][col]


# ---- Paketfluss-Simulation ----

# Simuliert ein Paket, das durch eine bestimmte Zeile (row) von links nach rechts fließt.
# Das Paket startet links mit Wert 1 und durchläuft alle Bauteile in der Zeile.
# Gibt den finalen Paketwert zurück.
func simulate_packet_flow(row: int) -> int:
	if row < 0 or row >= BOARD_HEIGHT:
		print("FEHLER: Ungültige Zeile ", row)
		return 0
	
	var packet_value = 1  # Startwert
	
	print("  Paket startet mit Wert ", packet_value, " in Zeile ", row)
	
	for col in range(BOARD_WIDTH):
		var component = board[row][col]
		if component != null:
			var before = packet_value
			packet_value = Component.process_packet(component, packet_value, self, row, col)
			print("    Spalte ", col, ": ", Component.get_type_name(component), " -> ", before, " -> ", packet_value)
	
	print("  Paket-Endwert: ", packet_value)
	return packet_value


# ---- Hilfsfunktionen ----

# Prüft, ob eine Position innerhalb des Bretts liegt.
func _is_in_bounds(col: int, row: int) -> bool:
	return col >= 0 and col < BOARD_WIDTH and row >= 0 and row < BOARD_HEIGHT


# Gibt den aktuell verbrauchten Watt-Wert zurück.
func get_used_watt() -> int:
	var total = 0
	for row in range(BOARD_HEIGHT):
		for col in range(BOARD_WIDTH):
			var comp = board[row][col]
			if comp != null:
				total += Component.get_watt_cost(comp)
	return total


# Gibt eine Liste aller leeren Positionen zurück.
func get_available_positions() -> Array:
	var positions = []
	for row in range(BOARD_HEIGHT):
		for col in range(BOARD_WIDTH):
			if board[row][col] == null:
				positions.append({"col": col, "row": row})
	return positions


# Gibt eine Liste aller platzierten Bauteile mit Positionen zurück.
func get_all_components() -> Array:
	var components = []
	for row in range(BOARD_HEIGHT):
		for col in range(BOARD_WIDTH):
			var comp = board[row][col]
			if comp != null:
				components.append({
					"type": comp,
					"col": col,
					"row": row
				})
	return components


# Leert das gesamte Brett.
func clear_board() -> void:
	_init_board()
	print("Brett wurde geleert.")