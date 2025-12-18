# This is the internals for all the important stuff inside the game. Things like settings, keymap and nodes

extends Node

var tree: SceneTree = null
var scene: Node = null
var camera: Camera3D = null
var player: CharacterBody3D = null
var hyprcube: Node = null
var hyprground: Node = null

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
	player = scene.find_child("Cubic", true, false)
	if not player:
		print("Couldn't find cubic! proceeding without explicit player reference. Check if Cubic is loaded on the map!")

	# Find camera: prefer Cubic/Camera, then any Camera node in tree
	camera = scene.find_child("Camera", true, false)
	if camera:
		camera.make_current()
	else:
		print("Couldn't find the camera! proceeding without making any camera current. Check if camera is loaded and inside cubic's node.")

	# Find global nodes
	hyprcube = scene.find_child("Hyprcube", true, false)
	if not hyprcube:
		print("Couldn't find Hyprcube node in the scene!")

	hyprground = scene.find_child("Hyprground", true, false)
	if not hyprground:
		print("Couldn't find Hyprground node in the scene!")


# Input map. (probably move this to a settings.gd?)
# func _input(event: InputEvent) -> void:
	# TODO: Implement the controls here when movement and stuff are implemented
	# IMPORTANT: utilize godot's keymap for controls!
	pass
