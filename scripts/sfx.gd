class_name Sfx
extends Node
## Plays the game's sound effects. The sounds are synthesized by
## tools/generate_sounds.py; re-run it after changing them.

const SOUNDS := {
	&"pick": preload("res://audio/pick.wav"),
	&"invalid": preload("res://audio/invalid.wav"),
	&"pour": preload("res://audio/pour.wav"),
	&"cork": preload("res://audio/cork.wav"),
	&"victory": preload("res://audio/victory.wav"),
}
const VOICES := 6

var muted := false:
	set(value):
		muted = value
		AudioServer.set_bus_mute(AudioServer.get_bus_index(&"Master"), value)

var _players: Array[AudioStreamPlayer] = []
var _next := 0


func _ready() -> void:
	for i in VOICES:
		var player := AudioStreamPlayer.new()
		add_child(player)
		_players.append(player)


## Plays `sound` on the next free voice and returns its player.
func play(sound: StringName, pitch := 1.0, volume_db := 0.0) -> AudioStreamPlayer:
	var player := _players[_next]
	_next = (_next + 1) % VOICES
	player.stream = SOUNDS[sound]
	player.pitch_scale = pitch
	player.volume_db = volume_db
	player.play()
	return player


## Quickly fades out a player started by play(), if it is still playing `sound`.
func fade_out(player: AudioStreamPlayer, sound: StringName, seconds := 0.08) -> void:
	if not player.playing or player.stream != SOUNDS[sound]:
		return
	var tween := create_tween()
	tween.tween_property(player, "volume_db", -40.0, seconds)
	tween.tween_callback(player.stop)
