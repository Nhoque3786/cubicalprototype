# Camera's core. It follows the player and it's controllable with R stick or JIKL keys
# TODO: i need to implement camera controls here
extends Camera3D

@export var radius : float = 3.8 

func _ready() -> void:
	set_projection(Camera3D.PROJECTION_ORTHOGONAL)
	position = Vector3(0, 0, radius)
pass