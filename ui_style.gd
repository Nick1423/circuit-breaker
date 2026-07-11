# Circuit Breaker - Zentrale Stil-/Theme-Schicht
#
# Alle Farben und die wiederkehrenden UI-Bau-Helfer an EINER Stelle. So lässt
# sich das komplette Aussehen des Spiels hier anpassen, ohne ui.gd anzufassen.
# Nutzung: UIStyle.label(...), UIStyle.panel(...), UIStyle.style_button(...), ...

class_name UIStyle

# ---- Farbpalette ----
const BG      = Color(0.055, 0.065, 0.09)
const PANEL   = Color(0.10, 0.12, 0.16)
const PANEL2  = Color(0.14, 0.17, 0.22)
const ACCENT  = Color(0.20, 0.85, 0.80)
const ACCENT2 = Color(0.30, 0.85, 0.50)
const DANGER  = Color(0.95, 0.35, 0.35)
const WARN    = Color(0.95, 0.75, 0.25)
const TEXT    = Color(0.90, 0.94, 0.97)
const MUTED   = Color(0.58, 0.64, 0.72)
const CELL    = Color(0.13, 0.15, 0.19)

# Farbe je Bauteil-Typ (zum Unterscheiden auf Board/Shop/Inventar)
const COMP_COLORS = {
	Component.ComponentType.TRACE:     Color(0.45, 0.45, 0.50),  # grau
	Component.ComponentType.CPU:       Color(0.22, 0.55, 0.90),  # blau
	Component.ComponentType.RAM:       Color(0.60, 0.40, 0.85),  # violett
	Component.ComponentType.GPU:       Color(0.90, 0.42, 0.20),  # orange
	Component.ComponentType.NPU:       Color(0.15, 0.75, 0.68),  # türkis
	Component.ComponentType.CACHE:     Color(0.30, 0.80, 0.45),  # grün
	Component.ComponentType.HEATSINK:  Color(0.40, 0.75, 0.95),  # hellblau
	Component.ComponentType.PSU:       Color(0.95, 0.80, 0.25),  # gelb
	Component.ComponentType.MAINBOARD: Color(0.55, 0.62, 0.68),  # stahlgrau
}


# StyleBoxFlat mit Hintergrund, optionalem Rahmen, Rundung und Innenabstand.
static func sb(bg: Color, border_col := Color(0, 0, 0, 0), border_w := 0, radius := 8, pad := 8) -> StyleBoxFlat:
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


static func panel(bg := PANEL, border := PANEL2, bw := 1, radius := 10) -> PanelContainer:
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", sb(bg, border, bw, radius, 12))
	return p


static func label(text := "", fsize := 16, col := TEXT) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", fsize)
	l.add_theme_color_override("font_color", col)
	return l


static func style_button(btn: Button, base: Color, txt := TEXT) -> void:
	btn.add_theme_stylebox_override("normal", sb(base, base.lightened(0.15), 1, 8, 10))
	btn.add_theme_stylebox_override("hover", sb(base.lightened(0.12), ACCENT, 2, 8, 10))
	btn.add_theme_stylebox_override("pressed", sb(base.darkened(0.15), ACCENT, 2, 8, 10))
	btn.add_theme_stylebox_override("disabled", sb(base.darkened(0.4), base.darkened(0.25), 1, 8, 10))
	btn.add_theme_stylebox_override("focus", sb(Color(0, 0, 0, 0)))
	btn.add_theme_color_override("font_color", txt)
	btn.add_theme_color_override("font_hover_color", Color.WHITE)


static func make_bar(fill: Color) -> ProgressBar:
	var b := ProgressBar.new()
	b.show_percentage = false
	b.custom_minimum_size = Vector2(0, 20)
	b.add_theme_stylebox_override("background", sb(Color(0.05, 0.06, 0.08), Color(0, 0, 0, 0), 0, 6, 0))
	b.add_theme_stylebox_override("fill", sb(fill, Color(0, 0, 0, 0), 0, 6, 0))
	return b
