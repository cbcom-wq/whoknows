extends GutTest

## The things to do in Wadoo (docs/superpowers/specs/2026-11-16-wadoo-design.md §7),
## as pieces: Halla's sun pump wakes when you fit a sun cell, the memorial takes
## the lilies you lay, and what you hold is what they answer to (Grasp.kind_in).
## The flight scene's side (taking from your hands, the tasks, making things
## again) is in test_placed_items.gd.

## Anything with hands, as the avatar has.
class Holder extends Node:
	var grasp := Grasp.new()

	func _notification(what: int) -> void:
		if what == NOTIFICATION_PREDELETE and is_instance_valid(grasp):
			if grasp.item != null and is_instance_valid(grasp.item):
				grasp.item.free()
			grasp.free()

func _holding(kind: StringName) -> Holder:
	var h := Holder.new()
	autofree(h)
	if kind != &"":
		var def := ItemDefinition.new()
		def.id = kind
		var item := Item.new()
		item.definition = def
		h.grasp.item = item
	return h

func _pump() -> SunPump:
	var pump := SunPump.make(Transform3D(Basis.IDENTITY, Vector3(2.0, 0.0, -3.0)), Vector3(2.7, 0.0, -1.5),
		Transform3D(Basis.IDENTITY, Vector3(4.0, 0.0, 0.0)), Vector2(4.0, 3.0), 0.4)
	add_child_autofree(pump)
	return pump

func _lilies() -> MemorialLilies:
	var feet := PackedVector3Array()
	for k in 6:
		var p := MemorialLilies.foot_of(Vector2(16.5, -16.5), 2.4, k, 6)
		feet.append(Vector3(p.x, 0.0, -p.y))
	var m := MemorialLilies.make(Transform3D(Basis.IDENTITY, Vector3(16.5, 0.0, 16.5)), 2.4, 6, feet)
	add_child_autofree(m)
	return m

func test_what_you_hold_is_what_they_answer_to() -> void:
	assert_eq(Grasp.kind_in(null), &"")
	assert_eq(Grasp.kind_in(autofree(Node.new())), &"", "no hands")
	assert_eq(Grasp.kind_in(_holding(&"")), &"", "empty hands")
	assert_eq(Grasp.kind_in(_holding(&"armlet")), &"armlet")

func test_the_pump_wants_a_sun_cell() -> void:
	var pump := _pump()
	assert_true(pump.is_in_group(&"interactable"))
	assert_eq(pump.collision_layer, BodyProxy.LAYER, "the suit's ray meets it (Interactor.SUIT_MASK)")
	assert_eq(pump.prompt_text(), "Fit the sun cell")
	assert_false(pump.can_interact(_holding(&"")), "empty hands")
	assert_false(pump.can_interact(_holding(&"armlet")), "not a cell")
	assert_true(pump.can_interact(_holding(&"sun_cell")))
	assert_false(pump.cell.visible, "its cage is empty")
	assert_false(pump.water.visible, "its channel is dry")
	assert_false(pump.green.visible, "and so is the garden")
	assert_false(pump.is_processing(), "broken, it does nothing each frame")
	var fits := []
	pump.fitted.connect(func(a: Node) -> void: fits.append(a))
	pump.interact(_holding(&"armlet"))
	assert_eq(fits.size(), 0)
	var me := _holding(&"sun_cell")
	pump.interact(me)
	assert_eq(fits, [me], "fitted: the scene takes it from your hands")

func test_fitted_it_draws_and_the_garden_grows() -> void:
	var pump := _pump()
	pump.set_working(true)
	assert_true(pump.cell.visible and pump.water.visible and pump.green.visible)
	assert_false(pump.can_interact(_holding(&"sun_cell")), "it has a cell")
	assert_true(pump.is_processing())
	assert_almost_eq(pump.green.scale.y, SunPump.GROW_FROM, 0.001, "the green starts low")
	assert_true(pump.green.global_position.is_equal_approx(Vector3(4.0, OasisLooks.BED_TOP, 0.0)),
		"it grows from the dry bed's top")
	var nods := []
	for i in 4:
		pump._process(SunPump.NOD_EVERY * 0.25)
		nods.append(pump.rod.rotation.z)
	assert_almost_eq(nods.max() - nods.min(), SunPump.NOD * 2.0, 0.01, "the rod nods as it draws")
	pump._process(SunPump.GROW_TIME * 0.5 - SunPump.NOD_EVERY)
	assert_almost_eq(pump.green.scale.y, lerpf(SunPump.GROW_FROM, 1.0, 0.5), 0.001, "half grown")
	pump._process(SunPump.GROW_TIME)
	assert_eq(pump.green.scale.y, 1.0, "grown, and no more")

func test_built_working_its_garden_is_green_already() -> void:
	var pump := _pump()
	pump.set_working(true, true)
	assert_eq(pump.green.scale.y, 1.0)
	pump.set_working(true)
	assert_eq(pump.green.scale.y, 1.0, "told again, it does not wither")

func test_the_memorial_takes_a_lily() -> void:
	var m := _lilies()
	assert_true(m.is_in_group(&"interactable"))
	assert_eq(m.collision_layer, 16, "exterior props: the suit's ray finds it")
	assert_eq(m.prompt_text(), "Lay the lily")
	assert_false(m.can_interact(_holding(&"")))
	assert_false(m.can_interact(_holding(&"armlet")))
	assert_true(m.can_interact(_holding(&"sun_lily")))
	var laid := []
	m.laid.connect(func(a: Node) -> void: laid.append(a))
	m.interact(_holding(&"sun_lily"))
	assert_eq(laid.size(), 1)
	assert_eq(m.lilies.filter(func(l: Node3D) -> bool: return l.visible).size(), 0,
		"none shows until the scene counts it (set_count)")

func test_one_lily_before_each_stone_up_to_six() -> void:
	var m := _lilies()
	m.set_count(2)
	assert_eq(m.lilies.filter(func(l: Node3D) -> bool: return l.visible).size(), 2)
	for k in 6:
		var d := OasisLooks.memorial_dir(k, 6)
		var at := m.lilies[k].position
		var out := Vector3(at.x, 0.0, at.z).dot(d)
		assert_between(out, 2.4 + OasisLooks.MEMORIAL_STONE.z * 0.5, 2.4 + WadooSite.MEMORIAL_OUT,
			"lily %d lies before stone %d, short of where a mourner kneels" % [k, k])
		var aside := Vector3(at.x, 0.0, at.z).dot(Vector3.UP.cross(d))
		assert_lt(aside * signf(OasisLooks.LAMP_ASIDE), 0.0, "away from its lamp")
		assert_gt(m.lilies[k].basis.y.dot(-d), 0.9, "its head toward the stone")
		assert_almost_eq(at.y, MemorialLilies.LIE, 0.001, "on the ground")
	m.set_count(9)
	assert_eq(m.count, 6, "no more than the stones")
	assert_false(m.can_interact(_holding(&"sun_lily")), "every stone has one")
