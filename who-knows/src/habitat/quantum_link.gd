class_name QuantumLink
extends RefCounted

## QE between two stores without loss (habitat modules spec §2 row 9, §6.1):
## never more than `from` holds or `to` has room for.

static func move(from: QuantumStore, to: QuantumStore, n: int) -> int:
	var k := mini(mini(n, from.amount), to.room())
	if k <= 0:
		return 0
	from.drain(k, &"link")
	to.credit(k, &"link")
	return k

static func in_reach(base_at: Vector3, hull_at: Vector3) -> bool:
	return base_at.distance_to(hull_at) <= HabitatValues.LINK_REACH
