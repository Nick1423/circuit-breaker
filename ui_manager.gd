# Circuit Breaker - UI-Manager
# Zeigt Homescreen, Status, Shop und Game Over als Text-Overlay

extends Control

const Component = preload("res://component.gd")

var game_manager = null
var message: String = ""
var message_timer: float = 0.0


func _ready() -> void:
	game_manager = $"../GameManager"


func _draw() -> void:
	# Hintergrund
	draw_rect(Rect2(0, 0, get_size().x, get_size().y), Color(0.1, 0.1, 0.12, 1), true)
	
	if game_manager == null:
		return
	
	var gm = game_manager
	var phase = gm.phase
	
	match phase:
		gm.GamePhase.HOMESCREEN:
			_draw_homescreen()
		gm.GamePhase.BUILD:
			_draw_build_phase()
		gm.GamePhase.SEND:
			_draw_send_phase()
		gm.GamePhase.RESULT:
			_draw_result_phase()
		gm.GamePhase.SHOP:
			_draw_shop_phase()
		gm.GamePhase.GAMEOVER:
			_draw_gameover()


func _draw_homescreen() -> void:
	var cx = get_size().x / 2
	var cy = get_size().y / 2
	var font = ThemeDB.fallback_font
	
	draw_string(font, Vector2(cx - 120, cy - 80), "CIRCUIT BREAKER", HORIZONTAL_ALIGNMENT_LEFT, -1, 32, Color(0.3, 0.6, 1.0, 1))
	draw_string(font, Vector2(cx - 100, cy - 40), "Ein Hacker-Platinen-Puzzle", HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color.LIGHT_GRAY)
	draw_string(font, Vector2(cx - 80, cy + 20), "start - Spiel beginnen", HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color.WHITE)
	draw_string(font, Vector2(cx - 80, cy + 45), "quit  - Beenden", HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color.WHITE)


func _draw_build_phase() -> void:
	var font = ThemeDB.fallback_font
	var gm = game_manager
	
	# Obere Leiste
	draw_rect(Rect2(0, 0, get_size().x, 50), Color(0.15, 0.15, 0.18, 1), true)
	
	var top_text = "Runde %d | Geld: %d | Score: %d | Watt: %d/%d" % [
		gm.current_round, gm.money, gm.score,
		gm.board.get_used_watt(), gm.board.watt_budget
	]
	draw_string(font, Vector2(20, 32), top_text, HORIZONTAL_ALIGNMENT_LEFT, -1, 18, Color.WHITE)
	
	# Ausgewähltes Bauteil
	var sel_name = Component.get_type_name(gm.selected_component)
	var sel_watt = Component.get_watt_cost(gm.selected_component)
	draw_string(font, Vector2(20, 75), "Ausgewählt: %s (%dW)" % [sel_name, sel_watt], HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color.LIGHT_GRAY)
	
	# Inventar
	if gm.inventory and gm.inventory.get_item_count() > 0:
		draw_string(font, Vector2(20, 95), "Inventar: %d Bauteile" % gm.inventory.get_item_count(), HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color.LIGHT_GRAY)
	
	# Hinweis
	draw_string(font, Vector2(20, get_size().y - 20), "Linksklick: Platzieren | Rechtsklick: Entfernen | Tastatur: Befehle", 
		HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color.GRAY)


func _draw_send_phase() -> void:
	_draw_build_phase()
	var font = ThemeDB.fallback_font
	draw_string(font, Vector2(20, 120), ">>> PAKETE UNTERWEGS <<<", HORIZONTAL_ALIGNMENT_LEFT, -1, 20, Color.YELLOW)


func _draw_result_phase() -> void:
	var font = ThemeDB.fallback_font
	draw_string(font, Vector2(20, 100), "RUNDE GESCHAFFT!", HORIZONTAL_ALIGNMENT_LEFT, -1, 24, Color.GREEN)


func _draw_shop_phase() -> void:
	var font = ThemeDB.fallback_font
	draw_string(font, Vector2(20, 80), "SHOP", HORIZONTAL_ALIGNMENT_LEFT, -1, 24, Color.YELLOW)
	draw_string(font, Vector2(20, 110), "buy <nr> - Kaufen | next - Nächste Runde", HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color.WHITE)


func _draw_gameover() -> void:
	var cx = get_size().x / 2
	var cy = get_size().y / 2
	var font = ThemeDB.fallback_font
	
	# Hintergrund abdunkeln
	draw_rect(Rect2(0, 0, get_size().x, get_size().y), Color(0, 0, 0, 0.7), true)
	
	draw_string(font, Vector2(cx - 80, cy - 60), "GAME OVER", HORIZONTAL_ALIGNMENT_LEFT, -1, 36, Color(1, 0.3, 0.3, 1))
	
	var gm = game_manager
	draw_string(font, Vector2(cx - 100, cy - 20), "Runde: %d" % gm.current_round, HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color.WHITE)
	draw_string(font, Vector2(cx - 100, cy + 5), "Score: %d" % gm.score, HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color.WHITE)
	
	if gm.score > 0 and gm.score >= gm.highscore:
		draw_string(font, Vector2(cx - 100, cy + 30), "NEUER HIGHSCORE!", HORIZONTAL_ALIGNMENT_LEFT, -1, 18, Color.YELLOW)
	
	draw_string(font, Vector2(cx - 100, cy + 60), "restart - Neustart", HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color.LIGHT_GRAY)
	draw_string(font, Vector2(cx - 100, cy + 80), "menu - Hauptmenü", HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color.LIGHT_GRAY)