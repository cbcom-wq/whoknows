extends GutTest

## SkyMap (ship weapons spec §3.3): which way a turret can fire without its
## own ship in the way, marched through the layout, every cell a cube.

func _plate(half := 2) -> ShipGrid:
	var g := ShipGrid.new()
	for x in range(-half, half + 1):
		for z in range(-half, half + 1):
			var inst := BlockInstance.new()
			inst.block_id = &"hull"
			g.set_block(Vector3i(x, 0, z), inst)
	return g

func _put(g: ShipGrid, at: Vector3i, id := &"hull") -> void:
	var inst := BlockInstance.new()
	inst.block_id = id
	g.set_block(at, inst)

func test_mount_normals_follow_the_block_up():
	assert_eq(SkyMap.normal_of(0), Vector3i.UP, "orientation 0 is dorsal")
	assert_eq(SkyMap.normal_of(2), Vector3i.DOWN, "orientation 2 is ventral")
	var sides := [SkyMap.normal_of(1), SkyMap.normal_of(3)]
	assert_true(sides.has(Vector3i.RIGHT) and sides.has(Vector3i.LEFT), "1 and 3 are the two flanks")
	for o in BlockOrientation.COUNT:
		var n := SkyMap.normal_of(o)
		assert_eq(absi(n.x) + absi(n.y) + absi(n.z), 1, "orientation %d has an axis normal" % o)

func test_the_mount_basis_stands_on_its_normal():
	for n: Vector3i in [Vector3i.UP, Vector3i.DOWN, Vector3i.LEFT, Vector3i.RIGHT, Vector3i(0, 0, -1), Vector3i(0, 0, 1)]:
		var b := SkyMap.mount_basis(n)
		assert_almost_eq(b.y, Vector3(n), Vector3.ONE * 0.0001, "+y is %s" % n)
		assert_almost_eq(b.determinant(), 1.0, 0.0001, "a rotation")

func test_directions_and_angles_agree():
	for yi in [0, 7, 16, 31]:
		for ei in [0, 5, 15]:
			var d := SkyMap.direction(yi, ei)
			assert_almost_eq(d.length(), 1.0, 0.0001)
			var a := SkyMap.angles(d)
			assert_almost_eq(SkyMap.direction(yi, ei), Vector3(sin(a.x) * cos(a.y), sin(a.y), -cos(a.x) * cos(a.y)),
				Vector3.ONE * 0.0001)

func test_a_turret_on_a_flat_deck_sees_its_whole_half_sky():
	var sky := SkyMap.build(_plate(), Vector3i.ZERO, Vector3i.UP)
	assert_almost_eq(sky.coverage(), 1.0, 0.0001)
	assert_true(sky.can_bear(Vector3.UP))
	assert_true(sky.can_bear(Vector3(1, 0.05, 0).normalized()), "just over the horizon")
	assert_false(sky.can_bear(Vector3.DOWN), "never below its face")

func test_a_wall_beside_it_blocks_that_side_low():
	var g := _plate()
	for y in range(1, 4):
		for z in range(-2, 3):
			_put(g, Vector3i(2, y, z))
	var sky := SkyMap.build(g, Vector3i.ZERO, Vector3i.UP)
	assert_lt(sky.coverage(), 1.0)
	assert_false(sky.can_bear(Vector3(1, 0.2, 0).normalized()), "into the wall")
	assert_true(sky.can_bear(Vector3(-1, 0.2, 0).normalized()), "away from it")
	assert_true(sky.can_bear(Vector3.UP), "over it")

func test_a_ventral_turret_looks_down():
	var sky := SkyMap.build(_plate(), Vector3i.ZERO, Vector3i.DOWN)
	assert_true(sky.can_bear(Vector3.DOWN))
	assert_false(sky.can_bear(Vector3.UP))

func test_its_own_cell_never_blocks_it():
	var g := _plate()
	_put(g, Vector3i.ZERO, WeaponValues.LIGHT)
	assert_almost_eq(SkyMap.build(g, Vector3i.ZERO, Vector3i.UP).coverage(), 1.0, 0.0001)

func test_the_muzzle_stands_off_the_face():
	assert_almost_eq(SkyMap.muzzle(Vector3i(1, 2, 3), Vector3i.UP),
		ShipGrid.cell_center(Vector3i(1, 2, 3)) + Vector3.UP * (WeaponValues.FACE_OUT + WeaponValues.MUZZLE_UP),
		Vector3.ONE * 0.0001)
