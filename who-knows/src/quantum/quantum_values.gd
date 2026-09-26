class_name QuantumValues
extends RefCounted

## Constants and functions that price the quantum economy (quantum energy
## spec §3.3, §4, §8).

## Boost's running cost, QE per second (spec §8.2).
const BOOST_COST := 5.0
## Making costs this many times an item's value (spec §3.3, §4.3).
const MAKE_MARKUP := 2
## The share of every thruster's force and every torque the core still
## delivers in low power (spec §8.3).
const LOW_POWER_AUTHORITY := 0.5

## What the machine charges to make one of these (spec §4.2, §4.3).
static func make_cost(def: ItemDefinition) -> int:
	return def.quantum_value * MAKE_MARKUP

## Everything the machine can make (spec §4.3): every catalogue item with a
## value, EVA tools left out, cheapest first. A cost tie (o2_tank/hand_lamp,
## toolbox/medkit in the spec's own table) breaks on id, ascending, so the
## order is a decision and not whatever the catalogue happened to enumerate.
static func makeable(catalog: ItemCatalog) -> Array[ItemDefinition]:
	var result: Array[ItemDefinition] = []
	for id in catalog.ids():
		var def := catalog.get_def(id)
		if def.eva_tool or def.quantum_value <= 0:
			continue
		result.append(def)
	result.sort_custom(func(a: ItemDefinition, b: ItemDefinition) -> bool:
		var cost_a := make_cost(a)
		var cost_b := make_cost(b)
		if cost_a != cost_b:
			return cost_a < cost_b
		return String(a.id) < String(b.id))
	return result
