# Cubic's internals.
extends CharacterBody3D

# TODO: move the gravity controls for map specific.
@export var speed: float = 6
@export var jump_power: float = 5
@export var gravity: float = 24
@export var is_climbing: bool = false

func _ready():
	pass

# func _physics_process(delta: float) -> void:
# TODO: implement movement system with refactored controls for game.gd
# uncomment this after making this shit lmao
# pass
