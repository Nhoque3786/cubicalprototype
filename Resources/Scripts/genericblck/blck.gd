extends MeshInstance3D


@export_enum("color", "texture", "rainbow") var appearance: String = "color"
@export var rainbowspeed: float = 1.0
@export var color: Color = Color(1, 1, 1)
@export var texture: Texture = null
@export var opacity: float = 1.0
@export var friction: float = 0.5
@export var solid: bool = true

var time_passed: float = 0.0

func _ready():
	update_appearance()
func _process(delta):
	if appearance == "rainbow":
		time_passed += delta * rainbowspeed

		var r = sin(time_passed * 0.9) * 0.5 + 0.5
		var g = sin(time_passed * 0.7 + 2) * 0.5 + 0.5
		var b = sin(time_passed * 0.8 + 4) * 0.5 + 0.5
		var rainbow_color = Color(r, g, b)

		if mesh and mesh.material:
			mesh.material.albedo_color = rainbow_color

func update_appearance():
	if mesh == null:
		mesh = BoxMesh.new()

	var material = StandardMaterial3D.new()
	if appearance == "color":
		material.albedo_color = color
	elif appearance == "texture":
		material.albedo_texture = texture
	elif appearance == "rainbow":
		material.albedo_color = Color(1, 1, 1)
	
	material.opacity = opacity
	material.roughness = 1.0
	material.metallic = 0.0
	
	mesh.material = material
		
	
