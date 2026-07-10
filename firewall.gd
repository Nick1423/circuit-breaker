# Circuit Breaker - Firewall-System
# Verwaltet die Firewall einer Runde: HP, Schaden, Belohnungen.

class_name Firewall

var level: int
var health: int
var max_health: int
var reward_watt: int
var packets_per_round: int

func _init(p_level: int):
	level = p_level
	max_health = 10 + (p_level * 5)
	health = max_health
	reward_watt = 2 + p_level
	packets_per_round = 3 + floor(p_level / 2)

# Fügt Schaden zu. Gibt true zurück, wenn die Firewall zerstört wurde.
func take_damage(amount: int) -> bool:
	health -= amount
	if health < 0:
		health = 0
	
	print("  Firewall nimmt ", amount, " Schaden! (", health, "/", max_health, " HP)")
	
	return health <= 0

# Prüft, ob die Firewall noch steht.
func is_alive() -> bool:
	return health > 0

# Gibt den aktuellen Status als String zurück.
func get_status() -> String:
	return "Firewall Level %d: %d/%d HP" % [level, health, max_health]

# Setzt die Firewall für einen neuen Versuch zurück (ohne Level-Änderung).
func reset() -> void:
	health = max_health