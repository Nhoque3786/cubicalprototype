# PlayerMovement.gd - Handles horizontal movement, friction, gravity, and jumping/coyote-time for Cubic.
extends Node
class_name PlayerMovement

var player: Player

# Internal variables for jumping/movement
var coyote_timer: float = 0.0
var jump_timer: float = 0.0
var is_preparing_jump: bool = false

func _ready() -> void:
	player = get_parent() as Player

func get_screen_horizontal_dir() -> Vector3:
	var cam: Camera3D = player.get_viewport().get_camera_3d()
	if not cam: return Vector3.RIGHT

	var screen_right: Vector3 = cam.global_transform.basis.x
	screen_right.y = 0
	screen_right = screen_right.normalized()

	var local_x: Vector3 = player.global_transform.basis.x
	var local_z: Vector3 = player.global_transform.basis.z

	if abs(local_x.dot(screen_right)) > abs(local_z.dot(screen_right)):
		return local_x * sign(local_x.dot(screen_right))
	else:
		return local_z * sign(local_z.dot(screen_right))

func update_coyote_time(delta: float) -> void:
	if player.is_on_floor():
		coyote_timer = player.coyote_time
	else:
		coyote_timer -= delta

func handle_horizontal_movement(move_dir: Vector3, input_h: float, delta: float) -> void:
	var current_h_vel: float = player.velocity.dot(move_dir)

	if input_h != 0:
		current_h_vel = move_toward(current_h_vel, input_h * player.speed, player.acceleration * delta)
	else:
		current_h_vel = move_toward(current_h_vel, 0.0, player.friction * delta)

	player.velocity = (move_dir * current_h_vel) + (Vector3.UP * player.velocity.y)

func apply_friction(move_dir: Vector3, delta: float) -> void:
	var current_h_vel: float = player.velocity.dot(move_dir)

	current_h_vel = move_toward(current_h_vel, 0.0, player.friction * delta)
	player.velocity = (move_dir * current_h_vel) + (Vector3.UP * player.velocity.y)

func apply_gravity(delta: float) -> void:
	player.velocity.y -= player.gravity * delta

func process_jump(delta: float) -> bool:
	var did_jump: bool = false
	if is_preparing_jump:
		jump_timer -= delta
		if jump_timer <= 0:
			player.velocity.y = player.jump_power
			is_preparing_jump = false
			did_jump = true  # Fire the flag when velocity actually launches
	elif Input.is_action_just_pressed(&"jump") and coyote_timer > 0.0:
		if player.jump_delay <= 0.0:
			# No delay: launch immediately
			player.velocity.y = player.jump_power
			coyote_timer = 0.0
			did_jump = true
		else:
			is_preparing_jump = true
			jump_timer = player.jump_delay
			coyote_timer = 0.0
	return did_jump
