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


# Generiert neue zufällige Angebote. Preise wachsen mit dem Level (nicht mit der
# Gesamt-Rundenzahl – sonst würde der Shop innerhalb eines Levels unnötig teuer).
func generate_offerings(level: int) -> void:
	offers.clear()

	var count = randi() % (max_offers - min_offers + 1) + min_offers
	price_multiplier = 1.0 + 0.06 * level  # L1:1.06  L5:1.3  L10:1.6  L20:2.2

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


# Gibt einen zufälligen Bauteil-Typ zurück (gewichtet: häufige = günstige Teile).
# Leiterbahnen (TRACE) werden bewusst NICHT angeboten – sie sind Start-Ausrüstung
# und als reine Lückenfüller später überflüssig.
func _get_random_component() -> int:
	var pool := [
		[Component.ComponentType.CPU, 22],
		[Component.ComponentType.GPU, 14],
		[Component.ComponentType.RAM, 14],
		[Component.ComponentType.NPU, 12],
		[Component.ComponentType.PSU, 12],
		[Component.ComponentType.HEATSINK, 10],
		[Component.ComponentType.CACHE, 8],
		[Component.ComponentType.MAINBOARD, 8],
	]
	var total := 0
	for p in pool:
		total += p[1]
	var roll := randi() % total
	for p in pool:
		roll -= p[1]
		if roll < 0:
			return p[0]
	return Component.ComponentType.CPU


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