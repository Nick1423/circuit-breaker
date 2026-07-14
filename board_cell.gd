# Core Cocker - Eine Zelle des Spielfelds
#
# Ist gleichzeitig Drop-Ziel (Bauteil aus dem Inventar oder ein anderer Block)
# und Drag-Quelle (platzierter Block lässt sich verschieben). Nutzt die nativen
# Godot-Drag&Drop-Virtuals _get_drag_data / _can_drop_data / _drop_data.

class_name BoardCell
extends Panel

signal item_dropped(c: int, r: int, data: Dictionary)

var c: int = -1
var r: int = -1
var has_block: bool = false
var drag_type: int = -1  # Typ des platzierten Blocks (für die Drag-Vorschau)
var drag_tier: int = 0   # Übertaktungsstufe des platzierten Blocks


func _get_drag_data(_at_position: Vector2) -> Variant:
	if not has_block:
		return null
	set_drag_preview(UIStyle.drag_preview(drag_type, drag_tier))
	return {"kind": "board", "from_c": c, "from_r": r}


func _can_drop_data(_at_position: Vector2, data) -> bool:
	return data is Dictionary and data.get("kind", "") in ["inventory", "board"]


func _drop_data(_at_position: Vector2, data) -> void:
	item_dropped.emit(c, r, data)
