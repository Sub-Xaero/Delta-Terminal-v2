class_name ObjectiveData
extends Resource
## A single mission objective. Instances are owned by a MissionData resource.

enum Type {
	CONNECT_TO,        # Connect to a specific node        (target = node_id)
	CRACK_NODE,        # Successfully crack a node          (target = node_id)
	STEAL_FILE,        # Download a file from a node        (target = file name) — future
	SCAN_NODE,         # Run a port scan on a node          (target = node_id)   — future
	DISCONNECT,        # Cleanly disconnect from a session  (target = "")        — future
	DELETE_LOG,        # Delete a log entry on a node       (target = node_id)
	STEAL_CREDENTIALS, # Steal credentials from a node      (target = node_id)
	MODIFY_RECORD,     # Modify a record on a node          (target = node_id)
	TRANSFER_FUNDS,    # Steal funds via bank terminal      (target = node_id)
	DEPLOY_VIRUS,      # Deploy a compiled virus on a node  (target = node_id)
}

@export var description: String = ""
@export var type: Type = Type.CONNECT_TO
@export var target: String = ""
## Runtime flag — set to true when the objective is satisfied this session.
## Not persisted; always starts false when the resource is first loaded.
@export var completed: bool = false
