extends Node3D

@export_group("Tracking")
@export var target: Node3D = null
@export var height: float = 0.0
@export var smooth_speed: float = 8.0
@export var lock_depth: bool = true

@export_group("Panning")
@export var pan_speed: float = 16.0
@export var pan_limit: float = 4.0
@export var pan_return_speed: float = 4.0

@export_group("Setup")
@export var angle: float = 0.0
@export var radius: float = 8.0
@export var orthographic_size: float = 6.0

@onready var spring_arm: SpringArm3D = $SpringArm3D
@onready var actual_camera: Camera3D = $SpringArm3D/ActualCamera
var pan_offset: Vector3 = Vector3.ZERO
var locked_depth: float = 0.0

func _ready() -> void:
	process_mode = PROCESS_MODE_ALWAYS
	spring_arm.spring_length = radius
	spring_arm.collision_mask = 0
	actual_camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	actual_camera.size = orthographic_size

	# Set the rig's rotation ONCE at the start. It will not change again.
	self.rotation.y = deg_to_rad(angle)

	if target == null:
		push_warning("Camera rig has no target assigned.")
		return

	locked_depth = _get_depth_axis().dot(target.global_position)

	# Set initial position
	_update_rig_pos(0.0)

func _process(delta: float) -> void:
	if target == null:
		return
	_handle_panning(delta)

	if Input.is_action_just_pressed("cam_focus"):
		pan_offset = Vector3.ZERO

	_update_rig_pos(delta)

func _handle_panning(delta: float) -> void:
	# Get input from actions defined in Project > Project Settings > Input Map
	var pan_input := Input.get_vector("cam_left", "cam_right", "cam_up", "cam_down")

	# Update the pan_offset based on input
	# We use the camera's own basis vectors to ensure "right" is always screen-right.
	var screen_right := global_transform.basis.x
	var screen_up := Vector3.UP
	pan_offset += screen_right * pan_input.x * pan_speed * delta
	pan_offset += screen_up * -pan_input.y * pan_speed * delta

	if lock_depth:
		var depth_axis := _get_depth_axis()
		pan_offset -= depth_axis * depth_axis.dot(pan_offset)

	# Clamp the offset to a maximum distance from the player
	pan_offset = pan_offset.limit_length(pan_limit)

	# If cubic moves, return the focus to him
	if Input.is_action_just_pressed(&"move_left") or Input.is_action_just_pressed(&"move_right") or Input.is_action_just_pressed(&"jump"):
		pan_offset = Vector3.ZERO

func _update_rig_pos(delta: float) -> void:
	var target_world: Vector3 = target.global_position

	if lock_depth:
		var depth_axis := _get_depth_axis()
		target_world += depth_axis * (locked_depth - depth_axis.dot(target_world))

	# The target position for our rig is the flattened player position,
	# PLUS our new panning offset.
	var target_pos: Vector3 = target_world + Vector3.UP * height + pan_offset

	# Smoothly move the entire rig towards the target position.
	if delta > 0 and smooth_speed > 0:
		var t: float = 1.0 - exp(-smooth_speed * delta)
		global_position = global_position.lerp(target_pos, t)
	else:
		global_position = target_pos

func _get_depth_axis() -> Vector3:
	var depth_axis := global_transform.basis.z
	depth_axis.y = 0.0

	if depth_axis.is_zero_approx():
		return Vector3.BACK

	return depth_axis.normalized()


