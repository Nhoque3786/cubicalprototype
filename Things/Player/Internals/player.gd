# Cubic (player)'s internals.
# Adapted for the new Hyprcore system.
extends CharacterBody3D
class_name Player

enum State { IDLE, MOVING, AIR, ROTATING, CLIMBING, GRABBING, DEAD }

@warning_ignore("unused_signal")
signal died
@warning_ignore("unused_signal")
signal respawned

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
@export var jump_buffer_time: float = 0.12

@export_group("Visuals")
@export var animated_sprite: AnimatedSprite3D

@export_group("Death & Respawn")
@export var death_y_threshold: float = -10.0
@export var death_freeze_duration: float = 0.6
@export var safe_ground_time: float = 0.3

var current_state: State = State.IDLE

# Components
var movement: PlayerMovement
var rip: PlayerRIP
var animator: PlayerAnimator
var ghost: PlayerGhost
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

	# If no movement component exists, try to find it or create it
	movement = find_child("PlayerMovement", true, false) as PlayerMovement
	if movement == null:
		movement = PlayerMovement.new()
		movement.name = "PlayerMovement"
		add_child(movement)

	# If no RIP component exists, try to find it or create it
	rip = find_child("PlayerRIP", true, false) as PlayerRIP
	if rip == null:
		rip = PlayerRIP.new()
		rip.name = "PlayerRIP"
		add_child(rip)

	# If no Ghost component exists, try to find it or create it
	ghost = find_child("PlayerGhost", true, false) as PlayerGhost
	if ghost == null:
		ghost = PlayerGhost.new()
		ghost.name = "PlayerGhost"
		add_child(ghost)

	# Keep the collision box world-aligned: depth (thin axis) always faces the
	# camera, regardless of how the level is rotated underneath us.
	_align_to_world()

func _physics_process(delta: float) -> void:
	if rip.is_dead():
		return

	if rip.check_death():
		return

	var h_dir: Vector3 = movement.get_screen_horizontal_dir()
	_update_state(h_dir)
	var was_on_floor: bool = is_on_floor()

	movement.update_coyote_time(delta)
	movement.update_jump_buffer(delta)

	var input_h: float = Input.get_axis(&"move_left", &"move_right")
	var did_jump: bool = false

	match current_state:
		State.ROTATING:
			movement.apply_friction(h_dir, delta)
		State.CLIMBING:
			# TODO: Implement climbing logic (after i actually make the climbing sprite/climbables)
			pass
		_: # Ground states (IDLE, MOVING) and AIR
			movement.handle_horizontal_movement(h_dir, input_h, delta)
			movement.apply_gravity(delta)
			did_jump = movement.process_jump(delta)

	move_and_slide()
	var is_on_floor_now: bool = is_on_floor()
	var just_landed: bool = not was_on_floor and is_on_floor_now

	if not is_on_floor_now:
		max_fall_speed = max(max_fall_speed, abs(min(velocity.y, 0.0)))

	rip.update_safe_position(is_on_floor_now, delta)

	var is_moving: bool = velocity.length_squared() > 0.01
	if hyprcore and not hyprcore.is_rotating:
		if is_moving or just_landed or did_jump:
			hyprcore.snap_to_grid(self)

	if animator:
		animator.reference_walk_speed = speed
		var h_vel: float = velocity.dot(h_dir)
		animator.update_animation(h_vel, velocity.y, is_on_floor_now, input_h, did_jump, just_landed, max_fall_speed, delta)

	if just_landed:
		max_fall_speed = 0.0

func _update_state(h_dir: Vector3) -> void:
	if current_state == State.DEAD:
		return

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

func _on_rotation_finished() -> void:
	# The level (our parent) just spun; cancel the inherited rotation so the
	# thin side of the collision box keeps facing the camera.
	_align_to_world()
	if hyprcore:
		hyprcore.snap_to_grid(self, true)

# Force the body upright/world-aligned. Position still follows the level (so Cubic
# arcs along with the spin), but the collider never rotates into the depth axis.
func _align_to_world() -> void:
	global_rotation = Vector3.ZERO
