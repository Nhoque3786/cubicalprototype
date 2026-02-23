extends Node
class_name PlayerAnimator

# References
@export var animated_sprite: AnimatedSprite3D

# Animation speed controls
@export var anim_default_speed: float = 1.0
@export var anim_walk_speed: float = 1.0
@export var anim_squish_speed: float = 0.8
@export var anim_stretch_speed: float = 0.5

func _ready() -> void:
	animated_sprite.animation_finished.connect(_on_animation_finished)

func _on_animation_finished() -> void:
	if animated_sprite.animation == "squish":
		# Stretch is not good yet for jumping, probably i will only use stretch for falling. TODO: make this more natural
		# animated_sprite.speed_scale = anim_stretch_speed
		# animated_sprite.play("stretch")
		pass


func update_animation(velocity: Vector3, is_on_floor: bool, input_h: float, did_jump: bool, _delta: float) -> void:
	# Jump 
	if did_jump:
		animated_sprite.speed_scale = anim_squish_speed
		animated_sprite.play("squish")
		return

	# If we are in the middle of a jump animation (squish/stretch), let it finish
	# Removido "stretch" da verificação abaixo para liberar a troca de animação mais cedo
	if (animated_sprite.animation == "squish") and animated_sprite.is_playing():
		return

	# Update direction (Flip H)
	if input_h != 0:
		var new_flip_h = input_h < 0
		if animated_sprite.flip_h != new_flip_h:
			animated_sprite.flip_h = new_flip_h
			# Only play turn animation if we are on floor
			if is_on_floor:
				animated_sprite.play("turn")
	if animated_sprite.animation == "turn" and animated_sprite.is_playing():
		return

	# falling
	# NOTE: This is just for testing purposes. In Later versions, i'm using the stretch anim for falling.
	# TODO: add the stretch anim for falling
	if not is_on_floor:
		animated_sprite.play("default") # Play the 'default' anim
		animated_sprite.stop()          # and stop it immediately to show the default frame.
		# TODO: Add squash & stretch logic for falling (The implementation for default pose only is just for testing.)
		return

	# Walk & Idle
	if abs(velocity.x) > 0.1:
		animated_sprite.speed_scale = anim_walk_speed
		animated_sprite.play("walk")
	else:
		animated_sprite.speed_scale = anim_default_speed
		animated_sprite.play("default")
