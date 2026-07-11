# Circuit Breaker - Haupt-Spiel-Loop
# Steuert Phasen: Build -> Send -> Result -> Shop -> nächste Runde

extends Node

const Component = preload("res://component.gd")
const Firewall = preload("res://firewall.gd")
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

# Kurze Rückmeldung für die UI (Ergebnis, Kauf, Fehler)
var ui_message: String = ""

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
	var ui = get_node_or_null("../UI")
	if ui and ui.has_method("refresh"):
		ui.refresh()


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
	money = 12
	score = 0
	current_round = 0
	firewall = null
	stats = {
		"total_damage": 0, "firewalls_destroyed": 0,
		"components_placed": 0, "components_bought": 0,
		"packets_sent": 0, "best_single_packet": 0
	}
	inventory = Inventory.new()
	board.clear_board()
	print("=== NEUER RUN GESTARTET === Start-Geld: ", money)
	ui_message = "Kaufe erst ein paar Bausteine, dann starte Runde 1."
	# Run beginnt im Shop: erst Bausteine kaufen, dann 'Nächste Runde'.
	start_shop_phase()


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
	ui_message = "Runde %d — platziere Bauteile und sende die Pakete." % current_round
	
	print("=== RUNDE ", current_round, " ===")
	print(firewall.get_status())
	print("Budget: ", board.watt_budget, "W | Geld: ", money)
	board.print_board()
	
	_redraw_ui()


# =============================================
#  PAKETE SENDEN
# =============================================

# Berechnet den kompletten Sende-Vorgang OHNE Zustandsänderung.
# Wird von der UI genutzt, um zuerst die Animation zu zeigen und danach
# via apply_send() den Schaden anzuwenden. Gibt ein Ergebnis-Dictionary zurück.
func compute_send() -> Dictionary:
	var path_result = board.simulate_path()
	var per_packet = int(path_result.value)

	# Durchbruch-Bonus: Paket erreicht den rechten Rand -> +50%
	if path_result.reached_end:
		per_packet = int(ceil(per_packet * 1.5))

	# Schild-Modifikator: Schaden pro Paket gedeckelt
	if firewall and firewall.packet_damage_cap > 0:
		per_packet = min(per_packet, firewall.packet_damage_cap)

	var packets = firewall.packets_per_round if firewall else 1
	var raw = per_packet * packets

	# Überhitzung
	var heat = board.get_total_heat()
	var hlimit = firewall.heat_limit if firewall else 999
	var overheated = heat > hlimit
	var total = raw
	if overheated:
		var penalty = clampf(float(hlimit) / float(max(1, heat)), 0.3, 1.0)
		penalty = clampf(1.0 - (1.0 - penalty) * (firewall.overheat_factor if firewall else 1.0), 0.15, 1.0)
		total = int(raw * penalty)

	return {
		"path": path_result.path,
		"path_value": int(path_result.value),
		"reached_end": bool(path_result.reached_end),
		"path_error": String(path_result.error),
		"per_packet": per_packet,
		"packets": packets,
		"raw": raw,
		"heat": heat,
		"heat_limit": hlimit,
		"overheated": overheated,
		"total_damage": total,
	}


# Wendet ein zuvor berechnetes Sende-Ergebnis an: Schaden, Score, Phasenwechsel.
func apply_send(res: Dictionary) -> void:
	if phase != GamePhase.BUILD:
		return
	if firewall == null:
		push_warning("apply_send ohne Firewall")
		return

	phase = GamePhase.SEND
	var total_damage = int(res.get("total_damage", 0))
	firewall.take_damage(total_damage)
	score += total_damage
	stats.total_damage += total_damage
	stats.packets_sent += int(res.get("packets", 0))
	var per_packet = int(res.get("per_packet", 0))
	if per_packet > stats.best_single_packet:
		stats.best_single_packet = per_packet

	var note = ""
	if res.get("reached_end", false):
		note = "  (Durchbruch +50%)"
	elif String(res.get("path_error", "")) != "":
		note = "  [%s]" % res.get("path_error")
	if res.get("overheated", false):
		note += "  (überhitzt!)"

	if not firewall.is_alive():
		stats.firewalls_destroyed += 1
		money += firewall.reward_watt
		ui_message = "Firewall zerstört! %d Schaden%s  •  +%d Geld" % [total_damage, note, firewall.reward_watt]
		start_shop_phase()
	else:
		ui_message = "Nur %d Schaden%s — Firewall hält (%d/%d HP)." % [total_damage, note, firewall.health, firewall.max_health]
		show_game_over()


# Bequemer Fallback ohne Animation (führt Berechnung + Anwendung sofort aus).
func send_all_packets() -> void:
	if phase != GamePhase.BUILD:
		return
	apply_send(compute_send())


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
		ui_message = "Gekauft: %s für %d Geld." % [result.name, result.price]
		print("Gekauft: ", result.name, " für ", result.price, " Geld")
	else:
		ui_message = "Kauf fehlgeschlagen: %s" % result.reason
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
			print("Bauteile: CPU GPU LOOP NPU RAM CAP OC COOL TRACE")
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
		"NPU": Component.ComponentType.NPU, "RAM": Component.ComponentType.RAM,
		"CAP": Component.ComponentType.CAP, "OC": Component.ComponentType.OC,
		"COOL": Component.ComponentType.COOL
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
		"NPU": Component.ComponentType.NPU, "RAM": Component.ComponentType.RAM,
		"CAP": Component.ComponentType.CAP, "OC": Component.ComponentType.OC,
		"COOL": Component.ComponentType.COOL
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
	print("Watt: ", board.get_used_watt(), "/", board.watt_budget, " | Hitze: ", board.get_total_heat())
	print("Ausgewählt: ", Component.get_type_name(selected_component))
	print("Inventar: ", inventory.get_item_count(), "/", inventory.max_size)
	if firewall:
		print(firewall.get_status())