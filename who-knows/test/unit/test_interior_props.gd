extends GutTest

## The reuse contract: every prop builds in a bare frame with no grid, no
## layout and no builder -- exactly what a future blueprint generator gives it.

var _root: Node3D
var _body: StaticBody3D
var _kit: InteriorKit

func before_each():
	_body = StaticBody3D.new()
	add_child_autofree(_body)
	_root = Node3D.new()
	_body.add_child(_root)
	_kit = InteriorKit.new(_root, _body)

func _colliders() -> Array:
	return _body.get_children().filter(func(n): return n is CollisionShape3D)

func _lights(role: StringName) -> Array:
	return _root.get_children().filter(
		func(n): return n is OmniLight3D and n.get_meta(&"role", &"") == role)

func _assert_built() -> void:
	assert_gt(_kit.commit().size(), 0, "the prop added geometry")
	for c in _colliders():
		assert_gt(c.position.z, 0.0, "colliders stand in the room, in front of the wall")

func test_prop_dimensions_match_the_ship_grid():
	assert_eq(InteriorProps.BAY, ShipGrid.CELL_SIZE)
	assert_almost_eq(InteriorProps.HEADROOM, InteriorBuilder.STOREY_HEIGHT - InteriorBuilder.FLOOR_THICKNESS, 0.0001)
	assert_almost_eq(InteriorProps.WALL_THICKNESS, InteriorBuilder.FLOOR_THICKNESS, 0.0001)

func test_porthole_frame_hides_the_square_opening():
	assert_gte(InteriorProps.PORTHOLE_OPENING, InteriorProps.PORTHOLE_RADIUS,
		"the square is at least as wide as the glass")
	assert_lt(InteriorProps.PORTHOLE_OPENING * sqrt(2.0), InteriorProps.PORTHOLE_FRAME_RADIUS,
		"the ring covers the square's corners")

func test_wall_trim_builds_without_a_grid():
	InteriorProps.wall_trim(_kit, Transform3D.IDENTITY)
	_assert_built()
	assert_eq(_colliders().size(), 0, "trim is flush enough to brush past")

func test_ceiling_light_brings_its_light():
	InteriorProps.ceiling_light(_kit, Vector3(0, 1.9, 0))
	_assert_built()
	assert_eq(_lights(&"ceiling").size(), 1)

## What runs along a ceiling keeps clear of its lights by the published rim.
func test_a_ceiling_lights_rim_is_as_published():
	InteriorProps.ceiling_light(_kit, Vector3(0, 1.9, 0))
	var box := AABB()
	for mi in _kit.commit():
		box = mi.mesh.get_aabb() if box.size == Vector3.ZERO else box.merge(mi.mesh.get_aabb())
	assert_almost_eq(box.end.x, InteriorProps.CEILING_LIGHT_RIM, 0.001)
	assert_almost_eq(box.end.z, InteriorProps.CEILING_LIGHT_RIM, 0.01)

func test_console_is_solid_and_lit():
	InteriorProps.console(_kit, Transform3D.IDENTITY, 0.4)
	_assert_built()
	assert_eq(_colliders().size(), 1)
	assert_eq(_lights(&"console").size(), 1)

func test_lockers_and_display_are_flat_enough_to_need_no_collider():
	InteriorProps.lockers(_kit, Transform3D.IDENTITY, 0.2)
	InteriorProps.display(_kit, InteriorKit.at(Vector3(3, 0, 0)), 0.7)
	_assert_built()
	assert_eq(_colliders().size(), 0)

func test_porthole_builds_frame_and_glass():
	InteriorProps.porthole(_kit, Transform3D.IDENTITY)
	var names := _kit.commit().map(func(mi): return String(mi.name))
	assert_has(names, "DressingSolid", "the frame")
	assert_has(names, "DressingPortals", "glass showing the real view outside")
	assert_has(names, "DressingGlass", "the glint")

## Airlock spec §3.3, §3.5: the airlock's pieces build in bare frames.
func test_hatch_frame_builds_and_is_flush_enough_to_brush_past():
	InteriorProps.hatch_frame(_kit, Transform3D.IDENTITY)
	assert_gt(_kit.commit().size(), 0)
	assert_eq(_colliders().size(), 0)

func test_airlock_wall_builds_with_its_nozzles():
	InteriorProps.airlock_wall(_kit, Transform3D.IDENTITY, 0.3)
	_assert_built()
	assert_eq(_colliders().size(), 0)
	var jets := InteriorProps.nozzle_frames(Transform3D.IDENTITY)
	assert_eq(jets.size(), InteriorProps.NOZZLES_PER_WALL)
	for j in jets:
		var along := j.basis * Vector3.FORWARD
		assert_gt(along.z, 0.0, "jets point into the room")
		assert_gt(along.y, 0.0, "and upward")

func test_airlock_ceiling_brings_its_light():
	var light := InteriorProps.airlock_ceiling(_kit, InteriorKit.at(Vector3(0, InteriorProps.AIRLOCK_CLEAR, 0)))
	_assert_built()
	assert_not_null(light)
	assert_eq(_lights(&"airlock").size(), 1)
	assert_lt(light.position.y, InteriorProps.AIRLOCK_CLEAR, "the light hangs below the ceiling")

func test_props_honour_a_rotated_frame():
	var f := Transform3D(Basis(Vector3.UP, PI * 0.5), Vector3(5, 0, 5))
	InteriorProps.console(_kit, f, 0.1)
	var c: CollisionShape3D = _colliders()[0]
	var local := f.affine_inverse() * c.position
	assert_gt(local.z, 0.0, "still in front of its wall, in the wall's own frame")

func test_nose_builds_a_rounded_shell_the_width_of_its_group():
	var shell := InteriorProps.nose(_kit, Transform3D.IDENTITY, 6.0, InteriorMaterials.canopy_fallback())
	var box := shell.mesh.get_aabb()
	assert_almost_eq(box.size.x, 6.0, 0.01)
	assert_almost_eq(box.size.y, InteriorProps.HEADROOM, 0.01)
	assert_almost_eq(box.size.z, InteriorProps.NOSE_DEPTH, 0.01, "bulges forward, away from the room")
	assert_lt(box.position.z, -1.0, "forward is -z in the nose's frame")

func test_nose_pushes_its_windows_and_colours_to_the_material():
	var m: ShaderMaterial = InteriorMaterials.canopy_fallback().duplicate()
	InteriorProps.nose(_kit, Transform3D.IDENTITY, 6.0, m)
	assert_eq(m.get_shader_parameter(&"window_0"), InteriorProps.NOSE_WINDOWS[0])
	assert_eq(m.get_shader_parameter(&"shell_color"), InteriorPalette.WALL)

func test_nose_has_a_cockpit_light():
	InteriorProps.nose(_kit, Transform3D.IDENTITY, 6.0, InteriorMaterials.canopy_fallback())
	assert_eq(_lights(&"cockpit").size(), 1)

func test_a_narrow_nose_still_builds():
	var shell := InteriorProps.nose(_kit, Transform3D.IDENTITY, 2.0, null)
	assert_not_null(shell)
	assert_true(shell.material_override is ShaderMaterial, "null material falls back, never a hole")

func _built_with_colliders(expected: int) -> void:
	_assert_built()
	assert_eq(_colliders().size(), expected)

func test_bunks_are_solid():
	InteriorProps.bunks(_kit, Transform3D.IDENTITY, 0.3, false)
	# Two blocks, not one: the lower bunk is solid only to its mattress, so the
	# Interactor can reach what lies on it, and the upper bunk has its own.
	_built_with_colliders(2)
	var tops := _colliders().map(func(c): return c.position.y + (c.shape as BoxShape3D).size.y * 0.5)
	assert_almost_eq(tops.min(), InteriorProps.BUNK_MATTRESS_TOP, 0.001, "the lower bunk")
	assert_almost_eq(tops.max(), 1.7, 0.001, "two tiers")

func test_a_low_bunk_leaves_room_for_a_porthole():
	InteriorProps.bunks(_kit, Transform3D.IDENTITY, 0.3, true)
	_built_with_colliders(1)
	var top := (_colliders()[0].shape as BoxShape3D).size.y
	assert_lt(top, InteriorProps.PORTHOLE_HEIGHT - InteriorProps.PORTHOLE_FRAME_RADIUS)

func test_tall_lockers_are_flat():
	InteriorProps.tall_lockers(_kit, Transform3D.IDENTITY, 0.3)
	_built_with_colliders(0)

func test_galley_counter_and_fridge_are_solid():
	InteriorProps.galley_counter(_kit, Transform3D.IDENTITY, 0.3, false)
	InteriorProps.fridge(_kit, InteriorKit.at(Vector3(3, 0, 0)), 0.3)
	_built_with_colliders(2)

func test_washstand_is_solid_and_the_towel_rail_is_not():
	InteriorProps.washstand(_kit, Transform3D.IDENTITY, 0.3)
	InteriorProps.towel_rail(_kit, InteriorKit.at(Vector3(3, 0, 0)), 0.3)
	# Two blocks, not one: the toilet's is low, so the Interactor can reach its
	# lid and the button under it (ToiletLid); the sink's is its full height.
	_built_with_colliders(2)

func test_the_toilet_s_collider_stops_under_the_button_in_its_bowl():
	InteriorProps.washstand(_kit, Transform3D.IDENTITY, 0.3)
	var tops := _colliders().map(func(c): return c.position.y + (c.shape as BoxShape3D).size.y * 0.5)
	assert_lte(tops.min(), InteriorProps.toilet_button().origin.y, "the toilet's")
	assert_almost_eq(tops.max(), 0.9, 0.001, "the sink's")

func test_the_shut_lid_rests_on_the_seat_over_the_button():
	var hinge := InteriorProps.toilet_hinge()
	var underside := hinge.origin.y - InteriorProps.TOILET_LID.y * 0.5
	assert_gte(underside, InteriorProps.TOILET_SEAT_TOP, "on the seat, not in it")
	assert_lt(underside - InteriorProps.TOILET_SEAT_TOP, 0.01, "and not floating over it")
	var button := InteriorProps.toilet_button()
	assert_almost_eq(button.basis.z, Vector3.UP, Vector3.ONE * 0.001, "the button faces up out of the bowl")
	# A ReadoutPanel's lit button stands 0.012 m proud of its face.
	assert_lt(button.origin.y + InteriorProps.TOILET_BUTTON.z + 0.012, underside, "and the shut lid clears it")
	var front := hinge.origin.z + InteriorProps.TOILET_LID.z
	assert_between(button.origin.z, hinge.origin.z, front, "under the lid")

func test_the_lifted_lid_clears_the_cistern():
	var hinge := InteriorProps.toilet_hinge()
	assert_gt(hinge.origin.z - InteriorProps.TOILET_LID.y * 0.5, InteriorProps.TOILET_TANK_DEPTH)

func test_the_toilet_lid_builds_in_its_hinge_frame():
	InteriorProps.toilet_lid(_kit, Transform3D.IDENTITY)
	var box := AABB()
	for mi in _kit.commit():
		box = mi.mesh.get_aabb()
	assert_almost_eq(box.size, InteriorProps.TOILET_LID, Vector3.ONE * 0.001)
	assert_almost_eq(box.position.z, 0.0, 0.001, "from the hinge line forward")
	assert_eq(_colliders().size(), 0, "ToiletLid gives it a hit box, not a collider")

func test_shelves_are_solid():
	InteriorProps.shelves(_kit, Transform3D.IDENTITY, 0.6)
	# Two posts and four boards, not one block: a single box would stop the
	# Interactor's ray before it reached anything stowed on a shelf.
	_built_with_colliders(6)

## Is `p` inside any of this prop's colliders? Frames here are the identity,
## so every collider is an axis-aligned box.
func _inside_a_collider(p: Vector3) -> bool:
	for c in _colliders():
		var size := (c.shape as BoxShape3D).size
		var local: Vector3 = c.transform.affine_inverse() * p
		if absf(local.x) < size.x * 0.5 and absf(local.y) < size.y * 0.5 and absf(local.z) < size.z * 0.5:
			return true
	return false

func _assert_spots_clear(spots: Array, classes: Array) -> void:
	assert_eq(spots.map(func(s): return s[1]), classes)
	for spot in spots:
		var xf: Transform3D = spot[0]
		assert_gt(xf.origin.z, 0.0, "a spot stands in front of the wall")
		assert_false(_inside_a_collider(xf * Vector3(0, 0.05, 0)),
			"a spot is clear of its prop's colliders, so the Interactor can reach what sits there")

func test_the_weapon_rack_has_two_pistol_cradles():
	InteriorProps.weapon_rack(_kit, Transform3D.IDENTITY, 0.3)
	_assert_built()
	_assert_spots_clear(InteriorProps.weapon_rack_spots(), [&"sidearm", &"sidearm"])

func test_the_galley_counter_holds_two_small_things():
	InteriorProps.galley_counter(_kit, Transform3D.IDENTITY, 0.3, false)
	_assert_built()
	_assert_spots_clear(InteriorProps.galley_counter_spots(), [&"small", &"small"])

func test_full_shelves_hold_small_things_tools_a_crate_and_a_pile_of_plates():
	InteriorProps.shelves(_kit, Transform3D.IDENTITY, 0.6, 1.7)
	_assert_built()
	_assert_spots_clear(InteriorProps.shelves_spots(1.7),
		[&"small", &"small", &"plate", &"plate", &"plate", &"crate", &"small", &"small", &"small", &"tool", &"tool", &"tool"])

func test_the_plates_pile_up_one_on_another():
	var plates := InteriorProps.shelves_spots(1.7).filter(func(s): return s[1] == &"plate")
	assert_eq(plates.size(), InteriorProps.PLATE_STACK)
	var plate := ItemCatalog.load_from_dir().get_def(&"scrap_plate")
	assert_eq(plate.stow_class, &"plate")
	for i in plates.size():
		var at: Vector3 = (plates[i][0] as Transform3D).origin
		var first: Vector3 = (plates[0][0] as Transform3D).origin
		assert_almost_eq(at, first + Vector3.UP * InteriorProps.PLATE_LIFT * i, Vector3.ONE * 0.0001)
	assert_gt(InteriorProps.PLATE_LIFT, plate.size.y, "a plate clears the one below")

func test_narrow_shelves_hold_small_things_and_a_crate():
	InteriorProps.shelves(_kit, Transform3D.IDENTITY, 0.6, 0.85)
	_assert_built()
	_assert_spots_clear(InteriorProps.shelves_spots(0.85), [&"small", &"small", &"small", &"crate"])

func test_shelf_spots_do_not_overlap():
	for width in [1.7, 0.85]:
		var spots := InteriorProps.shelves_spots(width)
		for i in spots.size():
			for j in range(i + 1, spots.size()):
				var a: Vector3 = (spots[i][0] as Transform3D).origin
				var b: Vector3 = (spots[j][0] as Transform3D).origin
				if absf(a.y - b.y) < 0.01:
					assert_gt(absf(a.x - b.x), 0.2, "spots %d and %d on a %s m shelf are apart" % [i, j, width])

func test_shelf_spots_sit_on_the_boards():
	for spot in InteriorProps.shelves_spots(1.7):
		if spot[1] == &"plate":
			continue
		var y: float = (spot[0] as Transform3D).origin.y
		assert_true(is_equal_approx(y, InteriorProps.shelf_top(0)) or is_equal_approx(y, InteriorProps.shelf_top(1))
			or is_equal_approx(y, InteriorProps.shelf_top(2)), "on a board top")

func test_weapon_rack_and_ammo_are_solid():
	InteriorProps.weapon_rack(_kit, Transform3D.IDENTITY, 0.3)
	InteriorProps.ammo_crates(_kit, InteriorKit.at(Vector3(3, 0, 0)), 0.3)
	_built_with_colliders(2)

func test_door_frame_is_lit_and_leaves_the_opening_clear():
	InteriorProps.door_frame(_kit, Transform3D.IDENTITY)
	_built_with_colliders(0)
	assert_eq(_lights(&"door").size(), 1)

## What runs over a doorway keeps above its lit header, whose top is published.
func test_a_door_frames_header_tops_out_as_published():
	InteriorProps.door_frame(_kit, Transform3D.IDENTITY)
	var top := -INF
	for mi in _kit.commit():
		top = maxf(top, mi.mesh.get_aabb().end.y)
	assert_almost_eq(top, InteriorProps.DOOR_HEIGHT + InteriorProps.DOOR_HEADER, 0.001)

func test_every_room_has_a_floor_colour():
	for id in InteriorLayout.ROOM_IDS:
		assert_true(InteriorPalette.ROOM_FLOOR.has(id), "%s has a floor colour" % id)

## Standing eyes are at 1.6 m: portholes are for looking out of.
func test_portholes_sit_at_eye_level():
	assert_between(InteriorProps.PORTHOLE_HEIGHT, 1.35, 1.6)
	assert_lt(InteriorProps.PORTHOLE_HEIGHT + InteriorProps.PORTHOLE_FRAME_RADIUS, InteriorProps.HEADROOM - 0.3,
		"clear of the light shelf")

func test_doors_are_door_height_not_ceiling_height():
	assert_between(InteriorProps.DOOR_HEIGHT, 2.0, InteriorProps.HEADROOM - 0.2)

func _batch_names() -> Array:
	return _kit.commit().map(func(mi): return String(mi.name))

## Cockpit pod spec §4: the pod builds in its own frame, jutting out along -z,
## and brings everything that stops the avatar -- the builder leaves its mouth
## open.
func test_cockpit_pod_builds_its_own_floor_roof_and_walls():
	InteriorProps.cockpit_pod(_kit, Transform3D.IDENTITY)
	assert_has(_batch_names(), "DressingPortals", "the glazing shows the real view outside")
	assert_eq(_colliders().size(), 2 + InteriorProps.POD_OUTLINE.size() - 1,
		"a floor, a roof and a wall per outline segment")
	for c in _colliders():
		assert_lt(c.position.z, 0.0, "all of it beyond the canopy plane, out in the pod")
	assert_eq(_lights(&"ceiling").size(), 1)

func test_the_pod_mouth_is_one_cell_face_wide():
	assert_eq(InteriorProps.POD_OUTLINE[0], Vector2(-InteriorProps.BAY * 0.5, 0.0))
	assert_eq(InteriorProps.POD_OUTLINE[-1], Vector2(InteriorProps.BAY * 0.5, 0.0))

func test_the_pod_glazing_sits_between_a_low_sill_and_a_roof_under_the_ceiling():
	assert_lt(InteriorProps.POD_SILL, InteriorProps.SEATED_EYE.y - 0.5, "a seated pilot sees well down past it")
	assert_lt(InteriorProps.POD_GLASS_TOP, InteriorProps.POD_ROOF)
	assert_lt(InteriorProps.POD_ROOF, InteriorProps.HEADROOM, "a header closes the mouth above it")

func test_shoulder_has_a_portal_window_and_a_console_desk():
	InteriorProps.shoulder(_kit, Transform3D.IDENTITY, 0.4)
	assert_has(_batch_names(), "DressingPortals")
	assert_eq(_colliders().size(), 1, "the desk")
	assert_eq(_lights(&"console").size(), 1)

func _screen_vertices() -> int:
	for mi in _kit.commit():
		if mi.material_override == InteriorMaterials.screen():
			return mi.mesh.surface_get_array_len(0)
	return 0

func test_a_console_can_leave_off_its_wall_screen():
	InteriorProps.console(_kit, Transform3D.IDENTITY, 0.4)
	var both := _screen_vertices()
	InteriorProps.console(_kit, Transform3D.IDENTITY, 0.4, false)
	assert_eq(_screen_vertices(), both / 2, "the desk screen stays, the wall screen goes")

## Cockpit pod spec §5: the captain's chair and helm console, in a fixture
## frame -- origin on the floor under the seat, -z the way it faces.
func test_pilot_station_builds_without_a_grid():
	InteriorProps.pilot_station(_kit, Transform3D.IDENTITY, 0.5)
	assert_gt(_kit.commit().size(), 0)
	assert_eq(_colliders().size(), 1, "the helm console; the seat's interactable box covers the chair")
	assert_lt(_colliders()[0].position.z, 0.0, "the helm stands ahead of the chair")
	assert_eq(_lights(&"helm").size(), 1)

## Seated in a pod, the pilot must see the bottom of the front glass over the
## helm console.
func test_the_helm_stays_under_the_seated_sightline():
	InteriorProps.pilot_station(_kit, Transform3D.IDENTITY, 0.5)
	var c: CollisionShape3D = _colliders()[0]
	var half := (c.shape as BoxShape3D).size * 0.5
	var helm_top := c.position.y + half.y
	var helm_front := c.position.z - half.z
	var front_glass := InteriorProps.POD_OUTLINE[3].y + InteriorProps.POD_SEAT_DEPTH
	var eye := InteriorProps.SEATED_EYE
	var t := (eye.z - helm_front) / (eye.z - front_glass)
	assert_lt(helm_top, lerpf(eye.y, InteriorProps.POD_SILL, t))

## Airlock spec §3.2: the airlock matches the hull's 2 m cell, and its hatches
## still pass the 1.8 m avatar.
func test_the_airlock_fits_the_hull_cell_and_the_avatar():
	assert_almost_eq(InteriorProps.AIRLOCK_CLEAR, ShipGrid.CELL_SIZE - InteriorBuilder.FLOOR_THICKNESS, 0.0001)
	assert_lt(InteriorProps.HATCH_HEIGHT, InteriorProps.AIRLOCK_CLEAR)
	assert_gt(InteriorProps.HATCH_HEIGHT, Avatar.STAND_HEIGHT)

func test_the_ammo_stack_holds_two_flares_on_top():
	InteriorProps.ammo_crates(_kit, Transform3D.IDENTITY, 0.3)
	_assert_built()
	_assert_spots_clear(InteriorProps.ammo_crates_spots(), [&"tool", &"tool"])

func test_the_washstand_has_a_bracket_for_a_medkit():
	InteriorProps.washstand(_kit, Transform3D.IDENTITY, 0.3)
	_built_with_colliders(2)
	_assert_spots_clear(InteriorProps.washstand_spots(), [&"tool"])

## Quantum energy spec §6.2: the core, in a bare fixture frame -- origin on
## the floor under it, -z the way it faces.
func test_the_quantum_core_builds_in_a_bare_fixture_frame():
	InteriorProps.quantum_core(_kit, Transform3D.IDENTITY, 0.5)
	var names := _batch_names()
	assert_has(names, "DressingSolid", "the plinth, the crown and the spine")
	assert_has(names, "DressingGlass", "the column is glass")
	assert_has(names, "DressingGlow", "the plinth's glowing base")
	assert_eq(_colliders().size(), 1)

func test_the_quantum_cores_collider_is_a_square_the_full_height():
	InteriorProps.quantum_core(_kit, Transform3D.IDENTITY, 0.5)
	var c: CollisionShape3D = _colliders()[0]
	var size := (c.shape as BoxShape3D).size
	assert_almost_eq(size, Vector3(1.1, InteriorProps.HEADROOM, 1.1), Vector3.ONE * 0.0001)
	assert_almost_eq(c.position, Vector3(0, InteriorProps.HEADROOM * 0.5, 0), Vector3.ONE * 0.0001,
		"centred in its frame, floor to ceiling")
	assert_almost_eq(InteriorProps.QUANTUM_CORE_FOOTPRINT, 1.2, 0.0001)

## Spec §6.1: the crown carries its cell's light, the same as a ring light's.
func test_the_quantum_cores_crown_carries_the_cells_light():
	InteriorProps.quantum_core(_kit, Transform3D.IDENTITY, 0.5)
	var lights := _lights(InteriorProps.CELL_LIGHT_ROLE)
	assert_eq(lights.size(), 1)
	var l: OmniLight3D = lights[0]
	assert_almost_eq(l.position, InteriorProps.quantum_core_crown_light(), Vector3.ONE * 0.0001)
	assert_almost_eq(l.light_energy, InteriorProps.CELL_LIGHT_ENERGY, 0.0001)
	assert_almost_eq(l.omni_range, InteriorProps.CELL_LIGHT_RANGE, 0.0001)
	assert_eq(l.light_color, InteriorPalette.LIGHT_WARM)

func test_a_ring_light_is_a_cell_light():
	InteriorProps.ceiling_light(_kit, Vector3(0, 2.5, 0))
	var l: OmniLight3D = _lights(InteriorProps.CELL_LIGHT_ROLE)[0]
	assert_almost_eq(l.light_energy, InteriorProps.CELL_LIGHT_ENERGY, 0.0001)
	assert_almost_eq(l.omni_range, InteriorProps.CELL_LIGHT_RANGE, 0.0001)

## The crown hangs from the ceiling whatever the storey (style guide §3.2).
func test_the_quantum_cores_crown_follows_the_headroom():
	InteriorProps.quantum_core(_kit, Transform3D.IDENTITY, 0.5)
	var top := -INF
	for mi in _kit.commit():
		top = maxf(top, mi.mesh.get_aabb().end.y)
	assert_almost_eq(top, InteriorProps.HEADROOM, 0.001)

## Its gauge runs up the spine on its facing side (-z), ten bars.
func test_the_quantum_cores_gauge_is_ten_bars_up_its_facing_side():
	var bars := InteriorProps.quantum_core_bars()
	assert_eq(bars.size(), 10)
	for i in bars.size():
		var at := bars[i].origin
		assert_lt(at.z, -0.4, "on the facing side")
		assert_gt(Vector2(at.x, at.z).length(), InteriorProps.QUANTUM_CORE_GLASS * 0.5 / cos(PI / 8.0),
			"outside the glass")
		assert_lt(maxf(absf(at.x), absf(at.z)), InteriorProps.QUANTUM_CORE_COLLIDER * 0.5, "inside the collider")
		assert_lt((bars[i].basis * Vector3.BACK).z, -0.8, "facing out, the way the core faces")
		if i > 0:
			assert_gt(bars[i].origin.y, bars[i - 1].origin.y, "bar %d above bar %d" % [i, i - 1])

## Quantum energy spec §6.3: the machine, in a bare wall frame.
func test_the_quantum_machine_builds_in_a_bare_wall_frame():
	InteriorProps.quantum_machine(_kit, Transform3D.IDENTITY, 0.5)
	_assert_built()
	assert_eq(_colliders().size(), 4, "built round the bay: below, above and either side of it")
	var lo := INF
	var hi := -INF
	for c in _colliders():
		var half := (c.shape as BoxShape3D).size.x * 0.5
		lo = minf(lo, c.position.x - half)
		hi = maxf(hi, c.position.x + half)
	assert_almost_eq(hi - lo, InteriorProps.QUANTUM_MACHINE_WIDTH, 0.001)
	assert_almost_eq(InteriorProps.QUANTUM_MACHINE_WIDTH, 1.5, 0.0001)

## The Interactor must reach what sits in the bay (style guide §3): the
## largest thing it takes, 0.55 m on a side (spec §7.1), floats clear of
## every collider.
func test_the_bay_is_clear_of_the_machines_colliders():
	InteriorProps.quantum_machine(_kit, Transform3D.IDENTITY, 0.5)
	var bay := InteriorProps.quantum_machine_bay()
	assert_gt(bay.origin.z, 0.0)
	for c in _colliders():
		var size := (c.shape as BoxShape3D).size
		var gap: Vector3 = (c.position - bay.origin).abs() - (size + Vector3.ONE * 0.55) * 0.5
		assert_true(gap.x >= 0.0 or gap.y >= 0.0 or gap.z >= 0.0,
			"a 0.55 m item in the bay is clear of the collider at %s" % c.position)

func test_the_machines_face_is_on_its_cabinet_front():
	InteriorProps.quantum_machine(_kit, Transform3D.IDENTITY, 0.5)
	var front := InteriorProps.QUANTUM_MACHINE_DEPTH
	var bay := InteriorProps.quantum_machine_bay().origin
	var buttons := InteriorProps.quantum_machine_buttons()
	assert_eq(buttons.size(), 3, "prev, big, next")
	for b in buttons:
		assert_gt(b.origin.x, bay.x + 0.3, "in a column right of the bay")
		assert_between(b.origin.z, front, front + 0.02, "on the cabinet's front")
	assert_gt(buttons[0].origin.y, buttons[1].origin.y, "prev above the big button")
	assert_gt(buttons[1].origin.y, buttons[2].origin.y, "the big button above next")
	var screen := InteriorProps.quantum_machine_screen().origin
	assert_almost_eq(screen.x, bay.x, 0.001, "the screen stands over the bay")
	assert_gt(screen.y, bay.y + 0.3)
	var plate := InteriorProps.quantum_machine_plate().origin
	assert_almost_eq(plate.y, 1.2, 0.001)
	assert_gt(plate.x, buttons[1].origin.x, "the plate at the right-hand end")

func test_the_machines_conduit_leaves_its_top_and_rises_to_the_ceiling():
	var path := InteriorProps.quantum_machine_conduit()
	assert_eq(path.size(), 2)
	assert_almost_eq(path[0].y, InteriorProps.QUANTUM_MACHINE_HEIGHT, 0.001, "out of the cabinet's top")
	assert_almost_eq(path[1].y, InteriorProps.QUANTUM_CONDUIT_HEIGHT, 0.001)
	assert_lt(InteriorProps.QUANTUM_CONDUIT_HEIGHT, InteriorProps.HEADROOM, "under the ceiling")
	assert_almost_eq(Vector2(path[0].x, path[0].z), Vector2(path[1].x, path[1].z), Vector2.ONE * 0.001,
		"straight up")

func test_a_conduit_draws_along_its_path():
	var path := PackedVector3Array([Vector3.ZERO, Vector3(0, 1, 0), Vector3(2, 1, 0)])
	InteriorProps.conduit(_kit, path)
	_built_with_colliders(0)

## With no core to run to, the conduit rises into the ceiling straight over
## where it leaves the cabinet, and a collar shows where it goes in.
func test_the_machines_ceiling_port_is_in_the_ceiling_over_its_conduit():
	var rise := InteriorProps.quantum_machine_conduit()[1]
	var port := InteriorProps.quantum_machine_ceiling_port()
	assert_almost_eq(port.origin, Vector3(rise.x, InteriorProps.HEADROOM, rise.z), Vector3.ONE * 0.0001)
	assert_almost_eq(port.basis * Vector3.BACK, Vector3.DOWN, Vector3.ONE * 0.0001, "+z out of the ceiling, down the pipe")

func test_a_conduit_collar_stands_out_of_its_surface_round_the_pipe():
	var up := Transform3D(Basis(Vector3.RIGHT, Vector3.FORWARD, Vector3.UP), Vector3(0, 2, 0))
	InteriorProps.conduit_collar(_kit, up)
	var box := AABB()
	for mi in _kit.commit():
		box = mi.mesh.get_aabb()
	assert_almost_eq(box.position.y, 2.0, 0.001, "on the surface")
	assert_gt(box.end.y, 2.0, "out of it, along the pipe")
	assert_gt(box.size.x, InteriorProps.CONDUIT_RADIUS * 2.0, "round the pipe")
	assert_almost_eq(box.get_center().x, 0.0, 0.001)
	assert_eq(_colliders().size(), 0, "a collar has no collider")

func test_something_can_lie_on_the_lower_bunk():
	for low_only in [true, false]:
		var body := StaticBody3D.new()
		add_child_autofree(body)
		var root := Node3D.new()
		body.add_child(root)
		_body = body
		_root = root
		_kit = InteriorKit.new(root, body)
		InteriorProps.bunks(_kit, Transform3D.IDENTITY, 0.3, low_only)
		_assert_built()
		_assert_spots_clear(InteriorProps.bunks_spots(), [&"tool"])
		assert_almost_eq((InteriorProps.bunks_spots()[0][0] as Transform3D).origin.y,
			InteriorProps.BUNK_MATTRESS_TOP, 0.001, "on the mattress")

## Bridge computer spec §3.3: the holo table builds in a bare fixture frame,
## solid where you would walk into it and open where the holo hangs.
func test_the_holo_table_builds_in_a_bare_fixture_frame():
	InteriorProps.holo_table(_kit, Transform3D.IDENTITY, 0.3)
	assert_gt(_kit.commit().size(), 0, "the table added geometry")
	assert_eq(_colliders().size(), 2, "the table, and the console's lip")
	assert_eq(_root.get_children().filter(func(n): return n is OmniLight3D).size(), 0, "no light of its own")

func test_nothing_solid_stands_in_the_holo():
	InteriorProps.holo_table(_kit, Transform3D.IDENTITY, 0.3)
	var c := InteriorProps.HOLO_VOLUME_CENTRE
	var volume := AABB(Vector3(-0.5, c - 0.3, -0.5), Vector3(1.0, 0.6, 1.0))
	for shape: CollisionShape3D in _colliders():
		# The console's collider is tilted with the console: bound it as placed.
		var half := (shape.shape as BoxShape3D).size * 0.5
		var box := shape.transform * AABB(-half, half * 2.0)
		assert_false(box.intersects(volume), "a collider reaches into the holo")

func test_the_console_faces_its_operator_and_its_buttons_run_left_to_right():
	var out := InteriorProps.holo_table_console().basis.z
	assert_lt(out.z, 0.0, "the console faces -z, toward the operator")
	assert_gt(out.y, 0.0, "and tilts up toward their eyes")
	var buttons := InteriorProps.holo_table_buttons()
	assert_eq(buttons.size(), 5, "PAGE, RANGE, prev, big, next")
	# The operator faces +z, so their right is -x: PAGE is furthest to +x.
	for i in 4:
		assert_gt(buttons[i].origin.x, buttons[i + 1].origin.x)
	assert_gt(InteriorProps.holo_table_screen().origin.y, buttons[0].origin.y,
		"the screen sits above the buttons")
	for b in buttons:
		assert_almost_eq(b.basis.z, out, Vector3.ONE * 0.0001, "each button faces the operator")

func test_the_holo_volume_hangs_over_the_table():
	var v := InteriorProps.holo_table_volume()
	assert_almost_eq(v.origin, Vector3(0, InteriorProps.HOLO_VOLUME_CENTRE, 0), Vector3.ONE * 0.0001)
	assert_gt(InteriorProps.HOLO_VOLUME_CENTRE - 0.3, InteriorProps.HOLO_TABLE_TOP,
		"the holo's floor is above the table top")

## Nothing solid pokes up through the holo table's black glass.
func test_the_holo_table_s_glass_is_clear():
	InteriorProps.holo_table(_kit, Transform3D.IDENTITY, 0.3)
	var solid: MeshInstance3D = null
	for m in _kit.commit():
		if m.name == "DressingSolid":
			solid = m
	var glass_y := InteriorProps.HOLO_TABLE_TOP - 0.004
	var inner := InteriorProps.HOLO_TABLE_RADIUS - 0.06
	var verts: PackedVector3Array = solid.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
	for v in verts:
		if Vector2(v.x, v.z).length() < inner - 0.01 and v.z > -0.3:
			assert_true(v.y <= glass_y + 0.0001, "a vertex above the glass at %s" % v)
			if v.y > glass_y + 0.0001:
				return

## Computer mode spec §3.1-§3.2: the station's box offers the computer over the
## table, under the holo; its eye stays under the ceiling however high it
## orbits.
func test_the_station_box_stays_under_the_holo():
	var top := InteriorProps.holo_station_shape_centre().y + InteriorProps.HOLO_STATION_SIZE.y * 0.5
	assert_lt(top, InteriorProps.HOLO_VOLUME_CENTRE - 0.3, "under the holo's floor")
	assert_gt(top, InteriorProps.HOLO_TABLE_TOP + 0.05, "above the table's collider")

func test_the_station_eye_looks_into_the_holo_from_the_operator_s_side():
	var eye := InteriorProps.holo_station_eye(InteriorProps.HOLO_STATION_ELEVATION)
	var centre := InteriorProps.holo_table_volume().origin
	assert_almost_eq(eye.origin.distance_to(centre), InteriorProps.HOLO_STATION_DISTANCE, 0.0001)
	assert_lt(eye.origin.z, 0.0, "on the operator's side, -z")
	assert_almost_eq(-eye.basis.z, (centre - eye.origin).normalized(), Vector3.ONE * 0.0001, "looking at the centre")
	assert_almost_eq(eye.origin.y, 1.85, 0.01)

func test_the_station_eye_orbits_under_the_ceiling():
	var high := InteriorProps.holo_station_eye(ComputerStation.ELEVATION_MAX)
	assert_lt(high.origin.y, InteriorProps.HEADROOM - 0.1)
