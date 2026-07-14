# Circuit Breaker - Inventar-System
# Verwaltet gekaufte Bauteile, die noch nicht auf dem Brett platziert sind.
# RefCounted (kein Node): wird nie in den Szenenbaum gehängt und gibt sich
# beim Ersetzen automatisch frei – kein manuelles free() nötig.

class_name Inventory

# Inventar: Liste von ComponentType-Werten
var items: Array = []

# Maximale Inventar-Größe (Board hat 30 Felder)
var max_size: int = 30


# Fügt ein Bauteil zum Inventar hinzu (Typ als int / Component.ComponentType)
func add_item(comp_type: int) -> bool:
	if items.size() >= max_size:
		return false
	items.append(comp_type)
	return true


# Entfernt und gibt ein Bauteil zurück (Typ als int, oder -1 wenn ungültig)
func take_item(index: int) -> int:
	if index < 0 or index >= items.size():
		return -1
	var comp = items[index]
	items.remove_at(index)
	return comp


# Gibt ein Bauteil zurück ohne es zu entfernen (Typ als int, oder -1)
func peek_item(index: int) -> int:
	if index < 0 or index >= items.size():
		return -1
	return items[index]


# Gibt die Anzahl der Items zurück
func get_item_count() -> int:
	return items.size()


# Gibt true zurück, wenn das Inventar leer ist
func is_empty() -> bool:
	return items.size() == 0
