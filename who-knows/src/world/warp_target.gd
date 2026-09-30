class_name WarpTarget
extends RefCounted

## One place a warp can take you (docs/superpowers/specs/2026-09-28-warp-design.md
## §3.1): the star, a planet or a belt cluster, as data. SystemRecipe makes
## these; WarpPlan, Whereabouts, the map and the HUD read them.

enum Kind { STAR, PLANET, CLUSTER }

## Stable within a system: &"star", &"p3", &"belt_0.c1".
var id: StringName
var kind: Kind
var name: String
var point: UniversePoint
## The body's radius, or a cluster's reach.
var radius: float
## Where the body ends as far as the warp cares (§3.2): its well, or a
## cluster's reach. Distances are measured from here, not from the centre, so
## a big body and a small one are treated alike.
var edge: float
## A warp may start only beyond this, measured from `point`: edge + WARP_CLEAR.
var limit: float
## The belt a cluster lies on, its index in SystemRecipe.belts; -1 otherwise.
var belt := -1

## Its contact's id with the ship's sensors (BodyContacts).
func contact_id() -> StringName:
	return StringName(BodyContacts.PREFIX + String(id))
