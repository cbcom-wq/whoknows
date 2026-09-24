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
	assert_almost_eq(InteriorProps.HEADROOM, ShipGrid.CELL_SIZE - InteriorBuilder.FLOOR_THICKNESS, 0.0001)
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
	assert_has(names, "DressingGlass", "the glass")

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
