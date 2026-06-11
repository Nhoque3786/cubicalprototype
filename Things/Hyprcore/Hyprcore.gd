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
@export var snap_speed: float = 0
@export_range(32, 512) var search_depth_radius: int = 64
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
		target_rotation_y_deg = fposmod(target_rotation_y_deg - 90, 360.0)
		current_side = posmod(current_side - 1, 4) as WorldSide
		should_rotate = true
	elif event.is_action_pressed("rotate_left"):
		target_rotation_y_deg = fposmod(target_rotation_y_deg + 90, 360.0)
		current_side = posmod(current_side + 1, 4) as WorldSide
		should_rotate = true

	if should_rotate:
		rotate_world()

# Instantly forces the world to a given side with no tween/animation. Used by the
# respawn system so Cubic always comes back facing the exact perspective he had
# safe ground on, even if the world got spun during the death sequence.
func set_world_side_instant(side: WorldSide) -> void:
	if level_node == null:
		return
	current_side = side
	target_rotation_y_deg = float(side) * 90.0
	level_node.rotation.y = deg_to_rad(target_rotation_y_deg)

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

	# Pausing the world to avoid physics glitches mid-spin.
	if player != null:
		player.set_physics_process(false)
	level_node.process_mode = Node.PROCESS_MODE_DISABLED

	var tween: Tween = create_tween()
	tween.set_trans(transition_type)
	tween.set_ease(ease_type)

	var start_rad: float = level_node.rotation.y
	var target_rad: float = deg_to_rad(target_rotation_y_deg)
	var angle_diff: float = fposmod(target_rad - start_rad + PI, TAU) - PI

	tween.tween_property(level_node, "rotation:y", start_rad + angle_diff, rotation_duration)

	await tween.finished

	level_node.rotation.y = fposmod(level_node.rotation.y, TAU)
	target_rotation_y_deg = fposmod(target_rotation_y_deg, 360.0)

	# Re-enable everything
	level_node.process_mode = Node.PROCESS_MODE_INHERIT
	if player != null:
		player.set_physics_process(true)

	await get_tree().physics_frame

	# If the player is NOT a child of level_node, we must manually move them
	# to their new global position after the rotation.
	if player != null and player.get_parent() != level_node:
		if has_player_position:
			player.global_position = level_node.to_global(player_level_position)

	snap_to_grid(player, true)
	is_rotating = false
	rotation_finished.emit()

# Hyprgrid: Snapping player to grid to make 2D platforming possible on 3D.
# assume_grounded forces grounded depth priority even when is_on_floor() is stale
# (e.g. right after a respawn teleport), so we don't pick an airborne Z and float.
func snap_to_grid(body: CharacterBody3D, force_instant: bool = false, assume_grounded: bool = false) -> void:
	if body == null or not body.is_inside_tree():
		return

	var space_state: PhysicsDirectSpaceState3D = body.get_world_3d().direct_space_state
	var origin: Vector3 = body.global_position
	# Compute both directions once here so neither snap path queries the camera twice.
	var depth_direction: Vector3 = get_depth_direction()
	var horizontal_direction: Vector3 = get_screen_horizontal_direction()

	var target_pos: Vector3 = origin
	var has_target: bool = false

	var grid_snap: Variant = _get_grid_snap_position(body, origin, depth_direction, horizontal_direction, assume_grounded)
	if grid_snap != null:
		target_pos = origin + depth_direction * (grid_snap as float)
		has_target = true
	else:
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

		if not hits.is_empty():
			var closest_hit: Dictionary = hits[0]
			var min_dist: float = abs(depth_direction.dot(closest_hit["position"] - origin))
			for i in range(1, hits.size()):
				var d: float = abs(depth_direction.dot(hits[i]["position"] - origin))
				if d < min_dist:
					min_dist = d
					closest_hit = hits[i]

			var hit_normal: Vector3 = closest_hit.get("normal", Vector3.ZERO)
			var ray_target: Vector3 = closest_hit["position"] - hit_normal * 0.5
			var snap_distance: float = depth_direction.dot(ray_target - origin)

			target_pos = origin + depth_direction * snap_distance
			has_target = true

	if not has_target:
		return

	var delta: float = body.get_physics_process_delta_time()

	if force_instant or snap_speed <= 0.0:
		body.global_position = target_pos
	else:
		var current_depth: float = depth_direction.dot(body.global_position)
		var target_depth: float = depth_direction.dot(target_pos)
		var new_depth: float = lerp(current_depth, target_depth, 1.0 - exp(-snap_speed * delta))

		if abs(new_depth - target_depth) < 0.001:
			new_depth = target_depth

		body.global_position += depth_direction * (new_depth - current_depth)


func _get_grid_snap_position(body: CharacterBody3D, origin: Vector3, depth_direction: Vector3, horizontal_direction: Vector3, assume_grounded: bool = false) -> Variant:
	var active_grid: GridMap = get_grid_map()
	if active_grid == null:
		return null

	var grounded: bool = assume_grounded or body.is_on_floor()
	var priority: DepthPriority = grounded_depth_priority if grounded else airborne_depth_priority

	# Optimization: Work in local space
	var local_origin: Vector3 = active_grid.to_local(origin)
	var local_horiz_dir: Vector3 = active_grid.global_transform.basis.inverse() * horizontal_direction
	var local_depth_dir: Vector3 = active_grid.global_transform.basis.inverse() * depth_direction
	var cell_size: Vector3 = active_grid.cell_size

	var center_cell: Vector3i = active_grid.local_to_map(local_origin)
	var r_h: int = ceil(projected_snap_tolerance / min(cell_size.x, cell_size.z)) + 1
	var r_v: int = ceil(max_floor_snap_height / cell_size.y) + 2
	var r_d: int = search_depth_radius

	# Assign the large depth range and small horizontal range to the correct local
	# axes. After a 90-degree level rotation the GridMap's local X and Z swap their
	# screen roles, so hardcoding r_d→z and r_h→x breaks after the first spin.
	var x_is_depth: bool = abs(local_depth_dir.x) > abs(local_depth_dir.z)
	var r_x: int = r_d if x_is_depth else r_h
	var r_z: int = r_h if x_is_depth else r_d

	var best_depth_offset: float = 0.0
	var best_score: float = INF
	var best_depth_position: float = 0.0
	var best_depth_distance: float = INF
	var has_candidate: bool = false

	for x in range(center_cell.x - r_x, center_cell.x + r_x + 1):
		for y in range(center_cell.y - r_v, center_cell.y + 2):
			for z in range(center_cell.z - r_z, center_cell.z + r_z + 1):
				var cell := Vector3i(x, y, z)
				if active_grid.get_cell_item(cell) == GridMap.INVALID_CELL_ITEM:
					continue

				var local_cell_center: Vector3 = (Vector3(cell) + Vector3(0.5, 0.5, 0.5)) * cell_size

				var cell_top_y: float = local_cell_center.y + cell_size.y * 0.5
				var floor_distance: float = local_origin.y - cell_top_y
				if floor_distance < -0.1 or floor_distance > max_floor_snap_height:
					continue

				var horizontal_distance: float = abs(local_horiz_dir.dot(local_cell_center - local_origin))
				if horizontal_distance > projected_snap_tolerance:
					continue

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

	return best_depth_offset

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

func get_grid_map() -> GridMap:
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

