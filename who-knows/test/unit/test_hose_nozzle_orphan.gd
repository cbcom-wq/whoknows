extends GutTest

## The orphan path's use-up (hose_nozzle.gd): a nozzle whose reel is gone is used
## up through HoseNozzle._use_up, deferred, and that call must be silent when the
## nozzle is already freed. Built from the catalogue's mug, so these need no
## hose_nozzle item and run now.

var _catalog: ItemCatalog

func before_each():
	_catalog = ItemCatalog.load_from_dir()

func test_use_up_consumes_a_live_item_once():
	var mug := Item.new()
	mug.setup(_catalog.get_def(&"mug"))
	add_child_autofree(mug)
	# A direct connection, not watch_signals: consume frees the item at once, and
	# GUT cannot look up a freed emitter's signal counts.
	var emitted := []
	mug.consumed.connect(func(): emitted.append(true))
	HoseNozzle._use_up(mug)
	assert_eq(emitted.size(), 1, "consumed was emitted once")
	assert_false(is_instance_valid(mug), "used up: gone")

func test_use_up_of_a_freed_item_is_silent():
	var mug := Item.new()
	mug.setup(_catalog.get_def(&"mug"))
	add_child(mug)
	mug.get_parent().remove_child(mug)
	mug.free()
	HoseNozzle._use_up(mug)
	HoseNozzle._use_up.call_deferred(mug)
	await wait_physics_frames(2)
	assert_false(is_instance_valid(mug), "the freed nozzle stays freed, and nothing raised")
