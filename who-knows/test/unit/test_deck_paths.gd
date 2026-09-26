extends GutTest

## The droid's map of the starter (docs/superpowers/specs/
## 2026-09-26-npc-foundation-design.md §5.5): walkable cells joined where no
## wall stands between them, never the airlock, the helm or any fixture.

var _layout: InteriorLayout
var _paths: DeckPaths

static func starter_layout() -> InteriorLayout:
	var bootstrap: Node = load("res://scenes/flight_test.gd").new()
	var grid: ShipGrid = bootstrap._starter_grid()
	bootstrap.free()
	var catalog := BlockCatalog.load_from_dir("res://data/blocks")
	var graph := DeckGraph.build(grid, catalog)
	return InteriorLayout.plan(grid, catalog, graph.walkable_coords())

func before_each():
	_layout = starter_layout()
	_paths = DeckPaths.build(_layout)

func test_the_airlock_and_the_helm_are_off_the_map():
	assert_false(_paths.has(Vector3i(0, 0, 3)), "the airlock")
	assert_false(_paths.has(Vector3i(0, 0, -3)), "the helm")

func test_every_other_walkable_cell_is_on_it():
	for cell in _layout.walkable_coords():
		if cell == Vector3i(0, 0, 3) or cell == Vector3i(0, 0, -3):
			continue
		assert_true(_paths.has(cell), "%s" % cell)

func test_the_corridor_runs_fore_and_aft():
	assert_true(_paths.linked(Vector3i(0, 0, -1), Vector3i(0, 0, 0)))
	assert_true(_paths.linked(Vector3i(0, 0, 0), Vector3i(0, 0, 1)))
	assert_true(_paths.linked(Vector3i(0, 0, 1), Vector3i(0, 0, 2)))

func test_each_room_opens_only_through_its_doorway():
	for room in _layout.rooms():
		var inside := {}
		for c in room["coords"]:
			inside[c] = true
		var crossings := 0
		for c: Vector3i in room["coords"]:
			for n in _paths.neighbours(c):
				if not inside.has(n):
					crossings += 1
		assert_eq(crossings, 1, "%s has %d ways out" % [room["zone"], crossings])

func test_a_path_from_the_closet_to_the_bridge_keeps_out_of_other_rooms():
	var route := _paths.path(Vector3i(1, 0, 2), Vector3i(-1, 0, -3))
	assert_gt(route.size(), 0)
	assert_eq(route[0], Vector3i(1, 0, 2))
	assert_eq(route[route.size() - 1], Vector3i(-1, 0, -3))
	for cell in route.slice(1, route.size() - 1):
		assert_false(InteriorLayout.ROOM_IDS.has(_layout.zone_at(cell)), "passes through %s" % cell)
	for i in route.size() - 1:
		assert_true(_paths.linked(route[i], route[i + 1]))

func test_no_way_to_nowhere():
	assert_eq(_paths.path(Vector3i(1, 0, 2), Vector3i(9, 0, 9)).size(), 0)
	assert_eq(_paths.path(Vector3i(1, 0, 2), Vector3i(1, 0, 2)), [Vector3i(1, 0, 2)] as Array[Vector3i])

func test_cell_at_undoes_floor_point():
	for cell in _paths.cells():
		assert_eq(DeckPaths.cell_at(DeckPaths.floor_point(cell)), cell)
		assert_eq(DeckPaths.cell_at(DeckPaths.floor_point(cell) + Vector3(0.9, 1.2, -0.9)), cell)

func test_avoided_cells_are_left_out():
	var paths := DeckPaths.build(_layout, [Vector3i(0, 0, 1)] as Array[Vector3i])
	assert_false(paths.has(Vector3i(0, 0, 1)))
	assert_eq(paths.path(Vector3i(1, 0, 2), Vector3i(-1, 0, -3)).size(), 0,
		"with the corridor cut, the closet is cut off")
