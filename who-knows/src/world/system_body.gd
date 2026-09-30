class_name SystemBody
extends RefCounted

## One body of a star system, as data (the system skeleton spec §4.5): the
## star, a planet or a moon. No node: SystemRecipe makes these, StarSystem
## draws them.

enum Kind { STAR, PLANET, MOON }

## Stable within a system: &"star", &"p3", &"p3.m1".
var id: StringName
var kind: Kind
var name: String
var point: UniversePoint
var radius: float
## Where its gravity will reach (Planetfall §7.1).
var well_radius: float
## The space that belongs to it (§4.2): no other body's overlaps it.
var neighbourhood: float
## A warp may start only beyond this, from its centre (the warp spec §3.2):
## its well plus WARP_CLEAR, and never inside its neighbourhood. 0 for a moon,
## which is not a warp target.
var warp_limit := 0.0
## What its seed decided; null for the star.
var recipe: WorldRecipe
## A moon's planet; &"" otherwise.
var parent_id: StringName = &""
## Its ring, or null.
var ring: AsteroidShapes.Ring
## The star's palette index into SpacePalette.STARS; -1 for anything else.
var star_palette := -1
## Its own seed: what its look draws from.
var seed: int

func _to_string() -> String:
	return "%s %s r=%.0f" % [id, name, radius]
