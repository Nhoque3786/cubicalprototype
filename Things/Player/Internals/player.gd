# Cubic (player)'s internals.
# Adapted for the new Hyprcore system.
extends CharacterBody3D
class_name Player

enum State { IDLE, MOVING, AIR, ROTATING, CLIMBING, GRABBING }

@export_group("References")
@export var hyprcore: Hyprcore

@export_group("Movement")
@export var speed: float = 6.0
@export var acceleration: float = 60.0
@export var friction: float = 50.0
@export var jump_power: float = 8.0
@export var gravity: float = 24.0
@export var jump_delay: float = 0.03
@export var coyote_time: float = 0.15

@export_group("Visuals")
@export var animated_sprite: AnimatedSprite3D

var current_state: State = State.IDLE

# Components
var animator: PlayerAnimator
var jump_timer: float = 0.0
var is_preparing_jump: bool = false
var coyote_timer: float = 0.0
var max_fall_speed: float = 0.0

func _ready() -> void:
	add_to_group(&"player")

	if hyprcore == null:
		hyprcore = get_tree().get_first_node_in_group(&"hyprcore") as Hyprcore

	if hyprcore:
		hyprcore.rotation_finished.connect(_on_rotation_finished)

	if not animated_sprite:
		animated_sprite = find_child("AnimatedSprite3D", true, false) as AnimatedSprite3D

	# If no animator exists, try to find it or create it
	animator = find_child("PlayerAnimator", true, false) as PlayerAnimator
	if animator == null and animated_sprite != null:
		animator = PlayerAnimator.new()
		animator.name = "PlayerAnimator"
		animator.animated_sprite = animated_sprite
		add_child(animator)

func _physics_process(delta: float) -> void:
	var h_dir: Vector3 = _get_screen_horizontal_dir()
	_update_state(h_dir)
	var was_on_floor: bool = is_on_floor()

	if is_on_floor():
		coyote_timer = coyote_time
	else:
		coyote_timer -= delta

	var input_h: float = Input.get_axis(&"move_left", &"move_right")
	var did_jump: bool = false

	match current_state:
		State.ROTATING:
			_apply_friction(h_dir, delta)
		State.AIR:
			_handle_horizontal_movement(h_dir, input_h, delta)
			_apply_gravity(delta)

			if is_preparing_jump:
				_process_jump_timer(delta)
			elif Input.is_action_just_pressed(&"jump") and coyote_timer > 0.0:
				_start_jump_preparation()
				coyote_timer = 0.0
				did_jump = true
		State.CLIMBING:
			# TODO: Implement climbing logic (after i actually make the climbing sprite/climbables)
			pass
		_: # Ground states (IDLE, MOVING)
			_handle_horizontal_movement(h_dir, input_h, delta)
			_apply_gravity(delta)

			if is_preparing_jump:
				_process_jump_timer(delta)
			elif Input.is_action_just_pressed(&"jump"):
				_start_jump_preparation()
				coyote_timer = 0.0
				did_jump = true

	move_and_slide()
	var is_on_floor_now: bool = is_on_floor()
	var just_landed: bool = not was_on_floor and is_on_floor_now

	if not is_on_floor_now:
		max_fall_speed = max(max_fall_speed, abs(min(velocity.y, 0.0)))

	# Optimization: Only snap if we are moving or if we just landed.
	var is_moving: bool = velocity.length_squared() > 0.01
	if hyprcore and not hyprcore.is_rotating:
		if is_moving or is_on_floor_now or did_jump:
			hyprcore.snap_to_grid(self)

	if animator:
		var h_vel: float = velocity.dot(h_dir)
		animator.update_animation(h_vel, velocity.y, is_on_floor_now, input_h, did_jump, just_landed, max_fall_speed, delta)

	if just_landed:
		max_fall_speed = 0.0

func _update_state(h_dir: Vector3) -> void:
	if hyprcore and hyprcore.is_rotating:
		current_state = State.ROTATING
		return

	if not is_on_floor():
		current_state = State.AIR
	else:
		var h_speed: float = abs(velocity.dot(h_dir))
		if h_speed > 0.1:
			current_state = State.MOVING
		else:
			current_state = State.IDLE

func _handle_horizontal_movement(move_dir: Vector3, input_h: float, delta: float) -> void:
	var current_h_vel: float = velocity.dot(move_dir)

	if input_h != 0:
		current_h_vel = move_toward(current_h_vel, input_h * speed, acceleration * delta)
	else:
		current_h_vel = move_toward(current_h_vel, 0.0, friction * delta)

	velocity = (move_dir * current_h_vel) + (Vector3.UP * velocity.y)

func _apply_friction(move_dir: Vector3, delta: float) -> void:
	var current_h_vel: float = velocity.dot(move_dir)

	current_h_vel = move_toward(current_h_vel, 0.0, friction * delta)
	velocity = (move_dir * current_h_vel) + (Vector3.UP * velocity.y)
func _get_screen_horizontal_dir() -> Vector3:
	var cam: Camera3D = get_viewport().get_camera_3d()
	if not cam: return Vector3.RIGHT

	var screen_right: Vector3 = cam.global_transform.basis.x
	screen_right.y = 0
	screen_right = screen_right.normalized()

	var local_x: Vector3 = global_transform.basis.x
	var local_z: Vector3 = global_transform.basis.z

	if abs(local_x.dot(screen_right)) > abs(local_z.dot(screen_right)):
		return local_x * sign(local_x.dot(screen_right))
	else:
		return local_z * sign(local_z.dot(screen_right))

func _apply_gravity(delta: float) -> void:
	velocity.y -= gravity * delta

func _process_jump_timer(delta: float) -> void:
	jump_timer -= delta
	if jump_timer <= 0:
		_handle_jump()
		is_preparing_jump = false

func _handle_jump() -> void:
	velocity.y = jump_power

func _start_jump_preparation() -> void:
	is_preparing_jump = true
	jump_timer = jump_delay

func _on_rotation_finished() -> void:
	if hyprcore:
		hyprcore.snap_to_grid(self)
