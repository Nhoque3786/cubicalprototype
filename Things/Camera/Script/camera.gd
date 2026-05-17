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
	if target == null:
		print("No camera target, focusing on origin instead!")
		return
	
	# Initial rotation setup
	var rad: float = deg_to_rad(angle)
	var offset: Vector3 = Vector3(sin(rad) * radius, height, cos(rad) * radius)
	global_position = target.global_position + offset
	look_at(target.global_position, Vector3.UP)
		
func _process(delta: float) -> void:
	if target == null:
		return

	var rad: float = deg_to_rad(angle)
	var offset: Vector3 = Vector3(sin(rad) * radius, height, cos(rad) * radius)
	var target_pos: Vector3 = target.global_position + offset

	if smooth_speed > 0:
		global_position = global_position.lerp(target_pos, 1.0 - exp(-smooth_speed * delta))
	else:
		global_position = target_pos
