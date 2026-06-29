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
		push_warning("Camera has no target assigned; keeping scene transform.")
		return

	_update_camera_pos(0.0)
	_align_rotation()

func _process(delta: float) -> void:
	if target == null:
		return
	_update_camera_pos(delta)
	_align_rotation()

func _align_rotation() -> void:
	var rad: float = deg_to_rad(angle)
	var forward: Vector3 = Vector3(sin(rad), 0, cos(rad))
	# Aponta a câmera sempre na direção de profundidade fixa (perpendicular ao plano)
	look_at(global_position - forward, Vector3.UP)

func _update_camera_pos(delta: float) -> void:
	var rad: float = deg_to_rad(angle)
	var forward: Vector3 = Vector3(sin(rad), 0, cos(rad))
	var right: Vector3 = Vector3(forward.z, 0, -forward.x)

	# Strip the target's depth component entirely so the camera
	# never shifts along the viewing axis when Cubic snaps to a
	# different Z-lane.
	var target_world: Vector3 = target.global_position
	var depth_component: float = forward.dot(target_world)
	var flat_target: Vector3 = target_world - forward * depth_component

	var target_pos: Vector3 = flat_target + Vector3.UP * height
	target_pos += forward * radius

	if delta > 0 and smooth_speed > 0:
		# Lerp only the non-depth axes; depth is always exactly radius.
		var t: float = 1.0 - exp(-smooth_speed * delta)
		var new_pos: Vector3 = global_position.lerp(target_pos, t)
		# Force the depth axis to the exact target value (no lerp drift).
		var depth_amount: float = forward.dot(new_pos)
		var target_depth: float = forward.dot(target_pos)
		new_pos += forward * (target_depth - depth_amount)
		global_position = new_pos
	else:
		global_position = target_pos
