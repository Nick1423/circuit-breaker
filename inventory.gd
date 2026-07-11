# Circuit Breaker - Inventar-System
# Verwaltet gekaufte Bauteile, die noch nicht auf dem Brett platziert sind.

extends Node

const Component = preload("res://component.gd")

# Inventar: Liste von ComponentType-Werten
var items: Array = []

# Maximale Inventar-Größe (Board hat 24 Felder)
var max_size: int = 24


func _init() -> void:
	pass


# Fügt ein Bauteil zum Inventar hinzu
func add_item(comp_type: Component.ComponentType) -> bool:
	if items.size() >= max_size:
		print("Inventar voll!")
		return false
	
	items.append(comp_type)
	print("+ ", Component.get_type_name(comp_type), " (Inventar: ", items.size(), "/", max_size, ")")
	return true


# Entfernt und gibt ein Bauteil zurück (zum Platzieren)
func take_item(index: int) -> Component.ComponentType:
	if index < 0 or index >= items.size():
		return -1  # Invalid
	
	var comp = items[index]
	items.remove_at(index)
	return comp


# Gibt ein Bauteil zurück ohne es zu entfernen
func peek_item(index: int) -> Component.ComponentType:
	if index < 0 or index >= items.size():
		return -1
	return items[index]


# Gibt die Anzahl der Items zurück
func get_item_count() -> int:
	return items.size()


# Gibt true zurück, wenn das Inventar leer ist
func is_empty() -> bool:
	return items.size() == 0


# Gibt das Inventar als lesbaren String aus
func print_inventory() -> void:
	print("========== INVENTAR ==========")
	if items.size() == 0:
		print("  (leer)")
	else:
		for i in range(items.size()):
			var comp = items[i]
			print("  [", i, "] ", Component.get_type_name(comp), 
				" (", Component.get_watt_cost(comp), "W)")
	print("  (", items.size(), "/", max_size, ")")
	print("==============================")