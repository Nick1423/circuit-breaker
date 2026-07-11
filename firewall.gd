# Circuit Breaker - Firewall-System
# Verwaltet die Firewall einer Runde: HP, Schaden, Belohnungen, Hitze-Limit
# und ab Level 3 zufällige Modifikatoren (Sonderregeln, die deine Engine brechen).

class_name Firewall

enum Modifier {
	NONE,      # keine Sonderregel
	ARMORED,   # Gepanzert: +50% HP
	UNSTABLE,  # Instabil: Hitze-Limit -4
	SHIELD,    # Schild: Schaden pro Paket gedeckelt
	JAMMER,    # Störsender: Zeile 0 zählt nicht
	MELTDOWN   # Brandmelder: Überhitzungs-Malus doppelt
}

var level: int
var health: int
var max_health: int
var reward_watt: int          # Belohnung (Geld) bei Zerstörung
var packets_per_round: int
var heat_limit: int

# Modifikator-Zustand (von game_manager ausgewertet)
var modifier: Modifier = Modifier.NONE
var modifier_name: String = ""
var modifier_desc: String = ""
var packet_damage_cap: int = 0     # 0 = kein Deckel
var dead_row: int = -1             # -1 = keine tote Zeile
var overheat_factor: float = 1.0   # >1 verstärkt Überhitzungs-Malus


func _init(p_level: int):
	level = p_level
	max_health = int(round(12.0 * pow(1.5, p_level - 1)))
	reward_watt = 3 + p_level
	packets_per_round = 3 + int(floor(p_level / 2.0))
	heat_limit = 6 + p_level

	# Ab Level 3: Chance auf einen Modifikator
	if p_level >= 3 and randf() < 0.6:
		_apply_random_modifier()

	health = max_health


func _apply_random_modifier() -> void:
	var options = [
		Modifier.ARMORED, Modifier.UNSTABLE, Modifier.SHIELD,
		Modifier.JAMMER, Modifier.MELTDOWN
	]
	modifier = options[randi() % options.size()]

	match modifier:
		Modifier.ARMORED:
			modifier_name = "Gepanzert"
			modifier_desc = "+50% HP"
			max_health = int(round(max_health * 1.5))
		Modifier.UNSTABLE:
			modifier_name = "Instabil"
			modifier_desc = "Hitze-Limit -4"
			heat_limit = max(1, heat_limit - 4)
		Modifier.SHIELD:
			modifier_name = "Schild"
			packet_damage_cap = max(5, int(max_health / 2.0))
			modifier_desc = "max. %d Schaden pro Paket" % packet_damage_cap
		Modifier.JAMMER:
			modifier_name = "Störsender"
			modifier_desc = "Zeile 0 zählt nicht"
			dead_row = 0
		Modifier.MELTDOWN:
			modifier_name = "Brandmelder"
			modifier_desc = "Überhitzungs-Malus doppelt"
			overheat_factor = 2.0


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


func has_modifier() -> bool:
	return modifier != Modifier.NONE


# Gibt den aktuellen Status als String zurück.
func get_status() -> String:
	var s = "Firewall Level %d: %d/%d HP  (Hitze-Limit %d)" % [level, health, max_health, heat_limit]
	if has_modifier():
		s += "\n  >> MODIFIKATOR: %s (%s)" % [modifier_name, modifier_desc]
	return s


# Setzt die Firewall für einen neuen Versuch zurück (ohne Level-Änderung).
func reset() -> void:
	health = max_health
