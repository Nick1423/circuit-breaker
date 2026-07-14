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

const MOD_DESCS := {
	Modifier.ARMORED:  "mehr HP",
	Modifier.UNSTABLE: "niedrigeres Hitze-Limit",
	Modifier.SHIELD:   "deckelt den Schaden pro Treffer",
	Modifier.JAMMER:   "dämpft den gelieferten Schaden",
	Modifier.MELTDOWN: "verschärft den Überhitzungs-Malus",
}

var level: int
var health: int
var max_health: int
var reward_watt: int            # Belohnung (Geld) bei Zerstörung
var heat_limit: int

# Modifikator-Zustand (von game_manager ausgewertet)
var modifiers: Array = []          # Liste aktiver Modifier (int)
var modifier_label: String = ""    # kombinierte Anzeige für die UI
var packet_damage_cap: int = 0     # SHIELD: max. Schaden pro Treffer (0 = kein Deckel)
var overheat_factor: float = 1.0   # MELTDOWN: verstärkt den Überhitzungs-Malus
var jammer_factor: float = 1.0     # JAMMER: dämpft gelieferten Schaden (1.0 = keine Störung)


# Unendliche HP-Kurve. Auf den transparenten (niedrigeren) Schaden abgestimmt:
# Level 1 klar mit ein paar CPUs schaffbar, danach stetig +22%/Level und ab
# Level 12 zusätzlich versteilt – bleibt endlos, verlangt aber Käufe + Übertaktung.
static func firewall_hp(l: int) -> int:
	var base := 22.0 * pow(1.22, l - 1)
	var accel := pow(1.05, max(0, l - 12))
	return int(round(base * accel))


func _init(p_level: int) -> void:
	level = p_level
	max_health = firewall_hp(level)
	reward_watt = 5 + level * 2
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
			# Signalstörung: gelieferter Schaden wird gedämpft, mit dem Level stärker.
			jammer_factor = clampf(0.7 - 0.015 * (level - 3), 0.45, 0.7)


func has_modifier() -> bool:
	return not modifiers.is_empty()


# Fügt Schaden zu. Gibt true zurück, wenn die Firewall zerstört wurde.
func take_damage(amount: int) -> bool:
	health = max(0, health - amount)
	return health <= 0


# Prüft, ob die Firewall noch steht.
func is_alive() -> bool:
	return health > 0
