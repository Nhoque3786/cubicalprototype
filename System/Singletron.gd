# Singletron: Handles music by itself 
extends Node

var player_a: AudioStreamPlayer
var player_b: AudioStreamPlayer
var active_player: AudioStreamPlayer

@export var default_fade_duration: float = 1.5
@export_range(0.0, 1.0) var music_volume: float = 1.0:
	set(value):
		music_volume = clamp(value, 0.0, 1.0)
		_update_active_volume()

func _ready() -> void:
	process_mode = PROCESS_MODE_ALWAYS
	
	player_a = AudioStreamPlayer.new()
	player_b = AudioStreamPlayer.new()
	
	player_a.bus = &"Music" if AudioServer.get_bus_index(&"Music") != -1 else &"Master"
	player_b.bus = &"Music" if AudioServer.get_bus_index(&"Music") != -1 else &"Master"
	
	add_child(player_a)
	add_child(player_b)
	
	active_player = player_a

func play_music(stream: AudioStream, fade_duration: float = default_fade_duration) -> void:
	if not stream:
		push_warning("Singletron: Attempted to play a null stream!")
		return
		
	if active_player.stream == stream and active_player.playing:
		return
		
	var next_player = player_b if active_player == player_a else player_a
	
	next_player.stream = stream
	next_player.volume_db = -80.0
	next_player.play()
	
	var tween = create_tween().set_parallel(true)
	
	tween.tween_property(next_player, "volume_db", linear_to_db(music_volume), fade_duration)\
		.set_trans(Tween.TRANS_CUBIC)\
		.set_ease(Tween.EASE_OUT)
		
	if active_player.playing:
		tween.tween_property(active_player, "volume_db", -80.0, fade_duration)\
			.set_trans(Tween.TRANS_CUBIC)\
			.set_ease(Tween.EASE_IN)
		tween.chain().tween_callback(active_player.stop)
		
	active_player = next_player

func stop_music(fade_duration: float = default_fade_duration) -> void:
	if not active_player.playing:
		return
		
	var tween = create_tween()
	tween.tween_property(active_player, "volume_db", -80.0, fade_duration)\
		.set_trans(Tween.TRANS_CUBIC)\
		.set_ease(Tween.EASE_IN)
	tween.tween_callback(active_player.stop)

func _update_active_volume() -> void:
	if active_player and active_player.playing:
		active_player.volume_db = linear_to_db(music_volume)
