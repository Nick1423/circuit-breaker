# Core Cocker - Haupt-Spiel-Loop
# Steuert Phasen: Build -> Send -> Belohnung -> Shop -> nächstes Level.
# Endlos-Modus: die Level werden immer schwerer, bis die Firewall nicht mehr
# rechtzeitig fällt (Game Over). Ein Highscore/Best-Level bleibt erhalten.

extends Node

# GameShop, Component, Firewall, Inventory sind über class_name global verfügbar.

# Node-Referenzen
@onready var board: Node2D = $"../Board"

# Spiel-Zustand
enum GamePhase { HOMESCREEN, BUILD, SEND, RESULT, REWARD, SHOP, GAMEOVER }
var phase: GamePhase = GamePhase.HOMESCREEN

# Level-Struktur: 1 Level = 1 Firewall, die in bis zu ROUNDS_PER_LEVEL Runden
# (Schaden kumuliert) geknackt werden muss. Es gibt kein End-Level – nur Endlos.
const ROUNDS_PER_LEVEL: int = 3

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
	Relic.BUSBREITE:     "+20% Gesamtschaden.",
	Relic.DURCHBRUCH:    "Durchbruch-Bonus ×2 statt ×1,5.",
	Relic.KUEHLPASTE:    "Hitze-Limit +4.",
	Relic.EFFIZIENZ:     "Gesamtschaden +25%.",
}
# Aktuell im Run gesammelte Relikte + zur Wahl stehende Belohnung
var relics: Array = []
var reward_choices: Array = []

# Spiel-Ressourcen
var money: int = 12
var score: int = 0
var highscore: int = 0
var best_level: int = 0        # bestes je erreichtes Level (bleibt über Runs)
var level: int = 0             # aktuelles Level (1..)
var round_in_level: int = 0    # Runde innerhalb des Levels (1..ROUNDS_PER_LEVEL)
var current_round: int = 0     # Gesamtzahl gespielter Runden (für Shop-Statistik)
var reroll_cost: int = 3
# Steuert, was der "Weiter"-Button im Shop auslöst: "start_level" oder "next_round"
var after_shop: String = "start_level"

# Dauerhafte Übertaktungs-Boni (Endlos-Belohnungen, wenn alle Relikte gesammelt)
var overclock_dmg: int = 0     # je Stufe +5% Gesamtschaden (max +50%)
var overclock_heat: int = 0    # je Stufe +2 Hitze-Limit

# Kurze Rückmeldung für die UI (Ergebnis, Kauf, Fehler)
var ui_message: String = ""

# Firewall des aktuellen Levels
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


# =============================================
#  SPIEL STARTEN
# =============================================

func start_new_run() -> void:
	money = 10
	score = 0
	level = 0
	round_in_level = 0
	current_round = 0
	after_shop = "start_level"
	firewall = null
	relics = []
	reward_choices = []
	reroll_cost = 3
	overclock_dmg = 0
	overclock_heat = 0
	stats = {
		"total_damage": 0, "firewalls_destroyed": 0,
		"components_placed": 0, "components_bought": 0,
		"packets_sent": 0, "best_single_packet": 0
	}
	inventory = Inventory.new()
	# Start-Ausrüstung: ein paar Leiterbahnen, um den Weg günstig um Ecken zu biegen.
	for _i in range(4):
		inventory.add_item(Component.ComponentType.TRACE)
	board.clear_board()
	ui_message = "Route das Paket vom EINGANG (links Mitte) zum AUSGANG (rechts Mitte). Klicke einen Block, um seinen Ausgang zu drehen. Kaufe zuerst im Shop."
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
	money += 3
	ui_message = "Level %d — Runde 1/%d. Route das Paket zum Ausgang und knacke die Firewall!" % [level, ROUNDS_PER_LEVEL]
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
# = Firewall-Basis + Netzteile (+3 je Stück) + Wärmeleitpaste + Übertaktung.
func effective_heat_limit() -> int:
	var limit = firewall.heat_limit if firewall else 7
	limit += board.get_power_bonus()
	if has_relic(Relic.KUEHLPASTE):
		limit += 4
	limit += overclock_heat * 2
	return limit


# Berechnet den kompletten Sende-Vorgang OHNE Zustandsänderung. Ein einzelnes
# Paket startet am Eingang (links, Mitte) und folgt den Ausgangsrichtungen der
# Blöcke. Erreicht es den Ausgang (rechts, Mitte), zählt sein Wert als Schaden
# (× Durchbruch-Bonus). Verfehlt es den Ausgang, gibt es keinen Schaden. Gibt ein
# Ergebnis-Dictionary zurück, das die UI erst animiert und dann via apply_send()
# anwendet.
func compute_send() -> Dictionary:
	var start_value := 3 if has_relic(Relic.STARTSPANNUNG) else 1
	var break_mult := 2.0 if has_relic(Relic.DURCHBRUCH) else 1.5
	var board_mult: float = board.get_board_multiplier()

	var route: Dictionary = board.simulate_route(start_value)
	var delivered: bool = route.get("delivered", false)
	var value: int = int(route.get("value", 0))

	var raw := 0
	if delivered:
		raw = int(ceil(value * break_mult))
		raw = int(raw * board_mult)
		if firewall and firewall.jammer_factor < 1.0:      # JAMMER: Signal gedämpft
			raw = int(raw * firewall.jammer_factor)
		if firewall and firewall.packet_damage_cap > 0:    # SHIELD: Deckel pro Treffer
			raw = min(raw, firewall.packet_damage_cap)
		if has_relic(Relic.EFFIZIENZ):
			raw = int(raw * 1.25)
		if has_relic(Relic.BUSBREITE):
			raw = int(raw * 1.20)

	# Überhitzung: steiler Malus, wenn Hitze über dem Limit liegt.
	var heat: int = board.get_total_heat()
	var hlimit := effective_heat_limit()
	var overheated := heat > hlimit
	var total := raw
	if overheated and raw > 0:
		var ratio := float(hlimit) / float(max(1, heat))
		var penalty := clampf(pow(ratio, 1.5), 0.15, 1.0)
		penalty = clampf(1.0 - (1.0 - penalty) * (firewall.overheat_factor if firewall else 1.0), 0.10, 1.0)
		total = int(raw * penalty)

	total = int(total * (1.0 + overclock_dmg * 0.05))

	return {
		"path": route.get("path", []),
		"delivered": delivered,
		"reason": route.get("reason", "empty"),
		"end_col": int(route.get("end_col", 0)),
		"end_row": int(route.get("end_row", 0)),
		"value": value,
		"packets": 1 if delivered else 0,
		"raw": raw,
		"heat": heat,
		"heat_limit": hlimit,
		"overheated": overheated,
		"total_damage": total,
	}


# Kurztext, warum das Paket den Ausgang nicht erreicht hat.
func reason_hint(reason: String) -> String:
	match reason:
		"empty":   return "Der Weg endet an einem leeren Feld."
		"offgrid": return "Der Weg verlässt das Feld an der falschen Seite."
		"loop":    return "Der Weg läuft im Kreis."
		_:         return ""


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
	if total_damage > stats.best_single_packet:
		stats.best_single_packet = total_damage

	var note = ""
	if res.get("delivered", false):
		note = "  (Durchbruch)"
	else:
		note = "  — Paket verfehlt den Ausgang: %s" % reason_hint(res.get("reason", ""))
	if res.get("overheated", false):
		note += "  (überhitzt!)"

	if not firewall.is_alive():
		# Level geschafft!
		stats.firewalls_destroyed += 1
		money += firewall.reward_watt
		ui_message = "Level %d geknackt! %d Schaden%s  •  +%d Geld — wähle ein Upgrade." % [level, total_damage, note, firewall.reward_watt]
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
	reroll_cost = 3 + int(level / 2.0)
	shop.generate_offerings(level)
	_redraw_ui()


# Neu würfeln der Shop-Angebote gegen Bezahlung.
func reroll_shop() -> void:
	if phase != GamePhase.SHOP:
		return
	if money < reroll_cost:
		ui_message = "Reroll kostet %d Geld – du hast nur %d." % [reroll_cost, money]
		_redraw_ui()
		return
	money -= reroll_cost
	reroll_cost += 2
	shop.generate_offerings(level)
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
#  RELIKTE / BELOHNUNG
# =============================================

func has_relic(r: int) -> bool:
	return relics.has(r)


# Anzeigename einer Belohnung (Relikt oder Endlos-Übertaktung).
func reward_name(r: int) -> String:
	match r:
		-1: return "Datenbonus"
		-2: return "Kühlkörper-Upgrade"
		-3: return "Übertaktung"
		_:  return RELIC_NAMES.get(r, "?")


func reward_desc(r: int) -> String:
	match r:
		-1: return "Sofort +%d Geld." % (10 + 3 * level)
		-2: return "Hitze-Limit dauerhaft +2."
		-3: return "Gesamtschaden dauerhaft +5%."
		_:  return RELIC_DESCS.get(r, "")


# Nach einem Level-Clear: 3 Belohnungen anbieten. Solange noch Relikte offen sind,
# werden Relikte gewählt; sind alle gesammelt, kommen wiederholbare Übertaktungen.
func start_reward_phase() -> void:
	var pool = []
	for r in [Relic.STARTSPANNUNG, Relic.BUSBREITE, Relic.DURCHBRUCH, Relic.KUEHLPASTE, Relic.EFFIZIENZ]:
		if not relics.has(r):
			pool.append(r)
	pool.shuffle()
	reward_choices = pool.slice(0, min(3, pool.size()))
	if reward_choices.is_empty():
		# Alle Relikte gesammelt -> wiederholbare Endlos-Upgrades
		reward_choices = [-1, -2, -3]
	phase = GamePhase.REWARD
	_redraw_ui()


func choose_reward(index: int) -> void:
	if phase != GamePhase.REWARD:
		return
	if index >= 0 and index < reward_choices.size():
		var r = reward_choices[index]
		match r:
			-1: money += 10 + 3 * level
			-2: overclock_heat += 1
			-3: overclock_dmg = min(overclock_dmg + 1, 10)  # Deckel +50%
			_:  relics.append(r)
		ui_message = "Erhalten: %s" % reward_name(r)
	reward_choices = []
	start_shop_phase()


func buy_component(index: int) -> void:
	if phase != GamePhase.SHOP:
		return
	if inventory.get_item_count() >= inventory.max_size:
		ui_message = "Inventar voll – kein Platz für weitere Bauteile."
		_redraw_ui()
		return
	var result = shop.buy(index, money)
	if result.success:
		money -= result.price
		stats.components_bought += 1
		inventory.add_item(result.component_type)
		ui_message = "Gekauft: %s für %d Geld." % [result.name, result.price]
	else:
		ui_message = "Kauf fehlgeschlagen: %s" % result.reason
	_redraw_ui()


# =============================================
#  GAME OVER
# =============================================

func show_game_over() -> void:
	phase = GamePhase.GAMEOVER
	if score > highscore:
		highscore = score
	if level > best_level:
		best_level = level
	_redraw_ui()
