# Circuit Breaker - Block-Instanz auf dem Board
# Ein platzierter Block hat einen Typ (Component.ComponentType) sowie einen
# Eingang (in_dir) und einen Ausgang (out_dir). Pakete betreten den Block über
# den Eingang und verlassen ihn über den Ausgang.

class_name Block

# Richtungen (Reihenfolge wichtig: opposite = (d + 2) % 4)
enum Dir { RIGHT, DOWN, LEFT, UP }

const DELTA := {
	Dir.RIGHT: Vector2i(1, 0),
	Dir.DOWN:  Vector2i(0, 1),
	Dir.LEFT:  Vector2i(-1, 0),
	Dir.UP:    Vector2i(0, -1),
}

var type: int          # Component.ComponentType
var in_dir: int = Dir.LEFT
var out_dir: int = Dir.RIGHT


func _init(p_type: int, p_in: int = Dir.LEFT, p_out: int = Dir.RIGHT) -> void:
	type = p_type
	in_dir = p_in
	out_dir = p_out


static func opposite(d: int) -> int:
	return (d + 2) % 4


static func delta(d: int) -> Vector2i:
	return DELTA.get(d, Vector2i.ZERO)


static func arrow(d: int) -> String:
	match d:
		Dir.RIGHT: return "→"
		Dir.DOWN:  return "↓"
		Dir.LEFT:  return "←"
		Dir.UP:    return "↑"
	return "?"


static func dir_name(d: int) -> String:
	match d:
		Dir.RIGHT: return "Rechts"
		Dir.DOWN:  return "Unten"
		Dir.LEFT:  return "Links"
		Dir.UP:    return "Oben"
	return "?"


# Dreht den Ausgang zur nächsten Richtung, überspringt die Eingangsrichtung
# (Ein- und Ausgang dürfen nicht auf derselben Seite liegen).
func cycle_out() -> void:
	var d := out_dir
	for _i in range(4):
		d = (d + 1) % 4
		if d != in_dir:
			break
	out_dir = d


# Dreht den Eingang zur nächsten Richtung, überspringt die Ausgangsrichtung.
func cycle_in() -> void:
	var d := in_dir
	for _i in range(4):
		d = (d + 1) % 4
		if d != out_dir:
			break
	in_dir = d
