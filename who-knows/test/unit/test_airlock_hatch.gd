extends GutTest

## Airlock spec §3.3: heavy leaves with bolts, a window and a light strip, and
## a collider across the opening whenever the hatch is not fully open.

var _body: StaticBody3D

func before_each():
	_body = StaticBody3D.new()
	add_child_autofree(_body)

func _hatch(portal := false) -> AirlockHatch:
	var h := AirlockHatch.new()
	h.setup(InteriorProps.DOOR_WIDTH, InteriorProps.HATCH_HEIGHT, _body, Transform3D.IDENTITY, portal)
	_body.add_child(h)
	return h

func test_a_hatch_is_solid_until_fully_open():
	var h := _hatch()
	assert_not_null(h.collider)
	assert_eq(h.collider.get_parent(), _body, "a shape registers only as the body's direct child")
	assert_false(h.collider.disabled, "shut")
	h.open_amount = 0.5
	assert_false(h.collider.disabled, "half open is still in the way")
	h.open_amount = 1.0
	assert_true(h.collider.disabled, "fully open")
	assert_true(h.is_fully_open())

func test_leaves_part_into_the_jambs():
	var h := _hatch()
	var w := InteriorProps.DOOR_WIDTH
	var shut := h.leaf_offsets()
	assert_almost_eq(shut[0], -w * 0.25, 0.001)
	assert_almost_eq(shut[1], w * 0.25, 0.001)
	h.open_amount = 1.0
	var open := h.leaf_offsets()
	assert_almost_eq(open[0], -w * 0.75, 0.001)
	assert_almost_eq(open[1], w * 0.75, 0.001)

func test_bolts_retract_across_the_seam():
	var h := _hatch()
	var home := h.bolt_offset()
	h.bolts_out = 1.0
	assert_gt(h.bolt_offset(), home + 0.05, "retracted bolts clear the seam")

func test_the_strip_shows_one_state_at_a_time():
	var h := _hatch()
	for state in [&"go", &"cycling", &"vacuum"]:
		h.set_strip(state)
		assert_eq(h.visible_strips(), [state])
	h.set_strip(&"off")
	assert_eq(h.visible_strips(), [])

func test_the_warning_lamp_shows_only_when_asked():
	var h := _hatch()
	assert_false(h.warning_shown())
	h.set_warning(true)
	assert_true(h.warning_shown())

func _batches(h: AirlockHatch) -> Array:
	return h.find_children("Dressing*", "MeshInstance3D", true, false).map(func(m): return String(m.name))

func test_a_portal_window_shows_the_real_outside():
	var names := _batches(_hatch(true))
	assert_true(names.any(func(n): return n.begins_with("DressingPortals")))

func test_a_plain_window_is_glass():
	var names := _batches(_hatch(false))
	assert_false(names.any(func(n): return n.begins_with("DressingPortals")))
	assert_true(names.any(func(n): return n.begins_with("DressingGlass")))

func test_everything_is_on_the_interior_layer():
	var h := _hatch()
	for m in h.find_children("*", "GeometryInstance3D", true, false):
		assert_eq(m.layers, InteriorKit.LAYER)
