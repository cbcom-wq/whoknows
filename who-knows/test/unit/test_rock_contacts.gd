extends GutTest

## Big rocks as sensor contacts (bridge computer spec §4.2): one exact contact
## per asteroid group's big rock within 30 km, from the recipe alone.

const SEED := 1337

func _ids(list: Array[Contact]) -> Array:
	var out := list.map(func(c: Contact) -> String: return String(c.id))
	out.sort()
	return out

func test_the_same_seed_gives_the_same_rocks():
	var focus := UniversePoint.at(0, 0, 0)
	var a := RockContacts.new(SEED).contacts(focus, RockContacts.RANGE, 0.0)
	var b := RockContacts.new(SEED).contacts(focus, RockContacts.RANGE, 0.0)
	assert_gt(a.size(), 0, "there are big rocks within 30 km")
	assert_eq(_ids(a), _ids(b))

func test_every_rock_is_exact_and_within_range():
	var focus := UniversePoint.at(0, 0, 0)
	var list := RockContacts.new(SEED).contacts(focus, 10000.0, 0.0)
	assert_gt(list.size(), 0)
	for c in list:
		assert_eq(c.kind, &"rock")
		assert_eq(c.label, "ROCK")
		assert_eq(c.precision, Contact.EXACT)
		assert_gt(c.radius, 50.0, "a big rock is 150-600 m across")
		assert_lte(c.point.minus(focus).length(), 10000.0)

## REACH is enough: a direct scan one region further finds nothing more
## within 30 km.
func test_no_big_rock_within_range_is_missed():
	var focus := UniversePoint.at(1234, -567, 8901)
	var found := _ids(RockContacts.new(SEED).contacts(focus, RockContacts.RANGE, 0.0))
	var recipe := AsteroidRecipe.new(SEED)
	var centre := AsteroidRecipe.cell_of(AsteroidRecipe.Tier.GIANT, focus)
	var reach := RockContacts.REACH + 1
	var expected := []
	for dx in range(-reach, reach + 1):
		for dy in range(-reach, reach + 1):
			for dz in range(-reach, reach + 1):
				var cell := centre + Vector3i(dx, dy, dz)
				var rocks := recipe.cell_rocks(AsteroidRecipe.Tier.GIANT, cell)
				if rocks.is_empty():
					continue
				var at := AsteroidRecipe.cell_corner(AsteroidRecipe.Tier.GIANT, cell).plus(rocks[0].local)
				if at.minus(focus).length() <= RockContacts.RANGE:
					expected.append(String(RockContacts.id_of(cell)))
	expected.sort()
	assert_eq(found, expected)

func test_a_rock_is_found_again_by_its_id():
	var focus := UniversePoint.at(0, 0, 0)
	var rocks := RockContacts.new(SEED)
	var first: Contact = rocks.contacts(focus, RockContacts.RANGE, 0.0)[0]
	var again := RockContacts.new(SEED).contact(first.id, focus, 0.0)
	assert_not_null(again, "a fresh reader finds it without a scan")
	assert_true(again.point.is_equal_approx(first.point))
	assert_null(rocks.contact(&"salvage:near", focus, 0.0), "not a rock's id")
	assert_null(rocks.contact(&"rock:nonsense", focus, 0.0))

## Crossing into the next region reads one slab and keeps the rest.
func test_moving_on_matches_a_fresh_read():
	var rocks := RockContacts.new(SEED)
	rocks.contacts(UniversePoint.at(0, 0, 0), RockContacts.RANGE, 0.0)
	var moved := UniversePoint.at(0, 0, 5000)
	var kept := rocks.contacts(moved, RockContacts.RANGE, 0.0)
	var fresh := RockContacts.new(SEED).contacts(moved, RockContacts.RANGE, 0.0)
	assert_eq(_ids(kept), _ids(fresh))
	var side := 2 * RockContacts.REACH + 1
	assert_eq(rocks.regions_read(), side * side * side, "one cube of regions is kept, not two")

func test_the_start_s_own_big_rock_is_close():
	var start := AsteroidRecipe.new(SEED).find_start()
	var near := RockContacts.new(SEED, start).contacts(start, 2000.0, 0.0)
	assert_gt(near.size(), 0, "the start is 700 m off a big rock's surface")

## Bridge computer spec §8: the HUD's contact marker leaves the big rocks to
## the canopy and the map; it marks what the senses pick up.
func test_the_hud_leaves_rocks_to_the_map():
	assert_false(ContactMarker.marks_kind(RockContacts.KIND))
	assert_true(ContactMarker.marks_kind(&"life"))
	assert_true(ContactMarker.marks_kind(&"salvage"))

## The flight scene registers the rocks with the ship's sensors.
func test_the_flight_scene_registers_the_rocks():
	var root: Node = load("res://scenes/flight_test.tscn").instantiate()
	add_child_autofree(root)
	var ship: Ship = root.get_node("Ship")
	assert_eq(ship.sensors.sources().filter(func(s): return s is RockContacts).size(), 1)
	var near := ship.sensors.contacts(2000.0).filter(func(c: Contact) -> bool: return c.kind == RockContacts.KIND)
	assert_gt(near.size(), 0, "the start's own big rock, 700 m off its surface")
