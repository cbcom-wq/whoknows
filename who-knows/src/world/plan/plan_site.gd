class_name PlanSite
extends RefCounted

## A place the plan sets aside (docs/superpowers/specs/2026-11-19-wadis-land-design.md
## §5.5): where an oasis, a stretch of shore or a kept disc lies. Plain data,
## written while the plan is built and only read after.

## OASIS: low, level, dry open ground a wild oasis may be built on. SHORE: a flat
## ledge by the sea. KEPT: a hand-made place, the plan's kept disc round it.
enum Kind { OASIS, SHORE, KEPT }

var kind: Kind
## The site's middle, a unit direction.
var dir := Vector3.UP
## Metres: how far the site reaches from its middle.
var radius := 0.0
## Degrees, as PlaceDesign.heading: clockwise from north, seen from above, the
## way the site's layout faces (a shore site faces the water).
var heading := 0.0
## 0 for flat to 1 for rough: the plan's base's slope over the site's radius,
## WorldPlan.SITE_ROUGH_SLOPE (a rise of 1 in 10) being 1.
var level := 0.0
## Lower is better, within a kind.
var rank := 0.0
