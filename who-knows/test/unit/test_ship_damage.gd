extends GutTest

## Hits and crashes reach the real ship's blocks (docs/superpowers/specs/
## 2026-09-29-health-and-damage-design.md §4, §5).

var _root: Node
var _ship: Ship

func before_each():
	_root = load("res://scenes/flight_test.tscn").instantiate()
	add_child_autofree(_root)
	_ship = _root.get_node("Ship")

func _hit(at: Vector3, normal: Vector3, damage: float) -> Hit:
	var hit := Hit.make(at, normal, -normal, Vector3.ZERO, null)
	hit.damage = damage
	return hit

## A hull block with open space on +x, and not a kept one.
func _outer_hull() -> Vector3i:
	for coord: Vector3i in _ship.grid.coords():
		var id := _ship.grid.get_block(coord).block_id
		if id == &"hull" and not _ship.grid.has_block(coord + Vector3i(1, 0, 0)):
			return coord
	fail_test("no outer hull block on +x")
	return Vector3i.ZERO

func test_the_ship_is_not_crippled_as_built():
	assert_false(_ship.stats.crippled, _ship.stats.crippled_reason)
	assert_gt(_ship.stats.intact_forward, 0.0)

func test_a_hit_on_the_hull_damages_the_cell_it_lands_on():
	var cell := _outer_hull()
	var local := ShipGrid.cell_center(cell) + Vector3(1.0, 0.2, -0.3)
	var hit := _hit(_ship.exterior.to_global(local), _ship.exterior.global_basis * Vector3(1, 0, 0), 10.0)
	Hit.deliver(_ship.exterior, hit)
	assert_eq(_ship.grid.get_block(cell).damage, 10.0)
	assert_eq(_ship.damage_log.busy(), "took damage")
	assert_eq(_ship.busy(), "took damage")

func test_a_hit_on_an_interior_wall_damages_the_block_behind_it():
	var layout: InteriorLayout = _ship.interior_builder.layout()
	for face in layout.faces():
		if face["kind"] != InteriorLayout.Kind.WALL or not face["owner"]:
			continue
		var coord: Vector3i = face["coord"]
		var normal: Vector3i = face["normal"]
		var behind := coord + normal
		if normal.y != 0 or not _ship.grid.has_block(behind):
			continue
		var local := InteriorBuilder.interior_center(coord) + Vector3(normal) * 0.95
		var hit := _hit(_ship.interior.to_global(local), -Vector3(normal), 10.0)
		Hit.deliver(_ship.interior_builder.geometry_body(), hit)
		assert_eq(_ship.grid.get_block(behind).damage, 10.0, "the wall at %s toward %s" % [coord, normal])
		return
	fail_test("no interior wall with a block behind it")

func test_crash_damage_curve():
	assert_eq(Ship.crash_damage(1.0), 0.0)
	assert_eq(Ship.crash_damage(Ship.CRASH_FROM), 0.0, "docking bumps are free")
	assert_almost_eq(Ship.crash_damage(5.0), 108.0, 0.001)
	assert_almost_eq(Ship.crash_damage(8.0), 432.0, 0.001)

func test_a_crash_lands_on_the_cell_and_half_on_its_neighbours():
	var cell := _outer_hull()
	_ship._deal_crash(cell, 40.0)
	assert_eq(_ship.grid.get_block(cell).damage, 40.0)
	for n in _ship.grid.neighbours(cell):
		if _ship.grid.has_block(n):
			assert_eq(_ship.grid.get_block(n).damage, 20.0, "neighbour %s" % n)

func test_a_gone_block_leaves_and_the_ship_is_rebuilt_lighter():
	var cell := _outer_hull()
	var mass := _ship.stats.total_mass_kg
	watch_signals(_ship)
	var removed := _ship.take_damage(cell, 10_000.0)
	assert_has(removed, cell)
	assert_false(_ship.grid.has_block(cell))
	assert_lt(_ship.stats.total_mass_kg, mass)
	assert_signal_emitted(_ship, "blocks_lost")

func test_a_wrecked_thruster_takes_its_thrust_away_without_a_rebuild():
	var thruster := Vector3i.ZERO
	var found := false
	for coord: Vector3i in _ship.grid.coords():
		if _ship.grid.get_block(coord).block_id == &"thruster":
			thruster = coord
			found = true
			break
	assert_true(found, "the starter ship has a main engine")
	var forward: float = _ship.flight_computer.thrust_budget[&"forward"]
	var body := _ship.interior_builder.geometry_body()
	_ship.take_damage(thruster, float(_ship.catalog.get_def(&"thruster").hp) * 1.1)
	assert_lt(_ship.flight_computer.thrust_budget[&"forward"], forward)
	assert_same(_ship.interior_builder.geometry_body(), body, "no rebuild for a stage")

func test_nothing_happens_to_an_empty_cell():
	assert_eq(_ship.take_damage(ShipCells.NONE, 50.0), [])
	assert_eq(_ship.take_damage(Vector3i(99, 99, 99), 50.0), [])
	assert_eq(_ship.damage_log.busy(), "")

# --- how it looks (spec §9) ---------------------------------------------------

func test_the_hull_instance_takes_the_stage_colour():
	var cell := _outer_hull()
	var hp := float(_ship.catalog.get_def(&"hull").hp)
	assert_eq(_ship.exterior_builder.instance_colour(cell), HullPalette.UNHURT)
	_ship.take_damage(cell, hp * 0.6)
	assert_eq(_ship.exterior_builder.instance_colour(cell), HullPalette.SCORCH)
	_ship.take_damage(cell, hp * 0.5)
	assert_eq(_ship.exterior_builder.instance_colour(cell), HullPalette.CHAR)

func test_a_damaged_outer_block_spits_sparks_and_a_mended_one_stops():
	var cell := _outer_hull()
	var hp := float(_ship.catalog.get_def(&"hull").hp)
	assert_eq(_ship.damage_show.spitting(), 0)
	_ship.take_damage(cell, hp * 0.6)
	assert_eq(_ship.damage_show.spitting(), 1)
	BlockDamage.repair(_ship.grid, _ship.catalog, cell, hp)
	assert_eq(_ship.damage_show.spitting(), 0)

func test_a_stage_seen_from_inside_rebuilds_once_at_the_end_of_the_frame():
	var wall := Vector3i.ZERO
	for coord: Vector3i in _ship.grid.coords():
		if _ship.interior_builder.shows(coord) and _ship.grid.get_block(coord).block_id == &"hull":
			wall = coord
			break
	var body := _ship.interior_builder.geometry_body()
	var hp := float(_ship.catalog.get_def(&"hull").hp)
	_ship.take_damage(wall, hp * 0.6)
	_ship.take_damage(wall, hp * 0.5)
	assert_same(_ship.interior_builder.geometry_body(), body, "not yet")
	await wait_physics_frames(2)
	assert_ne(_ship.interior_builder.geometry_body(), body, "rebuilt")
	assert_eq(_ship.interior_builder.wear_at(wall, Vector3i.ZERO), 2)

func test_a_block_knocked_off_the_outside_sheds_a_plate_and_chunks():
	var cell := _outer_hull()
	var shed := []
	_ship.plate_shed.connect(func(item: Item) -> void: shed.append(item))
	_ship.take_damage(cell, 10_000.0)
	assert_eq(shed.size(), 1)
	var plate: Item = shed[0]
	assert_eq(plate.definition.id, &"scrap_plate")
	assert_true(plate.in_space)
	assert_true(plate.is_in_group(Universe.EXTERIOR_SPACE))
	var chunks := get_tree().get_nodes_in_group(Universe.EXTERIOR_SPACE).filter(
		func(n): return n.name.begins_with("DamageChunk"))
	assert_gt(chunks.size(), 0)

# --- you, aboard (spec §7) -----------------------------------------------------

func test_you_wake_in_the_bunk_room_first():
	var spots := _ship.wake_spots()
	assert_gt(spots.size(), 0)
	var local := _ship.interior.to_local(spots[0].origin + Vector3.UP * 0.1)
	var cell := ShipCells.interior_cell_at(local)
	assert_eq(_ship.interior_builder.layout().zone_at(cell), Ship.WAKE_ROOM)

func test_a_blackout_aboard_wakes_you_in_the_bunk_room_and_costs_the_ship():
	var avatar: Avatar = _ship.get_node("Interior/Avatar")
	var store: QuantumStore = _ship.quantum.store
	store.credit(200, &"test")
	var before := store.amount
	avatar.take_damage(500.0)
	for i in roundi((Downed.FADE + Downed.BLACK + Downed.WAKE + 0.5) / 0.1):
		avatar._process(0.1)
	assert_null(avatar.downed)
	assert_eq(store.amount, before - Avatar.RESCUE_COST)
	# In the bunk room, or the nearest free cell to it: it is mostly bunks.
	var cell := ShipCells.interior_cell_at(_ship.interior.to_local(avatar.global_position + Vector3.UP * 0.1))
	var layout := _ship.interior_builder.layout()
	var nearest := INF
	for c: Vector3i in _ship.interior_builder.walkable_coords():
		if layout.zone_at(c) == Ship.WAKE_ROOM:
			nearest = minf(nearest, Vector3(c).distance_to(Vector3(cell)))
	assert_lt(nearest, 1.5, "woke at %s" % cell)

func test_a_hole_under_you_puts_you_outside():
	var avatar: Avatar = _ship.get_node("Interior/Avatar")
	var walk: Array = _ship.interior_builder.walkable_coords()
	var cell: Vector3i = Vector3i.ZERO
	for c: Vector3i in walk:
		if _ship.grid.get_block(c).block_id == &"deck":
			cell = c
			break
	avatar.place(_ship.interior.global_transform * Transform3D(Basis.IDENTITY, DeckPaths.floor_point(cell)))
	_ship.take_damage(cell, 100_000.0)
	assert_false(_ship.grid.has_block(cell))
	assert_eq(avatar.mode, Avatar.Mode.SUIT)
