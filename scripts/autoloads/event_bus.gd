extends Node
## Global signal bus. All cross-system communication goes through here.
## Usage: EventBus.some_signal.emit(args)

# ── Network ──────────────────────────────────────────────────────────────────
signal network_connected(node_id: String)
signal network_disconnected()
signal bounce_chain_updated(chain: Array)
signal firewall_bypassed(node_id: String)

# ── Trace ─────────────────────────────────────────────────────────────────────
signal trace_started(duration: float)
signal trace_progress(progress: float)   # 0.0 – 1.0
signal trace_completed()

# ── Tools ─────────────────────────────────────────────────────────────────────
signal open_tool_requested(tool_name: String)
signal tool_opened(tool_name: String)
signal tool_closed(tool_name: String)
signal tool_focus_requested(tool_name: String)
signal tool_task_started(tool_name: String, task_id: String)
signal tool_task_completed(tool_name: String, task_id: String, success: bool)

# ── Missions ──────────────────────────────────────────────────────────────────
signal mission_accepted(mission_id: String)
signal mission_objective_completed(mission_id: String, objective_index: int)
signal mission_completed(mission_id: String)
signal mission_failed(mission_id: String, reason: String)

# ── System / UI ───────────────────────────────────────────────────────────────
signal log_message(text: String, level: String)   # level: "info" | "warn" | "error"
signal player_stats_changed()
signal context_menu_requested(at_position: Vector2)
signal pause_requested()

# ── Hardware ───────────────────────────────────────────────────────────────────
signal hardware_changed()          # any install/uninstall or hack count change
signal system_nuke_triggered()     # fired after full state reset; desktop reacts

# ── Discovery & Intrusion ────────────────────────────────────────────────────
signal node_discovered(node_id: String)
signal intrusion_logged(node_id: String)
signal credentials_stolen(node_id: String, count: int)
signal exploit_installed(node_id: String, exploit_type: String)

# ── Factions & Heat ──────────────────────────────────────────────────────────
signal faction_rep_changed(faction_id: String, new_rep: int)
signal player_heat_changed(new_heat: int)

# ── Comms ────────────────────────────────────────────────────────────────────
signal comms_message_received(message_id: String)
signal news_headline_added(text: String)
signal voip_call_made(target_number: String, connected: bool)
