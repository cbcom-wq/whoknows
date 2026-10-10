class_name PlantSurface
extends RefCounted

## What planting asks of the ground (habitat modules spec §5.1), so Planting
## never sees a rock. RockSurface is a big rock in detail; a PlanetSurface is
## Planetfall's to add. This base is no ground at all.

## The ground's up at `point`: a rock's averaged normal there.
func up_at(_point: Vector3) -> Vector3:
	return Vector3.UP

## The ground along a ray: {position, normal}, or {} if it misses.
func cast(_from: Vector3, _dir: Vector3, _reach: float) -> Dictionary:
	return {}

## True if a box (centre and rotation `box`, extents `size`) would touch the
## ground, a boulder or a hull.
func blocked(_box: Transform3D, _size: Vector3) -> bool:
	return false

## True if it never moves. Only fixed ground takes a base.
func fixed() -> bool:
	return false

## The place a base on it belongs to, as RockHerds.site_of() names a rock.
func site_id() -> StringName:
	return &""

## The rock's id (AsteroidRock.id()), or zero for ground that is not a rock.
func rock() -> Vector4i:
	return Vector4i.ZERO

## What a drill finds in it: {seed, veined}.
func ore() -> Dictionary:
	return {"seed": 0, "veined": false}
