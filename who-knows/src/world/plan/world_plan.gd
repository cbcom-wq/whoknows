class_name WorldPlan
extends RefCounted

## A desert world's plan: where its seas, ranges, plateaus and canyons lie
## (docs/superpowers/specs/2026-11-19-wadis-land-design.md). Built once from a
## recipe, on any thread, and never written after. This skeleton holds only the
## dials; later tasks fill in the rest.

var dials: PlanDials

static func build(recipe: WorldRecipe) -> WorldPlan:
	var p := WorldPlan.new()
	p.dials = PlanDials.roll(recipe.seed, recipe.radius_m)
	p.dials.pin(recipe.plan_pins)
	return p
