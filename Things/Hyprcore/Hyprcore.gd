# Hyprcore: the heart and brains that make 2D platforming possible on a 3D world.
extends Node3D
class_name Hyprcore

signal rotation_started()
signal rotation_finished()

# Settings
@export_group("World Rotation")
@export var level_node: Node3D
@export var rotation_duration: float = 0.4
@export var transition_type: Tween.TransitionType = Tween.TRANS_CUBIC
@export var ease_type: Tween.EaseType = Tween.EASE_IN_OUT
var is_rotating: bool = false
var _cached_camera: Camera3D = null
var target_rotation_y_deg: float = 0.0

@export_group("Snapping")
@export var grid_map: GridMap
@export var max_distance: float = 128.0
@export_flags_3d_physics var collision_mask: int = 1
@export var vertical_offsets: Array[float] = [-0.35, -0.5, -0.65, -0.8, -0.95]
@export var projected_snap_tolerance: float = 0.55
@export var max_floor_snap_height: float = 3.0
@export var snap_speed: float = 0.0
@export_range(32, 512) var search_depth_radius: int = 64
enum DepthPriority { NEAREST, FRONTMOST, BEHINDMOST }
@export var grounded_depth_priority: DepthPriority = DepthPriority.NEAREST
@export var airborne_depth_priority: DepthPriority = DepthPriority.BEHINDMOST

enum WorldSide {NORTH, EAST, SOUTH, WEST}
@export_group("Orientation State")
@export var current_side: WorldSide = WorldSide.NORTH



func _enter_tree() -> void:
	add_to_group(&"hyprcore")

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS

	if level_node == null:
		level_node = get_node_or_null("Level") as Node3D
		if level_node == null:
			level_node = find_child("Level*", true, false) as Node3D

	if level_node == null:
		push_warning("Hyprcore: There's no Level node in the scene! Use the leveltemplate.tscn to get started.")

	if grid_map == null and level_node != null:
		grid_map = level_node.find_child("GridMap", true, false) as GridMap

func _unhandled_input(event: InputEvent) -> void:
	if is_rotating or level_node == null:
		return

	var should_rotate: bool = false
	if event.is_action_pressed("rotate_right"):
		target_rotation_y_deg = fposmod(target_rotation_y_deg - 90, 360.0)
		current_side = posmod(int(current_side) - 1, 4) as WorldSide
		should_rotate = true
	elif event.is_action_pressed("rotate_left"):
		target_rotation_y_deg = fposmod(target_rotation_y_deg + 90, 360.0)
		current_side = posmod(int(current_side) + 1, 4) as WorldSide
		should_rotate = true

	if should_rotate:
		rotate_world()

# --- Public API -------------

func rotate_world() -> void:
	if is_rotating:
		return
	is_rotating = true
	rotation_started.emit()
	await Hyprcube.rotate_world(self)
	is_rotating = false
	rotation_finished.emit()

# Instantly forces the world to a given side with no tween/animation
func set_world_side_instant(side: WorldSide) -> void:
	Hyprcube.set_world_side_instant(self, side)

func snap_to_grid(body: CharacterBody3D, force_instant: bool = false, assume_grounded: bool = false) -> void:
	Hyprsnap.snap_to_grid(self, body, force_instant, assume_grounded)

# --- Shared helpers (used by both Hyprcube and Hyprsnap) -----------------------

func get_grid_map() -> GridMap:
	if grid_map != null and grid_map.is_inside_tree():
		return grid_map
	if level_node == null:
		return null
	grid_map = level_node.find_child("GridMap", true, false) as GridMap
	return grid_map

func get_player() -> CharacterBody3D:
	if not is_inside_tree():
		return null
	return get_tree().get_first_node_in_group(&"player") as CharacterBody3D

func get_camera() -> Camera3D:
	if _cached_camera != null and _cached_camera.is_inside_tree():
		return _cached_camera
	var viewport := get_viewport()
	if viewport == null:
		return null
	_cached_camera = viewport.get_camera_3d()
	return _cached_camera

func get_depth_direction() -> Vector3:
	var camera: Camera3D = get_camera()
	if camera == null:
		return Vector3.BACK

	var camera_depth: Vector3 = camera.global_transform.basis.z
	camera_depth.y = 0.0
	if camera_depth.is_zero_approx():
		return Vector3.BACK

	return camera_depth.normalized()

func get_screen_horizontal_direction() -> Vector3:
	var camera: Camera3D = get_camera()
	if camera == null:
		return Vector3.RIGHT

	var camera_right: Vector3 = camera.global_transform.basis.x
	camera_right.y = 0.0
	if camera_right.is_zero_approx():
		return Vector3.RIGHT

	return camera_right.normalized()
