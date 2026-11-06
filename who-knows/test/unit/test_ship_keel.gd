extends GutTest

## A ship knows how deep its keel sits below the hull's origin, so the flight
## computer can level it by the height of its bottom, not its middle (desert-world
## spec §5.2).

var _root: Node
var _starter: Ship

func before_each():
	_root = load("res://scenes/flight_test.tscn").instantiate()
	add_child_autofree(_root)
	_starter = _root.get_node("Ship")

func test_starter_keel_is_its_lowest_cell_bottom():
	# starter.json's lowest row is y = -1: centre -2 m, bottom face -3 m in the grid's frame.
	# The exterior's colliders sit at ShipGrid.cell_center in the hull body's own frame (the
	# custom centre of mass moves no origin), so the grid's origin is the hull's origin.
	assert_almost_eq(_starter.keel_depth(), 3.0, 0.01)

## ...and how deep the plane it stands on is: its landing legs' feet, 0.4 m
## under the keel (Task 15). The flight computer measures altitude from there.
func test_the_flight_computer_is_told_where_it_stands():
	assert_almost_eq(_starter.stance_depth(), 3.4, 0.01)
	assert_almost_eq(_starter.flight_computer.keel_depth, _starter.stance_depth(), 0.001)

func test_a_rebuild_keeps_it_told():
	_starter.flight_computer.keel_depth = 0.0
	_starter._rebuild_everything()
	assert_almost_eq(_starter.flight_computer.keel_depth, 3.4, 0.01)
