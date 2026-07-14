# Core Cocker - Inventar-System
# Verwaltet gekaufte Bausteine als Block-INSTANZEN (Typ + Übertaktungsstufe), die
# noch nicht auf dem Brett liegen. So bleibt die Overclock-Stufe eines Bausteins
# erhalten, wenn er zwischen Inventar und Board hin- und hergezogen wird.
# RefCounted (kein Node): wird nie in den Szenenbaum gehängt.

class_name Inventory

# Inventar: Liste von Block-Instanzen
var items: Array = []

# Maximale Inventar-Größe (Board hat 30 Felder)
var max_size: int = 30


# Erzeugt einen neuen Baustein (tier 0 wenn nicht anders angegeben) und legt ihn ab.
func add_item(comp_type: int, tier: int = 0) -> bool:
	if items.size() >= max_size:
		return false
	items.append(Block.new(comp_type, Block.Dir.EAST, tier))
	return true


# Legt eine bestehende Block-Instanz ab (behält tier/Ausrichtung).
func add_block(block) -> bool:
	if block == null or items.size() >= max_size:
		return false
	items.append(block)
	return true


# Entfernt und gibt die Block-Instanz zurück (oder null bei ungültigem Index).
func take_item(index: int):
	if index < 0 or index >= items.size():
		return null
	var b = items[index]
	items.remove_at(index)
	return b


# Gibt die Block-Instanz zurück ohne sie zu entfernen (oder null).
func peek_item(index: int):
	if index < 0 or index >= items.size():
		return null
	return items[index]


# Bequemer Zugriff auf den Typ an einem Index (oder -1).
func peek_type(index: int) -> int:
	var b = peek_item(index)
	return b.type if b != null else -1


func get_item_count() -> int:
	return items.size()


func is_empty() -> bool:
	return items.size() == 0
