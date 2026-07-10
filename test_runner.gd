# Circuit Breaker - COMPLETE Test Suite
# Testet JEDE Funktion, JEDEN Randfall, JEDE Kombination
# Stand: v2.0 - Vollständige Abdeckung

extends Node

const Component = preload("res://component.gd")
const Firewall = preload("res://firewall.gd")
const Packet = preload("res://packet.gd")
const Shop = preload("res://shop.gd")
const ScoreSystem = preload("res://score_system.gd")

var tests_passed: int = 0
var tests_failed: int = 0
var test_count: int = 0


func _ready() -> void:
	var sep = ""
	for i in range(60):
		sep += "="
	print(sep)
	print("  CIRCUIT BREAKER - KOMPLETTE TEST SUITE v2.0")
	print(sep)
	print()
	
	var start_time = Time.get_ticks_msec()
	
	run_all_tests()
	
	var duration = Time.get_ticks_msec() - start_time
	var total = tests_passed + tests_failed
	
	print(sep)
	print("  E N D E R G E B N I S")
	print(sep)
	print("  Bestanden: ", tests_passed, "/", total)
	print("  Fehlgeschlagen: ", tests_failed, "/", total)
	print("  Dauer: ", duration, "ms")
	print()
	
	if tests_failed == 0:
		print("  ✅  A L L E  ", total, "  T E S T S  B E S T A N D E N !")
	else:
		print("  ❌  ", tests_failed, "  T E S T S  F E H L G E S C H L A G E N !")
	
	print(sep)


func run_all_tests() -> void:
	# =============================================
	#  KATEGORIE 1: BOARD-GRUNDLAGEN (14 Tests)
	# =============================================
	_TC("Board-Grundlagen")
	tc_board_init_6x4()
	tc_board_init_empty()
	tc_board_init_watt_zero()
	tc_board_place_cpu()
	tc_board_place_gpu()
	tc_board_place_loop()
	tc_board_place_trace()
	tc_board_place_npu()
	tc_board_place_all_types()
	tc_board_place_out_of_bounds_negative()
	tc_board_place_out_of_bounds_too_high()
	tc_board_place_out_of_bounds_col_too_high()
	tc_board_place_out_of_bounds_row_too_high()
	tc_board_place_on_occupied_fails()

	# =============================================
	#  KATEGORIE 2: BOARD-ENTFERNEN & LEEREN (8 Tests)
	# =============================================
	_TC("Board-Entfernen")
	tc_board_remove_component()
	tc_board_remove_empty_fails()
	tc_board_remove_out_of_bounds()
	tc_board_remove_updates_watt()
	tc_board_clear_board()
	tc_board_clear_empty_board()
	tc_board_clear_all_empty()
	tc_board_clear_watt_zero()

	# =============================================
	#  KATEGORIE 3: BOARD-HILFSFUNKTIONEN (8 Tests)
	# =============================================
	_TC("Board-Hilfsfunktionen")
	tc_board_get_available_24()
	tc_board_get_available_after_place()
	tc_board_get_available_after_remove()
	tc_board_get_available_full_board()
	tc_board_get_all_components_empty()
	tc_board_get_all_components_count()
	tc_board_get_all_components_types()
	tc_board_get_all_components_positions()

	# =============================================
	#  KATEGORIE 4: WATT-BUDGET (10 Tests)
	# =============================================
	_TC("Watt-Budget")
	tc_watt_budget_0()
	tc_watt_budget_exact()
	tc_watt_budget_exceeded()
	tc_watt_budget_mixed()
	tc_watt_budget_remove_frees()
	tc_watt_budget_after_clear()
	tc_watt_budget_change_budget()
	tc_watt_budget_all_types_sum()
	tc_watt_budget_zero_watt_components()
	tc_watt_budget_max_components()

	# =============================================
	#  KATEGORIE 5: KOMPONENTEN-FUNKTIONEN (20 Tests)
	# =============================================
	_TC("Komponenten-Funktionen")
	tc_comp_name_trace()
	tc_comp_name_cpu()
	tc_comp_name_gpu()
	tc_comp_name_loop()
	tc_comp_name_npu()
	tc_comp_name_invalid()
	tc_comp_watt_trace()
	tc_comp_watt_cpu()
	tc_comp_watt_gpu()
	tc_comp_watt_loop()
	tc_comp_watt_npu()
	tc_comp_watt_invalid()
	tc_comp_display_all()
	tc_comp_display_invalid()
	tc_comp_desc_all()
	tc_comp_desc_invalid()
	tc_comp_process_trace()
	tc_comp_process_cpu()
	tc_comp_process_gpu()
	tc_comp_process_loop()

	# =============================================
	#  KATEGORIE 6: PAKETFLUSS-EINZELN (12 Tests)
	# =============================================
	_TC("Paketfluss einzeln")
	tc_flow_empty_row()
	tc_flow_empty_all_rows()
	tc_flow_cpu_each_row()
	tc_flow_gpu_each_row()
	tc_flow_loop_each_row()
	tc_flow_trace_no_change()
	tc_flow_npu_no_neighbors()
	tc_flow_multiple_cpus()
	tc_flow_multiple_gpus()
	tc_flow_cpu_then_gpu_12()
	tc_flow_gpu_then_cpu_7()
	tc_flow_order_matters()

	# =============================================
	#  KATEGORIE 7: PAKETFLUSS-KOMBINATIONEN (12 Tests)
	# =============================================
	_TC("Paketfluss Kombos")
	tc_flow_full_chain_34()
	tc_flow_max_cpu_row()
	tc_flow_alternating()
	tc_flow_cpu_gpu_cpu()
	tc_flow_gpu_cpu_gpu()
	tc_flow_all_same_row()
	tc_flow_loop_then_gpu()
	tc_flow_cpu_then_loop()
	tc_flow_npu_with_cpu_neighbor()
	tc_flow_npu_two_cpu_neighbors()
	tc_flow_npu_no_cpu_neighbor_zero()
	tc_flow_all_five_types_row()

	# =============================================
	#  KATEGORIE 8: FIREWALL (12 Tests)
	# =============================================
	_TC("Firewall")
	tc_firewall_level_1()
	tc_firewall_level_5()
	tc_firewall_level_10()
	tc_firewall_take_damage_partial()
	tc_firewall_take_damage_exact()
	tc_firewall_take_damage_overkill()
	tc_firewall_destroyed()
	tc_firewall_not_destroyed()
	tc_firewall_is_alive_true()
	tc_firewall_is_alive_false()
	tc_firewall_reset()
	tc_firewall_level_scaling()

	# =============================================
	#  KATEGORIE 9: NPU-SPEZIAL (6 Tests)
	# =============================================
	_TC("NPU Spezial")
	tc_npu_0_neighbors()
	tc_npu_1_cpu_left()
	tc_npu_1_cpu_right()
	tc_npu_1_cpu_top()
	tc_npu_1_cpu_bottom()
	tc_npu_2_cpus()

	# =============================================
	#  KATEGORIE 10: SHOP (8 Tests)
	# =============================================
	_TC("Shop")
	tc_shop_create()
	tc_shop_empty_offers()
	tc_shop_generate_count()
	tc_shop_generate_valid()
	tc_shop_buy_success()
	tc_shop_buy_no_money()
	tc_shop_buy_invalid()
	tc_shop_buy_removes_offer()

	# =============================================
	#  KATEGORIE 11: SCORE-SYSTEM (10 Tests)
	# =============================================
	_TC("Score-System")
	tc_score_init()
	tc_score_add_money()
	tc_score_add_money_multiple()
	tc_score_spend_money()
	tc_score_spend_exact()
	tc_score_insufficient()
	tc_score_add_score()
	tc_score_add_score_multiple()
	tc_score_stats_damage()
	tc_score_reset()

	# =============================================
	#  KATEGORIE 12: GAME-MANAGER-PHASEN (6 Tests)
	# =============================================
	_TC("GameManager Phasen")
	tc_gm_phase_homescreen()
	tc_gm_phase_build()
	tc_gm_phase_shop()
	tc_gm_phase_gameover()
	tc_gm_round_increment()
	tc_gm_money_increases()

	# =============================================
	#  KATEGORIE 13: PAKET-KLASSE (4 Tests)
	# =============================================
	_TC("Paket-Klasse")
	tc_packet_create()
	tc_packet_value_1()
	tc_packet_reset()
	tc_packet_describe()


# =====================================================
#  TEST-AUSFÜHRUNG
# =====================================================

var _current_category: String = ""

func _TC(category: String) -> void:
	print("\n--- ", category, " ---")


# =============================================
#  KATEGORIE 1: BOARD-GRUNDLAGEN
# =============================================

func tc_board_init_6x4() -> void:
	var b = _board()
	_assert(b.BOARD_WIDTH == 6, "Board Breite = 6")
	_assert(b.BOARD_HEIGHT == 4, "Board Höhe = 4")

func tc_board_init_empty() -> void:
	var b = _board()
	var empty = true
	for r in range(4):
		for c in range(6):
			if b.get_component(c, r) != null:
				empty = false
	_assert(empty, "Alle 24 Felder initial leer")

func tc_board_init_watt_zero() -> void:
	_assert(_board().get_used_watt() == 0, "Start Watt = 0")

func tc_board_place_cpu() -> void:
	var b = _board()
	var ok = b.place_component(0, 0, Component.ComponentType.CPU)
	_assert(ok, "CPU platzierbar")
	_assert(b.get_component(0, 0) == Component.ComponentType.CPU, "Feld enthält CPU")

func tc_board_place_gpu() -> void:
	var b = _board()
	var ok = b.place_component(5, 3, Component.ComponentType.GPU)
	_assert(ok, "GPU platzierbar (Ecke)")
	_assert(b.get_component(5, 3) == Component.ComponentType.GPU, "Feld enthält GPU")

func tc_board_place_loop() -> void:
	var b = _board()
	_assert(b.place_component(3, 2, Component.ComponentType.LOOP), "Loop platzierbar")

func tc_board_place_trace() -> void:
	var b = _board()
	_assert(b.place_component(1, 1, Component.ComponentType.TRACE), "Trace platzierbar")

func tc_board_place_npu() -> void:
	var b = _board()
	_assert(b.place_component(4, 0, Component.ComponentType.NPU), "NPU platzierbar")

func tc_board_place_all_types() -> void:
	var b = _board()
	var all = true
	all = all and b.place_component(0,0, Component.ComponentType.CPU)
	all = all and b.place_component(1,0, Component.ComponentType.GPU)
	all = all and b.place_component(2,0, Component.ComponentType.LOOP)
	all = all and b.place_component(3,0, Component.ComponentType.TRACE)
	all = all and b.place_component(4,0, Component.ComponentType.NPU)
	_assert(all, "Alle 5 Typen platzierbar")

func tc_board_place_out_of_bounds_negative() -> void:
	_assert(not _board().place_component(-1, 0, Component.ComponentType.CPU), "col=-1: false")

func tc_board_place_out_of_bounds_too_high() -> void:
	_assert(not _board().place_component(0, 10, Component.ComponentType.CPU), "row=10: false")

func tc_board_place_out_of_bounds_col_too_high() -> void:
	_assert(not _board().place_component(10, 0, Component.ComponentType.CPU), "col=10: false")

func tc_board_place_out_of_bounds_row_too_high() -> void:
	_assert(not _board().place_component(0, 4, Component.ComponentType.CPU), "row=4: false (max 3)")

func tc_board_place_on_occupied_fails() -> void:
	var b = _board()
	b.place_component(2, 2, Component.ComponentType.GPU)
	_assert(not b.place_component(2, 2, Component.ComponentType.CPU), "Belegt: false")
	_assert(b.get_component(2, 2) == Component.ComponentType.GPU, "Original erhalten")


# =============================================
#  KATEGORIE 2: BOARD-ENTFERNEN & LEEREN
# =============================================

func tc_board_remove_component() -> void:
	var b = _board()
	b.place_component(1, 1, Component.ComponentType.LOOP)
	_assert(b.remove_component(1, 1), "Entfernen: true")
	_assert(b.get_component(1, 1) == null, "Feld wieder null")

func tc_board_remove_empty_fails() -> void:
	_assert(not _board().remove_component(0, 0), "Leer entfernen: false")

func tc_board_remove_out_of_bounds() -> void:
	_assert(not _board().remove_component(-1, 5), "Out-of-bounds entfernen: false")

func tc_board_remove_updates_watt() -> void:
	var b = _board()
	b.place_component(0, 0, Component.ComponentType.GPU)  # 5W
	_assert(b.get_used_watt() == 5, "Nach Platzieren: 5W")
	b.remove_component(0, 0)
	_assert(b.get_used_watt() == 0, "Nach Entfernen: 0W")

func tc_board_clear_board() -> void:
	var b = _board()
	b.place_component(0, 0, Component.ComponentType.CPU)
	b.place_component(5, 3, Component.ComponentType.GPU)
	b.clear_board()
	var empty = true
	for r in range(4):
		for c in range(6):
			if b.get_component(c, r) != null: empty = false
	_assert(empty, "Nach clear: alles leer")

func tc_board_clear_empty_board() -> void:
	var b = _board()
	b.clear_board()
	var empty = true
	for r in range(4):
		for c in range(6):
			if b.get_component(c, r) != null: empty = false
	_assert(empty, "Clear leer: bleibt leer")

func tc_board_clear_all_empty() -> void:
	var b = _board()
	b.place_component(0,0, Component.ComponentType.CPU)
	b.place_component(1,1, Component.ComponentType.GPU)
	b.place_component(2,2, Component.ComponentType.LOOP)
	b.place_component(3,3, Component.ComponentType.NPU)
	b.clear_board()
	var empty = true
	for r in range(4):
		for c in range(6):
			if b.get_component(c, r) != null: empty = false
	_assert(empty, "Clear 4 Komponenten: leer")

func tc_board_clear_watt_zero() -> void:
	var b = _board()
	b.place_component(0, 0, Component.ComponentType.GPU)
	b.clear_board()
	_assert(b.get_used_watt() == 0, "Nach clear: 0 Watt")


# =============================================
#  KATEGORIE 3: BOARD-HILFSFUNKTIONEN
# =============================================

func tc_board_get_available_24() -> void:
	_assert(_board().get_available_positions().size() == 24, "24 freie Positionen")

func tc_board_get_available_after_place() -> void:
	var b = _board()
	b.place_component(0, 0, Component.ComponentType.CPU)
	_assert(b.get_available_positions().size() == 23, "23 freie nach 1 Platzierung")

func tc_board_get_available_after_remove() -> void:
	var b = _board()
	b.place_component(0, 0, Component.ComponentType.CPU)
	b.remove_component(0, 0)
	_assert(b.get_available_positions().size() == 24, "24 freie nach entfernen")

func tc_board_get_available_full_board() -> void:
	var b = _board()
	for r in range(4):
		for c in range(6):
			b.place_component(c, r, Component.ComponentType.TRACE)
	_assert(b.get_available_positions().size() == 0, "0 freie bei vollem Brett")
	b.clear_board()

func tc_board_get_all_components_empty() -> void:
	_assert(_board().get_all_components().size() == 0, "0 Komponenten bei leerem Brett")

func tc_board_get_all_components_count() -> void:
	var b = _board()
	b.place_component(0, 0, Component.ComponentType.CPU)
	b.place_component(5, 3, Component.ComponentType.GPU)
	_assert(b.get_all_components().size() == 2, "2 Komponenten gefunden")

func tc_board_get_all_components_types() -> void:
	var b = _board()
	b.place_component(0, 0, Component.ComponentType.NPU)
	var all = b.get_all_components()
	_assert(all[0].type == Component.ComponentType.NPU, "NPU Typ korrekt")

func tc_board_get_all_components_positions() -> void:
	var b = _board()
	b.place_component(3, 2, Component.ComponentType.LOOP)
	var all = b.get_all_components()
	_assert(all[0].col == 3, "col = 3")
	_assert(all[0].row == 2, "row = 2")


# =============================================
#  KATEGORIE 4: WATT-BUDGET
# =============================================

func tc_watt_budget_0() -> void:
	var b = _board()
	b.watt_budget = 0
	_assert(not b.place_component(0, 0, Component.ComponentType.CPU), "Budget 0: CPU false")

func tc_watt_budget_exact() -> void:
	var b = _board()
	b.watt_budget = 10
	var ok = b.place_component(0, 0, Component.ComponentType.GPU)  # 5W
	ok = ok and b.place_component(1, 0, Component.ComponentType.GPU)  # 5W = 10
	_assert(ok, "2 GPUs = 10W: true")
	_assert(b.get_used_watt() == 10, "Verbrauch = 10")

func tc_watt_budget_exceeded() -> void:
	var b = _board()
	b.watt_budget = 10
	b.place_component(0, 0, Component.ComponentType.GPU)  # 5W
	b.place_component(1, 0, Component.ComponentType.GPU)  # 10W
	_assert(not b.place_component(2, 0, Component.ComponentType.GPU), "3. GPU: false")
	_assert(b.get_used_watt() == 10, "Verbrauch bleibt 10")

func tc_watt_budget_mixed() -> void:
	var b = _board()
	b.watt_budget = 10
	# CPU(2) + GPU(5) + LOOP(3) = 10
	var ok = b.place_component(0, 0, Component.ComponentType.CPU)
	ok = ok and b.place_component(1, 0, Component.ComponentType.GPU)
	ok = ok and b.place_component(2, 0, Component.ComponentType.LOOP)
	_assert(ok, "CPU+GPU+LOOP=10W: true")
	_assert(not b.place_component(3, 0, Component.ComponentType.TRACE), "Trace=0W, aber Budget=10 passt nicht?") 
	# TRACE kostet 0, also sollte es gehen! Mal prüfen:
	var b2 = _board()
	b2.watt_budget = 10
	b2.place_component(0,0, Component.ComponentType.CPU)  # 2W
	b2.place_component(1,0, Component.ComponentType.GPU)   # 5W = 7W
	b2.place_component(2,0, Component.ComponentType.LOOP)  # 3W = 10W
	_assert(b2.place_component(3,0, Component.ComponentType.TRACE), "TRACE=0W geht immer")

func tc_watt_budget_remove_frees() -> void:
	var b = _board()
	b.watt_budget = 10
	b.place_component(0, 0, Component.ComponentType.GPU)  # 5W
	b.place_component(1, 0, Component.ComponentType.GPU)  # 10W
	b.remove_component(1, 0)  # -5W = 5W
	_assert(b.get_used_watt() == 5, "Nach remove: 5W")
	_assert(b.place_component(2, 0, Component.ComponentType.GPU), "GPU again: true (5+5=10)")

func tc_watt_budget_after_clear() -> void:
	var b = _board()
	b.watt_budget = 10
	b.place_component(0, 0, Component.ComponentType.GPU)
	b.clear_board()
	_assert(b.get_used_watt() == 0, "Nach clear: 0W")
	_assert(b.place_component(0, 0, Component.ComponentType.GPU), "Wieder platzierbar: true")

func tc_watt_budget_change_budget() -> void:
	var b = _board()
	b.watt_budget = 5
	b.place_component(0, 0, Component.ComponentType.GPU)
	b.watt_budget = 2
	_assert(not b.place_component(1, 0, Component.ComponentType.GPU), "Nach Reduzierung: false")
	_assert(b.get_used_watt() == 5, "Verbrauch bleibt 5 (nicht angepasst)")

func tc_watt_budget_all_types_sum() -> void:
	var b = _board()
	b.watt_budget = 100
	b.place_component(0,0, Component.ComponentType.TRACE)  # 0
	b.place_component(1,0, Component.ComponentType.CPU)     # 2
	b.place_component(2,0, Component.ComponentType.GPU)     # 5
	b.place_component(3,0, Component.ComponentType.LOOP)    # 3
	b.place_component(4,0, Component.ComponentType.NPU)     # 4
	_assert(b.get_used_watt() == 14, "5 Typen: 0+2+5+3+4 = 14W")

func tc_watt_budget_zero_watt_components() -> void:
	var b = _board()
	b.watt_budget = 0
	_assert(b.place_component(0, 0, Component.ComponentType.TRACE), "TRACE=0W geht bei Budget 0")

func tc_watt_budget_max_components() -> void:
	var b = _board()
	b.watt_budget = 100
	var count = 0
	for r in range(4):
		for c in range(6):
			if b.place_component(c, r, Component.ComponentType.TRACE):
				count += 1
	_assert(count == 24, "Alle 24 Felder mit TRACE (0W) belegbar")


# =============================================
#  KATEGORIE 5: KOMPONENTEN-FUNKTIONEN
# =============================================

func tc_comp_name_trace() -> void:
	_assert(Component.get_type_name(Component.ComponentType.TRACE) == "Leiterbahn", "TRACE Name")

func tc_comp_name_cpu() -> void:
	_assert(Component.get_type_name(Component.ComponentType.CPU) == "CPU", "CPU Name")

func tc_comp_name_gpu() -> void:
	_assert(Component.get_type_name(Component.ComponentType.GPU) == "GPU", "GPU Name")

func tc_comp_name_loop() -> void:
	_assert(Component.get_type_name(Component.ComponentType.LOOP) == "Loop", "LOOP Name")

func tc_comp_name_npu() -> void:
	_assert(Component.get_type_name(Component.ComponentType.NPU) == "NPU", "NPU Name")

func tc_comp_name_invalid() -> void:
	_assert(Component.get_type_name(-1) == "Unbekannt", "Ungültiger Typ: Unbekannt")

func tc_comp_watt_trace() -> void:
	_assert(Component.get_watt_cost(Component.ComponentType.TRACE) == 0, "TRACE: 0W")

func tc_comp_watt_cpu() -> void:
	_assert(Component.get_watt_cost(Component.ComponentType.CPU) == 2, "CPU: 2W")

func tc_comp_watt_gpu() -> void:
	_assert(Component.get_watt_cost(Component.ComponentType.GPU) == 5, "GPU: 5W")

func tc_comp_watt_loop() -> void:
	_assert(Component.get_watt_cost(Component.ComponentType.LOOP) == 3, "LOOP: 3W")

func tc_comp_watt_npu() -> void:
	_assert(Component.get_watt_cost(Component.ComponentType.NPU) == 4, "NPU: 4W")

func tc_comp_watt_invalid() -> void:
	_assert(Component.get_watt_cost(-1) == 0, "Ungültig: 0W")

func tc_comp_display_all() -> void:
	_assert(Component.get_display_char(Component.ComponentType.TRACE) == "=", "TRACE: =")
	_assert(Component.get_display_char(Component.ComponentType.CPU) == "C", "CPU: C")
	_assert(Component.get_display_char(Component.ComponentType.GPU) == "G", "GPU: G")
	_assert(Component.get_display_char(Component.ComponentType.LOOP) == "L", "LOOP: L")
	_assert(Component.get_display_char(Component.ComponentType.NPU) == "N", "NPU: N")

func tc_comp_display_invalid() -> void:
	_assert(Component.get_display_char(-1) == "?", "Ungültig: ?")

func tc_comp_desc_all() -> void:
	_assert(Component.get_description(Component.ComponentType.TRACE) != "", "TRACE Desc")
	_assert(Component.get_description(Component.ComponentType.CPU) != "", "CPU Desc")
	_assert(Component.get_description(Component.ComponentType.GPU) != "", "GPU Desc")
	_assert(Component.get_description(Component.ComponentType.LOOP) != "", "LOOP Desc")
	_assert(Component.get_description(Component.ComponentType.NPU) != "", "NPU Desc")

func tc_comp_desc_invalid() -> void:
	_assert(Component.get_description(-1) == "", "Ungültig: leer")

func tc_comp_process_trace() -> void:
	_assert(Component.process_packet(Component.ComponentType.TRACE, 10, null) == 10, "TRACE: kein Change")

func tc_comp_process_cpu() -> void:
	_assert(Component.process_packet(Component.ComponentType.CPU, 1, null) == 6, "CPU: 1+5=6")
	_assert(Component.process_packet(Component.ComponentType.CPU, 10, null) == 15, "CPU: 10+5=15")

func tc_comp_process_gpu() -> void:
	_assert(Component.process_packet(Component.ComponentType.GPU, 1, null) == 2, "GPU: 1*2=2")
	_assert(Component.process_packet(Component.ComponentType.GPU, 10, null) == 20, "GPU: 10*2=20")

func tc_comp_process_loop() -> void:
	_assert(Component.process_packet(Component.ComponentType.LOOP, 1, null) == 2, "LOOP: 1*2=2")
	_assert(Component.process_packet(Component.ComponentType.LOOP, 10, null) == 20, "LOOP: 10*2=20")


# =============================================
#  KATEGORIE 6: PAKETFLUSS-EINZELN
# =============================================

func tc_flow_empty_row() -> void:
	var b = _board()
	_assert(b.simulate_packet_flow(0) == 1, "Leere Zeile 0: 1")
	_assert(b.simulate_packet_flow(1) == 1, "Leere Zeile 1: 1")
	_assert(b.simulate_packet_flow(2) == 1, "Leere Zeile 2: 1")
	_assert(b.simulate_packet_flow(3) == 1, "Leere Zeile 3: 1")

func tc_flow_empty_all_rows() -> void:
	var b = _board()
	for r in range(4):
		_assert(b.simulate_packet_flow(r) == 1, "Zeile "+str(r)+": 1")

func tc_flow_cpu_each_row() -> void:
	for r in range(4):
		var b = _board()
		b.place_component(0, r, Component.ComponentType.CPU)
		_assert(b.simulate_packet_flow(r) == 6, "CPU Zeile "+str(r)+": 6")
		b.clear_board()

func tc_flow_gpu_each_row() -> void:
	for r in range(4):
		var b = _board()
		b.place_component(0, r, Component.ComponentType.GPU)
		_assert(b.simulate_packet_flow(r) == 2, "GPU Zeile "+str(r)+": 2")
		b.clear_board()

func tc_flow_loop_each_row() -> void:
	for r in range(4):
		var b = _board()
		b.place_component(0, r, Component.ComponentType.LOOP)
		_assert(b.simulate_packet_flow(r) == 2, "LOOP Zeile "+str(r)+": 2")
		b.clear_board()

func tc_flow_trace_no_change() -> void:
	var b = _board()
	b.place_component(0, 0, Component.ComponentType.TRACE)
	_assert(b.simulate_packet_flow(0) == 1, "TRACE: 1 (kein Change)")

func tc_flow_npu_no_neighbors() -> void:
	var b = _board()
	b.place_component(0, 0, Component.ComponentType.NPU)
	_assert(b.simulate_packet_flow(0) == 1, "NPU ohne Nachbarn: 1")

func tc_flow_multiple_cpus() -> void:
	var b = _board()
	for c in range(3):
		b.place_component(c, 0, Component.ComponentType.CPU)
	# 1+5+5+5 = 16
	_assert(b.simulate_packet_flow(0) == 16, "3 CPUs: 1+5+5+5 = 16")

func tc_flow_multiple_gpus() -> void:
	var b = _board()
	b.place_component(0, 0, Component.ComponentType.GPU)
	b.place_component(1, 0, Component.ComponentType.GPU)
	# 1*2*2 = 4
	_assert(b.simulate_packet_flow(0) == 4, "2 GPUs: 1*2*2 = 4")

func tc_flow_cpu_then_gpu_12() -> void:
	var b = _board()
	b.place_component(0, 0, Component.ComponentType.CPU)
	b.place_component(1, 0, Component.ComponentType.GPU)
	# (1+5)*2 = 12
	_assert(b.simulate_packet_flow(0) == 12, "CPU->GPU: 12")

func tc_flow_gpu_then_cpu_7() -> void:
	var b = _board()
	b.place_component(0, 0, Component.ComponentType.GPU)
	b.place_component(1, 0, Component.ComponentType.CPU)
	# (1*2)+5 = 7
	_assert(b.simulate_packet_flow(0) == 7, "GPU->CPU: 7")

func tc_flow_order_matters() -> void:
	var b1 = _board()
	b1.place_component(0, 0, Component.ComponentType.CPU)
	b1.place_component(1, 0, Component.ComponentType.GPU)
	var r1 = b1.simulate_packet_flow(0)
	var b2 = _board()
	b2.place_component(0, 0, Component.ComponentType.GPU)
	b2.place_component(1, 0, Component.ComponentType.CPU)
	var r2 = b2.simulate_packet_flow(0)
	_assert(r1 != r2, "Reihenfolge wichtig: "+str(r1)+" vs "+str(r2))
	_assert(r1 == 12, "CPU->GPU=12")
	_assert(r2 == 7, "GPU->CPU=7")


# =============================================
#  KATEGORIE 7: PAKETFLUSS-KOMBINATIONEN
# =============================================

func tc_flow_full_chain_34() -> void:
	var b = _board()
	b.place_component(0, 0, Component.ComponentType.CPU)
	b.place_component(1, 0, Component.ComponentType.GPU)
	b.place_component(2, 0, Component.ComponentType.CPU)
	b.place_component(3, 0, Component.ComponentType.GPU)
	# ((1+5)*2+5)*2 = 34
	_assert(b.simulate_packet_flow(0) == 34, "CPU->GPU->CPU->GPU: 34")

func tc_flow_max_cpu_row() -> void:
	var b = _board()
	for c in range(6):
		b.place_component(c, 0, Component.ComponentType.CPU)
	# 1 + 6*5 = 31
	_assert(b.simulate_packet_flow(0) == 31, "6 CPUs: 1+30 = 31")

func tc_flow_alternating() -> void:
	var b = _board()
	b.place_component(0, 0, Component.ComponentType.CPU)
	b.place_component(1, 0, Component.ComponentType.GPU)
	b.place_component(2, 0, Component.ComponentType.CPU)
	# ((1+5)*2)+5 = 17
	_assert(b.simulate_packet_flow(0) == 17, "CPU->GPU->CPU: 17")

func tc_flow_cpu_gpu_cpu() -> void:
	var b = _board()
	b.place_component(0, 0, Component.ComponentType.CPU)
	b.place_component(1, 0, Component.ComponentType.GPU)
	b.place_component(2, 0, Component.ComponentType.CPU)
	_assert(b.simulate_packet_flow(0) == 17, "CPU->GPU->CPU: 17")

func tc_flow_gpu_cpu_gpu() -> void:
	var b = _board()
	b.place_component(0, 0, Component.ComponentType.GPU)
	b.place_component(1, 0, Component.ComponentType.CPU)
	b.place_component(2, 0, Component.ComponentType.GPU)
	_assert(b.simulate_packet_flow(0) == 14, "GPU->CPU->GPU: (1*2+5)*2 = 14")

func tc_flow_all_same_row() -> void:
	var b = _board()
	b.place_component(0, 0, Component.ComponentType.CPU)
	b.place_component(1, 0, Component.ComponentType.CPU)
	b.place_component(2, 0, Component.ComponentType.CPU)
	_assert(b.simulate_packet_flow(0) == 16, "3 CPUs: 16")

func tc_flow_loop_then_gpu() -> void:
	var b = _board()
	b.place_component(0, 0, Component.ComponentType.LOOP)
	b.place_component(1, 0, Component.ComponentType.GPU)
	_assert(b.simulate_packet_flow(0) == 4, "LOOP->GPU: (1*2)*2 = 4")

func tc_flow_cpu_then_loop() -> void:
	var b = _board()
	b.place_component(0, 0, Component.ComponentType.CPU)
	b.place_component(1, 0, Component.ComponentType.LOOP)
	_assert(b.simulate_packet_flow(0) == 12, "CPU->LOOP: (1+5)*2 = 12")

func tc_flow_npu_with_cpu_neighbor() -> void:
	var b = _board()
	b.place_component(0, 0, Component.ComponentType.CPU)
	b.place_component(1, 0, Component.ComponentType.NPU)
	# CPU: 1+5=6, NPU+3=9
	_assert(b.simulate_packet_flow(0) == 9, "CPU->NPU: (1+5)+3 = 9")

func tc_flow_npu_two_cpu_neighbors() -> void:
	var b = _board()
	b.place_component(0, 0, Component.ComponentType.CPU)
	b.place_component(1, 0, Component.ComponentType.NPU)
	b.place_component(2, 0, Component.ComponentType.CPU)
	# 1+5=6, NPU+6=12, +5=17
	_assert(b.simulate_packet_flow(0) == 17, "CPU->NPU->CPU: 17")

func tc_flow_npu_no_cpu_neighbor_zero() -> void:
	var b = _board()
	b.place_component(1, 0, Component.ComponentType.NPU)
	_assert(b.simulate_packet_flow(0) == 1, "NPU allein: 1 (kein Bonus)")

func tc_flow_all_five_types_row() -> void:
	var b = _board()
	b.place_component(0, 0, Component.ComponentType.CPU)   # +5
	b.place_component(1, 0, Component.ComponentType.GPU)   # *2
	b.place_component(2, 0, Component.ComponentType.LOOP)  # *2
	b.place_component(3, 0, Component.ComponentType.TRACE) # =
	b.place_component(4, 0, Component.ComponentType.NPU)   # kein CPU-Nachbar
	# ((1+5)*2*2)+0+0 = 24
	_assert(b.simulate_packet_flow(0) == 24, "CPU->GPU->LOOP->TRACE->NPU: 24")


# =============================================
#  KATEGORIE 8: FIREWALL
# =============================================

func tc_firewall_level_1() -> void:
	var f = Firewall.new(1)
	_assert(f.level == 1, "Level=1")
	_assert(f.max_health == 15, "HP=10+5=15")
	_assert(f.reward_watt == 3, "Reward=2+1=3")
	_assert(f.packets_per_round == 3, "Pakete=3+0=3")

func tc_firewall_level_5() -> void:
	var f = Firewall.new(5)
	_assert(f.max_health == 35, "L5 HP=10+25=35")
	_assert(f.reward_watt == 7, "L5 Reward=2+5=7")
	_assert(f.packets_per_round == 5, "L5 Pakete=3+2=5")

func tc_firewall_level_10() -> void:
	var f = Firewall.new(10)
	_assert(f.max_health == 60, "L10 HP=10+50=60")
	_assert(f.reward_watt == 12, "L10 Reward=2+10=12")
	_assert(f.packets_per_round == 8, "L10 Pakete=3+5=8")

func tc_firewall_take_damage_partial() -> void:
	var f = Firewall.new(1)
	f.take_damage(5)
	_assert(f.health == 10, "15-5=10 HP")
	_assert(f.is_alive(), "Noch alive")

func tc_firewall_take_damage_exact() -> void:
	var f = Firewall.new(1)
	var dead = f.take_damage(15)
	_assert(dead, "Genau 15: destroyed")
	_assert(f.health == 0, "HP=0")

func tc_firewall_take_damage_overkill() -> void:
	var f = Firewall.new(1)
	var dead = f.take_damage(100)
	_assert(dead, "Overkill: destroyed")
	_assert(f.health == 0, "HP=0 (nicht negativ)")

func tc_firewall_destroyed() -> void:
	var f = Firewall.new(1)
	_assert(f.take_damage(15), "destroyed=true")

func tc_firewall_not_destroyed() -> void:
	var f = Firewall.new(1)
	_assert(not f.take_damage(14), "14 Schaden: nicht destroyed")

func tc_firewall_is_alive_true() -> void:
	_assert(Firewall.new(1).is_alive(), "Neue FW: alive")

func tc_firewall_is_alive_false() -> void:
	var f = Firewall.new(1)
	f.take_damage(15)
	_assert(not f.is_alive(), "Nach Zerstörung: nicht alive")

func tc_firewall_reset() -> void:
	var f = Firewall.new(3)
	f.take_damage(20)
	f.reset()
	_assert(f.health == f.max_health, "Nach Reset: HP=MaxHP")

func tc_firewall_level_scaling() -> void:
	for l in range(1, 11):
		var f = Firewall.new(l)
		_assert(f.max_health == 10 + l*5, "L"+str(l)+" HP="+str(10+l*5))
		_assert(f.packets_per_round == 3 + floor(l/2), "L"+str(l)+" Pakete="+str(3+floor(l/2)))


# =============================================
#  KATEGORIE 9: NPU-SPEZIAL
# =============================================

func _npu_test_setup(npu_col: int, npu_row: int, cpu_positions: Array) -> int:
	var b = _board()
	b.place_component(0, 0, Component.ComponentType.TRACE)  # Dummy zum Aufwärmen
	b.clear_board()
	
	b.place_component(npu_col, npu_row, Component.ComponentType.NPU)
	for pos in cpu_positions:
		b.place_component(pos[0], pos[1], Component.ComponentType.CPU)
	return b.simulate_packet_flow(npu_row)

func tc_npu_0_neighbors() -> void:
	_assert(_npu_test_setup(0, 0, []) == 1, "NPU, keine Nachbarn: 1")

func tc_npu_1_cpu_left() -> void:
	var result = _npu_test_setup(1, 0, [[0, 0]])  # CPU links, NPU rechts
	# Paket fließt: CPU(1+5=6) → NPU(6+3=9)
	_assert(result == 9, "CPU links von NPU: 6+3=9")

func tc_npu_1_cpu_right() -> void:
	var result = _npu_test_setup(0, 0, [[1, 0]])  # NPU links, CPU rechts
	# Paket fließt: NPU(1+0=1) → CPU(1+5=6)
	_assert(result == 6, "CPU rechts von NPU: 1+5=6")

func tc_npu_1_cpu_top() -> void:
	var b = _board()
	b.place_component(0, 1, Component.ComponentType.CPU)  # oben (andere Zeile)
	b.place_component(0, 0, Component.ComponentType.NPU)  # unten
	_assert(b.simulate_packet_flow(0) == 4, "CPU über NPU (andere Zeile): NPU+3=4")  # 1+3=4

func tc_npu_1_cpu_bottom() -> void:
	var b = _board()
	b.place_component(0, 0, Component.ComponentType.CPU)  # oben
	b.place_component(0, 1, Component.ComponentType.NPU)  # unten (2. Zeile)
	_assert(b.simulate_packet_flow(0) == 6, "CPU (Zeile0): 6")
	_assert(b.simulate_packet_flow(1) == 4, "NPU unter CPU (Zeile1): NPU+3=4")

func tc_npu_2_cpus() -> void:
	var b = _board()
	b.place_component(0, 0, Component.ComponentType.CPU)
	b.place_component(1, 0, Component.ComponentType.NPU)
	b.place_component(2, 0, Component.ComponentType.CPU)
	# CPU(6) → NPU(6+6=12) → CPU(12+5=17)
	_assert(b.simulate_packet_flow(0) == 17, "CPU-NPU-CPU: 17")


# =============================================
#  KATEGORIE 10: SHOP
# =============================================

func tc_shop_create() -> void:
	var s = Shop.new()
	_assert(s != null, "Shop erstellbar")

func tc_shop_empty_offers() -> void:
	_assert(Shop.new().get_offer_count() == 0, "Neuer Shop: 0 Angebote")

func tc_shop_generate_count() -> void:
	var s = Shop.new()
	for r in [1, 3, 5, 10]:
		s.generate_offerings(r)
		var count = s.get_offer_count()
		_assert(count >= 3 and count <= 5, "Runde "+str(r)+": "+str(count)+" Angebote (3-5)")

func tc_shop_generate_valid() -> void:
	var s = Shop.new()
	s.generate_offerings(1)
	for i in range(s.get_offer_count()):
		var offer = s.get_offer(i)
		_assert(offer != null, "Angebot "+str(i)+": nicht null")
		_assert(offer.price > 0, "Angebot "+str(i)+": Preis > 0")
		_assert(offer.name != "", "Angebot "+str(i)+": Name nicht leer")

func tc_shop_buy_success() -> void:
	var s = Shop.new()
	s.generate_offerings(1)
	var result = s.buy(0, 999)
	_assert(result.success, "Kauf erfolgreich")
	_assert(result.has("component_type"), "Hat component_type")
	_assert(result.has("price"), "Hat price")

func tc_shop_buy_no_money() -> void:
	var s = Shop.new()
	s.generate_offerings(1)
	var result = s.buy(0, 0)
	_assert(not result.success, "Kein Geld: fehlgeschlagen")

func tc_shop_buy_invalid() -> void:
	var s = Shop.new()
	s.generate_offerings(1)
	var result = s.buy(999, 999)
	_assert(not result.success, "Ungültiger Index: fehlgeschlagen")

func tc_shop_buy_removes_offer() -> void:
	var s = Shop.new()
	s.generate_offerings(1)
	var before = s.get_offer_count()
	s.buy(0, 999)
	_assert(s.get_offer_count() == before - 1, "Angebot entfernt: " + str(before) + " -> " + str(s.get_offer_count()))


# =============================================
#  KATEGORIE 11: SCORE-SYSTEM
# =============================================

func tc_score_init() -> void:
	var sc = ScoreSystem.new()
	_assert(sc.money == 5, "Startgeld=5")
	_assert(sc.score == 0, "Score=0")
	_assert(sc.highscore == 0, "Highscore=0")

func tc_score_add_money() -> void:
	var sc = ScoreSystem.new()
	sc.add_money(10)
	_assert(sc.money == 15, "5+10=15")

func tc_score_add_money_multiple() -> void:
	var sc = ScoreSystem.new()
	sc.add_money(1)
	sc.add_money(2)
	sc.add_money(3)
	_assert(sc.money == 11, "5+1+2+3=11")

func tc_score_spend_money() -> void:
	var sc = ScoreSystem.new()
	_assert(sc.spend_money(3), "3 ausgeben: true")
	_assert(sc.money == 2, "5-3=2")

func tc_score_spend_exact() -> void:
	var sc = ScoreSystem.new()
	_assert(sc.spend_money(5), "5 ausgeben (alles): true")
	_assert(sc.money == 0, "5-5=0")

func tc_score_insufficient() -> void:
	var sc = ScoreSystem.new()
	_assert(not sc.spend_money(999), "999: false")
	_assert(sc.money == 5, "Geld unverändert: 5")

func tc_score_add_score() -> void:
	var sc = ScoreSystem.new()
	sc.add_score(50)
	_assert(sc.score == 50, "Score=50")
	_assert(sc.stats.total_damage == 50, "Damage=50")

func tc_score_add_score_multiple() -> void:
	var sc = ScoreSystem.new()
	sc.add_score(10)
	sc.add_score(20)
	sc.add_score(30)
	_assert(sc.score == 60, "10+20+30=60")

func tc_score_stats_damage() -> void:
	var sc = ScoreSystem.new()
	sc.add_score(100)
	sc.count_firewall_destroyed()
	sc.count_placement()
	sc.count_packet(42)
	_assert(sc.stats.total_damage == 100, "Damage=100")
	_assert(sc.stats.firewalls_destroyed == 1, "FW=1")
	_assert(sc.stats.components_placed == 1, "Placed=1")
	_assert(sc.stats.packets_sent == 1, "Packets=1")
	_assert(sc.stats.best_single_packet == 42, "Best=42")

func tc_score_reset() -> void:
	var sc = ScoreSystem.new()
	sc.add_money(50)
	sc.add_score(200)
	sc.reset_run()
	_assert(sc.money == 5, "Reset Geld=5")
	_assert(sc.score == 0, "Reset Score=0")
	_assert(sc.stats.total_damage == 0, "Reset Damage=0")


# =============================================
#  KATEGORIE 12: GAME-MANAGER-PHASEN
# =============================================

func tc_gm_phase_homescreen() -> void:
	var gm = _gm()
	_assert(gm.phase == gm.GamePhase.HOMESCREEN, "Start: HOMESCREEN")

func tc_gm_phase_build() -> void:
	var gm = _gm()
	gm.start_new_run()
	_assert(gm.phase == gm.GamePhase.BUILD, "Nach start: BUILD")
	_assert(gm.current_round == 1, "Runde 1")

func tc_gm_phase_shop() -> void:
	var gm = _gm()
	gm.start_new_run()
	gm._on_firewall_destroyed()
	_assert(gm.phase == gm.GamePhase.SHOP, "Nach FW besiegt: SHOP")

func tc_gm_phase_gameover() -> void:
	var gm = _gm()
	gm.show_game_over()
	_assert(gm.phase == gm.GamePhase.GAMEOVER, "show_game_over: GAMEOVER")

func tc_gm_round_increment() -> void:
	var gm = _gm()
	gm.start_new_run()
	_assert(gm.current_round == 1, "Runde 1")
	gm._on_firewall_destroyed()
	gm.start_round()
	_assert(gm.current_round == 2, "Runde 2")

func tc_gm_money_increases() -> void:
	var gm = _gm()
	gm.start_new_run()
	var money_before = gm.money
	gm._on_firewall_destroyed()
	_assert(gm.money > money_before, "Geld gestiegen nach FW besiegt")


# =============================================
#  KATEGORIE 13: PAKET-KLASSE
# =============================================

func tc_packet_create() -> void:
	var p = Packet.new()
	_assert(p != null, "Packet erstellbar")

func tc_packet_value_1() -> void:
	_assert(Packet.new().value == 1, "Startwert=1")

func tc_packet_reset() -> void:
	var p = Packet.new()
	p.value = 99
	p.reset()
	_assert(p.value == 1, "Nach Reset: 1")

func tc_packet_describe() -> void:
	var p = Packet.new()
	var d = p.describe()
	_assert(d.length() > 0, "describe() liefert Text")


# =============================================
#  HILFSFUNKTIONEN
# =============================================

func _board():
	var b = load("res://board.gd").new()
	b._init_board()
	b.watt_budget = 10
	return b

func _gm():
	var gm = load("res://game_manager.gd").new()
	return gm

func _assert(condition: bool, message: String) -> void:
	test_count += 1
	if condition:
		tests_passed += 1
		print("  ✅ [", test_count, "] ", message)
	else:
		tests_failed += 1
		print("  ❌ [", test_count, "] ", message, " (FEHLGESCHLAGEN!)")