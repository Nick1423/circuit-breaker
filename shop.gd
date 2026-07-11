# Circuit Breaker - Shop-System
# Bietet zufällige Bauteile zum Kauf zwischen den Runden.

class_name GameShop

# Component ist über class_name global verfügbar – kein preload nötig.

# Ein Angebot im Shop
class Offer:
	var component_type: int  # Component.ComponentType
	var price: int
	var name: String

	func _init(p_type: int, p_price: int):
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

	_guarantee_damage_offer()


# Fairness: sorgt dafür, dass mindestens ein Bauteil mit Schadenseffekt
# (CPU/GPU/RAM/NPU) im Angebot ist – sonst wäre der Shop unspielbar.
func _guarantee_damage_offer() -> void:
	var damage_types = [
		Component.ComponentType.CPU, Component.ComponentType.GPU,
		Component.ComponentType.RAM, Component.ComponentType.NPU,
	]
	for o in offers:
		if o.component_type in damage_types:
			return
	if offers.is_empty():
		return
	var idx = randi() % offers.size()
	var t = damage_types[randi() % damage_types.size()]
	var price = int(_get_base_price(t) * price_multiplier)
	if price < 1:
		price = 1
	offers[idx] = Offer.new(t, price)


# Gibt einen zufälligen Bauteil-Typ zurück (seltenere = stärkere Bauteile)
func _get_random_component() -> int:
	var roll = randf()

	# Häufig -> selten
	if roll < 0.15:
		return Component.ComponentType.TRACE
	elif roll < 0.36:
		return Component.ComponentType.CPU
	elif roll < 0.46:
		return Component.ComponentType.HEATSINK
	elif roll < 0.58:
		return Component.ComponentType.RAM
	elif roll < 0.70:
		return Component.ComponentType.NPU
	elif roll < 0.80:
		return Component.ComponentType.PSU
	elif roll < 0.90:
		return Component.ComponentType.GPU
	elif roll < 0.96:
		return Component.ComponentType.CACHE
	else:
		return Component.ComponentType.MAINBOARD


# Basis-Preis kommt aus der zentralen Bauteil-Tabelle
func _get_base_price(type: int) -> int:
	return Component.get_base_price(type)


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
		var w = Component.get_watt_cost(offer.component_type)
		var h = Component.get_heat(offer.component_type)
		print("  [", i, "] ", offer.name, " - ", offer.price, " Geld  (", w, "W, ", h, "H)")
	print("==========================")