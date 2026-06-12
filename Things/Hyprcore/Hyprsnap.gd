# Hyprsnap: the grid/raycast snapping that makes 2D platforming possible on 3D.
# Stateless logic (no scene presence). It operates on a Hyprcore node, which
# supplies the tuning values, direction helpers and active GridMap. Kept apart
# from the rotation code (Hyprcube) so the heavy depth-search math stands alone.
class_name Hyprsnap

# assume_grounded forces grounded depth priority even when is_on_floor() is stale
# (e.g. right after a respawn teleport), so we don't pick an airborne Z and float.
static func snap_to_grid(core: Hyprcore, body: CharacterBody3D, force_instant: bool = false, assume_grounded: bool = false) -> void:
	if body == null or not body.is_inside_tree():
		return

	var space_state: PhysicsDirectSpaceState3D = body.get_world_3d().direct_space_state
	var origin: Vector3 = body.global_position
	# Compute both directions once here so neither snap path queries the camera twice.
	var depth_direction: Vector3 = core.get_depth_direction()
	var horizontal_direction: Vector3 = core.get_screen_horizontal_direction()

	var target_pos: Vector3 = origin
	var has_target: bool = false

	var grid_snap: Variant = _get_grid_snap_position(core, body, origin, depth_direction, horizontal_direction, assume_grounded)
	if grid_snap != null:
		target_pos = origin + depth_direction * (grid_snap as float)
		has_target = true
	else:
		var hits: Array[Dictionary] = []

		for v_off in core.vertical_offsets:
			var start: Vector3 = origin + Vector3(0, v_off, 0)
			for dir in [1.0, -1.0]:
				var target: Vector3 = start + depth_direction * dir * core.max_distance
				var query: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(start, target, core.collision_mask)
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

	if force_instant or core.snap_speed <= 0.0:
		body.global_position = target_pos
	else:
		var current_depth: float = depth_direction.dot(body.global_position)
		var target_depth: float = depth_direction.dot(target_pos)
		var new_depth: float = lerp(current_depth, target_depth, 1.0 - exp(-core.snap_speed * delta))

		if abs(new_depth - target_depth) < 0.001:
			new_depth = target_depth

		body.global_position += depth_direction * (new_depth - current_depth)


static func _get_grid_snap_position(core: Hyprcore, body: CharacterBody3D, origin: Vector3, depth_direction: Vector3, horizontal_direction: Vector3, assume_grounded: bool = false) -> Variant:
	var active_grid: GridMap = core.get_grid_map()
	if active_grid == null:
		return null

	var grounded: bool = assume_grounded or body.is_on_floor()
	var priority: Hyprcore.DepthPriority = core.grounded_depth_priority if grounded else core.airborne_depth_priority

	# Optimization: Work in local space (yay)
	var local_origin: Vector3 = active_grid.to_local(origin)
	var local_horiz_dir: Vector3 = active_grid.global_transform.basis.inverse() * horizontal_direction
	var local_depth_dir: Vector3 = active_grid.global_transform.basis.inverse() * depth_direction
	var cell_size: Vector3 = active_grid.cell_size

	var center_cell: Vector3i = active_grid.local_to_map(local_origin)
	var r_h: int = int(ceil(core.projected_snap_tolerance / min(cell_size.x, cell_size.z))) + 1
	var r_v: int = int(ceil(core.max_floor_snap_height / cell_size.y)) + 2
	var r_d: int = core.search_depth_radius

	# Map depth and horizontal search ranges to the correct local axes based on 
	# which axis (X or Z) aligns with the depth direction after rotation.
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
				if floor_distance < -0.1 or floor_distance > core.max_floor_snap_height:
					continue

				var horizontal_distance: float = abs(local_horiz_dir.dot(local_cell_center - local_origin))
				if horizontal_distance > core.projected_snap_tolerance:
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


static func _is_better_depth_candidate(
	priority: Hyprcore.DepthPriority,
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
		Hyprcore.DepthPriority.FRONTMOST:
			return depth_position > best_depth_position
		Hyprcore.DepthPriority.BEHINDMOST:
			return depth_position < best_depth_position
		_:
			return depth_distance < best_depth_distance
