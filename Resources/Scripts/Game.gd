extends Node

var tree: SceneTree = null
var scene: Node = null
var camera: Camera3D = null
var player: CharacterBody3D = null

func _ready() -> void:

	tree = get_tree()
	if not tree:
		print("Couldn't find main tree")
		return

	scene = tree.get_current_scene()
	if not scene:
		print("Couldn't find main tree scene")
		return

	camera = scene.get_node_or_null("Camera3D")
	if not camera:
		print("Couldn't find main scene camera")
		return

	camera.make_current()

func _input(event: InputEvent) -> void:

	if event.is_action_pressed("ui_right"):
		camera.rotate_by(+PI/2)

	if event.is_action_pressed("ui_left"):
		camera.rotate_by(-PI/2)
