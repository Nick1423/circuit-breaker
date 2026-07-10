# Circuit Breaker - Shop-System
# Bietet zufällige Bauteile zum Kauf zwischen den Runden.

class_name GameShop

const Component = preload("res://component.gd")

# Ein Angebot im Shop
class Offer:
	var component_type: Component.ComponentType
	var price: int
	var name: String
	
	func _init(p_type: Component.ComponentType, p_price: int):
		component_type = p_type
		price = p_price
		name = Component.get_type_name(p_type)

# Aktuelle Angebote
var offers: Array = []

# Konfiguration
var min_offers: int = 3
var max_offers: int = 5
var price_multiplier: float = 1.0


func _init() -> void:
	pass


# Generiert neue zufällige Angebote
func generate_offerings(round_number: int) -> void:
	offers.clear()
	
	var count = randi() % (max_offers - min_offers + 1) + min_offers
	price_multiplier = 1.0 + (round_number * 0.1)  # Wird teurer pro Runde
	
	for i in range(count):
		var type = _get_random_component()
		var base_price = _get_base_price(type)
		var final_price = int(base_price * price_multiplier)
		if final_price < 1:
			final_price = 1
		offers.append(Offer.new(type, final_price))


# Gibt einen zufälligen Bauteil-Typ zurück (seltenere = höhere Stufen)
func _get_random_component() -> Component.ComponentType:
	var roll = randf()
	
	# TRACE: 20%, CPU: 35%, GPU: 15%, LOOP: 20%, NPU: 10%
	if roll < 0.20:
		return Component.ComponentType.TRACE
	elif roll < 0.55:
		return Component.ComponentType.CPU
	elif roll < 0.70:
		return Component.ComponentType.GPU
	elif roll < 0.90:
		return Component.ComponentType.LOOP
	else:
		return Component.ComponentType.NPU


# Gibt den Basis-Preis für einen Bauteil-Typ zurück
func _get_base_price(type: Component.ComponentType) -> int:
	match type:
		Component.ComponentType.TRACE:
			return 1
		Component.ComponentType.CPU:
			return 3
		Component.ComponentType.GPU:
			return 8
		Component.ComponentType.LOOP:
			return 5
		Component.ComponentType.NPU:
			return 6
	return 1


# Kauft ein Angebot (gibt den Typ zurück, null wenn nicht genug Geld)
func buy(index: int, player_money: int) -> Dictionary:
	if index < 0 or index >= offers.size():
		return {"success": false, "reason": "Ungültiger Index"}
	
	var offer = offers[index]
	
	if player_money < offer.price:
		return {"success": false, "reason": "Nicht genug Geld"}
	
	offers.remove_at(index)
	return {
		"success": true,
		"component_type": offer.component_type,
		"price": offer.price,
		"name": offer.name
	}


# Gibt die Anzahl der Angebote zurück
func get_offer_count() -> int:
	return offers.size()


# Gibt ein Angebot an Index zurück
func get_offer(index: int) -> Offer:
	if index < 0 or index >= offers.size():
		return null
	return offers[index]


# Gibt alle Angebote als Array zurück
func get_all_offers() -> Array:
	return offers.duplicate()


# Gibt den Shop als String aus (für Konsolen-Darstellung)
func print_shop() -> void:
	print("========== SHOP ==========")
	print("Angebote:")
	for i in range(offers.size()):
		var offer = offers[i]
		print("  [", i, "] ", offer.name, " - ", offer.price, " Geld")
	print("==========================")