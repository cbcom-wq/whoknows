class_name SaveGate
extends RefCounted

## When the game may save (docs/superpowers/specs/2026-09-26-saving-design.md
## §4, §5): only in a calm moment, so a loaded game never resumes an action
## part-way through.
##
## Sources register a Callable returning why a save must wait -- "airlock
## cycling", "hull struck" -- or "" when calm. Calm means no source has been
## busy for CALM_FOR. tick() says when to save: every INTERVAL of play, at the
## first calm moment after; and once an action ends, if the last save is more
## than EDGE_AFTER old. Nothing saves for SETTLE after a load. Damage, when it
## exists, is one more source.
##
## Pure: flight_test.gd ticks it and does the saving.

const INTERVAL := 60.0
const CALM_FOR := 2.0
const EDGE_AFTER := 15.0
const SETTLE := 2.0

## Seconds since the last save (or since the game began).
var since_save := 0.0
## Seconds every source has been calm for.
var calm_time := 0.0
## Why the latest tick could not save, for the F3 readout: "" when calm.
var reason := ""

var _sources: Array[Callable] = []
var _settle_left := SETTLE
## True once something was busy since the last save, until the calm after it.
var _saw_action := false

func add_source(source: Callable) -> void:
	_sources.append(source)

## Why a save must wait right now, or "".
func busy() -> String:
	if _settle_left > 0.0:
		return "settling"
	for source in _sources:
		if not source.is_valid():
			continue
		var why: String = source.call()
		if why != "":
			return why
	return ""

## True once every source has been calm for CALM_FOR.
func is_calm() -> bool:
	return reason == "" and calm_time >= CALM_FOR

## Advances by `delta` seconds of play. True when a save should be written
## now; the caller writes it, then calls saved().
func tick(delta: float) -> bool:
	since_save += delta
	_settle_left = maxf(_settle_left - delta, 0.0)
	reason = busy()
	if reason != "":
		calm_time = 0.0
		if reason != "settling":
			_saw_action = true
		return false
	var was_calm := calm_time >= CALM_FOR
	calm_time += delta
	if calm_time < CALM_FOR:
		return false
	if since_save >= INTERVAL:
		return true
	if not was_calm and _saw_action:
		# The calm after an action: save now if the last save is old enough.
		_saw_action = false
		return since_save >= EDGE_AFTER
	return false

## A save was written.
func saved() -> void:
	since_save = 0.0
	_saw_action = false

## A game was just loaded or begun: nothing saves for SETTLE.
func settle() -> void:
	_settle_left = SETTLE
	calm_time = 0.0
