# Circuit Breaker - Bauteil-System
# Definiert alle Bauteil-Typen, ihre Kosten (Watt/Hitze) und ihre Effekte
# auf Datenpakete. Effekte berücksichtigen jetzt Nachbarn (Synergien).

class_name Component

enum ComponentType {
	TRACE,  # Leiterbahn - leitet nur weiter, 0 Watt
	CPU,    # Addiert +5 zum Paketwert, 2 Watt
	GPU,    # Multipliziert (x2 +1 je benachbarter CPU), 5 Watt
	LOOP,   # Wiederholt die Bauteile links davon in der Zeile, 3 Watt
	NPU,    # +3 pro benachbarter CPU, 4 Watt
	RAM,    # +2 pro belegtem Feld in der Zeile, 3 Watt
	CAP,    # Kondensator: x1.5 (aufgerundet), 4 Watt
	OC,     # Overclock: x3, aber viel Hitze, 6 Watt
	COOL    # Kühler: senkt Hitze der Nachbarn, kein Paket-Effekt, 1 Watt
}

# Wie stark ein Kühler die Hitze jedes Nachbarn senkt
const COOLER_STRENGTH: int = 2


# Gibt einen lesbaren Namen für den Bauteil-Typ zurück
static func get_type_name(type: ComponentType) -> String:
	match type:
		ComponentType.TRACE: return "Leiterbahn"
		ComponentType.CPU:   return "CPU"
		ComponentType.GPU:   return "GPU"
		ComponentType.LOOP:  return "Loop"
		ComponentType.NPU:   return "NPU"
		ComponentType.RAM:   return "RAM"
		ComponentType.CAP:   return "Kondensator"
		ComponentType.OC:    return "Overclock"
		ComponentType.COOL:  return "Kühler"
	return "Unbekannt"


# Gibt die Watt-Kosten für einen Bauteil-Typ zurück
static func get_watt_cost(type: ComponentType) -> int:
	match type:
		ComponentType.TRACE: return 0
		ComponentType.CPU:   return 2
		ComponentType.GPU:   return 5
		ComponentType.LOOP:  return 3
		ComponentType.NPU:   return 4
		ComponentType.RAM:   return 3
		ComponentType.CAP:   return 4
		ComponentType.OC:    return 6
		ComponentType.COOL:  return 1
	return 0


# Gibt die Hitze-Erzeugung eines Bauteils zurück (Basis, ohne Kühler-Effekt)
static func get_heat(type: ComponentType) -> int:
	match type:
		ComponentType.TRACE: return 0
		ComponentType.CPU:   return 1
		ComponentType.GPU:   return 3
		ComponentType.LOOP:  return 2
		ComponentType.NPU:   return 2
		ComponentType.RAM:   return 2
		ComponentType.CAP:   return 2
		ComponentType.OC:    return 5
		ComponentType.COOL:  return 0
	return 0


# Gibt ein einzelnes Zeichen für die Konsolendarstellung zurück
static func get_display_char(type: ComponentType) -> String:
	match type:
		ComponentType.TRACE: return "="
		ComponentType.CPU:   return "C"
		ComponentType.GPU:   return "G"
		ComponentType.LOOP:  return "L"
		ComponentType.NPU:   return "N"
		ComponentType.RAM:   return "R"
		ComponentType.CAP:   return "K"
		ComponentType.OC:    return "O"
		ComponentType.COOL:  return "*"
	return "?"


# Zählt direkte Nachbarn (oben/unten/links/rechts) eines bestimmten Typs.
static func _count_adjacent(board_reference, row: int, col: int, target: ComponentType) -> int:
	if board_reference == null or row < 0 or col < 0:
		return 0
	var count = 0
	var deltas = [[-1, 0], [1, 0], [0, -1], [0, 1]]
	for d in deltas:
		var nr = row + d[0]
		var nc = col + d[1]
		var neighbor = board_reference.get_component(nc, nr)
		if neighbor != null and neighbor == target:
			count += 1
	return count


# Wendet den Bauteil-Effekt auf ein Datenpaket an.
# LOOP und COOL werden hier NICHT verarbeitet – LOOP wird in board.gd als
# Wiederholung der linken Zeilen-Bauteile umgesetzt, COOL wirkt nur auf Hitze.
# Rückgabe: der neue Paketwert nach Verarbeitung.
static func process_packet(type: ComponentType, packet_value: int, board_reference = null, row: int = -1, col: int = -1) -> int:
	var result = packet_value

	match type:
		ComponentType.TRACE:
			pass

		ComponentType.CPU:
			result += 5

		ComponentType.GPU:
			# Basis x2, +1 auf den Multiplikator je benachbarter CPU (Synergie)
			var mult = 2 + _count_adjacent(board_reference, row, col, ComponentType.CPU)
			result *= mult

		ComponentType.NPU:
			# +3 pro benachbarter CPU
			result += 3 * _count_adjacent(board_reference, row, col, ComponentType.CPU)

		ComponentType.RAM:
			# +2 pro belegtem Feld in der GESAMTEN Zeile (volle Zeile lohnt sich)
			var occupied = 0
			if board_reference != null and row >= 0:
				for c in range(board_reference.BOARD_WIDTH):
					if board_reference.get_component(c, row) != null:
						occupied += 1
			result += 2 * occupied

		ComponentType.CAP:
			# Kondensator: x1.5, aufgerundet
			result = int(ceil(result * 1.5))

		ComponentType.OC:
			# Overclock: x3 (Preis: viel Hitze)
			result *= 3

		ComponentType.LOOP, ComponentType.COOL:
			# Werden separat behandelt (siehe board.gd)
			pass

	return result


# Gibt die Beschreibung für einen Bauteil-Typ zurück
static func get_description(type: ComponentType) -> String:
	match type:
		ComponentType.TRACE: return "Leitet Paket ohne Veränderung weiter (0W, 0H)"
		ComponentType.CPU:   return "Addiert +5 zum Paketwert (2W, 1H)"
		ComponentType.GPU:   return "x2, +1 Multiplikator je benachbarter CPU (5W, 3H)"
		ComponentType.LOOP:  return "Wiederholt die Bauteile links davon in der Zeile (3W, 2H)"
		ComponentType.NPU:   return "+3 pro benachbarter CPU (4W, 2H)"
		ComponentType.RAM:   return "+2 pro belegtem Feld in der Zeile (3W, 2H)"
		ComponentType.CAP:   return "Kondensator: x1.5 aufgerundet (4W, 2H)"
		ComponentType.OC:    return "Overclock: x3, erzeugt viel Hitze (6W, 5H)"
		ComponentType.COOL:  return "Kühler: senkt Hitze der 4 Nachbarn um 2 (1W, 0H)"
	return ""
