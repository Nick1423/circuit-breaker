#!/usr/bin/env python3
"""
=============================================================================
 CIRCUIT BREAKER - COMMAND LINE INTERFACE (CLI)
=============================================================================
 Das komplette Spiel spielbar im Terminal!
 Kein Godot nötig - nur Python 3.

 Starten: python cli_game.py
=============================================================================
"""

import random
import os
import sys
from enum import Enum
from typing import Optional, List, Tuple

# =============================================
#  KERN-LOGIK (identisch zu Godot + playthrough)
# =============================================

BOARD_WIDTH = 6
BOARD_HEIGHT = 4

class ComponentType(Enum):
    TRACE = 0
    CPU = 1
    GPU = 2
    LOOP = 3
    NPU = 4

COMPONENT_NAMES = {
    ComponentType.TRACE: "Leiterbahn",
    ComponentType.CPU: "CPU",
    ComponentType.GPU: "GPU",
    ComponentType.LOOP: "Loop",
    ComponentType.NPU: "NPU",
}

COMPONENT_WATT = {
    ComponentType.TRACE: 0,
    ComponentType.CPU: 2,
    ComponentType.GPU: 5,
    ComponentType.LOOP: 3,
    ComponentType.NPU: 4,
}

COMPONENT_DISPLAY = {
    ComponentType.TRACE: "=",
    ComponentType.CPU: "C",
    ComponentType.GPU: "G",
    ComponentType.LOOP: "L",
    ComponentType.NPU: "N",
}

BASE_WATT_BUDGET = 10
WATT_PER_ROUND = 2
COMPONENT_BASE_PRICES = {ComponentType.TRACE: 1, ComponentType.CPU: 3, ComponentType.GPU: 8, ComponentType.LOOP: 5, ComponentType.NPU: 6}


def process_packet(comp_type: ComponentType, value: int, board=None, row: int = -1, col: int = -1) -> int:
    result = value
    if comp_type == ComponentType.TRACE:
        pass
    elif comp_type == ComponentType.CPU:
        result += 5
    elif comp_type == ComponentType.GPU:
        result *= 2
    elif comp_type == ComponentType.LOOP:
        result += 10
    elif comp_type == ComponentType.NPU:
        cpu_count = 0
        if board is not None and row >= 0 and col >= 0:
            for dr, dc in [(-1,0), (1,0), (0,-1), (0,1)]:
                nr, nc = row + dr, col + dc
                if 0 <= nr < BOARD_HEIGHT and 0 <= nc < BOARD_WIDTH:
                    if board.get_component(nc, nr) == ComponentType.CPU:
                        cpu_count += 1
        result += cpu_count * 3
    return result


class Board:
    def __init__(self, watt_budget=BASE_WATT_BUDGET):
        self.board = [[None] * BOARD_WIDTH for _ in range(BOARD_HEIGHT)]
        self.watt_budget = watt_budget

    def clear(self):
        self.board = [[None] * BOARD_WIDTH for _ in range(BOARD_HEIGHT)]

    def get_component(self, col, row):
        if 0 <= col < BOARD_WIDTH and 0 <= row < BOARD_HEIGHT:
            return self.board[row][col]
        return None

    def place_component(self, col, row, comp_type):
        if not (0 <= col < BOARD_WIDTH and 0 <= row < BOARD_HEIGHT):
            return False, "Außerhalb des Bretts!"
        if self.board[row][col] is not None:
            return False, "Feld ist bereits belegt!"
        if self.get_used_watt() + COMPONENT_WATT[comp_type] > self.watt_budget:
            return False, f"Nicht genug Watt! ({self.get_used_watt()} + {COMPONENT_WATT[comp_type]} > {self.watt_budget})"
        self.board[row][col] = comp_type
        return True, ""

    def remove_component(self, col, row):
        if not (0 <= col < BOARD_WIDTH and 0 <= row < BOARD_HEIGHT):
            return False, "Außerhalb des Bretts!"
        if self.board[row][col] is None:
            return False, "Feld ist bereits leer!"
        self.board[row][col] = None
        return True, ""

    def get_used_watt(self):
        total = 0
        for row in range(BOARD_HEIGHT):
            for col in range(BOARD_WIDTH):
                if self.board[row][col] is not None:
                    total += COMPONENT_WATT[self.board[row][col]]
        return total

    def get_available_positions(self):
        return [(c, r) for r in range(BOARD_HEIGHT) for c in range(BOARD_WIDTH) if self.board[r][c] is None]

    def simulate_packet_flow(self, row):
        if row < 0 or row >= BOARD_HEIGHT:
            return 0
        value = 1
        for col in range(BOARD_WIDTH):
            comp = self.board[row][col]
            if comp is not None:
                value = process_packet(comp, value, self, row, col)
        return value


class Firewall:
    def __init__(self, level):
        self.level = level
        self.max_health = 10 + (level * 5)
        self.health = self.max_health
        self.reward_watt = 2 + level
        self.packets_per_round = 3 + (level // 2)

    def take_damage(self, amount):
        self.health = max(0, self.health - amount)
        return self.health <= 0

    def is_alive(self):
        return self.health > 0


class Shop:
    def __init__(self):
        self.offers = []

    def generate_offerings(self, round_number):
        self.offers = []
        count = random.randint(3, 5)
        multiplier = 1.0 + (round_number * 0.1)
        for _ in range(count):
            roll = random.random()
            if roll < 0.20:
                ct = ComponentType.TRACE
            elif roll < 0.55:
                ct = ComponentType.CPU
            elif roll < 0.70:
                ct = ComponentType.GPU
            elif roll < 0.90:
                ct = ComponentType.LOOP
            else:
                ct = ComponentType.NPU
            price = max(1, int(COMPONENT_BASE_PRICES[ct] * multiplier))
            self.offers.append((ct, price))

    def buy(self, index, money):
        if index < 0 or index >= len(self.offers):
            return {"success": False, "reason": "Ungültiger Index"}
        ct, price = self.offers[index]
        if money < price:
            return {"success": False, "reason": f"Brauchst {price}, hast nur {money}"}
        self.offers.pop(index)
        return {"success": True, "component_type": ct, "price": price, "name": COMPONENT_NAMES[ct]}


class Inventory:
    def __init__(self):
        self.items = []
        self.max_size = 10

    def add_item(self, comp_type):
        if len(self.items) >= self.max_size:
            return False
        self.items.append(comp_type)
        return True

    def take_item(self, index):
        if 0 <= index < len(self.items):
            return self.items.pop(index)
        return None

    def peek_item(self, index):
        if 0 <= index < len(self.items):
            return self.items[index]
        return None

    def get_count(self):
        return len(self.items)


# =============================================
#  CLI-GAME
# =============================================

class Game:
    def __init__(self):
        self.board = Board()
        self.shop = Shop()
        self.inventory = Inventory()
        self.round = 0
        self.score = 0
        self.highscore = 0
        self.money = 5
        self.firewall = None
        self.game_over = False
        self.won = False

    def clear_screen(self):
        os.system('cls' if os.name == 'nt' else 'clear')

    def print_header(self, title):
        print("\n" + "=" * 60)
        print(f"  {title}")
        print("=" * 60)

    def print_board(self):
        print(f"\n  Watt: {self.board.get_used_watt()}/{self.board.watt_budget}")
        print("  " + "-" * 17)
        for row in range(BOARD_HEIGHT):
            line = "  "
            for col in range(BOARD_WIDTH):
                comp = self.board.board[row][col]
                if comp is None:
                    line += ". "
                else:
                    line += COMPONENT_DISPLAY[comp] + " "
            # Zeilennummer
            print(f"{line}  Zeile {row}")
        print("  " + "-" * 17)
        print("    0 1 2 3 4 5  (Spalten)")

    def print_status(self):
        print(f"\n  Runde: {self.round} | Geld: {self.money} | Score: {self.score}")
        if self.firewall:
            print(f"  Firewall: {self.firewall.health}/{self.firewall.max_health} HP | {self.firewall.packets_per_round} Pakete/Runde")
        print(f"  Inventar: {self.inventory.get_count()} Bauteile")

    def show_homescreen(self):
        self.clear_screen()
        print()
        print("╔" + "═" * 58 + "╗")
        print("║" + " " * 58 + "║")
        print("║" + "     ╔══════════════════════════════════════════╗".center(58) + "║")
        print("║" + "     ║       CIRCUIT BREAKER                   ║".center(58) + "║")
        print("║" + "     ║    Ein Hacker-Platinen-Puzzle           ║".center(58) + "║")
        print("║" + "     ╚══════════════════════════════════════════╝".center(58) + "║")
        print("║" + " " * 58 + "║")
        print("║" + "  Baue deine Platine, verstärke Datenpakete,".center(58) + "║")
        print("║" + "  und knacke die Firewall!".center(58) + "║")
        print("║" + " " * 58 + "║")
        print("║" + "  Bauteile:".center(58) + "║")
        print("║" + "    CPU  (+5, 2W)  |  GPU  (x2, 5W)".center(58) + "║")
        print("║" + "    LOOP (+10, 3W) |  NPU  (+3/CPU, 4W)".center(58) + "║")
        print("║" + "    TRACE (=, 0W)".center(58) + "║")
        print("║" + " " * 58 + "║")
        print("║" + "  Befehle: start, quit".center(58) + "║")
        print("║" + " " * 58 + "║")
        print("╚" + "═" * 58 + "╝")
        print()

    def show_help(self):
        self.print_header("HILFE")
        print("  BAU-PHASE:")
        print("    place CPU 0 0       - Bauteil setzen")
        print("    remove 0 0          - Bauteil entfernen")
        print("    clear                - Brett leeren")
        print("    invuse 0 2 1        - Item[0] aus Inventar setzen")
        print("")
        print("  AKTIONEN:")
        print("    send                 - Pakete losschicken")
        print("")
        print("  SHOP (nach Runde):")
        print("    buy <nr>            - Kaufen")
        print("    inv                  - Inventar anzeigen")
        print("    next                 - Nächste Runde")
        print("")
        print("  ALLGEMEIN:")
        print("    board                - Brett anzeigen")
        print("    status               - Spielstatus")
        print("    help                 - Diese Hilfe")
        print("    restart              - Neustart")
        print("    quit                 - Beenden")
        print()

    def show_shop(self):
        self.clear_screen()
        self.print_header(f"SHOP (Runde {self.round})")
        print(f"  Geld: {self.money}\n")
        print("  Angebote:")
        for i, (ct, price) in enumerate(self.shop.offers):
            name = COMPONENT_NAMES[ct]
            watt = COMPONENT_WATT[ct]
            print(f"    [{i}] {name:12s} - {price:3d} Geld ({watt}W)")
        print(f"\n  Inventar: {self.inventory.get_count()} Bauteile")
        print("\n  buy <nr> - kaufen | next - weiter | inv - inventar")

    def show_game_over(self):
        self.clear_screen()
        self.print_header("GAME OVER")
        print(f"\n  Runde: {self.round}")
        print(f"  Score: {self.score}")
        if self.score > self.highscore:
            self.highscore = self.score
            print(f"  🏆 NEUER HIGHSCORE: {self.highscore}!")
        print(f"  Highscore: {self.highscore}")
        print(f"  Geld: {self.money}")
        print(f"\n  restart - Neustart")
        print(f"  quit    - Beenden")

    def show_win(self):
        self.clear_screen()
        self.print_header("🎉 FIREWALL ZERSTÖRT!")
        print(f"\n  Belohnung: +{self.firewall.reward_watt} Geld")
        self.money += self.firewall.reward_watt
        self.score += self.firewall.health
        print(f"  Geld: {self.money} | Score: {self.score}")
        print(f"\n  buy <nr> - Shop | next - Nächste Runde")

    def start_run(self):
        self.board.clear()
        self.board.watt_budget = BASE_WATT_BUDGET
        self.money = 5
        self.score = 0
        self.round = 0
        self.inventory = Inventory()
        self.game_over = False
        self.won = False
        self.start_round()

    def start_round(self):
        self.round += 1
        self.firewall = Firewall(self.round)
        self.board.watt_budget = BASE_WATT_BUDGET + (self.round - 1) * WATT_PER_ROUND
        self.board.clear()

        # Geld-Bonus pro Runde
        self.money += 2 + self.round

        self.clear_screen()
        self.print_header(f"RUNDE {self.round}")
        self.print_status()
        self.print_board()
        print("\n  Platziere Bauteile, dann: send")
        print("  (help für Befehle)")

    def do_send(self):
        if self.firewall is None:
            print("  Keine Firewall aktiv!")
            return

        self.clear_screen()
        self.print_header(f"PAKETE SENDEN (Runde {self.round})")

        total_damage = 0
        packets = self.firewall.packets_per_round

        for i in range(packets):
            row = i % BOARD_HEIGHT
            val = self.board.simulate_packet_flow(row)
            self.firewall.take_damage(val)
            total_damage += val
            print(f"  Paket {i+1}/{packets} (Zeile {row}): {val} Schaden")

        print(f"\n  Gesamtschaden: {total_damage}")
        self.score += total_damage

        if not self.firewall.is_alive():
            self.won = True
            input("\n  Enter für Shop...")
            self.shop.generate_offerings(self.round)
            self.show_shop()
        else:
            self.game_over = True
            self.show_game_over()

    def do_buy(self, index):
        if not self.won:
            print("  Shop nur nach gewonnener Runde!")
            return

        result = self.shop.buy(index, self.money)
        if result["success"]:
            self.money -= result["price"]
            self.inventory.add_item(result["component_type"])
            print(f"  Gekauft: {result['name']} für {result['price']} Geld (Inventar)")
        else:
            print(f"  Fehler: {result['reason']}")

    def do_invuse(self, inv_idx, col, row):
        ct = self.inventory.peek_item(inv_idx)
        if ct is None:
            print(f"  Inventar-Index {inv_idx} ungültig!")
            return
        success, msg = self.board.place_component(col, row, ct)
        if success:
            self.inventory.take_item(inv_idx)
            print(f"  Platziert: {COMPONENT_NAMES[ct]} bei ({col},{row})")
            self.print_board()
        else:
            print(f"  Fehler: {msg}")

    def run(self):
        self.show_homescreen()

        while True:
            try:
                cmd = input("\n> ").strip().lower()
            except (EOFError, KeyboardInterrupt):
                print("\n  Bye!")
                break

            if not cmd:
                continue

            parts = cmd.split()
            action = parts[0]

            if action == "quit" or action == "q":
                print("  Spiel beendet!")
                break

            elif action == "start":
                self.start_run()

            elif action == "restart":
                self.start_run()

            elif action == "help" or action == "h":
                if self.game_over or self.round == 0:
                    self.show_homescreen()
                else:
                    self.show_help()

            elif action == "board":
                self.print_board()

            elif action == "status":
                self.print_status()

            elif action == "clear":
                if not self.game_over and self.round > 0:
                    self.board.clear()
                    print("  Brett geleert!")
                    self.print_board()
                else:
                    print("  Nicht in der Bau-Phase!")

            elif action == "place" or action == "p":
                if self.game_over or self.round == 0:
                    print("  Spiel starten mit 'start'!")
                    continue
                if len(parts) < 4:
                    print("  Usage: place <TYP> <x> <y>")
                    continue
                type_map = {"cpu": ComponentType.CPU, "gpu": ComponentType.GPU, 
                           "loop": ComponentType.LOOP, "npu": ComponentType.NPU,
                           "trace": ComponentType.TRACE}
                t = parts[1].upper()
                if t not in [k.upper() for k in type_map.keys()] and t.upper() not in ["CPU","GPU","LOOP","NPU","TRACE"]:
                    print(f"  Unbekannter Typ: {parts[1]}")
                    continue
                # Find the matching key
                key = None
                for k, v in type_map.items():
                    if k.upper() == t:
                        key = k
                        break
                if key is None:
                    t_upper = t
                    for k, v in type_map.items():
                        if v.name == t_upper:
                            key = k
                            break
                if key is None:
                    print(f"  Unbekannter Typ: {parts[1]}")
                    continue
                try:
                    col, row = int(parts[2]), int(parts[3])
                except:
                    print("  Ungültige Koordinaten!")
                    continue
                success, msg = self.board.place_component(col, row, type_map[key])
                if success:
                    print(f"  Platziert: {COMPONENT_NAMES[type_map[key]]} bei ({col},{row})")
                else:
                    print(f"  Fehler: {msg}")
                self.print_board()

            elif action == "remove" or action == "r":
                if self.game_over or self.round == 0:
                    print("  Spiel starten mit 'start'!")
                    continue
                if len(parts) < 3:
                    print("  Usage: remove <x> <y>")
                    continue
                try:
                    col, row = int(parts[1]), int(parts[2])
                except:
                    print("  Ungültige Koordinaten!")
                    continue
                success, msg = self.board.remove_component(col, row)
                if success:
                    print(f"  Entfernt von ({col},{row})")
                else:
                    print(f"  Fehler: {msg}")
                self.print_board()

            elif action == "invuse" or action == "i":
                if self.game_over or self.round == 0:
                    print("  Spiel starten mit 'start'!")
                    continue
                if len(parts) < 4:
                    print("  Usage: invuse <inv_index> <x> <y>")
                    continue
                try:
                    inv_idx, col, row = int(parts[1]), int(parts[2]), int(parts[3])
                except:
                    print("  Ungültige Parameter!")
                    continue
                self.do_invuse(inv_idx, col, row)

            elif action == "inv":
                if self.inventory.get_count() == 0:
                    print("  Inventar: (leer)")
                else:
                    print("  INVENTAR:")
                    for i in range(self.inventory.get_count()):
                        ct = self.inventory.peek_item(i)
                        print(f"    [{i}] {COMPONENT_NAMES[ct]} ({COMPONENT_WATT[ct]}W)")

            elif action == "send":
                if self.game_over or self.round == 0:
                    print("  Spiel starten mit 'start'!")
                    continue
                self.do_send()

            elif action == "buy" or action == "b":
                if len(parts) < 2:
                    print("  Usage: buy <nr>")
                    continue
                try:
                    idx = int(parts[1])
                except:
                    print("  Ungültiger Index!")
                    continue
                self.do_buy(idx)

            elif action == "next" or action == "n":
                if self.won:
                    self.won = False
                    self.start_round()
                else:
                    print("  Erst die Runde gewinnen!")

            elif action == "menu":
                self.game_over = False
                self.round = 0
                self.show_homescreen()

            else:
                print(f"  Unbekannter Befehl: {action}")
                print("  Tippe 'help' für Hilfe.")

        print("\n  Danke fürs Spielen!")


# =============================================
#  MAIN
# =============================================

if __name__ == "__main__":
    random.seed()
    game = Game()
    try:
        game.run()
    except KeyboardInterrupt:
        print("\n\n  Spiel beendet. Danke fürs Spielen!")
        sys.exit(0)