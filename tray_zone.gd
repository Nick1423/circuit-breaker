# Core Cocker - Ablage-Zone (Inventar-Fach als Drop-Ziel)
#
# Nimmt einen vom Board gezogenen Block entgegen und meldet das per Signal –
# so lässt sich ein platzierter Block per Drag zurück ins Inventar legen.

class_name TrayDropZone
extends PanelContainer

signal block_returned(data: Dictionary)


func _can_drop_data(_at_position: Vector2, data) -> bool:
	return data is Dictionary and data.get("kind", "") == "board"


func _drop_data(_at_position: Vector2, data) -> void:
	block_returned.emit(data)
