# Core Cocker - Firewall-System
# Verwaltet die Firewall eines Levels: HP, Schaden, Belohnung, Hitze-Limit und
# ab Level 3 zufällige Modifikatoren (Sonderregeln), deren Anzahl und Stärke mit
# dem Level wachsen – für unendlich steigende, aber faire Schwierigkeit.

class_name Firewall

enum Modifier { ARMORED, UNSTABLE, SHIELD, JAMMER, MELTDOWN }

const MOD_NAMES := {
	Modifier.ARMORED:  "Gepanzert",
	Modifier.UNSTABLE: "Instabil",
	Modifier.SHIELD:   "Schild",
	Modifier.JAMMER:   "Störsender",
	Modifier.MELTDOWN: "Brandmelder",
}

var level: int
var health: int
var max_health: int
var reward_watt: int            # Belohnung (Geld) bei Zerstörung
var heat_limit: int

# Modifikator-Zustand (von game_manager ausgewertet)
var modifiers: Array = []          # Liste aktiver Modifier (int)
var modifier_label: String = ""    # kombinierte Anzeige für die UI
var packet_damage_cap: int = 0     # SHIELD: max. Schaden pro Lane (0 = kein Deckel)
var overheat_factor: float = 1.0   # MELTDOWN: verstärkt den Überhitzungs-Malus


# Unendliche HP-Kurve: früh sanft (+25%/Level), ab Level 10 zusätzlich versteilt.
static func firewall_hp(l: int) -> int:
	var base := 32.0 * pow(1.25, l - 1)
	var accel := pow(1.06, max(0, l - 10))
	return int(round(base * accel))


func _init(p_level: int) -> void:
	level = p_level
	max_health = firewall_hp(level)
	reward_watt = 6 + level * 3
	heat_limit = 6 + level
	_roll_modifiers()
	health = max_health


# Anzahl unterschiedlicher Modifikatoren je Level (0..3).
func _modifier_count() -> int:
	if level < 3:
		return 0
	var guaranteed := 1
	if level >= 8:
		guaranteed = 2
	if level >= 14:
		guaranteed = 3
	var extra := clampf(0.12 * (level - 3), 0.0, 0.5)
	var n := guaranteed
	if guaranteed < 3 and randf() < extra:
		n += 1
	return n


func _roll_modifiers() -> void:
	var n := _modifier_count()
	if n <= 0:
		return
	var options := [Modifier.ARMORED, Modifier.UNSTABLE, Modifier.SHIELD, Modifier.JAMMER, Modifier.MELTDOWN]
	options.shuffle()
	modifiers = options.slice(0, min(n, options.size()))
	# In fester Reihenfolge anwenden: ARMORED zuerst, damit SHIELD die erhöhte HP nutzt.
	for m in [Modifier.ARMORED, Modifier.UNSTABLE, Modifier.SHIELD, Modifier.MELTDOWN, Modifier.JAMMER]:
		if m in modifiers:
			_apply_modifier(m)
	var names := []
	for m in modifiers:
		names.append(MOD_NAMES[m])
	modifier_label = ", ".join(names)


func _apply_modifier(m: int) -> void:
	match m:
		Modifier.ARMORED:
			var hp_mult := minf(2.0, 1.5 + 0.03 * (level - 3))
			max_health = int(round(max_health * hp_mult))
		Modifier.UNSTABLE:
			@warning_ignore("integer_division")
			heat_limit = max(1, heat_limit - (4 + int((level - 3) / 4.0)))
		Modifier.SHIELD:
			var frac := clampf(0.5 - 0.02 * (level - 3), 0.22, 0.5)
			packet_damage_cap = int(round(max_health * frac))
		Modifier.MELTDOWN:
			overheat_factor = minf(3.5, 2.0 + 0.1 * (level - 3))
		Modifier.JAMMER:
			pass  # Wirkung erst in jammer_rows()


func has_modifier() -> bool:
	return not modifiers.is_empty()


# Welche Zeilen deaktiviert der Störsender? level<12: Zeile 0; level>=12: beste Lane.
# Nie mehr als eine Zeile. board_ref = das Board (für simulate_lane).
func jammer_rows(board_ref) -> Array:
	if not (Modifier.JAMMER in modifiers):
		return []
	if level < 12:
		return [0]
	var best_row := -1
	var best_val := -1
	for row in range(board_ref.BOARD_HEIGHT):
		var lane: Dictionary = board_ref.simulate_lane(row, 1)
		if lane.is_empty():
			continue
		if int(lane.value) > best_val:
			best_val = int(lane.value)
			best_row = row
	return [best_row] if best_row >= 0 else []


# Fügt Schaden zu. Gibt true zurück, wenn die Firewall zerstört wurde.
func take_damage(amount: int) -> bool:
	health = max(0, health - amount)
	return health <= 0


# Prüft, ob die Firewall noch steht.
func is_alive() -> bool:
	return health > 0
