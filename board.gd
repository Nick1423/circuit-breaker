extends Node2D

# Das Spielbrett (Board) als 2D-Array
# board[Zeile][Spalte] = null (leer)
# Zeilen: 0 (oben) bis 3 (unten)
# Spalten: 0 (links) bis 5 (rechts)
var board: Array = []

# Breite (Spalten) und Höhe (Zeilen) des Bretts
const BOARD_WIDTH: int = 6
const BOARD_HEIGHT: int = 4


func _ready() -> void:
	# Schritt 1: Leeres 2D-Array anlegen
	_init_board()
	
	# Schritt 2: Brett in der Konsole ausgeben
	print_board()


# Erzeugt ein 2D-Array mit BOARD_HEIGHT Zeilen und BOARD_WIDTH Spalten.
# Jedes Feld bekommt den Wert null (= leer).
func _init_board() -> void:
	# Äußere Schleife: Zeilen (y-Richtung, vertikal)
	for row in range(BOARD_HEIGHT):
		# Leeres Array für diese Zeile anlegen
		var new_row: Array = []
		
		# Innere Schleife: Spalten (x-Richtung, horizontal)
		for col in range(BOARD_WIDTH):
			# Jedes Feld mit null initialisieren (leer)
			new_row.append(null)
		
		# Die fertige Zeile ans Brett anhängen
		board.append(new_row)


# Gibt das gesamte Brett Zeile für Zeile in der Konsole aus.
# Ein leerer Platz wird als "." dargestellt.
func print_board() -> void:
	print("=== Spielfeld (", BOARD_WIDTH, "x", BOARD_HEIGHT, ") ===")
	
	# Jede Zeile durchgehen
	for row in range(BOARD_HEIGHT):
		var line: String = ""
		
		# Jede Spalte in dieser Zeile durchgehen
		for col in range(BOARD_WIDTH):
			var cell = board[row][col]
			
			if cell == null:
				line += ". "
			else:
				# Später zeigen wir hier den Bauteil-Namen an
				line += str(cell) + " "
		
		# Die ganze Zeile ausgeben
		print(line)
	
	print()  # Leerzeile am Ende