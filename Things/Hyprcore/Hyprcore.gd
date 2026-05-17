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

@export_group("Orientation State")
enum WorldSide {NORTH, EAST, SOUTH, WEST}
var current_side: WorldSide = WorldSide.NORTH

func _enter_tree() -> void:
	add_to_group(&"hyprcore")

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

	var should_rotate: bool = false
	if event.is_action_pressed("rotate_right"):
		target_rotation_y_deg -= 90
		current_side = posmod(current_side - 1, 4) as WorldSide
		should_rotate = true
	elif event.is_action_pressed("rotate_left"):
		target_rotation_y_deg += 90
		current_side = posmod(current_side + 1, 4) as WorldSide
		should_rotate = true

	if should_rotate:
		rotate_world()

func rotate_world() -> void:
	if level_node == null:
		push_error("Hyprcore: level_node is null, cannot rotate!")
		return

	var player := _get_player()
	var player_level_position: Vector3 = Vector3.ZERO
	var has_player_position := false
	if player != null:
		player_level_position = level_node.to_local(player.global_position)
		has_player_position = true

	is_rotating = true
	rotation_started.emit()

	get_tree().paused = true

	var tween: Tween = create_tween()
	tween.set_trans(transition_type)
	tween.set_ease(ease_type)

	var target_rad: float = deg_to_rad(target_rotation_y_deg)
	tween.tween_property(level_node, "rotation:y", target_rad, rotation_duration)

	await tween.finished

	get_tree().paused = false
	await get_tree().physics_frame  # physics_frame is a valid SceneTree signal in Godot 4

	# If the player is NOT a child of level_node, we must manually move them
	# to their new global position after the rotation.
	if player != null and player.get_parent() != level_node:
		if has_player_position:
			player.global_position = level_node.to_global(player_level_position)

	snap_to_grid(player)
	is_rotating = false
	target_rotation_y_deg = fmod(target_rotation_y_deg, 360.0)
	rotation_finished.emit()

# Hyprgrid: Snapping player to grid to make 2D platforming possible on 3D.
func snap_to_grid(body: CharacterBody3D) -> void:
	if body == null or not body.is_inside_tree():
		return

	var space_state: PhysicsDirectSpaceState3D = body.get_world_3d().direct_space_state
	var origin: Vector3 = body.global_position
	var depth_direction: Vector3 = get_depth_direction()
	var grid_snap: Variant = _get_grid_snap_position(body, origin, depth_direction)
	if grid_snap != null:
		body.global_position = grid_snap as Vector3
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
	var min_dist: float = abs(depth_direction.dot(closest_hit["position"] - origin))
	for i in range(1, hits.size()):
		var d: float = abs(depth_direction.dot(hits[i]["position"] - origin))
		if d < min_dist:
			min_dist = d
			closest_hit = hits[i]

	var hit_normal: Vector3 = closest_hit.get("normal", Vector3.ZERO)
	var target_point: Vector3 = closest_hit["position"] - hit_normal * 0.5
	var snap_distance: float = depth_direction.dot(target_point - origin)

	body.global_position += depth_direction * snap_distance

func _get_grid_snap_position(body: CharacterBody3D, origin: Vector3, depth_direction: Vector3) -> Variant:
	var active_grid: GridMap = _get_grid_map()
	if active_grid == null:
		return null

	var priority: DepthPriority = grounded_depth_priority if body.is_on_floor() else airborne_depth_priority
	var horizontal_direction: Vector3 = get_screen_horizontal_direction()

	# Optimization: Work in local space
	var local_origin: Vector3 = active_grid.to_local(origin)
	var local_horiz_dir: Vector3 = active_grid.global_transform.basis.inverse() * horizontal_direction
	var local_depth_dir: Vector3 = active_grid.global_transform.basis.inverse() * depth_direction
	var cell_size: Vector3 = active_grid.cell_size

	# Determine search range in grid coordinates (localized lookup)
	var center_cell: Vector3i = active_grid.local_to_map(local_origin)
	var r_h: int = ceil(projected_snap_tolerance / min(cell_size.x, cell_size.z)) + 1
	var r_v: int = ceil(max_floor_snap_height / cell_size.y) + 2
	var r_d: int = 32 # Search depth radius (adjust as needed for level depth)

	var best_depth_offset: float = 0.0
	var best_score: float = INF
	var best_depth_position: float = 0.0
	var best_depth_distance: float = INF
	var has_candidate: bool = false

	for x in range(center_cell.x - r_h, center_cell.x + r_h + 1):
		for y in range(center_cell.y - r_v, center_cell.y + 2):
			for z in range(center_cell.z - r_d, center_cell.z + r_d + 1):
				var cell := Vector3i(x, y, z)
				if active_grid.get_cell_item(cell) == GridMap.INVALID_CELL_ITEM:
					continue

				# Calculate cell center in local space (very fast)
				var local_cell_center: Vector3 = (Vector3(cell) + Vector3(0.5, 0.5, 0.5)) * cell_size

				# 1. Vertical check (fast)
				var cell_top_y: float = local_cell_center.y + cell_size.y * 0.5
				var floor_distance: float = local_origin.y - cell_top_y
				if floor_distance < -0.1 or floor_distance > max_floor_snap_height:
					continue

				# 2. Horizontal check (fast)
				var horizontal_distance: float = abs(local_horiz_dir.dot(local_cell_center - local_origin))
				if horizontal_distance > projected_snap_tolerance:
					continue

				# 3. Depth logic
				var depth_offset: float = local_depth_dir.dot(local_cell_center - local_origin)
				var depth_distance: float = abs(depth_offset)

				var depth_position: float = local_depth_dir.dot(local_cell_center)
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
	return get_tree().get_first_node_in_group(&"player") as CharacterBody3D

func get_depth_direction() -> Vector3:
	var camera: Camera3D = get_viewport().get_camera_3d()
	if camera == null:
		return Vector3.BACK

	var camera_depth: Vector3 = camera.global_transform.basis.z
	camera_depth.y = 0.0
	if camera_depth.is_zero_approx():
		return Vector3.BACK

	return camera_depth.normalized()

func get_screen_horizontal_direction() -> Vector3:
	var camera: Camera3D = get_viewport().get_camera_3d()
	if camera == null:
		return Vector3.RIGHT

	var camera_right: Vector3 = camera.global_transform.basis.x
	camera_right.y = 0.0
	if camera_right.is_zero_approx():
		return Vector3.RIGHT

	return camera_right.normalized()

func get_horizontal_direction() -> Vector3:
	var angle_rad: float = deg_to_rad(target_rotation_y_deg)
	return Vector3.RIGHT.rotated(Vector3.UP, angle_rad)
