extends Camera3D

@export var smooth : float = 5.0
@export var target : float = 0.0
@export var rangle : float = 0.0
@export var radius : float = 3.8 

func _ready() -> void:
	
	set_projection(Camera3D.PROJECTION_ORTHOGONAL)

	position = Vector3(0, 0, radius)  

	print("Camera initialized")

func _process(delta: float) -> void:
	
	if rangle != target:
		rangle = lerp_angle(rangle, target, smooth * delta)

		position = Vector3(
			sin(rangle) * radius,
			0,
			cos(rangle) * radius
		)
	
		look_at(Vector3.ZERO)

		print("Camera rotation: ", rotation.y)

func rotate_by(amount: float) -> void:
	target += amount
