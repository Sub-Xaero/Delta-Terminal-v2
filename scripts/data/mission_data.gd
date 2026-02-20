class_name MissionData
extends Resource
## Describes a single mission. Loaded from data/missions/*.tres at startup.

@export var id: String = ""
@export var title: String = ""
@export var description: String = ""
@export var faction_id: String = ""
@export var min_rep: int = 0
@export var reward_credits: int = 0
@export var objectives: Array[ObjectiveData] = []
@export var reward_rating: int = 0
@export var reward_per_rating_point: int = 0
@export var min_rating: int = 0
@export var triggers_story_mission: String = ""
@export var delivery_method: String = "job_board"
@export var auto_deliver_on_start: bool = false
