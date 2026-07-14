# Core Cocker - Block-Instanz auf dem Board / im Inventar
#
# Jeder Block hat NUR einen Ausgang – keinen festen Eingang. Das Paket tritt aus
# der Nachbarzelle ein, wird verarbeitet und verlässt den Block IMMER in Richtung
# out_dir. Weil jede Zelle damit genau EINEN Ausgang hat, ist der Paketweg
# eindeutig (siehe board.simulate_route). Der Ausgang lässt sich drehen.
#
# tier = Übertaktungsstufe (0 = normal). In der Overclock-Werkstatt lässt sich ein
# Block gegen Geld aufwerten -> stärkerer Effekt. Der Block wird als Instanz durch
# Inventar -> Board -> Inventar gereicht, damit tier und Ausrichtung erhalten
# bleiben.

class_name Block

# Ausgangsrichtung: 0=Nord, 1=Ost, 2=Süd, 3=West.
enum Dir { NORTH, EAST, SOUTH, WEST }

const DELTA := {
	Dir.NORTH: Vector2i(0, -1),
	Dir.EAST:  Vector2i(1, 0),
	Dir.SOUTH: Vector2i(0, 1),
	Dir.WEST:  Vector2i(-1, 0),
}

const DIR_NAMES := {
	Dir.NORTH: "Nord", Dir.EAST: "Ost", Dir.SOUTH: "Süd", Dir.WEST: "West",
}

var type: int      # Component.ComponentType
var out_dir: int   # Dir – wohin das Paket den Block verlässt
var tier: int      # Übertaktungsstufe (0 = normal)


func _init(p_type: int, p_dir: int = Dir.EAST, p_tier: int = 0) -> void:
	type = p_type
	out_dir = p_dir
	tier = p_tier


# Dreht den Ausgang um 90° im/gegen den Uhrzeigersinn.
func rotate_cw() -> void:
	out_dir = (out_dir + 1) % 4

func rotate_ccw() -> void:
	out_dir = (out_dir + 3) % 4


# Versatz (col,row), in den das Paket diesen Block verlässt.
func delta() -> Vector2i:
	return DELTA[out_dir]


static func dir_delta(d: int) -> Vector2i:
	return DELTA.get(d, Vector2i(1, 0))
