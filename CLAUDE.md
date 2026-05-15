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
    desktop.tscn / desktop.gd          # Root OS shell scene — preloads all tools
    tool_window.tscn / tool_window.gd  # Base draggable window (ToolWindow class)
    window_manager.gd                  # Spawns/layers/closes tool windows
    taskbar.gd                         # Dock with tool buttons + live clock
    sidebar.gd                         # Left-side status panel
    crt_background.gdshader            # CRT scanline/grid visual effect
  tools/                               # 27 tool window scenes (see list below)
  ui/
    boot_sequence.tscn                 # Startup intro sequence
    pause_menu.tscn                    # In-game pause menu
    settings.tscn                      # Audio/CRT/fullscreen/autosave settings
scripts/
  autoloads/                           # 14 autoloads registered in project settings
  data/                                # Resource class definitions (not instances)
assets/
  fonts/ sounds/ textures/
data/
  missions/   # 14 MissionData .tres files
  nodes/      # 40 NodeData .tres files
  factions/   # 3 FactionData .tres files (ghost_collective, nova_corp, syn_underground)
```

### Tool Windows (scenes/tools/)

| Scene | Purpose |
|---|---|
| `bank_terminal` | View/transfer player account balances |
| `comms_client` | Email inbox — mission delivery + NPC messages |
| `credential_manager` | Browse stolen credentials per node |
| `dictionary_hacker` | Wordlist-based crack (gated by exe) |
| `encryption_breaker` | Break node encryption layer (gated) |
| `faction_job_board` | Mission board filtered by faction rep |
| `file_browser` | Browse and steal files from connected node |
| `firewall_bypasser` | Bypass firewall on high-security nodes (gated) |
| `hardware_viewer` | Inspect and upgrade installed hardware |
| `lan_console` | Access LAN sub-nodes on cracked nodes |
| `log_deleter` | Delete access.log entries to avoid detection (gated) |
| `mission_log` | Track active/completed missions |
| `network_map` | Visual map of nodes + bounce chain UI |
| `network_map_node` | Individual node widget (used inside network_map_canvas) |
| `node_directory` | ISP-style node lookup/discovery |
| `password_cracker` | Timed online crack with trace pressure (gated) |
| `player_profile` | Handle, credits, rating, heat, faction rep |
| `port_scanner` | Scan services on a node (gated) |
| `record_editor` | Browse and modify database records |
| `software_shop` | Purchase exe files with credits |
| `stock_terminal` | Trade NCORP/MERI/SYND stocks |
| `system_links` | Discover linked nodes from current connection |
| `system_log` | Passive log feed (always open) |
| `system_view` | View node info, security level, services |
| `trace_tracker` | Passive trace progress monitor (always open) |
| `voice_analyser` | Analyse voice samples (gated) |
| `voice_comms` | VOIP call interface (gated) |

Passive tools (always open, never closed): `system_log`, `trace_tracker`, `network_map`, `mission_log`.

Tool exe gates — these tools require a matching `.exe` in `local_storage` before they can be opened: Password Cracker, Port Scanner, Firewall Bypasser, Encryption Breaker, Log Deleter, Credential Manager, Record Editor, Stock Terminal, Dictionary Hacker, Voice Analyser, Voice Comms.

---

## Architecture

### EventBus (global signal hub)

All cross-system communication goes through `EventBus`. Never couple systems directly.

**Network**
| Signal | Args | Purpose |
|---|---|---|
| `network_connected` | `node_id: String` | Session established |
| `network_disconnected` | — | Session ended |
| `bounce_chain_updated` | `chain: Array` | Routing chain changed |
| `firewall_bypassed` | `node_id: String` | Firewall cleared |

**Trace**
| Signal | Args | Purpose |
|---|---|---|
| `trace_started` | `duration: float` | Trace timer begins |
| `trace_progress` | `progress: float` | Tick update (0–1) |
| `trace_completed` | — | Trace reached 100% |
| `passive_trace_started` | `origin_node_id: String` | Sysadmin passive trace |

**Tools**
| Signal | Args | Purpose |
|---|---|---|
| `open_tool_requested` | `tool_name: String` | Request tool spawn |
| `tool_opened` | `tool_name` | Window spawned |
| `tool_closed` | `tool_name` | Window removed |
| `tool_focus_requested` | `tool_name` | Bring to front |
| `tool_task_started` | `tool_name, task_id` | Long op begun |
| `tool_task_completed` | `tool_name, task_id, success` | Long op result |

**Missions**
| Signal | Args | Purpose |
|---|---|---|
| `mission_accepted` | `mission_id` | Mission started |
| `mission_objective_completed` | `mission_id, objective_index` | One objective done |
| `mission_completed` | `mission_id` | All objectives done |
| `mission_failed` | `mission_id, reason` | Mission lost |

**System / UI**
| Signal | Args | Purpose |
|---|---|---|
| `log_message` | `text, level` | Append to system log |
| `player_stats_changed` | — | Credits/rating updated |
| `context_menu_requested` | `at_position: Vector2` | Right-click menu |
| `pause_requested` | — | Open pause menu |

**Hardware**
| Signal | Args | Purpose |
|---|---|---|
| `hardware_changed` | — | Hardware install/remove |
| `system_nuke_triggered` | — | Emergency wipe |

**Discovery / Evidence**
| Signal | Args | Purpose |
|---|---|---|
| `node_discovered` | `node_id` | Node added to map |
| `node_removed` | `node_id` | Node wiped from map |
| `intrusion_logged` | `node_id` | Unclean disconnect flagged |
| `credentials_stolen` | `node_id, count` | Creds harvested |
| `exploit_installed` | `node_id, exploit_type` | Persistent exploit placed |
| `bank_transfer_completed` | `node_id, amount` | Funds moved |

**Factions / Heat**
| Signal | Args | Purpose |
|---|---|---|
| `faction_rep_changed` | `faction_id, new_rep` | Rep updated |
| `player_heat_changed` | `new_heat: int` | Heat updated |

**Comms / Market**
| Signal | Args | Purpose |
|---|---|---|
| `comms_message_received` | `message_id` | New email |
| `news_headline_added` | `text` | Ticker event |
| `voip_call_made` | `target_number, connected` | VOIP attempt |
| `voip_authentication_granted` | `node_id` | Voice cipher passed |
| `stock_price_changed` | `symbol, new_price` | Market tick |

**Nuke escape**
| Signal | Args | Purpose |
|---|---|---|
| `nuke_escape_success` | — | Nuke triggered in time |
| `nuke_too_late` | — | Trace completed before nuke |

---

### WindowManager

Accessed as `$WindowLayer` on the Desktop node.

```gdscript
window_manager.spawn_tool_window(scene: PackedScene, tool_name: String) -> ToolWindow
```

- Returns existing window and focuses it if already open (singleton behaviour).
- Cascades position so windows don't stack exactly.
- Tracks open windows in `open_windows: Dictionary` (tool_name → ToolWindow).

---

### ToolWindow (base class)

All tool windows extend `ToolWindow` (which extends `Panel`).

- Draggable via title bar; clamped to screen bounds.
- Click-to-focus raises z-order via `move_child`.
- Right-click anywhere re-emits `context_menu_requested`.
- Closing calls `EventBus.tool_closed.emit(tool_name)` and `queue_free()`.
- Call `super._ready()` first in subclass `_ready()`.
- Set `custom_minimum_size` on the root node to control default size.

---

### GameManager (autoload)

```gdscript
enum State { MAIN_MENU, DESKTOP, CONNECTING, HACKING }

GameManager.state                    # GameManager.State
GameManager.player_data              # Dictionary — see fields below
GameManager.transition_to(state)
GameManager.add_credits(amount: int)
GameManager.accept_mission(id: String)
```

`player_data` fields:
```gdscript
{
  "handle":        String,
  "credits":       int,
  "rating":        int,           # increases on mission_completed
  "heat":          int,           # 0–100 persistent wanted level
  "faction_rep":   Dictionary,    # faction_id → int (-100 to +100)
  "local_storage": Array,         # Array of file dicts (exe files owned)
  "player_accounts": Dictionary,  # node_id → { username, role }
}
```

---

### NetworkSim (autoload)

Manages all in-game network state. Read properties directly; mutations go through methods.

```gdscript
NetworkSim.is_connected              # bool
NetworkSim.connected_node_id         # String
NetworkSim.bounce_chain              # Array[String]
NetworkSim.cracked_nodes             # Array[String]
NetworkSim.bypassed_nodes            # Array[String]
NetworkSim.encryption_broken_nodes   # Array[String]
NetworkSim.discovered_nodes          # Array[String]
NetworkSim.exploits_installed        # Dictionary (node_id → Array of exploit type strings)
NetworkSim.trace_active              # bool
NetworkSim.trace_progress            # float 0–1

NetworkSim.connect_to_node(node_id) → bool   # Blocked if heat >= 80 (non-local)
NetworkSim.disconnect_from_node()             # Triggers passive trace if unclean logs exist
NetworkSim.add_to_bounce_chain(node_id)
NetworkSim.remove_from_bounce_chain(node_id)
NetworkSim.start_trace(duration: float)
NetworkSim.crack_node(node_id)
NetworkSim.bypass_node(node_id)
NetworkSim.break_encryption(node_id)
NetworkSim.discover_node(node_id)
NetworkSim.register_node(data)
NetworkSim.get_node_data(node_id) → Dictionary
NetworkSim.clear_intrusion_log(node_id)
NetworkSim.delete_file_from_node(node_id, file_id) → bool
NetworkSim.node_requires_bypass(node_id) → bool   # true if security >= 3 or has_firewall
```

Node data schema (`NodeData` resource):
```gdscript
{
  "id":                String,
  "ip":                String,
  "name":              String,
  "organisation":      String,
  "security":          int,        # 0 = own machine, 1–2 low, 3–4 medium, 5+ high
  "map_position":      Vector2,
  "files":             Array,      # Array of file dicts
  "services":          Array,      # e.g. ["banking", "job_board", "node_directory"]
  "connections":       Array,      # Array[String] adjacent node IDs
  "users":             Array,      # Array of { username, password_hash, role }
  "faction_id":        String,
  "shop_catalogue":    Array,
  "public_interfaces": Array,
  "node_type":         String,
  "lan_nodes":         Array,
}
```

---

### FactionManager (autoload)

```gdscript
FactionManager.get_rep(faction_id: String) → int          # -100 to +100
FactionManager.modify_rep(faction_id: String, delta: int)  # clamps, emits faction_rep_changed
FactionManager.get_faction(faction_id: String) → FactionData
```

Factions: `ghost_collective`, `nova_corp`, `syn_underground`. Loaded from `data/factions/*.tres`.

---

### MissionManager (autoload)

```gdscript
MissionManager.available_missions    # Dictionary (id → MissionData)
MissionManager.active_missions       # Dictionary (id → MissionData deep-copy)

MissionManager.accept_mission(mission_id: String)
MissionManager.restore_active_missions(ids: Array)
MissionManager.deliver_mission_by_email(mission_id: String)
```

Objective types (`ObjectiveData.Type` enum): `CONNECT_TO`, `CRACK_NODE`, `STEAL_FILE`, `SCAN_NODE`, `DISCONNECT`, `DELETE_LOG`, `STEAL_CREDENTIALS`, `MODIFY_RECORD`, `TRANSFER_FUNDS`.

Objectives auto-complete by listening to EventBus signals — no manual calls needed from tools.

Reward formula: `reward_credits + (reward_rating × player_rating)`.

---

### HardwareManager (autoload)

```gdscript
HardwareManager.ram_slots_total       # int
HardwareManager.ram_capacity          # int (total RAM units)
HardwareManager.ram_used              # int (open tools consume RAM)
HardwareManager.modem_trace_multiplier # float (higher = faster trace reduction)
HardwareManager.active_hack_count     # int
HardwareManager.effective_stack_speed # float = cpu_speed / max(1, active_hack_count)

HardwareManager.can_open_tool(tool_name: String) → bool   # passive tools always true
HardwareManager.purchase_item(item_id: String) → bool      # deducts credits, installs
HardwareManager.trigger_nuke()                             # emergency wipe + reset
HardwareManager.get_save_data() → Dictionary
HardwareManager.load_save_data(data: Dictionary)
```

Hardware catalog (key items):
- **Motherboards:** `mobo_basic` (2 slots, free), `mobo_pro` (4 slots, $2 500), `mobo_elite` (6 slots, $8 000)
- **RAM:** `ram_256` (1 cap, $500), `ram_512` (2 cap, $1 200), `ram_1gb` (4 cap, $3 000)
- **CPU stacks:** `cpu_z80` (1×, free), `cpu_dual` (2×, $3 000), `cpu_quad` (4×, $8 000), `cpu_quantum` (8×, $20 000)
- **Network:** `net_56k` (1× trace, free), `net_cable` (1.5×, $1 000), `net_fiber` (2×, $4 000), `net_quantum` (3×, $12 000)
- **Security:** `sec_dead_mans` (auto-nuke on trace complete, $5 000), `sec_kill_sw` (manual nuke, $8 000)

---

### SaveManager (autoload)

Persists to `user://save.json` (SAVE_VERSION = 2). Auto-saves on `network_disconnected` and mission events when `SettingsManager.autosave` is true.

```gdscript
SaveManager.has_save() → bool
SaveManager.save_game()
SaveManager.load_game() → bool
SaveManager.delete_save()
```

Keys saved: `version`, `player_data`, `active_missions`, `completed_missions`, `local_storage`, `cracked_nodes`, `node_state` (per-node files + scanned_ports), `hardware`, `credentials`, `comms_inbox`, `exploits_installed`, `discovered_nodes`, `tutorial_flags`, `market`.

---

### SettingsManager (autoload)

Persists to `user://settings.cfg`. Properties apply immediately when set.

```gdscript
SettingsManager.master_volume    # float
SettingsManager.sfx_volume       # float
SettingsManager.ambient_volume   # float
SettingsManager.crt_enabled      # bool
SettingsManager.crt_intensity    # float
SettingsManager.fullscreen       # bool
SettingsManager.autosave         # bool
```

---

### Other Autoloads

| Autoload | Key API |
|---|---|
| `AudioManager` | `play_sfx(key)`, `set_ambient(key)`, `toggle_mute()` |
| `CommsManager` | `send_message(msg: Dictionary)`, `mark_read(msg_id)`, `get_unread_count() → int` |
| `CredentialManager` | `add_credentials(node_id, creds)`, `get_credentials(node_id)`, `has_credentials(node_id) → bool` |
| `MarketManager` | `buy(symbol, qty) → bool`, `sell(symbol, qty) → bool`, `portfolio_value() → int` |
| `VoiceManager` | `store_sample(node_id, file)`, `has_sample_for(node_id) → bool`, `authenticate_node(node_id) → bool` |
| `FontManager` | Loads `Rajdhani-Regular.ttf` at runtime |

---

## Adding a New Tool

1. Create `scenes/tools/my_tool.tscn` — root node extends `ToolWindow`.
2. Attach `scenes/tools/my_tool.gd` extending `ToolWindow`. Call `super._ready()` first.
3. Set `custom_minimum_size` on the root to control default size.
4. Preload and register in `desktop.gd`:
   ```gdscript
   const MyToolScene := preload("res://scenes/tools/my_tool.tscn")
   # In _setup_context_menu() add a menu item
   # In _on_context_menu_id_pressed() spawn it:
   window_manager.spawn_tool_window(MyToolScene, "My Tool")
   ```
5. If it requires an exe gate, add it to `TOOL_EXE_REQUIREMENTS` in `desktop.gd`.
6. Emit `EventBus.log_message` for meaningful events so the System Log stays useful.

---

## Colour Palette

| Role | Colour | Hex / GDScript |
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
- `class_name` on every script referenced externally.
- Keep tool logic self-contained — read state from autoloads, write back via their methods or EventBus.
- Emit `EventBus.log_message` for any meaningful event so the System Log stays informative.

---

## Implemented Features

- [x] Desktop OS shell with CRT shader background and sidebar
- [x] WindowManager — spawning, layering, dragging, closing, exe gating
- [x] Taskbar with dynamic tool buttons, pinned icons, and live clock
- [x] Right-click context menu + desktop service icons (banking, shop, job board, etc.)
- [x] Boot sequence and main menu scene
- [x] System Log and Trace Tracker (passive, always open)
- [x] Network Map — visual node graph, bounce chain UI, compact node widgets
- [x] Password Cracker (online timed crack with trace pressure)
- [x] Firewall Bypasser, Encryption Breaker, Port Scanner, Dictionary Hacker
- [x] File Browser (browse + steal files from connected node)
- [x] Log Deleter (clean access.log entries before disconnect)
- [x] Mission Log, Faction Job Board, Node Directory, System Links
- [x] Comms Client (email inbox, mission delivery)
- [x] Bank Terminal and financial system (accounts.db, transactions.log)
- [x] Software Shop (purchase exe files)
- [x] Stock Terminal (NCORP / MERI / SYND trading)
- [x] Hardware Viewer (upgrade mobo, RAM, CPU, network card, security)
- [x] Player Profile (handle, credits, rating, heat, faction rep)
- [x] Credential Manager (view stolen credentials)
- [x] Record Editor (browse + modify database records)
- [x] LAN Console (access sub-nodes)
- [x] Voice Analyser and Voice Comms (VOIP tools, gated)
- [x] EventBus architecture (40+ signals)
- [x] NetworkSim — 40 data-driven nodes, bounce chain, trace, passive trace on unclean disconnect
- [x] GameManager state machine — heat, faction_rep, local_storage, player_accounts
- [x] FactionManager — ghost_collective, nova_corp, syn_underground
- [x] MissionManager — 14 missions, all objective types, email delivery, reward formula
- [x] HardwareManager — full catalog, RAM gating, nuke mechanic
- [x] SaveManager — full persistence (SAVE_VERSION 2), autosave
- [x] SettingsManager — audio, CRT, fullscreen, autosave
- [x] AudioManager — SFX pool and ambient loops

## Open Issues (tracked on GitHub)

| # | Feature | Notes |
|---|---|---|
| #18 | Factions & contacts system | FactionManager exists; job board needs rep gating wired end-to-end |
| #23 | Heat / reputation system | `heat` field exists in player_data; escalation logic + heat_changed events needed |
| #17 | News ticker | Reactive headline strip; depends on heat + event signals |
| #22 | Tutorial | TutorialManager autoload + dismissible toast hints |
| #39 | Credential system | CredentialManager stub exists; steal flow + direct login needed |
| #40 | Offline password cracking | Depends on #39; wordlist mode for Password Cracker |
| #16 | Bank & financial system | BankTerminal exists; audit trail + evidence loop needs completing |
| #44 | Sysadmin response / evidence trails | Intrusion flagging on unclean disconnect; HOT node indicator |
| #41 | Government servers + Record Viewer | Meridian Gov + SynthGov nodes; active_warrants at heat ≥ 75 |
| #42 | Exploit installer + botnet | bounce_relay + botnet_node exploits; NetworkSim.exploits_installed exists |
| #43 | VOIP + voice cipher | VoiceManager + VoiceComms exist; full call flow needed |
