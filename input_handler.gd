# Circuit Breaker - Tastatur-Steuerung
# Verarbeitet Tastatureingaben für das Spiel.

extends Node

const Component = preload("res://component.gd")

# Referenzen
var board_ref = null
var game_manager_ref = null
var shop_ref = null
var score_ref = null

# Aktuell ausgewählter Bauteil-Typ zum Platzieren
var selected_component: Component.ComponentType = Component.ComponentType.CPU

# Aktuelle Cursor-Position auf dem Brett
var cursor_col: int = 0
var cursor_row: int = 0

# Modus: "build", "shop", "menu"
var mode: String = "build"


func _init(p_board, p_game_manager, p_shop, p_score) -> void:
	board_ref = p_board
	game_manager_ref = p_game_manager
	shop_ref = p_shop
	score_ref = p_score


# Verarbeitet einen Tastatur-Befehl
# Gibt true zurück, wenn der Befehl erkannt wurde
func handle_command(text: String) -> bool:
	var parts = text.strip_edges().split(" ", false)
	if parts.size() == 0:
		return false
	
	var cmd = parts[0].to_lower()
	
	match cmd:
		"place", "p":
			return _cmd_place(parts)
		"remove", "r":
			return _cmd_remove(parts)
		"select", "s":
			return _cmd_select(parts)
		"send":
			return _cmd_send()
		"shop":
			return _cmd_shop()
		"buy", "b":
			return _cmd_buy(parts)
		"board":
			return _cmd_board()
		"status", "stats":
			return _cmd_status()
		"help", "h":
			return _cmd_help()
		"clear":
			return _cmd_clear()
		"reset":
			return _cmd_reset()
		"next", "n":
			return _cmd_next()
		"quit", "q":
			return _cmd_quit()
	
	return false


# place <type> <col> <row>
func _cmd_place(parts: Array) -> bool:
	if parts.size() < 4:
		print("Usage: place <CPU|GPU|LOOP|TRACE|NPU> <col> <row>")
		return true
	
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
		print("Unbekannter Typ: ", type_str, " (CPU, GPU, LOOP, TRACE, NPU)")
		return true
	
	var comp_type = type_map[type_str]
	var success = board_ref.place_component(col, row, comp_type)
	
	if success and score_ref != null:
		score_ref.count_placement()
	
	board_ref.print_board()
	return true


# remove <col> <row>
func _cmd_remove(parts: Array) -> bool:
	if parts.size() < 3:
		print("Usage: remove <col> <row>")
		return true
	
	var col = int(parts[1])
	var row = int(parts[2])
	board_ref.remove_component(col, row)
	board_ref.print_board()
	return true


# select <CPU|GPU|LOOP|TRACE|NPU>
func _cmd_select(parts: Array) -> bool:
	if parts.size() < 2:
		print("Aktuell ausgewählt: ", Component.get_type_name(selected_component))
		return true
	
	var type_str = parts[1].to_upper()
	var type_map = {
		"CPU": Component.ComponentType.CPU,
		"GPU": Component.ComponentType.GPU,
		"LOOP": Component.ComponentType.LOOP,
		"TRACE": Component.ComponentType.TRACE,
		"NPU": Component.ComponentType.NPU
	}
	
	if not type_map.has(type_str):
		print("Unbekannter Typ: ", type_str)
		return true
	
	selected_component = type_map[type_str]
	print("Ausgewählt: ", Component.get_type_name(selected_component),
		" (", Component.get_watt_cost(selected_component), "W)")
	return true


# send - Sendet alle Pakete
func _cmd_send() -> bool:
	if game_manager_ref != null:
		game_manager_ref.send_all_packets()
	return true


# shop - Öffnet den Shop
func _cmd_shop() -> bool:
	if shop_ref != null:
		shop_ref.print_shop()
		mode = "shop"
		print("Shop-Modus: buy <nummer>")
	return true


# buy <nummer>
func _cmd_buy(parts: Array) -> bool:
	if parts.size() < 2:
		print("Usage: buy <nummer>")
		return true
	
	var index = int(parts[1])
	
	if shop_ref == null or score_ref == null:
		print("Shop nicht verfügbar")
		return true
	
	var result = shop_ref.buy(index, score_ref.money)
	
	if result.success:
		score_ref.spend_money(result.price)
		score_ref.count_purchase()
		print("Gekauft: ", result.name)
		# Lege das gekaufte Bauteil ins Inventar (für später)
	else:
		print("Kauf fehlgeschlagen: ", result.reason)
	
	return true


# board - Zeigt das Brett an
func _cmd_board() -> bool:
	board_ref.print_board()
	return true


# status - Zeigt Spielstatus
func _cmd_status() -> bool:
	if score_ref != null:
		print(score_ref.get_status())
		print("Ausgewählt: ", Component.get_type_name(selected_component))
		print("Modus: ", mode)
	return true


# help - Zeigt Hilfe
func _cmd_help() -> bool:
	print("========== BEFEHLE ==========")
	print("place <TYP> <x> <y>  - Bauteil setzen")
	print("remove <x> <y>       - Bauteil entfernen")
	print("select <TYP>         - Bauteil auswählen")
	print("send                 - Pakete senden")
	print("shop                 - Shop öffnen")
	print("buy <nr>             - Im Shop kaufen")
	print("board                - Brett anzeigen")
	print("status               - Spielstatus")
	print("clear                - Brett leeren")
	print("reset                - Neustart")
	print("next                 - Nächste Runde")
	print("help                 - Diese Hilfe")
	print("quit                 - Beenden")
	print("==============================")
	print("Typen: CPU, GPU, LOOP, TRACE, NPU")
	return true


# clear - Leert das Brett
func _cmd_clear() -> bool:
	board_ref.clear_board()
	board_ref.print_board()
	return true


# reset - Neustart
func _cmd_reset() -> bool:
	if game_manager_ref != null:
		game_manager_ref.start_new_run()
	return true


# next - Nächste Runde (Debug)
func _cmd_next() -> bool:
	if game_manager_ref != null:
		game_manager_ref.start_round()
	return true


# quit - Beenden
func _cmd_quit() -> bool:
	print("Spiel beendet.")
	get_tree().quit()
	return true