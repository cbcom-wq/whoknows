extends GutTest

## Ship exterior spec §5: the outside shows what the inside made of it.

var _cat: BlockCatalog

func before_all():
	_cat = BlockCatalog.load_from_dir("res://data/blocks")

func _starter() -> ShipGrid:
	var bootstrap: Node = load("res://scenes/flight_test.gd").new()
	var g: ShipGrid = bootstrap._starter_grid()
	bootstrap.free()
	return g

func _layouts(g: ShipGrid) -> Array:
	var interior := InteriorLayout.plan(g, _cat, DeckGraph.build(g, _cat).walkable_coords())
	return [interior, HullLayout.plan(g, _cat, interior)]

func test_every_interior_window_has_one_outside():
	var both := _layouts(_starter())
	var hull: HullLayout = both[1]
	assert_eq(hull.unmatched, [] as Array[Dictionary], "no window inside without one outside")
	assert_gt(hull.wanted, 0)
	assert_eq(hull.windows.size(), hull.wanted)

func test_portholes_sit_where_the_interior_s_do():
	var both := _layouts(_starter())
	var interior: InteriorLayout = both[0]
	var hull: HullLayout = both[1]
	var inside := 0
	for face in interior.faces():
		if face["kind"] == InteriorLayout.Kind.WALL and face["porthole"]:
			inside += 1
	var outside := hull.windows.filter(func(w): return w["round"])
	assert_eq(outside.size(), inside)
	for w in outside:
		var coord: Vector3i = w["coord"]
		var f: Transform3D = w["frame"]
		assert_almost_eq(f.origin.y, InteriorBuilder.floor_y(coord) + InteriorProps.PORTHOLE_HEIGHT, 0.001,
			"a porthole at the interior's height (storey 0)")
		assert_almost_eq(w["size"].x, InteriorProps.PORTHOLE_RADIUS * 2.0, 0.0001)

func test_the_shoulders_are_plate_with_a_window_at_the_interior_s_heights():
	var hull: HullLayout = _layouts(_starter())[1]
	var rects := hull.windows.filter(func(w): return not w["round"])
	assert_eq(rects.size(), 2, "port and starboard shoulders")
	var fl := InteriorBuilder.floor_y(Vector3i(0, 0, -3))
	for w in rects:
		var f: Transform3D = w["frame"]
		var half_rise: float = w["size"].y * 0.5 * f.basis.y.y
		assert_almost_eq(f.origin.y - half_rise, fl + InteriorProps.SHOULDER_WINDOW_LOW, 0.001)
		assert_almost_eq(f.origin.y + half_rise, fl + InteriorProps.SHOULDER_WINDOW_HIGH, 0.001)
		assert_almost_eq(w["size"].x, InteriorProps.SHOULDER_WINDOW_HALF * 2.0, 0.0001)

func test_the_pod_shell_is_the_interior_pod():
	var both := _layouts(_starter())
	var interior: InteriorLayout = both[0]
	var hull: HullLayout = both[1]
	assert_eq(hull.pods.size(), 1)
	var pod: Dictionary = interior.pods()[0]
	var f: Transform3D = hull.pods[0]["frame"]
	assert_eq(f, InteriorDressing.pod_frame(pod["coord"], pod["normal"]), "the same frame, storey 0")
	assert_eq(hull.pods[0]["cell"], pod["coord"] + pod["normal"])
	assert_true(hull.is_pod_cell(pod["coord"] + pod["normal"]))
	assert_false(hull.skin.has(pod["coord"] + pod["normal"]))
	for fc in hull.facets:
		assert_ne(fc["coord"], pod["coord"] + pod["normal"], "the shell draws the pod's cell")

func test_a_nose_without_a_pod_gets_its_windows():
	var g := ShipGrid.new()
	for x in [-1, 0, 1]:
		for spec in [[Vector3i(x, 0, -1), &"canopy"], [Vector3i(x, 0, 0), &"deck"], [Vector3i(x, 1, 0), &"hull"]]:
			var i := BlockInstance.new()
			i.block_id = spec[1]
			g.set_block(spec[0], i)
	var hull: HullLayout = _layouts(g)[1]
	assert_eq(hull.pods.size(), 0)
	assert_eq(hull.unmatched, [] as Array[Dictionary])
	assert_eq(hull.windows.size(), InteriorProps.NOSE_WINDOWS.size() + hull.windows.filter(func(w): return w["round"]).size())

func test_running_strips_mark_the_top_edges():
	var hull: HullLayout = _layouts(_starter())[1]
	var running := hull.edges.filter(func(e): return e["running"])
	assert_gt(running.size(), 0)
	var top := -1000
	for e in hull.edges:
		if (e["a"] == Vector3i.UP or e["b"] == Vector3i.UP) and absi(e["axis"].z) == 1:
			top = maxi(top, e["coord"].y)
	for e in running:
		var along_top: bool = (e["a"] == Vector3i.UP or e["b"] == Vector3i.UP) and absi(e["axis"].z) == 1 \
			and e["coord"].y == top
		var bow: bool = absi(e["axis"].y) == 1 and (e["a"] == Vector3i.FORWARD or e["b"] == Vector3i.FORWARD)
		assert_true(along_top or bow, "a running strip on the top edges or the bow")
