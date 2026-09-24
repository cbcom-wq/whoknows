class_name AudioBuses
extends RefCounted

## The game's sound buses (docs/superpowers/specs/2026-09-24-airlock-design.md
## §6), made in code: SHIP for everything heard through air, with a low-pass
## filter the airlock turns down as the air goes, and SUIT for what you hear
## inside your own helmet, which no pressure touches.

const SHIP := &"Ship"
const SUIT := &"Suit"
const OPEN_CUTOFF := 20000.0
const VACUUM_CUTOFF := 300.0
const VACUUM_DB := -18.0

## Makes both buses if they are not there yet.
static func ensure() -> void:
	if AudioServer.get_bus_index(SHIP) == -1:
		var ship := _add(SHIP)
		var filter := AudioEffectLowPassFilter.new()
		filter.cutoff_hz = OPEN_CUTOFF
		AudioServer.add_bus_effect(ship, filter, 0)
	if AudioServer.get_bus_index(SUIT) == -1:
		_add(SUIT)

## How much air carries sound to the listener: 1 at normal pressure, 0 in
## vacuum, where the SHIP bus is muffled almost to nothing.
static func set_air(fraction: float) -> void:
	ensure()
	var f := clampf(fraction, 0.0, 1.0)
	var bus := AudioServer.get_bus_index(SHIP)
	var filter := AudioServer.get_bus_effect(bus, 0) as AudioEffectLowPassFilter
	filter.cutoff_hz = exp(lerpf(log(VACUUM_CUTOFF), log(OPEN_CUTOFF), f))
	AudioServer.set_bus_volume_db(bus, lerpf(VACUUM_DB, 0.0, f))

static func _add(bus_name: StringName) -> int:
	AudioServer.add_bus()
	var index := AudioServer.bus_count - 1
	AudioServer.set_bus_name(index, bus_name)
	AudioServer.set_bus_send(index, &"Master")
	return index
