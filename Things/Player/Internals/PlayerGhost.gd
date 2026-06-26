# PlayerGhost.gd - Draws a see-through silhouette of Cubic when world geometry
# sits between him and the (orthographic) camera, so he's never lost behind a block.
extends Node
class_name PlayerGhost

var player: Player
var source_sprite: AnimatedSprite3D
var ghost: AnimatedSprite3D

# How the silhouette looks. Low alpha + dark tint reads as a "shadow" showing through.
@export var tint: Color = Color(0.0, 0.0, 0.0, 0.55)
# Which physics layers count as occluders (match the world/blocks layer).
@export_flags_3d_physics var occluder_mask: int = 1
# Aim the occlusion ray a touch above the origin so it targets Cubic's body, not his feet.
@export var aim_height: float = 0.2
# Interval between occlusion raycasts (in seconds) to limit frequency.
@export var raycast_interval: float = 0.05
var _time_since_last_raycast: float = 0.0

func _ready() -> void:
	player = get_parent() as Player
	if player == null:
		return
	source_sprite = player.animated_sprite
	if source_sprite == null:
		source_sprite = player.find_child("AnimatedSprite3D", true, false) as AnimatedSprite3D
	if source_sprite == null:
		push_warning("PlayerGhost: no AnimatedSprite3D found on the player; ghost disabled.")
		return
	_build_ghost()

func _build_ghost() -> void:
	ghost = AnimatedSprite3D.new()
	ghost.name = "Ghost"
	# Share the same frames so the silhouette always matches Cubic's pose.
	ghost.sprite_frames = source_sprite.sprite_frames
	ghost.pixel_size = source_sprite.pixel_size
	ghost.billboard = source_sprite.billboard
	ghost.texture_filter = source_sprite.texture_filter
	# Draw on top of everything, recolored into a flat silhouette.
	ghost.no_depth_test = true
	ghost.render_priority = 100
	ghost.modulate = tint
	ghost.visible = false
	# Parent to the real sprite so it inherits position/offset automatically.
	source_sprite.add_child(ghost)

# Use _physics_process with an interval to limit occlusion raycasting overhead.
func _physics_process(delta: float) -> void:
	if ghost == null or source_sprite == null:
		return

	# Mirror Cubic's current pose.
	ghost.animation = source_sprite.animation
	ghost.frame = source_sprite.frame
	ghost.flip_h = source_sprite.flip_h

	_time_since_last_raycast += delta
	if _time_since_last_raycast >= raycast_interval:
		_time_since_last_raycast = 0.0
		ghost.visible = _is_occluded()

func _is_occluded() -> bool:
	var cam: Camera3D = null
	if player.hyprcore != null:
		cam = player.hyprcore.get_camera()
	if cam == null:
		cam = player.get_viewport().get_camera_3d()
	if cam == null:
		return false

	var space_state: PhysicsDirectSpaceState3D = player.get_world_3d().direct_space_state
	var target: Vector3 = player.global_position + Vector3.UP * aim_height
	var screen_pos: Vector2 = cam.unproject_position(target)
	var ray_origin: Vector3 = cam.project_ray_origin(screen_pos)
	var query := PhysicsRayQueryParameters3D.create(ray_origin, target, occluder_mask)
	query.exclude = [player.get_rid()]

	return not space_state.intersect_ray(query).is_empty()
