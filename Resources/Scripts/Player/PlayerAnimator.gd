extends Node
class_name PlayerAnimator

# References
@export var animated_sprite: AnimatedSprite3D

# Animation speed controls
@export var anim_default_speed: float = 1.0
@export var anim_walk_speed: float = 1.0
@export var anim_jump_speed: float = 0.6

func update_animation(velocity: Vector3, is_on_floor: bool, input_h: float, did_jump: bool) -> void:
	# Update direction (Flip H)
	if input_h != 0:
		animated_sprite.flip_h = input_h < 0

	# 1. In the air: overrides all other animations for a default pose.
	if not is_on_floor:
		animated_sprite.play("default") # Play the 'default' anim
		animated_sprite.stop()          # and stop it immediately to show the default frame.
		# TODO: Add squash & stretch logic for falling
		return

	# 2. On Floor: Let the one-shot jump animation finish if it's playing.
	if animated_sprite.animation == "jump" and animated_sprite.is_playing():
		return

	# 3. On Floor: Check for new jump input.
	if did_jump:
		# Slow down the jump animation specifically
		animated_sprite.speed_scale = anim_jump_speed
		animated_sprite.play("jump")
		# TODO: Add squash & stretch logic for jumping
		return

	# 4. On Floor: If not jumping, run the default walk/idle logic.
	# We check the length of the horizontal velocity vector to detect movement.
	if abs(velocity.x) > 0.1:
		animated_sprite.speed_scale = anim_walk_speed
		animated_sprite.play("walk")
	else:
		animated_sprite.speed_scale = anim_default_speed
		animated_sprite.play("default")