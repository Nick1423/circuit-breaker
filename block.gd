# Core Cocker - Block-Instanz auf dem Board
#
# Jeder Block hat einen FESTEN Eingang links und Ausgang rechts. Das Paket fließt
# immer von links nach rechts durch eine Zeile ("Lane"). Es gibt kein Drehen und
# keine Port-Ausrichtung mehr – das macht das Bauen nutzerfreundlich und eindeutig.

class_name Block

var type: int  # Component.ComponentType


func _init(p_type: int) -> void:
	type = p_type
