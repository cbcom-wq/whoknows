class_name Whereabouts
extends Node

## Where you are in the system (the system skeleton spec §8): in a planet's
## ring, near a moon, near a planet or the star, in a belt, or just in the
## system. Worked out from the focus's UniversePoint and the recipe ten times a
## second. Everything that behaves differently by place asks this, never works
## places out for itself (star systems spec §3.1).
##
## You enter a place at its edge and leave it HYSTERESIS beyond, so nothing
## flickers along a border.

signal entered(place: Place)
signal left(place: Place)

enum Kind { SYSTEM, BELT, NEAR, RING }

## One place you can be.
class Place:
	var kind: Kind
	## &"system", &"belt_0", &"near_p3", &"ring_p3"
	var id: StringName
	var name: String

	func _init(p_kind: Kind, p_id: StringName, p_name: String) -> void:
		kind = p_kind
		id = p_id
		name = p_name

## How often it looks, seconds.
const EVERY := 0.1
## You leave a place this far beyond its edge.
const HYSTERESIS := 100.0
## Within this of a ring's plane, inside its annulus, you are in the ring:
## among its rocks, not only its slab.
const RING_NEAR := 500.0
## How much dust shows (SpaceDust.density), by where you are.
const DUST_OPEN := 0.25
const DUST_NEAR := 0.5
const DUST_THICK := 1.0

var recipe: SystemRecipe
var universe: Universe

var _here: Array[Place] = []
var _since := INF

func setup(p_recipe: SystemRecipe, p_universe: Universe) -> void:
	recipe = p_recipe
	universe = p_universe
	name = "Whereabouts"
	look()

func _physics_process(delta: float) -> void:
	_since += delta
	if _since >= EVERY:
		look()

## Where you are, innermost first; the system itself is always last.
func here() -> Array[Place]:
	return _here

## True while you are in the place called `id`.
func is_in(id: StringName) -> bool:
	return _here.any(func(p: Place) -> bool: return p.id == id)

## Where you are, outermost first: KESTREL › near KORVA-7 › in the ring.
func text() -> String:
	var parts := PackedStringArray()
	for i in range(_here.size() - 1, -1, -1):
		parts.append(_here[i].name)
	return " › ".join(parts)

## How much dust shows here, 0 to 1.
func dust() -> float:
	var out := DUST_OPEN
	for p in _here:
		match p.kind:
			Kind.BELT, Kind.RING:
				out = maxf(out, DUST_THICK)
			Kind.NEAR:
				out = maxf(out, DUST_NEAR)
	return out

## Looks now, and tells anyone listening what changed.
func look() -> void:
	_since = 0.0
	if recipe == null or universe == null or not is_instance_valid(universe.focus) \
			or not universe.focus.is_inside_tree():
		return
	var now := places_at(recipe, universe.to_universe(universe.focus.global_position), _ids())
	var before := _here
	_here = now
	for p in before:
		if not now.any(func(q: Place) -> bool: return q.id == p.id):
			left.emit(p)
	for p in now:
		if not before.any(func(q: Place) -> bool: return q.id == p.id):
			entered.emit(p)

func _ids() -> Dictionary:
	var out := {}
	for p in _here:
		out[p.id] = true
	return out

## Where `u` is in `system`, innermost first. `inside` holds the ids of the
## places you were already in, which you leave only HYSTERESIS beyond.
static func places_at(system: SystemRecipe, u: UniversePoint, inside: Dictionary = {}) -> Array[Place]:
	var out: Array[Place] = []
	var bodies: Array[SystemBody] = []
	for b in system.bodies:
		var id := StringName("near_%s" % b.id)
		var margin := HYSTERESIS if inside.has(id) else 0.0
		if u.minus(b.point).length() <= b.neighbourhood + margin:
			bodies.append(b)
	# Rings first, then moons, then planets and the star.
	for b in bodies:
		if b.ring == null:
			continue
		var id := StringName("ring_%s" % b.id)
		var margin := HYSTERESIS if inside.has(id) else 0.0
		if _in_ring(b.ring, u, margin):
			out.append(Place.new(Kind.RING, id, "in the ring"))
	for kind in [SystemBody.Kind.MOON, SystemBody.Kind.PLANET, SystemBody.Kind.STAR]:
		for b in bodies:
			if b.kind == kind:
				out.append(Place.new(Kind.NEAR, StringName("near_%s" % b.id), "near %s" % b.name))
	for k in system.belts.size():
		var belt := system.belts[k]
		var id := StringName("belt_%d" % k)
		var margin := HYSTERESIS if inside.has(id) else 0.0
		if _in_belt(belt, u, margin):
			out.append(Place.new(Kind.BELT, id, belt_name(system, k)))
	out.append(Place.new(Kind.SYSTEM, &"system", system.name))
	return out

## What belt `k` is called: the belt, or the inner and the outer belt.
static func belt_name(system: SystemRecipe, k: int) -> String:
	if system.belts.size() < 2:
		return "in the belt"
	var inner := 0
	for j in system.belts.size():
		if system.belts[j].radius < system.belts[inner].radius:
			inner = j
	return "in the inner belt" if k == inner else "in the outer belt"

static func _in_belt(belt: AsteroidShapes.Belt, u: UniversePoint, margin: float) -> bool:
	var p := u.minus(belt.centre)
	var h := p.dot(belt.normal)
	var r := (p - belt.normal * h).length()
	return Vector2((r - belt.radius) / (belt.half_width + margin), h / (belt.half_thickness + margin)).length() <= 1.0

static func _in_ring(ring: AsteroidShapes.Ring, u: UniversePoint, margin: float) -> bool:
	var p := u.minus(ring.centre)
	var h := p.dot(ring.normal)
	var r := (p - ring.normal * h).length()
	return r >= ring.inner - margin and r <= ring.outer + margin and absf(h) <= RING_NEAR + margin
