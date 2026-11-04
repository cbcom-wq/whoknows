extends GutTest

## The weapons on the HUD (ship weapons spec §9.2): the strip's orders and
## pips, and a numbered bracket on each listed target.

var _saved_orders_keys: Array[InputEvent] = []

func after_each():
	Weapons.hostile_rule = Callable()
	if not _saved_orders_keys.is_empty():
		InputMap.action_erase_events(&"weapons_orders")
		for e in _saved_orders_keys:
			InputMap.action_add_event(&"weapons_orders", e)
		_saved_orders_keys.clear()

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

## Your orders at HOLD while a hostile is out for you (hostile ships spec
## §4.3): the strip warns, and the warning outranks the low-power line.
func test_hold_with_a_hostile_warns():
	var strip := WeaponsStrip.new()
	add_child_autofree(strip)
	var t := _telemetry(false, [&"idle"] as Array[StringName])
	t.hostile_on_hold = true
	strip.render(t)
	assert_eq(strip.orders_text(), "HOSTILE · WEAPONS ON HOLD")
	assert_eq(strip._label.get_theme_color("font_color"), HudPalette.WARNING)
	assert_lte(strip._label.get_minimum_size().x, strip.custom_minimum_size.x, "it fits the strip, on the band")
	assert_gt(strip.pip_top(), strip._label.position.y + strip._label.get_minimum_size().y, "the pips below it")
	t.weapons_low_power = true
	strip.render(t)
	assert_eq(strip.orders_text(), "HOSTILE · WEAPONS ON HOLD", "above the low-power line")
	strip.render(_telemetry(false, [&"idle"] as Array[StringName]))
	assert_eq(strip.orders_text(), "HOLD", "no hostile, no warning")

## The keys under the orders, so the pilot knows what to press: B to flip
## the orders, T to mark. HOLD reads as bright as ENGAGE; the hint recedes.
func test_the_strip_says_which_keys_work_it():
	var strip := WeaponsStrip.new()
	add_child_autofree(strip)
	strip.render(_telemetry(false, [&"idle"] as Array[StringName]))
	assert_eq(strip.hint_text(), "B ENGAGE · T MARK")
	assert_eq(strip._label.get_theme_color("font_color"), HudPalette.READOUT, "HOLD is not dimmed out of sight")
	assert_eq(strip._hint.get_theme_color("font_color"), HudPalette.DIM)
	strip.render(_telemetry(true, [&"idle"] as Array[StringName]))
	assert_eq(strip.hint_text(), "B HOLD · T MARK")
	strip.render(_telemetry(true, [&"idle"] as Array[StringName], true))
	assert_eq(strip.hint_text(), "B HOLD · T MARK", "low power: the orders still flip")

## Under the hostile warning the hint is in the warning's colour: it is the
## way out of it.
func test_the_hint_under_the_hostile_warning_says_how_to_engage():
	var strip := WeaponsStrip.new()
	add_child_autofree(strip)
	var t := _telemetry(false, [&"idle", &"idle"] as Array[StringName])
	t.hostile_on_hold = true
	strip.render(t)
	assert_eq(strip.hint_text(), "B ENGAGE · T MARK")
	assert_eq(strip._hint.get_theme_color("font_color"), HudPalette.WARNING)
	assert_gte(strip._hint.position.y, strip.pip_top() + WeaponsStrip.PIP, "below the pips")
	assert_lte(strip._hint.get_minimum_size().x, strip.custom_minimum_size.x, "it fits the strip")
	assert_gte(strip.custom_minimum_size.y, strip._hint.position.y + strip._hint.get_minimum_size().y,
		"the strip is tall enough to hold it")

## The hint reads the key from the input map, so a rebinding shows.
func test_the_hint_follows_the_binding():
	_saved_orders_keys = InputMap.action_get_events(&"weapons_orders")
	InputMap.action_erase_events(&"weapons_orders")
	var k := InputEventKey.new()
	k.physical_keycode = KEY_K
	InputMap.action_add_event(&"weapons_orders", k)
	var strip := WeaponsStrip.new()
	add_child_autofree(strip)
	strip.render(_telemetry(false, [&"idle"] as Array[StringName]))
	assert_eq(strip.hint_text(), "K ENGAGE · T MARK")

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

## A hostile in contact is bracketed whether listed or not (hostile ships spec
## §4.3): unnumbered, red, once, and a listed one is not drawn twice.
func test_an_unlisted_hostile_is_bracketed_unnumbered():
	var rig := _brackets_rig()
	var brackets: TargetBrackets = rig["brackets"]
	var other := Node3D.new()
	(rig["target"] as Node3D).get_parent().add_child(other)
	other.global_position = Vector3(0.0, 0.0, -1500.0)
	Weapons.join(other, &"ship:Red")
	Weapons.hostile_rule = func(_shooter: Node, node: Node) -> bool: return node == other
	brackets.hostiles = func() -> Array[Node3D]: return [rig["target"], other] as Array[Node3D]
	brackets.render(_telemetry(false, [] as Array[StringName]))
	assert_eq(brackets.marks.size(), 2, "the listed one once, the unlisted one once")
	assert_eq(brackets.marks[1]["index"], 0)
	assert_true(brackets.marks[1]["hostile"])
	assert_eq(brackets.marks[1]["text"], "1.5 KM")

func test_a_target_freed_since_the_last_assign_draws_nothing_and_raises_nothing():
	var rig := _brackets_rig()
	var brackets: TargetBrackets = rig["brackets"]
	(rig["target"] as Node3D).free()
	brackets.render(_telemetry(false, [] as Array[StringName]))
	assert_eq(brackets.marks.size(), 0)
	(rig["fc"] as FireControl).assign(0.2)
	brackets.render(_telemetry(false, [] as Array[StringName]))
	assert_eq(brackets.marks.size(), 0)

func test_a_demoted_target_out_of_the_tree_draws_nothing_and_raises_nothing():
	var rig := _brackets_rig()
	var brackets: TargetBrackets = rig["brackets"]
	var target := rig["target"] as Node3D
	target.get_parent().remove_child(target)
	brackets.render(_telemetry(false, [] as Array[StringName]))
	assert_eq(brackets.marks.size(), 0)
	target.free()
