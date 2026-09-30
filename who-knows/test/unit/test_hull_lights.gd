extends GutTest

## Ship exterior spec §6.1: the generator picks where the lights go.

var _cat: BlockCatalog

func before_all():
	_cat = BlockCatalog.load_from_dir("res://data/blocks")

func _plan(g: ShipGrid) -> HullLayout:
	return HullLayout.plan(g, _cat, InteriorLayout.plan(g, _cat, DeckGraph.build(g, _cat).walkable_coords()))

func _starter() -> ShipGrid:
	var bootstrap: Node = load("res://scenes/flight_test.gd").new()
	var g: ShipGrid = bootstrap._starter_grid()
	bootstrap.free()
	return g

func _group(l: HullLayout, group: StringName) -> Array:
	return l.mounts.filter(func(m): return m["group"] == group)

func test_the_starter_has_five_floods_and_two_forward_lights():
	var l := _plan(_starter())
	assert_eq(_group(l, HullLayout.FLOOD).size(), 5, "four belly corners and one on the keel (spec 6.1: floor(11.67 / 6))")
	assert_eq(_group(l, HullLayout.FORWARD).size(), 2)

func test_every_light_shines_clear_of_the_hull():
	var l := _plan(_starter())
	for m in l.mounts:
		var aim: Vector3 = m["aim"]
		assert_almost_eq(aim.length(), 1.0, 0.0001)
		for i in range(1, 21):
			var p: Vector3 = m["position"] + aim * (0.1 * i)
			assert_false(l.inside(p), "%s at %s shines into the hull %.1f m out" % [m["group"], m["position"], 0.1 * i])

func test_floods_look_down_and_out():
	var l := _plan(_starter())
	for m in _group(l, HullLayout.FLOOD):
		var aim: Vector3 = m["aim"]
		assert_almost_eq(rad_to_deg(aim.angle_to(Vector3.DOWN)), 25.0, 0.5, "tilted 25 deg out")
	var keel := _group(l, HullLayout.FLOOD).filter(func(m): return is_zero_approx(m["position"].x))
	assert_eq(keel.size(), 1)
	for m in keel:
		assert_almost_eq(m["aim"].x, 0.0, 0.0001, "a keel flood tilts fore or aft, not sideways")

func test_forward_lights_look_ahead_from_the_nose_corners():
	var l := _plan(_starter())
	var xs := []
	for m in _group(l, HullLayout.FORWARD):
		assert_lt(rad_to_deg(m["aim"].angle_to(Vector3.FORWARD)), 10.0)
		assert_lt(m["aim"].y, 0.0, "a little down")
		assert_gt(m["aim"].x * m["position"].x, 0.0, "toed out, away from the centreline")
		xs.append(m["position"].x)
	xs.sort()
	assert_lt(xs[0], -2.0)
	assert_gt(xs[1], 2.0)

func test_a_ship_with_no_pod_still_gets_forward_lights():
	var g := ShipGrid.new()
	for x in [-1, 0, 1]:
		for spec in [[Vector3i(x, 0, -1), &"canopy"], [Vector3i(x, 0, 0), &"deck"], [Vector3i(x, 1, 0), &"hull"]]:
			var i := BlockInstance.new()
			i.block_id = spec[1]
			g.set_block(spec[0], i)
	var l := _plan(g)
	assert_eq(_group(l, HullLayout.FORWARD).size(), 2)
	assert_gt(_group(l, HullLayout.FLOOD).size(), 0)

func test_the_dressing_makes_a_lens_per_group_starting_dark():
	var root := Node3D.new()
	add_child_autofree(root)
	var made := HullDressing.build(_plan(_starter()), root)
	for group in [HullLayout.FLOOD, HullLayout.FORWARD]:
		var lens: MeshInstance3D = made["lenses"][group]
		assert_not_null(lens)
		assert_eq((lens.material_override as ShaderMaterial).get_shader_parameter(&"energy"), 0.0)
	assert_ne(made["lenses"][HullLayout.FLOOD].material_override, made["lenses"][HullLayout.FORWARD].material_override)
