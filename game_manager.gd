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
enum GamePhase { HOMESCREEN, BUILD, SEND, RESULT, REWARD, SHOP, GAMEOVER, VICTORY }
var phase: GamePhase = GamePhase.HOMESCREEN

# Runde, ab der der Run gewonnen ist
const WIN_ROUND: int = 10

# Reliktarten (dauerhafte Run-Boni)
enum Relic { STARTSPANNUNG, BUSBREITE, DURCHBRUCH, KUEHLPASTE, EFFIZIENZ }
const RELIC_NAMES := {
	Relic.STARTSPANNUNG: "Startspannung",
	Relic.BUSBREITE:     "Bus-Breite",
	Relic.DURCHBRUCH:    "Durchbruch-Optimierung",
	Relic.KUEHLPASTE:    "Wärmeleitpaste",
	Relic.EFFIZIENZ:     "Effizienz-Firmware",
}
const RELIC_DESCS := {
	Relic.STARTSPANNUNG: "Pakete starten mit Wert 3 statt 1.",
	Relic.BUSBREITE:     "+1 Paket pro Runde.",
	Relic.DURCHBRUCH:    "Durchbruch-Bonus ×2 statt ×1,5.",
	Relic.KUEHLPASTE:    "Hitze-Limit +4.",
	Relic.EFFIZIENZ:     "Gesamtschaden +25%.",
}
# Aktuell im Run gesammelte Relikte + zur Wahl stehende Belohnung
var relics: Array = []
var reward_choices: Array = []

# Spiel-Ressourcen
var money: int = 5
var score: int = 0
var highscore: int = 0
var current_round: int = 0
var base_watt_budget: int = 10
var reroll_cost: int = 3

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
	relics = []
	reward_choices = []
	reroll_cost = 3
	stats = {
		"total_damage": 0, "firewalls_destroyed": 0,
		"components_placed": 0, "components_bought": 0,
		"packets_sent": 0, "best_single_packet": 0
	}
	inventory = Inventory.new()
	# Start-Ausrüstung: 5 Leiterbahnen, damit ein Weg gebaut werden kann
	for _i in range(5):
		inventory.add_item(Component.ComponentType.TRACE)
	board.clear_board()
	print("=== NEUER RUN GESTARTET === Start-Geld: ", money)
	ui_message = "Du hast 5 Leiterbahnen. Kaufe Bauteile, dann starte Runde 1."
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

# Effektives Hitze-Limit der Runde – EINE Quelle für Anzeige und Berechnung.
# = Firewall-Basis + Netzteile (+3 je Stück) + Wärmeleitpaste-Relikt (+4).
func effective_heat_limit() -> int:
	var limit = firewall.heat_limit if firewall else 7
	limit += board.get_power_bonus()
	if has_relic(Relic.KUEHLPASTE):
		limit += 4
	return limit


# Berechnet den kompletten Sende-Vorgang OHNE Zustandsänderung.
# Wird von der UI genutzt, um zuerst die Animation zu zeigen und danach
# via apply_send() den Schaden anzuwenden. Gibt ein Ergebnis-Dictionary zurück.
func compute_send() -> Dictionary:
	# Startwert (Relikt Startspannung)
	var start_value = 3 if has_relic(Relic.STARTSPANNUNG) else 1
	var path_result = board.simulate_path(start_value)
	var per_packet = int(path_result.value)

	# Durchbruch-Bonus: Paket erreicht den rechten Rand
	if path_result.reached_end:
		var break_mult = 2.0 if has_relic(Relic.DURCHBRUCH) else 1.5
		per_packet = int(ceil(per_packet * break_mult))

	# Mainboard: board-weiter Multiplikator
	per_packet = int(per_packet * board.get_board_multiplier())

	# Schild-Modifikator: Schaden pro Paket gedeckelt
	if firewall and firewall.packet_damage_cap > 0:
		per_packet = min(per_packet, firewall.packet_damage_cap)

	var packets = (firewall.packets_per_round if firewall else 1)
	if has_relic(Relic.BUSBREITE):
		packets += 1
	var raw = per_packet * packets

	# Effizienz-Relikt: +25% Gesamtschaden
	if has_relic(Relic.EFFIZIENZ):
		raw = int(raw * 1.25)

	# Überhitzung (Netzteile + Wärmeleitpaste heben das Limit) – gleiche Quelle wie die Anzeige
	var heat = board.get_total_heat()
	var hlimit = effective_heat_limit()
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
		if current_round >= WIN_ROUND:
			ui_message = "Alle %d Firewalls geknackt – du hast gewonnen!" % WIN_ROUND
			show_victory()
		else:
			ui_message = "Firewall zerstört! %d Schaden%s  •  +%d Geld" % [total_damage, note, firewall.reward_watt]
			start_reward_phase()
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
	reroll_cost = 3
	shop.generate_offerings(current_round)
	_redraw_ui()
	print("========== SHOP ==========")
	print("Geld: ", money)
	shop.print_shop()


# Neu würfeln der Shop-Angebote gegen Bezahlung.
func reroll_shop() -> void:
	if phase != GamePhase.SHOP:
		return
	if money < reroll_cost:
		ui_message = "Reroll kostet %d Geld – du hast nur %d." % [reroll_cost, money]
		_redraw_ui()
		return
	money -= reroll_cost
	reroll_cost += 1
	shop.generate_offerings(current_round)
	ui_message = "Neue Angebote gewürfelt."
	_redraw_ui()


# Verkauft ein Inventar-Item für die Hälfte des Basispreises (mind. 1).
func sell_item(index: int) -> void:
	if inventory == null:
		return
	var t = inventory.peek_item(index)
	if t == -1:
		return
	var refund = max(1, int(Component.get_base_price(t) / 2.0))
	inventory.take_item(index)
	money += refund
	ui_message = "Verkauft: %s für %d Geld." % [Component.get_type_name(t), refund]
	_redraw_ui()


# =============================================
#  RELIKTE / BELOHNUNG / SIEG
# =============================================

func has_relic(r: int) -> bool:
	return relics.has(r)


# Nach einem Sieg: bis zu 3 zufällige, noch nicht besessene Relikte anbieten.
func start_reward_phase() -> void:
	var pool = []
	for r in [Relic.STARTSPANNUNG, Relic.BUSBREITE, Relic.DURCHBRUCH, Relic.KUEHLPASTE, Relic.EFFIZIENZ]:
		if not relics.has(r):
			pool.append(r)
	pool.shuffle()
	reward_choices = pool.slice(0, min(3, pool.size()))
	if reward_choices.is_empty():
		# Alle Relikte gesammelt -> direkt in den Shop
		start_shop_phase()
		return
	phase = GamePhase.REWARD
	_redraw_ui()


func choose_reward(index: int) -> void:
	if phase != GamePhase.REWARD:
		return
	if index >= 0 and index < reward_choices.size():
		var r = reward_choices[index]
		relics.append(r)
		ui_message = "Relikt erhalten: %s" % RELIC_NAMES[r]
	reward_choices = []
	start_shop_phase()


func show_victory() -> void:
	phase = GamePhase.VICTORY
	if score > highscore:
		highscore = score
	print("=== SIEG === Score: ", score)
	_redraw_ui()


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


# Konsolen-Befehle wurden entfernt – die Steuerung läuft komplett über die
# klickbare UI (ui.gd).