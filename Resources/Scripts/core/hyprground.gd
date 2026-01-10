## Snapping system for the Z-axis.
## Since the world rotates, the player needs to be centered on the 1-unit blocks
## to ensure consistent movement along the X-axis.
extends Node

@export var max_distance: float = 128.0
@export_flags_3d_physics var collision_mask: int = 1
@export var vertical_offsets: Array[float] = [0.0, -0.9]


func snap(body: CharacterBody3D, distance: float) -> void:
	if body == null or not body.is_inside_tree():
		return

	var space_state: PhysicsDirectSpaceState3D = body.get_world_3d().direct_space_state
	var origin: Vector3 = body.global_position
	var results: Array[Dictionary] = []

	for v_offset in vertical_offsets:
		var start_point: Vector3 = origin
		start_point.y += v_offset

		for dir in [1.0, -1.0]:
			var target: Vector3 = start_point
			target.z += dir * distance
			
			var query: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(start_point, target, collision_mask)
			query.exclude = [body.get_rid()]
			
			var hit: Dictionary = space_state.intersect_ray(query)
			if not hit.is_empty():
				results.append(hit)

	if results.is_empty():
		return

	var closest_hit: Dictionary = results[0]
	var min_z_dist: float = abs(origin.z - closest_hit["position"].z)

	for i in range(1, results.size()):
		var hit: Dictionary = results[i]
		var z_dist: float = abs(origin.z - hit["position"].z)
		if z_dist < min_z_dist:
			min_z_dist = z_dist
			closest_hit = hit

	# Teleport ONLY on the Z axis, centering on the block.
	# We use the normal of the collision to know which side of the block we hit.
	# Since blocks are 1 unit wide, the center is 0.5 units away from the surface.
	var target_z: float = closest_hit["position"].z - (closest_hit["normal"].z * 0.5)
	body.global_position.z = target_z
