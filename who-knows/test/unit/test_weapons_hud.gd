extends GutTest

## The weapons on the HUD (ship weapons spec §9.2): the strip's orders and
## pips, and a numbered bracket on each listed target.

func _telemetry(engage: bool, pips: Array[StringName], low := false) -> VehicleTelemetry:
	var t := VehicleTelemetry.new()
	t.has_weapons = true
	t.weapons_engage = engage
	t.weapons_pips = pips
	t.weapons_low_power = low
	return t

func test_the_strip_shows_orders_and_a_pip_a_turret():
	var strip := WeaponsStrip.new()
	add_child_autofree(strip)
	strip.render(_telemetry(true, [&"firing", &"no_arc"] as Array[StringName]))
	assert_true(strip.visible)
	assert_eq(strip.orders_text(), "ENGAGE")
	assert_eq(strip.pip_colours(), [HudPalette.for_pip(&"firing"), HudPalette.for_pip(&"no_arc")])
	strip.render(_telemetry(true, [&"tracking"] as Array[StringName], true))
	assert_eq(strip.orders_text(), "WEAPONS · LOW POWER")

func test_no_turrets_no_strip():
	var strip := WeaponsStrip.new()
	add_child_autofree(strip)
	strip.render(VehicleTelemetry.new())
	assert_false(strip.visible)

func test_every_pip_state_has_a_colour():
	for s in [&"idle", &"tracking", &"firing", &"no_arc", &"damaged", &"low_power", &"wrecked"]:
		assert_true(HudPalette.for_pip(s) is Color)
