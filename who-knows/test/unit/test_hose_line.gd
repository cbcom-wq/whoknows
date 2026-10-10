extends GutTest

## The hose's line as a node (quantum energy spec §11.3): drawn as segments on
## the world's layer, a floating-origin member of its own, ended with its ends.

var _universe: Universe
var _outside: Node3D
var _hull: Node3D
var _reel: HoseReel
var _nozzle: Item

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
	_nozzle = _reel.item

func _out_with_a_line() -> HoseLine:
	_reel.release()
	return _reel.line

func test_it_is_drawn_as_one_instance_per_segment_on_the_worlds_layer():
	var line := _out_with_a_line()
	var shown := line.get_node("Segments") as MultiMeshInstance3D
	assert_eq(shown.multimesh.instance_count, HoseRope.SEGMENTS)
	assert_eq(shown.layers, Item.SPACE_LAYER)

func test_it_is_a_floating_origin_member_of_its_own():
	var line := _out_with_a_line()
	assert_true(line.is_in_group(Universe.EXTERIOR_SPACE))
	assert_eq(line.get_parent(), _outside)

func test_a_shift_carries_it_with_the_reel():
	var line := _out_with_a_line()
	await wait_physics_frames(2)
	var before := line.to_global(line.rope.points[20]) - _reel.anchor()
	_universe.shift(Vector3(2000, 0, -4000))
	await wait_physics_frames(1)
	var after := line.to_global(line.rope.points[20]) - _reel.anchor()
	assert_almost_eq(after, before, Vector3.ONE * 0.05, "the line kept its place relative to the reel")

func test_it_follows_the_nozzle():
	var line := _out_with_a_line()
	_nozzle.global_position = Vector3(10, 0, 0)
	await wait_physics_frames(3)
	assert_almost_eq(line.to_global(line.rope.points[40]).distance_to(line.tail()), 0.0, 0.01)

func test_it_ends_when_the_nozzle_is_freed():
	_out_with_a_line()
	_nozzle.get_parent().remove_child(_nozzle)
	_nozzle.free()
	await wait_physics_frames(2)
	# finish() queue_frees the line: ended means gone from the tree.
	assert_null(_outside.get_node_or_null("HoseLine"), "the line is gone from the tree")
