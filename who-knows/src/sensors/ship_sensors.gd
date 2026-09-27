class_name ShipSensors
extends Node

## One place every system asks what is out there (docs/superpowers/specs/
## 2026-09-25-bridge-computer-design.md §4.3; NPC foundation spec §22.3).
## Sources -- life signs now, salvage and rocks later -- each give Contacts;
## the sensors gather them, nearest first, refreshed a few times a second from
## where you are: the hull aboard, you on a spacewalk. The HUD and the bridge
## computer's map read the same answer.
##
## A source is anything with contacts(focus: UniversePoint, range_m: float,
## time: float) -> Array[Contact], and contact(id, focus, time) -> Contact or
## null.

const REFRESH_EVERY := 0.25

var universe: Universe
## The sensors' clock, seconds: pings are re-drawn by it.
var time := 0.0

var _sources: Array = []
var _cache: Array[Contact] = []
var _cache_range := 0.0
var _since := INF

func add_source(source) -> void:
	if not _sources.has(source):
		_sources.append(source)

func sources() -> Array:
	return _sources

func _process(delta: float) -> void:
	time += delta
	_since += delta

## Where the sensors are, in the universe; null with no focus.
func focus_point() -> UniversePoint:
	if universe == null or not is_instance_valid(universe.focus):
		return null
	return universe.to_universe(universe.focus.global_position)

## Every source's contacts within `range_m`, nearest first. Cached for
## REFRESH_EVERY seconds.
func contacts(range_m: float) -> Array[Contact]:
	if _since < REFRESH_EVERY and range_m <= _cache_range:
		return _filter(range_m)
	refresh(range_m)
	return _filter(range_m)

## Re-reads every source now.
func refresh(range_m: float) -> void:
	_since = 0.0
	_cache_range = range_m
	_cache.clear()
	var focus := focus_point()
	if focus == null:
		return
	for source in _sources:
		for c: Contact in source.contacts(focus, range_m, time):
			_cache.append(c)
	_cache.sort_custom(func(a: Contact, b: Contact) -> bool:
		return a.point.minus(focus).length_squared() < b.point.minus(focus).length_squared())

## The contact called `id`, looked up through its source, whatever the range.
func contact(id: StringName) -> Contact:
	var focus := focus_point()
	if focus == null:
		return null
	for source in _sources:
		var c: Contact = source.contact(id, focus, time)
		if c != null:
			return c
	return null

func _filter(range_m: float) -> Array[Contact]:
	var focus := focus_point()
	var out: Array[Contact] = []
	if focus == null:
		return out
	for c in _cache:
		if c.point.minus(focus).length() <= range_m + c.radius:
			out.append(c)
	return out
