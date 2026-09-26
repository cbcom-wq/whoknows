extends GutTest

## QuantumBay (docs/superpowers/specs/2026-09-24-quantum-energy-design.md
## §6.3, §7.1): a stow point that takes one item with a value, whose largest
## side is at most 0.55 m and which one person can lift (40 kg), floats it at
## its centre and turns it slowly (10°/s). Never an EVA tool; nothing new
## while the machine is working.

var _cat: ItemCatalog

func before_all():
	_cat = ItemCatalog.load_from_dir()

func _bay() -> QuantumBay:
	var bay := QuantumBay.new()
	add_child_autofree(bay)
	return bay

func _item(def: ItemDefinition) -> Item:
	var item := Item.new()
	item.setup(def)
	add_child_autofree(item)
	return item

## A hand-made kind: a mug's value and look, at a given size and mass.
func _def(size := Vector3(0.2, 0.2, 0.2), mass := 1.0, value := 3) -> ItemDefinition:
	var d := ItemDefinition.new()
	d.id = &"thing"
	d.display_name = "Thing"
	d.size = size
	d.mass_kg = mass
	d.quantum_value = value
	d.look = &"crate"
	return d

func test_every_starter_item_fits_a_crate_and_a_toolbox_among_them():
	for id in _cat.ids():
		assert_true(QuantumBay.takes(_cat.get_def(id)), "%s fits the bay" % id)
	var bay := _bay()
	assert_true(bay.fits(_item(_cat.get_def(&"crate"))), "spec §7.1: a crate fits")
	assert_true(bay.fits(_item(_cat.get_def(&"toolbox"))), "and a toolbox, 0.5 m long")

func test_it_refuses_an_item_with_no_value():
	assert_false(QuantumBay.takes(_def(Vector3(0.2, 0.2, 0.2), 1.0, 0)))
	assert_false(_bay().fits(_item(_def(Vector3(0.2, 0.2, 0.2), 1.0, 0))))

func test_it_refuses_an_eva_tool_whatever_its_value():
	var d := _def()
	d.eva_tool = true
	d.quantum_value = 50
	assert_false(QuantumBay.takes(d), "spec §4.3: EVA tools are never converted")

func test_it_refuses_anything_with_a_side_over_0_55_m():
	assert_true(QuantumBay.takes(_def(Vector3(0.55, 0.2, 0.2))), "0.55 m exactly fits")
	for size in [Vector3(0.56, 0.2, 0.2), Vector3(0.2, 0.56, 0.2), Vector3(0.2, 0.2, 0.56)]:
		assert_false(QuantumBay.takes(_def(size)), "%s is too big" % size)
		assert_false(_bay().fits(_item(_def(size))))

func test_it_refuses_anything_too_heavy_to_lift():
	assert_true(QuantumBay.takes(_def(Vector3(0.2, 0.2, 0.2), Item.LIFT_LIMIT_KG)), "40 kg exactly fits")
	assert_false(QuantumBay.takes(_def(Vector3(0.2, 0.2, 0.2), Item.LIFT_LIMIT_KG + 0.5)))
	assert_false(_bay().fits(_item(_def(Vector3(0.2, 0.2, 0.2), 41.0))))

func test_it_takes_one_at_a_time():
	var bay := _bay()
	bay.secure(_item(_cat.get_def(&"mug")))
	assert_false(bay.fits(_item(_cat.get_def(&"ration_tin"))))

func test_it_takes_nothing_new_while_the_machine_works():
	var bay := _bay()
	bay.busy = true
	assert_false(bay.fits(_item(_cat.get_def(&"mug"))))
	bay.busy = false
	assert_true(bay.fits(_item(_cat.get_def(&"mug"))))

func test_what_it_holds_floats_at_its_centre():
	var bay := _bay()
	bay.position = Vector3(1, 2, 3)
	var crate := _item(_cat.get_def(&"crate"))
	bay.secure(crate)
	assert_almost_eq(crate.global_position, bay.global_position, Vector3.ONE * 0.0001,
		"its centre, not its base, on the bay's origin")
	assert_eq(crate.state, Item.State.STOWED)

## Spec §6.3: an item in the bay turns slowly, 10°/s, about the bay's up.
func test_hold_turn_turns_what_it_holds_at_10_degrees_a_second():
	var bay := _bay()
	bay.transform = Transform3D(Basis(Vector3.UP, 0.3), Vector3(1, 2, 3))
	var mug := _item(_cat.get_def(&"mug"))
	bay.secure(mug)
	for i in 60:
		bay.hold_turn(1.0 / 60.0)
	var turned := (bay.global_basis.inverse() * mug.global_basis)
	assert_almost_eq(rad_to_deg(turned.get_euler().y), QuantumBay.TURN_RATE, 0.01)
	assert_almost_eq(turned.y.dot(Vector3.UP), 1.0, 0.0001, "about the bay's own up")
	assert_almost_eq(mug.global_position, bay.global_position, Vector3.ONE * 0.0001, "and stays at the centre")
	assert_eq(QuantumBay.TURN_RATE, 10.0)

func test_hold_turn_with_nothing_in_it_is_harmless():
	var bay := _bay()
	bay.hold_turn(1.0)
	assert_true(bay.is_free())
