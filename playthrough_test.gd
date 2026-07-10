# Circuit Breaker - Automatischer Spieldurchlauf
# Simuliert einen kompletten Run ohne Benutzereingabe.
# Starte test_scene.tscn und setze dieses Skript als Hauptskript.

extends Node

const Component = preload("res://component.gd")
const Firewall = preload("res://firewall.gd")
const Packet = preload("res://packet.gd")
const Shop = preload("res://shop.gd")

var board = null
var gm = null
var shop = null

var round: int = 0
var total_damage_dealt: int = 0
var firewalls_destroyed: int = 0
var components_placed: int = 0
var money_earned: int = 0
var game_over_reached: bool = false


func _ready() -> void:
	print("=".repeat(60))
	print("  CIRCUIT BREAKER - AUTOMATISCHER SPIELDURCHLAUF")
	print("=".repeat(60))
	print()
	
	# Board erstellen
	board = load("res://board.gd").new()
	board._init_board()
	board.watt_budget = 10
	
	# GameManager erstellen
	gm = load("res://game_manager.gd").new()
	gm.board = board
	
	# Shop erstellen
	shop = Shop.new()
	gm.shop = shop
	
	# Starte den Run
	_start_run()
	
	print("=".repeat(60))
	print("  SPIELDURCHLAUF ABGESCHLOSSEN")
	print("=".repeat(60))
	print("  Runden gespielt: ", round)
	print("  Firewalls zerstört: ", firewalls_destroyed)
	print("  Gesamtschaden: ", total_damage_dealt)
	print("  Bauteile platziert: ", components_placed)
	print("  Game Over erreicht: ", game_over_reached)
	print("=".repeat(60))
	
	if firewalls_destroyed >= 2 and game_over_reached:
		print("  ✅ SPIELDURCHLAUF ERFOLGREICH!")
	else:
		print("  ⚠️  Spiel wurde nicht vollständig durchgespielt")
	print("=".repeat(60))
	
	get_tree().quit()


func _start_run() -> void:
	print("--- Starte neuen Run ---")
	board.clear_board()
	board.watt_budget = 10
	round = 0
	total_damage_dealt = 0
	firewalls_destroyed = 0
	components_placed = 0
	money_earned = 0
	game_over_reached = false
	
	# Runde 1 spielen
	_play_round()
	
	# Wenn Runde 1 erfolgreich, Runde 2 spielen
	if not game_over_reached:
		_play_round()
	
	# Wenn Runde 2 erfolgreich, Runde 3 spielen
	if not game_over_reached:
		_play_round()


func _play_round() -> void:
	round += 1
	print("\n=== RUNDE ", round, " ===")
	
	# Firewall erstellen
	var firewall = Firewall.new(round)
	print("Firewall Level ", round, ": ", firewall.max_health, " HP, ", firewall.packets_per_round, " Pakete")
	
	# Bauteile platzieren (optimiertes Setup)
	_place_optimal_setup()
	
	# Pakete senden
	var damage = _send_packets(firewall)
	total_damage_dealt += damage
	
	# Prüfen, ob Firewall zerstört wurde
	if not firewall.is_alive():
		print("*** Firewall zerstört! ***")
		firewalls_destroyed += 1
		money_earned += firewall.reward_watt
		
		# Shop besuchen
		_visit_shop(round)
	else:
		print("*** Firewall NICHT zerstört! (", firewall.health, "/", firewall.max_health, " HP) ***")
		game_over_reached = true
		_show_game_over()


func _place_optimal_setup() -> void:
	print("  Platziere Bauteile...")
	board.clear_board()
	
	# Optimales Setup für maximale Watt-Effizienz:
	# Zeile 0: CPU -> GPU (12 Schaden, 7W)
	board.place_component(0, 0, Component.ComponentType.CPU)
	board.place_component(1, 0, Component.ComponentType.GPU)
	components_placed += 2
	
	# Zeile 1: CPU -> CPU -> GPU (14 Schaden, 9W)
	board.place_component(0, 1, Component.ComponentType.CPU)
	board.place_component(1, 1, Component.ComponentType.CPU)
	board.place_component(2, 1, Component.ComponentType.GPU)
	components_placed += 3
	
	# Zeile 2: LOOP -> GPU (4 Schaden, 8W)
	board.place_component(0, 2, Component.ComponentType.LOOP)
	board.place_component(1, 2, Component.ComponentType.GPU)
	components_placed += 2
	
	# Zeile 3: CPU -> CPU -> CPU (16 Schaden, 6W)
	board.place_component(0, 3, Component.ComponentType.CPU)
	board.place_component(1, 3, Component.ComponentType.CPU)
	board.place_component(2, 3, Component.ComponentType.CPU)
	components_placed += 3
	
	print("  Verbrauch: ", board.get_used_watt(), "/", board.watt_budget, "W")
	board.print_board()


func _send_packets(firewall) -> int:
	print("  Sende Pakete...")
	var total = 0
	var packets = firewall.packets_per_round
	
	for i in range(packets):
		var row = i % 4
		var value = board.simulate_packet_flow(row)
		firewall.take_damage(value)
		total += value
		print("    Paket ", i+1, " (Zeile ", row, "): ", value, " Schaden")
	
	print("  Gesamtschaden: ", total)
	return total


func _visit_shop(round_number: int) -> void:
	print("\n  --- Shop (Runde ", round_number, ") ---")
	shop.generate_offerings(round_number)
	shop.print_shop()
	
	# Kaufe das günstigste Angebot, wenn genug Geld
	var best_index = -1
	var best_price = 999
	
	for i in range(shop.get_offer_count()):
		var offer = shop.get_offer(i)
		if offer.price < best_price:
			best_price = offer.price
			best_index = i
	
	if best_index >= 0 and money_earned >= best_price:
		var result = shop.buy(best_index, money_earned)
		if result.success:
			money_earned -= result.price
			print("  Gekauft: ", result.name, " für ", result.price, " Geld")
			
			# Auf freies Feld setzen
			var positions = board.get_available_positions()
			if positions.size() > 0:
				var pos = positions[0]
				board.place_component(pos.col, pos.row, result.component_type)
				components_placed += 1
				print("  Platziert bei (", pos.col, ", ", pos.row, ")")
	else:
		print("  Nichts gekauft (kein Geld oder keine Angebote)")
	
	print()


func _show_game_over() -> void:
	print("\n=== GAME OVER ===")
	print("Runden: ", round)
	print("Firewalls zerstört: ", firewalls_destroyed)
	print("Gesamtschaden: ", total_damage_dealt)
	print("Bauteile platziert: ", components_placed)
	print()