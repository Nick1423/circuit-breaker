# Circuit Breaker - Konsolen-Eingabe
# Ein Node, der Tastatureingaben abfängt und an den GameManager weiterleitet.
# Verwendet Keycode-Vergleiche statt Unicode/String-Funktionen für Kompatibilität.

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
		
		# Buchstaben A-Z
		if keycode >= KEY_A and keycode <= KEY_Z:
			if event.shift_pressed:
				input_buffer += char(keycode)
			else:
				input_buffer += char(keycode + 32)  # lowercase
			get_viewport().set_input_as_handled()
			return
		
		# Zahlen 0-9
		if keycode >= KEY_0 and keycode <= KEY_9:
			input_buffer += char(keycode)
			get_viewport().set_input_as_handled()
			return