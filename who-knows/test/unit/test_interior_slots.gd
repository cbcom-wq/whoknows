extends GutTest

## One pool of interior slots for ships and bases (habitat modules spec §9.3).

func test_claims_the_lowest_free_slot():
	var pool := InteriorSlots.new()
	assert_eq(pool.claim(), 0)
	assert_eq(pool.claim(), 1)
	pool.release(0)
	assert_eq(pool.claim(), 0, "a released slot is reused")

func test_take_holds_a_given_slot_once():
	var pool := InteriorSlots.new()
	assert_true(pool.take(3))
	assert_false(pool.take(3), "already held")
	assert_false(pool.take(-1))
	assert_false(pool.take(InteriorSlots.MAX))
	assert_true(pool.is_held(3))
	assert_eq(pool.claim(), 0)

func test_the_pool_runs_out_at_max():
	var pool := InteriorSlots.new()
	for i in InteriorSlots.MAX:
		assert_eq(pool.claim(), i)
	assert_eq(pool.claim(), -1, "full")
	assert_eq(pool.free_count(), 0)

func test_the_fleet_draws_from_its_pool():
	var root: Node = load("res://scenes/flight_test.tscn").instantiate()
	add_child_autofree(root)
	var fleet: Fleet = root.fleet
	assert_true(fleet.slots.is_held(0), "the starter holds slot 0")
	var other := fleet.slots.claim()
	assert_eq(other, 1, "something else took slot 1")
	var starter: Ship = root.get_node("Ship")
	var ship := fleet.spawn(root._starter_grid(), starter.exterior.global_transform.translated(Vector3(300, 0, 0)))
	assert_eq(ship.interior_slot, 2, "the ship takes the next free one")
	fleet.remove(ship)
	await wait_process_frames(1)
	assert_false(fleet.slots.is_held(2), "removing a ship frees its slot")
