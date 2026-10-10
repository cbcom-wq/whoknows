extends GutTest

## The avatar and the hose (quantum energy spec §11.2, §11.3, §12): the line
## holds you at its length for free, letting go is every way out of the suit,
## and the HUD and toast hear about it.

class LeashUse extends ItemUse:
	var anchor := Vector3.ZERO
	var homed := 0
	func tether() -> Dictionary:
		return {"anchor": anchor, "length": 30.0}
	func tool_text() -> String:
		return "HOSE 12 M"
	func go_home(_item: Item) -> bool:
		homed += 1
		return true

var _outside: Node3D
var _avatar: Avatar

func before_each():
	_outside = Node3D.new()
	add_child_autofree(_outside)
	var scene := load("res://scenes/avatar.tscn") as PackedScene
	_avatar = scene.instantiate() as Avatar
	add_child_autofree(_avatar)
	_avatar.enter_suit(_outside, Transform3D.IDENTITY, Vector3.ZERO, null)
	# The cell starts empty, and a dry suit lets the tool go: charge it.
	_avatar.suit_cell.charge = SuitCell.CAPACITY

func _leash() -> Item:
	var def := ItemDefinition.new()
	def.id = &"test_leash"
	def.look = &"spanner"
	def.mass_kg = 1.0
	def.size = Vector3(0.1, 0.1, 0.3)
	def.grip = ItemDefinition.Grip.WIELD
	def.eva_tool = true
	def.works_outside = true
	def.use = LeashUse
	var item := Item.new()
	item.setup(def)
	item.set_space(true)
	_outside.add_child(item)
	return item

func test_the_spacewalk_interactor_sees_items_as_well_as_the_hull_panel():
	assert_eq(Interactor.SUIT_MASK, 16 | 32)

func test_the_suit_cell_pays_nothing_for_the_tethers_pull():
	var item := _leash()
	_avatar.grasp.take(item)
	_avatar.global_position = Vector3(0, 0, 35.0)
	_avatar.velocity = Vector3(0, 0, 4.0)
	var before := _avatar.suit_cell.charge
	# The assist's own braking is the suit's thruster work and is charged (spec §9); switch it off to isolate the tether's pull, which is free.
	_avatar.suit_assist = false
	_avatar.suit_step(1.0 / 60.0, Vector3.ZERO)
	assert_lte(_avatar.velocity.z, 0.0, "the outward speed is gone")
	assert_eq(_avatar.suit_cell.charge, before, "and it cost the cell nothing")

func test_the_suits_assist_braking_is_still_charged_at_the_end_of_the_line():
	var item := _leash()
	_avatar.grasp.take(item)
	_avatar.global_position = Vector3(0, 0, 35.0)
	_avatar.velocity = Vector3(0, 0, 4.0)
	var before := _avatar.suit_cell.charge
	assert_true(_avatar.suit_assist, "the assist is on by default")
	_avatar.suit_step(1.0 / 60.0, Vector3.ZERO)
	assert_lte(_avatar.velocity.z, 0.0, "the outward speed is still removed")
	assert_lt(_avatar.suit_cell.charge, before, "but the assist's own braking cost the cell")

func test_inside_the_length_the_line_changes_nothing():
	_avatar.grasp.take(_leash())
	_avatar.global_position = Vector3(0, 0, 5.0)
	_avatar.velocity = Vector3(0, 0, 1.0)
	_avatar.suit_step(1.0 / 60.0, Vector3.ZERO)
	assert_almost_eq(_avatar.velocity.z, 1.0, 0.05)

func test_the_tether_works_in_the_ships_frame_not_the_worlds():
	var hull := RigidBody3D.new()
	add_child_autofree(hull)
	hull.linear_velocity = Vector3(0, 0, 5.0)
	_avatar.enter_suit(_outside, Transform3D.IDENTITY, Vector3(0, 0, 5.0), hull)
	_avatar.suit_cell.charge = SuitCell.CAPACITY
	_avatar.grasp.take(_leash())
	_avatar.global_position = Vector3(0, 0, 35.0)
	_avatar.velocity = Vector3(0, 0, 5.0)
	_avatar.suit_step(1.0 / 60.0, Vector3.ZERO)
	assert_almost_eq(_avatar.velocity.z, 5.0, 0.05, "riding with the ship: not braked against the world")

func test_a_dry_suit_lets_the_tool_go_and_is_not_tethered():
	var item := _leash()
	_avatar.grasp.take(item)
	_avatar.suit_cell.charge = 0.0
	_avatar.suit_step(1.0 / 60.0, Vector3.ZERO)
	assert_null(_avatar.grasp.item)
	assert_eq((item.use_node as LeashUse).homed, 1)

func test_coming_back_aboard_lets_the_tool_go_first():
	var item := _leash()
	_avatar.grasp.take(item)
	var interior := Node3D.new()
	add_child_autofree(interior)
	_avatar.enter_plating(interior, Transform3D.IDENTITY, 0.0, Vector3.ZERO, Quaternion.IDENTITY)
	assert_null(_avatar.grasp.item)
	assert_eq((item.use_node as LeashUse).homed, 1)

func test_the_huds_status_line_carries_the_tools_text():
	_avatar.grasp.take(_leash())
	assert_eq(_avatar.build_telemetry().tool_text, "HOSE 12 M")

func test_the_toast_hears_what_the_nozzle_swallowed():
	var item := _leash()
	# A use that can be swallowed-from: the avatar listens to any use with the signal.
	var nozzle := Item.new()
	nozzle.setup(ItemCatalog.load_from_dir().get_def(&"hose_nozzle"))
	nozzle.set_space(true)
	_outside.add_child(nozzle)
	item.queue_free()
	_avatar.grasp.take(nozzle)
	watch_signals(_avatar)
	(nozzle.use_node as HoseNozzle).swallowed.emit("ICE CHUNK", 12)
	assert_signal_emitted_with_parameters(_avatar, "toast", ["+12 QE · ICE CHUNK"])
