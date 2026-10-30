# ClimbSidewaysTest.gd - Autoplays Cubic's sideways climbing animations in a loop:
# climb up -> stop (idle) -> climb down -> stop (idle) -> repeat.
extends Node3D

@export var sprite: AnimatedSprite3D
@export var anim_up: StringName = &"Climb_side_up"
@export var anim_down: StringName = &"Climb_side_down"
@export var anim_idle: StringName = &"Climb_side_idle"
@export var climb_distance: float = 1.5
@export var climb_duration: float = 1.5
@export var pause_duration: float = 1.0
@export var flip_h: bool = false

var _start_y: float

func _ready() -> void:
	sprite.flip_h = flip_h
	_start_y = sprite.position.y
	_run_loop()

func _run_loop() -> void:
	while is_inside_tree():
		# Climb up
		sprite.play(anim_up)
		await _move_to(_start_y + climb_distance)
		# Stop
		sprite.play(anim_idle)
		await get_tree().create_timer(pause_duration).timeout
		# Climb down
		sprite.play(anim_down)
		await _move_to(_start_y)
		# Stop
		sprite.play(anim_idle)
		await get_tree().create_timer(pause_duration).timeout

func _move_to(target_y: float) -> void:
	var tween: Tween = create_tween()
	tween.tween_property(sprite, "position:y", target_y, climb_duration)
	await tween.finished
