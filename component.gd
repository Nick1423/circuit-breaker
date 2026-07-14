# Circuit Breaker - Bauteil-Definitionen (zentrale Datenquelle)
#
# Echte IT-Bauteile mit klarer Funktion. Jeder Typ hat: Kurzname (Badge auf dem
# Block), Effekt-Label, Beschreibung, Hitze und Basispreis.
#
# Effekte:
#   TRACE (Leiterbahn) : +0, nur Routing
#   CPU                : +5
#   RAM                : +2 je bereits durchlaufenem Bauteil (in board.gd)
#   GPU                : x2
#   NPU                : x1.5 (aufgerundet)
#   CACHE (Cache)      : wiederholt den vorherigen Baustein (in board.gd)
#   HEATSINK (Kühler)  : kein Paket-Effekt, senkt Nachbar-Hitze
#   PSU (Netzteil)     : kein Paket-Effekt, hebt das Hitze-Limit (in game_manager)

class_name Component

enum ComponentType {
	TRACE,
	CPU,
	RAM,
	GPU,
	NPU,
	CACHE,
	HEATSINK,
	PSU,
	MAINBOARD,
}

# Basiswerte (tier 0). Die tier-abhängigen Effekte stehen in den *_at()-Funktionen.
# Wie stark ein Kühler die Hitze jedes Nachbarn senkt
const COOLER_STRENGTH: int = 2
# Wie viel Hitze-Limit ein Netzteil hinzufügt
const PSU_HEAT_BONUS: int = 3
# Wie viel Endschaden-Bonus ein Mainboard gibt (+50% je Stück)
const MAINBOARD_BONUS: float = 0.5

# Höchste Übertaktungsstufe (0 = normal, bis MAX_TIER aufwertbar)
const MAX_TIER: int = 4

# ---- Tier-abhängige Effektwerte (eine zentrale Quelle) ----
static func cpu_add(tier: int) -> int:          # CPU: +5, +7, +9, ...
	return 5 + 2 * tier
static func gpu_mult(tier: int) -> float:       # GPU: x2.0, x2.35, x2.7, ...
	return 2.0 + 0.35 * tier
static func npu_mult(tier: int) -> float:       # NPU: x1.5, x1.7, x1.9, ...
	return 1.5 + 0.2 * tier
static func ram_per(tier: int) -> int:          # RAM: +2, +3, +4 je Vor-Block
	return 2 + tier
static func cache_repeats(tier: int) -> int:    # CACHE: 1x, 2x, 3x Wiederholung
	return 1 + tier
static func cooler_strength(tier: int) -> int:  # Kühler: -2, -3, -4 Nachbar-Hitze
	return COOLER_STRENGTH + tier
static func psu_bonus(tier: int) -> int:        # Netzteil: +3, +4, +5 Hitze-Limit
	return PSU_HEAT_BONUS + tier
static func mainboard_bonus(tier: int) -> float: # Mainboard: +50%, +75%, +100% ...
	return MAINBOARD_BONUS + 0.25 * tier

const _NAMES := {
	ComponentType.TRACE:    "Leiterbahn",
	ComponentType.CPU:      "CPU",
	ComponentType.RAM:      "RAM",
	ComponentType.GPU:      "GPU",
	ComponentType.NPU:      "NPU",
	ComponentType.CACHE:    "Cache",
	ComponentType.HEATSINK: "Kühler",
	ComponentType.PSU:      "Netzteil",
	ComponentType.MAINBOARD: "Mainboard",
}

# Kurzer Badge oben auf dem Block
const _SHORT := {
	ComponentType.TRACE:    "PCB",
	ComponentType.CPU:      "CPU",
	ComponentType.RAM:      "RAM",
	ComponentType.GPU:      "GPU",
	ComponentType.NPU:      "NPU",
	ComponentType.CACHE:    "Cache",
	ComponentType.HEATSINK: "Kühler",
	ComponentType.PSU:      "PSU",
	ComponentType.MAINBOARD: "MoBo",
}

# Effekt-Label (untere Zeile auf dem Block)
const _LABELS := {
	ComponentType.TRACE:    "→",
	ComponentType.CPU:      "+5",
	ComponentType.RAM:      "+2/Blk",
	ComponentType.GPU:      "×2",
	ComponentType.NPU:      "+50%",
	ComponentType.CACHE:    "Loop",
	ComponentType.HEATSINK: "-Hitze",
	ComponentType.PSU:      "+Limit",
	ComponentType.MAINBOARD: "×Board",
}

const _DESCRIPTIONS := {
	ComponentType.TRACE:    "Leiterbahn: leitet das Paket ohne Änderung weiter und erzeugt keine Hitze. Ideal, um den Weg um die Ecke zum Ausgang zu biegen.",
	ComponentType.CPU:      "CPU: addiert +5 auf den Paketwert.",
	ComponentType.RAM:      "RAM: addiert +2 für jeden Baustein, den das Paket vorher schon durchlaufen hat. Stark am Ende langer Pfade.",
	ComponentType.GPU:      "GPU: verdoppelt den Paketwert (×2). Am stärksten nach vielen Addierern.",
	ComponentType.NPU:      "NPU: erhöht den Paketwert um 50% (×1,5, aufgerundet).",
	ComponentType.CACHE:    "Cache: wiederholt den Effekt des vorherigen Bausteins im Pfad noch einmal.",
	ComponentType.HEATSINK: "Kühler: kein Effekt aufs Paket, senkt aber die Hitze der 4 Nachbarn um 2.",
	ComponentType.PSU:      "Netzteil: kein Effekt aufs Paket, hebt aber das Hitze-Limit der Runde um +3.",
	ComponentType.MAINBOARD: "Mainboard: kein Effekt aufs einzelne Feld, erhöht aber den gesamten Paketwert um +50% je Mainboard auf dem Board.",
}

const _HEAT := {
	ComponentType.TRACE: 0, ComponentType.CPU: 1, ComponentType.RAM: 1,
	ComponentType.GPU: 3, ComponentType.NPU: 2, ComponentType.CACHE: 2,
	ComponentType.HEATSINK: 0, ComponentType.PSU: 1, ComponentType.MAINBOARD: 1,
}

const _PRICE := {
	ComponentType.TRACE: 1, ComponentType.CPU: 5, ComponentType.RAM: 7,
	ComponentType.GPU: 11, ComponentType.NPU: 7, ComponentType.CACHE: 8,
	ComponentType.HEATSINK: 4, ComponentType.PSU: 8, ComponentType.MAINBOARD: 15,
}


static func get_type_name(type: int) -> String:
	return _NAMES.get(type, "Unbekannt")

static func get_short_name(type: int) -> String:
	return _SHORT.get(type, "?")

# Effekt-Label; bei tier>0 wird der aktuelle (aufgewertete) Wert gezeigt.
static func get_label(type: int, tier: int = 0) -> String:
	if tier <= 0:
		return _LABELS.get(type, "?")
	match type:
		ComponentType.CPU:       return "+%d" % cpu_add(tier)
		ComponentType.RAM:       return "+%d/Blk" % ram_per(tier)
		ComponentType.GPU:       return "×%.2f" % gpu_mult(tier)
		ComponentType.NPU:       return "×%.1f" % npu_mult(tier)
		ComponentType.CACHE:     return "Loop×%d" % cache_repeats(tier)
		ComponentType.HEATSINK:  return "-%d Hitze" % cooler_strength(tier)
		ComponentType.PSU:       return "+%d Lim" % psu_bonus(tier)
		ComponentType.MAINBOARD: return "+%d%%" % int(mainboard_bonus(tier) * 100)
		_:                       return _LABELS.get(type, "?")

# TRACE lässt sich nicht aufwerten (reiner Router). Alles andere schon.
static func is_upgradeable(type: int) -> bool:
	return type != ComponentType.TRACE

# Kosten, um von der aktuellen Stufe auf die nächste aufzuwerten. -1 = nicht möglich.
static func get_upgrade_cost(type: int, current_tier: int) -> int:
	if not is_upgradeable(type) or current_tier >= MAX_TIER:
		return -1
	return int(round(get_base_price(type) * 2.5 * (current_tier + 1)))

static func get_heat(type: int) -> int:
	return _HEAT.get(type, 0)

static func get_base_price(type: int) -> int:
	return _PRICE.get(type, 1)

static func get_description(type: int) -> String:
	return _DESCRIPTIONS.get(type, "")


# Wendet den (stateless) Effekt eines Bausteins auf einen Paketwert an.
# TRACE/HEATSINK/PSU/MAINBOARD verändern den Wert hier nicht; RAM und CACHE werden
# in board.simulate_route() mit Pfad-Kontext behandelt. tier = Übertaktungsstufe.
static func process_packet(type: int, value: int, tier: int = 0) -> int:
	match type:
		ComponentType.CPU:
			return value + cpu_add(tier)
		ComponentType.GPU:
			return int(round(value * gpu_mult(tier)))
		ComponentType.NPU:
			return int(ceil(value * npu_mult(tier)))
		_:
			return value
