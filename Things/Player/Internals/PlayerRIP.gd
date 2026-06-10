# PlayerRIP.gd - Handles death checks, safe ground recording, and respawning for Cubic.
extends Node
class_name PlayerRIP

var player: Player

var _last_safe_position: Vector3 = Vector3.ZERO
var _grounded_timer: float = 0.0
var _is_dead: bool = false

func _ready() -> void:
	player = get_parent() as Player

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
	else:
		_grounded_timer += delta
		if _grounded_timer >= player.safe_ground_time:
			_last_safe_position = player.global_position

func trigger_death() -> void:
	if _is_dead:
		return
	_is_dead = true
	player.current_state = Player.State.DEAD
	player.velocity = Vector3.ZERO
	player.died.emit()
	_play_death_sequence()

func _play_death_sequence() -> void:
	if player.animated_sprite and player.animated_sprite.sprite_frames.has_animation(&"death_fall"):
		player.animated_sprite.speed_scale = 1.0
		player.animated_sprite.play(&"death_fall")
		await player.animated_sprite.animation_finished

	await get_tree().create_timer(player.death_freeze_duration).timeout

	_respawn()

func _respawn() -> void:
	if _last_safe_position != Vector3.ZERO:
		player.global_position = _last_safe_position

	player.velocity = Vector3.ZERO
	_grounded_timer = 0.0
	_is_dead = false
	player.current_state = Player.State.IDLE

	# NOTE: We intentionally do NOT call snap_to_grid here.
	# Right after teleporting, is_on_floor() is stale (still false),
	# which causes snap_to_grid to use airborne depth priority and pick
	# the wrong Z position, floating the player in the air.
	# The physics_process snap runs every frame and will correct it naturally.

	player.respawned.emit()
