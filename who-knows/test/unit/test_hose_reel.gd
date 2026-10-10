extends GutTest

## The reel (quantum energy spec §11.1): stocked with a nozzle, it pays the line
## out when the nozzle is taken, winds it home in a second when it is let go,
## and keeps a stowed nozzle where it belongs as the hull moves.

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
	var mug := Item.new()
	mug.setup(ItemCatalog.load_from_dir().get_def(&"mug"))
	add_child_autofree(mug)
	assert_false(_reel.fits(mug))

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

func test_a_stowed_nozzle_follows_the_reel_as_the_hull_moves():
	var nozzle := _reel.item
	_hull.global_position = Vector3(40, -3, 12)
	await wait_physics_frames(2)
	assert_almost_eq(nozzle.global_position, _reel.item_transform(nozzle).origin, Vector3.ONE * 0.001)

func test_a_second_release_does_not_make_a_second_line():
	_reel.release()
	var line := _reel.line
	_reel.release()
	assert_eq(_reel.line, line)
