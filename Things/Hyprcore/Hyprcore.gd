# Hyprcore: the thing that makes the 2D possible, on a 3D environment
# This script takes care of world rotation, snapping, and orientation flagging.
extends Node3D
class_name Hyprcore

signal rotation_started
signal rotation_finished

# Settings
@export_group("World Rotation")
@export var level_node: Node3D
@export var rotation_duration: float = 0.4
@export var transition_type: Tween.TransitionType = Tween.TRANS_CUBIC
@export var ease_type: Tween.EaseType = Tween.EASE_IN_OUT
var is_rotating: bool = false
var target_rotation_y_deg: float = 0.0

@export_group("Snapping")
@export var grid_map: GridMap
@export var max_distance: float = 128.0
@export_flags_3d_physics var collision_mask: int = 1
@export var vertical_offsets: Array[float] = [-0.35, -0.5, -0.65, -0.8, -0.95]
@export var projected_snap_tolerance: float = 0.55
@export var max_floor_snap_height: float = 3.0
enum DepthPriority { NEAREST, FRONTMOST, BEHINDMOST }
@export var grounded_depth_priority: DepthPriority = DepthPriority.NEAREST
@export var airborne_depth_priority: DepthPriority = DepthPriority.BEHINDMOST

@export_group("Orientation")
enum Orientation {NORTH, EAST, SOUTH, WEST}
var current_side: Hyprcore.Orientation = Orientation.NORTH



# HyprCube: Makes the perspective spin in your command.
func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS

	if level_node == null:
		level_node = get_node_or_null("Level")
		if level_node == null:
			level_node = find_child("Level*", true, false) as Node3D

	if level_node == null:
		push_warning("Hyprcore: There's no Level node in the scene! Use the leveltemplate.tscn to get started.")

	if grid_map == null and level_node != null:
		grid_map = level_node.find_child("GridMap", true, false) as GridMap

func _unhandled_input(event: InputEvent) -> void:
	if is_rotating:
		return

	var should_rotate := false
	if event.is_action_pressed("rotate_right"):
		target_rotation_y_deg -= 90
		current_side = posmod(current_side - 1, 4) as Hyprcore.Orientation
		should_rotate = true
	elif event.is_action_pressed("rotate_left"):
		target_rotation_y_deg += 90
		current_side = posmod(current_side + 1, 4) as Hyprcore.Orientation
		should_rotate = true

	if should_rotate:
		rotate_world()

func rotate_world() -> void:
	if level_node == null:
		push_error("Hyprcore: level_node is null, cannot rotate!")
		return

	var player := _get_player()
	var player_level_position: Variant = null
	if player != null:
		player_level_position = level_node.to_local(player.global_position)

	is_rotating = true
	rotation_started.emit()

	get_tree().paused = true

	var tween: Tween = create_tween()
	tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	tween.set_trans(transition_type)
	tween.set_ease(ease_type)

	var target_rad: float = deg_to_rad(target_rotation_y_deg)
	tween.tween_property(level_node, "rotation:y", target_rad, rotation_duration)

	await tween.finished

	get_tree().paused = false
	await get_tree().physics_frame

	if player != null and player_level_position != null:
		player.global_position = level_node.to_global(player_level_position)

	snap_to_grid(player)
	is_rotating = false
	rotation_finished.emit()

# Hyprgrid: Snapping player to grid to make 2D platforming possible on 3D.
func snap_to_grid(body: CharacterBody3D, _unused: GridMap = null) -> void:
	if body == null or not body.is_inside_tree():
		return

	var space_state: PhysicsDirectSpaceState3D = body.get_world_3d().direct_space_state
	var origin: Vector3 = body.global_position
	var depth_direction: Vector3 = get_depth_direction()
	var grid_snap: Variant = _get_grid_snap_position(body, origin, depth_direction)
	if grid_snap != null:
		body.global_position = grid_snap
		return

	var hits: Array[Dictionary] = []

	for v_off in vertical_offsets:
		var start: Vector3 = origin + Vector3(0, v_off, 0)
		for dir in [1.0, -1.0]:
			var target: Vector3 = start + depth_direction * dir * max_distance
			var query: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(start, target, collision_mask)
			query.exclude = [body.get_rid()]
			query.hit_from_inside = true
			
			var result: Dictionary = space_state.intersect_ray(query)
			if not result.is_empty():
				hits.append(result)

	if hits.is_empty():
		return

	var closest_hit: Dictionary = hits[0]
	var min_dist = abs(depth_direction.dot(closest_hit.position - origin))
	for i in range(1, hits.size()):
		var d = abs(depth_direction.dot(hits[i].position - origin))
		if d < min_dist:
			min_dist = d
			closest_hit = hits[i]

	var hit_normal: Vector3 = closest_hit.get("normal", Vector3.ZERO)
	var target_point: Vector3 = closest_hit.position - hit_normal * 0.5
	var snap_distance: float = depth_direction.dot(target_point - origin)

	body.global_position += depth_direction * snap_distance

func _get_grid_snap_position(body: CharacterBody3D, origin: Vector3, depth_direction: Vector3) -> Variant:
	var active_grid: GridMap = _get_grid_map()
	if active_grid == null:
		return null

	var horizontal_direction: Vector3 = get_screen_horizontal_direction()
	var priority: DepthPriority = grounded_depth_priority if body.is_on_floor() else airborne_depth_priority
	var best_depth_offset: float = 0.0
	var best_score: float = INF
	var best_depth_position: float = 0.0
	var best_depth_distance: float = INF
	var has_candidate := false

	for cell in active_grid.get_used_cells():
		var cell_center: Vector3 = active_grid.to_global(active_grid.map_to_local(cell))
		var cell_size: Vector3 = active_grid.cell_size
		var cell_top_y: float = cell_center.y + cell_size.y * 0.5
		var floor_distance: float = origin.y - cell_top_y

		if floor_distance < -0.1 or floor_distance > max_floor_snap_height:
			continue

		var horizontal_distance: float = abs(horizontal_direction.dot(cell_center - origin))
		if horizontal_distance > projected_snap_tolerance:
			continue

		var depth_offset: float = depth_direction.dot(cell_center - origin)
		var depth_distance: float = abs(depth_offset)
		var depth_position: float = depth_direction.dot(cell_center)
		var score: float = horizontal_distance * 10.0 + floor_distance

		if _is_better_depth_candidate(priority, score, depth_distance, depth_position, best_score, best_depth_distance, best_depth_position, has_candidate):
			best_score = score
			best_depth_position = depth_position
			best_depth_distance = depth_distance
			best_depth_offset = depth_offset
			has_candidate = true

	if not has_candidate:
		return null

	return origin + depth_direction * best_depth_offset

func _is_better_depth_candidate(
	priority: DepthPriority,
	score: float,
	depth_distance: float,
	depth_position: float,
	best_score: float,
	best_depth_distance: float,
	best_depth_position: float,
	has_candidate: bool
) -> bool:
	if not has_candidate:
		return true

	if not is_equal_approx(score, best_score):
		return score < best_score

	match priority:
		DepthPriority.FRONTMOST:
			return depth_position > best_depth_position
		DepthPriority.BEHINDMOST:
			return depth_position < best_depth_position
		_:
			return depth_distance < best_depth_distance

func _get_grid_map() -> GridMap:
	if grid_map != null and grid_map.is_inside_tree():
		return grid_map

	if level_node == null:
		return null

	grid_map = level_node.find_child("GridMap", true, false) as GridMap
	return grid_map

func _get_player() -> CharacterBody3D:
	return get_tree().root.find_child("Cubic", true, false) as CharacterBody3D

func get_depth_direction() -> Vector3:
	var camera := get_viewport().get_camera_3d()
	if camera == null:
		return Vector3.BACK

	var camera_depth := camera.global_transform.basis.z
	camera_depth.y = 0.0
	if camera_depth.is_zero_approx():
		return Vector3.BACK

	return camera_depth.normalized()

func get_screen_horizontal_direction() -> Vector3:
	var camera := get_viewport().get_camera_3d()
	if camera == null:
		return Vector3.RIGHT

	var camera_right := camera.global_transform.basis.x
	camera_right.y = 0.0
	if camera_right.is_zero_approx():
		return Vector3.RIGHT

	return camera_right.normalized()

func get_horizontal_direction() -> Vector3:
	var angle_rad: float = deg_to_rad(target_rotation_y_deg)
	return Vector3.RIGHT.rotated(Vector3.UP, angle_rad)
