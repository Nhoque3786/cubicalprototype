# Hyprcube: Spins the world at your command.
# Stateless logic (no scene presence). It operates on a Hyprcore node, which holds
# the level reference, tuning, orientation state and rotation signals.
class_name Hyprcube

# Pauses the world, tweens the 90-degree spin, then re-snaps the player when done.
static func rotate_world(core: Hyprcore) -> void:
	if core.level_node == null:
		push_error("Hyprcube: level_node is null, cannot rotate!")
		return

	var player := core.get_player()
	var player_level_position: Vector3 = Vector3.ZERO
	var has_player_position := false
	if player != null:
		player_level_position = core.level_node.to_local(player.global_position)
		has_player_position = true

	# Pausing the world to avoid mishaps while rotating.
	if player != null:
		player.set_physics_process(false)
	core.level_node.process_mode = Node.PROCESS_MODE_DISABLED

	var tween: Tween = core.create_tween()
	tween.set_trans(core.transition_type)
	tween.set_ease(core.ease_type)

	var start_rad: float = core.level_node.rotation.y
	var target_rad: float = deg_to_rad(core.target_rotation_y_deg)
	var angle_diff: float = fposmod(target_rad - start_rad + PI, TAU) - PI

	tween.tween_property(core.level_node, "rotation:y", start_rad + angle_diff, core.rotation_duration)

	await tween.finished

	core.level_node.rotation.y = fposmod(core.level_node.rotation.y, TAU)
	core.target_rotation_y_deg = fposmod(core.target_rotation_y_deg, 360.0)

	# Un-pauses everything.
	core.level_node.process_mode = Node.PROCESS_MODE_INHERIT
	if player != null:
		player.set_physics_process(true)

	await core.get_tree().physics_frame

	# If the player is NOT a child of level_node, we must manually move them
	# to their new global position after the rotation.
	if player != null and player.get_parent() != core.level_node:
		if has_player_position:
			player.global_position = core.level_node.to_global(player_level_position)

	core.snap_to_grid(player, true)

# Snaps the world to a given side immediately, with no tween/animation.
static func set_world_side_instant(core: Hyprcore, side: Hyprcore.WorldSide) -> void:
	if core.level_node == null:
		return
	core.current_side = side
	core.target_rotation_y_deg = float(side) * 90.0
	core.level_node.rotation.y = deg_to_rad(core.target_rotation_y_deg)
