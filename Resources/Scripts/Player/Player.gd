# Cubic (player)'s internals.
# IMPORTANT: For things like Climbing, hyperjumps, "world rotation", grabbables and etc, please make refatoration.
extends CharacterBody3D

# Player parameters
@export var speed: float = 6.0
@export var jump_power: float = 8.0
@export var gravity: float = 24.0
@export var climbing: bool = false
@export var grabbing: bool = false

# Animation
@onready var animated_sprite: AnimatedSprite3D = $Sprite

# Node references
@onready var hyprcube: Node = get_node_or_null("../Hyprcube")

# Animation speed controls
@export var anim_default_speed: float = 1.0
@export var anim_walk_speed: float = 1.0
@export var anim_jump_speed: float = 0.6

func _physics_process(delta: float) -> void:
	var input_h := Input.get_action_strength("move_right") - Input.get_action_strength("move_left")

	# If the world is rotating, freeze all horizontal movement.
	if hyprcube and hyprcube.is_world_rotating():
		input_h = 0
		velocity.x = 0
		velocity.z = 0

	# Handle jump
	if is_on_floor():
		# Reset the vertical component when touching the floor
		if Input.is_action_just_pressed("jump"):
			velocity.y = jump_power
		else:
			# Ensure a small negative vertical velocity doesn't accumulate on landing
			velocity.y = 0.0
	else:
		# Apply gravity while in the air (Note: make gravity custom to every level later)
		velocity.y -= gravity * delta

	# Get the current movement direction from Hyprcube and apply horizontal movement
	if hyprcube:
		var horizontal_direction: Vector3 = hyprcube.get_horizontal_direction()
		var target_velocity: Vector3 = horizontal_direction * input_h * speed
		velocity.x = target_velocity.x
		velocity.z = target_velocity.z
	else:
		# Fallback to old behavior if hyprcube is not found
		velocity.x = input_h * speed
		velocity.z = 0

	# Update animations and sprite direction
	update_animation()
	update_direction(input_h)

	# Apply movement with collision detection
	move_and_slide()

func update_animation() -> void:
	# Handles which animation to play. The order of checks is important.

	# 1. In the air: overrides all other animations for a default pose.
	if not is_on_floor():
		animated_sprite.play("default") # Play the 'default' anim
		animated_sprite.stop()          # and stop it immediately to show the default frame.
		return

	# 2. On Floor: Let the one-shot jump animation finish if it's playing.
	if animated_sprite.animation == "jump" and animated_sprite.is_playing():
		return

	# 3. On Floor: Check for new jump input.
	if Input.is_action_just_pressed("jump"):
		# Slow down the jump animation specifically
		animated_sprite.speed_scale = anim_jump_speed
		animated_sprite.play("jump")
		return

	# 4. On Floor: If not jumping, run the default walk/idle logic.
	# We check the length of the horizontal velocity vector to detect movement.
	var horizontal_velocity = Vector2(velocity.x, velocity.z)
	if horizontal_velocity.length() > 0.1:
		animated_sprite.speed_scale = anim_walk_speed
		animated_sprite.play("walk")
	else:
		animated_sprite.speed_scale = anim_default_speed
		animated_sprite.play("default")

func update_direction(input_h: float) -> void:
	# Flips the sprite based on horizontal input
	if input_h != 0:
		animated_sprite.flip_h = input_h < 0 
