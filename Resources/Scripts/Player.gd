extends CharacterBody3D 

@export var speed: float = 6
@export var jump_power: float = 5
@export var gravity: float = 24
@export var is_climbing: bool = false

func _ready():
	pass

func _physics_process(delta: float) -> void:

	# input detection
	var input_dir = Vector2(
		Input.get_action_strength("right") - Input.get_action_strength("left"),
		Input.get_action_strength("down") - Input.get_action_strength("up")
	)
	 
	# movement
	if input_dir.length() > 0.1:

		velocity.x = input_dir.x * speed
		velocity.z = input_dir.z * speed

	else: # friction!
		velocity.x = move_toward(velocity.x, 0, speed * delta * 10)
		velocity.z = move_toward(velocity.z, 0, speed * delta * 10)
		
	if is_on_floor():
		if Input.is_action_just_pressed("jump"):
			velocity.y = jump_power
	else:
		velocity.y -= gravity * delta
	
	move_and_slide()
