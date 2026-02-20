class_name NodeData
extends Resource
## Describes a network node. Loaded from data/nodes/*.tres at startup.

@export var id: String = ""
@export var ip: String = ""
@export var name: String = ""
@export var organisation: String = ""
@export var security: int = 0
@export var map_position: Vector2 = Vector2.ZERO
@export var files: Array = []
@export var services: Array = []
@export var connections: Array = []
@export var users: Array = []
@export var faction_id: String = ""
@export var shop_catalogue: Array = []
@export var public_interfaces: Array = []  # [{name, description, tool?}]
