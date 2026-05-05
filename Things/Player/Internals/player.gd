# Cubic (player)'s internals.
# Adapted for the new Hyprcore system.
extends CharacterBody3D

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

@export_group("Visuals")
@export var animated_sprite: AnimatedSprite3D

var current_state: State = State.IDLE

# Components (Will need PlayerAnimator.gd in the same folder)
var animator: Node # Using Node for now as PlayerAnimator might not be defined yet
var jump_timer: float = 0.0
var is_preparing_jump: bool = false

func _ready() -> void:
	if hyprcore == null:
		hyprcore = _find_hyprcore(get_tree().root)
	
	if hyprcore:
		hyprcore.rotation_finished.connect(_on_rotation_finished)

	if not animated_sprite:
		for child in get_children():
			if child is AnimatedSprite3D:
				animated_sprite = child
				break
	if animated_sprite:
		var animator_script = load("res://Things/Player/Internals/PlayerAnimator.gd")
		if animator_script:
			animator = animator_script.new()
			animator.set("animated_sprite", animated_sprite)
			add_child(animator)
		else:
			push_warning("Player: PlayerAnimator.gd not found in Internals. Visuals might not work.")

func _physics_process(delta: float) -> void:
	_update_state()

	var input_h := Input.get_axis(&"move_left", &"move_right")
	var did_jump := false

	match current_state:
		State.ROTATING:
			_apply_friction(delta)
		State.AIR:
			_handle_horizontal_movement(input_h, delta)
			_apply_gravity(delta)
		State.CLIMBING:
			# TODO: Implement climbing logic
			pass
		_: # Ground states (IDLE, MOVING)
			_handle_horizontal_movement(input_h, delta)
			_apply_gravity(delta)
			
			if is_preparing_jump:
				jump_timer -= delta
				if jump_timer <= 0:
					_handle_jump()
					is_preparing_jump = false
			elif Input.is_action_just_pressed(&"jump"):
				_start_jump_preparation()
				did_jump = true

	move_and_slide()
	
	if hyprcore and not hyprcore.is_rotating:
		hyprcore.snap_to_grid(self)
	
	if animator and animator.has_method("update_animation"):
		animator.call("update_animation", velocity, is_on_floor(), input_h, did_jump, delta)

func _update_state() -> void:
	if hyprcore and hyprcore.is_rotating:
		current_state = State.ROTATING
		return
		
	if not is_on_floor():
		current_state = State.AIR
	elif abs(velocity.x) > 0.1:
		current_state = State.MOVING
	else:
		current_state = State.IDLE

func _find_hyprcore(parent: Node) -> Hyprcore:
	if parent is Hyprcore:
		return parent

	for child in parent.get_children():
		var found := _find_hyprcore(child)
		if found != null:
			return found

	return null

func _handle_horizontal_movement(input_h: float, delta: float) -> void:
	var move_dir := _get_screen_horizontal_dir()
	
	# Get current horizontal velocity by projecting global velocity onto move_dir
	var current_h_vel := velocity.dot(move_dir)
	
	if input_h != 0:
		current_h_vel = move_toward(current_h_vel, input_h * speed, acceleration * delta)
	else:
		current_h_vel = move_toward(current_h_vel, 0.0, friction * delta)
	
	# Reconstruct velocity: (horizontal * dir) + (vertical * UP)
	# This automatically zeroes out "depth" velocity relative to the current plane
	velocity = (move_dir * current_h_vel) + (Vector3.UP * velocity.y)

func _apply_friction(delta: float) -> void:
	var move_dir := _get_screen_horizontal_dir()
	var current_h_vel := velocity.dot(move_dir)
	
	current_h_vel = move_toward(current_h_vel, 0.0, friction * delta)
	velocity = (move_dir * current_h_vel) + (Vector3.UP * velocity.y)

func _get_screen_horizontal_dir() -> Vector3:
	var cam := get_viewport().get_camera_3d()
	if not cam: return Vector3.RIGHT
	
	# What direction is "Right" on the screen in global space?
	var screen_right := cam.global_transform.basis.x
	screen_right.y = 0
	screen_right = screen_right.normalized()
	
	# Since we are a child of Level, we want to move along whichever 
	# of the Level's local axes (X or Z) currently looks "Right" on screen.
	var local_x := global_transform.basis.x
	var local_z := global_transform.basis.z
	
	# Pick the axis that aligns best with screen_right
	if abs(local_x.dot(screen_right)) > abs(local_z.dot(screen_right)):
		return local_x * sign(local_x.dot(screen_right))
	else:
		return local_z * sign(local_z.dot(screen_right))

func _apply_gravity(delta: float) -> void:
	velocity.y -= gravity * delta

func _handle_jump() -> void:
	velocity.y = jump_power

func _start_jump_preparation() -> void:
	is_preparing_jump = true
	jump_timer = jump_delay

func _on_rotation_finished() -> void:
	if hyprcore:
		hyprcore.snap_to_grid(self)
