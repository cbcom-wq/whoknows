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

## A hull block of the buffer, outside the cabin's shell, with open space on
## +x: one that can be knocked off.
func _outer_hull() -> Vector3i:
	for coord: Vector3i in _ship.grid.coords():
		var id := _ship.grid.get_block(coord).block_id
		if id == &"hull" and not _ship.grid.has_block(coord + Vector3i(1, 0, 0)) \
				and not _ship.inner_cells.has(coord):
			return coord
	fail_test("no buffer hull block on +x")
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

## The colours `cell`'s pieces are drawn with now in Skin/<kit>/<batch>.
func _skin_colours(cell: Vector3i, kit: String, batch: InteriorKit.Batch) -> PackedColorArray:
	var eb := _ship.exterior_builder
	var mesh: ArrayMesh = (eb.get_node("Skin/%s/%s" % [kit, InteriorKit.BATCH_NAMES[batch]]) as MeshInstance3D).mesh
	var colours: PackedColorArray = mesh.surface_get_arrays(0)[Mesh.ARRAY_COLOR]
	var out := PackedColorArray()
	for span: Array in eb.skin_spans(cell):
		if span[0] == mesh:
			for i in range(span[1], span[2]):
				out.append(colours[i])
	return out

func _all_near(colours: PackedColorArray, want: Color) -> bool:
	for c in colours:
		# Vertex colours are stored at 8 bits a channel.
		if absf(c.r - want.r) > 0.01 or absf(c.g - want.g) > 0.01 or absf(c.b - want.b) > 0.01:
			return false
	return not colours.is_empty()

## The tint reaches every piece: each vertex of every tinted skin mesh is one
## cell's, the light fixtures' housings included.
func test_every_tinted_skin_vertex_belongs_to_one_cell():
	var eb := _ship.exterior_builder
	var owners := {}   # ArrayMesh -> PackedInt32Array, how many cells claim each vertex
	for kit in ["Hull", "Windows"]:
		for batch in HullDressing.TINTED:
			var mi := eb.get_node_or_null("Skin/%s/%s" % [kit, InteriorKit.BATCH_NAMES[batch]]) as MeshInstance3D
			if mi != null:
				var counts := PackedInt32Array()
				counts.resize((mi.mesh as ArrayMesh).surface_get_array_len(0))
				owners[mi.mesh] = counts
	assert_eq(owners.size(), 5, "the plating and trim, and the windows' plating, trim and glass")
	for cell: Vector3i in _ship.grid.coords():
		for span: Array in eb.skin_spans(cell):
			var counts: PackedInt32Array = owners[span[0]]
			for i in range(span[1], span[2]):
				counts[i] += 1
			owners[span[0]] = counts
	for mesh: ArrayMesh in owners:
		var counts: PackedInt32Array = owners[mesh]
		var unowned := 0
		var shared := 0
		for n in counts:
			unowned += int(n == 0)
			shared += int(n > 1)
		assert_eq([unowned, shared], [0, 0], "%d vertices: none without a cell, none in two" % counts.size())

func test_every_light_mount_is_on_its_cell():
	var eb := _ship.exterior_builder
	assert_gt(eb.light_mounts().size(), 0)
	for m in eb.light_mounts():
		var cell: Vector3i = m["coord"]
		assert_true(_ship.grid.has_block(cell), "%s is a block" % cell)
		var d: Vector3 = (m["position"] as Vector3) - ShipGrid.cell_center(cell)
		assert_lte(maxf(absf(d.x), maxf(absf(d.y), absf(d.z))), ShipGrid.CELL_SIZE * 0.5 + 0.01,
			"the mount at %s sits on %s" % [m["position"], cell])

## The livery multiplies by the plating's vertex colour (spec §17.5): an
## unhurt plate's is white, a hurt one's its stage colour.
func test_a_hurt_cell_s_plating_takes_its_stage_colour_and_the_rest_stay_white():
	var cell := _outer_hull()
	var other := Vector3i.ZERO
	for coord: Vector3i in _ship.grid.coords():
		if coord != cell and not _skin_colours(coord, "Hull", InteriorKit.Batch.HULL).is_empty():
			other = coord
			break
	assert_true(_all_near(_skin_colours(cell, "Hull", InteriorKit.Batch.HULL), HullPalette.UNHURT), "as built")
	var hp := float(_ship.catalog.get_def(&"hull").hp)
	_ship.take_damage(cell, hp * 0.6)
	await wait_process_frames(3)
	assert_true(_all_near(_skin_colours(cell, "Hull", InteriorKit.Batch.HULL), HullPalette.SCORCH), "scorched")
	assert_true(_all_near(_skin_colours(other, "Hull", InteriorKit.Batch.HULL), HullPalette.UNHURT), "%s untouched" % other)
	_ship.take_damage(cell, hp * 0.5)
	await wait_process_frames(3)
	assert_true(_all_near(_skin_colours(cell, "Hull", InteriorKit.Batch.HULL), HullPalette.CHAR), "charred")

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

## Spec §4.5 as amended 2026-10-02: however hard the ship is hit, the cabin
## keeps its shape -- every walkable cell, every room and pod, the helm --
## and only the buffer outside it breaks away. (The owner crashed onto a
## planet and was left in a room with the chair, unable to sit back down.)
func test_the_cabin_keeps_its_shape_however_hard_it_is_hit():
	var layout := _ship.interior_builder.layout()
	var walk_before: Array = _ship.interior_builder.walkable_coords().duplicate()
	var pods_before := layout.pods()
	var rooms_before := layout.rooms().size()
	var blocks_before := _ship.grid.size()
	var shell := 0
	for coord: Vector3i in _ship.grid.coords():
		if _ship.inner_cells.has(coord):
			shell += 1
	var hits := {}
	for coord: Vector3i in _ship.grid.coords():
		hits[coord] = 100_000.0
	_ship.take_damage_many(hits)
	assert_eq(_ship.interior_builder.walkable_coords().size(), walk_before.size(), "every walkable cell")
	for cell in walk_before:
		assert_true(_ship.grid.has_block(cell), "%s is still there" % cell)
	assert_eq(_ship.interior_builder.layout().pods(), pods_before, "the cockpit pod")
	assert_eq(_ship.interior_builder.layout().rooms().size(), rooms_before, "every room")
	assert_lt(_ship.grid.size(), blocks_before, "the buffer broke away")
	assert_eq(_ship.grid.size(), shell, "and only the buffer")
	for coord: Vector3i in _ship.grid.coords():
		var inst := _ship.grid.get_block(coord)
		assert_eq(BlockDamage.stage_of(inst, _ship.catalog.get_def(inst.block_id)), BlockDamage.Stage.WRECKED)

func test_a_save_with_holes_in_the_cabin_gets_its_shell_back_wrecked():
	var deck := Vector3i.ZERO
	for c: Vector3i in _ship.interior_builder.walkable_coords():
		if _ship.grid.get_block(c).block_id == &"deck":
			deck = c
			break
	var holed := ShipBlueprint.from_grid(_ship.grid, "Holed").to_grid()
	holed.clear_block(deck)
	_ship.set_grid(holed, false)
	assert_true(_ship.grid.has_block(deck), "put back")
	assert_eq(_ship.damage_at(deck), float(_ship.catalog.get_def(&"deck").hp) * BlockDamage.WRECKED_AT)
	assert_true(_ship.interior_builder.walkable_coords().has(deck))

func test_a_wrecked_cabin_wall_spits_sparks_inside():
	var wall := Vector3i.ZERO
	for coord: Vector3i in _ship.grid.coords():
		if _ship.inner_cells.has(coord) and _ship.grid.get_block(coord).block_id == &"hull":
			wall = coord
			break
	assert_eq(_ship.damage_show.spitting_inside(), 0)
	_ship.take_damage(wall, float(_ship.catalog.get_def(&"hull").hp) * 1.2)
	assert_eq(_ship.damage_show.spitting_inside(), 1)
	await wait_physics_frames(2)
	assert_eq(_ship.damage_show.spitting_inside(), 1, "still, after the rebuild")

func test_the_spits_never_hold_the_floating_origin():
	var cell := _outer_hull()
	_ship.take_damage(cell, float(_ship.catalog.get_def(&"hull").hp) * 0.6)
	for node in get_tree().get_nodes_in_group(Universe.HOLDS_SHIFT):
		assert_ne(node.name, "Sparks", "a spit in its own frame does not hold the shift")

# --- the band (spec §11) --------------------------------------------------------

func test_the_hull_reads_whole_then_less_and_reaches_the_band():
	assert_eq(_ship.hull_whole(), 1.0)
	var t: VehicleTelemetry = _ship.flight_computer.build_telemetry()
	assert_true(t.has_hull)
	assert_eq(t.hull, 1.0)
	assert_eq(t.crippled_reason, "")
	var cell := _outer_hull()
	_ship.take_damage(cell, 10_000.0)
	assert_lt(_ship.hull_whole(), 1.0, "a knocked-off block counts as all lost")
	assert_lt(_ship.flight_computer.build_telemetry().hull, 1.0)

func test_crippled_reaches_the_band():
	for coord: Vector3i in _ship.grid.coords():
		if _ship.grid.get_block(coord).block_id == &"thruster":
			_ship.take_damage(coord, float(_ship.catalog.get_def(&"thruster").hp) * 1.2)
	assert_eq(_ship.flight_computer.build_telemetry().crippled_reason, "no thrust")

func test_a_stage_seen_from_inside_leaves_the_hull_standing():
	var wall := Vector3i.ZERO
	for coord: Vector3i in _ship.grid.coords():
		if _ship.inner_cells.has(coord) and _ship.grid.get_block(coord).block_id == &"hull":
			wall = coord
			break
	var hull_shapes := _ship.exterior.get_children().filter(func(n): return n is CollisionShape3D)
	_ship.take_damage(wall, float(_ship.catalog.get_def(&"hull").hp) * 0.6)
	await wait_physics_frames(2)
	for shape in hull_shapes:
		assert_true(is_instance_valid(shape), "the hull's colliders were not rebuilt")
	assert_eq(_ship.airlocks.size(), 1, "the airlock is still bound")

## A hit on the quantum cells keeps the energy (owner, 2026-10-02): the store
## stops taking more until they are mended, and mending gives the room back.
func test_a_hit_on_the_quantum_cells_keeps_the_energy():
	var cells: Array[Vector3i] = []
	for coord: Vector3i in _ship.grid.coords():
		if _ship.grid.get_block(coord).block_id == &"quantum_cell":
			cells.append(coord)
	assert_gt(cells.size(), 0, "the starter has quantum cells")
	var store := _ship.quantum.store
	var full := store.capacity
	store.credit(store.room(), &"test")
	assert_eq(store.amount, full)
	var hp := float(_ship.catalog.get_def(&"quantum_cell").hp)
	for c in cells:
		_ship.take_damage(c, hp * 1.1)
	assert_eq(store.capacity, 0, "every cell wrecked holds nothing more")
	assert_eq(store.amount, full, "but what was stored stays")
	assert_false(store.credit(1, &"test"))
	for c in cells:
		_ship.repair_cell(c, hp * 2.0)
	assert_eq(store.capacity, full, "mended")
	assert_eq(store.amount, full)

## A wrecked ceiling flickers (owner, 2026-10-02) and a mended one is steady.
func test_a_wrecked_ceiling_light_flickers_and_a_mended_one_is_steady():
	var cell := Vector3i.ZERO
	var above := Vector3i.ZERO
	for c: Vector3i in _ship.interior_builder.walkable_coords():
		var b := _ship.grid.get_block(c + Vector3i.UP)
		if b != null and _ship.interior_builder.shows(c + Vector3i.UP):
			cell = c
			above = c + Vector3i.UP
			break
	assert_ne(above, Vector3i.ZERO, "a walkable cell with a ceiling block")
	assert_eq(_ship.find_children("Flicker", "LightFlicker", true, false).size(), 0, "none as built")
	var hp := float(_ship.catalog.get_def(_ship.grid.get_block(above).block_id).hp)
	_ship.take_damage(above, hp * 1.1)
	await wait_process_frames(3)
	var flickers := _ship.find_children("Flicker", "LightFlicker", true, false)
	assert_gt(flickers.size(), 0, "the wrecked ceiling's light flickers")
	var f: LightFlicker = flickers[0]
	assert_eq(f.lamp.get_meta(&"role"), InteriorProps.CELL_LIGHT_ROLE)
	assert_almost_eq(f.lamp_energy, InteriorProps.CELL_LIGHT_ENERGY, 0.0001)
	_ship.repair_cell(above, hp * 2.0)
	await wait_process_frames(3)
	assert_eq(_ship.find_children("Flicker", "LightFlicker", true, false).size(), 0, "mended: steady again")
