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

## The course (docs/superpowers/specs/2026-09-25-bridge-computer-design.md
## §4.3, §6.2): one per ship, kept here so every table and the HUD agree.
signal course_changed(id: StringName)
signal course_arrived(id: StringName)

const REFRESH_EVERY := 0.25
## Within this far of a big rock's surface, you have arrived.
const ARRIVE_ROCK := 1000.0

var universe: Universe
## The sensors' clock, seconds: pings are re-drawn by it.
var time := 0.0

## The contact the course is set to, by id; empty for none.
var course: StringName = &""
## The course that last cleared by arriving, until the next is set.
var last_arrived: StringName = &""

var _sources: Array = []
var _cache: Array[Contact] = []
## How far each cached contact was from the focus when it was read.
var _dist := PackedFloat32Array()
var _cache_range := 0.0
var _since := INF
var _course_since := 0.0

func add_source(source) -> void:
	if not _sources.has(source):
		_sources.append(source)

func sources() -> Array:
	return _sources

func _process(delta: float) -> void:
	time += delta
	_since += delta
	_course_since += delta
	if _course_since >= REFRESH_EVERY:
		check_course()

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
	_dist.resize(0)
	var focus := focus_point()
	if focus == null:
		# Nothing to read from yet: not an answer worth keeping.
		_since = INF
		return
	# Each distance worked out once, not once per comparison: at 30 km there
	# are hundreds of big rocks.
	var keyed: Array = []
	for source in _sources:
		for c: Contact in source.contacts(focus, range_m, time):
			keyed.append([c.point.minus(focus).length(), c])
	keyed.sort_custom(func(a: Array, b: Array) -> bool: return a[0] < b[0])
	_dist.resize(keyed.size())
	for i in keyed.size():
		_dist[i] = keyed[i][0]
		_cache.append(keyed[i][1])

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
	for i in _cache.size():
		if _dist[i] <= range_m + _cache[i].radius:
			out.append(_cache[i])
	return out

func set_course(id: StringName) -> void:
	if id == course:
		return
	course = id
	last_arrived = &""
	course_changed.emit(id)

func clear_course() -> void:
	if course.is_empty():
		return
	course = &""
	course_changed.emit(&"")

func forget_arrival() -> void:
	last_arrived = &""

## The course's contact wherever it is, through its source: null for none, or
## once it is gone.
func course_contact() -> Contact:
	return null if course.is_empty() else contact(course)

## Clears the course on arriving -- inside a region, or within ARRIVE_ROCK of
## an exact contact's surface -- or once its contact is gone (spec §6.2). A
## ping never arrives: you are still kilometres off. Run a few times a second.
func check_course() -> void:
	_course_since = 0.0
	if course.is_empty():
		return
	var focus := focus_point()
	if focus == null:
		return
	var c := course_contact()
	if c == null:
		clear_course()
		return
	var d := c.point.minus(focus).length()
	var arrived := false
	match c.precision:
		Contact.REGION:
			arrived = d <= c.radius
		Contact.EXACT:
			arrived = d - c.radius <= ARRIVE_ROCK
	if arrived:
		var id := course
		clear_course()
		last_arrived = id
		course_arrived.emit(id)
