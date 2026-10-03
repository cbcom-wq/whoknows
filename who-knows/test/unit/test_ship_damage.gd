extends GutTest

## Hits and crashes reach the real ship's six hull sections and four
## components (docs/superpowers/specs/2026-10-03-ship-damage-sections-design.md),
## and the grid, the hull and the cabin show it.

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

## An outer hull block, off the centre line, with open space on +x or -x.
func _outer_hull() -> Vector3i:
	for coord: Vector3i in _ship.grid.coords():
		var id := _ship.grid.get_block(coord).block_id
		if id == &"hull" and coord.x != 0 and _ship.damage.sections_of.has(coord) \
				and not _ship.grid.has_block(coord + Vector3i(signi(coord.x), 0, 0)):
			return coord
	fail_test("no outer hull block")
	return Vector3i.ZERO

func _section_of(coord: Vector3i) -> StringName:
	return _ship.damage.sections_of[coord][0]

## Takes `section` to `health` (0..1).
func _set_health(section: StringName, health: float) -> void:
	var want: float = _ship.damage.section_hp[section] * (1.0 - health)
	var now: float = _ship.damage.section_damage[section]
	if want > now:
		_ship.damage.section_damage[section] = want
		_ship._apply_view()
	else:
		_ship.repair_section(section, (now - want) / _ship.damage.section_hp[section])

func _all_sections(health: float) -> void:
	for id in ShipDamage.SECTIONS:
		_set_health(id, health)

func _components_of(comp: StringName) -> Array[Vector3i]:
	var out: Array[Vector3i] = []
	for coord: Vector3i in _ship.damage.component_of:
		if _ship.damage.component_of[coord] == comp:
			out.append(coord)
	return out

func test_the_ship_is_not_crippled_as_built():
	assert_false(_ship.stats.crippled, _ship.stats.crippled_reason)
	assert_gt(_ship.stats.intact_forward, 0.0)
	assert_eq(_ship.hull_whole(), 1.0)

func test_a_hit_on_the_hull_goes_to_its_section():
	var cell := _outer_hull()
	var out := Vector3(signi(cell.x), 0, 0)
	var local := ShipGrid.cell_center(cell) + out * 1.0 + Vector3(0, 0.2, -0.3)
	var hit := _hit(_ship.exterior.to_global(local), _ship.exterior.global_basis * out, 10.0)
	Hit.deliver(_ship.exterior, hit)
	assert_eq(_ship.damage.section_damage[_section_of(cell)], 10.0)
	assert_eq(_ship.damage_log.busy(), "took damage")
	assert_eq(_ship.busy(), "took damage")

func test_a_bolt_on_an_interior_wall_hurts_the_hull_a_little():
	var layout: InteriorLayout = _ship.interior_builder.layout()
	for face in layout.faces():
		if face["kind"] != InteriorLayout.Kind.WALL or not face["owner"]:
			continue
		var coord: Vector3i = face["coord"]
		var normal: Vector3i = face["normal"]
		var behind := coord + normal
		if normal.y != 0 or not _ship.damage.sections_of.has(behind):
			continue
		var local := InteriorBuilder.interior_center(coord) + Vector3(normal) * 0.95
		Hit.deliver(_ship.interior_builder.geometry_body(), _hit(_ship.interior.to_global(local), -Vector3(normal), 10.0))
		var part := _ship.damage.part_of(behind, float(normal.x))
		assert_almost_eq(_ship.damage.section_damage[part], 10.0, 0.001, "the wall at %s toward %s" % [coord, normal])
		assert_lt(10.0 / _ship.damage.section_hp[part], 0.01, "under 1% of the section")
		return
	fail_test("no interior wall with a hull block behind it")

func test_crash_damage_curve():
	assert_eq(Ship.crash_damage(1.0), 0.0)
	assert_eq(Ship.crash_damage(Ship.CRASH_FROM), 0.0, "docking bumps are free")
	assert_almost_eq(Ship.crash_damage(5.0), 108.0, 0.001)
	assert_almost_eq(Ship.crash_damage(8.0), 432.0, 0.001)

func test_a_crash_lands_on_the_cell_and_half_on_its_neighbours():
	var cell := _outer_hull()
	var n := 0
	for c in _ship.grid.neighbours(cell):
		if _ship.grid.has_block(c):
			n += 1
	_ship._deal_crash(cell, 40.0, 0.0)
	var total := 0.0
	for id in ShipDamage.SECTIONS:
		total += _ship.damage.section_damage[id]
	for comp: StringName in _ship.damage.component_damage:
		total += _ship.damage.component_damage[comp]
	assert_almost_eq(total, 40.0 + 20.0 * n, 0.001)

func test_a_hit_on_a_component_goes_to_it():
	var core: Vector3i = _components_of(&"quantum_core")[0]
	_ship.take_damage(core, 50.0)
	assert_eq(_ship.damage.component_damage[&"quantum_core"], 50.0)
	assert_eq(_ship.hull_whole(), 1.0, "the hull is untouched")

func test_nothing_happens_to_an_empty_cell():
	assert_eq(_ship.take_damage(ShipCells.NONE, 50.0), [])
	assert_eq(_ship.take_damage(Vector3i(99, 99, 99), 50.0), [])
	assert_eq(_ship.damage_log.busy(), "")

# --- pieces (spec §4) ---------------------------------------------------------------

func test_a_section_below_half_loses_its_own_pieces_and_gets_them_back():
	var section := &"port_stern"
	var mass := _ship.stats.total_mass_kg
	var before := _ship.grid.size()
	watch_signals(_ship)
	_set_health(section, 0.55)
	assert_eq(_ship.grid.size(), before, "over half: whole")
	_set_health(section, 0.0)
	assert_lt(_ship.grid.size(), before)
	assert_lt(_ship.stats.total_mass_kg, mass)
	assert_signal_emitted(_ship, "blocks_lost")
	for coord: Vector3i in _ship.damage.launch:
		if not _ship.grid.has_block(coord):
			assert_true(_ship.damage.pieces[section].has(coord), "%s is one of this section's pieces" % coord)
	_set_health(section, 1.0)
	assert_eq(_ship.grid.size(), before, "welded whole: every piece back")
	assert_almost_eq(_ship.stats.total_mass_kg, mass, 0.01)

func test_a_piece_knocked_off_sheds_a_plate_and_chunks():
	var shed := []
	_ship.plate_shed.connect(func(item: Item) -> void: shed.append(item))
	_set_health(&"starboard_bow", 0.0)
	assert_eq(shed.size(), 1)
	var plate: Item = shed[0]
	assert_eq(plate.definition.id, &"scrap_plate")
	assert_true(plate.in_space)
	assert_true(plate.is_in_group(Universe.EXTERIOR_SPACE))
	var chunks := get_tree().get_nodes_in_group(Universe.EXTERIOR_SPACE).filter(
		func(n): return n.name.begins_with("DamageChunk"))
	assert_gt(chunks.size(), 0)

# --- what works (spec §2) -------------------------------------------------------------

func test_the_hull_at_nothing_changes_nothing_the_ship_can_do():
	var budget: Dictionary = _ship.stats.thrust_budget.duplicate()
	var torque: Vector3 = _ship.stats.torque_budget
	var capacity := _ship.quantum.store.capacity
	_all_sections(0.0)
	assert_eq(_ship.stats.thrust_budget, budget, "every thruster and RCS works")
	for axis in 3:
		# The pieces lost move the centre of mass a little, and the arms with it.
		assert_almost_eq(_ship.stats.torque_budget[axis], torque[axis], torque[axis] * 0.1, "axis %d still turns" % axis)
	assert_eq(_ship.quantum.store.capacity, capacity, "the cells hold what they did")
	assert_false(_ship.stats.crippled, _ship.stats.crippled_reason)

func test_damaged_engines_give_half_thrust_and_wrecked_none():
	var forward: float = _ship.flight_computer.thrust_budget[&"forward"]
	var thruster: Vector3i = _components_of(&"engines")[0]
	_ship.take_damage(thruster, _ship.damage.component_hp[&"engines"] * 0.6)
	assert_almost_eq(_ship.flight_computer.thrust_budget[&"forward"], forward * 0.5, 1.0, "every thruster at half")
	_ship.take_damage(thruster, _ship.damage.component_hp[&"engines"])
	assert_eq(_ship.flight_computer.thrust_budget[&"forward"], 0.0)
	assert_eq(_ship.flight_computer.build_telemetry().crippled_reason, "no thrust")
	_ship.repair_component(&"engines", 10_000.0)
	assert_almost_eq(_ship.flight_computer.thrust_budget[&"forward"], forward, 1.0, "mended")

func test_a_wrecked_quantum_core_cripples():
	_ship.take_damage(_components_of(&"quantum_core")[0], 10_000.0)
	assert_true(_ship.stats.crippled)
	assert_eq(_ship.damage.component_stage(&"quantum_core"), BlockDamage.Stage.WRECKED)
	assert_true(_ship.grid.has_block(_components_of(&"quantum_core")[0]), "a component is never knocked off")

# --- how it looks (spec §4, §9) ---------------------------------------------------------

func test_a_hurt_section_tints_its_exposed_blocks_and_no_other():
	var cell := _outer_hull()
	var section := _section_of(cell)
	assert_eq(_ship.exterior_builder.instance_colour(cell), HullPalette.UNHURT)
	_set_health(section, 0.6)
	var shown := BlockDamage.stage_of(_ship.grid.get_block(cell), _ship.catalog.get_def(&"hull"))
	assert_ne(shown, BlockDamage.Stage.INTACT, "an outer block shows it at 60%")
	assert_eq(_ship.exterior_builder.instance_colour(cell), _ship.exterior_builder.stage_colour(shown))
	for coord: Vector3i in _ship.damage.sections_of:
		if not _ship.damage.sections_of[coord].has(section) and _ship.grid.has_block(coord):
			assert_eq(_ship.grid.get_block(coord).damage, 0.0, "%s is in another section" % coord)

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
## The livery multiplies by the plating's vertex colour (spec §17.5): an
## unhurt plate's is white, a hurt one's its stage colour.
func test_a_hurt_section_s_plating_takes_its_stage_colour_and_the_rest_stay_white():
	var cell := _outer_hull()
	var other := Vector3i.ZERO
	for coord: Vector3i in _ship.damage.sections_of:
		if not _ship.damage.sections_of[coord].has(_section_of(cell)) \
				and not _skin_colours(coord, "Hull", InteriorKit.Batch.HULL).is_empty():
			other = coord
			break
	assert_true(_all_near(_skin_colours(cell, "Hull", InteriorKit.Batch.HULL), HullPalette.UNHURT), "as built")
	_set_health(_section_of(cell), 0.55)
	await wait_process_frames(3)
	var stage := BlockDamage.stage_of(_ship.grid.get_block(cell), _ship.catalog.get_def(&"hull"))
	assert_true(_all_near(_skin_colours(cell, "Hull", InteriorKit.Batch.HULL), _ship.exterior_builder.stage_colour(stage)),
		"its stage colour")
	assert_true(_all_near(_skin_colours(other, "Hull", InteriorKit.Batch.HULL), HullPalette.UNHURT), "%s untouched" % other)

func test_damaged_hull_blocks_spit_sparks_and_mended_ones_stop():
	assert_eq(_ship.damage_show.spitting(), 0)
	_set_health(&"port_mid", 0.7)
	assert_gt(_ship.damage_show.spitting(), 0)
	_set_health(&"port_mid", 1.0)
	assert_eq(_ship.damage_show.spitting(), 0)

func test_the_spits_never_hold_the_floating_origin():
	_all_sections(0.3)
	var spits := []
	for e: Dictionary in _ship.damage_show._spitting.values() + _ship.damage_show._inside.values():
		spits.append(e["emitter"])
	assert_gt(spits.size(), 0)
	for node in get_tree().get_nodes_in_group(Universe.HOLDS_SHIFT):
		assert_false(spits.has(node), "a spit in its own frame does not hold the shift")

# --- the cabin (spec §5) ----------------------------------------------------------------

func _hull_wall() -> Vector3i:
	for coord: Vector3i in _ship.inner_cells:
		if _ship.grid.has_block(coord) and _ship.grid.get_block(coord).block_id == &"hull":
			return coord
	return Vector3i.ZERO

func _flickers() -> int:
	return _ship.find_children("Flicker", "LightFlicker", true, false).size()

func test_the_cabin_follows_hull_percent():
	var wall := _hull_wall()
	assert_eq(_ship.interior_builder.wear_at(wall, Vector3i.ZERO), 0)
	assert_eq(_ship.damage_show.spitting_inside(), 0)
	_all_sections(0.6)
	await wait_physics_frames(2)
	assert_eq(_ship.interior_builder.wear_at(wall, Vector3i.ZERO), 0, "over 50%: as built")
	_all_sections(0.4)
	await wait_physics_frames(2)
	assert_eq(_ship.interior_builder.wear_at(wall, Vector3i.ZERO), 1, "scorched")
	assert_eq(_ship.damage_show.spitting_inside(), DamageShow.CABIN_SPITS[1])
	assert_eq(_flickers(), 0, "steady")
	_all_sections(0.1)
	await wait_physics_frames(2)
	assert_eq(_ship.interior_builder.wear_at(wall, Vector3i.ZERO), 2, "charred")
	assert_eq(_ship.damage_show.spitting_inside(), DamageShow.CABIN_SPITS[2])
	assert_gt(_flickers(), 0, "the lights flicker under 20%")
	_all_sections(1.0)
	await wait_physics_frames(2)
	assert_eq(_ship.interior_builder.wear_at(wall, Vector3i.ZERO), 0)
	assert_eq(_ship.damage_show.spitting_inside(), 0)
	assert_eq(_flickers(), 0, "welded whole: steady")

func test_one_wrecked_section_alone_leaves_the_cabin_as_built():
	_set_health(&"port_bow", 0.0)
	await wait_physics_frames(2)
	assert_gt(_ship.hull_whole(), 0.5)
	assert_eq(_ship.interior_builder.wear_at(_hull_wall(), Vector3i.ZERO), 0)
	assert_eq(_flickers(), 0)

func test_a_component_inside_shows_its_own_stage():
	var core: Vector3i = _components_of(&"quantum_core")[0]
	_ship.take_damage(core, _ship.damage.component_hp[&"quantum_core"] * 0.6)
	await wait_physics_frames(2)
	assert_eq(_ship.interior_builder.wear_at(core, Vector3i.ZERO), 1)

## However hard the ship is hit, the cabin keeps its shape -- every walkable
## cell, every room and pod, the helm -- and only the sections' pieces break
## away. (The owner crashed onto a planet and was left in a room with the
## chair, unable to sit back down.)
func test_the_cabin_keeps_its_shape_however_hard_it_is_hit():
	var layout := _ship.interior_builder.layout()
	var walk_before: Array = _ship.interior_builder.walkable_coords().duplicate()
	var pods_before := layout.pods()
	var rooms_before := layout.rooms().size()
	var hits := {}
	for coord: Vector3i in _ship.grid.coords():
		hits[coord] = 100_000.0
	_ship.take_damage_many(hits)
	assert_eq(_ship.hull_whole(), 0.0)
	assert_eq(_ship.interior_builder.walkable_coords().size(), walk_before.size(), "every walkable cell")
	for cell in walk_before:
		assert_true(_ship.grid.has_block(cell), "%s is still there" % cell)
	assert_eq(_ship.interior_builder.layout().pods(), pods_before, "the cockpit pod")
	assert_eq(_ship.interior_builder.layout().rooms().size(), rooms_before, "every room")
	assert_eq(_ship.grid.size(), _ship.damage.launch.size() - _ship.damage.lost().size(), "only the pieces")
	for coord: Vector3i in _ship.inner_cells:
		assert_true(_ship.grid.has_block(coord), "the shell's %s" % coord)

func test_a_save_with_holes_in_the_cabin_gets_its_shell_back():
	var deck := Vector3i.ZERO
	for c: Vector3i in _ship.interior_builder.walkable_coords():
		if _ship.grid.get_block(c).block_id == &"deck":
			deck = c
			break
	var holed := ShipBlueprint.from_grid(_ship.grid, "Holed").to_grid()
	holed.clear_block(deck)
	_ship.set_grid(holed, false)
	assert_true(_ship.grid.has_block(deck), "put back")
	assert_gt(_ship.damage.section_damage[_ship.damage.part_of(deck)], 0.0, "its section took the hole's hp")
	assert_true(_ship.interior_builder.walkable_coords().has(deck))

# --- the band (spec §7) -------------------------------------------------------------------

func test_the_hull_reads_whole_then_less_and_reaches_the_band():
	var t: VehicleTelemetry = _ship.flight_computer.build_telemetry()
	assert_true(t.has_hull)
	assert_eq(t.hull, 1.0)
	assert_eq(t.crippled_reason, "")
	_set_health(&"port_mid", 0.0)
	assert_lt(_ship.hull_whole(), 1.0)
	assert_almost_eq(_ship.flight_computer.build_telemetry().hull, _ship.hull_whole(), 0.0001)

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

