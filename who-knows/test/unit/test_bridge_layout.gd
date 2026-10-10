extends GutTest

## The bridge in the layout (docs/superpowers/specs/2026-10-09-ship-bridge-design.md
## §3.4, §4, §5): one list of helms, a band where a helm ship has glass, no pod,
## the dais and the hull's windows.

const BRIDGE := "res://test/fixtures/bridge/bridge.json"

var _cat: BlockCatalog
var _grid: ShipGrid
var _layout: InteriorLayout

func before_all():
	_cat = BlockCatalog.load_from_dir("res://data/blocks")

func before_each():
	_grid = ShipLibrary.read(BRIDGE)["grid"]
	_layout = InteriorLayout.plan(_grid, _cat, DeckGraph.build(_grid, _cat).walkable_coords())

func _ids(list: Array) -> Array:
	var out := []
	for f in list:
		out.append(f["id"])
	return out

func test_both_helms_are_helms():
	assert_eq(InteriorLayout.HELM_IDS, [&"pilot_seat", &"helm"] as Array[StringName])
	assert_eq(ShipValidator.HELM_IDS, InteriorLayout.HELM_IDS)

func test_a_helm_ship_has_no_pod():
	assert_eq(_layout.pods(), [])

func test_the_starter_still_has_its_pod():
	var starter := ShipLibrary.load_from_dir().grid(&"starter")
	var l := InteriorLayout.plan(starter, _cat, DeckGraph.build(starter, _cat).walkable_coords())
	assert_eq(l.pods().size(), 1)

func test_the_validator_takes_a_helm():
	var codes := []
	for issue in ShipValidator.validate(_grid, _cat):
		codes.append(issue.code)
	assert_does_not_have(codes, &"HAS_PILOT_SEAT")

func test_the_seats_are_fixtures():
	var ids := _ids(_layout.fixtures())
	assert_has(ids, &"helm")
	assert_has(ids, &"captain_chair")
	assert_eq(ids.count(&"crew_station"), 2)

func test_the_chairs_are_quiet():
	assert_true(InteriorLayout.QUIET_FIXTURES.has(&"captain_chair"))
	assert_true(InteriorLayout.QUIET_FIXTURES.has(&"crew_station"))

func test_the_helm_stands_forward_toward_the_glass():
	var f := InteriorDressing.fixture_frame(_layout, Vector3i(0, 0, -4))
	var centre := ShipGrid.cell_center(Vector3i(0, 0, -4))
	assert_almost_eq(f.origin.z, centre.z - InteriorProps.HELM_FORWARD, 0.001)
	assert_almost_eq((-f.basis.z).dot(Vector3.FORWARD), 1.0, 0.001)

func test_the_droid_docks_and_the_crew_scans_the_seats():
	var paths := DeckPaths.build(_layout)
	assert_ne(ShipCrew.dock(_layout, paths), ShipCrew.NO_DOCK)
	var keys := []
	for spot in ShipCrew.work_spots(_layout, paths):
		keys.append(String(spot["key"]))
	assert_has(keys, "fixture:%s" % Vector3i(0, 0, -2), "the captain's chair is tended")

func test_damage_keeps_the_helm_and_counts_it_cockpit():
	assert_true(BlockDamage.KEEP.has(&"helm"))
	assert_true(ShipDamage.COMPONENTS[&"cockpit"].has(&"helm"))

func test_every_group_of_a_helm_ship_is_a_band():
	assert_gt(_layout.canopy_groups().size(), 2, "the front and both sides")
	for g in _layout.canopy_groups():
		assert_true(g["band"])

func test_the_starter_has_no_band():
	var starter := ShipLibrary.load_from_dir().grid(&"starter")
	var l := InteriorLayout.plan(starter, _cat, DeckGraph.build(starter, _cat).walkable_coords())
	for g in l.canopy_groups():
		assert_false(g["band"])

func _dressed() -> Node3D:
	var body := StaticBody3D.new()
	add_child_autofree(body)
	return InteriorDressing.build(_layout, body, null)

func test_a_pane_on_every_canopy_face():
	var faces := 0
	for g in _layout.canopy_groups():
		faces += (g["coords"] as Array).size()
	var root := _dressed()
	assert_eq(root.find_children("BandPane_*", "", true, false).size(), faces)
	assert_null(root.find_child("CockpitPod", true, false), "no pod")

func test_the_lights_panel_is_on_the_helm_desk():
	var root := _dressed()
	var panels := root.find_children("LightsPanel_*", "LightsPanel", true, false)
	assert_eq(panels.size(), 1)
	var helm := InteriorDressing.fixture_frame(_layout, Vector3i(0, 0, -4))
	var expect := helm * InteriorProps.helm_panel_frame()
	assert_almost_eq((panels[0] as Node3D).transform.origin, expect.origin, Vector3.ONE * 0.001)

func test_every_pane_has_its_window_outside():
	var hull := HullLayout.plan(_grid, _cat, _layout)
	assert_eq(hull.unmatched, [] as Array[Dictionary], "no pane without glass outside")
	# One window on the canopy cell outside each face, and no other (a nose's
	# three windows per group happen to make the same count on this ship, so
	# the count alone proves nothing).
	var wanted := {}
	for g in _layout.canopy_groups():
		for c: Vector3i in g["coords"]:
			var out: Vector3i = c + (g["normal"] as Vector3i)
			wanted[out] = 1 + int(wanted.get(out, 0))
	var got := {}
	for w in hull.windows:
		var c: Vector3i = w["coord"]
		if _grid.has_block(c) and _grid.get_block(c).block_id == &"canopy":
			got[c] = 1 + int(got.get(c, 0))
			assert_almost_eq((w["size"] as Vector2).x, InteriorProps.BAY - 2.0 * InteriorProps.BAND_POST, 0.001,
				"a pane's width at %s" % c)
	assert_eq(got, wanted)
