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

func test_hatch_brings_its_light():
	InteriorProps.hatch(_kit, Transform3D.IDENTITY)
	_assert_built()
	assert_eq(_lights(&"hatch").size(), 1)

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
	_built_with_colliders(1)
	assert_almost_eq((_colliders()[0].shape as BoxShape3D).size.y, 1.7, 0.001, "two tiers")

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
	_built_with_colliders(1)

func test_shelves_are_solid():
	InteriorProps.shelves(_kit, Transform3D.IDENTITY, 0.6)
	_built_with_colliders(1)

func test_weapon_rack_and_ammo_are_solid():
	InteriorProps.weapon_rack(_kit, Transform3D.IDENTITY, 0.3)
	InteriorProps.ammo_crates(_kit, InteriorKit.at(Vector3(3, 0, 0)), 0.3)
	_built_with_colliders(2)

func test_door_frame_is_lit_and_leaves_the_opening_clear():
	InteriorProps.door_frame(_kit, Transform3D.IDENTITY)
	_built_with_colliders(0)
	assert_eq(_lights(&"door").size(), 1)

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
