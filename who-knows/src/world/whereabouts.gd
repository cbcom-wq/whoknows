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
##
## It also knows which warp limits you are within
## (docs/superpowers/specs/2026-09-28-warp-design.md §8), apart from here():
## they are not places on the location line, but WarpPlan and the HUD's
## toasts ask about them.
##
## And which well you are in and how high you are over its ground (the world
## scale spec §7), for the speed limit: worked out when asked, from the
## world's own WorldTerrain, never cached between ticks.

signal entered(place: Place)
signal left(place: Place)
## Crossing a warp limit (the warp spec §8): kept apart from entered and left,
## which are the places on the location line.
signal limit_entered(place: Place)
signal limit_left(place: Place)

enum Kind { SYSTEM, BELT, NEAR, RING, LIMIT }

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

## The focus over one world's ground, worked out once (over()): what
## altitude(), air() and up() each give with that world the well.
class Over:
	var altitude: float
	var air: float
	var up: Vector3

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
## The air thickness (air()) at which the dust is gone (spec §6.1).
const DUST_GONE_AT := 0.2

var recipe: SystemRecipe
var universe: Universe

var _here: Array[Place] = []
var _limits: Array[Place] = []
var _since := INF
## One WorldTerrain per world, by body id, for this thread.
var _terrains := {}

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

## The warp targets whose limits you are within, by target id (the warp spec
## §8).
func limits() -> Array[StringName]:
	var out: Array[StringName] = []
	for p in _limits:
		out.append(StringName(String(p.id).trim_prefix("limit_")))
	return out

## True when no warp limit holds you: a warp may start here.
func warp_clear() -> bool:
	return _limits.is_empty()

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
	return out * clampf(1.0 - air() / DUST_GONE_AT, 0.0, 1.0)

## How thick the air is here, 0 to 1; 0 outside a world's well (spec §6.1).
## This, and over() from the same formula, is the one place the air at the
## focus is worked out.
func air() -> float:
	var b := well()
	if b == null or b.recipe == null:
		return 0.0
	return b.recipe.air_at(altitude())

## Away from the centre of the world whose well holds the focus; zero outside
## one (spec §6.1).
func up() -> Vector3:
	var b := well()
	if b == null or b.recipe == null:
		return Vector3.ZERO
	return _focus_point().minus(b.point).normalized()

## The sine of the sun's height over your horizon, -1 to 1; 1.0 outside a
## world's well (spec §6.1).
func sun_up() -> float:
	var b := well()
	if b == null or b.recipe == null:
		return 1.0
	var focus := _focus_point()
	return up().dot(recipe.star.point.minus(focus).normalized())

## The body whose well the focus is in, or null. Wells never overlap.
func well() -> SystemBody:
	var u := _focus_point()
	return well_at(recipe, u) if u != null else null

## How high the focus is over the ground of the well it is in; INF in none.
func altitude() -> float:
	var b := well()
	if b == null:
		return INF
	return _altitude_over(b, _focus_point().minus(b.point))

## The focus's altitude over `body`'s ground, the air there and the up, in one
## go with the well already in hand (`body`, from well()): for whoever wants
## all three every tick (BlowingSand), so the well is looked for once. Null
## with no focus, and for the star.
func over(body: SystemBody) -> Over:
	var u := _focus_point()
	if u == null or body == null or body.recipe == null:
		return null
	var local := u.minus(body.point)
	var out := Over.new()
	out.altitude = _altitude_over(body, local)
	out.air = body.recipe.air_at(out.altitude)
	out.up = local.normalized()
	return out

## How high `local` (from `b`'s centre) is over `b`'s ground.
func _altitude_over(b: SystemBody, local: Vector3) -> float:
	var t := terrain_of(b)
	return t.altitude_of(local) if t != null else local.length() - b.radius

## `body`'s ground, or null for the star.
func terrain_of(body: SystemBody) -> WorldTerrain:
	if body.recipe == null:
		return null
	if not _terrains.has(body.id):
		_terrains[body.id] = WorldTerrain.new(body.recipe)
	return _terrains[body.id]

## `body`'s drawn ground while it is near (BodyProxy.surface()), else null:
## through the StarSystem that made this node, its parent.
func surface_of(body: SystemBody) -> WorldSurface:
	var system := get_parent() as StarSystem
	var proxy := system.proxy(body.id) if system != null else null
	return proxy.surface() if proxy != null else null

static func well_at(system: SystemRecipe, u: UniversePoint) -> SystemBody:
	for b in system.bodies:
		if u.minus(b.point).length() <= b.well_radius:
			return b
	return null

func _focus_point() -> UniversePoint:
	if recipe == null or universe == null or not is_instance_valid(universe.focus) \
			or not universe.focus.is_inside_tree():
		return null
	return universe.to_universe(universe.focus.global_position)

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
	var limits_before := _limits
	_limits = limits_at(recipe, universe.to_universe(universe.focus.global_position), _limit_ids())
	for p in limits_before:
		if not _limits.any(func(q: Place) -> bool: return q.id == p.id):
			limit_left.emit(p)
	for p in _limits:
		if not limits_before.any(func(q: Place) -> bool: return q.id == p.id):
			limit_entered.emit(p)

func _ids() -> Dictionary:
	var out := {}
	for p in _here:
		out[p.id] = true
	return out

func _limit_ids() -> Dictionary:
	var out := {}
	for p in _limits:
		out[p.id] = true
	return out

## The warp limits `u` is within in `system`, each a LIMIT place named after
## its target. `inside` holds the ids you were already in.
static func limits_at(system: SystemRecipe, u: UniversePoint, inside: Dictionary = {}) -> Array[Place]:
	var out: Array[Place] = []
	for t in system.warp_targets():
		var id := StringName("limit_%s" % t.id)
		var margin := HYSTERESIS if inside.has(id) else 0.0
		if u.minus(t.point).length() <= t.limit + margin:
			out.append(Place.new(Kind.LIMIT, id, t.name))
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
