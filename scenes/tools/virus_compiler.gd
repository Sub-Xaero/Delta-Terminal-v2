class_name VirusCompiler
extends ToolWindow

# Compiles virus component files (.vc) into deployable virus executables.
# Requires 2+ components. 20-second compile operation.
# Compiled viruses can be deployed on connected nodes.

const MIN_COMPONENTS := 2
const COMPILE_TIME := 20.0

enum VirusType { DESTROY_DATA, BACKDOOR, WORM }
enum State { IDLE, COMPILING, COMPILED, DEPLOYING, DEPLOYED, NO_COMPONENTS }

var _state: State = State.NO_COMPONENTS
var _elapsed: float = 0.0
var _selected_type: VirusType = VirusType.WORM
var _compiled_virus: String = ""

@onready var _status_label: Label = $ContentArea/VBox/StatusLabel
@onready var _component_list: ItemList = $ContentArea/VBox/ComponentList
@onready var _type_option: OptionButton = $ContentArea/VBox/TypeOption
@onready var _compile_btn: Button = $ContentArea/VBox/CompileBtn
@onready var _deploy_btn: Button = $ContentArea/VBox/DeployBtn
@onready var _progress_bar: ProgressBar = $ContentArea/VBox/ProgressBar

func _ready() -> void:
	super._ready()
	custom_minimum_size = Vector2(480, 380)
	_type_option.add_item("WORM")
	_type_option.add_item("BACKDOOR")
	_type_option.add_item("DESTROY_DATA")
	_type_option.selected = 0
	_type_option.item_selected.connect(_on_type_selected)
	_compile_btn.pressed.connect(_on_compile_pressed)
	_deploy_btn.pressed.connect(_on_deploy_pressed)
	EventBus.network_connected.connect(_on_network_changed)
	EventBus.network_disconnected.connect(_on_network_changed.bind(""))
	_refresh_components()

func _process(delta: float) -> void:
	if _state == State.COMPILING:
		_elapsed += delta
		_progress_bar.value = _elapsed / COMPILE_TIME
		if _elapsed >= COMPILE_TIME:
			_on_compile_complete()

func _refresh_components() -> void:
	_component_list.clear()
	var storage: Array = GameManager.player_data.get("local_storage", [])
	var components := storage.filter(func(f: Dictionary) -> bool: return f.get("type", "") == "component")
	for f: Dictionary in components:
		_component_list.add_item("%s  [%d KB]" % [f.get("name", ""), f.get("size", 0) / 1024])
	if components.size() < MIN_COMPONENTS:
		_set_state(State.NO_COMPONENTS)
	else:
		_set_state(State.IDLE)

func _on_type_selected(idx: int) -> void:
	_selected_type = idx as VirusType

func _on_compile_pressed() -> void:
	_elapsed = 0.0
	_progress_bar.value = 0.0
	_set_state(State.COMPILING)
	EventBus.log_message.emit("Compiling virus...", "warn")

func _on_compile_complete() -> void:
	var type_name: String
	match _selected_type:
		VirusType.WORM:        type_name = "worm"
		VirusType.BACKDOOR:    type_name = "backdoor"
		VirusType.DESTROY_DATA: type_name = "destroy_data"
	_compiled_virus = "virus_%s.exe" % type_name
	var exe_entry := {"id": "compiled_virus", "name": _compiled_virus, "type": "exe", "size": 2048}
	var storage: Array = GameManager.player_data.get("local_storage", [])
	storage.append(exe_entry)
	GameManager.player_data["local_storage"] = storage
	_set_state(State.COMPILED)
	EventBus.tool_task_completed.emit("virus_compiler", "local_machine", true)
	EventBus.log_message.emit("Virus compiled: %s" % _compiled_virus, "info")

func _on_deploy_pressed() -> void:
	if not NetworkSim.is_connected:
		EventBus.log_message.emit("Not connected to any node.", "error")
		return
	var node_id := NetworkSim.connected_node_id
	_set_state(State.DEPLOYED)
	_apply_virus(node_id)
	EventBus.tool_task_completed.emit("virus_compiler", node_id, true)
	EventBus.log_message.emit("Virus deployed on %s" % node_id, "warn")

func _apply_virus(node_id: String) -> void:
	match _selected_type:
		VirusType.DESTROY_DATA:
			if NetworkSim.nodes.has(node_id):
				NetworkSim.nodes[node_id]["files"].clear()
				EventBus.log_message.emit("Data destroyed on %s." % node_id, "warn")
		VirusType.BACKDOOR:
			if not NetworkSim.exploits_installed.has(node_id):
				NetworkSim.exploits_installed[node_id] = []
			if "backdoor" not in NetworkSim.exploits_installed[node_id]:
				NetworkSim.exploits_installed[node_id].append("backdoor")
			EventBus.log_message.emit("Backdoor installed on %s." % node_id, "warn")
		VirusType.WORM:
			var spread_targets := NetworkSim.nodes[node_id].get("connections", [])
			for target_id: String in spread_targets:
				var target_data := NetworkSim.get_node_data(target_id)
				if target_data.get("security", 99) <= 2 and target_id not in NetworkSim.cracked_nodes:
					NetworkSim.cracked_nodes.append(target_id)
					EventBus.log_message.emit("Worm spread to %s." % target_id, "warn")

func _on_network_changed(_node_id: String = "") -> void:
	_deploy_btn.disabled = not (NetworkSim.is_connected and _state == State.COMPILED)

func _set_state(s: State) -> void:
	_state = s
	match s:
		State.NO_COMPONENTS:
			_status_label.text = "Insufficient components. Need %d+ .vc files." % MIN_COMPONENTS
			_compile_btn.disabled = true
			_deploy_btn.disabled = true
		State.IDLE:
			_status_label.text = "Components loaded. Select virus type and compile."
			_compile_btn.disabled = false
			_deploy_btn.disabled = true
		State.COMPILING:
			_status_label.text = "Compiling..."
			_compile_btn.disabled = true
			_deploy_btn.disabled = true
		State.COMPILED:
			_status_label.text = "Virus ready: %s" % _compiled_virus
			_compile_btn.disabled = true
			_deploy_btn.disabled = not NetworkSim.is_connected
		State.DEPLOYING:
			_status_label.text = "Deploying..."
			_deploy_btn.disabled = true
		State.DEPLOYED:
			_status_label.text = "Virus deployed successfully."
			_deploy_btn.disabled = true
