# Circuit Breaker - Bauteil-System
# Definiert alle Bauteil-Typen und ihre Effekte auf Datenpakete.

class_name Component

enum ComponentType {
	TRACE,  # Leiterbahn - leitet nur weiter, 0 Watt
	CPU,    # Addiert +5 zum Paketwert, 2 Watt
	GPU,    # Multipliziert mit 2, 5 Watt
	LOOP,   # Lässt Paket 2x durchlaufen, 3 Watt
	NPU     # +3 pro benachbarter CPU, 4 Watt
}

# Gibt einen lesbaren Namen für den Bauteil-Typ zurück
static func get_type_name(type: ComponentType) -> String:
	match type:
		ComponentType.TRACE:
			return "Leiterbahn"
		ComponentType.CPU:
			return "CPU"
		ComponentType.GPU:
			return "GPU"
		ComponentType.LOOP:
			return "Loop"
		ComponentType.NPU:
			return "NPU"
	return "Unbekannt"

# Gibt die Watt-Kosten für einen Bauteil-Typ zurück
static func get_watt_cost(type: ComponentType) -> int:
	match type:
		ComponentType.TRACE:
			return 0
		ComponentType.CPU:
			return 2
		ComponentType.GPU:
			return 5
		ComponentType.LOOP:
			return 3
		ComponentType.NPU:
			return 4
	return 0

# Gibt ein einzelnes Zeichen für die Konsolendarstellung zurück
static func get_display_char(type: ComponentType) -> String:
	match type:
		ComponentType.TRACE:
			return "="
		ComponentType.CPU:
			return "C"
		ComponentType.GPU:
			return "G"
		ComponentType.LOOP:
			return "L"
		ComponentType.NPU:
			return "N"
	return "?"

# Wendet den Bauteil-Effekt auf ein Datenpaket an
# Rückgabe: Der neue Wert nach Verarbeitung
static func process_packet(type: ComponentType, packet_value: int, board_reference = null, row: int = -1, col: int = -1) -> int:
	var result = packet_value
	
	match type:
		ComponentType.TRACE:
			# Leiterbahn verändert nichts
			pass
		
		ComponentType.CPU:
			# CPU addiert +5
			result += 5
		
		ComponentType.GPU:
			# GPU multipliziert mit 2
			result *= 2
		
		ComponentType.LOOP:
			# Loop: Wendet CPU-Effekt 2x an (addiert 2x+5) 
			# Simuliert: Paket durchläuft 2x einen CPU-ähnlichen Boost
			result += 10  # 2 * +5 (wie 2 CPU-Durchläufe)
		
		ComponentType.NPU:
			# NPU: +3 pro benachbarter CPU
			var cpu_count = 0
			if board_reference != null and row >= 0 and col >= 0:
				var neighbors = [
					[ row - 1, col ],
					[ row + 1, col ],
					[ row, col - 1 ],
					[ row, col + 1 ]
				]
				for n in neighbors:
					var n_row = n[0]
					var n_col = n[1]
					if n_row >= 0 and n_row < 4 and n_col >= 0 and n_col < 6:
						var neighbor = board_reference.get_component(n_col, n_row)
						if neighbor != null and neighbor == ComponentType.CPU:
							cpu_count += 1
			result += cpu_count * 3
	
	return result

# Gibt die Beschreibung für einen Bauteil-Typ zurück
static func get_description(type: ComponentType) -> String:
	match type:
		ComponentType.TRACE:
			return "Leitet Paket ohne Veränderung weiter (0W)"
		ComponentType.CPU:
			return "Addiert +5 zum Paketwert (2W)"
		ComponentType.GPU:
			return "Multipliziert Paketwert mit 2 (5W)"
		ComponentType.LOOP:
			return "Lässt Paket 2x durchlaufen (3W)"
		ComponentType.NPU:
			return "+3 pro benachbarter CPU (4W)"
	return ""