# Circuit Breaker - Konsolen-Eingabe
# Ein Node, der Tastatureingaben abfängt und an den GameManager weiterleitet.

extends Node

@onready var game_manager = $"../GameManager"

var input_buffer: String = ""
var is_active: bool = true


func _unhandled_input(event: InputEvent) -> void:
	if not is_active:
		return
	
	if event is InputEventKey and event.pressed and not event.echo:
		var keycode = event.keycode
		
		# Enter = Befehl ausführen
		if keycode == KEY_ENTER:
			if input_buffer.length() > 0:
				var cmd = input_buffer
				input_buffer = ""
				print("> ", cmd)
				if game_manager:
					game_manager.handle_command(cmd)
			get_viewport().set_input_as_handled()
			return
		
		# Backspace = letztes Zeichen löschen
		if keycode == KEY_BACKSPACE:
			if input_buffer.length() > 0:
				input_buffer = input_buffer.left(input_buffer.length() - 1)
			get_viewport().set_input_as_handled()
			return
		
		# Escape = Buffer leeren
		if keycode == KEY_ESCAPE:
			input_buffer = ""
			get_viewport().set_input_as_handled()
			return
		
		# Space = Leerzeichen
		if keycode == KEY_SPACE:
			input_buffer += " "
			get_viewport().set_input_as_handled()
			return
		
		# Normale Zeichen über Unicode
		if event.unicode > 0:
			var char_str = String.chr(event.unicode)
			# Nur druckbare Zeichen: Buchstaben, Zahlen
			if (char_str >= "a" and char_str <= "z") or \
			   (char_str >= "A" and char_str <= "Z") or \
			   (char_str >= "0" and char_str <= "9"):
				input_buffer += char_str
				get_viewport().set_input_as_handled()
				return