# This is the internals for all the important stuff inside the game. Things like settings, keymap and nodes

extends Node

var tree: SceneTree = null
var scene: Node = null
var camera: Camera3D = null
var player: CharacterBody3D = null

func _ready() -> void:

	tree = get_tree()
	if not tree:
		print("Couldn't find main tree!")
		return
	scene = tree.get_current_scene()
	if not scene:
		print("Couldn't find main tree scene!")
		return

	# Find player (Cubic) robustly
	player = scene.get_node_or_null("Cubic")
	if not player:
		var found_player := scene.find_child("Cubic", true, false)
		if found_player and found_player is CharacterBody3D:
			player = found_player
		else:
			print("Couldn't find cubic! proceeding without explicit player reference. Check if Cubic is loaded on the map!")

	# Find camera: prefer Cubic/Camera, then any Camera node in tree
	camera = scene.get_node_or_null("Cubic/Camera") as Camera3D
	if not camera:
		var found_cam := scene.find_child("Camera", true, false)
		if found_cam and found_cam is Camera3D:
			camera = found_cam
	if camera:
		camera.make_current()
	else:
		print("Couldn't find the camera! proceeding without making any camera current. Check if camera is loaded and inside cubic's node.")
	# loads hyprcam's script


# Input map. (probably move this to a settings.gd?)
# func _input(event: InputEvent) -> void:
	# TODO: Implement the controls here when movement and stuff are implemented
	# IMPORTANT: utilize godot's keymap for controls!
	pass
