extends GutTest

## Which ship's hull is drawn as your own (docs/superpowers/specs/
## 2026-10-02-many-ships-design.md §4.2): yours on
## ExteriorBuilder.OWN_HULL_LAYER, which every window leaves out; any other's
## on layer 1, so you see it through your windows; and only your interior
## shown.

var _root: Node
var _ship: Ship

func before_each():
	_root = load("res://scenes/flight_test.tscn").instantiate()
	add_child_autofree(_root)
	_ship = _root.get_node("Ship")

## How many drawn pieces of the hull are on each set of layers.
func _layers() -> Dictionary:
	var out := {}
	for node in _ship.exterior.find_children("*", "GeometryInstance3D", true, false):
		var layers := (node as GeometryInstance3D).layers
		out[layers] = out.get(layers, 0) + 1
	return out

func test_a_ship_is_your_own_until_told_otherwise():
	assert_true(_ship.own)
	assert_gt(_layers().get(ExteriorBuilder.OWN_HULL_LAYER, 0), 0, "its skin is on the own layer")
	assert_true(_ship.interior.visible)

func test_another_ships_hull_is_on_the_worlds_layer():
	var own_pieces: int = _layers()[ExteriorBuilder.OWN_HULL_LAYER]
	var on_one: int = _layers().get(1, 0)
	_ship.set_own(false)
	var now := _layers()
	assert_eq(now.get(ExteriorBuilder.OWN_HULL_LAYER, 0), 0, "nothing left only on the own layer")
	assert_eq(now.get(1, 0), on_one + own_pieces, "every own piece moved to layer 1")
	assert_false(_ship.interior.visible, "its interior hides")

func test_and_back_again():
	var before := _layers()
	_ship.set_own(false)
	_ship.set_own(true)
	assert_eq(_layers(), before)
	assert_true(_ship.interior.visible)

func test_pieces_on_both_layers_stay_on_both():
	var both: int = _layers().get(1 | ExteriorBuilder.OWN_HULL_LAYER, 0)
	_ship.set_own(false)
	assert_eq(_layers().get(1 | ExteriorBuilder.OWN_HULL_LAYER, 0), both)

func test_a_rebuild_keeps_it():
	_ship.set_own(false)
	_ship.set_grid(_ship.grid, false)
	assert_eq(_layers().get(ExteriorBuilder.OWN_HULL_LAYER, 0), 0, "a rebuilt skin comes out on layer 1 too")
	assert_false(_ship.interior.visible)
