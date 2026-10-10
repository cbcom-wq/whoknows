extends GutTest

## The nozzle (quantum energy spec §11.4): a held trigger pulls what lies in
## its cone, swallows what reaches the mouth into the store, refuses what is
## too big or does not fit, and costs nothing.

var _universe: Universe
var _outside: Node3D
var _hull: Node3D
var _reel: HoseReel
var _nozzle: Item
var _use: HoseNozzle
var _store: QuantumStore
var _catalog: ItemCatalog

func before_each():
	_catalog = ItemCatalog.load_from_dir()
	_universe = Universe.new()
	add_child_autofree(_universe)
	_universe.set_physics_process(false)
	_outside = Node3D.new()
	add_child_autofree(_outside)
	_hull = Node3D.new()
	add_child_autofree(_hull)
	_store = QuantumStore.new(1000, 0)
	_reel = HoseReel.new()
	_hull.add_child(_reel)
	_reel.line_parent = _outside
	_reel.sink = func(item: Item) -> bool:
		return _store.credit(item.definition.quantum_value, &"hose")
	_reel.room = func() -> int: return _store.room()
	_reel.stock_nozzle(_catalog.get_def(&"hose_nozzle"))
	_nozzle = _reel.item
	_use = _nozzle.use_node as HoseNozzle
	# Held: out of the reel, at the origin, mouth along -z.
	_reel.release()
	_nozzle.set_held()
	_nozzle.global_transform = Transform3D.IDENTITY

func _loose(id: StringName, at: Vector3) -> Item:
	var item := Item.new()
	item.setup(_catalog.get_def(id))
	item.set_space(true)
	_outside.add_child(item)
	item.global_position = at
	return item

func _hold(frames: int) -> void:
	for i in frames:
		_use.hold(_nozzle, Transform3D.IDENTITY, _outside, null, 1.0 / 60.0)
		await wait_physics_frames(1)

func test_an_item_in_the_cone_is_pulled_toward_the_mouth():
	var chunk := _loose(&"rock_chunk", Vector3(0, 0, -4))
	await _hold(30)
	assert_gt(chunk.global_position.z, -4.0, "it came toward the nozzle")

func test_an_item_outside_the_cone_is_left_alone():
	var chunk := _loose(&"rock_chunk", Vector3(5, 0, -2))
	await _hold(30)
	assert_almost_eq(chunk.global_position, Vector3(5, 0, -2), Vector3.ONE * 0.01)

func test_it_swallows_credits_the_store_once_and_frees_the_item():
	var chunk := _loose(&"rock_chunk", Vector3(0, 0, -1.0))
	var value := chunk.definition.quantum_value
	watch_signals(_use)
	await _hold(90)
	assert_eq(_store.amount, value)
	assert_signal_emit_count(_use, "swallowed", 1)
	assert_false(is_instance_valid(chunk), "gone")

func test_the_toast_text_names_it_and_says_what_it_was_worth():
	var chunk := _loose(&"ice_chunk", Vector3(0, 0, -0.5))
	var value := chunk.definition.quantum_value
	watch_signals(_use)
	await _hold(30)
	assert_signal_emitted_with_parameters(_use, "swallowed", ["ICE CHUNK", value])

func test_a_full_store_stops_suction_and_says_so():
	_store = QuantumStore.new(100, 100)
	var chunk := _loose(&"rock_chunk", Vector3(0, 0, -3))
	await _hold(30)
	assert_almost_eq(chunk.global_position.z, -3.0, 0.01, "not pulled")
	assert_eq(chunk.state, Item.State.LOOSE)
	assert_eq(_use.aim_text(_nozzle, Transform3D.IDENTITY, null), "Store full")
	assert_eq(_store.amount, 100)

func test_an_item_the_store_has_no_room_for_is_left_where_it_is():
	_store = QuantumStore.new(100, 95)
	var chunk := _loose(&"rock_chunk", Vector3(0, 0, -3))
	await _hold(30)
	assert_almost_eq(chunk.global_position.z, -3.0, 0.01, "5 QE of room, a 10 QE chunk: not pulled")
	assert_eq(_use.aim_text(_nozzle, Transform3D.IDENTITY, null), "Store full")

func test_a_thing_too_big_is_not_pulled_and_the_prompt_says_so():
	# The catalogue's crate is within the limits, so the fixture is made here:
	# 0.8 m on its longest side.
	var def := ItemDefinition.new()
	def.id = &"test_slab"
	def.look = &"spanner"
	def.mass_kg = 5.0
	def.size = Vector3(0.8, 0.2, 0.2)
	def.quantum_value = 10
	var slab := Item.new()
	slab.setup(def)
	slab.set_space(true)
	_outside.add_child(slab)
	slab.global_position = Vector3(0, 0, -3)
	await _hold(30)
	assert_almost_eq(slab.global_position.z, -3.0, 0.01, "not pulled")
	assert_eq(_use.aim_text(_nozzle, Transform3D.IDENTITY, null), "Too big")

func test_items_are_funnelled_in_the_holders_frame_not_the_worlds():
	# The holder drifts at 4 m/s along x and the chunk drifts with it: relative
	# to the mouth it is not drifting at all. A funnel in the world's frame
	# would damp that 4 m/s away as if it were sideways drift.
	var holder := CharacterBody3D.new()
	add_child_autofree(holder)
	holder.velocity = Vector3(4.0, 0, 0)
	var chunk := _loose(&"rock_chunk", Vector3(0, 0, -3.0))
	chunk.linear_velocity = Vector3(4.0, 0, 0)
	for i in 6:
		_use.hold(_nozzle, Transform3D.IDENTITY, _outside, holder, 1.0 / 60.0)
		await wait_physics_frames(1)
	assert_almost_eq(chunk.linear_velocity.x, 4.0, 0.1, "it keeps the holder's drift: nothing damped it")
	assert_gt(chunk.linear_velocity.z, 0.0, "and it is being drawn toward the mouth")

func test_it_costs_the_store_nothing_to_draw():
	_store = QuantumStore.new(1000, 500)
	_loose(&"rock_chunk", Vector3(0, 0, -6))
	var before := _store.amount
	await _hold(10)
	assert_eq(_store.amount, before)

func test_the_hud_line_says_how_much_hose_is_out():
	_nozzle.global_position = Vector3(0, 0, 12)
	assert_eq(_use.tool_text(), "HOSE 12 M")

func test_it_hands_the_avatar_a_tether_to_the_reel_30_m_long():
	var t := _use.tether()
	assert_eq(t["anchor"], _reel.anchor())
	assert_eq(t["length"], 30.0)

func test_a_save_waits_while_it_is_out():
	assert_eq(_use.busy(), "hose out")

func test_an_item_freed_from_under_the_shrink_raises_no_error():
	var chunk := _loose(&"rock_chunk", Vector3(0, 0, -0.2))
	await _hold(1)
	assert_eq(chunk.state, Item.State.HELD, "swallowed and shrinking")
	chunk.get_parent().remove_child(chunk)
	chunk.free()
	await wait_physics_frames(30)
	assert_eq(_use._shrinking.size(), 0, "the dead entry was dropped without an error")
