extends GutTest

## GridHome (habitat modules spec §9.1): what a ship and a base share,
## extracted from Ship with no change to the ship.

var _root: Node
var _ship: Ship

func before_each():
	_root = load("res://scenes/flight_test.tscn").instantiate()
	add_child_autofree(_root)
	_ship = _root.get_node("Ship")

func test_a_ship_is_a_grid_home():
	assert_true(_ship is GridHome)
	assert_eq(_ship.interior.global_position, GridHome.INTERIOR_WORLD_BASE, "slot 0")
	assert_not_null(_ship.items)
	assert_false(_ship.airlocks.is_empty())

func test_its_airlocks_know_its_warp_through_the_home():
	for a: Airlock in _ship.airlocks.values():
		assert_false(a.warping())
	assert_false(_ship.is_warping())

func test_items_round_trip_through_the_home():
	var saved := _ship.items_to_dict()
	assert_gt(saved.size(), 0, "the starter is stocked")
	var item := _ship.restore_item(saved[0])
	assert_not_null(item)
	assert_eq(item.get_parent(), _ship.items)

func test_its_home_busy_is_calm_at_rest():
	assert_eq(_ship.home_busy(), "")
	assert_eq(_ship.busy(), "")
