# Core Cocker - Komplette Spiel-UI (Drag & Drop, Routing, Animation)
#
# Ablauf: Menü -> Shop (kaufen) -> Bau-Phase (Bauteile aus dem Fach unten aufs
# Feld ziehen, Ausgänge drehen) -> Paket senden (animiert) -> Belohnung -> Shop.
#
# ROUTING-MODELL: Ein einzelnes Paket startet am EINGANG (linker Rand, mittlere
# Zeile), läuft nach Osten in die erste Zelle und folgt danach immer der
# Ausgangsrichtung des Blocks in der aktuellen Zelle. Erreicht es den AUSGANG
# (rechter Rand, mittlere Zeile), zählt sein Wert als Schaden. Jeder Block hat nur
# einen – drehbaren – Ausgang, deshalb ist der Weg eindeutig. Klick auf einen
# Block dreht den Ausgang um 90°. Alles wird über refresh() aktualisiert.

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

# Board-Maße (spiegeln board.gd: 6 Spalten x 5 Zeilen, Ein-/Ausgang in Zeile 2)
const COLS := 6
const ROWS := 5
const MID  := 2
const CELL_SIZE := 84
const STEP_TIME := 0.32   # Zeit pro Feld beim Paket-Lauf (langsam & lesbar)
const HOLD_TIME := 0.22   # kurze Pause, wenn der Wert steigt

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
var rail_overlay: Control     # zeichnet Board-Rahmen/Sockel HINTER den Zellen
var wire_overlay: Control     # zeichnet Pfad/Pfeile VOR den Zellen
var cell_root := []           # [row][col] -> BoardCell
var cell_char := []           # [row][col] -> Label
var in_lbl: Label
var out_lbl: Label
var out_chip: Label           # Schadenszahl am Ausgang

# Inventar-Fach (unten)
var tray_box: HBoxContainer
var inv_sell_btn: Button

# Shop
var shop_money: Label
var shop_offers: VBoxContainer
var shop_reroll_btn: Button
var shop_next_btn: Button
var shop_relics_lbl: Label
var tab_buy_btn: Button
var tab_oc_btn: Button
var shop_buy_view: Control       # Container der Kauf-Angebote
var overclock_view: Control      # Container der Overclock-Werkstatt
var overclock_box: VBoxContainer
var shop_hint_lbl: Label

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
var _shop_tab := "buy"          # "buy" | "overclock"
var _animating := false
# Vorschau beim Bauen
var _route := {}              # Ergebnis aus compute_send()
var _on_path := {}            # Vector2i -> true (Zelle liegt auf dem Paketweg)
var _orphan := {}             # Vector2i -> true (belegt, aber nicht auf dem Weg)
var _hint_start := false      # noch nichts platziert -> Eingangszelle einladen


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


# Tastatur: Leertaste/Enter = Paket senden.
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

	var sub := _label("Route ein Datenpaket durch deine Schaltung – vom Eingang zum Ausgang – und knacke endlose Firewalls.", 17, C_MUTED)
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
	left.add_theme_constant_override("separation", 10)
	left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	mid.add_child(left)

	# Firewall
	fw_panel = _panel(C_PANEL, C_DANGER.darkened(0.3), 1, 10)
	left.add_child(fw_panel)
	var fw_v := VBoxContainer.new()
	fw_v.add_theme_constant_override("separation", 5)
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
	fw_bar.custom_minimum_size = Vector2(0, 22)
	fw_v.add_child(fw_bar)
	fw_hp = _label("", 13, C_MUTED)
	fw_v.add_child(fw_hp)

	# Board-Bereich (Rail-Overlay | Grid | Wire-Overlay | Sockel-Labels)
	board_area = Control.new()
	board_area.size_flags_vertical = Control.SIZE_EXPAND_FILL
	board_area.custom_minimum_size = Vector2(600, 470)
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
	grid.columns = COLS
	grid.add_theme_constant_override("h_separation", 8)
	grid.add_theme_constant_override("v_separation", 8)
	board_center.add_child(grid)
	_build_cells(grid)

	wire_overlay = Control.new()
	wire_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_full(wire_overlay)
	wire_overlay.draw.connect(_draw_wires)
	board_area.add_child(wire_overlay)

	in_lbl = _label("EIN", 12, C_ACCENT2)
	in_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	in_lbl.z_index = 5
	board_area.add_child(in_lbl)
	out_lbl = _label("AUS", 12, C_WARN)
	out_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	out_lbl.z_index = 5
	board_area.add_child(out_lbl)
	out_chip = _label("", 16, C_ACCENT2)
	out_chip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	out_chip.z_index = 6
	board_area.add_child(out_chip)

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
	preview_lbl.custom_minimum_size = Vector2(0, 72)
	prev_v.add_child(preview_lbl)

	send_btn = Button.new()
	send_btn.text = ">  PAKET SENDEN  (Leertaste)"
	send_btn.custom_minimum_size = Vector2(0, 58)
	send_btn.add_theme_font_size_override("font_size", 20)
	_style_button(send_btn, C_ACCENT2.darkened(0.35))
	send_btn.pressed.connect(_on_send)
	right.add_child(send_btn)

	var msg_panel := _panel(Color(0.08,0.09,0.12), C_PANEL2, 1, 10)
	msg_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	right.add_child(msg_panel)
	msg_lbl = _label("Zieh Bauteile aus dem Fach unten aufs Feld. Klicke einen Block, um seinen Ausgang zu drehen, und route das Paket zum Ausgang.", 14, C_MUTED)
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
	tray_head.add_child(_label("Chip aufs Feld ziehen · Klick auf Block = Ausgang drehen · Rechtsklick = zurück · Block auf Block ziehen = tauschen", 12, C_MUTED))
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
	for r in range(ROWS):
		var rr := []; var rc := []
		for c in range(COLS):
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

	# Tabs: Kaufen | Overclock-Werkstatt
	var tabs := HBoxContainer.new()
	tabs.add_theme_constant_override("separation", 8)
	v.add_child(tabs)
	tab_buy_btn = Button.new()
	tab_buy_btn.text = "Kaufen"
	tab_buy_btn.custom_minimum_size = Vector2(0, 38)
	tab_buy_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tab_buy_btn.add_theme_font_size_override("font_size", 15)
	tab_buy_btn.pressed.connect(_on_shop_tab.bind("buy"))
	tabs.add_child(tab_buy_btn)
	tab_oc_btn = Button.new()
	tab_oc_btn.text = "Overclock-Werkstatt"
	tab_oc_btn.custom_minimum_size = Vector2(0, 38)
	tab_oc_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tab_oc_btn.add_theme_font_size_override("font_size", 15)
	tab_oc_btn.pressed.connect(_on_shop_tab.bind("overclock"))
	tabs.add_child(tab_oc_btn)

	shop_hint_lbl = _label("", 14, C_MUTED)
	shop_hint_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(shop_hint_lbl)

	# Inhaltsbereich: entweder Kauf-Angebote oder Overclock-Werkstatt
	var content := Control.new()
	content.size_flags_vertical = Control.SIZE_EXPAND_FILL
	content.custom_minimum_size = Vector2(0, 300)
	v.add_child(content)

	shop_buy_view = VBoxContainer.new()
	_full(shop_buy_view)
	content.add_child(shop_buy_view)
	shop_offers = VBoxContainer.new()
	shop_offers.add_theme_constant_override("separation", 8)
	shop_offers.size_flags_vertical = Control.SIZE_EXPAND_FILL
	shop_buy_view.add_child(shop_offers)

	overclock_view = VBoxContainer.new()
	_full(overclock_view)
	content.add_child(overclock_view)
	var oc_scroll := ScrollContainer.new()
	oc_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	oc_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	overclock_view.add_child(oc_scroll)
	overclock_box = VBoxContainer.new()
	overclock_box.add_theme_constant_override("separation", 8)
	overclock_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	oc_scroll.add_child(overclock_box)

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
	_shop_tab = "buy"
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

func _on_shop_tab(tab: String) -> void:
	_shop_tab = tab
	refresh()

func _on_upgrade(index: int) -> void:
	gm.upgrade_block(index)
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

# Klick auf eine Zelle. Linksklick: Block drehen (bzw. gewähltes Bauteil setzen).
# Rechtsklick: Block zurück ins Inventar. Ein echter Drag löst hier KEIN Release
# aus (Godot leitet es ans Drop-Ziel), darum drehen wir erst beim Loslassen.
func _on_cell_input(event: InputEvent, c: int, r: int) -> void:
	if _animating or gm.phase != gm.GamePhase.BUILD:
		return
	if not (event is InputEventMouseButton):
		return
	var block = gm.board.get_block(c, r)
	if event.button_index == MOUSE_BUTTON_LEFT and not event.pressed:
		if block != null:
			gm.board.rotate_block(c, r)
			refresh()
		else:
			_try_place(c, r)
	elif event.button_index == MOUSE_BUTTON_RIGHT and event.pressed:
		if block != null:
			_return_block(c, r)

# Drop auf eine Zelle: platzieren (Inventar), verschieben oder tauschen (Board).
func _on_cell_drop(c: int, r: int, data: Dictionary) -> void:
	if _animating or gm.phase != gm.GamePhase.BUILD:
		return
	match data.get("kind", ""):
		"inventory":
			var idx: int = int(data.get("index", -1))
			if idx < 0 or idx >= gm.inventory.get_item_count():
				return
			var blk = gm.inventory.peek_item(idx)
			if blk == null:
				return
			# Block-Instanz umsetzen -> Übertaktungsstufe bleibt erhalten.
			if gm.board.put_block(c, r, blk):
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
				# Block-Instanz umsetzen -> Ausgangsrichtung bleibt erhalten.
				var b = gm.board.take_block(fc, fr)
				if b != null:
					gm.board.put_block(c, r, b)
			else:
				gm.board.swap_blocks(fc, fr, c, r)
	refresh()

# Drop aufs Inventar-Fach: platzierten Block zurücklegen.
func _on_tray_drop(data: Dictionary) -> void:
	if _animating or gm.phase != gm.GamePhase.BUILD:
		return
	var fc: int = int(data.get("from_c", -1))
	var fr: int = int(data.get("from_r", -1))
	_return_block(fc, fr)

func _return_block(c: int, r: int) -> void:
	if gm.inventory and gm.inventory.get_item_count() >= gm.inventory.max_size:
		_set_msg("Inventar voll – kein Platz zum Zurücklegen.")
		return
	var b = gm.board.take_block(c, r)
	if b != null and gm.inventory:
		# Block-Instanz zurücklegen -> Übertaktungsstufe bleibt erhalten.
		if gm.inventory.add_block(b):
			_set_msg("Zurück ins Inventar: %s%s" % [Component.get_type_name(b.type), UIStyle.tier_badge(b.tier)])
		else:
			gm.board.put_block(c, r, b)  # Feld ist jetzt leer -> gelingt immer
			_set_msg("Inventar voll.")
	refresh()

func _try_place(c: int, r: int) -> void:
	if gm.inventory == null or selected_inv_index < 0:
		_set_msg("Wähle ein Bauteil (anklicken) oder zieh es direkt aufs Feld.")
		return
	if selected_inv_index >= gm.inventory.get_item_count():
		selected_inv_index = -1
		refresh()
		return
	var blk = gm.inventory.peek_item(selected_inv_index)
	if blk != null and gm.board.put_block(c, r, blk):
		gm.inventory.take_item(selected_inv_index)
		gm.stats.components_placed += 1
		selected_inv_index = -1
		_set_msg("Platziert: %s. Klick den Block, um den Ausgang zu drehen." % Component.get_type_name(blk.type))
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


# Ein Paket läuft langsam vom Eingang die Kette entlang (Wert rollt hoch) und
# fliegt bei Lieferung in die Firewall; sonst zerplatzt es am Weg-Ende.
func _play_send(res: Dictionary) -> void:
	var path: Array = res.get("path", [])
	if path.is_empty():
		_set_msg("Kein Weg – zieh ein Bauteil in die Eingangszeile (Mitte links).")
		await get_tree().create_timer(0.4).timeout
		return

	var delivered: bool = res.get("delivered", false)
	var total := int(res.get("total_damage", 0))
	_set_msg("Paket unterwegs …")

	var token := _make_packet_token(int(path[0].before))
	add_child(token)
	var lbl: Label = token.get_child(0)
	# Start am Eingangssockel, dann in die erste Zelle.
	token.global_position = _in_point_global() - token.size / 2.0

	for step in path:
		var target = _cell_center(step.col, step.row) - token.size / 2.0
		var mt := create_tween()
		mt.tween_property(token, "global_position", target, STEP_TIME).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		await mt.finished
		if int(step.after) != int(step.before):
			var rise := int(step.after) - int(step.before)
			# Dauer < HOLD_TIME, sonst überschreibt der Roll den nächsten Wert.
			var roll := create_tween()
			roll.tween_method(func(v): lbl.text = str(int(v)), float(step.before), float(step.after), 0.2).set_ease(Tween.EASE_OUT)
			var pop := create_tween()
			pop.tween_property(lbl, "scale", Vector2(1.3, 1.3), 0.09)
			pop.tween_property(lbl, "scale", Vector2.ONE, 0.09)
			var fcol := C_ACCENT2 if rise > 0 else C_DANGER
			_spawn_float(("+%d" % rise) if rise > 0 else str(rise), _cell_center(step.col, step.row), fcol)
			await get_tree().create_timer(HOLD_TIME).timeout
		else:
			lbl.text = str(int(step.after))

	if delivered:
		# Aus der letzten Zelle zum Ausgangssockel, dann in die Firewall.
		var out_target = _out_point_global() - token.size / 2.0
		var ot := create_tween()
		ot.tween_property(token, "global_position", out_target, STEP_TIME * 0.8).set_trans(Tween.TRANS_SINE)
		await ot.finished
		_spawn_float("Durchbruch!", _out_point_global() + Vector2(0, -26), C_ACCENT)
		lbl.text = str(total)
		var bt := create_tween()
		bt.tween_property(token, "scale", Vector2(1.35, 1.35), 0.08)
		bt.tween_property(token, "scale", Vector2.ONE, 0.08)
		await bt.finished
		if fw_bar:
			var fw_target = fw_bar.global_position + fw_bar.size / 2.0 - token.size / 2.0
			var ft := create_tween()
			ft.tween_property(token, "global_position", fw_target, 0.24).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
			await ft.finished
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
			_spawn_float("-%d" % total, fw_bar.global_position + Vector2(fw_bar.size.x * 0.5, -8), C_DANGER)
			var hpt := create_tween()
			hpt.tween_property(fw_bar, "value", target_hp, 0.35).set_trans(Tween.TRANS_CUBIC)
			await hpt.finished
	else:
		# Paket verpufft am Weg-Ende.
		var last = path[path.size() - 1]
		_spawn_float("✕ verpufft", _cell_center(last.col, last.row) + Vector2(0, -22), C_DANGER)
		var fz := create_tween()
		fz.tween_property(token, "modulate:a", 0.0, 0.3)
		fz.parallel().tween_property(token, "scale", Vector2(0.4, 0.4), 0.3)
		await fz.finished

	token.queue_free()


func _cell_center(c: int, r: int) -> Vector2:
	var node: Control = cell_root[r][c]
	return node.global_position + node.size / 2.0

# Globaler Punkt des Eingangssockels (links neben Zelle (0, MID)).
func _in_point_global() -> Vector2:
	var cell: Control = cell_root[MID][0]
	return cell.global_position + Vector2(-24, cell.size.y / 2.0)

# Globaler Punkt des Ausgangssockels (rechts neben Zelle (COLS-1, MID)).
func _out_point_global() -> Vector2:
	var cell: Control = cell_root[MID][COLS - 1]
	return cell.global_position + Vector2(cell.size.x + 24, cell.size.y / 2.0)

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
	# Während eines laufenden Drags NICHT neu aufbauen (das würde die Drag-Quelle
	# löschen). Godot löscht gui.dragging erst NACH _drop_data – der Drop ruft
	# refresh() also noch "im Drag" auf; darum verschieben wir es auf den nächsten
	# Idle-Frame, sonst bliebe das Board nach jedem Ablegen optisch stehen.
	if is_inside_tree() and get_viewport().gui_is_dragging():
		refresh.call_deferred()
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

	# Routen-/Vorschau-Daten (nur beim Bauen)
	_route = {}
	_on_path = {}
	_orphan = {}
	_hint_start = false
	if phase == gm.GamePhase.BUILD:
		var res = gm.compute_send()
		_route = res
		for step in res.path:
			_on_path[Vector2i(step.col, step.row)] = true
		for rr in range(ROWS):
			for cc in range(COLS):
				if gm.board.get_block(cc, rr) != null and not _on_path.has(Vector2i(cc, rr)):
					_orphan[Vector2i(cc, rr)] = true
		_hint_start = gm.board.placed_count() == 0
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
		if fw.has_modifier():
			var mdesc := []
			for m in fw.modifiers:
				mdesc.append("%s: %s" % [fw.MOD_NAMES[m], fw.MOD_DESCS.get(m, "")])
			fw_mod.tooltip_text = "\n".join(mdesc)
		else:
			fw_mod.tooltip_text = ""
	else:
		fw_title.text = "FIREWALL"
		fw_bar.max_value = 1
		fw_bar.value = 0
		fw_hp.text = "- noch keine Runde -"
		fw_mod.text = ""

	_refresh_cells()
	_refresh_io()

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
	var path: Array = res.get("path", [])
	if path.is_empty():
		preview_lbl.add_theme_color_override("font_color", C_WARN)
		preview_lbl.text = "Zieh ein Bauteil in die Eingangszeile (Mitte links) und route das Paket nach rechts zum Ausgang."
		return
	var delivered: bool = res.get("delivered", false)
	if not delivered:
		preview_lbl.add_theme_color_override("font_color", C_DANGER)
		preview_lbl.text = "Paket erreicht den Ausgang NICHT.\n%s\nDrehe Ausgänge (Klick), bis der Weg rechts in der Mitte herausführt." % gm.reason_hint(res.get("reason", ""))
		return
	var dmg = int(res.get("total_damage", 0))
	var value = int(res.get("value", 0))
	var oh = "  •  ÜBERHITZT" if res.get("overheated", false) else ""
	var win = gm.firewall != null and dmg >= gm.firewall.health
	var verdict = "reicht zum Knacken" if win else "reicht NICHT"
	preview_lbl.text = "Paketwert %d → %d Schaden%s\n%s (Firewall: %d HP)" % [value, dmg, oh, verdict, (gm.firewall.health if gm.firewall else 0)]
	preview_lbl.add_theme_color_override("font_color", C_ACCENT2 if win else C_DANGER)


func _refresh_cells() -> void:
	for r in range(ROWS):
		for c in range(COLS):
			var cell: BoardCell = cell_root[r][c]
			var char_lbl: Label = cell_char[r][c]
			var b = gm.board.get_block(c, r)
			cell.has_block = b != null
			cell.drag_type = b.type if b != null else -1
			cell.drag_tier = b.tier if b != null else 0
			if b == null:
				var is_gate: bool = (r == MID) and (c == 0)
				if _hint_start and is_gate:
					cell.add_theme_stylebox_override("panel", _sb(C_CELL, C_ACCENT2, 2, 8, 0))
					char_lbl.text = "EIN →"
					char_lbl.add_theme_font_size_override("font_size", 13)
					char_lbl.add_theme_color_override("font_color", Color(C_ACCENT2.r, C_ACCENT2.g, C_ACCENT2.b, 0.7))
				else:
					var edge := C_ACCENT2.darkened(0.1) if (r == MID and c == 0) else Color(1,1,1,0.06)
					cell.add_theme_stylebox_override("panel", _sb(C_CELL, edge, 1, 8, 0))
					char_lbl.text = ""
			else:
				var col: Color = COMP_COLORS.get(b.type, C_PANEL2)
				var powered: bool = _on_path.has(Vector2i(c, r))
				# Übertaktete Blöcke bekommen einen goldenen Rahmen.
				var border: Color = (C_WARN if b.tier > 0 else col.lightened(0.3)) if powered else (C_WARN.darkened(0.2) if b.tier > 0 else C_MUTED.darkened(0.1))
				var bw := 3 if (powered or b.tier > 0) else 2
				var bg: Color = col.darkened(0.1) if powered else col.darkened(0.45)
				cell.add_theme_stylebox_override("panel", _sb(bg, border, bw, 8, 0))
				char_lbl.add_theme_font_size_override("font_size", 14)
				char_lbl.add_theme_color_override("font_color", Color.WHITE if powered else Color(1,1,1,0.5))
				char_lbl.text = "%s%s\n%s" % [Component.get_short_name(b.type), UIStyle.tier_badge(b.tier), Component.get_label(b.type, b.tier)]


# Positioniert die Sockel-Labels und die Ausgangs-Schadenszahl.
func _refresh_io() -> void:
	if cell_root.is_empty():
		return
	var in_cell: Control = cell_root[MID][0]
	var out_cell: Control = cell_root[MID][COLS - 1]
	var area_pos := board_area.global_position
	in_lbl.position = in_cell.global_position - area_pos + Vector2(-44, in_cell.size.y / 2.0 - 30)
	out_lbl.position = out_cell.global_position - area_pos + Vector2(out_cell.size.x + 12, out_cell.size.y / 2.0 - 30)

	var delivered: bool = _route.get("delivered", false)
	var has_path: bool = not _route.get("path", []).is_empty()
	out_chip.position = out_cell.global_position - area_pos + Vector2(out_cell.size.x + 6, out_cell.size.y / 2.0 - 4)
	if gm.phase != gm.GamePhase.BUILD or not has_path:
		out_chip.text = ""
	elif delivered:
		out_chip.text = "%d ⚡" % int(_route.get("total_damage", 0))
		out_chip.add_theme_color_override("font_color", C_ACCENT2)
	else:
		out_chip.text = "MISS"
		out_chip.add_theme_color_override("font_color", C_DANGER)


func _refresh_tray() -> void:
	for child in tray_box.get_children():
		tray_box.remove_child(child)
		child.queue_free()
	if gm.inventory == null or gm.inventory.get_item_count() == 0:
		tray_box.add_child(_label("(leer – im Shop kaufen)", 13, C_MUTED))
		return
	# Nach (Typ, Tier) gruppieren, Reihenfolge des ersten Auftretens beibehalten.
	var order := []
	var groups := {}
	for i in range(gm.inventory.get_item_count()):
		var b = gm.inventory.peek_item(i)
		var key := Vector2i(b.type, b.tier)
		if not groups.has(key):
			groups[key] = {"count": 0, "first": i, "type": b.type, "tier": b.tier}
			order.append(key)
		groups[key].count += 1
	for key in order:
		var g = groups[key]
		var t: int = g.type
		var tier: int = g.tier
		var item := InventoryItem.new()
		item.item_index = g.first
		item.comp_type = t
		item.comp_tier = tier
		item.custom_minimum_size = Vector2(88, 54)
		item.tooltip_text = "%s%s\n%s" % [Component.get_type_name(t), UIStyle.tier_badge(tier), Component.get_description(t)]
		var base: Color = COMP_COLORS.get(t, C_PANEL2)
		var selected: bool = g.first == selected_inv_index
		var bcol: Color = C_WARN if tier > 0 else (base.lightened(0.2) if selected else base.darkened(0.2))
		item.add_theme_stylebox_override("panel", _sb(base.darkened(0.05 if selected else 0.5), bcol, 2 if (selected or tier > 0) else 1, 8, 6))
		item.picked.connect(_on_inv_select)
		var vb := VBoxContainer.new()
		vb.add_theme_constant_override("separation", 0)
		vb.mouse_filter = Control.MOUSE_FILTER_IGNORE
		item.add_child(vb)
		var name_lbl := _label("%s%s ×%d" % [Component.get_short_name(t), UIStyle.tier_badge(tier), g.count], 13, Color.WHITE)
		name_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		vb.add_child(name_lbl)
		var eff_lbl := _label(Component.get_label(t, tier), 12, C_MUTED)
		eff_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		vb.add_child(eff_lbl)
		tray_box.add_child(item)


func _refresh_shop() -> void:
	shop_money.text = "Geld: %d" % gm.money
	shop_reroll_btn.text = "Neu würfeln (%d G)" % gm.reroll_cost
	shop_reroll_btn.disabled = gm.money < gm.reroll_cost or _shop_tab != "buy"
	shop_reroll_btn.visible = _shop_tab == "buy"
	if shop_next_btn:
		shop_next_btn.text = ("Nächste Runde  >" if gm.after_shop == "next_round" else "Level %d starten  >" % (gm.level + 1))

	# Tab-Zustand
	var on_buy := _shop_tab == "buy"
	shop_buy_view.visible = on_buy
	overclock_view.visible = not on_buy
	_style_button(tab_buy_btn, C_ACCENT2.darkened(0.3) if on_buy else C_PANEL2)
	_style_button(tab_oc_btn, C_PANEL2 if on_buy else C_WARN.darkened(0.35))
	shop_hint_lbl.text = ("Gekaufte Bausteine landen im Inventar-Fach." if on_buy
		else "Werte Bausteine gegen Geld auf – höhere Stufe = stärkerer Effekt. TRACE ist nicht übertaktbar.")
	if not on_buy:
		_refresh_overclock()

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
		var inv_full = gm.inventory.get_item_count() >= gm.inventory.max_size
		var affordable = gm.money >= offer.price and not inv_full
		_style_button(buy, C_WARN.darkened(0.4) if affordable else C_PANEL)
		buy.disabled = not affordable
		buy.pressed.connect(_on_buy.bind(i))
		h.add_child(buy)
		shop_offers.add_child(row)


# Overclock-Werkstatt: Inventar nach (Typ,Tier) gruppiert, je Gruppe ein Aufwerten-Knopf.
func _refresh_overclock() -> void:
	for child in overclock_box.get_children():
		overclock_box.remove_child(child)
		child.queue_free()
	if gm.inventory == null or gm.inventory.get_item_count() == 0:
		overclock_box.add_child(_label("Inventar leer – kaufe zuerst Bausteine im Kauf-Tab.", 15, C_MUTED))
		return

	var order := []
	var groups := {}
	for i in range(gm.inventory.get_item_count()):
		var b = gm.inventory.peek_item(i)
		var key := Vector2i(b.type, b.tier)
		if not groups.has(key):
			groups[key] = {"count": 0, "first": i, "type": b.type, "tier": b.tier}
			order.append(key)
		groups[key].count += 1

	for key in order:
		var g = groups[key]
		var t: int = g.type
		var tier: int = g.tier
		var cost: int = Component.get_upgrade_cost(t, tier)
		var row := PanelContainer.new()
		row.add_theme_stylebox_override("panel", _sb(C_PANEL2, COMP_COLORS.get(t, C_PANEL2).darkened(0.2), 1, 8, 8))
		var h := HBoxContainer.new()
		h.add_theme_constant_override("separation", 12)
		row.add_child(h)
		var sw := _label("%s%s\n×%d" % [Component.get_short_name(t), UIStyle.tier_badge(tier), g.count], 15, Color.WHITE)
		sw.custom_minimum_size = Vector2(70, 0)
		sw.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		h.add_child(sw)
		var info := VBoxContainer.new()
		info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		info.add_child(_label("%s  (Stufe %d)" % [Component.get_type_name(t), tier], 16, C_TEXT))
		if cost < 0:
			var reason := "nicht übertaktbar" if not Component.is_upgradeable(t) else "Maximalstufe erreicht"
			info.add_child(_label("%s → %s" % [Component.get_label(t, tier), reason], 13, C_MUTED))
		else:
			info.add_child(_label("%s  →  %s" % [Component.get_label(t, tier), Component.get_label(t, tier + 1)], 13, C_ACCENT2))
		h.add_child(info)
		var up := Button.new()
		up.custom_minimum_size = Vector2(110, 44)
		up.add_theme_font_size_override("font_size", 15)
		if cost < 0:
			up.text = "—"
			up.disabled = true
			_style_button(up, C_PANEL)
		else:
			up.text = "Stufe %d\n%d G" % [tier + 1, cost]
			var affordable: bool = gm.money >= cost
			up.disabled = not affordable
			_style_button(up, C_WARN.darkened(0.4) if affordable else C_PANEL)
			up.pressed.connect(_on_upgrade.bind(g.first))
		h.add_child(up)
		overclock_box.add_child(row)


# =============================================================
#  BOARD-GRAFIK (Overlays)
# =============================================================

func _to_local(overlay: Control, gp: Vector2) -> Vector2:
	return overlay.get_global_transform().affine_inverse() * gp

func _cell_local(overlay: Control, c: int, r: int) -> Vector2:
	var cell: Control = cell_root[r][c]
	return _to_local(overlay, cell.global_position + cell.size / 2.0)

# HINTER den Zellen: Board-Wanne + Ein-/Ausgangssockel (mittlere Zeile).
func _draw_rails() -> void:
	if cell_root.is_empty() or gm == null:
		return
	# Board-Wanne
	var tl := _to_local(rail_overlay, cell_root[0][0].global_position)
	var br_cell: Control = cell_root[ROWS - 1][COLS - 1]
	var br := _to_local(rail_overlay, br_cell.global_position + br_cell.size)
	var tub := Rect2(tl - Vector2(16, 16), (br - tl) + Vector2(32, 32))
	rail_overlay.draw_style_box(_sb(Color(0.05, 0.06, 0.09), Color(1,1,1,0.05), 1, 16, 0), tub)

	var has_path: bool = not _route.get("path", []).is_empty()
	var delivered: bool = _route.get("delivered", false)

	# Eingangssockel (links, MID)
	var in_p := _to_local(rail_overlay, _in_point_global())
	rail_overlay.draw_line(in_p, in_p + Vector2(20, 0), C_ACCENT2, 5.0)
	rail_overlay.draw_circle(in_p, 10, C_ACCENT2)
	rail_overlay.draw_circle(in_p, 5, C_BG)

	# Ausgangssockel (rechts, MID)
	var out_p := _to_local(rail_overlay, _out_point_global())
	var out_col: Color = C_ACCENT2 if (has_path and delivered) else (C_WARN.darkened(0.05) if has_path else C_MUTED.darkened(0.2))
	rail_overlay.draw_line(out_p - Vector2(20, 0), out_p, out_col, 5.0)
	rail_overlay.draw_circle(out_p, 10, out_col)
	rail_overlay.draw_circle(out_p, 5, C_BG)


# VOR den Zellen: der gezeichnete Paketweg + Ausgangspfeile je Block + Endmarker.
func _draw_wires() -> void:
	if cell_root.is_empty() or gm == null:
		return
	if gm.phase == gm.GamePhase.BUILD:
		_draw_route_path()
	# Ausgangspfeile auf jedem platzierten Block.
	for r in range(ROWS):
		for c in range(COLS):
			var b = gm.board.get_block(c, r)
			if b == null:
				continue
			var on_path: bool = _on_path.has(Vector2i(c, r))
			_draw_out_arrow(c, r, b.out_dir, on_path)


func _draw_route_path() -> void:
	var path: Array = _route.get("path", [])
	if path.is_empty():
		return
	var delivered: bool = _route.get("delivered", false)
	var pts: Array = []
	pts.append(_to_local(wire_overlay, _in_point_global()))
	for step in path:
		pts.append(_cell_local(wire_overlay, step.col, step.row))
	if delivered:
		pts.append(_to_local(wire_overlay, _out_point_global()))

	var glow: Color = C_ACCENT if delivered else C_WARN
	var core: Color = C_ACCENT2 if delivered else C_WARN.lightened(0.1)
	for i in range(pts.size() - 1):
		wire_overlay.draw_line(pts[i], pts[i + 1], Color(glow.r, glow.g, glow.b, 0.30), 10.0)
		wire_overlay.draw_line(pts[i], pts[i + 1], core, 4.0)

	# Endmarker, wenn das Paket den Ausgang nicht erreicht.
	if not delivered and not path.is_empty():
		var last = path[path.size() - 1]
		var p := _cell_local(wire_overlay, last.col, last.row)
		var s := 9.0
		wire_overlay.draw_line(p + Vector2(-s, -s), p + Vector2(s, s), C_DANGER, 3.0)
		wire_overlay.draw_line(p + Vector2(-s, s), p + Vector2(s, -s), C_DANGER, 3.0)


# Kleiner Pfeil an der Ausgangsseite eines Blocks, zeigt die Ausgangsrichtung.
func _draw_out_arrow(c: int, r: int, dir: int, on_path: bool) -> void:
	var cell: Control = cell_root[r][c]
	var center := _to_local(wire_overlay, cell.global_position + cell.size / 2.0)
	var half := cell.size.x / 2.0
	var dvec := Vector2(Block.dir_delta(dir))
	var tip := center + dvec * (half - 4)
	var perp := Vector2(-dvec.y, dvec.x)
	var col: Color = C_ACCENT2 if on_path else C_MUTED.darkened(0.05)
	var a := tip
	var b := tip - dvec * 12 + perp * 7
	var d := tip - dvec * 12 - perp * 7
	wire_overlay.draw_colored_polygon(PackedVector2Array([a, b, d]), col)
