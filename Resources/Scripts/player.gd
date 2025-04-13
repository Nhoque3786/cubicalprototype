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

func _ready():
    # is isometricam ready?
    if has_node("isometricam"):
        print("Isometricam ready!")
    else:
        print("Whoops, Isometricam was not ready!")
pass

func _physics_process(_delta):

    # imput detection
    var input_x = Input.get_axis("right", "left")
    var input_y = Input.get_action_strength("down") - Input.get_action_strength("up")
    
    # get camera rotation
    var camera = get_node("isometricam")
    var camera_rotation = camera.current_rotation
    
    # Makes the movement based on the camera's current rotation
    direction = 

pass
