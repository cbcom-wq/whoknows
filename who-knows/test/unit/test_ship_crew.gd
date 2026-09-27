extends GutTest

## Who lives aboard (docs/superpowers/specs/2026-09-26-npc-foundation-design.md
## §4.2, §14.2): one droid docked in the closet, and jobs from the layout.

const TestDeckPaths := preload("res://test/unit/test_deck_paths.gd")

var _layout: InteriorLayout
var _paths: DeckPaths

static func _block(id: StringName) -> BlockInstance:
	var b := BlockInstance.new()
	b.block_id = id
	return b

func before_each():
	_layout = TestDeckPaths.starter_layout()
	_paths = DeckPaths.build(_layout)

func test_the_starter_docks_its_droid_in_the_closet():
	assert_eq(ShipCrew.dock(_layout, _paths), Vector3i(1, 0, 2))

func test_one_droid_with_a_stable_id():
	var recs := ShipCrew.records(_layout, _paths, &"Ship", 0)
	assert_eq(recs.size(), 1)
	assert_eq(recs[0].id, &"droid:Ship:0")
	assert_eq(recs[0].species, ShipCrew.SPECIES)
	assert_eq(DeckPaths.cell_at(recs[0].home), Vector3i(1, 0, 2))
	var again := ShipCrew.records(_layout, _paths, &"Ship", 0)
	assert_eq(again[0].seed, recs[0].seed)
	assert_eq(again[0].home, recs[0].home)

func test_without_a_closet_it_docks_farthest_from_the_helm():
	var bootstrap: Node = load("res://scenes/flight_test.gd").new()
	var grid: ShipGrid = bootstrap._starter_grid()
	bootstrap.free()
	grid.set_block(Vector3i(1, 0, 2), _block(&"deck"))
	var catalog := BlockCatalog.load_from_dir("res://data/blocks")
	var layout := InteriorLayout.plan(grid, catalog, DeckGraph.build(grid, catalog).walkable_coords())
	var paths := DeckPaths.build(layout)
	var at := ShipCrew.dock(layout, paths)
	var steps := paths.distances(Vector3i(-1, 0, -3))
	for cell in paths.cells():
		assert_true(int(steps.get(cell, -1)) <= int(steps[at]), "%s is farther than the dock %s" % [cell, at])

func test_a_small_ship_has_no_crew():
	var grid := ShipGrid.new()
	var catalog := BlockCatalog.load_from_dir("res://data/blocks")
	grid.set_block(Vector3i(0, 0, 0), _block(&"core"))
	for z in 6:
		grid.set_block(Vector3i(1, 0, z), _block(&"deck"))
	var layout := InteriorLayout.plan(grid, catalog, DeckGraph.build(grid, catalog).walkable_coords())
	assert_eq(ShipCrew.records(layout, DeckPaths.build(layout), &"Tiny", 0).size(), 0)

func test_every_job_it_is_given_is_reachable_from_the_dock():
	var steps := _paths.distances(ShipCrew.dock(_layout, _paths))
	var spots := ShipCrew.reachable_spots(_layout, _paths)
	assert_gt(spots.size(), 0)
	for spot in spots:
		assert_true(steps.has(spot["cell"]), "%s at %s" % [spot["key"], spot["cell"]])

## The helm, the quantum core, the machine and the bridge computer's table are
## fixtures, off the droid's map. Without the diagonal steps past the quiet
## fixtures' corners (DeckPaths) they would wall off the whole front of the
## bridge; with them, the droid reaches every job on the starter.
func test_on_the_starter_every_job_is_reachable():
	var reachable := ShipCrew.reachable_spots(_layout, _paths)
	assert_eq(reachable.size(), ShipCrew.work_spots(_layout, _paths).size())
	var keys := reachable.map(func(s: Dictionary) -> StringName: return s["key"])
	assert_true(keys.has(StringName("fixture:%s" % Vector3i(0, 0, -3))), "the helm")
	assert_true(keys.has(StringName("fixture:%s" % Vector3i(-1, 0, -1))), "the bridge computer")

func test_the_starter_has_something_to_polish_and_scan_and_its_helm_to_tend():
	var actions := {}
	var keys := {}
	for spot in ShipCrew.work_spots(_layout, _paths):
		actions[spot["action"]] = true
		keys[spot["key"]] = true
	assert_true(actions.has(&"polish"), "portholes")
	assert_true(actions.has(&"scan"), "consoles or the helm")
	assert_true(keys.has(StringName("fixture:%s" % Vector3i(0, 0, -3))), "the helm, from beside it")
