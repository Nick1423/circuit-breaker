#!/usr/bin/env python3
"""
=============================================================================
 Circuit Breaker - Asset Generator
 Erstellt automatisch Pixel-Art-Grafiken für das Spiel.
 Kein externes Tool nötig - nur Python 3 + PIL/Pillow!

 Installiere: pip install Pillow
 Starten: python generate_assets.py
=============================================================================
"""

import os
import math
from enum import Enum

try:
    from PIL import Image, ImageDraw, ImageFont, ImageFilter
    HAS_PIL = True
except ImportError:
    HAS_PIL = False
    print("❌ Pillow nicht installiert!")
    print("   Installiere: pip install Pillow")
    exit(1)


# =============================================
#  KONFIGURATION
# =============================================

ASSETS_DIR = "assets"
TILE_SIZE = 64  # Größe der Kacheln (64x64 Pixel)
ICON_SIZE = 32  # Größe der Icons

# Farbpalette (Hacker/Platinen-Thema)
COLORS = {
    # Hintergründe
    "bg_dark": (14, 14, 18),        # Fast schwarz
    "bg_panel": (20, 22, 28),       # Dunkles Panel
    "bg_tile": (26, 28, 36),        # Kachel-Hintergrund
    
    # Bauteil-Farben
    "cpu": (50, 140, 220),          # Blau
    "cpu_light": (100, 180, 255),
    "cpu_dark": (30, 80, 140),
    "gpu": (220, 50, 50),           # Rot
    "gpu_light": (255, 100, 100),
    "gpu_dark": (140, 20, 20),
    "loop": (50, 200, 100),         # Grün
    "loop_light": (100, 255, 150),
    "loop_dark": (20, 120, 50),
    "npu": (220, 160, 50),          # Orange
    "npu_light": (255, 200, 100),
    "npu_dark": (140, 100, 20),
    "trace": (120, 120, 130),       # Grau
    "trace_light": (160, 160, 170),
    "trace_dark": (70, 70, 80),
    
    # UI
    "text": (200, 200, 210),
    "text_dim": (120, 120, 130),
    "gold": (255, 200, 50),
    "green": (50, 220, 100),
    "red": (220, 50, 50),
    "white": (255, 255, 255),
    "firewall": (200, 50, 80),
    "firewall_light": (255, 100, 130),
    
    # Leiterbahnen
    "circuit": (40, 180, 120),
    "circuit_dim": (20, 80, 50),
    
    # Paket
    "packet": (100, 220, 255),
    "packet_glow": (150, 240, 255),
}


# =============================================
#  HILFSFUNKTIONEN
# =============================================

def ensure_dir(path):
    """Stellt sicher, dass ein Verzeichnis existiert."""
    os.makedirs(path, exist_ok=True)


def draw_rounded_rect(draw, xy, radius, fill, outline=None, width=1):
    """Zeichnet ein abgerundetes Rechteck."""
    x1, y1, x2, y2 = xy
    draw.rounded_rectangle(xy, radius=radius, fill=fill, outline=outline, width=width)


def draw_circuit_lines(draw, x, y, w, h, color, count=3):
    """Zeichnet Leiterbahn-Muster auf eine Kachel."""
    for i in range(count):
        spacing = h // (count + 1)
        cy = y + spacing * (i + 1)
        # Horizontale Linie
        draw.line([(x + 4, cy), (x + w - 4, cy)], fill=color, width=2)
        # Kleine Punkte an den Enden
        draw.ellipse([(x + 2, cy - 2), (x + 6, cy + 2)], fill=color)
        draw.ellipse([(x + w - 6, cy - 2), (x + w - 2, cy + 2)], fill=color)


def glow_effect(img, color, radius=3):
    """Erzeugt einen Glow-Effekt um die Form."""
    glow = Image.new("RGBA", img.size, (0, 0, 0, 0))
    gdraw = ImageDraw.Draw(glow)
    gdraw.bitmap((0, 0), img, fill=color)
    glow = glow.filter(ImageFilter.GaussianBlur(radius=radius))
    return Image.alpha_composite(glow, img)


# =============================================
#  BAU TEIL-GENERATOREN
# =============================================

def create_cpu_tile(size=TILE_SIZE):
    """Erstellt eine CPU-Kachel."""
    img = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    draw = ImageDraw.Draw(img)
    s = size - 4
    
    # Hintergrund-Rechteck (abgerundet)
    draw_rounded_rect(draw, (2, 2, s, s), 8, COLORS["cpu_dark"])
    draw_rounded_rect(draw, (4, 4, s - 2, s - 2), 6, COLORS["cpu"])
    
    # CPU-Textur: Kleine Quadrate (Pins)
    pin_size = 4
    pin_color = COLORS["cpu_light"]
    for i in range(4):
        py = 8 + i * 14
        for j in range(2):
            px = 6 + j * (size - 12)
            draw.rectangle([(px, py), (px + pin_size, py + pin_size)], fill=pin_color)
            draw.rectangle([(px, size - py - pin_size), (px + pin_size, size - py)], fill=pin_color)
    
    # Chip-Mitte
    cx, cy = size // 2, size // 2
    draw_rounded_rect(draw, (cx - 10, cy - 8, cx + 10, cy + 8), 3, COLORS["cpu_light"])
    
    # Buchstabe "C"
    draw.text((cx - 4, cy - 5), "C", fill=COLORS["white"], font=None)
    
    return img


def create_gpu_tile(size=TILE_SIZE):
    """Erstellt eine GPU-Kachel."""
    img = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    draw = ImageDraw.Draw(img)
    s = size - 4
    
    draw_rounded_rect(draw, (2, 2, s, s), 8, COLORS["gpu_dark"])
    draw_rounded_rect(draw, (4, 4, s - 2, s - 2), 6, COLORS["gpu"])
    
    # GPU-Textur: Lüfter-Design
    cx, cy = size // 2, size // 2
    for i in range(3):
        angle = i * 120
        rad = math.radians(angle)
        for r in range(6, 18, 6):
            lx = cx + int(r * math.cos(rad))
            ly = cy + int(r * math.sin(rad))
            draw.ellipse([(lx - 3, ly - 3), (lx + 3, ly + 3)], fill=COLORS["gpu_light"])
    
    draw.ellipse([(cx - 8, cy - 8), (cx + 8, cy + 8)], fill=COLORS["gpu_light"])
    draw.text((cx - 4, cy - 5), "G", fill=COLORS["white"], font=None)
    
    return img


def create_loop_tile(size=TILE_SIZE):
    """Erstellt eine LOOP-Kachel."""
    img = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    draw = ImageDraw.Draw(img)
    s = size - 4
    
    draw_rounded_rect(draw, (2, 2, s, s), 8, COLORS["loop_dark"])
    draw_rounded_rect(draw, (4, 4, s - 2, s - 2), 6, COLORS["loop"])
    
    # Loop-Textur: Kreisförmige Pfeile
    cx, cy = size // 2, size // 2
    draw.ellipse([(cx - 12, cy - 12), (cx + 12, cy + 12)], outline=COLORS["loop_light"], width=3)
    draw.ellipse([(cx - 6, cy - 6), (cx + 6, cy + 6)], fill=COLORS["loop_light"])
    
    draw.text((cx - 4, cy - 5), "L", fill=COLORS["white"], font=None)
    
    return img


def create_npu_tile(size=TILE_SIZE):
    """Erstellt eine NPU-Kachel."""
    img = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    draw = ImageDraw.Draw(img)
    s = size - 4
    
    draw_rounded_rect(draw, (2, 2, s, s), 8, COLORS["npu_dark"])
    draw_rounded_rect(draw, (4, 4, s - 2, s - 2), 6, COLORS["npu"])
    
    # NPU-Textur: Netzwerk-artig
    cx, cy = size // 2, size // 2
    connections = [(cx - 10, cy - 8), (cx + 10, cy - 8), (cx - 8, cy + 8), (cx + 8, cy + 8), (cx, cy)]
    for i, (x1, y1) in enumerate(connections):
        for x2, y2 in connections[i+1:]:
            draw.line([(x1, y1), (x2, y2)], fill=COLORS["npu_light"], width=1)
        draw.ellipse([(x1 - 3, y1 - 3), (x1 + 3, y1 + 3)], fill=COLORS["npu_light"])
    
    draw.text((cx - 4, cy - 5), "N", fill=COLORS["white"], font=None)
    
    return img


def create_trace_tile(size=TILE_SIZE):
    """Erstellt eine TRACE/Leiterbahn-Kachel."""
    img = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    draw = ImageDraw.Draw(img)
    s = size - 4
    
    draw_rounded_rect(draw, (2, 2, s, s), 8, COLORS["trace_dark"])
    draw_rounded_rect(draw, (4, 4, s - 2, s - 2), 6, COLORS["trace"])
    
    # Leiterbahn-Muster
    draw_circuit_lines(draw, 6, 8, size - 12, size - 16, COLORS["trace_light"], 2)
    
    return img


def create_empty_tile(size=TILE_SIZE):
    """Erstellt eine leere Kachel."""
    img = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    draw = ImageDraw.Draw(img)
    s = size - 4
    
    draw_rounded_rect(draw, (2, 2, s, s), 8, COLORS["bg_tile"])
    draw_rounded_rect(draw, (4, 4, s - 2, s - 2), 6, (30, 32, 42))
    
    # Gitter-Punkte
    for x in range(12, size, 16):
        for y in range(12, size, 16):
            draw.ellipse([(x - 1, y - 1), (x + 1, y + 1)], fill=(40, 42, 52))
    
    return img


# =============================================
#  UI-ELEMENTE
# =============================================

def create_button(width=160, height=40, text="Button", color=(50, 140, 220)):
    """Erstellt einen Button."""
    img = Image.new("RGBA", (width, height), (0, 0, 0, 0))
    draw = ImageDraw.Draw(img)
    
    draw_rounded_rect(draw, (0, 0, width - 1, height - 1), 6, color)
    draw_rounded_rect(draw, (2, 2, width - 3, height - 3), 5, 
                      (min(color[0] + 30, 255), min(color[1] + 30, 255), min(color[2] + 30, 255)))
    
    # Text
    bbox = draw.textbbox((0, 0), text)
    tw = bbox[2] - bbox[0]
    th = bbox[3] - bbox[1]
    draw.text(((width - tw) // 2, (height - th) // 2), text, fill=COLORS["white"])
    
    return img


def create_panel(width=400, height=300):
    """Erstellt ein Panel/dialog."""
    img = Image.new("RGBA", (width, height), (0, 0, 0, 0))
    draw = ImageDraw.Draw(img)
    
    draw_rounded_rect(draw, (0, 0, width - 1, height - 1), 10, COLORS["bg_panel"])
    draw_rounded_rect(draw, (2, 2, width - 3, height - 3), 9, (24, 26, 34))
    
    # Rand
    draw_rounded_rect(draw, (0, 0, width - 1, height - 1), 10, None, outline=COLORS["circuit"], width=2)
    
    return img


def create_firewall_icon(size=ICON_SIZE * 2):
    """Erstellt ein Firewall-Icon."""
    img = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    draw = ImageDraw.Draw(img)
    
    # Schild-Form
    cx, cy = size // 2, size // 2
    points = [(cx, 2), (size - 2, cy - 8), (size - 4, size - 4), (cx, size - 2), (4, size - 4), (2, cy - 8)]
    draw.polygon(points, fill=COLORS["firewall_dark"] if "firewall_dark" in COLORS else (100, 20, 40))
    
    # Schloss-Symbol
    draw_rounded_rect(draw, (cx - 10, cy - 4, cx + 10, cy + 12), 3, COLORS["firewall"])
    draw.ellipse([(cx - 6, cy - 8), (cx + 6, cy + 2)], fill=COLORS["firewall_light"])
    
    return img


def create_packet_icon(size=ICON_SIZE):
    """Erstellt ein Paket-Icon (Datenpaket)."""
    img = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    draw = ImageDraw.Draw(img)
    
    cx, cy = size // 2, size // 2
    
    # Leuchtender Punkt mit Schweif
    draw.ellipse([(cx - 6, cy - 6), (cx + 6, cy + 6)], fill=COLORS["packet"])
    draw.ellipse([(cx - 3, cy - 3), (cx + 3, cy + 3)], fill=COLORS["packet_glow"])
    
    # Schweif (nach unten links)
    for i in range(3):
        alpha = 100 - i * 30
        r = 4 - i
        draw.ellipse([(cx - 8 - i * 3, cy + 2 + i * 3), 
                      (cx - 8 - i * 3 + r * 2, cy + 2 + i * 3 + r * 2)], 
                     fill=(COLORS["packet"][0], COLORS["packet"][1], COLORS["packet"][2], alpha))
    
    return img


# =============================================
#  HAUPTFUNKTION
# =============================================

def generate_all():
    """Generiert ALLE Assets."""
    print("=" * 60)
    print("  CIRCUIT BREAKER - ASSET GENERATOR")
    print("=" * 60)
    
    ensure_dir(ASSETS_DIR)
    ensure_dir(os.path.join(ASSETS_DIR, "tiles"))
    ensure_dir(os.path.join(ASSETS_DIR, "ui"))
    ensure_dir(os.path.join(ASSETS_DIR, "icons"))
    
    generated = []
    
    # 1. Spielfeld-Kacheln
    print("\n📦 Generiere Spielfeld-Kacheln...")
    tiles = {
        "tile_cpu.png": create_cpu_tile,
        "tile_gpu.png": create_gpu_tile,
        "tile_loop.png": create_loop_tile,
        "tile_npu.png": create_npu_tile,
        "tile_trace.png": create_trace_tile,
        "tile_empty.png": create_empty_tile,
    }
    
    for filename, func in tiles.items():
        path = os.path.join(ASSETS_DIR, "tiles", filename)
        img = func()
        img.save(path)
        generated.append(path)
        print(f"  ✅ {path} ({img.size[0]}x{img.size[1]})")
    
    # 2. UI-Elemente
    print("\n🖥️  Generiere UI-Elemente...")
    ui_items = {
        "button_start.png": lambda: create_button(200, 50, "START", COLORS["cpu"]),
        "button_send.png": lambda: create_button(200, 50, "SEND", COLORS["green"]),
        "button_buy.png": lambda: create_button(200, 50, "BUY", COLORS["gold"]),
        "button_next.png": lambda: create_button(200, 50, "NEXT", COLORS["loop"]),
        "button_restart.png": lambda: create_button(200, 50, "RESTART", COLORS["gpu"]),
        "button_quit.png": lambda: create_button(200, 50, "QUIT", (100, 100, 100)),
        "panel_shop.png": lambda: create_panel(500, 350),
        "panel_gameover.png": lambda: create_panel(400, 250),
    }
    
    for filename, func in ui_items.items():
        path = os.path.join(ASSETS_DIR, "ui", filename)
        img = func()
        img.save(path)
        generated.append(path)
        print(f"  ✅ {path} ({img.size[0]}x{img.size[1]})")
    
    # 3. Icons
    print("\n🔣 Generiere Icons...")
    icons = {
        "icon_firewall.png": create_firewall_icon,
        "icon_packet.png": create_packet_icon,
        "icon_cpu.png": lambda: create_cpu_tile(ICON_SIZE),
        "icon_gpu.png": lambda: create_gpu_tile(ICON_SIZE),
        "icon_loop.png": lambda: create_loop_tile(ICON_SIZE),
        "icon_npu.png": lambda: create_npu_tile(ICON_SIZE),
        "icon_trace.png": lambda: create_trace_tile(ICON_SIZE),
    }
    
    for filename, func in icons.items():
        path = os.path.join(ASSETS_DIR, "icons", filename)
        img = func()
        img.save(path)
        generated.append(path)
        print(f"  ✅ {path} ({img.size[0]}x{img.size[1]})")
    
    # 4. Grid-Zusammenstellung (Vorschau)
    print("\n🖼️  Erstelle Vorschau-Grid...")
    preview = Image.new("RGBA", (TILE_SIZE * 6 + 20, TILE_SIZE * 4 + 20), COLORS["bg_dark"])
    tile_files = [
        ("tile_empty.png", None), ("tile_empty.png", None), ("tile_empty.png", None), 
        ("tile_empty.png", None), ("tile_empty.png", None), ("tile_empty.png", None),
        ("tile_cpu.png", "CPU"), ("tile_gpu.png", "GPU"), ("tile_loop.png", "LOOP"),
        ("tile_npu.png", "NPU"), ("tile_trace.png", "TRACE"), ("tile_empty.png", None),
    ]
    
    for i, (filename, label) in enumerate(tile_files):
        col = i % 6
        row = i // 6
        try:
            tile = Image.open(os.path.join(ASSETS_DIR, "tiles", filename))
            preview.paste(tile, (col * TILE_SIZE + 10, row * TILE_SIZE + 10), tile)
        except:
            pass
    
    preview_path = os.path.join(ASSETS_DIR, "preview.png")
    preview.save(preview_path)
    generated.append(preview_path)
    print(f"  ✅ {preview_path}")
    
    # Zusammenfassung
    print(f"\n{'=' * 60}")
    print(f"  ✅ {len(generated)} Assets generiert!")
    print(f"  📁 Ordner: {os.path.abspath(ASSETS_DIR)}")
    print(f"{'=' * 60}")
    print(f"\n  So importierst du in Godot:")
    print(f"  1. Öffne Godot")
    print(f"  2. Ziehe den Ordner 'assets/' in den FileSystem-Dock")
    print(f"  3. Die Texturen sind bereit zum Nutzen!")
    print(f"\n  Oder starte einfach: python cli_game.py")


# =============================================
#  MAIN
# =============================================

if __name__ == "__main__":
    generate_all()