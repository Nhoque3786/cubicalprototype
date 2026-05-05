# PlayerAnimator.gd - Handles visuals and animation states for Cubic.
extends Node
class_name PlayerAnimator

@export var animated_sprite: AnimatedSprite3D

# Animation speed multipliers
@export var walk_speed_mult: float = 1.5
@export var jump_anim_speed: float = 1.2

func update_animation(velocity: Vector3, is_on_floor: bool, input_h: float, did_jump: bool, _delta: float) -> void:
	if not animated_sprite: return

	# 1. High Priority: Jump Start (Squish phase)
	if did_jump:
		animated_sprite.play(&"squish")
		return

	# Prevent interrupting transition animations while on floor
	if is_on_floor and (animated_sprite.animation == &"squish" or animated_sprite.animation == &"turn") and animated_sprite.is_playing():
		return

	# 2. Direction and Turning (Flip H)
	if input_h != 0:
		var target_flip: bool = input_h < 0
		if animated_sprite.flip_h != target_flip:
			animated_sprite.flip_h = target_flip
			if is_on_floor:
				animated_sprite.play(&"turn")
				return

	# 3. Air States (Jumping / Falling)
	if not is_on_floor:
		if velocity.y > 0:
			# Play jump upward animation if available
			if animated_sprite.sprite_frames.has_animation(&"jump"):
				animated_sprite.play(&"jump")
			else:
				animated_sprite.play(&"default")
		else:
			# Play falling animation if available
			if animated_sprite.sprite_frames.has_animation(&"fall"):
				animated_sprite.play(&"fall")
			else:
				animated_sprite.play(&"default")
		
		# Ensure animation is playing and speed is normal
		animated_sprite.speed_scale = 1.0
		return

	# 4. Ground States (Walk / Idle)
	# Check magnitude of horizontal velocity (compatible with Hyprcore rotation)
	var horizontal_speed: float = Vector2(velocity.x, velocity.z).length()

	if horizontal_speed > 0.1:
		animated_sprite.play(&"walk")
		# Adjust animation speed based on actual movement speed
		animated_sprite.speed_scale = (horizontal_speed / 6.0) * walk_speed_mult
	else:
		animated_sprite.play(&"default")
		animated_sprite.speed_scale = 1.0
