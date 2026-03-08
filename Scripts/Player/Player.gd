# Cubic (player)'s internals.
# IMPORTANT: For things like Climbing, hyperjumps, "world rotation", grabbables and etc, please make refatoration.
extends CharacterBody3D

# Player parameters
enum State { IDLE, MOVING, AIR, ROTATING, CLIMBING, GRABBING }

# Player parameters
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

# Components
var animator: PlayerAnimator
var jump_timer: float = 0.0
var is_preparing_jump: bool = false

func _ready() -> void:
	if not animated_sprite:
		for child in get_children():
			if child is AnimatedSprite3D:
				animated_sprite = child
				break

	if animated_sprite:
		animator = PlayerAnimator.new()
		animator.animated_sprite = animated_sprite
		add_child(animator)
	else:
		push_error("OOPS, Player.gd didint found any AnimatedSprite3D to initialize the Animator.")

func _physics_process(delta: float) -> void:
	# 1. Update References & State
	var hyprcube: Node = Game.hyprcube
	var ground: Node = Game.hyprground
	
	_update_state(hyprcube)

	# 2. Handle Movement Logic
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
			_apply_gravity(delta) # Mantain a little bit of force still
			
			if is_preparing_jump:
				jump_timer -= delta
				if jump_timer <= 0:
					_handle_jump()
					# we don't set did_jump here because the visual "squish" 
					# already started at the beginning of preparation
					is_preparing_jump = false
			elif Input.is_action_just_pressed(&"jump"):
				_start_jump_preparation()
				did_jump = true
				# TODO: add coyote time, for less anxiety inducing jumps

	# 3. Physics Execution
	move_and_slide()
	
	# 4. Post-movement adjustments
	if ground:
		(ground as Hyprground).snap(self, (ground as Hyprground).max_distance)

	# 5. Visuals
	if animator:
		animator.update_animation(velocity, is_on_floor(), input_h, did_jump, delta)

func _update_state(hyprcube: Node) -> void:
	if hyprcube and (hyprcube as Hyprcube).is_world_rotating():
		current_state = State.ROTATING
		return
		
	if not is_on_floor():
		current_state = State.AIR
	elif velocity.x != 0:
		current_state = State.MOVING
	else:
		current_state = State.IDLE

func _handle_horizontal_movement(input_h: float, delta: float) -> void:
	if input_h != 0:
		velocity.x = move_toward(velocity.x, input_h * speed, acceleration * delta)
	else:
		_apply_friction(delta)
	
	# makes sure we don't start drifting into the Z axis suddenly.
	velocity.z = 0.0

func _apply_friction(delta: float) -> void:
	velocity.x = move_toward(velocity.x, 0.0, friction * delta)
	velocity.z = 0.0

func _apply_gravity(delta: float) -> void:
	velocity.y -= gravity * delta

func _handle_jump() -> void:
	velocity.y = jump_power

func _start_jump_preparation() -> void:
	is_preparing_jump = true
	jump_timer = jump_delay
