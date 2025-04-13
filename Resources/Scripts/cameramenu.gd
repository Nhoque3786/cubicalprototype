## this was a old version of camera.gd, but it spins on itself. Pretty great for a main menu camera or somethin like that lol

extends Camera3D

var smooth_speed = 5.0
var target_rotation = 0.0
var current_rotation = 0.0

func _ready():
    # Set up initial properties
    set_projection(Camera3D.PROJECTION_PERSPECTIVE)
    set_current(true)
    print("Camera initialized")

func _process(delta):
    # Smooth rotation interpolation
    current_rotation = lerp_angle(current_rotation, target_rotation, smooth_speed * delta)
    rotation.y = current_rotation
    print("Camera rotation: ", rotation.y)

func rotate_left():
    target_rotation += PI/2
    print("Rotating left. Target rotation: ", target_rotation)

func rotate_right():
    target_rotation -= PI/2
    print("Rotating right. Target rotation: ", target_rotation)

func _input(event):
    if event.is_action_pressed("ui_left"):
        rotate_left()
    elif event.is_action_pressed("ui_right"):
        rotate_right()
    print("Input detected: ", event.as_text() if event is InputEvent else "Non-input event")
