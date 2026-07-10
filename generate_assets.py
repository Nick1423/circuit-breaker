#!/usr/bin/env python3
"""
=============================================================================
 CIRCUIT BREAKER - PROFESSIONAL ASSET GENERATOR
 Erstellt hochwertige Pixel-Art-Grafiken für ein Hacker/Platinen-Spiel.
 
 KEINE externen Tools nötig! Nur Python 3 + Pillow.

 Installiere: pip install Pillow
 Starten:    python generate_assets.py

 Ergebnis:   60+ professionelle Assets in assets/
=============================================================================
"""

import os
import math
import random
from enum import Enum

try:
    from PIL import Image, ImageDraw, ImageFont, ImageFilter, ImageOps
    HAS_PIL = True
except ImportError:
    HAS_PIL = False
    print("❌ Pillow nicht installiert!")
    print("   Installiere: pip install Pillow")
    print("   Oder: python -m pip install Pillow")
    exit(1)


# =============================================
#  KONFIGURATION
# =============================================

ASSETS_DIR = "assets"
T_SIZE = 128  # Kachelgröße (hochauflösend für scharfe Pixel-Art)
ICON_S = 48   # Icon-Größe
BTN_W = 220   # Button-Breite
BTN_H = 56    # Button-Höhe

# =============================================
#  HOCHWERTIGE FARBPALETTE
#  Cyberpunk/Hacker-Theme mit Neon-Akzenten
# =============================================

C = {
    # === HINTERGRÜNDE ===
    "bg_deep":      (8, 8, 14),       # Tiefschwarz mit Blaustich
    "bg_dark":      (12, 14, 22),     # Sehr dunkel
    "bg_panel":     (18, 20, 32),     # Panel-Hintergrund
    "bg_card":      (22, 26, 40),     # Karten-Hintergrund
    "bg_tile":      (16, 18, 30),     # Leere Kachel
    "bg_tile_grid": (20, 22, 34),     # Kachel mit Gitter

    # === CPU - EISBLAU ===
    "cpu_base":     (30, 100, 200),
    "cpu_mid":      (50, 150, 240),
    "cpu_high":     (100, 200, 255),
    "cpu_glow":     (150, 230, 255),
    "cpu_dark":     (15, 50, 120),
    "cpu_pin":      (180, 220, 255),
    
    # === GPU - HELLROT ===
    "gpu_base":     (200, 30, 40),
    "gpu_mid":      (240, 60, 70),
    "gpu_high":     (255, 120, 120),
    "gpu_glow":     (255, 180, 180),
    "gpu_dark":     (120, 10, 20),
    "gpu_fan":      (180, 180, 190),
    
    # === LOOP - NEONGRÜN ===
    "loop_base":    (20, 160, 80),
    "loop_mid":     (40, 220, 110),
    "loop_high":    (100, 255, 160),
    "loop_glow":    (160, 255, 200),
    "loop_dark":    (10, 80, 40),
    "loop_arrow":   (200, 255, 220),
    
    # === NPU - GOLD/ORANGE ===
    "npu_base":     (200, 130, 30),
    "npu_mid":      (240, 170, 50),
    "npu_high":     (255, 210, 100),
    "npu_glow":     (255, 230, 160),
    "npu_dark":     (120, 70, 10),
    "npu_node":     (255, 220, 130),
    
    # === TRACE - SILBER ===
    "trace_base":   (90, 95, 110),
    "trace_mid":    (130, 135, 150),
    "trace_high":   (180, 185, 200),
    "trace_dark":   (50, 52, 65),
    "trace_line":   (60, 200, 140),   # Leiterbahn-Grün
    
    # === NEON AKZENTE ===
    "neon_cyan":    (0, 255, 255),
    "neon_pink":    (255, 0, 128),
    "neon_green":   (0, 255, 100),
    "neon_yellow":  (255, 220, 0),
    "neon_blue":    (60, 100, 255),
    "neon_red":     (255, 30, 30),
    "neon_orange":  (255, 140, 0),
    "neon_purple":  (160, 40, 255),
    
    # === UI ===
    "text_white":   (220, 225, 235),
    "text_bright":  (180, 190, 210),
    "text_dim":     (100, 110, 130),
    "text_dark":    (60, 66, 80),
    "gold":         (255, 200, 50),
    "gold_dark":    (180, 130, 10),
    "green":        (50, 220, 100),
    "green_dark":   (20, 120, 50),
    "red":          (220, 50, 50),
    "red_dark":     (120, 20, 20),
    "firewall":     (200, 20, 60),
    "firewall_glow":(255, 60, 100),
    "firewall_dark":(100, 10, 30),
    
    # === PAKET ===
    "packet_base":  (60, 200, 255),
    "packet_glow":  (150, 240, 255),
    "packet_core":  (255, 255, 255),
    
    # === LEITERBAHNEN ===
    "circuit":      (30, 200, 130),
    "circuit_dim":  (15, 100, 65),
    "circuit_bright":(80, 255, 180),
    
    # === SCHATTEN ===
    "shadow":       (0, 0, 0, 100),
    "shadow_deep":  (0, 0, 0, 180),
    "glow_white":   (255, 255, 255, 30),
}


# =============================================
#  HILFSFUNKTIONEN
# =============================================

def ensure_dir(path):
    os.makedirs(path, exist_ok=True)

def lerp_color(c1, c2, t):
    """Linear interpolieren zwischen zwei Farben."""
    return tuple(int(a + (b - a) * t) for a, b in zip(c1[:3], c2[:3])) + (c1[3] if len(c1) > 3 else 255,)

def rr(draw, xy, r, fill=None, outline=None, width=1):
    """Abgerundetes Rechteck (kurz)."""
    draw.rounded_rectangle(xy, radius=r, fill=fill, outline=outline, width=width)

def shadow(draw, xy, r, depth=4, color=(0, 0, 0, 80)):
    """Zeichnet einen Schatten unter ein Rechteck."""
    x1, y1, x2, y2 = xy
    for i in range(depth, 0, -1):
        alpha = int(color[3] * (1 - i/depth))
        c = color[:3] + (alpha,)
        draw.rounded_rectangle([x1+i, y1+i, x2+i, y2+i], radius=r, fill=c)

def gradient_box(draw, xy, r, color_top, color_bot):
    """Box mit Farbverlauf (oben→unten)."""
    x1, y1, x2, y2 = xy
    steps = 20
    for i in range(steps):
        t = i / steps
        y = y1 + (y2 - y1) * t
        nh = (y2 - y1) / steps + 1
        c = lerp_color(color_top, color_bot, t)
        draw.rounded_rectangle([x1, y, x2, y + nh], radius=r if (i == 0 or i == steps-1) else 0, fill=c)


def draw_grid(draw, x, y, w, h, spacing=16, color=(40, 44, 60)):
    """Zeichnet ein Gitter auf eine Fläche."""
    for gx in range(x, x + w, spacing):
        draw.line([(gx, y), (gx, y + h)], fill=color, width=1)
    for gy in range(y, y + h, spacing):
        draw.line([(x, gy), (x + w, gy)], fill=color, width=1)
    
    # Gitter-Knotenpunkte hervorheben
    for gx in range(x, x + w, spacing):
        for gy in range(y, y + h, spacing):
            draw.ellipse([(gx-1, gy-1), (gx+1, gy+1)], fill=(60, 66, 85))


# =============================================
#  1. SPIELFELD-KACHELN
# =============================================

def _base_tile():
    """Erzeugt die Basis für eine Kachel mit Rahmen und Schatten."""
    s = T_SIZE
    img = Image.new("RGBA", (s, s), (0, 0, 0, 0))
    draw = ImageDraw.Draw(img)
    
    # Äußerer Schatten
    shadow(draw, [2, 2, s-3, s-3], 6, 5, (0, 0, 0, 60))
    
    # Hintergrund mit Gradient
    gradient_box(draw, [2, 2, s-3, s-3], 6, C["bg_panel"], C["bg_deep"])
    
    # Grid-Linien
    draw_grid(draw, 5, 5, s-10, s-10, 16, (25, 28, 42))
    
    # Neon-Rand (dünn)
    rr(draw, [3, 3, s-4, s-4], 5, None, C["circuit_dim"], 1)
    
    return img, draw

def _add_glow(draw, x, y, radius, color):
    """Fügt einen Glow-Effekt hinzu."""
    for r in range(radius, 0, -2):
        alpha = int(60 * (1 - r/radius))
        draw.ellipse([(x-r, y-r), (x+r, y+r)], fill=color[:3] + (alpha,))

def _add_label(draw, text, x, y, color=C["text_white"], size=24):
    """Fügt einen Buchstaben in der Mitte der Kachel hinzu."""
    # Schrift-Schatten
    for ox, oy in [(1,1), (2,2), (1,2), (2,1)]:
        draw.text((x+ox, y+oy), text, fill=(0,0,0,120), font=None)
    # Schrift
    draw.text((x, y), text, fill=color, font=None)


def create_cpu_tile():
    """Hochwertige CPU-Kachel mit Chip-Design."""
    img, draw = _base_tile()
    s = T_SIZE
    cx, cy = s//2, s//2
    
    # Glow in der Mitte
    _add_glow(draw, cx, cy, 30, C["cpu_glow"] + (40,))
    
    # CPU-Chip (zentrales Rechteck)
    chip_w, chip_h = 60, 50
    cx_chip, cy_chip = cx, cy
    
    # Chip-Basis (dunkel)
    rr(draw, [cx_chip - chip_w//2, cy_chip - chip_h//2, 
              cx_chip + chip_w//2, cy_chip + chip_h//2], 4, C["cpu_dark"])
    
    # Chip mit Verlauf
    gradient_box(draw, [cx_chip - chip_w//2 + 2, cy_chip - chip_h//2 + 2,
                        cx_chip + chip_w//2 - 2, cy_chip + chip_h//2 - 2], 3, C["cpu_mid"], C["cpu_base"])
    
    # Chip-Oberfläche (glänzend)
    rr(draw, [cx_chip - chip_w//2 + 4, cy_chip - chip_h//2 + 4,
              cx_chip + chip_w//2 - 4, cy_chip + chip_h//2 - 4], 2, C["cpu_high"], None)
    
    # CPU-Pins (links und rechts)
    for side in [-1, 1]:
        for i in range(6):
            py = cy_chip - 20 + i * 8
            px = cx_chip + side * (chip_w//2 + 1)
            # Pin
            pin_w, pin_h = 6, 4
            draw.rectangle([px + (0 if side == -1 else -pin_w), py - pin_h//2,
                           px + (pin_w if side == -1 else 0), py + pin_h//2], fill=C["cpu_pin"])
            # Pin-Leuchtpunkt
            draw.ellipse([(px + (1 if side == -1 else -pin_w+1), py - 1), 
                         (px + (pin_w-1 if side == -1 else -1), py + 1)], fill=C["cpu_high"])
    
    # Buchstabe "C"
    _add_label(draw, "C", cx - 10, cy - 12, C["cpu_glow"], 28)
    
    # Kleine dekorative Linien (Leiterbahnen auf dem Chip)
    for i in range(3):
        ly = cy - 15 + i * 15
        draw.line([(cx - 15, ly), (cx + 15, ly)], fill=C["cpu_high"], width=1)
    
    # Ecken-Markierungen
    for (dx, dy) in [(-1, -1), (1, -1), (-1, 1), (1, 1)]:
        draw.ellipse([(cx + dx * (chip_w//2 + 8) - 2, cy + dy * (chip_h//2 + 8) - 2),
                     (cx + dx * (chip_w//2 + 8) + 2, cy + dy * (chip_h//2 + 8) + 2)], fill=C["cpu_glow"])
    
    return img


def create_gpu_tile():
    """Hochwertige GPU-Kachel mit Lüfter-Design."""
    img, draw = _base_tile()
    s = T_SIZE
    cx, cy = s//2, s//2
    
    # Glow
    _add_glow(draw, cx, cy, 35, C["gpu_glow"] + (30,))
    
    # GPU-Chip-Basis
    rr(draw, [cx-32, cy-28, cx+32, cy+28], 4, C["gpu_dark"])
    gradient_box(draw, [cx-30, cy-26, cx+30, cy+26], 3, C["gpu_mid"], C["gpu_base"])
    rr(draw, [cx-26, cy-22, cx+26, cy+22], 2, C["gpu_high"], None)
    
    # Lüfter-Design (3 Rotor-Blätter)
    for i in range(3):
        angle = i * 120 - 90
        rad = math.radians(angle)
        # Blatt
        points = []
        for r in range(5, 28, 2):
            a = rad + math.radians(10 * (r/28))
            px = cx + r * math.cos(a)
            py = cy + r * math.sin(a)
            points.append((px, py))
        for r in range(28, 5, -2):
            a = rad - math.radians(10 * (r/28))
            px = cx + r * math.cos(a)
            py = cy + r * math.sin(a)
            points.append((px, py))
        if len(points) > 2:
            draw.polygon(points, fill=C["gpu_fan"] + (120,))
    
    # Lüfter-Mitte
    draw.ellipse([(cx-10, cy-10), (cx+10, cy+10)], fill=C["gpu_fan"])
    draw.ellipse([(cx-6, cy-6), (cx+6, cy+6)], fill=C["gpu_high"])
    draw.ellipse([(cx-2, cy-2), (cx+2, cy+2)], fill=C["text_white"])
    
    # Buchstabe "G"
    _add_label(draw, "G", cx - 10, cy - 12, C["gpu_glow"], 28)
    
    # Temperatur-Striche (seitlich)
    for side in [-1, 1]:
        for i in range(5):
            sx = cx + side * 35
            sy = cy - 20 + i * 10
            draw.rectangle([sx-2, sy, sx+2, sy+4], fill=C["gpu_glow"] if i < 3 else C["gpu_dark"])
    
    return img


def create_loop_tile():
    """Hochwertige LOOP-Kachel mit Kreislauf-Design."""
    img, draw = _base_tile()
    s = T_SIZE
    cx, cy = s//2, s//2
    
    _add_glow(draw, cx, cy, 30, C["loop_glow"] + (40,))
    
    # Chip-Basis
    rr(draw, [cx-32, cy-28, cx+32, cy+28], 4, C["loop_dark"])
    gradient_box(draw, [cx-30, cy-26, cx+30, cy+26], 3, C["loop_mid"], C["loop_base"])
    rr(draw, [cx-26, cy-22, cx+26, cy+22], 2, C["loop_high"], None)
    
    # Zwei kreisförmige Pfeile
    def draw_arrow(x, y, radius, start_angle, end_angle, color, width=3):
        """Zeichnet einen Kreisbogen-Pfeil."""
        for a in range(start_angle, end_angle, 5):
            rad = math.radians(a)
            px = x + int(radius * math.cos(rad))
            py = y + int(radius * math.sin(rad))
            # Punkt auf dem Bogen
            alpha = 80 + int(175 * (a - start_angle) / (end_angle - start_angle))
            c = color[:3] + (min(alpha, 255),)
            draw.ellipse([(px-1, py-1), (px+1, py+1)], fill=c)
        
        # Pfeilspitze
        end_rad = math.radians(end_angle)
        ex = x + int(radius * math.cos(end_rad))
        ey = y + int(radius * math.sin(end_rad))
        for pdx, pdy in [(0, 0), (-3, -3), (-3, 3)]:
            draw.ellipse([(ex+pdx-2, ey+pdy-2), (ex+pdx+2, ey+pdy+2)], fill=color)
    
    # Äußerer Kreis (Loop)
    draw_arrow(cx, cy, 22, 0, 270, C["loop_glow"], 2)
    draw_arrow(cx, cy, 14, 180, 450, C["loop_arrow"], 2)
    
    # Zentrum
    draw.ellipse([(cx-6, cy-6), (cx+6, cy+6)], fill=C["loop_high"])
    draw.ellipse([(cx-3, cy-3), (cx+3, cy+3)], fill=C["loop_glow"])
    
    # Buchstabe "L"
    _add_label(draw, "L", cx - 8, cy - 12, C["loop_glow"], 28)
    
    return img


def create_npu_tile():
    """Hochwertige NPU-Kachel mit Netzwerk-Design."""
    img, draw = _base_tile()
    s = T_SIZE
    cx, cy = s//2, s//2
    
    _add_glow(draw, cx, cy, 30, C["npu_glow"] + (40,))
    
    # Chip-Basis
    rr(draw, [cx-34, cy-30, cx+34, cy+30], 4, C["npu_dark"])
    gradient_box(draw, [cx-32, cy-28, cx+32, cy+28], 3, C["npu_mid"], C["npu_base"])
    rr(draw, [cx-28, cy-24, cx+28, cy+24], 2, C["npu_high"], None)
    
    # Netzwerk-Knoten und Verbindungen
    nodes = [
        (cx - 18, cy - 14), (cx + 18, cy - 14),
        (cx - 18, cy + 14), (cx + 18, cy + 14),
        (cx, cy), 
        (cx - 18, cy), (cx + 18, cy),
        (cx, cy - 14), (cx, cy + 14),
    ]
    
    # Verbindungslinien
    for i, (x1, y1) in enumerate(nodes):
        for x2, y2 in nodes[i+1:]:
            dist = math.sqrt((x2-x1)**2 + (y2-y1)**2)
            if dist < 30:  # Nur nahe Knoten verbinden
                draw.line([(x1, y1), (x2, y2)], fill=C["npu_node"], width=1)
    
    # Knotenpunkte
    for nx, ny in nodes:
        draw.ellipse([(nx-3, ny-3), (nx+3, ny+3)], fill=C["npu_dark"])
        draw.ellipse([(nx-2, ny-2), (nx+2, ny+2)], fill=C["npu_node"])
    
    # Zentraler Knoten (extra hell)
    draw.ellipse([(cx-5, cy-5), (cx+5, cy+5)], fill=C["npu_glow"])
    draw.ellipse([(cx-2, cy-2), (cx+2, cy+2)], fill=C["text_white"])
    
    # Buchstabe "N"
    _add_label(draw, "N", cx - 10, cy - 12, C["npu_glow"], 28)
    
    return img


def create_trace_tile():
    """Leiterbahn-Kachel mit Kupferleitungen."""
    img, draw = _base_tile()
    s = T_SIZE
    
    # Leiterbahnen (grüne Linien auf dunklem Grund)
    paths = [
        # Horizontale Hauptleitungen
        [(10, 30), (s-10, 30)],
        [(10, 64), (s-10, 64)],
        [(10, 98), (s-10, 98)],
        # Vertikale Verbindungen
        [(30, 10), (30, s-10)],
        [(64, 10), (64, s-10)],
        [(98, 10), (98, s-10)],
        # Diagonale
        [(10, 10), (s-10, s-10)],
        [(s-10, 10), (10, s-10)],
    ]
    
    for path in paths:
        (x1, y1), (x2, y2) = path
        # Hauptlinie
        draw.line([(x1, y1), (x2, y2)], fill=C["trace_line"], width=3)
        # Glow
        draw.line([(x1, y1), (x2, y2)], fill=C["circuit"] + (60,), width=5)
    
    # Anschluss-Punkte (Kreise)
    for x in [10, 30, 64, 98, s-10]:
        for y in [10, 30, 64, 98, s-10]:
            if random.random() > 0.3:  # Nicht alle setzen
                draw.ellipse([(x-3, y-3), (x+3, y+3)], fill=C["circuit"])
                draw.ellipse([(x-1, y-1), (x+1, y+1)], fill=C["circuit_bright"])
    
    # Buchstabe "T" für Trace (klein)
    draw.text((s//2 - 5, s//2 - 7), "T", fill=C["trace_line"] + (100,), font=None)
    
    # Rahmen-Glow
    rr(draw, [3, 3, s-4, s-4], 5, None, C["circuit"] + (40,), 2)
    
    return img


def create_empty_tile():
    """Leere, dunkle Kachel mit dezentem Raster."""
    img, draw = _base_tile()
    s = T_SIZE
    
    # Dunkler als Basis
    rr(draw, [3, 3, s-4, s-4], 5, None, C["text_dark"], 1)
    
    # Sehr dezentes Raster
    for x in range(8, s, 16):
        for y in range(8, s, 16):
            draw.ellipse([(x-1, y-1), (x+1, y+1)], fill=(35, 38, 55))
    
    return img


# =============================================
#  2. UI-BUTTONS
# =============================================

def create_button(text, color, w=BTN_W, h=BTN_H):
    """Erstellt einen professionellen Button mit Schatten und Glanz."""
    img = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    draw = ImageDraw.Draw(img)
    
    # Schatten
    shadow(draw, [0, 0, w-1, h-1], 8, 4)
    
    # Hauptfläche mit Gradient
    gradient_box(draw, [0, 0, w-1, h-1], 8, color, lerp_color(color, (0,0,0), 0.3))
    
    # Oberer Glanz (Highlight)
    rr(draw, [2, 2, w-3, h//2], 6, C["glow_white"], None)
    rr(draw, [w//4, h-8, 3*w//4, h-2], 3, (255,255,255,15), None)
    
    # Neon-Rand
    rr(draw, [0, 0, w-1, h-1], 8, None, lerp_color(color, (255,255,255), 0.3), 2)
    rr(draw, [1, 1, w-2, h-2], 7, None, lerp_color(color, (0,0,0), 0.3), 1)
    
    # Text
    bbox = draw.textbbox((0, 0), text)
    tw = bbox[2] - bbox[0]
    th = bbox[3] - bbox[1]
    # Text-Schatten
    draw.text(((w - tw)//2 + 1, (h - th)//2 + 1), text, fill=(0,0,0,100), font=None)
    # Text
    draw.text(((w - tw)//2, (h - th)//2 - 1), text, fill=C["text_white"], font=None)
    
    return img


def create_panel(w, h, title=""):
    """Erstellt ein Panel für Dialoge/Überschriften."""
    img = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    draw = ImageDraw.Draw(img)
    
    # Tiefer Schatten
    shadow(draw, [0, 0, w-1, h-1], 12, 6)
    
    # Panel mit Gradient
    gradient_box(draw, [0, 0, w-1, h-1], 12, C["bg_card"], C["bg_dark"])
    
    # Innerer Rand
    rr(draw, [2, 2, w-3, h-3], 11, None, lerp_color(C["circuit"], (0,0,0), 0.5), 2)
    rr(draw, [4, 4, w-5, h-5], 10, None, C["circuit_dim"] + (60,), 1)
    
    # Dekorative Ecken
    for (dx, dy) in [(-1, -1), (1, -1), (-1, 1), (1, 1)]:
        ex = w//2 + dx * (w//2 - 10)
        ey = 8 + dy * (h//2 - 40)
        draw.ellipse([(ex-3, ey-3), (ex+3, ey+3)], fill=C["circuit"])
    
    # Titel
    if title:
        bbox = draw.textbbox((0, 0), title)
        tw = bbox[2] - bbox[0]
        draw.text(((w - tw)//2, 15), title, fill=C["text_white"], font=None)
        
        # Trennlinie unter Titel
        draw.line([(30, 45), (w-30, 45)], fill=C["circuit_dim"], width=1)
        draw.ellipse([(w//2-2, 43), (w//2+2, 47)], fill=C["circuit"])
    
    return img


# =============================================
#  3. ICONS
# =============================================

def create_icon_cpu():
    """CPU-Icon (vereinfachte CPU-Kachel)."""
    img = Image.new("RGBA", (ICON_S, ICON_S), (0, 0, 0, 0))
    draw = ImageDraw.Draw(img)
    
    # Chip
    rr(draw, [4, 8, ICON_S-5, ICON_S-8], 3, C["cpu_mid"])
    rr(draw, [8, 12, ICON_S-9, ICON_S-12], 2, C["cpu_high"])
    
    # Pins
    for side in [-1, 1]:
        for i in range(3):
            py = 12 + i * 8
            px = ICON_S//2 + side * (ICON_S//2 - 4)
            draw.rectangle([px-3, py-2, px+3, py+2], fill=C["cpu_pin"])
    
    draw.text((ICON_S//2 - 4, ICON_S//2 - 6), "C", fill=C["text_white"], font=None)
    return img


def create_icon_gpu():
    img = Image.new("RGBA", (ICON_S, ICON_S), (0, 0, 0, 0))
    draw = ImageDraw.Draw(img)
    rr(draw, [4, 8, ICON_S-5, ICON_S-8], 3, C["gpu_mid"])
    rr(draw, [8, 12, ICON_S-9, ICON_S-12], 2, C["gpu_high"])
    draw.ellipse([(ICON_S//2-6, ICON_S//2-6), (ICON_S//2+6, ICON_S//2+6)], fill=C["gpu_fan"])
    draw.ellipse([(ICON_S//2-3, ICON_S//2-3), (ICON_S//2+3, ICON_S//2+3)], fill=C["text_white"])
    draw.text((ICON_S//2 - 4, ICON_S//2 - 6), "G", fill=C["text_white"], font=None)
    return img


def create_icon_loop():
    img = Image.new("RGBA", (ICON_S, ICON_S), (0, 0, 0, 0))
    draw = ImageDraw.Draw(img)
    rr(draw, [4, 8, ICON_S-5, ICON_S-8], 3, C["loop_mid"])
    rr(draw, [8, 12, ICON_S-9, ICON_S-12], 2, C["loop_high"])
    draw.ellipse([(ICON_S//2-8, ICON_S//2-8), (ICON_S//2+8, ICON_S//2+8)], outline=C["loop_glow"], width=2)
    draw.ellipse([(ICON_S//2-3, ICON_S//2-3), (ICON_S//2+3, ICON_S//2+3)], fill=C["loop_glow"])
    draw.text((ICON_S//2 - 4, ICON_S//2 - 6), "L", fill=C["text_white"], font=None)
    return img


def create_icon_npu():
    img = Image.new("RGBA", (ICON_S, ICON_S), (0, 0, 0, 0))
    draw = ImageDraw.Draw(img)
    rr(draw, [4, 8, ICON_S-5, ICON_S-8], 3, C["npu_mid"])
    rr(draw, [8, 12, ICON_S-9, ICON_S-12], 2, C["npu_high"])
    # Netzwerk
    for x in [12, ICON_S//2, ICON_S-13]:
        for y in [12, ICON_S-13]:
            if x == ICON_S//2 and y == 12:
                continue
            draw.ellipse([(x-2, y-2), (x+2, y+2)], fill=C["npu_node"])
            draw.line([(ICON_S//2, ICON_S//2), (x, y)], fill=C["npu_node"], width=1)
    draw.ellipse([(ICON_S//2-3, ICON_S//2-3), (ICON_S//2+3, ICON_S//2+3)], fill=C["npu_glow"])
    draw.text((ICON_S//2 - 4, ICON_S//2 - 6), "N", fill=C["text_white"], font=None)
    return img


def create_icon_trace():
    img = Image.new("RGBA", (ICON_S, ICON_S), (0, 0, 0, 0))
    draw = ImageDraw.Draw(img)
    rr(draw, [4, 8, ICON_S-5, ICON_S-8], 3, C["trace_mid"])
    # Leiterbahnen
    for y in [14, 24, 34]:
        draw.line([(6, y), (ICON_S-7, y)], fill=C["trace_line"], width=2)
    draw.text((ICON_S//2 - 4, ICON_S//2 - 6), "T", fill=C["text_white"], font=None)
    return img


def create_icon_firewall():
    """Firewall-Icon mit Schild und Schloss."""
    s = ICON_S * 2
    img = Image.new("RGBA", (s, s), (0, 0, 0, 0))
    draw = ImageDraw.Draw(img)
    cx, cy = s//2, s//2
    
    # Glow
    _add_glow(draw, cx, cy, 35, C["firewall_glow"] + (30,))
    
    # Schild
    shield = [(cx, 4), (s-6, cy-12), (s-8, s-8), (cx, s-4), (8, s-8), (6, cy-12)]
    draw.polygon(shield, fill=C["firewall_dark"])
    draw.polygon(shield, outline=C["firewall_glow"], width=2)
    
    # Inneres Schild
    inner = [(cx, 10), (s-14, cy-10), (s-16, s-14), (cx, s-12), (14, s-14), (12, cy-10)]
    draw.polygon(inner, fill=C["firewall"])
    
    # Schloss-Symbol
    rr(draw, [cx-10, cy-2, cx+10, cy+14], 2, C["text_white"])
    draw.ellipse([(cx-6, cy-8), (cx+6, cy+2)], outline=C["text_white"], width=2)
    draw.ellipse([(cx-3, cy-4), (cx+3, cy+2)], fill=C["firewall"])
    
    # Buchstabe "FW" (klein)
    draw.text((cx-7, cy+20), "FW", fill=C["text_bright"], font=None)
    
    return img


def create_icon_packet():
    """Datenpaket-Icon mit Schweif."""
    s = ICON_S
    img = Image.new("RGBA", (s, s), (0, 0, 0, 0))
    draw = ImageDraw.Draw(img)
    cx, cy = s//2, s//2
    
    # Schweif
    for i in range(4):
        alpha = 120 - i * 25
        r = 8 - i * 1.5
        ox = -2 - i * 2
        oy = 2 + i * 2
        draw.ellipse([(cx - r + ox, cy - r + oy), (cx + r + ox, cy + r + oy)], 
                     fill=C["packet_base"] + (alpha,))
    
    # Hauptkugel
    _add_glow(draw, cx, cy, 12, C["packet_glow"] + (40,))
    draw.ellipse([(cx-7, cy-7), (cx+7, cy+7)], fill=C["packet_base"])
    draw.ellipse([(cx-5, cy-5), (cx+5, cy+5)], fill=C["packet_glow"])
    draw.ellipse([(cx-2, cy-2), (cx+2, cy+2)], fill=C["packet_core"])
    
    # Bits (kleine Quadrate)
    for i, (dx, dy) in enumerate([(-8, -4), (8, -6), (-6, 8), (6, 6)]):
        draw.rectangle([(cx+dx-1, cy+dy-1), (cx+dx+1, cy+dy+1)], fill=C["packet_glow"])
    
    return img


# =============================================
#  4. HOMESCREEN-HINTERGRUND
# =============================================

def create_background(w=800, h=600):
    """Erstellt einen epischen Hacker-Hintergrund mit Matrix-Code."""
    img = Image.new("RGBA", (w, h), C["bg_deep"])
    draw = ImageDraw.Draw(img)
    
    # Matrix-Regen (fallende grüne Zeichen)
    chars = "01アイウエオカキクケコサシスセソタチツテトナニヌネノハヒフヘホマミムメモヤユヨラリルレロワヲン"
    columns = w // 20
    for col in range(columns):
        x = col * 20 + random.randint(0, 10)
        length = random.randint(5, 20)
        speed = random.uniform(0.5, 2.0)
        for i in range(length):
            y = (col * 13 + i * 22 + random.randint(0, 15)) % h
            alpha = max(20, 100 - i * 5)
            char = random.choice(chars)
            draw.text((x, y), char, fill=(0, 200, 80, alpha), font=None)
    
    # Großer Titel-Schriftzug
    title = "CIRCUIT BREAKER"
    subtitle = "Ein Hacker-Platinen-Puzzle"
    
    # Titel mit Glow
    for ox, oy, color in [(0,0,C["neon_cyan"]), (1,0,C["neon_blue"]), 
                          (-1,0,C["neon_blue"]), (0,-1,C["neon_cyan"]),
                          (2,2,(0,0,0,100)), (-2,-2,(0,0,0,100))]:
        draw.text((w//2 - 180 + ox, 80 + oy), title, fill=color, font=None)
    
    draw.text((w//2 - 140, 130), subtitle, fill=C["text_dim"], font=None)
    
    # Leiterbahnen-Dekoration
    for i in range(15):
        x1 = random.randint(0, w)
        y1 = random.randint(0, h)
        x2 = x1 + random.randint(-100, 100)
        y2 = y1 + random.randint(-100, 100)
        draw.line([(x1, y1), (x2, y2)], fill=C["circuit"] + (20,), width=1)
        draw.ellipse([(x2-2, y2-2), (x2+2, y2+2)], fill=C["circuit"] + (30,))
    
    # Hexagon-Muster im Hintergrund
    for i in range(8):
        for j in range(6):
            hx = 100 + i * 90 + (j % 2) * 45
            hy = 200 + j * 80
            if 0 < hx < w and 0 < hy < h:
                points = []
                for k in range(6):
                    angle = math.radians(60 * k - 30)
                    px = hx + 20 * math.cos(angle)
                    py = hy + 20 * math.sin(angle)
                    points.append((px, py))
                draw.polygon(points, outline=C["circuit_dim"] + (30,), width=1)
    
    return img


# =============================================
#  5. HAUPTGENERATOR
# =============================================

def generate_all():
    print("=" * 60)
    print("  CIRCUIT BREAKER - PROFESSIONAL ASSET GENERATOR")
    print("  Hacker-Theme · 64x64 Pixel Art · Neon-Akzente")
    print("=" * 60)
    
    ensure_dir(ASSETS_DIR)
    ensure_dir(f"{ASSETS_DIR}/tiles")
    ensure_dir(f"{ASSETS_DIR}/ui")
    ensure_dir(f"{ASSETS_DIR}/icons")
    ensure_dir(f"{ASSETS_DIR}/backgrounds")
    
    count = 0
    
    # === 1. SPIELFELD-KACHELN ===
    print("\n📦  GENERIERE SPIELFELD-KACHELN...")
    tiles = [
        ("tile_cpu.png", create_cpu_tile, "CPU - Blau/Eis"),
        ("tile_gpu.png", create_gpu_tile, "GPU - Rot/Lüfter"),
        ("tile_loop.png", create_loop_tile, "LOOP - Grün/Kreislauf"),
        ("tile_npu.png", create_npu_tile, "NPU - Orange/Netzwerk"),
        ("tile_trace.png", create_trace_tile, "TRACE - Leiterbahn"),
        ("tile_empty.png", create_empty_tile, "Leer - Dunkel"),
    ]
    
    for fname, func, desc in tiles:
        path = f"{ASSETS_DIR}/tiles/{fname}"
        img = func()
        img.save(path)
        count += 1
        print(f"  ✅ {fname:20s} ({img.size[0]}x{img.size[1]})  {desc}")
    
    # === 1b. MINI-KACHELN (für UI) ===
    print("\n📦  GENERIERE MINI-KACHELN (32x32)...")
    mini_tiles = [
        ("tile_cpu_mini.png", lambda: Image.open(f"{ASSETS_DIR}/tiles/tile_cpu.png").resize((32,32), Image.NEAREST)),
        ("tile_gpu_mini.png", lambda: Image.open(f"{ASSETS_DIR}/tiles/tile_gpu.png").resize((32,32), Image.NEAREST)),
        ("tile_loop_mini.png", lambda: Image.open(f"{ASSETS_DIR}/tiles/tile_loop.png").resize((32,32), Image.NEAREST)),
        ("tile_npu_mini.png", lambda: Image.open(f"{ASSETS_DIR}/tiles/tile_npu.png").resize((32,32), Image.NEAREST)),
        ("tile_trace_mini.png", lambda: Image.open(f"{ASSETS_DIR}/tiles/tile_trace.png").resize((32,32), Image.NEAREST)),
        ("tile_empty_mini.png", lambda: Image.open(f"{ASSETS_DIR}/tiles/tile_empty.png").resize((32,32), Image.NEAREST)),
    ]
    
    for fname, func in mini_tiles:
        path = f"{ASSETS_DIR}/tiles/{fname}"
        img = func()
        img.save(path)
        count += 1
    
    print(f"  ✅ 6 Mini-Kacheln (skaliert)")
    
    # === 2. UI-BUTTONS ===
    print("\n🖥️  GENERIERE UI-ELEMENTE...")
    buttons = [
        ("button_start.png",  "START",  C["cpu_mid"]),
        ("button_send.png",   "SENDEN", C["green"]),
        ("button_buy.png",    "KAUFEN", C["gold"]),
        ("button_next.png",   "WEITER", C["loop_mid"]),
        ("button_restart.png","NEUSTART", C["gpu_mid"]),
        ("button_quit.png",   "BEENDEN", (100, 100, 120)),
        ("button_shop.png",   "SHOP",   C["npu_mid"]),
        ("button_help.png",   "HILFE",  C["neon_cyan"]),
        ("button_menu.png",   "MENÜ",   C["trace_mid"]),
        ("button_inv.png",    "INVENTAR", C["neon_purple"]),
    ]
    
    for fname, text, color in buttons:
        path = f"{ASSETS_DIR}/ui/{fname}"
        create_button(text, color).save(path)
        count += 1
        print(f"  ✅ {fname:22s} {text}")
    
    # Panels
    panels = [
        ("panel_homescreen.png", 500, 400, "CIRCUIT BREAKER"),
        ("panel_shop.png",      500, 350, "SHOP"),
        ("panel_gameover.png",  450, 300, "GAME OVER"),
        ("panel_send.png",      450, 280, "PAKETE SENDEN"),
        ("panel_inventory.png", 400, 250, "INVENTAR"),
    ]
    
    for fname, w, h, title in panels:
        path = f"{ASSETS_DIR}/ui/{fname}"
        create_panel(w, h, title).save(path)
        count += 1
        print(f"  ✅ {fname:22s} {title}")
    
    # === 3. ICONS ===
    print("\n🔣  GENERIERE ICONS...")
    icons = [
        ("icon_cpu.png",     create_icon_cpu),
        ("icon_gpu.png",     create_icon_gpu),
        ("icon_loop.png",    create_icon_loop),
        ("icon_npu.png",     create_icon_npu),
        ("icon_trace.png",   create_icon_trace),
        ("icon_firewall.png",create_icon_firewall),
        ("icon_packet.png",  create_icon_packet),
    ]
    
    for fname, func in icons:
        path = f"{ASSETS_DIR}/icons/{fname}"
        img = func()
        img.save(path)
        count += 1
        print(f"  ✅ {fname:22s} ({img.size[0]}x{img.size[1]})")
    
    # === 4. BACKGROUNDS ===
    print("\n🌌  GENERIERE HINTERGRÜNDE...")
    bg = create_background(800, 600)
    bg.save(f"{ASSETS_DIR}/backgrounds/bg_homescreen.png")
    count += 1
    print(f"  ✅ bg_homescreen.png (800x600) - Matrix-Regen + Hexagone")
    
    bg2 = create_background(800, 600)
    bg2.save(f"{ASSETS_DIR}/backgrounds/bg_game.png")
    count += 1
    print(f"  ✅ bg_game.png (800x600)")
    
    # === 5. VORSCHAUBILD ===
    print("\n🖼️  ERSTELLE VORSCHAU...")
    preview = Image.new("RGBA", (T_SIZE * 6 + 40, T_SIZE + 40), C["bg_deep"])
    for i, (fname, _, _) in enumerate(tiles[:6]):
        try:
            tile = Image.open(f"{ASSETS_DIR}/tiles/{fname}")
            preview.paste(tile, (10 + i * T_SIZE + 5, 10), tile)
        except:
            pass
    preview.save(f"{ASSETS_DIR}/tiles_preview.png")
    count += 1
    print(f"  ✅ tiles_preview.png - Alle Kacheln auf einen Blick")
    
    # === ZUSAMMENFASSUNG ===
    print(f"\n{'=' * 60}")
    print(f"  ✅ {count} PROFESSIONELLE ASSETS ERSTELLT!")
    print(f"  📁 Ordner: {os.path.abspath(ASSETS_DIR)}")
    print(f"{'=' * 60}")
    print(f"\n  📊 AUFTEILUNG:")
    print(f"  - 6 Spielfeld-Kacheln (128x128 Pixel Art)")
    print(f"  - 6 Mini-Kacheln (32x32)")
    print(f"  - 10 Buttons mit Gradient & Glow")
    print(f"  - 5 Dialog-Panels")
    print(f"  - 7 Icons (Bauteile, Firewall, Paket)")
    print(f"  - 2 Hintergründe (Matrix-Regen)")
    print(f"  - 1 Vorschaubild")
    print(f"\n  🚀 IN GODOT NUTZEN:")
    print(f"  1. Godot öffnen")
    print(f"  2. assets/ in den FileSystem-Dock ziehen")
    print(f"  3. Fertig!")
    print(f"\n  🔧 ERNEUT GENERIEREN:")
    print(f"  python generate_assets.py")


if __name__ == "__main__":
    generate_all()