class_name WorldGravity
extends RefCounted

## What pulls where (desert-world spec §5.1). This is the one source: the
## flight computer, the avatar, loose items and the hostile pilot all ask it,
## and interiors never do. Only a world pulls (a body with a recipe); the
## star does not. A ring is not ground: inside a well but far above the air
## top, so a ship there feels the pull and nothing on foot does.
##
## The statics take a [UniversePoint]; the instance takes engine positions and
## converts them through the [Universe], so it survives the floating origin.

var system: SystemRecipe
var universe: Universe
var whereabouts: Whereabouts

func setup(p_system: SystemRecipe, p_universe: Universe, p_whereabouts: Whereabouts) -> void:
	system = p_system
	universe = p_universe
	whereabouts = p_whereabouts

## m/s², toward the well's centre: surface_gravity × (R / max(r, R))² inside a
## world's well; zero outside every well and in the star's.
static func vector(sys: SystemRecipe, u: UniversePoint) -> Vector3:
	var b := _world_at(sys, u)
	if b == null:
		return Vector3.ZERO
	var to_centre := b.point.minus(u)
	var r := to_centre.length()
	if r < 0.0001:
		return Vector3.ZERO
	var k := b.radius / maxf(r, b.radius)
	return to_centre / r * b.recipe.surface_gravity * k * k

## In a world's well and below its air top: where feet, loose items and NPCs
## feel gravity.
static func on_world(sys: SystemRecipe, u: UniversePoint) -> bool:
	var b := _world_at(sys, u)
	if b == null:
		return false
	return u.minus(b.point).length() - b.radius < b.recipe.air_top()

## The world whose well holds `u`, or null (the star's well counts as null).
static func _world_at(sys: SystemRecipe, u: UniversePoint) -> SystemBody:
	for b in sys.bodies:
		if b.recipe != null and u.minus(b.point).length() <= b.well_radius:
			return b
	return null

## The world whose well holds engine point `p`; null outside every well.
func body_at(p: Vector3) -> SystemBody:
	return _world_at(system, universe.to_universe(p))

func at(p: Vector3) -> Vector3:
	return vector(system, universe.to_universe(p))

func on_world_at(p: Vector3) -> bool:
	return on_world(system, universe.to_universe(p))

## Away from the centre; zero outside a world's well.
func up_at(p: Vector3) -> Vector3:
	var u := universe.to_universe(p)
	var b := _world_at(system, u)
	if b == null:
		return Vector3.ZERO
	return u.minus(b.point).normalized()

## Over the terrain, as [method Whereabouts.altitude] reads it; INF outside a
## world's well.
func altitude_at(p: Vector3) -> float:
	var u := universe.to_universe(p)
	var b := _world_at(system, u)
	if b == null:
		return INF
	var local := u.minus(b.point)
	var t := whereabouts.terrain_of(b) if whereabouts != null else null
	return t.altitude_of(local) if t != null else local.length() - b.radius

func surface_gravity_at(p: Vector3) -> float:
	var b := _world_at(system, universe.to_universe(p))
	return b.recipe.surface_gravity if b != null else 0.0
