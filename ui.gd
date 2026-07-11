# Circuit Breaker - Komplette Spiel-UI (klickbar, mit Ports & Animation)
#
# Ablauf: Menü -> Shop (Bausteine kaufen) -> Bau-Phase (aus Inventar platzieren,
# Ein-/Ausgänge per Popup drehen) -> Pakete senden (animiert) -> Shop -> ...
#
# Pakete laufen links rein, folgen den Ausgängen von Block zu Block und müssen
# den rechten Rand erreichen (Durchbruch-Bonus). Alles wird über refresh()
# aus dem GameManager-Zustand aktualisiert.

extends Control

# Component und Block sind über class_name global verfügbar – kein preload nötig.

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

var gm = null

# Screens
var menu_root: Control
var game_root: Control
var shop_root: Control
var over_root: Control
var dialog_root: Control

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
var inv_grid: GridContainer
var menu_high: Label

# Board-Zellen (jeweils [row][col])
var cell_root := []
var cell_char := []
var cell_in := []
var cell_out := []
var cell_info := []

# Shop
var shop_money: Label
var shop_offers: VBoxContainer

# Game Over
var over_round: Label
var over_score: Label
var over_high: Label

# Belohnung / Sieg / Vorschau
var reward_root: Control
var reward_cards: HBoxContainer
var victory_root: Control
var victory_score: Label
var preview_lbl: Label
var shop_reroll_btn: Button
var shop_relics_lbl: Label
var inv_sell_btn: Button

# Dialog
var dlg_title: Label
var dlg_desc: Label
var dlg_ports: Label
var dialog_cell := Vector2i(-1, -1)

# Zustand
var selected_inv_index := -1
var _animating := false
# Pfad-Vorschau (beim Bauen): Zellen auf dem Pfad + Abbruch-Zelle
var _preview_cells := {}
var _preview_break := Vector2i(-1, -1)


func _ready() -> void:
	gm = get_node_or_null("../GameManager")
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_build_background()
	_build_menu()
	_build_game()
	_build_shop()
	_build_reward()
	_build_victory()
	_build_over()
	_build_dialog()
	refresh()


# =============================================================
#  STYLE-HELFER
# =============================================================

# Dünne Weiterleitungen an Style – die eigentliche Definition liegt in ui_style.gd.
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

	var title := _label(">> CIRCUIT BREAKER <<", 46, C_ACCENT)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(title)

	var sub := _label("Baue die Schaltung, leite das Paket, knacke die Firewall.", 17, C_MUTED)
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
		margin.add_theme_constant_override(m, 20)
	game_root.add_child(margin)

	var root_v := VBoxContainer.new()
	root_v.add_theme_constant_override("separation", 14)
	margin.add_child(root_v)

	# Top-Bar
	var topbar := _panel(C_PANEL, C_ACCENT.darkened(0.3), 1, 10)
	root_v.add_child(topbar)
	var top_h := HBoxContainer.new()
	top_h.add_theme_constant_override("separation", 20)
	topbar.add_child(top_h)
	top_h.add_child(_label("CIRCUIT BREAKER", 20, C_ACCENT))
	var tsp := Control.new()
	tsp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top_h.add_child(tsp)
	lbl_round = _label("Runde 1", 18, C_TEXT)
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

	# Mitte
	var mid := HBoxContainer.new()
	mid.add_theme_constant_override("separation", 16)
	mid.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root_v.add_child(mid)

	# LINKS: Firewall + Board + Hitze
	var left := VBoxContainer.new()
	left.add_theme_constant_override("separation", 12)
	left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	mid.add_child(left)

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
	fw_bar.custom_minimum_size = Vector2(0, 22)
	fw_v.add_child(fw_bar)
	fw_hp = _label("", 13, C_MUTED)
	fw_v.add_child(fw_hp)

	var board_center := CenterContainer.new()
	board_center.size_flags_vertical = Control.SIZE_EXPAND_FILL
	left.add_child(board_center)
	var board_h := HBoxContainer.new()
	board_h.add_theme_constant_override("separation", 6)
	board_center.add_child(board_h)
	board_h.add_child(_marker("START", C_ACCENT2))
	var grid := GridContainer.new()
	grid.columns = 6
	grid.add_theme_constant_override("h_separation", 6)
	grid.add_theme_constant_override("v_separation", 6)
	board_h.add_child(grid)
	_build_cells(grid)
	board_h.add_child(_marker("ZIEL", C_DANGER))

	var heat_panel := _panel(C_PANEL, C_PANEL2, 1, 10)
	left.add_child(heat_panel)
	var heat_v := VBoxContainer.new()
	heat_panel.add_child(heat_v)
	heat_lbl = _label("Hitze 0/7", 14, C_WARN)
	heat_v.add_child(heat_lbl)
	heat_bar = _make_bar(C_WARN)
	heat_v.add_child(heat_bar)

	# RECHTS: Inventar + Senden + Meldung
	var right := VBoxContainer.new()
	right.add_theme_constant_override("separation", 12)
	right.custom_minimum_size = Vector2(340, 0)
	mid.add_child(right)

	var inv_panel := _panel(C_PANEL, C_ACCENT.darkened(0.4), 1, 10)
	inv_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	right.add_child(inv_panel)
	var inv_v := VBoxContainer.new()
	inv_v.add_theme_constant_override("separation", 8)
	inv_panel.add_child(inv_v)
	inv_v.add_child(_label("INVENTAR", 16, C_ACCENT))
	inv_v.add_child(_label("auswählen, dann leeres Feld klicken", 12, C_MUTED))
	inv_grid = GridContainer.new()
	inv_grid.columns = 4
	inv_grid.add_theme_constant_override("h_separation", 6)
	inv_grid.add_theme_constant_override("v_separation", 6)
	inv_v.add_child(inv_grid)
	inv_sell_btn = Button.new()
	inv_sell_btn.text = "Ausgewähltes verkaufen"
	inv_sell_btn.add_theme_font_size_override("font_size", 13)
	_style_button(inv_sell_btn, C_PANEL2)
	inv_sell_btn.pressed.connect(_on_sell)
	inv_v.add_child(inv_sell_btn)

	preview_lbl = _label("", 14, C_ACCENT2)
	preview_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	right.add_child(preview_lbl)

	send_btn = Button.new()
	send_btn.text = ">  PAKETE SENDEN"
	send_btn.custom_minimum_size = Vector2(0, 56)
	send_btn.add_theme_font_size_override("font_size", 20)
	_style_button(send_btn, C_ACCENT2.darkened(0.35))
	send_btn.pressed.connect(_on_send)
	right.add_child(send_btn)

	var msg_panel := _panel(Color(0.08,0.09,0.12), C_PANEL2, 1, 10)
	msg_panel.custom_minimum_size = Vector2(0, 90)
	right.add_child(msg_panel)
	msg_lbl = _label("Kaufe Bausteine, platziere sie, verbinde Ein-/Ausgänge zum rechten Rand.", 14, C_MUTED)
	msg_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	msg_lbl.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	msg_panel.add_child(msg_lbl)


func _build_cells(grid: GridContainer) -> void:
	cell_root.clear(); cell_char.clear(); cell_in.clear(); cell_out.clear(); cell_info.clear()
	for r in range(4):
		var rr := []; var rc := []; var ri := []; var ro := []; var rinfo := []
		for c in range(6):
			var panel := Panel.new()
			panel.custom_minimum_size = Vector2(CELL_SIZE, CELL_SIZE)
			panel.gui_input.connect(_on_cell_input.bind(c, r))

			var char_lbl := Label.new()
			_full(char_lbl)
			char_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			char_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
			char_lbl.add_theme_font_size_override("font_size", 15)
			char_lbl.add_theme_color_override("font_color", Color.WHITE)
			char_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
			panel.add_child(char_lbl)

			var in_lbl := Label.new()
			in_lbl.add_theme_font_size_override("font_size", 15)
			in_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
			panel.add_child(in_lbl)

			var out_lbl := Label.new()
			out_lbl.add_theme_font_size_override("font_size", 17)
			out_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
			panel.add_child(out_lbl)

			var info_btn := Button.new()
			info_btn.text = "i"
			info_btn.custom_minimum_size = Vector2(20, 20)
			info_btn.position = Vector2(CELL_SIZE - 24, 4)
			info_btn.add_theme_font_size_override("font_size", 12)
			_style_button(info_btn, C_PANEL2)
			info_btn.pressed.connect(_on_cell_info.bind(c, r))
			panel.add_child(info_btn)

			grid.add_child(panel)
			rr.append(panel); rc.append(char_lbl); ri.append(in_lbl); ro.append(out_lbl); rinfo.append(info_btn)
		cell_root.append(rr); cell_char.append(rc); cell_in.append(ri); cell_out.append(ro); cell_info.append(rinfo)


func _vtext(s: String) -> String:
	var out := ""
	for i in range(s.length()):
		out += s[i]
		if i < s.length() - 1:
			out += "\n"
	return out

func _marker(text: String, col: Color) -> Label:
	var l := _label(_vtext(text), 13, col)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	l.custom_minimum_size = Vector2(26, 0)
	return l

func _edge_pos(dir: int) -> Vector2:
	match dir:
		Block.Dir.RIGHT: return Vector2(CELL_SIZE - 18, CELL_SIZE / 2.0 - 10)
		Block.Dir.DOWN:  return Vector2(CELL_SIZE / 2.0 - 8, CELL_SIZE - 22)
		Block.Dir.LEFT:  return Vector2(2, CELL_SIZE / 2.0 - 10)
		Block.Dir.UP:    return Vector2(CELL_SIZE / 2.0 - 8, 2)
	return Vector2(CELL_SIZE / 2.0, CELL_SIZE / 2.0)


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
	panel.custom_minimum_size = Vector2(560, 480)
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
	v.add_child(_label("Gekaufte Bausteine landen im Inventar.", 14, C_MUTED))
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
	var next_btn := Button.new()
	next_btn.text = "Weiter  >"
	next_btn.custom_minimum_size = Vector2(0, 50)
	next_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	next_btn.add_theme_font_size_override("font_size", 18)
	_style_button(next_btn, C_ACCENT2.darkened(0.35))
	next_btn.pressed.connect(_on_next)
	btn_row.add_child(next_btn)


# =============================================================
#  BELOHNUNGS-OVERLAY (Relikt-Wahl)
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
		c.queue_free()
	for i in range(gm.reward_choices.size()):
		var r = gm.reward_choices[i]
		var card := _panel(C_PANEL2, C_ACCENT2.darkened(0.3), 1, 10)
		card.custom_minimum_size = Vector2(210, 0)
		var cv := VBoxContainer.new()
		cv.add_theme_constant_override("separation", 10)
		card.add_child(cv)
		cv.add_child(_label(gm.RELIC_NAMES[r], 18, C_ACCENT2))
		var desc := _label(gm.RELIC_DESCS[r], 14, C_TEXT)
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
#  SIEG-OVERLAY
# =============================================================

func _build_victory() -> void:
	victory_root = Control.new()
	_full(victory_root)
	add_child(victory_root)
	var dim := ColorRect.new()
	dim.color = Color(0, 0.04, 0.03, 0.85)
	_full(dim)
	victory_root.add_child(dim)
	var center := CenterContainer.new()
	_full(center)
	victory_root.add_child(center)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 14)
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	center.add_child(box)
	var t := _label("SIEG!", 52, C_ACCENT2)
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(t)
	var s := _label("Alle Firewalls geknackt.", 18, C_TEXT)
	s.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(s)
	victory_score = _label("", 22, C_WARN)
	victory_score.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(victory_score)
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
	over_round = _label("", 18, C_TEXT)
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
#  BLOCK-DIALOG (Info + Aktionen)
# =============================================================

func _dlg_button(text: String) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(0, 42)
	b.add_theme_font_size_override("font_size", 16)
	_style_button(b, C_PANEL2)
	return b

func _build_dialog() -> void:
	dialog_root = Control.new()
	_full(dialog_root)
	add_child(dialog_root)
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.6)
	_full(dim)
	dim.gui_input.connect(_on_dialog_dim_input)
	dialog_root.add_child(dim)
	var center := CenterContainer.new()
	_full(center)
	dialog_root.add_child(center)
	var panel := _panel(C_PANEL, C_ACCENT.darkened(0.2), 2, 14)
	panel.custom_minimum_size = Vector2(430, 0)
	center.add_child(panel)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 10)
	panel.add_child(v)
	dlg_title = _label("", 22, C_ACCENT)
	v.add_child(dlg_title)
	dlg_desc = _label("", 15, C_TEXT)
	dlg_desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	dlg_desc.custom_minimum_size = Vector2(390, 0)
	v.add_child(dlg_desc)
	dlg_ports = _label("", 15, C_MUTED)
	v.add_child(dlg_ports)
	var sep := Control.new()
	sep.custom_minimum_size = Vector2(0, 6)
	v.add_child(sep)
	var b_in := _dlg_button("Eingang drehen")
	b_in.pressed.connect(_on_rotate_in)
	v.add_child(b_in)
	var b_out := _dlg_button("Ausgang drehen")
	b_out.pressed.connect(_on_rotate_out)
	v.add_child(b_out)
	var b_rm := _dlg_button("Entfernen (zurück ins Inventar)")
	_style_button(b_rm, C_DANGER.darkened(0.4))
	b_rm.pressed.connect(_on_remove_block)
	v.add_child(b_rm)
	var b_close := _dlg_button("Schließen")
	b_close.pressed.connect(_close_dialog)
	v.add_child(b_close)


func _open_dialog(c: int, r: int) -> void:
	if gm.board.get_block(c, r) == null:
		return
	dialog_cell = Vector2i(c, r)
	_refresh_dialog()
	dialog_root.visible = true

func _refresh_dialog() -> void:
	var b = gm.board.get_block(dialog_cell.x, dialog_cell.y)
	if b == null:
		_close_dialog()
		return
	dlg_title.text = "%s  [%s]" % [Component.get_type_name(b.type), Component.get_display_char(b.type)]
	dlg_desc.text = Component.get_description(b.type)
	dlg_ports.text = "Eingang: %s %s     Ausgang: %s %s" % [
		Block.arrow(b.in_dir), Block.dir_name(b.in_dir),
		Block.arrow(b.out_dir), Block.dir_name(b.out_dir)]

func _on_dialog_dim_input(e: InputEvent) -> void:
	if e is InputEventMouseButton and e.pressed:
		_close_dialog()

func _close_dialog() -> void:
	dialog_root.visible = false
	dialog_cell = Vector2i(-1, -1)

func _on_rotate_in() -> void:
	var b = gm.board.get_block(dialog_cell.x, dialog_cell.y)
	if b: b.cycle_in()
	_refresh_dialog()
	refresh()

func _on_rotate_out() -> void:
	var b = gm.board.get_block(dialog_cell.x, dialog_cell.y)
	if b: b.cycle_out()
	_refresh_dialog()
	refresh()

func _on_remove_block() -> void:
	var t = gm.board.remove_component(dialog_cell.x, dialog_cell.y)
	if t >= 0 and gm.inventory:
		gm.inventory.add_item(t)
		_set_msg("Zurück ins Inventar: %s" % Component.get_type_name(t))
	_close_dialog()
	refresh()


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
		_set_msg("Wähle zuerst ein Inventar-Item zum Verkaufen.")
	refresh()

func _on_reward_pick(index: int) -> void:
	gm.choose_reward(index)
	refresh()

func _on_cell_info(c: int, r: int) -> void:
	if _animating:
		return
	if gm.board.get_block(c, r) != null:
		_open_dialog(c, r)

func _on_cell_input(event: InputEvent, c: int, r: int) -> void:
	if _animating:
		return
	if not (event is InputEventMouseButton) or not event.pressed:
		return
	if event.button_index != MOUSE_BUTTON_LEFT:
		return
	if gm.phase != gm.GamePhase.BUILD:
		return
	if gm.board.get_block(c, r) == null:
		_try_place(c, r)
	else:
		_open_dialog(c, r)

func _try_place(c: int, r: int) -> void:
	if gm.inventory == null or selected_inv_index < 0:
		_set_msg("Wähle zuerst ein Bauteil im Inventar aus.")
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
		_set_msg("Platziert: %s. Klicke den Block, um Ein-/Ausgang zu drehen." % Component.get_type_name(t))
	else:
		_set_msg("Dieses Feld ist belegt.")
	refresh()

func _on_inv_select(index: int) -> void:
	selected_inv_index = index
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


# Spielt den kompletten Sende-Vorgang ab: pro Paket einmal den Pfad entlang und
# einen Firewall-Treffer. Die Schadens-Anteile summieren sich exakt auf total_damage.
func _play_send(res: Dictionary) -> void:
	var path: Array = res.get("path", [])
	if path.is_empty():
		_set_msg("Kein gültiger Pfad. " + String(res.get("path_error", "")))
		await get_tree().create_timer(0.5).timeout
		return
	var packets = max(1, int(res.get("packets", 1)))
	var total = int(res.get("total_damage", 0))
	var shares = _split_damage(total, packets)
	var hp = fw_bar.value  # HP-Balkenwert vor dem Schaden
	for i in range(packets):
		_set_msg("Paket %d / %d unterwegs …" % [i + 1, packets])
		var target_hp = max(0.0, hp - shares[i])
		await _travel_and_hit(res, shares[i], target_hp, i == 0)
		hp = target_hp


# Verteilt den Gesamtschaden gleichmäßig auf n Pakete (Summe bleibt = total).
func _split_damage(total: int, n: int) -> Array:
	var arr = []
	@warning_ignore("integer_division")
	var base = total / n
	var rem = total - base * n
	for i in range(n):
		arr.append(base + (1 if i < rem else 0))
	return arr

func _cell_center(c: int, r: int) -> Vector2:
	var node: Control = cell_root[r][c]
	return node.global_position + node.size / 2.0

func _make_packet_token(val: int) -> Panel:
	var p := Panel.new()
	p.custom_minimum_size = Vector2(46, 46)
	p.size = Vector2(46, 46)
	p.pivot_offset = Vector2(23, 23)
	p.add_theme_stylebox_override("panel", _sb(C_ACCENT, Color.WHITE, 2, 23, 0))
	p.z_index = 100
	var l := Label.new()
	_full(l)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	l.add_theme_font_size_override("font_size", 18)
	l.add_theme_color_override("font_color", Color.BLACK)
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
	t.tween_property(l, "global_position:y", gpos.y - 36, 0.6)
	t.parallel().tween_property(l, "modulate:a", 0.0, 0.6)
	t.tween_callback(l.queue_free)

# Ein einzelnes Paket: läuft den Pfad entlang, zeigt seinen Schaden und schlägt
# in die Firewall ein (HP-Balken auf target_hp). detailed=true nur beim 1. Paket
# (mit "+X"-Einblendungen), die weiteren laufen schneller und ruhiger.
func _travel_and_hit(res: Dictionary, share: int, target_hp: float, detailed: bool) -> void:
	var path: Array = res.get("path", [])
	if path.is_empty():
		return

	var token := _make_packet_token(int(path[0].before))
	add_child(token)
	var lbl: Label = token.get_child(0)
	token.global_position = _cell_center(path[0].col, path[0].row) - token.size / 2.0

	var step_time = 0.10 if detailed else 0.06
	for step in path:
		var target = _cell_center(step.col, step.row) - token.size / 2.0
		var mt := create_tween()
		mt.tween_property(token, "global_position", target, step_time).set_trans(Tween.TRANS_SINE)
		await mt.finished
		lbl.text = str(int(step.after))
		if detailed and int(step.after) > int(step.before):
			_spawn_float("+%d" % (int(step.after) - int(step.before)), _cell_center(step.col, step.row), C_ACCENT2)

	# Durchbruch sichtbar machen, dann auf den echten Paket-Schaden setzen
	var last = path[path.size() - 1]
	if res.get("reached_end", false) and detailed:
		_spawn_float("Durchbruch!", _cell_center(last.col, last.row) + Vector2(0, -22), C_ACCENT)
	lbl.text = str(share)
	var bt := create_tween()
	bt.tween_property(token, "scale", Vector2(1.35, 1.35), 0.08)
	bt.tween_property(token, "scale", Vector2(1, 1), 0.08)
	await bt.finished

	# In die Firewall schießen
	if fw_bar == null:
		token.queue_free()
		return
	var fw_target = fw_bar.global_position + fw_bar.size / 2.0 - token.size / 2.0
	var ft := create_tween()
	ft.tween_property(token, "global_position", fw_target, 0.20).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	await ft.finished
	token.queue_free()

	# Einschlag: Schadenszahl, Punch, Flash, HP-Balken senken
	_spawn_float("-%d" % share, fw_bar.global_position + Vector2(fw_bar.size.x * 0.5, -8), C_DANGER)
	fw_bar.pivot_offset = fw_bar.size / 2.0
	var punch := create_tween()
	punch.tween_property(fw_bar, "scale", Vector2(1.04, 1.2), 0.05)
	punch.tween_property(fw_bar, "scale", Vector2(1, 1), 0.14)
	if fw_panel:
		var flash := create_tween()
		flash.tween_property(fw_panel, "modulate", Color(1.6, 1.2, 1.2), 0.05)
		flash.tween_property(fw_panel, "modulate", Color(1, 1, 1), 0.18)
	var hp := create_tween()
	hp.tween_property(fw_bar, "value", target_hp, 0.22).set_trans(Tween.TRANS_CUBIC)
	await hp.finished


# =============================================================
#  REFRESH
# =============================================================

func refresh() -> void:
	if gm == null or menu_root == null:
		return

	var phase = gm.phase
	var in_menu = phase == gm.GamePhase.HOMESCREEN
	menu_root.visible = in_menu
	game_root.visible = not in_menu
	shop_root.visible = phase == gm.GamePhase.SHOP
	over_root.visible = phase == gm.GamePhase.GAMEOVER
	reward_root.visible = phase == gm.GamePhase.REWARD
	victory_root.visible = phase == gm.GamePhase.VICTORY
	if dialog_root:
		dialog_root.visible = dialog_root.visible and phase == gm.GamePhase.BUILD

	if in_menu:
		menu_high.text = ("Highscore: %d" % gm.highscore) if gm.highscore > 0 else ""
		return

	# Pfad-Vorschau + Schadens-Vorschau (nur beim Bauen)
	_preview_cells = {}
	_preview_break = Vector2i(-1, -1)
	if phase == gm.GamePhase.BUILD:
		var pv = gm.compute_send()
		var ppath: Array = pv.get("path", [])
		for step in ppath:
			_preview_cells[Vector2i(step.col, step.row)] = true
		if not pv.get("reached_end", false) and not ppath.is_empty():
			var last = ppath[ppath.size() - 1]
			_preview_break = Vector2i(last.col, last.row)
		_update_preview_label(pv)
	else:
		if preview_lbl:
			preview_lbl.text = ""

	# HUD
	lbl_round.text = ("Vorbereitung" if gm.level == 0 else "Level %d/%d  •  Runde %d/%d" % [gm.level, gm.WIN_LEVEL, gm.round_in_level, gm.ROUNDS_PER_LEVEL])
	lbl_money.text = "Geld: %d" % gm.money
	lbl_score.text = "Score: %d" % gm.score

	# Firewall
	if gm.firewall:
		var fw = gm.firewall
		fw_title.text = "FIREWALL  Level %d" % fw.level
		fw_bar.max_value = max(1, fw.max_health)
		fw_bar.value = fw.health
		fw_hp.text = "%d / %d HP   -   %d Pakete/Runde" % [fw.health, fw.max_health, fw.packets_per_round]
		fw_mod.text = ("! %s: %s" % [fw.modifier_name, fw.modifier_desc]) if fw.has_modifier() else ""
	else:
		fw_title.text = "FIREWALL"
		fw_bar.max_value = 1
		fw_bar.value = 0
		fw_hp.text = "- noch keine Runde -"
		fw_mod.text = ""

	_refresh_cells()

	# Hitze (Netzteile + Wärmeleitpaste-Relikt heben das Limit) – gleiche Quelle wie die Berechnung
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

	_refresh_inventory()

	send_btn.disabled = phase != gm.GamePhase.BUILD

	if gm.get("ui_message") != null and gm.ui_message != "":
		_set_msg(gm.ui_message)

	if phase == gm.GamePhase.SHOP:
		_refresh_shop()
	if phase == gm.GamePhase.REWARD:
		_refresh_reward()
	if phase == gm.GamePhase.VICTORY:
		victory_score.text = "Score: %d" % gm.score
	if phase == gm.GamePhase.GAMEOVER:
		over_round.text = "Erreichtes Level: %d / %d" % [gm.level, gm.WIN_LEVEL]
		over_score.text = "Score: %d" % gm.score
		over_high.text = ("* NEUER HIGHSCORE *" if (gm.score >= gm.highscore and gm.score > 0) else "Highscore: %d" % gm.highscore)
	if dialog_root and dialog_root.visible:
		_refresh_dialog()


# Text der Schadens-Vorschau unter dem Senden-Button.
func _update_preview_label(pv: Dictionary) -> void:
	if preview_lbl == null:
		return
	var ppath: Array = pv.get("path", [])
	if ppath.is_empty():
		preview_lbl.add_theme_color_override("font_color", C_DANGER)
		preview_lbl.text = "Kein Pfad: setze in Spalte 0 einen Block mit Eingang nach links."
		return
	var per_packet = int(pv.get("per_packet", 0))
	var packets = int(pv.get("packets", 1))
	var dmg = int(pv.get("total_damage", 0))
	var reached = pv.get("reached_end", false)
	var oh = "  •  ÜBERHITZT" if pv.get("overheated", false) else ""
	var reach_hint = "" if reached else "  (Ziel nicht erreicht)"
	var win = gm.firewall != null and dmg >= gm.firewall.health
	var verdict = "reicht zum Knacken" if win else "reicht NICHT – sonst Game Over"
	preview_lbl.text = "Vorschau: %d × %d Pakete = ~%d Schaden  •  %s%s%s" % [per_packet, packets, dmg, verdict, reach_hint, oh]
	preview_lbl.add_theme_color_override("font_color", C_ACCENT2 if win else C_DANGER)


func _refresh_cells() -> void:
	for r in range(4):
		for c in range(6):
			var panel: Panel = cell_root[r][c]
			var char_lbl: Label = cell_char[r][c]
			var in_lbl: Label = cell_in[r][c]
			var out_lbl: Label = cell_out[r][c]
			var info_btn: Button = cell_info[r][c]
			var b = gm.board.get_block(c, r)
			if b == null:
				panel.add_theme_stylebox_override("panel", _sb(C_CELL, Color(1,1,1,0.06), 1, 8, 0))
				char_lbl.text = ""
				in_lbl.text = ""
				out_lbl.text = ""
				info_btn.visible = false
			else:
				var col: Color = COMP_COLORS.get(b.type, C_PANEL2)
				var key := Vector2i(c, r)
				var border: Color = col.lightened(0.25)
				var bw := 2
				if _preview_break == key:
					border = C_DANGER
					bw = 4
				elif _preview_cells.has(key):
					border = C_ACCENT2
					bw = 4
				panel.add_theme_stylebox_override("panel", _sb(col.darkened(0.1), border, bw, 8, 0))
				char_lbl.text = "%s\n%s" % [Component.get_short_name(b.type), Component.get_label(b.type)]
				in_lbl.text = Block.arrow(b.in_dir)
				in_lbl.add_theme_color_override("font_color", Color(1, 1, 1, 0.45))
				in_lbl.position = _edge_pos(b.in_dir)
				out_lbl.text = Block.arrow(b.out_dir)
				out_lbl.add_theme_color_override("font_color", C_ACCENT)
				out_lbl.position = _edge_pos(b.out_dir)
				info_btn.visible = true


func _refresh_inventory() -> void:
	for child in inv_grid.get_children():
		child.queue_free()
	if gm.inventory == null or gm.inventory.get_item_count() == 0:
		inv_grid.add_child(_label("(leer – im Shop kaufen)", 13, C_MUTED))
		return
	for i in range(gm.inventory.get_item_count()):
		var t = gm.inventory.peek_item(i)
		var b := Button.new()
		b.text = "%s\n%s" % [Component.get_short_name(t), Component.get_label(t)]
		b.custom_minimum_size = Vector2(72, 52)
		b.add_theme_font_size_override("font_size", 13)
		b.tooltip_text = "%s\n%s" % [Component.get_type_name(t), Component.get_description(t)]
		var base: Color = COMP_COLORS.get(t, C_PANEL2)
		if i == selected_inv_index:
			_style_button(b, base.darkened(0.05))
		else:
			_style_button(b, base.darkened(0.5))
		b.pressed.connect(_on_inv_select.bind(i))
		inv_grid.add_child(b)


func _refresh_shop() -> void:
	shop_money.text = "Geld: %d" % gm.money

	# Reroll-Button
	shop_reroll_btn.text = "Neu würfeln (%d G)" % gm.reroll_cost
	shop_reroll_btn.disabled = gm.money < gm.reroll_cost

	# Gesammelte Relikte
	if gm.relics.is_empty():
		shop_relics_lbl.text = "Relikte: (noch keine)"
	else:
		var names = []
		for r in gm.relics:
			names.append(gm.RELIC_NAMES[r])
		shop_relics_lbl.text = "Relikte: " + ", ".join(names)

	for child in shop_offers.get_children():
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
		info.add_child(_label("%s  (%dH)" % [Component.get_type_name(t), Component.get_heat(t)], 16, C_TEXT))
		info.add_child(_label(Component.get_description(t), 12, C_MUTED))
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
