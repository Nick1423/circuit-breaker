# Circuit Breaker - Komplette Spiel-UI (klickbar, mit Ports & Animation)
#
# Ablauf: Menü -> Shop (Bausteine kaufen) -> Bau-Phase (aus Inventar platzieren,
# Ein-/Ausgänge per Popup drehen) -> Pakete senden (animiert) -> Shop -> ...
#
# Pakete laufen links rein, folgen den Ausgängen von Block zu Block und müssen
# den rechten Rand erreichen (Durchbruch-Bonus). Alles wird über refresh()
# aus dem GameManager-Zustand aktualisiert.

extends Control

const Component = preload("res://component.gd")
const Block = preload("res://block.gd")

# ---- Farbpalette ----
const C_BG      = Color(0.055, 0.065, 0.09)
const C_PANEL   = Color(0.10, 0.12, 0.16)
const C_PANEL2  = Color(0.14, 0.17, 0.22)
const C_ACCENT  = Color(0.20, 0.85, 0.80)
const C_ACCENT2 = Color(0.30, 0.85, 0.50)
const C_DANGER  = Color(0.95, 0.35, 0.35)
const C_WARN    = Color(0.95, 0.75, 0.25)
const C_TEXT    = Color(0.90, 0.94, 0.97)
const C_MUTED   = Color(0.58, 0.64, 0.72)
const C_CELL    = Color(0.13, 0.15, 0.19)

const CELL_SIZE := 90

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

# Dialog
var dlg_title: Label
var dlg_desc: Label
var dlg_ports: Label
var dialog_cell := Vector2i(-1, -1)

# Zustand
var selected_inv_index := -1
var _animating := false


func _ready() -> void:
	gm = get_node_or_null("../GameManager")
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_build_background()
	_build_menu()
	_build_game()
	_build_shop()
	_build_over()
	_build_dialog()
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
	btn.add_theme_stylebox_override("disabled", _sb(base.darkened(0.4), base.darkened(0.25), 1, 8, 10))
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

	var fw_panel := _panel(C_PANEL, C_DANGER.darkened(0.3), 1, 10)
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
	var grid := GridContainer.new()
	grid.columns = 6
	grid.add_theme_constant_override("h_separation", 6)
	grid.add_theme_constant_override("v_separation", 6)
	board_center.add_child(grid)
	_build_cells(grid)

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
			char_lbl.add_theme_font_size_override("font_size", 30)
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
		gm.start_round()
		refresh()

func _on_buy(index: int) -> void:
	gm.buy_component(index)
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
	await _animate_packet(res)
	_animating = false
	gm.apply_send(res)
	refresh()

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

func _animate_packet(res: Dictionary) -> void:
	var path: Array = res.get("path", [])
	if path.is_empty():
		_set_msg("Kein gültiger Pfad. " + String(res.get("path_error", "")))
		await get_tree().create_timer(0.4).timeout
		return

	var token := _make_packet_token(1)
	add_child(token)
	var lbl: Label = token.get_child(0)
	var first = path[0]
	token.global_position = _cell_center(first.col, first.row) - token.size / 2.0
	lbl.text = str(int(first.before))

	for step in path:
		var target = _cell_center(step.col, step.row) - token.size / 2.0
		var mt := create_tween()
		mt.tween_property(token, "global_position", target, 0.22).set_trans(Tween.TRANS_SINE)
		await mt.finished
		var after := int(step.after)
		var before := int(step.before)
		lbl.text = str(after)
		if after > before:
			_spawn_float("+%d" % (after - before), _cell_center(step.col, step.row), C_ACCENT2)
			var pt := create_tween()
			pt.tween_property(token, "scale", Vector2(1.3, 1.3), 0.08)
			pt.tween_property(token, "scale", Vector2(1, 1), 0.08)
			await pt.finished

	if res.get("reached_end", false):
		var last = path[path.size() - 1]
		var off = _cell_center(last.col, last.row) - token.size / 2.0 + Vector2(150, 0)
		var et := create_tween()
		et.tween_property(token, "global_position", off, 0.28)
		et.parallel().tween_property(token, "modulate:a", 0.0, 0.28)
		await et.finished
	else:
		await get_tree().create_timer(0.15).timeout

	token.queue_free()


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
	if dialog_root:
		dialog_root.visible = dialog_root.visible and phase == gm.GamePhase.BUILD

	if in_menu:
		menu_high.text = ("Highscore: %d" % gm.highscore) if gm.highscore > 0 else ""
		return

	# HUD
	lbl_round.text = ("Vorbereitung" if gm.current_round == 0 else "Runde %d" % gm.current_round)
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

	# Hitze
	var heat = gm.board.get_total_heat()
	var hlimit = gm.firewall.heat_limit if gm.firewall else 7
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
	if phase == gm.GamePhase.GAMEOVER:
		over_round.text = "Erreichte Runde: %d" % gm.current_round
		over_score.text = "Score: %d" % gm.score
		over_high.text = ("* NEUER HIGHSCORE *" if (gm.score >= gm.highscore and gm.score > 0) else "Highscore: %d" % gm.highscore)
	if dialog_root and dialog_root.visible:
		_refresh_dialog()


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
				panel.add_theme_stylebox_override("panel", _sb(col.darkened(0.1), col.lightened(0.25), 2, 8, 0))
				char_lbl.text = Component.get_display_char(b.type)
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
		b.text = Component.get_display_char(t)
		b.custom_minimum_size = Vector2(56, 48)
		b.add_theme_font_size_override("font_size", 20)
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
		h.add_child(_label(Component.get_display_char(t), 22, Color.WHITE))
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
