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

class StubTurret extends Node3D:
	var target: Node3D
	var no_arc := false
	var state: StringName = &"idle"
	func can_engage(_node: Node3D) -> bool:
		return true
	func muzzle() -> Vector3:
		return global_position

func _brackets_rig() -> Dictionary:
	var world := Node3D.new()
	add_child_autofree(world)
	var cam := Camera3D.new()
	world.add_child(cam)
	cam.make_current()
	var own := Node3D.new()
	world.add_child(own)
	var fc := FireControl.new()
	fc.ship = own
	world.add_child(fc)
	var turret := StubTurret.new()
	world.add_child(turret)
	fc.turrets.append(turret)
	var target := Node3D.new()
	world.add_child(target)
	target.global_position = Vector3(0.0, 0.0, -100.0)
	Weapons.join(target, &"ship:Brk")
	var brackets := TargetBrackets.new()
	world.add_child(brackets)
	brackets.set_camera(cam)
	brackets.fire_control = fc
	fc.mark(&"ship:Brk")
	fc.assign(0.2)
	return {"fc": fc, "target": target, "brackets": brackets}

func test_a_bracket_is_drawn_on_a_listed_target():
	var rig := _brackets_rig()
	var brackets: TargetBrackets = rig["brackets"]
	brackets.render(_telemetry(false, [] as Array[StringName]))
	assert_eq(brackets.marks.size(), 1)
	assert_eq(brackets.marks[0]["index"], 1)
	assert_true(brackets.marks[0]["solid"], "a turret can bear")
	assert_eq(brackets.marks[0]["text"], "1 · 100 M")

func test_a_target_freed_since_the_last_assign_draws_nothing_and_raises_nothing():
	var rig := _brackets_rig()
	var brackets: TargetBrackets = rig["brackets"]
	(rig["target"] as Node3D).free()
	brackets.render(_telemetry(false, [] as Array[StringName]))
	assert_eq(brackets.marks.size(), 0)
	(rig["fc"] as FireControl).assign(0.2)
	brackets.render(_telemetry(false, [] as Array[StringName]))
	assert_eq(brackets.marks.size(), 0)
