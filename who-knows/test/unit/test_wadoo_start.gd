extends GutTest

## The dev reset (F9) begins a new game over Wadoo's oasis (the owner's request,
## 2026-11-22): the starter at rest WADOO_START_OFF over the oasis's floor, in the
## real flight scene. The reset's flag is set as the reset sets it; saving is
## off, so no save is read or written.

const SCENE := "res://scenes/flight_test.tscn"

func test_a_reset_starts_a_new_game_over_the_oasis():
	var root: Node = load(SCENE).instantiate()
	root.save_enabled = false
	get_tree().set_meta(root.START_AT_WADOO, true)
	add_child(root)
	var place: PlaceDesign = root.places.design(WadooSource.PLACE)
	assert_not_null(place, "the oasis is on this system's world")
	var body: SystemBody = root.system.body(place.body_id)
	var floor_point: UniversePoint = PlaceField.ground_point(place, body, root.star_system.whereabouts.terrain_of(body))
	var hull: UniversePoint = root.get_node("Universe").to_universe(root.aboard.exterior.global_position)
	var gap: float = hull.minus(floor_point).length()
	assert_almost_eq(gap, root.WADOO_START_OFF, 1.0, "the starter hangs over the oasis's floor")
	assert_eq(root.aboard.exterior.linear_velocity, Vector3.ZERO, "and at rest")
	remove_child(root)
	root.free()
