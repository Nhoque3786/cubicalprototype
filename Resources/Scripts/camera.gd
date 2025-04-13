extends Camera3D

var smooth_speed = 5.0
var target_rotation = 0.0
var current_rotation = 0.0
var orbit_radius = 3.8 

func _ready():
	
	set_projection(Camera3D.PROJECTION_ORTHOGONAL)
	set_current(true)
	position = Vector3(0, 0, orbit_radius)  
	print("Camera initialized")

func _process(delta):
	
	current_rotation = lerp_angle(current_rotation, target_rotation, smooth_speed * delta)
	
	var new_x = orbit_radius * sin(current_rotation)
	var new_z = orbit_radius * cos(current_rotation)
	position = Vector3(new_x, 0, new_z)
	
	look_at(Vector3.ZERO)
	print("Camera rotation: ", rotation.y)

func rotate_left():
	target_rotation += PI/2
	print("Rotating left. Target rotation: ", target_rotation)

func rotate_right():
	target_rotation -= PI/2
	print("Rotating right. Target rotation: ", target_rotation)

func _input(event):
	if event.is_action_pressed("camera_left"):
		rotate_left()
	elif event.is_action_pressed("camera_right"):
		rotate_right()
	print("Input detected: ", event.as_text() if event is InputEvent else "Non-input event")

func current_direction():
	# Converts to direction (0=north, 1=east, 2=south, 3=west)
	return (current_rotation / (PI/2)) % 4