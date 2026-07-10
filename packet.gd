# Circuit Breaker - Datenpaket
# Ein Paket startet links mit einem Wert und wird durch Bauteile verstärkt.

class_name Packet

var value: int
var start_value: int = 1

func _init():
	value = start_value

# Setzt das Paket auf den Startwert zurück
func reset():
	value = start_value

# Gibt eine textuelle Darstellung zurück
func describe() -> String:
	return "Paket(Wert: %d)" % value
