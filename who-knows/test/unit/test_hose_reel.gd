extends GutTest

## The reel (quantum energy spec §11.1): stocked with a nozzle, it pays the line
## out when the nozzle is taken, winds it home in a second when it is let go,
## and keeps a stowed nozzle where it belongs as the hull moves.

var _universe: Universe
var _outside: Node3D
var _hull: Node3D
var _reel: HoseReel

func _def() -> ItemDefinition:
	var d := ItemDefinition.new()
	d.id = &"test_nozzle"
	d.mass_kg = 1.0
	d.size = Vector3(0.1, 0.1, 0.3)
	d.grip = ItemDefinition.Grip.WIELD
	d.stow_class = &"hose"
	d.look = &"spanner"
	d.eva_tool = true
	return d

func before_each():
	# A real Universe, never stepping by itself: a test calls shift() on it.
	_universe = Universe.new()
	add_child_autofree(_universe)
	_universe.set_physics_process(false)
	_outside = Node3D.new()
	add_child_autofree(_outside)
	_hull = Node3D.new()
	_hull.add_to_group(Universe.EXTERIOR_SPACE)
	add_child_autofree(_hull)
	_reel = HoseReel.new()
	_hull.add_child(_reel)
	_reel.line_parent = _outside
	_reel.stock_nozzle(_def())

func test_it_accepts_the_hose_class_only():
	assert_eq(_reel.accepts, &"hose")
	# A free reel, so only the class decides: a hose part fits, a mug does not.
	var empty := HoseReel.new()
	add_child_autofree(empty)
	var def := ItemDefinition.new()
	def.id = &"test_hose_part"
	def.look = &"spanner"
	def.size = Vector3(0.1, 0.12, 0.3)
	def.mass_kg = 1.0
	def.stow_class = &"hose"
	var hose_part := Item.new()
	hose_part.setup(def)
	add_child_autofree(hose_part)
	var mug := Item.new()
	mug.setup(ItemCatalog.load_from_dir().get_def(&"mug"))
	add_child_autofree(mug)
	assert_true(empty.fits(hose_part))
	assert_false(empty.fits(mug))

func test_stocking_secures_a_nozzle_and_does_it_once():
	var first := _reel.item
	assert_not_null(first)
	assert_eq(first.state, Item.State.STOWED)
	assert_false(_reel.is_out())
	_reel.stock_nozzle(_def())
	assert_eq(_reel.item, first, "a second stock changes nothing")

func test_taking_the_nozzle_pays_the_line_out():
	assert_null(_reel.line)
	var nozzle := _reel.item
	_reel.release()
	assert_true(_reel.is_out())
	assert_not_null(_reel.line)
	assert_eq(_reel.line.nozzle, nozzle)

func test_a_taken_back_nozzle_winds_home_in_a_second_then_secures_and_ends_the_line():
	var nozzle := _reel.item
	_reel.release()
	nozzle.global_position = Vector3(5, 1, 0)
	assert_true(_reel.take_back(nozzle))
	assert_true(_reel.is_out(), "still out while winding")
	await wait_physics_frames(30)
	assert_true(_reel.is_out(), "half a second: not home yet")
	await wait_physics_frames(45)
	assert_false(_reel.is_out())
	assert_eq(_reel.item, nozzle)
	assert_eq(nozzle.state, Item.State.STOWED)
	await wait_physics_frames(2)
	# finish() queue_frees the line: done means gone from the tree.
	assert_null(_outside.get_node_or_null("HoseLine"), "the line is done")

## Lets the nozzle go from 5 m off the reel and winds it home with the hull
## drifting by `drift` (m/s, engine frame) the whole way and, from physics
## frame `shift_at` of the wind (never if it is negative), a floating-origin
## shift of 2 km along and 1 km across. Returns the worst distance, metres, that
## the nozzle strayed -- seen in the REEL's own frame, which a drifting hull and
## a shift both leave alone -- from the straight line from where it was let go
## to where it is stowed. That is 0 on a still hull, whatever the wind's own
## easing.
func _worst_stray_on_the_wind_home(drift: Vector3, shift_at := -1) -> float:
	var nozzle := _reel.item
	_reel.release()
	nozzle.global_position = _reel.to_global(Vector3(5, 1, 0))
	assert_true(_reel.take_back(nozzle))
	var from := _reel.to_local(nozzle.global_position)
	var to := Vector3(0.0, nozzle.definition.size.y * 0.5, 0.0)
	var worst := 0.0
	var frame := 0
	while _reel.is_out() and frame < 120:
		await get_tree().physics_frame
		var at := _reel.to_local(nozzle.global_position)
		worst = maxf(worst, at.distance_to(Geometry3D.get_closest_point_to_segment(at, from, to)))
		frame += 1
		_hull.global_position += drift / 60.0
		if frame == shift_at:
			_universe.shift(Vector3(2000, 0, -1000))
	assert_false(_reel.is_out(), "it got home")
	assert_eq(_reel.item, nozzle)
	return worst

## The wind keeps its place in the reel's frame, not the engine's: a ship
## coasting at 100 m/s shifts every ~20 s, so a few let-gos in a hundred land
## in a shift (CLAUDE.md, the floating origin), and every ship drifts.
func test_the_wind_home_keeps_the_reels_frame_on_a_drifting_hull_and_across_a_shift():
	var worst: float = await _worst_stray_on_the_wind_home(Vector3(0, 0, 10), 30)
	assert_lt(worst, 0.05, "the nozzle strayed %.2f m from its way home" % worst)

func test_the_wind_home_keeps_the_reels_frame_on_a_drifting_hull():
	var worst: float = await _worst_stray_on_the_wind_home(Vector3(0, 0, 10))
	assert_lt(worst, 0.05, "the nozzle strayed %.2f m from its way home" % worst)

func test_the_wind_home_keeps_the_reels_frame_across_a_shift():
	var worst: float = await _worst_stray_on_the_wind_home(Vector3.ZERO, 30)
	assert_lt(worst, 0.05, "the nozzle strayed %.2f m from its way home" % worst)

func test_a_stowed_nozzle_follows_the_reel_as_the_hull_moves():
	var nozzle := _reel.item
	_hull.global_position = Vector3(40, -3, 12)
	await wait_physics_frames(2)
	# The physics body, not the node: a body that did not follow its parent would fail here.
	var body: Transform3D = PhysicsServer3D.body_get_state(nozzle.get_rid(), PhysicsServer3D.BODY_STATE_TRANSFORM)
	assert_almost_eq(body.origin, _reel.item_transform(nozzle).origin, Vector3.ONE * 0.001)

func test_a_second_release_while_the_line_is_out_does_not_make_a_second_line():
	var nozzle := _reel.item
	_reel.release()
	var line := _reel.line
	_reel.secure(nozzle)
	_reel.release()
	assert_eq(_reel.line, line, "the line that is paying out is reused")

## A hull-keeping rebuild binds the same reel again (Airlock._bind_reel) while
## the nozzle is out; a free reel is not an empty one, so it makes no second.
func test_a_second_stock_while_the_nozzle_is_out_makes_no_second_nozzle():
	_reel.release()
	assert_true(_reel.is_out())
	_reel.stock_nozzle(_def())
	assert_true(_reel.is_out(), "nothing new was secured")
	assert_null(_reel.item)
	var nozzles := 0
	for child in _reel.get_children():
		if child is Item:
			nozzles += 1
	# release() does not reparent: the one nozzle is still a child until a hand takes it.
	assert_eq(nozzles, 1, "the nozzle that is out, and no second")
