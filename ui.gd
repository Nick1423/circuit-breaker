# Circuit Breaker - Komplette Spiel-UI (klickbar)
# Baut Hauptmenü, HUD, Board-Grid, Bauteil-Palette, Shop und Game-Over
# programmatisch aus Godot-Control-Nodes auf. Kein _draw(), keine Konsole nötig.

extends Control

const Component = preload("res://component.gd")

# ---- Farbpalette (Theme) ----
const C_BG        = Color(0.055, 0.065, 0.09)
const C_PANEL     = Color(0.10, 0.12, 0.16)
const C_PANEL2    = Color(0.14, 0.17, 0.22)
const C_ACCENT    = Color(0.20, 0.85, 0.80)   # Cyan
const C_ACCENT2   = Color(0.30, 0.85, 0.50)   # Grün
const C_DANGER    = Color(0.95, 0.35, 0.35)
const C_WARN      = Color(0.95, 0.75, 0.25)
const C_TEXT      = Color(0.90, 0.94, 0.97)
const C_MUTED     = Color(0.58, 0.64, 0.72)
const C_CELL      = Color(0.13, 0.15, 0.19)

const COMP_COLORS = {
	Component.ComponentType.TRACE: Color(0.45, 0.45, 0.50),
	Component.ComponentType.CPU:   Color(0.20, 0.60, 0.85),
	Component.ComponentType.GPU:   Color(0.85, 0.28, 0.28),
	Component.ComponentType.LOOP:  Color(0.25, 0.80, 0.45),
	Component.ComponentType.NPU:   Color(0.92, 0.62, 0.22),
	Component.ComponentType.RAM:   Color(0.58, 0.38, 0.78),
	Component.ComponentType.CAP:   Color(0.90, 0.80, 0.28),
	Component.ComponentType.OC:    Color(0.95, 0.20, 0.58),
	Component.ComponentType.COOL:  Color(0.32, 0.72, 0.92),
}

const PALETTE_ORDER = [
	Component.ComponentType.CPU, Component.ComponentType.GPU,
	Component.ComponentType.LOOP, Component.ComponentType.NPU,
	Component.ComponentType.RAM, Component.ComponentType.CAP,
	Component.ComponentType.OC, Component.ComponentType.COOL,
	Component.ComponentType.TRACE,
]

var gm = null

# Screens (Top-Level Controls)
var menu_root: Control
var game_root: Control
var shop_root: Control
var over_root: Control

# HUD-Referenzen
var lbl_round: Label
var lbl_money: Label
var lbl_score: Label
var fw_title: Label
var fw_mod: Label
var fw_bar: ProgressBar
var fw_hp: Label
var watt_bar: ProgressBar
var watt_lbl: Label
var heat_bar: ProgressBar
var heat_lbl: Label
var msg_lbl: Label
var send_btn: Button
var inv_box: HBoxContainer
var menu_high: Label

var cell_buttons := []          # cell_buttons[row][col] -> Button
var palette_buttons := {}       # type -> Button

# Shop
var shop_money: Label
var shop_offers: VBoxContainer

# Game Over
var over_round: Label
var over_score: Label
var over_high: Label


func _ready() -> void:
	gm = get_node_or_null("../GameManager")
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_build_background()
	_build_menu()
	_build_game()
	_build_shop()
	_build_over()
	refresh()


# =============================================================
#  STYLE-HELFER
# =============================================================

func _sb(bg: Color, border_col := Color(0,0,0,0), border_w := 0, radius := 8, pad := 8) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	if border_w > 0:
		s.set_border_width_all(border_w)
		s.border_color = border_col
	s.set_corner_radius_all(radius)
	s.content_margin_left = pad
	s.content_margin_right = pad
	s.content_margin_top = pad
	s.content_margin_bottom = pad
	return s

func _panel(bg := C_PANEL, border := C_PANEL2, bw := 1, radius := 10) -> PanelContainer:
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", _sb(bg, border, bw, radius, 12))
	return p

func _label(text := "", size := 16, col := C_TEXT) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", col)
	return l

func _style_button(btn: Button, base: Color, txt := C_TEXT) -> void:
	btn.add_theme_stylebox_override("normal", _sb(base, base.lightened(0.15), 1, 8, 10))
	btn.add_theme_stylebox_override("hover", _sb(base.lightened(0.12), C_ACCENT, 2, 8, 10))
	btn.add_theme_stylebox_override("pressed", _sb(base.darkened(0.15), C_ACCENT, 2, 8, 10))
	btn.add_theme_stylebox_override("disabled", _sb(base.darkened(0.35), base.darkened(0.2), 1, 8, 10))
	btn.add_theme_stylebox_override("focus", _sb(Color(0,0,0,0)))
	btn.add_theme_color_override("font_color", txt)
	btn.add_theme_color_override("font_hover_color", Color.WHITE)

func _make_bar(fill: Color) -> ProgressBar:
	var b := ProgressBar.new()
	b.show_percentage = false
	b.custom_minimum_size = Vector2(0, 20)
	b.add_theme_stylebox_override("background", _sb(Color(0.05,0.06,0.08), Color(0,0,0,0), 0, 6, 0))
	b.add_theme_stylebox_override("fill", _sb(fill, Color(0,0,0,0), 0, 6, 0))
	return b


# =============================================================
#  HINTERGRUND
# =============================================================

func _build_background() -> void:
	var bg := ColorRect.new()
	bg.color = C_BG
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bg)


func _full(node: Control) -> void:
	node.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)


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

	var title := _label(">> CIRCUIT BREAKER <<", 48, C_ACCENT)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(title)

	var sub := _label("Ein Hacker-Platinen-Roguelike", 18, C_MUTED)
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(sub)

	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(0, 20)
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

	var hint := _label("Baue deine Platine, verstärke Datenpakete, knacke die Firewall.", 14, C_MUTED)
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(hint)


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

	# ---- Top-Bar ----
	var topbar := _panel(C_PANEL, C_ACCENT.darkened(0.3), 1, 10)
	root_v.add_child(topbar)
	var top_h := HBoxContainer.new()
	top_h.add_theme_constant_override("separation", 24)
	topbar.add_child(top_h)

	var brand := _label("CIRCUIT BREAKER", 20, C_ACCENT)
	top_h.add_child(brand)

	var top_spacer := Control.new()
	top_spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top_h.add_child(top_spacer)

	lbl_round = _label("Runde 1", 18, C_TEXT)
	lbl_money = _label("Geld: 0", 18, C_WARN)
	lbl_score = _label("Score: 0", 18, C_ACCENT2)
	top_h.add_child(lbl_round)
	top_h.add_child(_sep_v())
	top_h.add_child(lbl_money)
	top_h.add_child(_sep_v())
	top_h.add_child(lbl_score)

	var menu_btn := Button.new()
	menu_btn.text = "Menü"
	menu_btn.add_theme_font_size_override("font_size", 15)
	_style_button(menu_btn, C_PANEL2)
	menu_btn.pressed.connect(func(): gm.show_homescreen())
	top_h.add_child(_sep_v())
	top_h.add_child(menu_btn)

	# ---- Mitte: links Board, rechts Palette ----
	var mid := HBoxContainer.new()
	mid.add_theme_constant_override("separation", 16)
	mid.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root_v.add_child(mid)

	# LINKE SPALTE
	var left := VBoxContainer.new()
	left.add_theme_constant_override("separation", 12)
	left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	mid.add_child(left)

	# Firewall-Panel
	var fw_panel := _panel(C_PANEL, C_DANGER.darkened(0.3), 1, 10)
	left.add_child(fw_panel)
	var fw_v := VBoxContainer.new()
	fw_v.add_theme_constant_override("separation", 6)
	fw_panel.add_child(fw_v)
	var fw_top := HBoxContainer.new()
	fw_title = _label("FIREWALL", 17, C_DANGER)
	fw_top.add_child(fw_title)
	var fw_sp := Control.new()
	fw_sp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	fw_top.add_child(fw_sp)
	fw_mod = _label("", 14, C_WARN)
	fw_top.add_child(fw_mod)
	fw_v.add_child(fw_top)
	fw_bar = _make_bar(C_DANGER)
	fw_bar.custom_minimum_size = Vector2(0, 22)
	fw_v.add_child(fw_bar)
	fw_hp = _label("", 13, C_MUTED)
	fw_v.add_child(fw_hp)

	# Board-Grid
	var board_center := CenterContainer.new()
	board_center.size_flags_vertical = Control.SIZE_EXPAND_FILL
	left.add_child(board_center)
	var grid := GridContainer.new()
	grid.columns = 6
	grid.add_theme_constant_override("h_separation", 6)
	grid.add_theme_constant_override("v_separation", 6)
	board_center.add_child(grid)

	cell_buttons.clear()
	for r in range(4):
		var row_arr := []
		for c in range(6):
			var b := Button.new()
			b.custom_minimum_size = Vector2(88, 88)
			b.add_theme_font_size_override("font_size", 30)
			b.pressed.connect(_on_cell.bind(c, r))
			grid.add_child(b)
			row_arr.append(b)
		cell_buttons.append(row_arr)

	# Ressourcen-Bars (Watt + Hitze)
	var res_panel := _panel(C_PANEL, C_PANEL2, 1, 10)
	left.add_child(res_panel)
	var res_h := HBoxContainer.new()
	res_h.add_theme_constant_override("separation", 20)
	res_panel.add_child(res_h)

	var watt_v := VBoxContainer.new()
	watt_v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	watt_lbl = _label("Watt 0/10", 14, C_ACCENT)
	watt_v.add_child(watt_lbl)
	watt_bar = _make_bar(C_ACCENT)
	watt_v.add_child(watt_bar)
	res_h.add_child(watt_v)

	var heat_v := VBoxContainer.new()
	heat_v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	heat_lbl = _label("Hitze 0/7", 14, C_WARN)
	heat_v.add_child(heat_lbl)
	heat_bar = _make_bar(C_WARN)
	heat_v.add_child(heat_bar)
	res_h.add_child(heat_v)

	# RECHTE SPALTE (Palette + Senden + Log)
	var right := VBoxContainer.new()
	right.add_theme_constant_override("separation", 12)
	right.custom_minimum_size = Vector2(340, 0)
	mid.add_child(right)

	var pal_panel := _panel(C_PANEL, C_ACCENT.darkened(0.4), 1, 10)
	right.add_child(pal_panel)
	var pal_v := VBoxContainer.new()
	pal_v.add_theme_constant_override("separation", 8)
	pal_panel.add_child(pal_v)
	pal_v.add_child(_label("BAUTEILE  (auswählen → Feld klicken)", 14, C_ACCENT))
	var pal_grid := GridContainer.new()
	pal_grid.columns = 3
	pal_grid.add_theme_constant_override("h_separation", 8)
	pal_grid.add_theme_constant_override("v_separation", 8)
	pal_v.add_child(pal_grid)
	for t in PALETTE_ORDER:
		var pb := Button.new()
		pb.custom_minimum_size = Vector2(0, 54)
		pb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		pb.add_theme_font_size_override("font_size", 13)
		pb.text = "%s\n%dW %dH" % [Component.get_type_name(t), Component.get_watt_cost(t), Component.get_heat(t)]
		pb.tooltip_text = Component.get_description(t)
		pb.pressed.connect(_on_palette.bind(t))
		_style_button(pb, COMP_COLORS[t].darkened(0.45))
		pal_grid.add_child(pb)
		palette_buttons[t] = pb

	# Inventar
	var inv_panel := _panel(C_PANEL, C_PANEL2, 1, 10)
	right.add_child(inv_panel)
	var inv_v := VBoxContainer.new()
	inv_v.add_theme_constant_override("separation", 6)
	inv_panel.add_child(inv_v)
	inv_v.add_child(_label("INVENTAR", 14, C_MUTED))
	inv_box = HBoxContainer.new()
	inv_box.add_theme_constant_override("separation", 6)
	inv_v.add_child(inv_box)

	# Senden
	send_btn = Button.new()
	send_btn.text = ">  PAKETE SENDEN"
	send_btn.custom_minimum_size = Vector2(0, 56)
	send_btn.add_theme_font_size_override("font_size", 20)
	_style_button(send_btn, C_ACCENT2.darkened(0.35))
	send_btn.pressed.connect(_on_send)
	right.add_child(send_btn)

	# Log / Meldung
	var msg_panel := _panel(Color(0.08,0.09,0.12), C_PANEL2, 1, 10)
	msg_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	right.add_child(msg_panel)
	msg_lbl = _label("Wähle ein Bauteil und klicke ein Feld.", 14, C_MUTED)
	msg_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	msg_lbl.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	msg_panel.add_child(msg_lbl)


func _sep_v() -> Label:
	return _label("|", 16, C_MUTED)


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

	v.add_child(_label("Gekaufte Bauteile landen im Inventar.", 14, C_MUTED))

	shop_offers = VBoxContainer.new()
	shop_offers.add_theme_constant_override("separation", 8)
	shop_offers.size_flags_vertical = Control.SIZE_EXPAND_FILL
	v.add_child(shop_offers)

	var next_btn := Button.new()
	next_btn.text = "Nächste Runde  >"
	next_btn.custom_minimum_size = Vector2(0, 50)
	next_btn.add_theme_font_size_override("font_size", 20)
	_style_button(next_btn, C_ACCENT2.darkened(0.35))
	next_btn.pressed.connect(_on_next)
	v.add_child(next_btn)


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
#  SIGNAL-HANDLER
# =============================================================

func _on_play() -> void:
	gm.start_new_run()
	refresh()

func _on_menu() -> void:
	gm.show_homescreen()
	refresh()

func _on_palette(t) -> void:
	gm.selected_component = t
	_set_msg("Ausgewählt: %s — %s" % [Component.get_type_name(t), Component.get_description(t)])
	refresh()

func _on_cell(col: int, row: int) -> void:
	if gm.phase != gm.GamePhase.BUILD:
		return
	var comp = gm.board.get_component(col, row)
	if comp == null:
		var ok = gm.board.place_component(col, row, gm.selected_component)
		if ok:
			gm.stats.components_placed += 1
			_set_msg("Platziert: %s bei (%d,%d)" % [Component.get_type_name(gm.selected_component), col, row])
		else:
			_set_msg("Kann hier nicht platzieren (Watt-Budget zu klein?).")
	else:
		gm.board.remove_component(col, row)
		_set_msg("Entfernt bei (%d,%d)." % [col, row])
	refresh()

func _on_send() -> void:
	if gm.phase != gm.GamePhase.BUILD:
		return
	gm.send_all_packets()
	refresh()

func _on_buy(index: int) -> void:
	gm.buy_component(index)
	refresh()

func _on_next() -> void:
	if gm.phase == gm.GamePhase.SHOP:
		gm.start_round()
		refresh()

func _set_msg(t: String) -> void:
	if msg_lbl:
		msg_lbl.text = t


# =============================================================
#  REFRESH – aktualisiert alles nach Spielzustand
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

	if in_menu:
		if gm.highscore > 0:
			menu_high.text = "Highscore: %d" % gm.highscore
		else:
			menu_high.text = ""
		return

	# HUD
	lbl_round.text = "Runde %d" % gm.current_round
	lbl_money.text = "Geld: %d" % gm.money
	lbl_score.text = "Score: %d" % gm.score

	# Firewall
	if gm.firewall:
		var fw = gm.firewall
		fw_title.text = "FIREWALL  Level %d" % fw.level
		fw_bar.max_value = max(1, fw.max_health)
		fw_bar.value = fw.health
		fw_hp.text = "%d / %d HP   •   %d Pakete/Runde" % [fw.health, fw.max_health, fw.packets_per_round]
		if fw.has_modifier():
			fw_mod.text = "! %s: %s" % [fw.modifier_name, fw.modifier_desc]
		else:
			fw_mod.text = ""

	# Board-Zellen
	for r in range(4):
		for c in range(6):
			var b: Button = cell_buttons[r][c]
			var comp = gm.board.get_component(c, r)
			if comp == null:
				b.text = ""
				b.add_theme_stylebox_override("normal", _sb(C_CELL, Color(1,1,1,0.06), 1, 8, 0))
				b.add_theme_stylebox_override("hover", _sb(C_CELL.lightened(0.12), C_ACCENT, 2, 8, 0))
				b.add_theme_stylebox_override("pressed", _sb(C_CELL.darkened(0.1), C_ACCENT, 2, 8, 0))
			else:
				var col: Color = COMP_COLORS[comp]
				b.text = Component.get_display_char(comp)
				b.add_theme_color_override("font_color", Color.WHITE)
				b.add_theme_stylebox_override("normal", _sb(col.darkened(0.1), col.lightened(0.2), 2, 8, 0))
				b.add_theme_stylebox_override("hover", _sb(col, C_DANGER, 2, 8, 0))
				b.add_theme_stylebox_override("pressed", _sb(col.darkened(0.2), C_DANGER, 2, 8, 0))

	# Watt-Bar
	var used_w = gm.board.get_used_watt()
	watt_bar.max_value = max(1, gm.board.watt_budget)
	watt_bar.value = used_w
	watt_lbl.text = "Watt  %d / %d" % [used_w, gm.board.watt_budget]

	# Hitze-Bar
	var heat = gm.board.get_total_heat()
	var hlimit = gm.firewall.heat_limit if gm.firewall else 7
	heat_bar.max_value = max(1, hlimit)
	heat_bar.value = min(heat, hlimit)
	if heat > hlimit:
		heat_lbl.text = "Hitze  %d / %d  ! ÜBERHITZT" % [heat, hlimit]
		heat_lbl.add_theme_color_override("font_color", C_DANGER)
		heat_bar.add_theme_stylebox_override("fill", _sb(C_DANGER, Color(0,0,0,0), 0, 6, 0))
	else:
		heat_lbl.text = "Hitze  %d / %d" % [heat, hlimit]
		heat_lbl.add_theme_color_override("font_color", C_WARN)
		heat_bar.add_theme_stylebox_override("fill", _sb(C_WARN, Color(0,0,0,0), 0, 6, 0))

	# Palette-Highlight
	for t in palette_buttons:
		var pb: Button = palette_buttons[t]
		if t == gm.selected_component:
			_style_button(pb, COMP_COLORS[t].darkened(0.1))
		else:
			_style_button(pb, COMP_COLORS[t].darkened(0.5))

	# Inventar
	for child in inv_box.get_children():
		child.queue_free()
	if gm.inventory and gm.inventory.get_item_count() > 0:
		for i in range(gm.inventory.get_item_count()):
			var it = gm.inventory.peek_item(i)
			var ib := Button.new()
			ib.text = Component.get_display_char(it)
			ib.custom_minimum_size = Vector2(38, 38)
			ib.add_theme_font_size_override("font_size", 18)
			ib.tooltip_text = Component.get_type_name(it)
			_style_button(ib, COMP_COLORS[it].darkened(0.35))
			ib.pressed.connect(_on_palette.bind(it))
			inv_box.add_child(ib)
	else:
		inv_box.add_child(_label("(leer)", 13, C_MUTED))

	# Senden nur in Bau-Phase
	send_btn.disabled = phase != gm.GamePhase.BUILD

	# ui_message vom GameManager übernehmen
	if gm.get("ui_message") != null and gm.ui_message != "":
		_set_msg(gm.ui_message)

	# Shop
	if phase == gm.GamePhase.SHOP:
		_refresh_shop()

	# Game Over
	if phase == gm.GamePhase.GAMEOVER:
		over_round.text = "Erreichte Runde: %d" % gm.current_round
		over_score.text = "Score: %d" % gm.score
		if gm.score >= gm.highscore and gm.score > 0:
			over_high.text = "* NEUER HIGHSCORE *"
		else:
			over_high.text = "Highscore: %d" % gm.highscore


func _refresh_shop() -> void:
	shop_money.text = "Geld: %d" % gm.money
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
		row.add_theme_stylebox_override("panel", _sb(C_PANEL2, COMP_COLORS[t].darkened(0.2), 1, 8, 8))
		var h := HBoxContainer.new()
		h.add_theme_constant_override("separation", 12)
		row.add_child(h)

		var swatch := _label(Component.get_display_char(t), 22, Color.WHITE)
		swatch.custom_minimum_size = Vector2(34, 0)
		h.add_child(swatch)

		var info := VBoxContainer.new()
		info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		info.add_child(_label("%s  (%dW, %dH)" % [Component.get_type_name(t), Component.get_watt_cost(t), Component.get_heat(t)], 16, C_TEXT))
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
