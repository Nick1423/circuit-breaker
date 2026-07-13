# Core Cocker - Ein Bauteil-Chip im Inventar-Fach (unten)
#
# Drag-Quelle: zieht ein Bauteil aufs Board. Linksklick wählt es als Fallback
# (klicken statt ziehen). Kein Button, damit die Klick-/Drag-Semantik sauber ist.

class_name InventoryItem
extends PanelContainer

signal picked(index: int)

var item_index: int = -1
var comp_type: int = -1


func _get_drag_data(_at_position: Vector2) -> Variant:
	set_drag_preview(UIStyle.drag_preview(comp_type))
	return {"kind": "inventory", "type": comp_type, "index": item_index}


# Auswahl erst beim LOSLASSEN – ein echter Drag löst auf der Quelle kein Release
# aus, sodass das Neuaufbauen des Fachs die Drag-Quelle nicht mitten im Zug löscht.
func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and not event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		picked.emit(item_index)
