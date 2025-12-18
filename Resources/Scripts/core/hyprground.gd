## Makes 2D colision possible on 3D enviroment
## In a nutshell, it "teleports" the target to the closest ground on Z axis utilizing raycasts.
extends Node

@export var max_distance: float = 128

func snap(body: CharacterBody3D, distance: float) -> void:
	var space_state: PhysicsDirectSpaceState3D = body.get_world_3d().direct_space_state
	var origin: Vector3 = body.global_position

	var results: Array[Variant] = []

	# Check from center and slightly below (feet level) to catch platforms when falling
	var vertical_offsets: Array[Variant] = [0.0, -0.9]

	for v_offset in vertical_offsets:
		var start_point: Vector3 = origin + Vector3(0, v_offset, 0)

		for dir in [1, -1]:
			var target: Vector3 = start_point + Vector3(0, 0, dir * distance)
			var query: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(start_point, target)
			query.exclude = [body.get_rid()]
			var hit: Dictionary = space_state.intersect_ray(query)
			if hit:
				results.append(hit)

	# if nothing found, cancels to not frick things up
	if results.size() == 0:
		return

	# chooses the closest hit based on Z distance only
	var closest_hit = results[0]
	var min_z_dist = abs(origin.z - closest_hit.position.z)

	for hit in results:
		var z_dist = abs(origin.z - hit.position.z)
		if z_dist < min_z_dist:
			min_z_dist = z_dist
			closest_hit = hit

	# then teleports ONLY on Z axis
	# We align the player to the face of the block + 0.5 offset (assuming 1x1 grid logic)
	var target_z = closest_hit.position.z + (closest_hit.normal.z * 0.05)

	# Apply the Z change
	body.global_position.z = target_z
