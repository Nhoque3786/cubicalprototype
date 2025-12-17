extends Camera3D

@export var thing : CharacterBody3D = null
@export var angle : float = 0.0
@export var radius : float = 3.8
@export var height : float = 0.0

func _ready() -> void:
	set_projection(Camera3D.PROJECTION_ORTHOGONAL)
	if thing == null:
		print("No camera target, focusing on origin instead!")
		return
		
func _process(_delta: float) -> void:
	if thing == null:
		return
		
	var rad = deg_to_rad(angle)
	var offset =Vector3(sin(rad), height, cos(rad)) * radius
	global_position = thing.global_position + offset
	
	look_at(thing.global_position, Vector3.UP)
	return
