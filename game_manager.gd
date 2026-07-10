# Circuit Breaker - Haupt-Spiel-Loop
# Steuert Phasen: Build -> Send -> Result -> Shop -> nächste Runde

extends Node

const Component = preload("res://component.gd")
const Firewall = preload("res://firewall.gd")
const Packet = preload("res://packet.gd")
const GameShop = preload("res://shop.gd")
const Shop = GameShop

# Node-Referenzen
@onready var board: Node2D = $"../Board"
@onready var ui_manager = $"../UIManager"

# Spiel-Zustand
enum GamePhase { HOMESCREEN, BUILD, SEND, RESULT, SHOP, GAMEOVER }
var phase: GamePhase = GamePhase.HOMESCREEN

# Spiel-Ressourcen
var money: int = 5
var score: int = 0
var highscore: int = 0
var current_round: int = 0
var base_watt_budget: int = 10

# Firewall der aktuellen Runde
var firewall: Firewall = null

# Shop
var shop: Shop = null

# Aktuell ausgewählter Bauteil-Typ
var selected_component: Component.ComponentType = Component.ComponentType.CPU

# Statistik für den aktuellen Run
var stats = {
	"total_damage": 0,
	"firewalls_destroyed": 0,
	"components_placed": 0,
	"components_bought": 0,
	"packets_sent": 0,
	"best_single_packet": 0
}


func _ready() -> void:
	randomize()
	shop = Shop.new()
	show_homescreen()


# =============================================
#  HOMESCREEN
# =============================================

func show_homescreen() -> void:
	phase = GamePhase.HOMESCREEN
	print("========================================")
	print("     CIRCUIT BREAKER")
	print("  Ein Hacker-Platinen-Puzzle")
	print("========================================")
	print()
	print("Baue deine Platine, verstärke Datenpakete,")
	print("und knacke die Firewall!")
	print()
	print("Befehle: help")
	print("         start - Spiel beginnen")
	print("         quit  - Beenden")
	print()


# =============================================
#  SPIEL STARTEN
# =============================================

func start_new_run() -> void:
	money = 5
	score = 0
	current_round = 0
	stats = {
		"total_damage": 0,
		"firewalls_destroyed": 0,
		"components_placed": 0,
		"components_bought": 0,
		"packets_sent": 0,
		"best_single_packet": 0
	}
	
	board.watt_budget = base_watt_budget
	board.clear_board()
	
	print("=== NEUER RUN GESTARTET ===")
	print("Start-Geld: ", money)
	print("Watt-Budget: ", board.watt_budget)
	print()
	
	start_round()


# =============================================
#  RUNDE
# =============================================

func start_round() -> void:
	current_round += 1
	firewall = Firewall.new(current_round)
	phase = GamePhase.BUILD
	
	# Geld-Belohnung für neue Runde
	var round_bonus = 2 + current_round
	money += round_bonus
	
	# Watt-Budget erhöhen
	board.watt_budget = base_watt_budget + (current_round - 1) * 2
	
	print("========================================")
	print("  RUNDE ", current_round)
	print("========================================")
	print(firewall.get_status())
	print("Budget: ", board.watt_budget, "W | Geld: ", money)
	print("Pakete/Runde: ", firewall.packets_per_round)
	print()
	print("Platziere Bauteile (help für Befehle)")
	print("Dann: send - Pakete losschicken")
	print()
	board.print_board()
	print("Ausgewählt: ", Component.get_type_name(selected_component), " (", Component.get_watt_cost(selected_component), "W)")


# =============================================
#  PAKETE SENDEN (Phase: BUILD -> SEND -> RESULT)
# =============================================

func send_all_packets() -> void:
	if phase != GamePhase.BUILD:
		print("Du bist nicht in der Bau-Phase!")
		return
	
	phase = GamePhase.SEND
	
	print("=== PAKETE WERDEN GESENDET ===")
	
	var total_damage = 0
	var packets_to_send = firewall.packets_per_round
	
	for i in range(packets_to_send):
		var row = i % board.BOARD_HEIGHT
		print("\n--- Paket ", i + 1, "/", packets_to_send, " (Zeile ", row, ") ---")
		var damage = _send_single_packet(row)
		total_damage += damage
	
	phase = GamePhase.RESULT
	
	print("\n=== RUNDEN-ERGEBNIS ===")
	print("Gesamtschaden: ", total_damage)
	
	# Score gutschreiben
	score += total_damage
	stats.total_damage += total_damage
	
	# Prüfen, ob Firewall zerstört wurde
	if not firewall.is_alive():
		_on_firewall_destroyed()
	else:
		print("\nFirewall steht noch! (", firewall.health, "/", firewall.max_health, " HP)")
		print("Du hast nicht genug Schaden gemacht.")
		show_game_over()


func _send_single_packet(row: int) -> int:
	var packet_value = 1  # Startwert
	
	for col in range(board.BOARD_WIDTH):
		var component = board.board[row][col]
		if component != null:
			var before = packet_value
			packet_value = Component.process_packet(component, packet_value, board, row, col)
			print("  [", col, "] ", Component.get_type_name(component), ": ", before, " -> ", packet_value)
	
	firewall.take_damage(packet_value)
	stats.packets_sent += 1
	if packet_value > stats.best_single_packet:
		stats.best_single_packet = packet_value
	
	print("  => Paket-Wert: ", packet_value)
	return packet_value


# =============================================
#  FIREWALL ZERSTÖRT -> SHOP
# =============================================

func _on_firewall_destroyed() -> void:
	print("\n*** FIREWALL ZERSTÖRT! ***")
	stats.firewalls_destroyed += 1
	
	# Belohnung
	var reward = firewall.reward_watt
	money += reward
	print("Belohnung: +", reward, " Geld")
	print("Geld: ", money)
	print("Score: ", score)
	print()
	
	# Shop öffnen
	start_shop_phase()


# =============================================
#  SHOP-PHASE
# =============================================

func start_shop_phase() -> void:
	phase = GamePhase.SHOP
	shop.generate_offerings(current_round)
	
	print("========== SHOP (Runde ", current_round, ") ==========")
	print("Geld: ", money)
	print()
	shop.print_shop()
	print()
	print("buy <nr> - Kaufen")
	print("next     - Nächste Runde")
	print()


func buy_component(index: int) -> void:
	if phase != GamePhase.SHOP:
		print("Shop ist nicht geöffnet!")
		return
	
	var result = shop.buy(index, money)
	
	if result.success:
		money -= result.price
		stats.components_bought += 1
		print("Gekauft: ", result.name, " für ", result.price, " Geld")
		
		# Bauteil auf erstes freies Feld setzen (oder in Inventar)
		var positions = board.get_available_positions()
		if positions.size() > 0:
			var pos = positions[0]
			board.place_component(pos.col, pos.row, result.component_type)
			board.print_board()
		else:
			print("Kein freier Platz auf dem Brett!")
	else:
		print("Kauf fehlgeschlagen: ", result.reason)


# =============================================
#  GAME OVER
# =============================================

func show_game_over() -> void:
	phase = GamePhase.GAMEOVER
	
	if score > highscore:
		highscore = score
		print("*** NEUER HIGHSCORE: ", highscore, " ***")
	
	print("\n=== GAME OVER ===")
	print("Runde: ", current_round)
	print("Score: ", score)
	print("Highscore: ", highscore)
	print("Geld: ", money)
	print("Firewalls geknackt: ", stats.firewalls_destroyed)
	print("Bester Paket-Wert: ", stats.best_single_packet)
	print()
	print("restart - Neustart")
	print("menu    - Hauptmenü")
	print()


# =============================================
#  BEFEHL
# =============================================

func handle_command(text: String) -> void:
	var parts = text.strip_edges().split(" ", false)
	if parts.size() == 0:
		return
	
	var cmd = parts[0].to_lower()
	
	match cmd:
		"help", "h":
			_show_help()
		"start":
			if phase == GamePhase.HOMESCREEN:
				start_new_run()
		"place", "p":
			_cmd_place(parts)
		"remove", "r":
			_cmd_remove(parts)
		"select", "s":
			_cmd_select(parts)
		"send":
			send_all_packets()
		"shop":
			if phase == GamePhase.RESULT:
				start_shop_phase()
		"buy", "b":
			if parts.size() >= 2:
				buy_component(int(parts[1]))
		"next", "n":
			if phase == GamePhase.SHOP:
				start_round()
		"board":
			board.print_board()
		"status":
			print("Runde: ", current_round, " | Phase: ", phase)
			print("Geld: ", money, " | Score: ", score, " | Highscore: ", highscore)
			print("Ausgewählt: ", Component.get_type_name(selected_component))
		"clear":
			board.clear_board()
		"restart":
			start_new_run()
		"menu":
			show_homescreen()
		"quit", "q":
			print("Spiel beendet.")
			get_tree().quit()
		_:
			print("Unbekannter Befehl. 'help' für Hilfe.")


func _show_help() -> void:
	match phase:
		GamePhase.HOMESCREEN:
			print("Befehle: start, quit")
		GamePhase.BUILD:
			print("========== BAU-PHASE ==========")
			print("place CPU 0 0     - Bauteil setzen")
			print("remove 0 0        - Bauteil entfernen")
			print("select GPU        - Bauteil auswählen")
			print("send              - Pakete senden")
			print("board             - Brett anzeigen")
			print("status            - Spielstatus")
			print("clear             - Brett leeren")
			print("================================")
		GamePhase.SHOP:
			print("========== SHOP ==========")
			print("buy <nr>          - Kaufen")
			print("next              - Nächste Runde")
			print("===========================")
		GamePhase.GAMEOVER:
			print("Befehle: restart, menu")
		_:
			print("Befehle: help, status, board")


func _cmd_place(parts: Array) -> void:
	if phase != GamePhase.BUILD:
		print("Du kannst nur in der Bau-Phase platzieren!")
		return
	
	if parts.size() < 4:
		print("Usage: place <TYP> <x> <y>")
		return
	
	var type_str = parts[1].to_upper()
	var col = int(parts[2])
	var row = int(parts[3])
	
	var type_map = {
		"CPU": Component.ComponentType.CPU,
		"GPU": Component.ComponentType.GPU,
		"LOOP": Component.ComponentType.LOOP,
		"TRACE": Component.ComponentType.TRACE,
		"NPU": Component.ComponentType.NPU
	}
	
	if not type_map.has(type_str):
		print("Unbekannter Typ: ", type_str)
		return
	
	var success = board.place_component(col, row, type_map[type_str])
	if success:
		stats.components_placed += 1


func _cmd_remove(parts: Array) -> void:
	if phase != GamePhase.BUILD:
		print("Du kannst nur in der Bau-Phase entfernen!")
		return
	
	if parts.size() < 3:
		print("Usage: remove <x> <y>")
		return
	
	board.remove_component(int(parts[1]), int(parts[2]))


func _cmd_select(parts: Array) -> void:
	if parts.size() < 2:
		print("Aktuell: ", Component.get_type_name(selected_component))
		return
	
	var type_map = {
		"CPU": Component.ComponentType.CPU,
		"GPU": Component.ComponentType.GPU,
		"LOOP": Component.ComponentType.LOOP,
		"TRACE": Component.ComponentType.TRACE,
		"NPU": Component.ComponentType.NPU
	}
	
	var key = parts[1].to_upper()
	if type_map.has(key):
		selected_component = type_map[key]
		print("Ausgewählt: ", Component.get_type_name(selected_component), " (", Component.get_watt_cost(selected_component), "W)")
	else:
		print("Unbekannter Typ: ", parts[1])