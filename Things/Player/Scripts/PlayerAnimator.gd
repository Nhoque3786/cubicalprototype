# PlayerAnimator.gd - Handles visuals and animation states for Cubic.
extends Node
class_name PlayerAnimator

@export var animated_sprite: AnimatedSprite3D

# Animation speed multipliers
@export var walk_speed_mult: float = 1.5
@export var jump_anim_speed: float = 1.2
@export var turn_anim_speed: float = 1.0
@export var soft_land_speed: float = 7.0
@export var hard_land_speed: float = 14.0
@export var stretch_velocity_threshold: float = 5.0
@export var reference_walk_speed: float = 6.0
@export var input_deadzone: float = 0.1

# Animation tags from .ase
@export_group("Animation Tags")
@export var anim_idle: StringName = &"Idle"
@export var anim_idle_blink: StringName = &"Idle_Blink"
@export var anim_walk: StringName = &"walk"
@export var anim_walk_blink: StringName = &"Walk_blink"
@export var anim_squish: StringName = &"Squish"
@export var anim_squish_hard: StringName = &"Squish_Hard"
@export var anim_turn: StringName = &"Turn"
@export var anim_stretch: StringName = &"stretch"
@export var anim_fall: StringName = &"fall"

# Blink system
@export_group("Blink Settings")
@export var blink_interval_min: float = 2.0
@export var blink_interval_max: float = 6.0
@export var blink_duration: float = 0.6
var _blink_timer: float = 4.0
var _is_blinking: bool = false

var _cache_initialized: bool = false
var _has_stretch_anim: bool = false
var _has_squish_anim: bool = false
var _has_squish_hard_anim: bool = false
var _has_turn_anim: bool = false
var _has_fall_anim: bool = false
var _has_walk_blink_anim: bool = false
var _has_idle_blink_anim: bool = false

var _is_turning: bool = false
var _target_flip: bool = false

func _ready() -> void:
	_cache_animations()

func _cache_animations() -> void:
	if animated_sprite and animated_sprite.sprite_frames:
		var frames: SpriteFrames = animated_sprite.sprite_frames
		_has_stretch_anim = frames.has_animation(anim_stretch)
		_has_squish_anim = frames.has_animation(anim_squish)
		_has_squish_hard_anim = frames.has_animation(anim_squish_hard)
		_has_turn_anim = frames.has_animation(anim_turn)
		_has_fall_anim = frames.has_animation(anim_fall)
		_has_walk_blink_anim = frames.has_animation(anim_walk_blink)
		_has_idle_blink_anim = frames.has_animation(anim_idle_blink)

		# Ensure one-shot transition animations cannot soft-lock on the floor if imported with loop=true
		for one_shot: StringName in [anim_squish, anim_squish_hard, anim_turn]:
			if frames.has_animation(one_shot):
				frames.set_animation_loop(one_shot, false)

		_cache_initialized = true

func _commit_turn() -> void:
	if _is_turning:
		if animated_sprite:
			animated_sprite.flip_h = _target_flip
		_is_turning = false

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
	if not animated_sprite or not animated_sprite.sprite_frames:
		return

	if not _cache_initialized:
		_cache_animations()

	var current_anim: StringName = animated_sprite.animation
	var playing: bool = animated_sprite.is_playing()

	# Clean up turning state if turn animation is no longer active
	if _is_turning and (current_anim != anim_turn or not playing):
		_commit_turn()

	# 1. High Priority: Jump Start (Squish phase)
	if did_jump:
		_commit_turn()
		animated_sprite.speed_scale = jump_anim_speed
		if _has_squish_anim:
			animated_sprite.play(anim_squish)
		return

	if just_landed:
		_commit_turn()
		animated_sprite.speed_scale = 1.0
		if fall_speed >= hard_land_speed:
			if _has_squish_hard_anim:
				animated_sprite.play(anim_squish_hard)
			elif _has_squish_anim:
				animated_sprite.play(anim_squish)
			return
		elif fall_speed >= soft_land_speed and _has_squish_anim:
			animated_sprite.play(anim_squish)
			return

	# 2. Direction and Turning (Flip H)
	var in_landing_squish: bool = is_on_floor and playing and (current_anim == anim_squish or current_anim == anim_squish_hard)
	if abs(input_h) > input_deadzone:
		var target_flip: bool = input_h < 0
		if _is_turning:
			if target_flip == animated_sprite.flip_h:
				_is_turning = false
		elif animated_sprite.flip_h != target_flip:
			if is_on_floor and _has_turn_anim and not in_landing_squish:
				_is_turning = true
				_target_flip = target_flip
				animated_sprite.speed_scale = turn_anim_speed
				animated_sprite.play(anim_turn)
				return
			else:
				animated_sprite.flip_h = target_flip

	# Prevent interrupting transition animations while on floor
	if is_on_floor and playing and (current_anim == anim_squish or current_anim == anim_squish_hard or current_anim == anim_turn):
		return

	# 3. Air States (Jumping / Falling / Stretching)
	if not is_on_floor:
		_commit_turn()

		# Allow jump squish to finish playing during upward ascent
		if v_vel > 0.0 and current_anim == anim_squish and playing:
			return

		animated_sprite.speed_scale = 1.0

		# Use stretch animation only for fast falling
		if v_vel < -stretch_velocity_threshold and _has_stretch_anim:
			animated_sprite.play(anim_stretch)
		elif _has_fall_anim:
			# Near the apex of the jump or slow movement
			animated_sprite.play(anim_fall)
		else:
			animated_sprite.play(anim_idle)
		return

	# 4. Ground States (Walk / Idle)
	_update_blink_timer(delta)
	# Use the provided h_vel for consistent speed calculation regardless of world rotation
	var horizontal_speed: float = abs(h_vel)

	if horizontal_speed > 0.1:
		_play_preserving_frame(current_anim, playing, _get_blink_variant(anim_walk, anim_walk_blink, _has_walk_blink_anim), anim_walk, anim_walk_blink)
		animated_sprite.speed_scale = (horizontal_speed / max(reference_walk_speed, 0.001)) * walk_speed_mult
	else:
		_play_preserving_frame(current_anim, playing, _get_blink_variant(anim_idle, anim_idle_blink, _has_idle_blink_anim), anim_idle, anim_idle_blink)
		animated_sprite.speed_scale = 1.0

func _play_preserving_frame(
	current_anim: StringName,
	playing: bool,
	target_anim: StringName,
	base_anim: StringName,
	blink_anim: StringName
) -> void:
	if current_anim == target_anim and playing:
		return
	if playing and ((current_anim == base_anim and target_anim == blink_anim) or (current_anim == blink_anim and target_anim == base_anim)):
		var cur_frame: int = animated_sprite.frame
		var cur_progress: float = animated_sprite.frame_progress
		animated_sprite.play(target_anim)
		var frame_count: int = animated_sprite.sprite_frames.get_frame_count(target_anim)
		if frame_count > 0:
			animated_sprite.set_frame_and_progress(cur_frame % frame_count, cur_progress)
	else:
		animated_sprite.play(target_anim)

func _update_blink_timer(delta: float) -> void:
	_blink_timer -= delta
	if _blink_timer <= 0.0:
		_is_blinking = not _is_blinking
		if _is_blinking:
			_blink_timer = blink_duration
		else:
			_blink_timer = randf_range(blink_interval_min, blink_interval_max)

func _get_blink_variant(base_anim: StringName, blink_anim: StringName, has_blink_anim: bool) -> StringName:
	if _is_blinking and has_blink_anim:
		return blink_anim
	return base_anim
