extends GutTest

## The hose in the real flight scene (quantum energy spec §11): a reel on every
## airlock, the nozzle taken on a spacewalk, suction into the ship's store, the
## tether at 30 m, and every way of letting go.

var _root: Node
var _ship: Ship
var _avatar: Avatar
var _outside: Node3D
var _airlock: Airlock
var _reel: HoseReel

func before_each():
	_root = load("res://scenes/flight_test.tscn").instantiate()
	add_child_autofree(_root)
	_ship = _root.get_node("Ship")
	_avatar = _root.get_node("Ship/Interior/Avatar")
	_outside = _root.get_node("Outside")
	_airlock = _ship.airlocks.values()[0]
	_reel = _airlock.alcove.reel
	await wait_physics_frames(2)

## Out on a spacewalk a little way off the outer hatch, in a charged suit (the
## cell starts empty, and a dry suit lets the nozzle go on the next tick). A
## hatch's +z points into its room, so outside is -z, and you face away from
## the hull: what the nozzle draws in must not lie inside it.
func _out() -> void:
	var hatch := _airlock.alcove.outer_hatch.global_transform
	_avatar.suit_cell.charge = SuitCell.CAPACITY
	var facing := Basis.looking_at(-hatch.basis.z, Vector3.UP)
	_avatar.enter_suit(_outside, Transform3D(facing, hatch * Vector3(0, 1.0, -3.0)), Vector3.ZERO, _ship.exterior)
	await wait_physics_frames(2)

## Waits out the grab swipe: the hand draws the nozzle in from the reel over
## Hands.GRAB_TIME, and until it is home its mouth is still up at the reel.
func _settled() -> void:
	for i in 120:
		if not _avatar.hands.grabbing():
			break
		await wait_physics_frames(1)

## How many nozzles (Items) hang under `reel` right now.
func _items_under(reel: HoseReel) -> int:
	var n := 0
	for child in reel.get_children():
		if child is Item:
			n += 1
	return n

func _loose(id: StringName, at: Vector3) -> Item:
	var item := Item.new()
	item.setup(_ship.item_catalog.get_def(id))
	item.set_space(true)
	_outside.add_child(item)
	item.global_position = at
	return item

func test_every_airlock_has_a_reel_with_a_nozzle_and_a_sink():
	for airlock: Airlock in _ship.airlocks.values():
		var reel := airlock.alcove.reel
		assert_not_null(reel, "a reel on the alcove")
		assert_not_null(reel.item, "a nozzle stocked")
		assert_eq(reel.item.definition.id, &"hose_nozzle")
		assert_eq(reel.item.state, Item.State.STOWED)
		assert_true(reel.sink.is_valid())
		assert_eq(reel.line_parent, _ship.outside)

func test_the_nozzle_is_never_a_floating_origin_member():
	assert_false(_reel.item.is_in_group(Universe.EXTERIOR_SPACE))

func test_taking_the_nozzle_on_a_spacewalk_pays_the_line_out_and_the_hud_says_so():
	await _out()
	assert_true(_avatar.grasp.take(_reel.item))
	assert_not_null(_reel.line)
	assert_true(_avatar.build_telemetry().tool_text.begins_with("HOSE"))

func test_drawing_swallows_salvage_into_the_ships_store():
	await _out()
	var nozzle := _reel.item
	_avatar.grasp.take(nozzle)
	await _settled()
	var mouth := nozzle.global_transform * nozzle.definition.use_point
	var dir := -nozzle.global_basis.z
	var chunk := _loose(&"rock_chunk", mouth + dir * 3.0)
	var want := chunk.definition.quantum_value
	var before := _ship.quantum.store.amount
	for i in 300:
		_avatar.grasp.hold_now(1.0 / 60.0, true)
		await wait_physics_frames(1)
		if not is_instance_valid(chunk):
			break
	assert_false(is_instance_valid(chunk), "swallowed")
	assert_eq(_ship.quantum.store.amount, before + want)

func test_the_tether_holds_at_30_m():
	await _out()
	_avatar.grasp.take(_reel.item)
	_avatar.global_position = _reel.anchor() + Vector3(0, 0, 35.0)
	_avatar.velocity = Vector3(0, 0, 3.0)
	_avatar.suit_step(1.0 / 60.0, Vector3.ZERO)
	assert_lte(_avatar.velocity.z, 0.0)

func test_letting_go_winds_it_home_in_a_second():
	await _out()
	var nozzle := _reel.item
	_avatar.grasp.take(nozzle)
	_avatar.grasp.let_go_outside()
	await wait_physics_frames(90)
	assert_eq(_reel.item, nozzle)
	assert_eq(nozzle.state, Item.State.STOWED)
	assert_false(_reel.is_out())

func test_crossing_back_in_lets_go_first():
	await _out()
	var nozzle := _reel.item
	_avatar.grasp.take(nozzle)
	_avatar.enter_plating(_ship.interior, Transform3D(Basis.IDENTITY, _ship.interior.to_global(Vector3(0, -0.95, 6))),
		0.0, Vector3.ZERO, Quaternion.IDENTITY)
	assert_null(_avatar.grasp.item)
	await wait_physics_frames(90)
	assert_eq(_reel.item, nozzle)

func test_a_save_waits_while_the_hose_is_out():
	await _out()
	_avatar.grasp.take(_reel.item)
	assert_eq(_avatar.busy(), "hose out")

func test_a_rebuild_with_the_hose_out_leaves_hands_empty_and_a_new_nozzle_on_a_new_reel():
	await _out()
	_avatar.grasp.take(_reel.item)
	# The rebuild a destroyed hull block causes.
	_ship._rebuild_everything()
	await wait_physics_frames(4)
	assert_null(_avatar.grasp.item, "the orphaned nozzle used itself up")
	var fresh: HoseReel = _airlock.alcove.reel
	assert_not_null(fresh)
	assert_not_null(fresh.item, "a fresh nozzle on the new reel")
	assert_eq(fresh.item.state, Item.State.STOWED)

func test_a_full_store_refuses_the_item_and_says_so():
	await _out()
	var nozzle := _reel.item
	_avatar.grasp.take(nozzle)
	await _settled()
	var store := _ship.quantum.store
	store.amount = store.capacity
	var mouth := nozzle.global_transform * nozzle.definition.use_point
	var chunk := _loose(&"rock_chunk", mouth + (-nozzle.global_basis.z) * 0.2)
	for i in 30:
		_avatar.grasp.hold_now(1.0 / 60.0, true)
		await wait_physics_frames(1)
	assert_true(is_instance_valid(chunk))
	assert_eq(chunk.state, Item.State.LOOSE)
	assert_eq(nozzle.use_node.aim_text(nozzle, Transform3D.IDENTITY, null), "Store full")

## The room check, not the swallow's own refusal: far from the mouth, a full
## store pulls nothing in (spec §11.4), so nothing is dragged to a mouth that
## cannot take it. Without Airlock._bind_reel's `reel.room`, it would be drawn.
func test_a_full_store_pulls_nothing_toward_the_mouth():
	await _out()
	var nozzle := _reel.item
	_avatar.grasp.take(nozzle)
	await _settled()
	var store := _ship.quantum.store
	store.amount = store.capacity
	var mouth := nozzle.global_transform * nozzle.definition.use_point
	var chunk := _loose(&"rock_chunk", mouth + (-nozzle.global_basis.z) * 3.0)
	var start := chunk.global_position
	for i in 30:
		_avatar.grasp.hold_now(1.0 / 60.0, true)
		await wait_physics_frames(1)
	assert_true(is_instance_valid(chunk))
	assert_almost_eq(chunk.global_position, start, Vector3.ONE * 0.01)
	assert_eq(nozzle.use_node.aim_text(nozzle, Transform3D.IDENTITY, null), "Store full")

## A rebuild that keeps the hull (damage staged while you are out, a cabin-level
## change) binds the same reel again: the nozzle that is out gets no second one.
func test_a_rebuild_that_keeps_the_hull_does_not_stock_a_second_nozzle():
	await _out()
	var nozzle := _reel.item
	_avatar.grasp.take(nozzle)
	await _settled()
	_ship._rebuild_everything(false)
	await wait_physics_frames(4)
	assert_eq(_airlock.alcove.reel, _reel, "the reel survived")
	assert_null(_reel.item, "still out")
	assert_eq(_items_under(_reel), 0, "no second nozzle was made")
	assert_eq(_avatar.grasp.item, nozzle, "not used up: its reel is still there")
	_avatar.grasp.let_go_outside()
	await wait_physics_frames(90)
	assert_eq(_reel.item, nozzle)
	assert_eq(_items_under(_reel), 1, "the one nozzle, home again")

## A ship spawned from the library has its own reel, crediting its own store
## (every ship is usable, CLAUDE.md).
func test_a_spawned_ship_has_its_own_reel_and_credits_its_own_store():
	var place := Transform3D(Basis.IDENTITY, _ship.exterior.global_position + Vector3(0, 0, -80))
	var other: Ship = _root.fleet.spawn(_root._starter_grid(), place, true, "second")
	await wait_physics_frames(3)
	assert_not_null(other)
	if other == null:
		return
	var airlock: Airlock = other.airlocks.values()[0]
	var reel := airlock.alcove.reel
	assert_not_null(reel)
	assert_not_null(reel.item)
	assert_ne(reel, _reel)
	assert_eq(reel.item.definition.id, &"hose_nozzle")
	assert_eq(reel.item.state, Item.State.STOWED)
	assert_ne(reel.item, _reel.item, "its own nozzle")
	assert_eq(reel.line_parent, other.outside)
	var chunk := _loose(&"rock_chunk", Vector3(0, 0, -200))
	var worth := chunk.definition.quantum_value
	var mine := _ship.quantum.store.amount
	var theirs := other.quantum.store.amount
	assert_true(reel.sink.call(chunk))
	assert_eq(_ship.quantum.store.amount, mine, "not the starter's store")
	assert_eq(other.quantum.store.amount, theirs + worth, "its own")

## The toast (quantum energy spec §12): what the nozzle swallows shows near the
## reticle, as the flight scene's own QuantumToast, wired to the avatar.
func test_the_toast_is_wired_to_the_avatar():
	_avatar.toast.emit("+7 QE · TEST")
	var toast: QuantumToast = _root.find_child("QuantumToast", true, false)
	assert_not_null(toast)
	if toast == null:
		return
	assert_true(toast.visible)
	assert_eq(toast.text(), "+7 QE · TEST")
