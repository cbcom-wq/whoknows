extends RefCounted

## For test fixtures that are not ships to fly (the bridge and the 400-block
## ship): they test rooms and size, so ShipRules' CANNOT_LIFT (LIFT_MARGIN at
## the heaviest planet) is dropped from what they expect. Never use it on a
## library ship or a grid derived from one.
static func without(rules: Array) -> Array:
	return rules.filter(func(r: Dictionary) -> bool: return r["code"] != &"CANNOT_LIFT")
