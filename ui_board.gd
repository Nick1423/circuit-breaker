# Circuit Breaker - Grafische Brett-Darstellung
# Zeichnet das 6x4 Spielfeld mit farbigen Kacheln und Maus-Interaktion.

extends Control

const Component = preload("res://component.gd")

# Größe und Layout
const TILE_SIZE: int = 80
const TILE_MARGIN: int = 4
const BOARD_OFFSET_X: int = 40
const BOARD_OFFSET_Y: int = 80

# Farben für Bauteile
const COLORS = {
	null: Color(0.2, 0.2, 0.2, 1),        # Leer - Dunkelgrau
	Component.ComponentType.TRACE: Color(0.4, 0.4, 0.4, 1),  # Grau
	Component.ComponentType.CPU: Color(0.2, 0.6, 0.8, 1),    # Blau
	Component.ComponentType.GPU: Color(0.8, 0.2, 0.2, 1),    # Rot
	Component.ComponentType.LOOP: Color(0.2, 0.8, 0.4, 1),   # Grün
	Component.ComponentType.NPU: Color(0.8, 0.6, 0.2, 1),    # Orange
}

var board_ref = null  # Referenz auf board.gd
var tile_rects: Array = []  # Für Klick-Erkennung

var mouse_col: int = -1
var mouse_row: int = -1


func _ready() -> void:
	custom_minimum_size = Vector2(600, 500)
	board_ref = $"../Board"


func _draw() -> void:
	tile_rects.clear()
	
	# Überschrift
	draw_string(ThemeDB.fallback_font, Vector2(20, 30), "Platine", HORIZONTAL_ALIGNMENT_LEFT, -1, 20, Color.WHITE)
	
	# Watt-Anzeige
	if board_ref:
		var watt_text = "Watt: %d/%d" % [board_ref.get_used_watt(), board_ref.watt_budget]
		draw_string(ThemeDB.fallback_font, Vector2(20, 55), watt_text, HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color.LIGHT_GRAY)
	
	# Brett zeichnen
	for row in range(6):  # Wir zeichnen 6 Zeilen für bessere Optik (2. Reihe später)
		for col in range(6):
			var x = BOARD_OFFSET_X + col * (TILE_SIZE + TILE_MARGIN)
			var y = BOARD_OFFSET_Y + row * (TILE_SIZE + TILE_MARGIN)
			var rect = Rect2(x, y, TILE_SIZE, TILE_SIZE)
			
			# Farbe bestimmen
			var comp = null
			if board_ref and row < 4:
				comp = board_ref.get_component(col, row)
			
			var color = COLORS[comp] if comp in COLORS else COLORS[null]
			
			# Hover-Effekt
			if col == mouse_col and row == mouse_row and row < 4:
				color = color.lightened(0.3)
			
			# Kachel zeichnen
			draw_rect(rect, color, true)
			draw_rect(rect, Color(1, 1, 1, 0.2), false, 2)
			
			# Bauteil-Buchstabe
			if comp != null:
				var text = Component.get_display_char(comp)
				var font = ThemeDB.fallback_font
				var text_size = font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, 24)
				var text_pos = Vector2(
					x + (TILE_SIZE - text_size.x) / 2,
					y + (TILE_SIZE + text_size.y) / 2
				)
				draw_string(font, text_pos, text, HORIZONTAL_ALIGNMENT_LEFT, -1, 24, Color.WHITE)
			
			# Spalten-/Zeilennummern
			if row == 5:
				var num_text = str(col)
				var font = ThemeDB.fallback_font
				draw_string(font, Vector2(x + 35, y + 20), num_text, HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color.GRAY)
			
			# Merken für Klick-Erkennung (nur Spielfeld 0-3)
			if row < 4:
				tile_rects.append({
					"rect": rect,
					"col": col,
					"row": row
				})
	
	# Legende
	var legend_y = BOARD_OFFSET_Y + 4 * (TILE_SIZE + TILE_MARGIN) + 30
	draw_string(ThemeDB.fallback_font, Vector2(20, legend_y), "Legende:", HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color.WHITE)
	
	var legend_items = [
		[Component.ComponentType.CPU, "CPU (+5, 2W)"],
		[Component.ComponentType.GPU, "GPU (x2, 5W)"],
		[Component.ComponentType.LOOP, "LOOP (+10, 3W)"],
		[Component.ComponentType.NPU, "NPU (+3/CPU, 4W)"],
		[Component.ComponentType.TRACE, "TRACE (=, 0W)"],
	]
	
	for i in range(legend_items.size()):
		var lx = 20 + i * 120
		var ly = legend_y + 25
		var lcolor = COLORS[legend_items[i][0]]
		draw_rect(Rect2(lx, ly - 12, 16, 16), lcolor, true)
		draw_string(ThemeDB.fallback_font, Vector2(lx + 20, ly + 5), legend_items[i][1], HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color.LIGHT_GRAY)


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		mouse_col = -1
		mouse_row = -1
		for tile in tile_rects:
			if tile["rect"].has_point(event.position):
				mouse_col = tile["col"]
				mouse_row = tile["row"]
				break
		queue_redraw()
	
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		# Klick auf Kachel
		for tile in tile_rects:
			if tile["rect"].has_point(event.position):
				var col = tile["col"]
				var row = tile["row"]
				
				# Prüfen ob Feld belegt
				if board_ref and board_ref.get_component(col, row) == null:
					# Platzieren
					var gm = $"../GameManager"
					if gm and gm.phase == gm.GamePhase.BUILD:
						var success = board_ref.place_component(col, row, gm.selected_component)
						if success:
							gm.stats.components_placed += 1
							queue_redraw()
				else:
					# Entfernen (Rechtsklick oder Shift+Klick)
					if board_ref:
						board_ref.remove_component(col, row)
						queue_redraw()
				break