class_name WindSound
extends Node

## Wind, heard on the way down and on the ground (desert world spec §6.4; the
## style guide's §2.9, "Space is silent", changes in Task 12). Seated in a ship
## it comes through the hull on the Ship bus; on foot on a world it is in the
## helmet on the Suit bus; on a spacewalk, in a ring, or in space, where
## `Whereabouts.air()` is 0, there is none. Exactly one of the two plays, so
## stepping out hands it over with no gap and no doubling.

enum Ear { NONE, HULL, HELMET }

## The level on still air at gust 1, and the speed (m/s) at which wind alone
## reaches full level.
const AMBIENT := 0.3
const FULL_SPEED := 150.0
const HULL_DB := -14.0
const HELMET_DB := -8.0
## Below this level both players stop.
const SILENT_BELOW := 0.003

var _hull: AudioStreamPlayer
var _helmet: AudioStreamPlayer
var _time := 0.0

func _ready() -> void:
	AudioBuses.ensure()
	_hull = _player("Hull", AudioBuses.SHIP)
	_helmet = _player("Helmet", AudioBuses.SUIT)

## 0..1: the air times a steady breath of wind plus the speed through it.
static func level(air: float, speed: float, gust: float) -> float:
	return clampf(air * (AMBIENT * gust + speed / FULL_SPEED), 0.0, 1.0)

## A slow, bounded swell, 0.5..1.
static func gust(t: float) -> float:
	return 0.75 + 0.15 * sin(TAU * t / 11.0) + 0.10 * sin(TAU * t / 4.3 + 1.3)

## Where the wind is heard: in the helmet on a world's ground, through the hull
## when seated or standing in a ship, nowhere on a spacewalk.
static func ear(mode: Avatar.Mode, in_ship: bool) -> Ear:
	if mode == Avatar.Mode.FIELD:
		return Ear.HELMET
	if mode == Avatar.Mode.PLATING and in_ship:
		return Ear.HULL
	return Ear.NONE

func hull_playing() -> bool:
	return _hull.playing

func helmet_playing() -> bool:
	return _helmet.playing

## One frame: `speed` is the ship's through the air for HULL, yours for HELMET.
func tick(air: float, speed: float, which: Ear, delta: float) -> void:
	_time += delta
	var g := gust(_time)
	var lvl := level(air, speed, g)
	if which == Ear.NONE or lvl < SILENT_BELOW:
		_play(_hull, false, &"wind_hull")
		_play(_helmet, false, &"wind")
		return
	var hull := which == Ear.HULL
	_play(_hull, hull, &"wind_hull")
	_play(_helmet, not hull, &"wind")
	if hull:
		_hull.volume_db = linear_to_db(lvl) + HULL_DB
	else:
		_helmet.volume_db = linear_to_db(lvl) + HELMET_DB
		_helmet.pitch_scale = 0.9 + 0.2 * g

func _play(player: AudioStreamPlayer, on: bool, sound_name: StringName) -> void:
	if on and not player.playing:
		var s := Synth.sound(sound_name)
		if s != null:
			player.stream = s
			player.play()
	elif not on and player.playing:
		player.stop()

func _player(player_name: String, bus: StringName) -> AudioStreamPlayer:
	var p := AudioStreamPlayer.new()
	p.name = player_name
	p.bus = bus
	add_child(p)
	return p
