class_name Bases
extends Node

## Every base in the game (docs/superpowers/specs/
## 2026-09-26-habitat-modules-design.md §9.1, §9.3): the one place that knows
## them. Each is a BaseSite always, and a Base node only while awake: within
## WAKE_AT of the universe's focus, in the current system, with an interior
## slot from the pool it shares with the fleet. Past SLEEP_AT it captures
## what is in it into its site and is freed, slot and all, as a sleeping ship
## is held (many ships spec §5.1). The base you are in never sleeps.

signal joined(base: Base)
signal left(base: Base)

const GROUP := &"bases"
const CHECK_EVERY := 1.0

## Where base nodes go (the flight scene), and their outside.
var home: Node
var outside: Node3D
var universe: Universe
var slots: InteriorSlots
## The current star system, by seed: only its bases wake.
var system := 0
## Seconds of play (the flight scene's play_time): the drills' clock.
var clock: Callable
## The base you are in, or whose suit you wear: never asleep. A Callable
## returning a Base, or null.
var inside: Callable
## The nearest awake ship to a point (engine space), or null: the quantum link's other end.
var ship_near: Callable
## The number the next base's name takes (Base1, Base2 ...); it only goes up.
var next_number := 1

var _sites: Dictionary = {}   # StringName -> BaseSite
var _awake: Dictionary = {}   # StringName -> Base
var _check_in := 0.0

func _ready() -> void:
	add_to_group(GROUP)

func _physics_process(delta: float) -> void:
	_check_in -= delta
	if _check_in > 0.0:
		return
	_check_in = CHECK_EVERY
	check_sleep()

func sites() -> Array[BaseSite]:
	var out: Array[BaseSite] = []
	for s: BaseSite in _sites.values():
		out.append(s)
	return out

func awake() -> Array[Base]:
	var out: Array[Base] = []
	for b: Base in _awake.values():
		out.append(b)
	return out

func named(id: StringName) -> Base:
	return _awake.get(id)

func site_named(id: StringName) -> BaseSite:
	return _sites.get(id)

## The base on the ground `site_id` in this system, or null.
func on(site_id: StringName) -> BaseSite:
	for s: BaseSite in _sites.values():
		if s.system == system and s.site_id == site_id:
			return s
	return null

## A site's frame in engine space.
func frame_of(site: BaseSite) -> Transform3D:
	return Transform3D(site.turn, universe.to_engine(site.at))

## The awake base whose frame is nearest `point`, or null.
func nearest(point: Vector3) -> Base:
	var best: Base = null
	for b: Base in _awake.values():
		if best == null or b.exterior.global_position.distance_to(point) \
				< best.exterior.global_position.distance_to(point):
			best = b
	return best

## Plants a module where `r` fits on `surface` (§5.3): a hub on bare ground
## founds a base; anything else joins the ground's base. Returns the base,
## which is unfolding the new module, or null if it could not wake.
func plant(kind: StringName, r: Planting.Result, surface: PlantSurface) -> Base:
	var site := on(surface.site_id())
	if site == null:
		site = BaseSite.new()
		site.id = StringName("Base%d" % next_number)
		next_number += 1
		site.system = system
		site.at = universe.to_universe(r.frame.origin)
		site.turn = r.frame.basis
		site.rock = surface.rock()
		site.site_id = surface.site_id()
		var first := site.add(kind, r.cell, r.turns, r.legs)
		_on_planted(site, first, surface)
		_sites[site.id] = site
		return _wake(site, first)
	var i := site.add(kind, r.cell, r.turns, r.legs)
	_on_planted(site, i, surface)
	var base := named(site.id)
	if base != null:
		base.begin_unfold(i)
	return base

## What a new module of `site` keeps from the ground it was planted on: a
## drill, its rock's ore and the time it started (§6.2).
func _on_planted(site: BaseSite, index: int, surface: PlantSurface) -> void:
	if site.modules[index]["kind"] == ModuleCatalog.DRILL:
		site.modules[index]["drill"] = DrillYield.fresh(surface.ore(), clock.call() if clock.is_valid() else 0.0)

## True if a drill on `site_id`'s base has run QUIET_AFTER and stands within
## QUIET_RADIUS of `point` (engine space): its herds have moved away (§8.4).
func quiet(site_id: StringName, point: Vector3) -> bool:
	var site := on(site_id)
	if site == null:
		return false
	var frame := frame_of(site)
	for i in site.drills():
		var drill: Dictionary = site.modules[i]["drill"]
		if float(drill.get("ran", 0.0)) < HabitatValues.QUIET_AFTER:
			continue
		if (frame * site.centre_of(i)).distance_to(point) <= HabitatValues.QUIET_RADIUS:
			return true
	return false

func wake(id: StringName) -> Base:
	if _awake.has(id):
		return _awake[id]
	var site: BaseSite = _sites.get(id)
	return _wake(site, -1) if site != null else null

func _wake(site: BaseSite, unfolding: int) -> Base:
	var slot := slots.claim()
	if slot < 0:
		# Stays asleep, whole, and tries again at the next check; no log, it would repeat every second.
		return null
	var base := Base.make(site, slot, NodePath("../%s" % home.get_path_to(outside)), unfolding)
	base.clock = clock
	home.add_child(base)
	base.place(frame_of(site))
	base.restore_inside()
	_awake[site.id] = base
	joined.emit(base)
	return base

func sleep(id: StringName) -> void:
	var base: Base = _awake.get(id)
	if base == null:
		return
	base.capture()
	_awake.erase(id)
	slots.release(base.interior_slot)
	left.emit(base)
	base.get_parent().remove_child(base)
	base.queue_free()

## Sleeps every awake base past SLEEP_AT of the focus that is calm and not
## yours, and wakes every sleeping one of this system inside WAKE_AT.
func check_sleep() -> void:
	if universe == null or not is_instance_valid(universe.focus):
		return
	var here := universe.to_universe(universe.focus.global_position)
	var mine: Base = inside.call() if inside.is_valid() else null
	for site: BaseSite in _sites.values():
		var base: Base = _awake.get(site.id)
		if site.system != system:
			if base != null and base != mine:
				sleep(site.id)
			continue
		var d := site.at.minus(here).length()
		if base != null:
			if base != mine and d > HabitatValues.SLEEP_AT and base.busy() == "":
				sleep(site.id)
		elif d < HabitatValues.WAKE_AT:
			wake(site.id)

## Why a save must wait on a base, or "".
func busy() -> String:
	for base: Base in _awake.values():
		var why := base.busy()
		if why != "":
			return why
	return ""

## Every base's part of a save (§11.1): awake ones captured first.
func to_dict() -> Dictionary:
	for base: Base in _awake.values():
		base.capture()
	var out := []
	for site: BaseSite in _sites.values():
		out.append(site.to_dict())
	return {"next": next_number, "sites": out}

## Takes a saved game's bases. Call before the first check_sleep: none is awake.
func from_dict(d: Dictionary) -> void:
	next_number = maxi(int(d.get("next", 1)), 1)
	_sites.clear()
	for part in d.get("sites", []):
		if part is Dictionary:
			var site := BaseSite.from_dict(part)
			if not site.modules.is_empty():
				_sites[site.id] = site
