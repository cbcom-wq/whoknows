extends GutTest

## The weapons station (ship weapons spec §3.5): a crew station of its own,
## sat in like one, its console's screen the target board.

func _bridge_grid() -> ShipGrid:
	var grid := ShipLibrary.read("res://test/fixtures/bridge/bridge.json")["grid"] as ShipGrid
	for c: Vector3i in grid.coords():
		if grid.get_block(c).block_id == &"crew_station":
			grid.get_block(c).block_id = WeaponValues.STATION
			break
	return grid

func test_the_block():
	var def := BlockCatalog.load_from_dir("res://data/blocks").get_def(WeaponValues.STATION)
	assert_not_null(def)
	assert_eq(def.occupancy, BlockDefinition.Occupancy.MOUNT)
	assert_almost_eq(def.power_draw, 0.3, 0.0001)
	assert_eq(ShipPlan.default_token(WeaponValues.STATION, 0), "Ws")

func test_it_is_a_seat_the_rules_check():
	assert_true(InteriorLayout.SEAT_IDS.has(WeaponValues.STATION))
	assert_true(InteriorLayout.QUIET_FIXTURES.has(WeaponValues.STATION))
	var found := ShipRules.check(_bridge_grid(), BlockCatalog.load_from_dir("res://data/blocks"))
	assert_eq(found["rules"], [], "the bridge fixture with a weapons station breaks nothing")

func test_the_board_stands_proud_of_the_screen_panel():
	# Along the face's normal (+z in the face frame) the board must lie clear
	# in front of the dark panel's front plane, or the text is hidden in it.
	var in_face := InteriorProps.STATION_FACE.affine_inverse() * WeaponsStation.board_frame()
	assert_almost_eq(in_face.origin.x, 0.0, 0.0001)
	assert_almost_eq(in_face.origin.y, 0.0, 0.0001)
	assert_gt(in_face.origin.z, InteriorProps.STATION_PANEL_FRONT + 0.005,
		"the board is %.4f m out of the face; the panel's front is %.4f" % [in_face.origin.z, InteriorProps.STATION_PANEL_FRONT])
	assert_true(in_face.basis.is_equal_approx(Basis.IDENTITY), "the board faces out of the screen")

func test_a_ship_builds_a_weapons_station_seat():
	var root: Node = load("res://scenes/flight_test.tscn").instantiate()
	root.starter_ship = "res://test/fixtures/bridge/bridge.json"
	add_child_autofree(root)
	var ship: Ship = root.get_node("Ship")
	ship.launch_blueprint = null
	ship.set_grid(_bridge_grid())
	var stations := ship.seats().filter(func(s: Seat) -> bool: return s is WeaponsStation)
	assert_eq(stations.size(), 1)
	if stations.size() == 1:
		assert_eq((stations[0] as WeaponsStation).prompt_text(), "Man the weapons")
		assert_not_null((stations[0] as WeaponsStation).board)