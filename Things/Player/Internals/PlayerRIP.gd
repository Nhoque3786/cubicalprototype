# PlayerRIP.gd - Handles death checks, safe ground recording, and respawning for Cubic.
extends Node
class_name PlayerRIP

var player: Player

var _last_safe_position: Vector3 = Vector3.ZERO
var _has_safe_position: bool = false
var _last_safe_side: Hyprcore.WorldSide = Hyprcore.WorldSide.NORTH
var _grounded_timer: float = 0.0
var _is_dead: bool = false

func _ready() -> void:
	player = get_parent() as Player
	var spawn: Variant = _compute_safe_position()
	if spawn != null:
		_last_safe_position = spawn
		if player.hyprcore != null:
			_last_safe_side = player.hyprcore.current_side
		_has_safe_position = true

func _get_level_node() -> Node3D:
	if player.hyprcore != null:
		return player.hyprcore.level_node
	return null

func is_dead() -> bool:
	return _is_dead

func check_death() -> bool:
	if _is_dead:
		return true

	if player.global_position.y < player.death_y_threshold:
		trigger_death()
		return true
	return false

func update_safe_position(is_on_floor_now: bool, delta: float) -> void:
	if not is_on_floor_now:
		_grounded_timer = 0.0
		return

	_grounded_timer += delta
	if _grounded_timer < player.safe_ground_time:
		return

	var safe: Variant = _compute_safe_position()
	if safe == null:
		return  # no solid block centered beneath us -> keep the previous safe spot

	_last_safe_position = safe
	if player.hyprcore != null:
		_last_safe_side = player.hyprcore.current_side
	_has_safe_position = true


func _compute_safe_position() -> Variant:
	var level_node: Node3D = _get_level_node()
	var grid: GridMap = null
	if player.hyprcore != null:
		grid = player.hyprcore.get_grid_map()

	# No grid to snap against: just store the raw position (level-local if we can).
	if grid == null:
		if level_node != null:
			return level_node.to_local(player.global_position)
		return player.global_position

	var local_in_grid: Vector3 = grid.to_local(player.global_position)
	var floor_cell: Variant = _find_floor_cell(grid, local_in_grid)
	if floor_cell == null:
		return null

	var cell: Vector3i = floor_cell
	var cell_size: Vector3 = grid.cell_size
	# Center horizontally on the block; keep our actual standing height.
	local_in_grid.x = (float(cell.x) + 0.5) * cell_size.x
	local_in_grid.z = (float(cell.z) + 0.5) * cell_size.z

	var world_centered: Vector3 = grid.to_global(local_in_grid)
	if level_node != null:
		return level_node.to_local(world_centered)
	return world_centered

# Searches straight down from Cubic for the nearest solid gridmap cell, returning
# its Vector3i coords (or null if none within reach).
func _find_floor_cell(grid: GridMap, local_in_grid: Vector3) -> Variant:
	var start_cell: Vector3i = grid.local_to_map(local_in_grid)
	var cell_size_y: float = max(grid.cell_size.y, 0.001)
	var search_down: int = 4
	if player.hyprcore != null:
		search_down = int(ceil(player.hyprcore.max_floor_snap_height / cell_size_y)) + 2

	for dy in range(0, search_down + 1):
		var c: Vector3i = Vector3i(start_cell.x, start_cell.y - dy, start_cell.z)
		if grid.get_cell_item(c) != GridMap.INVALID_CELL_ITEM:
			return c
	return null

func trigger_death() -> void:
	if _is_dead:
		return
	_is_dead = true
	player.current_state = Player.State.DEAD
	player.velocity = Vector3.ZERO
	player.died.emit()
	_play_death_sequence()

func _play_death_sequence() -> void:
	if player.animated_sprite and player.animated_sprite.sprite_frames and player.animated_sprite.sprite_frames.has_animation(&"death_fall"):
		player.animated_sprite.speed_scale = 1.0
		player.animated_sprite.play(&"death_fall")

		var done := [false]
		var mark_done := func(): done[0] = true

		player.animated_sprite.animation_finished.connect(mark_done, CONNECT_ONE_SHOT)
		get_tree().create_timer(1.5).timeout.connect(mark_done, CONNECT_ONE_SHOT)

		while not done[0]:
			await get_tree().process_frame

		if player.animated_sprite.animation_finished.is_connected(mark_done):
			player.animated_sprite.animation_finished.disconnect(mark_done)

	await get_tree().create_timer(player.death_freeze_duration).timeout

	_respawn()

func _respawn() -> void:
	# Restore the perspective Cubic had safe ground on FIRST, so the level-local
	# safe position resolves to the correct global spot for that orientation.
	if _has_safe_position and player.hyprcore != null:
		player.hyprcore.set_world_side_instant(_last_safe_side)

	if _has_safe_position:
		var level_node: Node3D = _get_level_node()
		if level_node != null:
			# Convert the level-local safe spot back to where the platform is NOW,
			# accounting for any world rotations that happened since it was saved.
			player.global_position = level_node.to_global(_last_safe_position)
		else:
			player.global_position = _last_safe_position

	player.velocity = Vector3.ZERO
	_grounded_timer = 0.0
	_is_dead = false
	player.current_state = Player.State.IDLE

	# Snap to grid immediately so Cubic locks onto the platform's depth (Z) the
	# instant he respawns. We force grounded depth priority because is_on_floor()
	# is still stale right after the teleport; without it the snap would assume
	# airborne priority and float Cubic onto the wrong plane.
	if player.hyprcore != null:
		player.hyprcore.snap_to_grid(player, true, true)

	player.respawned.emit()
