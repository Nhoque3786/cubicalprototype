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
@export var reference_walk_speed: float = 6.0

# Blink system
@export var blink_interval_min: float = 2.0
@export var blink_interval_max: float = 6.0
var _blink_timer: float = 4.0
var _is_blinking: bool = false
const _BLINK_DURATION: float = 0.6

var _cache_initialized: bool = false
var _has_stretch_anim: bool = false
var _has_squish_anim: bool = false
var _has_fall_anim: bool = false
var _has_walk_blink_anim: bool = false
var _has_default_blink_anim: bool = false

func _ready() -> void:
	_cache_animations()

func _cache_animations() -> void:
	if animated_sprite and animated_sprite.sprite_frames:
		_has_stretch_anim = animated_sprite.sprite_frames.has_animation(&"stretch")
		_has_squish_anim = animated_sprite.sprite_frames.has_animation(&"squish")
		_has_fall_anim = animated_sprite.sprite_frames.has_animation(&"fall")
		_has_walk_blink_anim = animated_sprite.sprite_frames.has_animation(&"walk_blink")
		_has_default_blink_anim = animated_sprite.sprite_frames.has_animation(&"default_blink")
		_cache_initialized = true

func update_animation(
	h_vel: float,
	v_vel: float,
	is_on_floor: bool,
	input_h: float,
	did_jump: bool,
	just_landed: bool,
	fall_speed: float,
	delta: float
) -> void:
	if not animated_sprite or not animated_sprite.sprite_frames: return

	if not _cache_initialized:
		_cache_animations()

	_update_blink_timer(delta)

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
		if v_vel < -stretch_velocity_threshold:
			if _has_stretch_anim:
				animated_sprite.play(&"stretch")
			elif _has_squish_anim:
				animated_sprite.play(&"squish")
		else:
			# Near the apex of the jump or slow movement
			if _has_fall_anim:
				animated_sprite.play(&"fall")
			else:
				animated_sprite.play(&"default")
		return

	# 4. Ground States (Walk / Idle)
	# Use the provided h_vel for consistent speed calculation regardless of world rotation
	var horizontal_speed: float = abs(h_vel)

	if horizontal_speed > 0.1:
		animated_sprite.play(_get_blink_variant(&"walk", &"walk_blink"))
		animated_sprite.speed_scale = (horizontal_speed / max(reference_walk_speed, 0.001)) * walk_speed_mult
	else:
		animated_sprite.play(_get_blink_variant(&"default", &"default_blink"))
		animated_sprite.speed_scale = 1.0

func _update_blink_timer(delta: float) -> void:
	_blink_timer -= delta
	if _blink_timer <= 0.0:
		_is_blinking = not _is_blinking
		if _is_blinking:
			_blink_timer = _BLINK_DURATION
		else:
			_blink_timer = randf_range(blink_interval_min, blink_interval_max)

func _get_blink_variant(base_anim: StringName, blink_anim: StringName) -> StringName:
	if _is_blinking:
		if blink_anim == &"walk_blink" and _has_walk_blink_anim:
			return blink_anim
		elif blink_anim == &"default_blink" and _has_default_blink_anim:
			return blink_anim
	return base_anim
