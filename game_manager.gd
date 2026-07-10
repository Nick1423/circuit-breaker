# Circuit Breaker - Haupt-Spiel-Loop
# Steuert Phasen: Build -> Send -> Result -> Shop -> nächste Runde

extends Node

const Component = preload("res://component.gd")
const Firewall = preload("res://firewall.gd")
const Packet = preload("res://packet.gd")
const GameShop = preload("res://shop.gd")
const Shop = GameShop
const Inventory = preload("res://inventory.gd")

# Node-Referenzen
@onready var board: Node2D = $"../Board"

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

# Shop & Inventar
var shop: Shop = null
var inventory: Inventory = null

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
	inventory = Inventory.new()
	_redraw_ui()
	show_homescreen()


# Hilfsfunktion: UI neu zeichnen
func _redraw_ui() -> void:
	var ui_board = $"../UIBoard"
	if ui_board:
		ui_board.queue_redraw()
	var ui_mgr = $"../UIManager"
	if ui_mgr:
		ui_mgr.queue_redraw()


# =============================================
#  HOMESCREEN
# =============================================

func show_homescreen() -> void:
	phase = GamePhase.HOMESCREEN
	_redraw_ui()
	print("========================================")
	print("     CIRCUIT BREAKER")
	print("  Ein Hacker-Platinen-Puzzle")
	print("========================================")
	print()
	print("Befehle: help, start, quit")
	print()


# =============================================
#  SPIEL STARTEN
# =============================================

func start_new_run() -> void:
	money = 5
	score = 0
	current_round = 0
	stats = {
		"total_damage": 0, "firewalls_destroyed": 0,
		"components_placed": 0, "components_bought": 0,
		"packets_sent": 0, "best_single_packet": 0
	}
	inventory = Inventory.new()
	board.watt_budget = base_watt_budget
	board.clear_board()
	print("=== NEUER RUN GESTARTET ===")
	print("Start-Geld: ", money, " | Watt-Budget: ", board.watt_budget)
	print()
	start_round()


# =============================================
#  RUNDE
# =============================================

func start_round() -> void:
	current_round += 1
	firewall = Firewall.new(current_round)
	phase = GamePhase.BUILD
	
	var round_bonus = 2 + current_round
	money += round_bonus
	board.watt_budget = base_watt_budget + (current_round - 1) * 2
	
	print("=== RUNDE ", current_round, " ===")
	print(firewall.get_status())
	print("Budget: ", board.watt_budget, "W | Geld: ", money)
	board.print_board()
	
	_redraw_ui()


# =============================================
#  PAKETE SENDEN
# =============================================

func send_all_packets() -> void:
	if phase != GamePhase.BUILD:
		print("Du bist nicht in der Bau-Phase!")
		return
	
	phase = GamePhase.SEND
	_redraw_ui()
	
	print("=== PAKETE WERDEN GESENDET ===")
	var total_damage = 0
	
	for i in range(firewall.packets_per_round):
		var row = i % board.BOARD_HEIGHT
		var damage = _send_single_packet(row)
		total_damage += damage
	
	phase = GamePhase.RESULT
	print("Gesamtschaden: ", total_damage)
	score += total_damage
	stats.total_damage += total_damage
	
	if not firewall.is_alive():
		print("*** FIREWALL ZERSTÖRT! ***")
		stats.firewalls_destroyed += 1
		money += firewall.reward_watt
		_redraw_ui()
		start_shop_phase()
	else:
		print("Firewall steht noch! (", firewall.health, "/", firewall.max_health, " HP)")
		show_game_over()


func _send_single_packet(row: int) -> int:
	var value = 1
	for col in range(board.BOARD_WIDTH):
		var comp = board.board[row][col]
		if comp != null:
			value = Component.process_packet(comp, value, board, row, col)
	firewall.take_damage(value)
	stats.packets_sent += 1
	if value > stats.best_single_packet:
		stats.best_single_packet = value
	print("  Zeile ", row, ": ", value, " Schaden")
	return value


# =============================================
#  SHOP
# =============================================

func start_shop_phase() -> void:
	phase = GamePhase.SHOP
	shop.generate_offerings(current_round)
	_redraw_ui()
	print("========== SHOP ==========")
	print("Geld: ", money)
	shop.print_shop()


func buy_component(index: int) -> void:
	if phase != GamePhase.SHOP:
		print("Shop ist nicht geöffnet!")
		return
	var result = shop.buy(index, money)
	if result.success:
		money -= result.price
		stats.components_bought += 1
		inventory.add_item(result.component_type)
		print("Gekauft: ", result.name, " für ", result.price, " Geld")
	else:
		print("Fehler: ", result.reason)
	_redraw_ui()


# =============================================
#  GAME OVER
# =============================================

func show_game_over() -> void:
	phase = GamePhase.GAMEOVER
	if score > highscore:
		highscore = score
		print("NEUER HIGHSCORE: ", highscore)
	print("\n=== GAME OVER ===")
	print("Runde: ", current_round, " | Score: ", score)
	print("restart - Neustart | menu - Hauptmenü")
	_redraw_ui()


# =============================================
#  BEFEHLE
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
		"invuse", "i":
			_cmd_invuse(parts)
		"inv":
			inventory.print_inventory()
		"send":
			send_all_packets()
		"buy", "b":
			if parts.size() >= 2:
				buy_component(int(parts[1]))
		"next", "n":
			if phase == GamePhase.SHOP:
				start_round()
		"board":
			board.print_board()
		"status":
			_cmd_status()
		"clear":
			board.clear_board()
			_redraw_ui()
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
			print("start, quit")
		GamePhase.BUILD:
			print("place CPU 0 0 | remove 0 0 | select GPU")
			print("invuse 0 1 1 | inv | send | board | clear")
		GamePhase.SHOP:
			print("buy <nr> | next | inv")
		GamePhase.GAMEOVER:
			print("restart, menu")
		_:
			print("help, status, board")


func _cmd_place(parts: Array) -> void:
	if phase != GamePhase.BUILD:
		print("Nur in Bau-Phase!")
		return
	if parts.size() < 4:
		print("Usage: place <TYP> <x> <y>")
		return
	
	var type_map = {
		"CPU": Component.ComponentType.CPU, "GPU": Component.ComponentType.GPU,
		"LOOP": Component.ComponentType.LOOP, "TRACE": Component.ComponentType.TRACE,
		"NPU": Component.ComponentType.NPU
	}
	var t = parts[1].to_upper()
	if not type_map.has(t):
		print("Unbekannter Typ: ", parts[1])
		return
	
	var ok = board.place_component(int(parts[2]), int(parts[3]), type_map[t])
	if ok:
		stats.components_placed += 1
	_redraw_ui()


func _cmd_remove(parts: Array) -> void:
	if phase != GamePhase.BUILD:
		print("Nur in Bau-Phase!")
		return
	if parts.size() < 3:
		print("Usage: remove <x> <y>")
		return
	board.remove_component(int(parts[1]), int(parts[2]))
	_redraw_ui()


func _cmd_select(parts: Array) -> void:
	if parts.size() < 2:
		print("Aktuell: ", Component.get_type_name(selected_component))
		return
	var type_map = {
		"CPU": Component.ComponentType.CPU, "GPU": Component.ComponentType.GPU,
		"LOOP": Component.ComponentType.LOOP, "TRACE": Component.ComponentType.TRACE,
		"NPU": Component.ComponentType.NPU
	}
	var key = parts[1].to_upper()
	if type_map.has(key):
		selected_component = type_map[key]
		print("Ausgewählt: ", Component.get_type_name(selected_component))
	_redraw_ui()


func _cmd_invuse(parts: Array) -> void:
	if phase != GamePhase.BUILD:
		print("Nur in Bau-Phase!")
		return
	if parts.size() < 4:
		print("Usage: invuse <inv_idx> <x> <y>")
		return
	
	var idx = int(parts[1])
	var ct = inventory.peek_item(idx)
	if ct == -1:
		print("Ungültiger Index!")
		return
	
	var ok = board.place_component(int(parts[2]), int(parts[3]), ct)
	if ok:
		inventory.take_item(idx)
		stats.components_placed += 1
	_redraw_ui()


func _cmd_status() -> void:
	print("Runde: ", current_round, " | Geld: ", money, " | Score: ", score)
	print("Watt: ", board.get_used_watt(), "/", board.watt_budget)
	print("Ausgewählt: ", Component.get_type_name(selected_component))
	print("Inventar: ", inventory.get_item_count(), "/", inventory.max_size)
	if firewall:
		print(firewall.get_status())