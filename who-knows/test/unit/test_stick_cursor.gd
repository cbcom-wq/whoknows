extends GutTest

## The stick and the pointer on the HUD (flight controls spec §8).

func _cursor() -> StickCursor:
	var c := StickCursor.new()
	add_child_autofree(c)
	c.size = Vector2(1280.0, 720.0)
	return c

func _t(stick: Vector2, pointing := false, pointer := Vector2.ZERO) -> VehicleTelemetry:
	var t := VehicleTelemetry.new()
	t.stick = stick
	t.stick_radius = PilotStick.RADIUS
	t.stick_deadzone = PilotStick.DEADZONE
	t.pointing = pointing
	t.pointer = pointer
	return t

func test_a_centred_stick_draws_nothing():
	var c := _cursor()
	c.render(_t(Vector2.ZERO))
	assert_true(c.armed)
	assert_false(c.show_stick)

func test_a_deflected_stick_sits_where_it_is_held():
	var c := _cursor()
	c.render(_t(Vector2(0.1, -0.05)))
	assert_true(c.show_stick)
	assert_almost_eq(c.stick_at, Vector2(640.0 + 72.0, 360.0 - 36.0), Vector2.ONE * 0.01)

func test_point_mode_draws_the_pointer_and_the_hint():
	var c := _cursor()
	c.render(_t(Vector2.ZERO, true, Vector2(-0.1, 0.0)))
	assert_true(c.pointing)
	assert_false(c.show_stick)
	assert_true(c.hint.visible)
	assert_almost_eq(c.pointer_at, Vector2(640.0 - 72.0, 360.0), Vector2.ONE * 0.01)

func test_no_vehicle_draws_nothing():
	var c := _cursor()
	c.render(_t(Vector2(0.1, 0.0), true))
	c.render(null)
	assert_false(c.armed)
	assert_false(c.show_stick)
	assert_false(c.hint.visible)

func test_it_ignores_the_mouse():
	var c := _cursor()
	assert_eq(c.mouse_filter, Control.MOUSE_FILTER_IGNORE)
	assert_eq(c.hint.mouse_filter, Control.MOUSE_FILTER_IGNORE)

## Rendered, the bare hint sat on the cream canopy frame and could not be read:
## it carries the HUD band's dark backdrop so it reads over anything.
func test_the_hint_sits_on_the_hud_backdrop():
	var c := _cursor()
	var box := c.hint.get_theme_stylebox("normal") as StyleBoxFlat
	assert_not_null(box)
	assert_eq(box.bg_color, HudPalette.BACKDROP)
