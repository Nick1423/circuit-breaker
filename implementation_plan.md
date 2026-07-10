# Implementation Plan

## [Overview]
Implement the complete game logic for "Circuit Breaker" — a roguelike puzzle game where players place electronic components on a 6x4 board to amplify data packets that break through firewalls.

The game is inspired by Balatro's roguelike loop: each round the player sends packets through their component setup to deal damage to a firewall. Between rounds, they visit a shop to buy new components. The challenge lies in optimizing component placement with limited watt budget. This implementation covers all core logic without any visual/graphics layer — everything runs in the console for testing.

## [Types]
Define all data structures and enums needed for the game logic.

### Enums

```gdscript
# component.gd
enum ComponentType {
	TRACE,      # Leiterbahn - leitet nur weiter, 0 Watt
	CPU,        # Addiert festen Wert (+5), 2 Watt
	GPU,        # Multipliziert (x2), 5 Watt
	LOOP,       # Lässt Paket mehrfach durchlaufen, 3 Watt
	NPU         # Spezialeffekt (später), 4 Watt
}
```

### Data Structures

```gdscript
# component.gd
# Component resource/data
class Component:
	var type: ComponentType
	var name: String
	var watt_cost: int
	var heat_generation: int  # für später
	var description: String
	
	func _init(p_type: ComponentType):
		type = p_type
		match type:
			ComponentType.TRACE:
				name = "Leiterbahn"
				watt_cost = 0
				heat_generation = 0
				description = "Leitet Paket ohne Veränderung weiter"
			ComponentType.CPU:
				name = "CPU"
				watt_cost = 2
				heat_generation = 1
				description = "Addiert +5 zum Paketwert"
			ComponentType.GPU:
				name = "GPU"
				watt_cost = 5
				heat_generation = 3
				description = "Multipliziert Paketwert mit 2"
			ComponentType.LOOP:
				name = "Loop"
				watt_cost = 3
				heat_generation = 2
				description = "Lässt Paket 2x durchlaufen"
			ComponentType.NPU:
				name = "NPU"
				watt_cost = 4
				heat_generation = 2
				description = "Spezial: +3 pro benachbarter CPU"

# packet.gd
class Packet:
	var value: int
	var start_value: int = 1
	
	func _init():
		value = start_value

# firewall.gd
class FirewallConfig:
	var level: int
	var health: int
	var max_health: int
	var reward_watt: int
	var packets_per_round: int
	
	func _init(p_level: int):
		level = p_level
		max_health = 10 + (p_level * 5)
		health = max_health
		reward_watt = 2 + p_level
		packets_per_round = 3 + floor(p_level / 2)
```

## [Files]
Create new files and modify existing ones to implement the game logic.

### New Files to Create

1. **`component.gd`** - Component class with type enum, stats, and processing logic
2. **`packet.gd`** - Packet class that flows through components
3. **`firewall.gd`** - Firewall/round configuration and damage tracking
4. **`game_manager.gd`** - Main game loop: rounds, shop, win/lose conditions
5. **`shop.gd`** - Shop logic for buying components between rounds

### Existing Files to Modify

1. **`board.gd`** - Extend with:
   - Component placement/removal methods
   - Packet flow simulation (left to right)
   - Watt budget tracking
   - Board validation (path existence check)
   - Enhanced console output showing components

2. **`main.tscn`** - Add GameManager node as child (no visual changes needed)

## [Functions]
Define all functions needed across the codebase.

### component.gd

| Function | Signature | Purpose |
|----------|-----------|---------|
| `Component._init(type)` | `func _init(p_type: ComponentType)` | Initialize component with type-based stats |
| `Component.process_packet(packet)` | `func process_packet(packet: Packet) -> Packet` | Apply component effect to packet (add, multiply, loop) |
| `Component.get_display_char()` | `func get_display_char() -> String` | Return single char for console display |

### packet.gd

| Function | Signature | Purpose |
|----------|-----------|---------|
| `Packet._init()` | `func _init()` | Create packet with value=1 |
| `Packet.reset()` | `func reset()` | Reset packet to start value |

### firewall.gd

| Function | Signature | Purpose |
|----------|-----------|---------|
| `FirewallConfig._init(level)` | `func _init(p_level: int)` | Create firewall config for given level |
| `FirewallConfig.take_damage(amount)` | `func take_damage(amount: int) -> bool` | Reduce health, return true if destroyed |

### board.gd (modified)

| Function | Signature | Purpose |
|----------|-----------|---------|
| `_init_board()` | `func _init_board()` | Already exists - keep as is |
| `print_board()` | `func print_board()` | Already exists - enhance to show component chars |
| `place_component(col, row, component)` | `func place_component(col: int, row: int, component: Component) -> bool` | Place component at position, return success |
| `remove_component(col, row)` | `func remove_component(col: int, row: int) -> bool` | Remove component from position |
| `get_component(col, row)` | `func get_component(col: int, row: int) -> Component` | Get component at position |
| `simulate_packet_flow(start_col)` | `func simulate_packet_flow(start_col: int) -> Packet` | Simulate packet flowing left to right through row |
| `get_total_watt_usage()` | `func get_total_watt_usage() -> int` | Sum watt cost of all placed components |
| `is_valid_placement(col, row, component)` | `func is_valid_placement(col: int, row: int, component: Component) -> bool` | Check if placement is valid (within bounds, empty cell, watt budget) |
| `get_available_positions()` | `func get_available_positions() -> Array` | Return list of empty positions |

### game_manager.gd

| Function | Signature | Purpose |
|----------|-----------|---------|
| `_ready()` | `func _ready()` | Initialize game state, start first round |
| `start_round()` | `func start_round()` | Begin new round with firewall config |
| `send_packet(row)` | `func send_packet(row: int) -> int` | Send packet through row, return damage |
| `send_all_packets()` | `func send_all_packets() -> int` | Send all packets for current round |
| `end_round()` | `func end_round()` | Check if firewall destroyed, handle result |
| `start_shop_phase()` | `func start_shop_phase()` | Enter shop between rounds |
| `buy_component(component_type)` | `func buy_component(component_type: ComponentType) -> bool` | Purchase component from shop |
| `next_round()` | `func next_round()` | Advance to next round |
| `game_over()` | `func game_over()` | Handle game over state |
| `print_game_state()` | `func print_game_state()` | Print current game state to console |

### shop.gd

| Function | Signature | Purpose |
|----------|-----------|---------|
| `_init()` | `func _init()` | Initialize shop with available components |
| `generate_offerings(count)` | `func generate_offerings(count: int) -> Array` | Generate random component offerings |
| `buy(index)` | `func buy(index: int) -> Component` | Purchase component at index |
| `print_shop()` | `func print_shop()` | Print shop offerings to console |

## [Classes]
Define all class modifications.

### New Classes

1. **`Component`** (in `component.gd`)
   - Resource-like data class
   - Methods: `_init(type)`, `process_packet(packet)`, `get_display_char()`
   - No inheritance (plain class)

2. **`Packet`** (in `packet.gd`)
   - Simple data class
   - Properties: `value`, `start_value`
   - Methods: `_init()`, `reset()`

3. **`FirewallConfig`** (in `firewall.gd`)
   - Configuration and state class
   - Properties: `level`, `health`, `max_health`, `reward_watt`, `packets_per_round`
   - Methods: `_init(level)`, `take_damage(amount)`

4. **`GameManager`** (in `game_manager.gd`)
   - Extends `Node`
   - Main game controller
   - Properties: `board`, `firewall`, `current_round`, `watt_budget`, `gold`, `inventory`
   - All game loop methods

5. **`Shop`** (in `shop.gd`)
   - Plain class (not Node)
   - Properties: `offerings`, `prices`
   - Methods: `_init()`, `generate_offerings(count)`, `buy(index)`, `print_shop()`

### Modified Classes

1. **`board.gd`** (extends `Node2D`)
   - Add property: `watt_budget: int = 10`
   - Add property: `components: Array` (2D array of Component references)
   - Keep existing `board` array for null/occupied tracking
   - Add all placement and simulation methods

## [Dependencies]
No external dependencies. Pure GDScript in Godot 4.6.

## [Testing]
Test the game logic by running the Godot scene and checking console output.

### Test Scenarios
1. Board initialization (6x4 empty grid)
2. Component placement and removal
3. Packet flow simulation (single component, chain)
4. CPU+GPU order matters test (1+5)*2 vs (1*2)+5
5. Watt budget enforcement
6. Firewall damage tracking
7. Full round simulation (send packets, damage firewall)
8. Shop generation and purchasing
9. Multiple rounds with increasing difficulty
10. Game over condition

### Test Commands
```bash
# Run the scene in Godot headless (if available)
godot --headless --path . --scene main.tscn

# Or run in editor and check Output panel
```

## [Implementation Order]
Build the game logic bottom-up, testing each layer before moving to the next.

1. **Component system** - Create `component.gd` with ComponentType enum, Component class, and processing logic
2. **Packet system** - Create `packet.gd` with Packet class
3. **Board extension** - Add placement, removal, and simulation to `board.gd`
4. **Firewall system** - Create `firewall.gd` with FirewallConfig
5. **Game Manager** - Create `game_manager.gd` with round loop
6. **Shop system** - Create `shop.gd` with shop logic
7. **Integration** - Wire everything together in `main.tscn`, test full game loop
8. **Polish & edge cases** - Handle invalid states, add debug commands