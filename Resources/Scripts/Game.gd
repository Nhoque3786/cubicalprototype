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
	player = scene.get_node_or_null("Player")
	if not player:
		print("Couldn't find the player! is it loaded?")
		return
	camera = scene.get_node_or_null("Camera3D")
	if not camera:
		print("Couldn't find main scene camera!")
		return
	camera.make_current()

# Input map. (probably move this to a settings.gd?)
func _input(event: InputEvent) -> void:
	# TODO: Implement the controls here when movement and stuff are implemented
	# IMPORTANT: utilize godot's keymap for controls!
	pass