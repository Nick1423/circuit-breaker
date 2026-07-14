# Core Cocker - Block-Instanz auf dem Board
#
# Jeder Block hat NUR einen Ausgang – keinen festen Eingang. Das Paket tritt aus
# der Nachbarzelle ein, wird verarbeitet und verlässt den Block IMMER in Richtung
# out_dir. Weil jede Zelle damit genau EINEN Ausgang hat, ist der Paketweg
# eindeutig bestimmt (siehe board.simulate_route). Der Ausgang lässt sich drehen.

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


func _init(p_type: int, p_dir: int = Dir.EAST) -> void:
	type = p_type
	out_dir = p_dir


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
