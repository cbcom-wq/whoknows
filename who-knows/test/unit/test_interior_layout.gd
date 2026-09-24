extends GutTest

var _cat: BlockCatalog
var _grid: ShipGrid

func before_each():
	_cat = BlockCatalog.new()
	for id in [&"hull", &"canopy"]:
		_cat.register(_def(id, BlockDefinition.Occupancy.SOLID))
	for id in [&"deck", &"airlock"]:
		_cat.register(_def(id, BlockDefinition.Occupancy.DECK))
	for id in InteriorLayout.ROOM_IDS:
		_cat.register(_def(id, BlockDefinition.Occupancy.DECK))
	_cat.register(_def(&"seat", BlockDefinition.Occupancy.MOUNT))
	_grid = ShipGrid.new()

func _def(id: StringName, occ: BlockDefinition.Occupancy) -> BlockDefinition:
	var d := BlockDefinition.new()
	d.id = id
	d.display_name = String(id)
	d.occupancy = occ
	return d

func _put(coord: Vector3i, id: StringName) -> void:
	var i := BlockInstance.new()
	i.block_id = id
	_grid.set_block(coord, i)

func _plan() -> InteriorLayout:
	return InteriorLayout.plan(_grid, _cat, DeckGraph.build(_grid, _cat).walkable_coords())

func _face(layout: InteriorLayout, coord: Vector3i, normal: Vector3i) -> Dictionary:
	for f in layout.faces():
		if f["coord"] == coord and f["normal"] == normal:
			return f
	return {}

func _count(layout: InteriorLayout, variant: InteriorLayout.WallVariant) -> int:
	var n := 0
	for f in layout.faces():
		if f["kind"] == InteriorLayout.Kind.WALL and f["variant"] == variant:
			n += 1
	return n

func test_every_walkable_cell_gets_a_floor_and_a_ceiling():
	_put(Vector3i(0, 0, 0), &"deck")
	_put(Vector3i(1, 0, 0), &"deck")
	var layout := _plan()
	for coord in [Vector3i(0, 0, 0), Vector3i(1, 0, 0)]:
		assert_eq(_face(layout, coord, Vector3i.DOWN)["kind"], InteriorLayout.Kind.FLOOR)
		assert_eq(_face(layout, coord, Vector3i.UP)["kind"], InteriorLayout.Kind.CEILING)

func test_open_passage_between_walkable_cells_has_no_wall():
	_put(Vector3i(0, 0, 0), &"deck")
	_put(Vector3i(1, 0, 0), &"deck")
	assert_true(_face(_plan(), Vector3i(0, 0, 0), Vector3i(1, 0, 0)).is_empty())

func test_flank_on_the_outer_skin_gets_a_porthole():
	_put(Vector3i(0, 0, 0), &"deck")
	_put(Vector3i(1, 0, 0), &"hull")   # vacuum beyond: outer skin
	var f := _face(_plan(), Vector3i(0, 0, 0), Vector3i(1, 0, 0))
	assert_eq(f["variant"], InteriorLayout.WallVariant.PORTHOLE)
	assert_true(f["porthole"], "the builder is told to cut it")

func test_flank_with_solid_beyond_gets_no_porthole():
	_put(Vector3i(0, 0, 0), &"deck")
	_put(Vector3i(1, 0, 0), &"hull")
	_put(Vector3i(2, 0, 0), &"hull")   # a porthole here would look into machinery
	var f := _face(_plan(), Vector3i(0, 0, 0), Vector3i(1, 0, 0))
	assert_ne(f["variant"], InteriorLayout.WallVariant.PORTHOLE)
	assert_false(f["porthole"])

func test_end_walls_never_get_portholes():
	_put(Vector3i(0, 0, 0), &"deck")
	_put(Vector3i(0, 0, 1), &"hull")   # skin, but fore/aft
	assert_ne(_face(_plan(), Vector3i(0, 0, 0), Vector3i(0, 0, 1))["variant"],
		InteriorLayout.WallVariant.PORTHOLE)

func test_wall_beside_a_mount_is_a_console_even_on_the_skin():
	_put(Vector3i(0, 0, 0), &"seat")
	_put(Vector3i(1, 0, 0), &"deck")
	_put(Vector3i(2, 0, 0), &"hull")   # skin flank, but by the helm
	assert_eq(_face(_plan(), Vector3i(1, 0, 0), Vector3i(1, 0, 0))["variant"],
		InteriorLayout.WallVariant.CONSOLE)

func test_mount_cells_own_walls_hold_nothing_that_protrudes():
	_put(Vector3i(0, 0, 0), &"seat")
	_put(Vector3i(1, 0, 0), &"hull")
	var layout := _plan()
	assert_eq(_face(layout, Vector3i(0, 0, 0), Vector3i(1, 0, 0))["variant"],
		InteriorLayout.WallVariant.PORTHOLE, "skin flank: a porthole is flat enough")
	assert_eq(_face(layout, Vector3i(0, 0, 0), Vector3i(0, 0, 1))["variant"],
		InteriorLayout.WallVariant.PANEL, "anything else stays flat")

func test_cockpit_row_walls_are_consoles():
	_put(Vector3i(0, 0, 0), &"deck")
	_put(Vector3i(0, 0, -1), &"canopy")
	_put(Vector3i(1, 0, 0), &"hull")
	_put(Vector3i(2, 0, 0), &"hull")
	assert_eq(_face(_plan(), Vector3i(0, 0, 0), Vector3i(1, 0, 0))["variant"],
		InteriorLayout.WallVariant.CONSOLE)

func test_hatch_only_where_the_airlock_meets_vacuum():
	_put(Vector3i(0, 0, 0), &"airlock")
	_put(Vector3i(0, 0, -1), &"deck")
	_put(Vector3i(1, 0, 0), &"hull")
	_put(Vector3i(-1, 0, 0), &"hull")   # only the aft face opens onto vacuum
	var layout := _plan()
	assert_eq(_face(layout, Vector3i(0, 0, 0), Vector3i(0, 0, 1))["variant"],
		InteriorLayout.WallVariant.HATCH)
	assert_ne(_face(layout, Vector3i(0, 0, 0), Vector3i(1, 0, 0))["variant"],
		InteriorLayout.WallVariant.HATCH)
	assert_eq(_count(layout, InteriorLayout.WallVariant.HATCH), 1)

func test_every_wall_has_one_variant_and_canopies_have_none():
	_put(Vector3i(0, 0, 0), &"deck")
	_put(Vector3i(0, 0, -1), &"canopy")
	_put(Vector3i(0, 0, 1), &"airlock")
	for f in _plan().faces():
		match f["kind"]:
			InteriorLayout.Kind.WALL:
				assert_ne(f["variant"], InteriorLayout.WallVariant.NONE)
			_:
				assert_eq(f["variant"], InteriorLayout.WallVariant.NONE)

func test_porthole_flag_matches_the_porthole_variant():
	_put(Vector3i(0, 0, 0), &"deck")
	_put(Vector3i(1, 0, 0), &"hull")
	_put(Vector3i(0, 0, 1), &"deck")
	for f in _plan().faces():
		if f["kind"] == InteriorLayout.Kind.WALL:
			assert_eq(f["porthole"], f["variant"] == InteriorLayout.WallVariant.PORTHOLE)

func test_bridge_zone_is_the_command_area():
	_put(Vector3i(0, 0, 0), &"seat")
	_put(Vector3i(0, 0, 1), &"deck")
	_put(Vector3i(0, 0, 2), &"deck")
	var layout := _plan()
	assert_eq(_face(layout, Vector3i(0, 0, 0), Vector3i.DOWN)["zone"], InteriorLayout.ZONE_BRIDGE)
	assert_eq(_face(layout, Vector3i(0, 0, 1), Vector3i.DOWN)["zone"], InteriorLayout.ZONE_BRIDGE,
		"beside the seat")
	assert_eq(_face(layout, Vector3i(0, 0, 2), Vector3i.DOWN)["zone"], InteriorLayout.ZONE_COMMON)

func test_canopy_faces_in_one_plane_form_one_group():
	for x in [-1, 0, 1]:
		_put(Vector3i(x, 0, 0), &"deck")
		_put(Vector3i(x, 0, -1), &"canopy")
	var groups := _plan().canopy_groups()
	assert_eq(groups.size(), 1)
	assert_eq(groups[0]["normal"], Vector3i(0, 0, -1))
	assert_eq(groups[0]["coords"].size(), 3)

func test_canopies_on_different_planes_group_separately():
	_put(Vector3i(0, 0, 0), &"deck")
	_put(Vector3i(0, 0, -1), &"canopy")
	_put(Vector3i(5, 0, 3), &"deck")
	_put(Vector3i(5, 0, 2), &"canopy")
	assert_eq(_plan().canopy_groups().size(), 2)

func test_the_same_grid_always_plans_the_same():
	_put(Vector3i(0, 0, 0), &"deck")
	_put(Vector3i(1, 0, 0), &"deck")
	_put(Vector3i(0, 0, 1), &"seat")
	_put(Vector3i(2, 0, 0), &"hull")
	assert_eq(_plan().faces(), _plan().faces())

## The real starter shuttle, as flight_test.gd builds it (spec §7.5).
func test_starter_shuttle_layout():
	var bootstrap: Node = load("res://scenes/flight_test.gd").new()
	var grid: ShipGrid = bootstrap._starter_grid()
	bootstrap.free()
	var catalog := BlockCatalog.load_from_dir("res://data/blocks")
	var layout := InteriorLayout.plan(grid, catalog, DeckGraph.build(grid, catalog).walkable_coords())
	assert_eq(_count(layout, InteriorLayout.WallVariant.CONSOLE), 4, "both walls of the two helm rows")
	assert_eq(_count(layout, InteriorLayout.WallVariant.HATCH), 1)
	assert_eq(layout.rooms().size(), 5)
	var doorways := layout.faces().filter(func(f): return f["kind"] == InteriorLayout.Kind.DOORWAY)
	assert_eq(doorways.size(), 10, "five doorways, two sides each")
	var portholes := layout.faces().filter(func(f): return f["porthole"])
	assert_eq(portholes.size(), 4, "two on the bridge, one in the bunk room, one in the galley")
	assert_eq(layout.canopy_groups().size(), 1)
	assert_eq(layout.canopy_groups()[0]["coords"].size(), 3)

func _walls_of(layout: InteriorLayout, coord: Vector3i) -> Array:
	var out := []
	for f in layout.faces():
		if f["coord"] == coord and (f["kind"] == InteriorLayout.Kind.WALL
				or f["kind"] == InteriorLayout.Kind.DOORWAY):
			out.append(f)
	return out

func test_room_cells_take_their_room_as_zone():
	_put(Vector3i(0, 0, 0), &"galley")
	var layout := _plan()
	assert_eq(layout.zone_at(Vector3i(0, 0, 0)), &"galley")
	assert_eq(_face(layout, Vector3i(0, 0, 0), Vector3i.DOWN)["zone"], &"galley")

func test_a_partition_has_a_record_on_each_side_and_one_owner():
	_put(Vector3i(0, 0, 0), &"deck")
	_put(Vector3i(1, 0, 0), &"galley")
	_put(Vector3i(0, 0, 1), &"deck")   # so the galley's doorway is not this face
	var layout := _plan()
	var here := _face(layout, Vector3i(0, 0, 0), Vector3i(1, 0, 0))
	var there := _face(layout, Vector3i(1, 0, 0), Vector3i(-1, 0, 0))
	assert_true(here["partition"] and there["partition"])
	assert_ne(here["owner"], there["owner"], "exactly one side builds it")

func test_no_wall_between_bridge_and_common():
	_put(Vector3i(0, 0, 0), &"seat")
	_put(Vector3i(0, 0, 1), &"deck")   # bridge
	_put(Vector3i(0, 0, 2), &"deck")   # common
	assert_true(_face(_plan(), Vector3i(0, 0, 1), Vector3i(0, 0, 1)).is_empty())

func test_each_room_gets_exactly_one_doorway():
	for z in [0, 1]:
		_put(Vector3i(0, 0, z), &"deck")
		_put(Vector3i(-1, 0, z), &"bunk_room")
	_put(Vector3i(-1, 0, -1), &"deck")
	var layout := _plan()
	assert_eq(layout.rooms().size(), 1, "two bunk cells, one room")
	var doorways := layout.faces().filter(func(f): return f["kind"] == InteriorLayout.Kind.DOORWAY)
	assert_eq(doorways.size(), 2, "one doorway, seen from both sides")

func test_doorway_prefers_a_flank_onto_common_space():
	_put(Vector3i(1, 0, 0), &"galley")
	_put(Vector3i(0, 0, 0), &"deck")    # corridor, across a flank
	_put(Vector3i(1, 0, -1), &"deck")   # bridge side, across an end
	var door: Dictionary = _plan().rooms()[0]["doorway"]
	assert_eq(door["coord"], Vector3i(1, 0, 0))
	assert_eq(door["normal"], Vector3i(-1, 0, 0))

func test_doorway_ties_break_forward():
	for z in [0, 1]:
		_put(Vector3i(0, 0, z), &"deck")
		_put(Vector3i(-1, 0, z), &"bunk_room")
	var door: Dictionary = _plan().rooms()[0]["doorway"]
	assert_eq(door["coord"], Vector3i(-1, 0, 0), "the forward of two equal faces")

func test_a_room_with_no_common_neighbour_opens_onto_another_room():
	_put(Vector3i(0, 0, 0), &"deck")
	_put(Vector3i(1, 0, 0), &"galley")
	_put(Vector3i(2, 0, 0), &"closet")   # only touches the galley
	var layout := _plan()
	for room in layout.rooms():
		assert_false(room["doorway"].is_empty(), "%s has a way in" % room["zone"])

func test_feature_wall_prefers_an_outer_flank():
	_put(Vector3i(0, 0, 0), &"deck")
	_put(Vector3i(0, 0, 1), &"deck")
	_put(Vector3i(-1, 0, 0), &"bunk_room")
	_put(Vector3i(-1, 0, 1), &"bunk_room")
	_put(Vector3i(-2, 0, 0), &"hull")
	_put(Vector3i(-2, 0, 1), &"hull")
	var layout := _plan()
	for coord in [Vector3i(-1, 0, 0), Vector3i(-1, 0, 1)]:
		assert_eq(_face(layout, coord, Vector3i(-1, 0, 0))["variant"], InteriorLayout.WallVariant.FEATURE,
			"the hull side, not the corridor side")

func test_a_feature_on_the_outer_skin_gets_a_porthole():
	_put(Vector3i(0, 0, 0), &"deck")
	_put(Vector3i(1, 0, 0), &"galley")
	_put(Vector3i(2, 0, 0), &"hull")   # vacuum beyond
	var f := _face(_plan(), Vector3i(1, 0, 0), Vector3i(1, 0, 0))
	assert_eq(f["variant"], InteriorLayout.WallVariant.FEATURE)
	assert_true(f["porthole"])

## A 2 m room fits one main piece and one smaller one; more collide in the
## corners. The rest of its walls keep just their trim.
func test_every_room_cell_has_one_feature_and_at_most_one_secondary():
	_put(Vector3i(0, 0, 0), &"deck")
	_put(Vector3i(1, 0, 0), &"galley")
	_put(Vector3i(1, 0, 1), &"closet")
	var layout := _plan()
	for coord in [Vector3i(1, 0, 0), Vector3i(1, 0, 1)]:
		var tally := {}
		for f in _walls_of(layout, coord):
			if f["kind"] == InteriorLayout.Kind.WALL:
				assert_has([InteriorLayout.WallVariant.FEATURE, InteriorLayout.WallVariant.SECONDARY,
					InteriorLayout.WallVariant.PANEL], f["variant"])
				tally[f["variant"]] = tally.get(f["variant"], 0) + 1
		assert_eq(tally.get(InteriorLayout.WallVariant.FEATURE, 0), 1, "%s has one feature wall" % coord)
		assert_lte(tally.get(InteriorLayout.WallVariant.SECONDARY, 0), 1, "%s has at most one secondary" % coord)

func test_the_secondary_wall_is_beside_the_feature_and_knows_where_it_is():
	_put(Vector3i(0, 0, 0), &"deck")
	_put(Vector3i(1, 0, 0), &"galley")
	_put(Vector3i(2, 0, 0), &"hull")
	_put(Vector3i(1, 0, -1), &"hull")
	_put(Vector3i(1, 0, 1), &"hull")
	var layout := _plan()
	var feature := _face(layout, Vector3i(1, 0, 0), Vector3i(1, 0, 0))
	assert_eq(feature["variant"], InteriorLayout.WallVariant.FEATURE)
	var secondaries := _walls_of(layout, Vector3i(1, 0, 0)).filter(
		func(f): return f["variant"] == InteriorLayout.WallVariant.SECONDARY)
	assert_eq(secondaries.size(), 1)
	var n: Vector3i = secondaries[0]["normal"]
	assert_eq(n.x, 0, "at right angles to the feature wall, not facing it")
	assert_eq(secondaries[0]["feature_normal"], Vector3i(1, 0, 0),
		"the dressing pushes the secondary piece away from the feature wall")

func test_partitions_are_never_portholes_or_hatches():
	_put(Vector3i(0, 0, 0), &"airlock")
	_put(Vector3i(1, 0, 0), &"galley")
	_put(Vector3i(0, 0, -1), &"deck")
	for f in _plan().faces():
		if f.get("partition", false):
			assert_false(f["porthole"])
			assert_ne(f["variant"], InteriorLayout.WallVariant.HATCH)
