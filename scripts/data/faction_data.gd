class_name FactionData
extends Resource
## Describes a faction. Loaded from data/factions/*.tres at startup.

@export var id: String = ""
@export var name: String = ""
@export var description: String = ""
@export var color: Color = Color.WHITE
@export var starting_rep: int = 0
