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

# Wie stark ein Kühler die Hitze jedes Nachbarn senkt
const COOLER_STRENGTH: int = 2
# Wie viel Hitze-Limit ein Netzteil hinzufügt
const PSU_HEAT_BONUS: int = 3
# Wie viel Endschaden-Bonus ein Mainboard gibt (+50% je Stück)
const MAINBOARD_BONUS: float = 0.5

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

static func get_label(type: int) -> String:
	return _LABELS.get(type, "?")

static func get_heat(type: int) -> int:
	return _HEAT.get(type, 0)

static func get_base_price(type: int) -> int:
	return _PRICE.get(type, 1)

static func get_description(type: int) -> String:
	return _DESCRIPTIONS.get(type, "")


# Wendet den (stateless) Effekt eines Bausteins auf einen Paketwert an.
# TRACE/CACHE/HEATSINK/PSU verändern den Wert hier nicht; RAM und CACHE werden
# in board.simulate_path() mit Pfad-Kontext behandelt.
static func process_packet(type: int, value: int) -> int:
	match type:
		ComponentType.CPU:
			return value + 5
		ComponentType.GPU:
			return value * 2
		ComponentType.NPU:
			return int(ceil(value * 1.5))
		_:
			return value
