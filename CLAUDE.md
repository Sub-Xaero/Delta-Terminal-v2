# Delta Terminal — CLAUDE.md

Cyberpunk hacking game built in Godot 4.6, inspired by Uplink. The player operates a desktop OS, connects through a network of nodes, cracks security, and completes missions while evading trace detection.

**GitHub repo:** `Sub-Xaero/Delta-Terminal-v2`

---

## Engine & Tooling

- **Engine:** Godot 4.6 (Forward Plus renderer)
- **Language:** GDScript (typed where practical)
- **Viewport:** 1280×720
- **Main scene:** `res://scenes/desktop/desktop.tscn`

---

## Project Structure

```
scenes/
  desktop/
    desktop.tscn / desktop.gd          # Root OS shell scene
    tool_window.tscn / tool_window.gd  # Base draggable window (ToolWindow class)
    window_manager.gd                  # Spawns/layers/closes tool windows
    taskbar.gd                         # Dock with tool buttons + clock
    crt_background.gdshader            # CRT scanline/grid visual effect
  tools/
    system_log.tscn / system_log.gd    # Passive log feed (always open)
    trace_tracker.tscn / trace_tracker.gd
    network_map.tscn / network_map.gd (+ canvas + node widgets)
    password_cracker.tscn / password_cracker.gd
  network/                             # (placeholder)
  ui/                                  # (placeholder)
scripts/
  autoloads/
    event_bus.gd                       # Global signal hub (autoloaded as EventBus)
    game_manager.gd                    # State machine + player data (GameManager)
    network_sim.gd                     # Network/trace simulation (NetworkSim)
assets/
  fonts/ sounds/ textures/             # (currently empty)
data/
  missions/ nodes/                     # (currently empty — future data-driven content)
```

---

## Architecture

### EventBus (global signal hub)
All cross-system communication goes through `EventBus`. Never couple systems directly — emit a signal instead.

Key signals:
| Signal | Args | Purpose |
|---|---|---|
| `network_connected` | `node_id` | Node connection established |
| `network_disconnected` | — | Session ended |
| `bounce_chain_updated` | `chain: Array` | Routing chain changed |
| `trace_started` | `duration` | Trace timer begins |
| `trace_progress` | `progress 0–1` | Tick update |
| `trace_completed` | — | Trace reached 100% |
| `tool_opened` | `tool_name` | Window spawned |
| `tool_closed` | `tool_name` | Window removed |
| `tool_focus_requested` | `tool_name` | Bring window to front |
| `tool_task_started` | `tool_name, task_id` | Long op begun |
| `tool_task_completed` | `tool_name, task_id, success` | Long op result |
| `log_message` | `text, level` | Append to system log |
| `context_menu_requested` | `position` | Show right-click menu |
| `mission_accepted/completed/failed` | varies | Mission lifecycle |
| `player_stats_changed` | — | Credits/rating updated |

### WindowManager
- Accessed as `$WindowLayer` on the Desktop node.
- `spawn_tool_window(scene: PackedScene, tool_name: String) -> ToolWindow`
  - Returns existing window and focuses it if already open (singleton behaviour).
  - Cascades position so windows don't overlap exactly.
- Tracks open windows in `open_windows: Dictionary` (tool_name → ToolWindow).

### ToolWindow (base class)
All tool windows extend `ToolWindow` (which extends `Panel`).
- Draggable via title bar; clamped to screen bounds.
- Click-to-focus raises z-order via `move_child`.
- Right-click anywhere on the window re-emits `context_menu_requested`.
- Closing calls `EventBus.tool_closed.emit(tool_name)` and `queue_free()`.
- Call `super._ready()` first in subclass `_ready()`.
- Set `custom_minimum_size` on the root node to control window size.

### NetworkSim (autoload)
Manages all in-game network state. Direct property reads are fine; mutations go through its methods.

```gdscript
NetworkSim.is_connected          # bool
NetworkSim.connected_node_id     # String
NetworkSim.cracked_nodes         # Array[String]
NetworkSim.bounce_chain          # Array[String]
NetworkSim.trace_active          # bool
NetworkSim.trace_progress        # float 0–1

NetworkSim.connect_to_node(id)   # returns bool
NetworkSim.disconnect_from_node()
NetworkSim.start_trace(duration) # starts trace timer
NetworkSim.crack_node(id)        # marks node as cracked
NetworkSim.get_node_data(id)     # returns Dictionary
NetworkSim.register_node(data)   # adds node to registry
```

Node data schema:
```gdscript
{
  "id": String,
  "ip": String,
  "name": String,
  "security": int,        # 0 = own machine, 1–2 low, 3–4 medium, 5+ high
  "map_position": Vector2,
  "files": Array,
  "services": Array,
  "connections": Array[String],  # IDs of adjacent nodes
}
```

### GameManager (autoload)
```gdscript
GameManager.state               # GameManager.State enum
GameManager.player_data         # { handle, credits, rating }
GameManager.transition_to(state)
GameManager.add_credits(amount)
GameManager.accept_mission(id)
```

---

## Adding a New Tool

1. Create `scenes/tools/my_tool.tscn` — root node should be a `ToolWindow` (or scene that extends it).
2. Attach `scenes/tools/my_tool.gd` extending `ToolWindow`. Call `super._ready()`.
3. Set `custom_minimum_size` on the root to set the window's default size.
4. Preload and add it to `desktop.gd`:
   ```gdscript
   const MyToolScene := preload("res://scenes/tools/my_tool.tscn")
   # In _setup_context_menu(), add a menu item
   # In _on_context_menu_id_pressed(), spawn it:
   window_manager.spawn_tool_window(MyToolScene, "My Tool")
   ```
5. Emit meaningful events via `EventBus.log_message` so the System Log stays useful.

---

## Colour Palette

| Role | Colour | Hex |
|---|---|---|
| Primary / info | Cyan | `#00E1FF` — `Color(0.0, 0.88, 1.0)` |
| Danger / close | Hot pink | `#FF1580` — `Color(1.0, 0.08, 0.55)` |
| Warning / medium | Amber | `#FFBF00` — `Color(1.0, 0.75, 0.0)` |
| Window bg | Deep navy | `Color(0.04, 0.03, 0.10, 0.95)` |
| Title bar bg | Dark purple | `Color(0.06, 0.04, 0.14)` |
| Border | Cyan 1px | same as primary |
| Muted text | Slate | `Color(0.35, 0.35, 0.45)` |

Log level colours: `info` → cyan, `warn` → amber, `error` → hot pink.

---

## Code Conventions

- Typed GDScript where practical (`var foo: String`, `func bar(x: int) -> void`).
- Section separator comments: `# ── Section name ───...` (em-dash style).
- Private vars/methods prefixed with `_`.
- `class_name` on every script that is referenced externally.
- Keep tool logic self-contained — read state from autoloads, write back via their methods or EventBus signals.
- `log_message` for any meaningful event so the System Log stays informative.

---

## Implemented Features (Wave 1)

- [x] Desktop OS shell with CRT shader background
- [x] WindowManager — spawning, layering, dragging, closing
- [x] Taskbar with dynamic tool buttons and live clock
- [x] Right-click context menu
- [x] System Log (passive, always open)
- [x] Trace Tracker (passive monitor, always open)
- [x] Network Map (visualisation + connect/disconnect)
- [x] Password Cracker (timed crack with trace pressure)
- [x] EventBus signal architecture
- [x] NetworkSim with 6 default nodes
- [x] GameManager state machine + player data

## Pending / Planned

- [ ] Missions system (data structures exist, no UI)
- [ ] Main menu scene
- [ ] Data-driven node/mission loading from `data/`
- [ ] Additional tools (file browser, port scanner, firewall bypass, etc.)
- [ ] Font, sound, and texture assets
