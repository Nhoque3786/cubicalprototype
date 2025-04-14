extends CharacterBody3D 

# settings (set this up on the object later for dynamic shit)
@export var speed = 6
@export var jump_power = 5
@export var gravity = 24

# More variables

@export var direction = 0
@export var camerarotating = false # makes the gameplay pause when the camera is rotating
@export var isclimbing = false
@export var onfloor = false #changes if you are on floor.
var camera

func _ready():
    # is isometricam ready?
    if has_node("isometricam"):
        camera = get_node("isometricam")
        camera.connect("rotation_started", self, "_on_camera_rotation_started")
        camera.connect("rotation_completed", self, "_on_camera_rotation_completed")
        print("Isometricam ready!")
        
        direction = camera.current_direction()
    else:
        print("Whoops, Isometricam was not ready!")

func _physics_process(_delta):
    if camerarotating:
        return
    onfloor = is_on_floor()
    
    # input detection
    var input_dir = Vector2(
        Input.get_action_strength("right") - Input.get_action_strength("left"),
        Input.get_action_strength("down") - Input.get_action_strength("up"))
     
    # movement
    if input_dir.length() > 0.1:
        velocity.x = input_dir.x * speed
        velocity.z = input_dir.z * speed
    else: # friction!
        velocity.x = move_toward(velocity.x, 0, speed * _delta * 10)
        velocity.z = move_toward(velocity.z, 0, speed * _delta * 10)
        
    
    # jump
    if Input.is_action_just_pressed("jump") and onfloor:
        velocity.y = jump_power

    # apply gravity (make this a separate script and sync it with the world/level config later when starting to make the maps)
    if not onfloor:
        velocity.y -= gravity * _delta
    
    # apply movement
    move_and_slide()

func _convert_input_to_movement(input_dir, camera_direction):
    var movement = Vector3.ZERO
    var cubic_direction = camera_direction
    
    match cubic_direction:
        0: #north
            movement.x = input_dir.x
            movement.z = input_dir.y
        
        1: #east
            movement.x = input_dir.y
            movement.z = -input_dir.x
        
        2: #south
            movement.x = -input_dir.x
            movement.z = -input_dir.y
        
        3: #west
            movement.x = -input_dir.y
            movement.z = input_dir.x
    
    # normalize if need it
    if movement.length_squared() > 1.0:
        movement = movement.normalized()
    
    return movement

func _on_camera_rotation_started():
    camerarotating = true
    velocity = Vector3.ZERO

func _on_camera_rotation_completed():
    camerarotating = false