# PlayerAnimator.gd - Handles visuals and animation states for Cubic.
extends Node
class_name PlayerAnimator

@export var animated_sprite: AnimatedSprite3D

# Animation speed multipliers
@export var walk_speed_mult: float = 1.5
@export var jump_anim_speed: float = 1.2
@export var soft_land_speed: float = 7.0
@export var hard_land_speed: float = 14.0
@export var stretch_velocity_threshold: float = 5.0

func update_animation(
	h_vel: float,
	v_vel: float,
	is_on_floor: bool,
	input_h: float,
	did_jump: bool,
	just_landed: bool,
	fall_speed: float,
	_delta: float
) -> void:
	if not animated_sprite: return

	# 1. High Priority: Jump Start (Squish phase)
	if did_jump:
		animated_sprite.speed_scale = jump_anim_speed
		animated_sprite.play(&"squish")
		return

	if just_landed:
		animated_sprite.speed_scale = 1.0
		if fall_speed >= hard_land_speed:
			animated_sprite.play(&"squish_hard")
			return
		elif fall_speed >= soft_land_speed:
			animated_sprite.play(&"squish")
			return

	# Prevent interrupting transition animations while on floor
	if is_on_floor and animated_sprite.animation in [&"squish", &"squish_hard", &"turn"] and animated_sprite.is_playing():
		return

	# 2. Direction and Turning (Flip H)
	if input_h != 0:
		var target_flip: bool = input_h < 0
		if animated_sprite.flip_h != target_flip:
			animated_sprite.flip_h = target_flip
			if is_on_floor:
				animated_sprite.play(&"turn")
				return

	# 3. Air States (Jumping / Falling / Stretching)
	if not is_on_floor:
		animated_sprite.speed_scale = 1.0

		# Use stretch animation only for fast falling
		# The user mentioned jump animation reuses squish, so we fallback to that if stretch is missing.
		if v_vel < -stretch_velocity_threshold:
			if animated_sprite.sprite_frames.has_animation(&"stretch"):
				animated_sprite.play(&"stretch")
			elif animated_sprite.sprite_frames.has_animation(&"squish"):
				animated_sprite.play(&"squish")
		else:
			# Near the apex of the jump or slow movement
			if animated_sprite.sprite_frames.has_animation(&"fall"):
				animated_sprite.play(&"fall")
			else:
				animated_sprite.play(&"default")
		return

	# 4. Ground States (Walk / Idle)
	# Use the provided h_vel for consistent speed calculation regardless of world rotation
	var horizontal_speed: float = abs(h_vel)

	if horizontal_speed > 0.1:
		animated_sprite.play(&"walk")
		# Adjust animation speed based on actual movement speed (default speed 6.0)
		animated_sprite.speed_scale = (horizontal_speed / 6.0) * walk_speed_mult
	else:
		animated_sprite.play(&"default")
		animated_sprite.speed_scale = 1.0
