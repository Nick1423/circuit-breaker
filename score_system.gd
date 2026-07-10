# Circuit Breaker - Score & Wirtschaft
# Verwaltet Geld, Punkte und Spiel-Fortschritt.

extends Node

# Spieler-Ressourcen
var money: int = 5          # Startgeld
var score: int = 0          # Gesamtpunktzahl
var highscore: int = 0      # Bester Run
var round_reached: int = 0  # Höchste erreichte Runde

# Statistik für den aktuellen Run
var stats = {
	"total_damage": 0,
	"firewalls_destroyed": 0,
	"components_placed": 0,
	"components_bought": 0,
	"packets_sent": 0,
	"best_single_packet": 0
}


func _init() -> void:
	_load_highscore()


# Fügt Geld hinzu
func add_money(amount: int) -> void:
	money += amount
	print("+", amount, " Geld (", money, ")")


# Gibt Geld aus. Gibt true zurück bei Erfolg.
func spend_money(amount: int) -> bool:
	if money >= amount:
		money -= amount
		print("-", amount, " Geld (", money, ")")
		return true
	print("Nicht genug Geld! (", money, "/", amount, ")")
	return false


# Fügt Punkte hinzu (basierend auf Schaden)
func add_score(damage: int) -> void:
	var points = damage
	score += points
	stats.total_damage += damage


# Zählt einen platzierten Block
func count_placement() -> void:
	stats.components_placed += 1


# Zählt einen gekauften Block
func count_purchase() -> void:
	stats.components_bought += 1


# Zählt ein gesendetes Paket
func count_packet(value: int) -> void:
	stats.packets_sent += 1
	if value > stats.best_single_packet:
		stats.best_single_packet = value


# Zählt eine zerstörte Firewall
func count_firewall_destroyed() -> void:
	stats.firewalls_destroyed += 1


# Beendet den Run und speichert Highscore
func end_run() -> void:
	if score > highscore:
		highscore = score
		_save_highscore()
	
	print("=== RUN BEENDET ===")
	print("Score: ", score)
	print("Runde: ", round_reached)
	print("Highscore: ", highscore)
	print("Schaden: ", stats.total_damage)
	print("Bester Paket-Wert: ", stats.best_single_packet)
	print("Bauteile platziert: ", stats.components_placed)
	print("Bauteile gekauft: ", stats.components_bought)


# Setzt den Run zurück (für Neustart)
func reset_run() -> void:
	money = 5
	score = 0
	round_reached = 0
	stats = {
		"total_damage": 0,
		"firewalls_destroyed": 0,
		"components_placed": 0,
		"components_bought": 0,
		"packets_sent": 0,
		"best_single_packet": 0
	}


# Gibt den aktuellen Status als String zurück
func get_status() -> String:
	return "Geld: %d | Score: %d | Runde: %d" % [money, score, round_reached]


# Lädt den Highscore (später: aus Datei)
func _load_highscore() -> void:
	# TODO: Aus Datei laden
	highscore = 0


# Speichert den Highscore (später: in Datei)
func _save_highscore() -> void:
	# TODO: In Datei speichern
	print("Neuer Highscore: ", highscore)