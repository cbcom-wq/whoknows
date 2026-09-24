class_name SuitSounds
extends Node

## What you hear inside your helmet on a spacewalk (docs/superpowers/specs/
## 2026-09-24-airlock-design.md §6): your own slow breathing, the soft puff of
## your thrusters while they fire, and a chime the moment your ship starts
## moving or turning hard enough to leave you. On the Suit bus, which no
## pressure touches: space itself is silent.

const BREATH_DB := -16.0
const THRUSTER_DB := -12.0
const CHIME_DB := -8.0

var _avatar: Avatar
var _breath: AudioStreamPlayer
var _thruster: AudioStreamPlayer
var _chime: AudioStreamPlayer
var _alarm := false

func bind(avatar: Avatar) -> void:
	_avatar = avatar
	AudioBuses.ensure()
	_breath = _player("Breath", BREATH_DB)
	_thruster = _player("Thruster", THRUSTER_DB)
	_chime = _player("Chime", CHIME_DB)

func _physics_process(_delta: float) -> void:
	tick()

## Starts and stops the helmet's sounds to match the avatar now.
func tick() -> void:
	if _avatar == null:
		return
	var out := _avatar.mode == Avatar.Mode.SUIT
	_loop(_breath, out, &"breath")
	_loop(_thruster, out and _avatar.thrusting, &"thruster_puff")
	var alarm := false
	if out and is_instance_valid(_avatar.hull):
		var hull := _avatar.hull
		alarm = AirlockCycle.motion_warning(hull.linear_velocity.length(),
			rad_to_deg(hull.angular_velocity.length()))["level"] >= 2
	if alarm and not _alarm:
		var s := Synth.sound(&"warning_chime")
		if s != null:
			_chime.stream = s
			_chime.play()
	_alarm = alarm

func breathing() -> bool:
	return _breath.playing

func thrusting() -> bool:
	return _thruster.playing

func _loop(player: AudioStreamPlayer, on: bool, sound_name: StringName) -> void:
	if on and not player.playing:
		var s := Synth.sound(sound_name)
		if s != null:
			player.stream = s
			player.play()
	elif not on and player.playing:
		player.stop()

func _player(player_name: String, volume: float) -> AudioStreamPlayer:
	var p := AudioStreamPlayer.new()
	p.name = player_name
	p.bus = AudioBuses.SUIT
	p.volume_db = volume
	add_child(p)
	return p
