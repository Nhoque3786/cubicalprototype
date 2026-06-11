extends Camera3D

@export var target : Node3D = null
@export var angle : float = 0.0
@export var radius : float = 5
@export var height : float = 0.0
@export var smooth_speed : float = 8.0
#TODO: add camera controls with R Stick/WASD/Mouse
func _ready() -> void:
	process_mode = PROCESS_MODE_ALWAYS
	set_projection(Camera3D.PROJECTION_ORTHOGONAL)

	far = 2000.0
	near = 0.1

	if target == null:
		print("No camera target, focusing on origin instead!")
		return
	
	_update_camera_pos(0.0)
	look_at(target.global_position, Vector3.UP)
		
func _process(delta: float) -> void:
	if target == null:
		return
	_update_camera_pos(delta)

func _update_camera_pos(delta: float) -> void:
	var rad: float = deg_to_rad(angle)
	var forward: Vector3 = Vector3(sin(rad), 0, cos(rad))
	var right: Vector3 = Vector3(forward.z, 0, -forward.x)

	var target_horiz_dist: float = right.dot(target.global_position)
	var target_vert_dist: float = target.global_position.y + height

	var target_pos: Vector3 = (right * target_horiz_dist) + (Vector3.UP * target_vert_dist)

	target_pos += forward * radius


	if delta > 0 and smooth_speed > 0:
		global_position = global_position.lerp(target_pos, 1.0 - exp(-smooth_speed * delta))
	else:
		global_position = target_pos

