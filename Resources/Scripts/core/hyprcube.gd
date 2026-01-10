## Hyprcube: makes the world spin, literally.
## This script handles the world rotation and provides movement orientation for the player.
extends Node

signal rotation_started
signal rotation_finished

# A reference to the node that contains the entire level geometry to be rotated.
@export var world_node: Node3D
# How long the rotation animation takes.
@export var rotation_duration: float = 0.4
@export var transition_type: int = Tween.TRANS_CUBIC
@export var ease_type: int = Tween.EASE_IN_OUT

var is_rotating: bool = false
var target_rotation_y_deg: float = 0.0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	
	# If world_node is not set in the editor, try to find it automatically.
	# This assumes this script is a child of "World" and the level node is named "Level".
	if world_node == null:
		var current_scene: Node = get_tree().current_scene
		if current_scene:
			world_node = current_scene.find_child("Level", true, false)
		
		if world_node == null:
			world_node = get_node_or_null(^"../Level")

	if world_node == null:
		push_error("Hyprcube: Could not find 'Level' node! Please check if the nodetree is the same structure as the template.")
		set_process_unhandled_input(false)


func _unhandled_input(event: InputEvent) -> void:
	# Don't allow new rotation while one is in progress.
	if is_rotating:
		return

	var should_rotate := false
	if event.is_action_pressed("rotate_right"):
		target_rotation_y_deg += 90.0
		should_rotate = true
	elif event.is_action_pressed("rotate_left"):
		target_rotation_y_deg -= 90.0
		should_rotate = true

	if should_rotate:
		rotate_world()


func rotate_world() -> void:
	is_rotating = true
	rotation_started.emit()
	
	# pause the game while rotating
	get_tree().paused = true
	
	var tween: Tween = create_tween()
	# Use a smooth transition curve.
	tween.set_trans(transition_type)
	tween.set_ease(ease_type)

	# Animate the 'rotation_degrees:y' property of the world node.
	tween.tween_property(world_node, ^"rotation_degrees:y", target_rotation_y_deg, rotation_duration)

	# Wait for the animation to finish.
	await tween.finished
	
	is_rotating = false
	get_tree().paused = false
	rotation_finished.emit()


# This public function will be called by the player to know which way is "right".
func get_horizontal_direction() -> Vector3:
	# Create a vector pointing right (1, 0, 0) and rotate it by the current world rotation.
	var angle_rad: float = deg_to_rad(target_rotation_y_deg)
	return Vector3.RIGHT.rotated(Vector3.UP, angle_rad)


func is_world_rotating() -> bool:
	return is_rotating
