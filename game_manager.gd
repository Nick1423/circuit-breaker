# Circuit Breaker - Haupt-Spiel-Loop
# Steuert Phasen: Build -> Send -> Result -> Shop -> nächste Runde

extends Node

# GameShop, Component, Firewall, Inventory sind über class_name global verfügbar.

# Node-Referenzen
@onready var board: Node2D = $"../Board"

# Spiel-Zustand
enum GamePhase { HOMESCREEN, BUILD, SEND, RESULT, REWARD, SHOP, GAMEOVER, VICTORY }
var phase: GamePhase = GamePhase.HOMESCREEN

# Level-Struktur: 1 Level = 1 Firewall, die in bis zu ROUNDS_PER_LEVEL Runden
# geknackt werden muss (Schaden summiert sich). WIN_LEVEL Level = Sieg.
const ROUNDS_PER_LEVEL: int = 3
const WIN_LEVEL: int = 5

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
var level: int = 0            # aktuelles Level (1..WIN_LEVEL)
var round_in_level: int = 0   # Runde innerhalb des Levels (1..ROUNDS_PER_LEVEL)
var current_round: int = 0    # Gesamtzahl gespielter Runden (für Statistik)
var base_watt_budget: int = 10
var reroll_cost: int = 3
# Steuert, was der "Weiter"-Button im Shop auslöst: "start_level" oder "next_round"
var after_shop: String = "start_level"

# Kurze Rückmeldung für die UI (Ergebnis, Kauf, Fehler)
var ui_message: String = ""

# Firewall der aktuellen Runde
var firewall: Firewall = null

# Shop & Inventar
var shop: GameShop = null
var inventory: Inventory = null

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
	shop = GameShop.new()
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
	level = 0
	round_in_level = 0
	current_round = 0
	after_shop = "start_level"
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
	ui_message = "Du hast 5 Leiterbahnen. Kaufe Bauteile, dann starte Level 1."
	# Run beginnt im Shop: erst Bausteine kaufen, dann 'Weiter'.
	start_shop_phase()


# =============================================
#  LEVEL & RUNDE
# =============================================

# Startet ein neues Level mit einer frischen Firewall (HP steigt pro Level).
func start_level() -> void:
	level += 1
	round_in_level = 1
	current_round += 1
	firewall = Firewall.new(level)
	phase = GamePhase.BUILD
	money += 3 + level
	board.watt_budget = base_watt_budget + (level - 1) * 2
	ui_message = "Level %d — Runde 1/%d. Knacke die Firewall!" % [level, ROUNDS_PER_LEVEL]
	print("=== LEVEL ", level, " (Runde 1/", ROUNDS_PER_LEVEL, ") ===")
	print(firewall.get_status())
	_redraw_ui()


# Nächste Runde innerhalb desselben Levels – die Firewall bleibt bestehen,
# der bisherige Schaden zählt weiter (kumulativ).
func next_round() -> void:
	round_in_level += 1
	current_round += 1
	phase = GamePhase.BUILD
	money += 2
	var last := round_in_level >= ROUNDS_PER_LEVEL
	var warn := "   LETZTE RUNDE – sonst Game Over!" if last else ""
	ui_message = "Level %d — Runde %d/%d.%s" % [level, round_in_level, ROUNDS_PER_LEVEL, warn]
	print("=== LEVEL ", level, " (Runde ", round_in_level, "/", ROUNDS_PER_LEVEL, ") ===")
	_redraw_ui()


# Wird vom "Weiter"-Button im Shop aufgerufen.
func advance_from_shop() -> void:
	if phase != GamePhase.SHOP:
		return
	if after_shop == "next_round":
		next_round()
	else:
		start_level()


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
		# Level geschafft!
		stats.firewalls_destroyed += 1
		money += firewall.reward_watt
		if level >= WIN_LEVEL:
			ui_message = "Alle %d Level geknackt – du hast gewonnen!" % WIN_LEVEL
			show_victory()
		else:
			ui_message = "Level %d geschafft! %d Schaden%s  •  +%d Geld — wähle ein Upgrade." % [level, total_damage, note, firewall.reward_watt]
			# Nach Level-Clear: Upgrade wählen -> Shop -> nächstes Level
			after_shop = "start_level"
			start_reward_phase()
	else:
		# Firewall hält noch
		if round_in_level >= ROUNDS_PER_LEVEL:
			ui_message = "Firewall hält nach %d Runden (%d/%d HP) — Game Over." % [ROUNDS_PER_LEVEL, firewall.health, firewall.max_health]
			show_game_over()
		else:
			ui_message = "Runde %d/%d: %d Schaden%s. Firewall bei %d/%d HP — weiter im Shop." % [round_in_level, ROUNDS_PER_LEVEL, total_damage, note, firewall.health, firewall.max_health]
			after_shop = "next_round"
			start_shop_phase()


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