# Core Cocker - Komplette Spiel-UI (Drag & Drop, Lanes, Animation)
#
# Ablauf: Menü -> Shop (kaufen) -> Bau-Phase (Bauteile aus dem Fach unten aufs
# Feld ziehen) -> Pakete senden (animiert) -> Belohnung -> Shop -> ...
#
# Jede Zeile ist eine "Lane": liegt in Spalte 0 ein Block, startet dort ein Paket
# und fließt nach rechts durch die lückenlose Kette. Erreicht es den rechten Rand,
# gibt es einen Durchbruch-Bonus. Mehr/längere Lanes = mehr Schaden, aber mehr
# Hitze. Alles wird über refresh() aus dem GameManager-Zustand aktualisiert.

extends Control

# Component, Block, BoardCell, InventoryItem, TrayDropZone sind über class_name global.

# ---- Stil (Palette & Bau-Helfer stehen in ui_style.gd) ----
const Style = preload("res://ui_style.gd")
const C_BG      = Style.BG
const C_PANEL   = Style.PANEL
const C_PANEL2  = Style.PANEL2
const C_ACCENT  = Style.ACCENT
const C_ACCENT2 = Style.ACCENT2
const C_DANGER  = Style.DANGER
const C_WARN    = Style.WARN
const C_TEXT    = Style.TEXT
const C_MUTED   = Style.MUTED
const C_CELL    = Style.CELL
const COMP_COLORS = Style.COMP_COLORS

const CELL_SIZE := 90
const STEP_TIME := 0.30   # Zeit pro Feld beim Paket-Lauf (langsam & lesbar)
const HOLD_TIME := 0.20   # kurze Pause, wenn der Wert steigt

var gm = null

# Screens
var menu_root: Control
var game_root: Control
var shop_root: Control
var over_root: Control
var reward_root: Control

# HUD
var lbl_round: Label
var lbl_money: Label
var lbl_score: Label
var fw_panel: PanelContainer
var fw_title: Label
var fw_mod: Label
var fw_bar: ProgressBar
var fw_hp: Label
var heat_bar: ProgressBar
var heat_lbl: Label
var msg_lbl: Label
var send_btn: Button

# Board
var board_area: Control
var rail_overlay: Control     # zeichnet Schienen/Sockel HINTER den Zellen
var wire_overlay: Control     # zeichnet Kabel/Nubs VOR den Zellen
var cell_root := []           # [row][col] -> BoardCell
var cell_char := []           # [row][col] -> Label
var lane_chip := []           # [row] -> Label (Schadenszahl am rechten Rand)

# Inventar-Fach (unten)
var tray_box: HBoxContainer
var inv_sell_btn: Button

# Shop
var shop_money: Label
var shop_offers: VBoxContainer
var shop_reroll_btn: Button
var shop_next_btn: Button
var shop_relics_lbl: Label

# Belohnung
var reward_cards: HBoxContainer

# Game Over
var over_round: Label
var over_score: Label
var over_high: Label

# Menü
var menu_high: Label
var preview_lbl: Label

# Zustand
var selected_inv_index := -1
var _animating := false
# Vorschau beim Bauen
var _powered := {}            # Vector2i -> true (Zelle ist Teil einer aktiven Lane)
var _lane_by_row := {}        # row -> Lane-Dictionary (aus compute_send)
var _orphan_cells := {}       # Vector2i -> true (belegt, aber ohne Strom)
var _hint_start := false      # noch keine aktive Lane -> Spalte 0 einladen


func _ready() -> void:
	gm = get_node_or_null("../GameManager")
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_build_background()
	_build_menu()
	_build_game()
	_build_shop()
	_build_reward()
	_build_over()
	refresh()


# Tastatur: Leertaste/Enter = Pakete senden.
func _unhandled_input(event: InputEvent) -> void:
	if gm == null or not (event is InputEventKey) or not event.pressed or event.echo:
		return
	match event.keycode:
		KEY_SPACE, KEY_ENTER, KEY_KP_ENTER:
			if gm.phase == gm.GamePhase.BUILD and not _animating:
				_on_send()
				get_viewport().set_input_as_handled()


# =============================================================
#  STYLE-HELFER
# =============================================================

func _sb(bg: Color, border_col := Color(0,0,0,0), border_w := 0, radius := 8, pad := 8) -> StyleBoxFlat:
	return Style.sb(bg, border_col, border_w, radius, pad)

func _panel(bg := C_PANEL, border := C_PANEL2, bw := 1, radius := 10) -> PanelContainer:
	return Style.panel(bg, border, bw, radius)

func _label(text := "", fsize := 16, col := C_TEXT) -> Label:
	return Style.label(text, fsize, col)

func _style_button(btn: Button, base: Color, txt := C_TEXT) -> void:
	Style.style_button(btn, base, txt)

func _make_bar(fill: Color) -> ProgressBar:
	return Style.make_bar(fill)

func _full(node: Control) -> void:
	node.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

func _build_background() -> void:
	var bg := ColorRect.new()
	bg.color = C_BG
	_full(bg)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bg)


# =============================================================
#  HAUPTMENÜ
# =============================================================

func _build_menu() -> void:
	menu_root = Control.new()
	_full(menu_root)
	add_child(menu_root)

	var center := CenterContainer.new()
	_full(center)
	menu_root.add_child(center)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 16)
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	center.add_child(box)

	var title := _label(">> CORE COCKER <<", 46, C_ACCENT)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(title)

	var sub := _label("Baue Schaltungs-Lanes, leite die Pakete, knacke endlose Firewalls.", 17, C_MUTED)
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(sub)

	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(0, 16)
	box.add_child(spacer)

	var play := Button.new()
	play.text = ">  SPIELEN"
	play.custom_minimum_size = Vector2(280, 56)
	play.add_theme_font_size_override("font_size", 22)
	_style_button(play, C_ACCENT2.darkened(0.35))
	play.pressed.connect(_on_play)
	box.add_child(play)

	var quit := Button.new()
	quit.text = "Beenden"
	quit.custom_minimum_size = Vector2(280, 44)
	quit.add_theme_font_size_override("font_size", 18)
	_style_button(quit, C_PANEL2)
	quit.pressed.connect(func(): get_tree().quit())
	box.add_child(quit)

	menu_high = _label("", 16, C_WARN)
	menu_high.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(menu_high)


# =============================================================
#  SPIEL-SCREEN
# =============================================================

func _build_game() -> void:
	game_root = Control.new()
	_full(game_root)
	add_child(game_root)

	var margin := MarginContainer.new()
	_full(margin)
	for m in ["margin_left", "margin_right", "margin_top", "margin_bottom"]:
		margin.add_theme_constant_override(m, 18)
	game_root.add_child(margin)

	var root_v := VBoxContainer.new()
	root_v.add_theme_constant_override("separation", 12)
	margin.add_child(root_v)

	# Top-Bar
	var topbar := _panel(C_PANEL, C_ACCENT.darkened(0.3), 1, 10)
	root_v.add_child(topbar)
	var top_h := HBoxContainer.new()
	top_h.add_theme_constant_override("separation", 20)
	topbar.add_child(top_h)
	top_h.add_child(_label("CORE COCKER", 20, C_ACCENT))
	var tsp := Control.new()
	tsp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top_h.add_child(tsp)
	lbl_round = _label("Vorbereitung", 18, C_TEXT)
	lbl_money = _label("Geld: 0", 18, C_WARN)
	lbl_score = _label("Score: 0", 18, C_ACCENT2)
	top_h.add_child(lbl_round)
	top_h.add_child(_label("|", 16, C_MUTED))
	top_h.add_child(lbl_money)
	top_h.add_child(_label("|", 16, C_MUTED))
	top_h.add_child(lbl_score)
	var menu_btn := Button.new()
	menu_btn.text = "Menü"
	menu_btn.add_theme_font_size_override("font_size", 15)
	_style_button(menu_btn, C_PANEL2)
	menu_btn.pressed.connect(func(): gm.show_homescreen())
	top_h.add_child(menu_btn)

	# Mitte: LINKS Board-Bereich, RECHTS Vorschau/Senden/Meldung
	var mid := HBoxContainer.new()
	mid.add_theme_constant_override("separation", 16)
	mid.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root_v.add_child(mid)

	var left := VBoxContainer.new()
	left.add_theme_constant_override("separation", 12)
	left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	mid.add_child(left)

	# Firewall
	fw_panel = _panel(C_PANEL, C_DANGER.darkened(0.3), 1, 10)
	left.add_child(fw_panel)
	var fw_v := VBoxContainer.new()
	fw_v.add_theme_constant_override("separation", 6)
	fw_panel.add_child(fw_v)
	var fw_top := HBoxContainer.new()
	fw_title = _label("FIREWALL", 17, C_DANGER)
	fw_top.add_child(fw_title)
	var fwsp := Control.new()
	fwsp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	fw_top.add_child(fwsp)
	fw_mod = _label("", 14, C_WARN)
	fw_top.add_child(fw_mod)
	fw_v.add_child(fw_top)
	fw_bar = _make_bar(C_DANGER)
	fw_bar.custom_minimum_size = Vector2(0, 24)
	fw_v.add_child(fw_bar)
	fw_hp = _label("", 13, C_MUTED)
	fw_v.add_child(fw_hp)

	# Board-Bereich (Rail-Overlay | Grid | Wire-Overlay | Lane-Chips)
	board_area = Control.new()
	board_area.size_flags_vertical = Control.SIZE_EXPAND_FILL
	board_area.custom_minimum_size = Vector2(640, 400)
	left.add_child(board_area)

	rail_overlay = Control.new()
	rail_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_full(rail_overlay)
	rail_overlay.draw.connect(_draw_rails)
	board_area.add_child(rail_overlay)

	var board_center := CenterContainer.new()
	_full(board_center)
	board_center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	board_area.add_child(board_center)
	var grid := GridContainer.new()
	grid.columns = 6
	grid.add_theme_constant_override("h_separation", 8)
	grid.add_theme_constant_override("v_separation", 8)
	board_center.add_child(grid)
	_build_cells(grid)

	wire_overlay = Control.new()
	wire_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_full(wire_overlay)
	wire_overlay.draw.connect(_draw_wires)
	board_area.add_child(wire_overlay)

	lane_chip.clear()
	for r in range(4):
		var chip := _label("", 15, C_ACCENT2)
		chip.mouse_filter = Control.MOUSE_FILTER_IGNORE
		chip.z_index = 5
		board_area.add_child(chip)
		lane_chip.append(chip)

	# Hitze
	var heat_panel := _panel(C_PANEL, C_PANEL2, 1, 10)
	left.add_child(heat_panel)
	var heat_v := VBoxContainer.new()
	heat_panel.add_child(heat_v)
	heat_lbl = _label("Hitze 0/7", 14, C_WARN)
	heat_v.add_child(heat_lbl)
	heat_bar = _make_bar(C_WARN)
	heat_v.add_child(heat_bar)

	# RECHTS: Vorschau + Senden + Meldung
	var right := VBoxContainer.new()
	right.add_theme_constant_override("separation", 12)
	right.custom_minimum_size = Vector2(300, 0)
	mid.add_child(right)

	var prev_panel := _panel(C_PANEL, C_ACCENT2.darkened(0.4), 1, 10)
	right.add_child(prev_panel)
	var prev_v := VBoxContainer.new()
	prev_v.add_theme_constant_override("separation", 4)
	prev_panel.add_child(prev_v)
	prev_v.add_child(_label("VORSCHAU", 14, C_ACCENT2))
	preview_lbl = _label("", 14, C_TEXT)
	preview_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	preview_lbl.custom_minimum_size = Vector2(0, 66)
	prev_v.add_child(preview_lbl)

	send_btn = Button.new()
	send_btn.text = ">  PAKETE SENDEN  (Leertaste)"
	send_btn.custom_minimum_size = Vector2(0, 60)
	send_btn.add_theme_font_size_override("font_size", 20)
	_style_button(send_btn, C_ACCENT2.darkened(0.35))
	send_btn.pressed.connect(_on_send)
	right.add_child(send_btn)

	var msg_panel := _panel(Color(0.08,0.09,0.12), C_PANEL2, 1, 10)
	msg_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	right.add_child(msg_panel)
	msg_lbl = _label("Zieh Bauteile aus dem Fach unten in die Zeilen. Fülle eine Zeile bis zum rechten Rand für den Durchbruch-Bonus.", 14, C_MUTED)
	msg_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	msg_lbl.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	msg_panel.add_child(msg_lbl)

	# UNTEN: Inventar-Fach (Drag-Quelle + Ablage zum Zurücklegen)
	var tray_panel := TrayDropZone.new()
	tray_panel.add_theme_stylebox_override("panel", _sb(C_PANEL, C_ACCENT.darkened(0.4), 1, 10, 10))
	tray_panel.custom_minimum_size = Vector2(0, 104)
	tray_panel.block_returned.connect(_on_tray_drop)
	root_v.add_child(tray_panel)
	var tray_v := VBoxContainer.new()
	tray_v.add_theme_constant_override("separation", 6)
	tray_panel.add_child(tray_v)
	var tray_head := HBoxContainer.new()
	tray_head.add_theme_constant_override("separation", 12)
	tray_v.add_child(tray_head)
	tray_head.add_child(_label("INVENTAR", 15, C_ACCENT))
	tray_head.add_child(_label("Chip aufs Feld ziehen · Rechtsklick auf Block = zurück · Block auf einen anderen ziehen = tauschen", 12, C_MUTED))
	var thsp := Control.new()
	thsp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tray_head.add_child(thsp)
	inv_sell_btn = Button.new()
	inv_sell_btn.text = "Auswahl verkaufen"
	inv_sell_btn.add_theme_font_size_override("font_size", 12)
	_style_button(inv_sell_btn, C_PANEL2)
	inv_sell_btn.pressed.connect(_on_sell)
	tray_head.add_child(inv_sell_btn)
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(0, 62)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	tray_v.add_child(scroll)
	tray_box = HBoxContainer.new()
	tray_box.add_theme_constant_override("separation", 8)
	scroll.add_child(tray_box)


func _build_cells(grid: GridContainer) -> void:
	cell_root.clear(); cell_char.clear()
	for r in range(4):
		var rr := []; var rc := []
		for c in range(6):
			var cell := BoardCell.new()
			cell.c = c
			cell.r = r
			cell.custom_minimum_size = Vector2(CELL_SIZE, CELL_SIZE)
			cell.item_dropped.connect(_on_cell_drop)
			cell.gui_input.connect(_on_cell_input.bind(c, r))

			var char_lbl := Label.new()
			_full(char_lbl)
			char_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			char_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
			char_lbl.add_theme_font_size_override("font_size", 15)
			char_lbl.add_theme_color_override("font_color", Color.WHITE)
			char_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
			cell.add_child(char_lbl)

			grid.add_child(cell)
			rr.append(cell); rc.append(char_lbl)
		cell_root.append(rr); cell_char.append(rc)


# =============================================================
#  SHOP-OVERLAY
# =============================================================

func _build_shop() -> void:
	shop_root = Control.new()
	_full(shop_root)
	add_child(shop_root)
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.6)
	_full(dim)
	shop_root.add_child(dim)
	var center := CenterContainer.new()
	_full(center)
	shop_root.add_child(center)
	var panel := _panel(C_PANEL, C_ACCENT.darkened(0.2), 2, 14)
	panel.custom_minimum_size = Vector2(560, 500)
	center.add_child(panel)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 12)
	panel.add_child(v)
	var head := HBoxContainer.new()
	head.add_child(_label("SHOP", 26, C_ACCENT))
	var sp := Control.new()
	sp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(sp)
	shop_money = _label("Geld: 0", 20, C_WARN)
	head.add_child(shop_money)
	v.add_child(head)
	v.add_child(_label("Gekaufte Bausteine landen im Inventar-Fach.", 14, C_MUTED))
	shop_offers = VBoxContainer.new()
	shop_offers.add_theme_constant_override("separation", 8)
	shop_offers.size_flags_vertical = Control.SIZE_EXPAND_FILL
	v.add_child(shop_offers)

	shop_relics_lbl = _label("", 13, C_ACCENT2)
	shop_relics_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(shop_relics_lbl)

	var btn_row := HBoxContainer.new()
	btn_row.add_theme_constant_override("separation", 10)
	v.add_child(btn_row)
	shop_reroll_btn = Button.new()
	shop_reroll_btn.custom_minimum_size = Vector2(0, 50)
	shop_reroll_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	shop_reroll_btn.add_theme_font_size_override("font_size", 16)
	_style_button(shop_reroll_btn, C_PANEL2)
	shop_reroll_btn.pressed.connect(_on_reroll)
	btn_row.add_child(shop_reroll_btn)
	shop_next_btn = Button.new()
	shop_next_btn.text = "Weiter  >"
	shop_next_btn.custom_minimum_size = Vector2(0, 50)
	shop_next_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	shop_next_btn.add_theme_font_size_override("font_size", 18)
	_style_button(shop_next_btn, C_ACCENT2.darkened(0.35))
	shop_next_btn.pressed.connect(_on_next)
	btn_row.add_child(shop_next_btn)


# =============================================================
#  BELOHNUNGS-OVERLAY
# =============================================================

func _build_reward() -> void:
	reward_root = Control.new()
	_full(reward_root)
	add_child(reward_root)
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.72)
	_full(dim)
	reward_root.add_child(dim)
	var center := CenterContainer.new()
	_full(center)
	reward_root.add_child(center)
	var panel := _panel(C_PANEL, C_ACCENT2.darkened(0.2), 2, 14)
	center.add_child(panel)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 14)
	panel.add_child(v)
	var t := _label("LEVEL GESCHAFFT — wähle ein Upgrade", 24, C_ACCENT2)
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(t)
	reward_cards = HBoxContainer.new()
	reward_cards.add_theme_constant_override("separation", 12)
	v.add_child(reward_cards)

func _refresh_reward() -> void:
	for c in reward_cards.get_children():
		reward_cards.remove_child(c)
		c.queue_free()
	for i in range(gm.reward_choices.size()):
		var r = gm.reward_choices[i]
		var card := _panel(C_PANEL2, C_ACCENT2.darkened(0.3), 1, 10)
		card.custom_minimum_size = Vector2(210, 0)
		var cv := VBoxContainer.new()
		cv.add_theme_constant_override("separation", 10)
		card.add_child(cv)
		cv.add_child(_label(gm.reward_name(r), 18, C_ACCENT2))
		var desc := _label(gm.reward_desc(r), 14, C_TEXT)
		desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		desc.custom_minimum_size = Vector2(186, 60)
		cv.add_child(desc)
		var pick := Button.new()
		pick.text = "Wählen"
		pick.custom_minimum_size = Vector2(0, 42)
		pick.add_theme_font_size_override("font_size", 16)
		_style_button(pick, C_ACCENT2.darkened(0.35))
		pick.pressed.connect(_on_reward_pick.bind(i))
		cv.add_child(pick)
		reward_cards.add_child(card)


# =============================================================
#  GAME-OVER-OVERLAY
# =============================================================

func _build_over() -> void:
	over_root = Control.new()
	_full(over_root)
	add_child(over_root)
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.78)
	_full(dim)
	over_root.add_child(dim)
	var center := CenterContainer.new()
	_full(center)
	over_root.add_child(center)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 14)
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	center.add_child(box)
	var title := _label("GAME OVER", 44, C_DANGER)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(title)
	over_round = _label("", 20, C_TEXT)
	over_round.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(over_round)
	over_score = _label("", 22, C_ACCENT2)
	over_score.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(over_score)
	over_high = _label("", 18, C_WARN)
	over_high.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(over_high)
	var sp := Control.new()
	sp.custom_minimum_size = Vector2(0, 14)
	box.add_child(sp)
	var again := Button.new()
	again.text = "Nochmal"
	again.custom_minimum_size = Vector2(260, 50)
	again.add_theme_font_size_override("font_size", 20)
	_style_button(again, C_ACCENT2.darkened(0.35))
	again.pressed.connect(_on_play)
	box.add_child(again)
	var menu := Button.new()
	menu.text = "Hauptmenü"
	menu.custom_minimum_size = Vector2(260, 42)
	menu.add_theme_font_size_override("font_size", 17)
	_style_button(menu, C_PANEL2)
	menu.pressed.connect(func(): gm.show_homescreen())
	box.add_child(menu)


# =============================================================
#  SIGNAL-HANDLER
# =============================================================

func _on_play() -> void:
	selected_inv_index = -1
	gm.start_new_run()
	refresh()

func _on_next() -> void:
	if gm.phase == gm.GamePhase.SHOP:
		selected_inv_index = -1
		gm.advance_from_shop()
		refresh()

func _on_buy(index: int) -> void:
	gm.buy_component(index)
	refresh()

func _on_reroll() -> void:
	gm.reroll_shop()
	refresh()

func _on_sell() -> void:
	if selected_inv_index >= 0:
		gm.sell_item(selected_inv_index)
		selected_inv_index = -1
	else:
		_set_msg("Wähle zuerst ein Inventar-Item (anklicken).")
	refresh()

func _on_reward_pick(index: int) -> void:
	gm.choose_reward(index)
	refresh()

func _on_inv_select(index: int) -> void:
	selected_inv_index = index
	refresh()

# Klick-Fallback auf eine Zelle (Ziehen ist der Hauptweg).
func _on_cell_input(event: InputEvent, c: int, r: int) -> void:
	if _animating or gm.phase != gm.GamePhase.BUILD:
		return
	if not (event is InputEventMouseButton) or not event.pressed:
		return
	var block = gm.board.get_block(c, r)
	if event.button_index == MOUSE_BUTTON_LEFT:
		if block == null:
			_try_place(c, r)
	elif event.button_index == MOUSE_BUTTON_RIGHT:
		if block != null:
			_return_block(c, r)

# Drop auf eine Zelle: platzieren (Inventar), verschieben oder tauschen (Board).
func _on_cell_drop(c: int, r: int, data: Dictionary) -> void:
	if gm.phase != gm.GamePhase.BUILD:
		return
	match data.get("kind", ""):
		"inventory":
			var idx: int = int(data.get("index", -1))
			if idx < 0 or idx >= gm.inventory.get_item_count():
				return
			var t: int = gm.inventory.peek_item(idx)
			if gm.board.place_component(c, r, t):
				gm.inventory.take_item(idx)
				gm.stats.components_placed += 1
				selected_inv_index = -1
			else:
				_set_msg("Feld ist belegt.")
		"board":
			var fc: int = int(data.get("from_c", -1))
			var fr: int = int(data.get("from_r", -1))
			if fc == c and fr == r:
				return
			if gm.board.get_block(c, r) == null:
				var b = gm.board.remove_component(fc, fr)
				if b >= 0:
					gm.board.place_component(c, r, b)
			else:
				gm.board.swap_blocks(fc, fr, c, r)
	refresh()

# Drop aufs Inventar-Fach: platzierten Block zurücklegen.
func _on_tray_drop(data: Dictionary) -> void:
	if gm.phase != gm.GamePhase.BUILD:
		return
	var fc: int = int(data.get("from_c", -1))
	var fr: int = int(data.get("from_r", -1))
	_return_block(fc, fr)

func _return_block(c: int, r: int) -> void:
	var t = gm.board.remove_component(c, r)
	if t >= 0 and gm.inventory:
		gm.inventory.add_item(t)
		_set_msg("Zurück ins Inventar: %s" % Component.get_type_name(t))
	refresh()

func _try_place(c: int, r: int) -> void:
	if gm.inventory == null or selected_inv_index < 0:
		_set_msg("Wähle ein Bauteil (anklicken) oder zieh es direkt aufs Feld.")
		return
	if selected_inv_index >= gm.inventory.get_item_count():
		selected_inv_index = -1
		refresh()
		return
	var t = gm.inventory.peek_item(selected_inv_index)
	if gm.board.place_component(c, r, t):
		gm.inventory.take_item(selected_inv_index)
		gm.stats.components_placed += 1
		selected_inv_index = -1
		_set_msg("Platziert: %s." % Component.get_type_name(t))
	else:
		_set_msg("Dieses Feld ist belegt.")
	refresh()

func _set_msg(t: String) -> void:
	if msg_lbl:
		msg_lbl.text = t


# =============================================================
#  SENDEN + ANIMATION
# =============================================================

func _on_send() -> void:
	if _animating or gm.phase != gm.GamePhase.BUILD:
		return
	var res = gm.compute_send()
	_animating = true
	send_btn.disabled = true
	await _play_send(res)
	_animating = false
	gm.apply_send(res)
	refresh()


func _play_send(res: Dictionary) -> void:
	var lanes := []
	for lr in res.get("lanes", []):
		if not lr.jammed and not lr.path.is_empty():
			lanes.append(lr)
	var total := int(res.get("total_damage", 0))
	if lanes.is_empty():
		_set_msg("Keine aktive Lane – zieh Bauteile in Spalte 1 einer Zeile.")
		await get_tree().create_timer(0.4).timeout
		return
	var shares := _proportional_shares(lanes, total)
	_set_msg("%d Paket(e) unterwegs …" % lanes.size())

	# Alle Lanes gleichzeitig loslaufen lassen (Koroutinen ohne await starten).
	var done := [0]
	for i in range(lanes.size()):
		_animate_lane(lanes[i], shares[i], done)
	while done[0] < lanes.size():
		await get_tree().process_frame

	# Gesamtschaden auf einmal abziehen + Firewall-Punch/Shake.
	if fw_bar:
		var target_hp = max(0.0, fw_bar.value - total)
		_shake(clampf(3.0 + total * 0.02, 3.0, 16.0))
		fw_bar.pivot_offset = fw_bar.size / 2.0
		var punch := create_tween()
		punch.tween_property(fw_bar, "scale", Vector2(1.05, 1.25), 0.06)
		punch.tween_property(fw_bar, "scale", Vector2.ONE, 0.16)
		if fw_panel:
			var flash := create_tween()
			flash.tween_property(fw_panel, "modulate", Color(1.6, 1.2, 1.2), 0.06)
			flash.tween_property(fw_panel, "modulate", Color(1, 1, 1), 0.2)
		var hpt := create_tween()
		hpt.tween_property(fw_bar, "value", target_hp, 0.35).set_trans(Tween.TRANS_CUBIC)
		await hpt.finished


# Eine Lane: Paket läuft langsam die Kette entlang (Wert rollt hoch), fliegt dann
# in die Firewall. Läuft als Koroutine parallel zu den anderen Lanes.
func _animate_lane(lr: Dictionary, share: int, done: Array) -> void:
	var path: Array = lr.path
	var token := _make_packet_token(int(path[0].before))
	add_child(token)
	var lbl: Label = token.get_child(0)
	token.global_position = _cell_center(path[0].col, path[0].row) - token.size / 2.0

	for step in path:
		var target = _cell_center(step.col, step.row) - token.size / 2.0
		var mt := create_tween()
		mt.tween_property(token, "global_position", target, STEP_TIME).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		await mt.finished
		if int(step.after) > int(step.before):
			var roll := create_tween()
			roll.tween_method(func(v): lbl.text = str(int(v)), float(step.before), float(step.after), 0.25).set_ease(Tween.EASE_OUT)
			var pop := create_tween()
			pop.tween_property(lbl, "scale", Vector2(1.3, 1.3), 0.09)
			pop.tween_property(lbl, "scale", Vector2.ONE, 0.09)
			_spawn_float("+%d" % (int(step.after) - int(step.before)), _cell_center(step.col, step.row), C_ACCENT2)
			await get_tree().create_timer(HOLD_TIME).timeout
		else:
			lbl.text = str(int(step.after))

	if lr.reached_end:
		var last = path[path.size() - 1]
		_spawn_float("Durchbruch!", _cell_center(last.col, last.row) + Vector2(0, -24), C_ACCENT)

	lbl.text = str(share)
	var bt := create_tween()
	bt.tween_property(token, "scale", Vector2(1.3, 1.3), 0.08)
	bt.tween_property(token, "scale", Vector2.ONE, 0.08)
	await bt.finished

	if fw_bar:
		var fw_target = fw_bar.global_position + fw_bar.size / 2.0 - token.size / 2.0
		var ft := create_tween()
		ft.tween_property(token, "global_position", fw_target, 0.22).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
		await ft.finished
		_spawn_float("-%d" % share, fw_bar.global_position + Vector2(fw_bar.size.x * 0.5, -8), C_DANGER)
	token.queue_free()
	done[0] += 1


# Verteilt total gewichtet nach Lane-Schaden auf die Lanes (Summe = total).
func _proportional_shares(lanes: Array, total: int) -> Array:
	var weights := []
	var sumw := 0
	for lr in lanes:
		var w = max(0, int(lr.damage))
		weights.append(w)
		sumw += w
	var shares := []
	if sumw <= 0:
		@warning_ignore("integer_division")
		var base = total / lanes.size()
		for i in range(lanes.size()):
			shares.append(base)
		for i in range(total - base * lanes.size()):
			shares[i] += 1
		return shares
	var assigned := 0
	for i in range(lanes.size()):
		var s = int(round(float(weights[i]) / float(sumw) * total))
		shares.append(s)
		assigned += s
	if not shares.is_empty():
		shares[0] = max(0, shares[0] + (total - assigned))
	return shares


func _cell_center(c: int, r: int) -> Vector2:
	var node: Control = cell_root[r][c]
	return node.global_position + node.size / 2.0

func _make_packet_token(val: int) -> Panel:
	var p := Panel.new()
	p.custom_minimum_size = Vector2(48, 48)
	p.size = Vector2(48, 48)
	p.pivot_offset = Vector2(24, 24)
	p.add_theme_stylebox_override("panel", _sb(C_ACCENT, Color.WHITE, 2, 24, 0))
	p.z_index = 100
	var l := Label.new()
	_full(l)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	l.add_theme_font_size_override("font_size", 18)
	l.add_theme_color_override("font_color", Color.BLACK)
	l.pivot_offset = Vector2(24, 24)
	l.text = str(val)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	p.add_child(l)
	return p

func _spawn_float(text: String, gpos: Vector2, col: Color) -> void:
	var l := _label(text, 20, col)
	l.z_index = 101
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(l)
	l.global_position = gpos
	var t := create_tween()
	t.tween_property(l, "global_position:y", gpos.y - 38, 0.6)
	t.parallel().tween_property(l, "modulate:a", 0.0, 0.6)
	t.tween_callback(l.queue_free)

func _shake(amount: float) -> void:
	if game_root == null:
		return
	var t := create_tween()
	for i in range(4):
		t.tween_property(game_root, "position", Vector2(randf_range(-amount, amount), randf_range(-amount, amount)), 0.03)
	t.tween_property(game_root, "position", Vector2.ZERO, 0.05)


# =============================================================
#  REFRESH
# =============================================================

func refresh() -> void:
	if gm == null or menu_root == null:
		return
	# Während eines laufenden Drags nicht neu aufbauen (würde die Drag-Quelle löschen).
	if is_inside_tree() and get_viewport().gui_is_dragging():
		return

	var phase = gm.phase
	var in_menu = phase == gm.GamePhase.HOMESCREEN
	menu_root.visible = in_menu
	game_root.visible = not in_menu
	shop_root.visible = phase == gm.GamePhase.SHOP
	over_root.visible = phase == gm.GamePhase.GAMEOVER
	reward_root.visible = phase == gm.GamePhase.REWARD

	if in_menu:
		var hs := []
		if gm.highscore > 0:
			hs.append("Highscore: %d" % gm.highscore)
		if gm.best_level > 0:
			hs.append("Bestes Level: %d" % gm.best_level)
		menu_high.text = "   ".join(hs)
		return

	# Lane-/Vorschau-Daten (nur beim Bauen)
	_powered = {}
	_lane_by_row = {}
	_orphan_cells = {}
	_hint_start = false
	if phase == gm.GamePhase.BUILD:
		var res = gm.compute_send()
		for lr in res.lanes:
			_lane_by_row[lr.row] = lr
			for step in lr.path:
				_powered[Vector2i(step.col, step.row)] = true
		for rr in range(4):
			for cc in range(6):
				if gm.board.get_block(cc, rr) != null and not _powered.has(Vector2i(cc, rr)):
					_orphan_cells[Vector2i(cc, rr)] = true
		_hint_start = res.lanes.is_empty()
		_update_preview_label(res)
	else:
		if preview_lbl:
			preview_lbl.text = ""

	# HUD
	lbl_round.text = ("Vorbereitung" if gm.level == 0 else "Level %d  •  Runde %d/%d" % [gm.level, gm.round_in_level, gm.ROUNDS_PER_LEVEL])
	lbl_money.text = "Geld: %d" % gm.money
	lbl_score.text = "Score: %d" % gm.score

	# Firewall
	if gm.firewall:
		var fw = gm.firewall
		fw_title.text = "FIREWALL  Level %d" % fw.level
		fw_bar.max_value = max(1, fw.max_health)
		fw_bar.value = fw.health
		fw_hp.text = "%d / %d HP" % [fw.health, fw.max_health]
		fw_mod.text = ("! %s" % fw.modifier_label) if fw.has_modifier() else ""
	else:
		fw_title.text = "FIREWALL"
		fw_bar.max_value = 1
		fw_bar.value = 0
		fw_hp.text = "- noch keine Runde -"
		fw_mod.text = ""

	_refresh_cells()
	_refresh_lane_chips()

	# Hitze
	var heat = gm.board.get_total_heat()
	var hlimit = gm.effective_heat_limit()
	heat_bar.max_value = max(1, hlimit)
	heat_bar.value = min(heat, hlimit)
	if heat > hlimit:
		heat_lbl.text = "Hitze  %d / %d   ! ÜBERHITZT" % [heat, hlimit]
		heat_lbl.add_theme_color_override("font_color", C_DANGER)
		heat_bar.add_theme_stylebox_override("fill", _sb(C_DANGER, Color(0,0,0,0), 0, 6, 0))
	else:
		heat_lbl.text = "Hitze  %d / %d" % [heat, hlimit]
		heat_lbl.add_theme_color_override("font_color", C_WARN)
		heat_bar.add_theme_stylebox_override("fill", _sb(C_WARN, Color(0,0,0,0), 0, 6, 0))

	_refresh_tray()
	send_btn.disabled = phase != gm.GamePhase.BUILD

	if gm.get("ui_message") != null and gm.ui_message != "":
		_set_msg(gm.ui_message)

	if phase == gm.GamePhase.SHOP:
		_refresh_shop()
	if phase == gm.GamePhase.REWARD:
		_refresh_reward()
	if phase == gm.GamePhase.GAMEOVER:
		over_round.text = "Erreichtes Level: %d" % gm.level
		over_score.text = "Score: %d" % gm.score
		over_high.text = ("* NEUER HIGHSCORE *" if (gm.score >= gm.highscore and gm.score > 0) else "Highscore: %d  •  Bestes Level: %d" % [gm.highscore, gm.best_level])

	rail_overlay.queue_redraw()
	wire_overlay.queue_redraw()


func _update_preview_label(res: Dictionary) -> void:
	if preview_lbl == null:
		return
	var lanes: Array = res.get("lanes", [])
	if lanes.is_empty():
		preview_lbl.add_theme_color_override("font_color", C_WARN)
		preview_lbl.text = "Zieh ein Bauteil in Spalte 1 einer Zeile, um eine Lane zu starten."
		return
	var packets = int(res.get("packets", 0))
	var dmg = int(res.get("total_damage", 0))
	var oh = "  •  ÜBERHITZT" if res.get("overheated", false) else ""
	var win = gm.firewall != null and dmg >= gm.firewall.health
	var verdict = "reicht zum Knacken" if win else "reicht NICHT"
	preview_lbl.text = "%d Lane(s) → %d Schaden%s\n%s (Firewall: %d HP)" % [packets, dmg, oh, verdict, (gm.firewall.health if gm.firewall else 0)]
	preview_lbl.add_theme_color_override("font_color", C_ACCENT2 if win else C_DANGER)


func _refresh_cells() -> void:
	for r in range(4):
		for c in range(6):
			var cell: BoardCell = cell_root[r][c]
			var char_lbl: Label = cell_char[r][c]
			var b = gm.board.get_block(c, r)
			cell.has_block = b != null
			cell.drag_type = b.type if b != null else -1
			if b == null:
				if _hint_start and c == 0:
					cell.add_theme_stylebox_override("panel", _sb(C_CELL, C_ACCENT2, 2, 8, 0))
					char_lbl.text = "+"
					char_lbl.add_theme_color_override("font_color", Color(C_ACCENT2.r, C_ACCENT2.g, C_ACCENT2.b, 0.55))
				else:
					cell.add_theme_stylebox_override("panel", _sb(C_CELL, Color(1,1,1,0.06), 1, 8, 0))
					char_lbl.text = ""
			else:
				var col: Color = COMP_COLORS.get(b.type, C_PANEL2)
				var powered: bool = _powered.has(Vector2i(c, r))
				var border: Color = col.lightened(0.3) if powered else C_MUTED.darkened(0.1)
				var bw := 3 if powered else 2
				var bg: Color = col.darkened(0.1) if powered else col.darkened(0.45)
				cell.add_theme_stylebox_override("panel", _sb(bg, border, bw, 8, 0))
				char_lbl.add_theme_color_override("font_color", Color.WHITE if powered else Color(1,1,1,0.5))
				char_lbl.text = "%s\n%s" % [Component.get_short_name(b.type), Component.get_label(b.type)]


func _refresh_lane_chips() -> void:
	for r in range(4):
		var chip: Label = lane_chip[r]
		if not _lane_by_row.has(r) or cell_root.is_empty():
			chip.visible = false
			continue
		var lr = _lane_by_row[r]
		var cell: Control = cell_root[r][5]
		chip.visible = true
		chip.global_position = cell.global_position + Vector2(cell.size.x + 18, cell.size.y / 2.0 - 12)
		if lr.jammed:
			chip.text = "JAM"
			chip.add_theme_color_override("font_color", C_DANGER)
		elif lr.reached_end:
			chip.text = "%d ⚡" % int(lr.damage)
			chip.add_theme_color_override("font_color", C_ACCENT2)
		else:
			chip.text = "%d" % int(lr.damage)
			chip.add_theme_color_override("font_color", C_WARN)


func _refresh_tray() -> void:
	for child in tray_box.get_children():
		tray_box.remove_child(child)
		child.queue_free()
	if gm.inventory == null or gm.inventory.get_item_count() == 0:
		tray_box.add_child(_label("(leer – im Shop kaufen)", 13, C_MUTED))
		return
	# Nach Typ gruppieren, Reihenfolge des ersten Auftretens beibehalten.
	var order := []
	var groups := {}
	for i in range(gm.inventory.get_item_count()):
		var t = gm.inventory.peek_item(i)
		if not groups.has(t):
			groups[t] = {"count": 0, "first": i}
			order.append(t)
		groups[t].count += 1
	for t in order:
		var g = groups[t]
		var item := InventoryItem.new()
		item.item_index = g.first
		item.comp_type = t
		item.custom_minimum_size = Vector2(86, 54)
		item.tooltip_text = "%s\n%s" % [Component.get_type_name(t), Component.get_description(t)]
		var base: Color = COMP_COLORS.get(t, C_PANEL2)
		var selected: bool = g.first == selected_inv_index
		item.add_theme_stylebox_override("panel", _sb(base.darkened(0.05 if selected else 0.5), base.lightened(0.2) if selected else base.darkened(0.2), 2 if selected else 1, 8, 6))
		item.picked.connect(_on_inv_select)
		var vb := VBoxContainer.new()
		vb.add_theme_constant_override("separation", 0)
		vb.mouse_filter = Control.MOUSE_FILTER_IGNORE
		item.add_child(vb)
		var name_lbl := _label("%s ×%d" % [Component.get_short_name(t), g.count], 13, Color.WHITE)
		name_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		vb.add_child(name_lbl)
		var eff_lbl := _label(Component.get_label(t), 12, C_MUTED)
		eff_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		vb.add_child(eff_lbl)
		tray_box.add_child(item)


func _refresh_shop() -> void:
	shop_money.text = "Geld: %d" % gm.money
	shop_reroll_btn.text = "Neu würfeln (%d G)" % gm.reroll_cost
	shop_reroll_btn.disabled = gm.money < gm.reroll_cost
	if shop_next_btn:
		shop_next_btn.text = ("Nächste Runde  >" if gm.after_shop == "next_round" else "Level %d starten  >" % (gm.level + 1))

	if gm.relics.is_empty():
		shop_relics_lbl.text = "Relikte: (noch keine)"
	else:
		var names = []
		for r in gm.relics:
			names.append(gm.RELIC_NAMES[r])
		shop_relics_lbl.text = "Relikte: " + ", ".join(names)

	for child in shop_offers.get_children():
		shop_offers.remove_child(child)
		child.queue_free()
	var offers = gm.shop.offers
	if offers.is_empty():
		shop_offers.add_child(_label("Keine Angebote mehr.", 16, C_MUTED))
		return
	for i in range(offers.size()):
		var offer = offers[i]
		var t = offer.component_type
		var row := PanelContainer.new()
		row.add_theme_stylebox_override("panel", _sb(C_PANEL2, COMP_COLORS.get(t, C_PANEL2).darkened(0.2), 1, 8, 8))
		var h := HBoxContainer.new()
		h.add_theme_constant_override("separation", 12)
		row.add_child(h)
		var sw := _label("%s\n%s" % [Component.get_short_name(t), Component.get_label(t)], 15, Color.WHITE)
		sw.custom_minimum_size = Vector2(64, 0)
		sw.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		h.add_child(sw)
		var info := VBoxContainer.new()
		info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		info.add_child(_label("%s  (%d Hitze)" % [Component.get_type_name(t), Component.get_heat(t)], 16, C_TEXT))
		var d := _label(Component.get_description(t), 12, C_MUTED)
		d.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		d.custom_minimum_size = Vector2(300, 0)
		info.add_child(d)
		h.add_child(info)
		var buy := Button.new()
		buy.text = "%d G" % offer.price
		buy.custom_minimum_size = Vector2(80, 40)
		buy.add_theme_font_size_override("font_size", 16)
		var affordable = gm.money >= offer.price
		_style_button(buy, C_WARN.darkened(0.4) if affordable else C_PANEL)
		buy.disabled = not affordable
		buy.pressed.connect(_on_buy.bind(i))
		h.add_child(buy)
		shop_offers.add_child(row)


# =============================================================
#  BOARD-GRAFIK (Overlays)
# =============================================================

func _to_local(overlay: Control, gp: Vector2) -> Vector2:
	return overlay.get_global_transform().affine_inverse() * gp

func _row_center_y(overlay: Control, r: int) -> float:
	var cell: Control = cell_root[r][0]
	return _to_local(overlay, cell.global_position).y + cell.size.y / 2.0

# HINTER den Zellen: Schienen (Grooves) + Ein-/Ausgangssockel je Zeile.
func _draw_rails() -> void:
	if cell_root.is_empty() or gm == null:
		return
	var rail_style := _sb(Color(0.05, 0.06, 0.09), Color(1,1,1,0.04), 1, 14, 0)
	for r in range(4):
		var c0: Control = cell_root[r][0]
		var c5: Control = cell_root[r][5]
		var left := _to_local(rail_overlay, c0.global_position)
		var right := _to_local(rail_overlay, c5.global_position + Vector2(c5.size.x, 0))
		var cy := left.y + c0.size.y / 2.0
		var rail := Rect2(Vector2(left.x - 20, cy - 32), Vector2((right.x + 20) - (left.x - 20), 64))
		rail_overlay.draw_style_box(rail_style, rail)
		var active: bool = _lane_by_row.has(r)
		var lane = _lane_by_row.get(r, null)
		var broke: bool = active and lane != null and lane.reached_end
		# Eingangssockel links
		var in_c := Vector2(left.x - 12, cy)
		rail_overlay.draw_circle(in_c, 9, C_ACCENT2 if active else C_MUTED.darkened(0.25))
		rail_overlay.draw_circle(in_c, 4, C_BG)
		# Ausgangssockel rechts
		var out_c := Vector2(right.x + 12, cy)
		var out_col: Color = C_ACCENT2 if broke else (C_WARN.darkened(0.05) if active else C_MUTED.darkened(0.25))
		rail_overlay.draw_circle(out_c, 9, out_col)
		rail_overlay.draw_circle(out_c, 4, C_BG)

# VOR den Zellen: Kabel in den Lücken zwischen benachbarten Blöcken + Abbruch-Kappe.
func _draw_wires() -> void:
	if cell_root.is_empty() or gm == null:
		return
	for r in range(4):
		var cy := _row_center_y(wire_overlay, r)
		for c in range(5):
			if gm.board.get_block(c, r) == null or gm.board.get_block(c + 1, r) == null:
				continue
			var a: Control = cell_root[r][c]
			var b: Control = cell_root[r][c + 1]
			var pa := _to_local(wire_overlay, a.global_position + Vector2(a.size.x, a.size.y / 2.0))
			var pb := _to_local(wire_overlay, b.global_position + Vector2(0, b.size.y / 2.0))
			var powered: bool = _powered.has(Vector2i(c, r)) and _powered.has(Vector2i(c + 1, r))
			if powered:
				wire_overlay.draw_line(pa, pb, Color(C_ACCENT.r, C_ACCENT.g, C_ACCENT.b, 0.35), 8.0)
				wire_overlay.draw_line(pa, pb, C_ACCENT, 4.0)
			else:
				wire_overlay.draw_line(pa, pb, C_MUTED.darkened(0.1), 3.0)
		# Abbruch-Kappe: aktive Lane, die den Rand NICHT erreicht.
		var lane = _lane_by_row.get(r, null)
		if lane != null and not lane.reached_end and int(lane.stop_col) < 6 and not lane.path.is_empty():
			var sc := int(lane.stop_col)
			var lastc: Control = cell_root[r][sc - 1]
			var cap_x := _to_local(wire_overlay, lastc.global_position + Vector2(lastc.size.x, 0)).x + 4
			wire_overlay.draw_line(Vector2(cap_x, cy - 15), Vector2(cap_x, cy + 15), C_WARN, 3.0)
