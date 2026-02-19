extends Node
## Global signal bus. All cross-system communication goes through here.
## Usage: EventBus.some_signal.emit(args)

# ── Network ──────────────────────────────────────────────────────────────────
signal network_connected(node_id: String)
signal network_disconnected()
signal bounce_chain_updated(chain: Array)

# ── Trace ─────────────────────────────────────────────────────────────────────
signal trace_started(duration: float)
signal trace_progress(progress: float)   # 0.0 – 1.0
signal trace_completed()

# ── Tools ─────────────────────────────────────────────────────────────────────
signal tool_opened(tool_name: String)
signal tool_closed(tool_name: String)
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
