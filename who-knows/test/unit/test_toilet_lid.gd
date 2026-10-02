extends GutTest

## The toilet's lid and, in a dev build, the QE refill button under it: lift
## the lid, press the button in the bowl, and the ship's quantum store is full.

func _lid(dev := true) -> ToiletLid:
	var lid := ToiletLid.new()
	lid.dev = dev
	lid.setup(InteriorKit.LAYER)
	add_child_autofree(lid)
	return lid

func test_dev_follows_the_build():
	var lid: ToiletLid = autofree(ToiletLid.new())
	assert_eq(lid.dev, OS.is_debug_build())

func test_the_lid_lifts_and_closes():
	var lid := _lid()
	assert_true(lid.is_in_group("interactable"))
	assert_false(lid.is_open, "it starts shut")
	assert_eq(lid.prompt_text(), "Lift lid")
	lid.interact(null)
	assert_true(lid.is_open)
	assert_eq(lid.prompt_text(), "Close lid")
	lid.interact(null)
	assert_false(lid.is_open)

func test_the_lid_swings_up_on_its_hinge_and_its_hit_box_goes_with_it():
	var lid := _lid()
	var hit: CollisionShape3D = lid.get_node("Hit")
	assert_almost_eq(lid.lid_frame().basis.z, Vector3.BACK, Vector3.ONE * 0.001, "shut, it lies along the seat")
	var shut_y := hit.position.y
	lid.set_open(true, false)
	assert_almost_eq(lid.lid_frame().basis.z, Vector3.UP, Vector3.ONE * 0.001, "lifted, it stands up")
	var drawn: Transform3D = lid.get_node("Lid").transform
	assert_almost_eq(drawn.origin, lid.lid_frame().origin, Vector3.ONE * 0.001, "the lid is drawn there")
	assert_almost_eq(drawn.basis.z, Vector3.UP, Vector3.ONE * 0.001)
	assert_gt(hit.position.y, shut_y + 0.1, "so you can look past it into the bowl")

func test_the_lid_swings_over_time_in_the_tree():
	var lid := _lid()
	lid.set_open(true)
	assert_almost_eq(lid.lid_frame().basis.z, Vector3.BACK, Vector3.ONE * 0.001, "not there at once")
	await wait_seconds(ToiletLid.OPEN_TIME + 0.1)
	assert_almost_eq(lid.lid_frame().basis.z, Vector3.UP, Vector3.ONE * 0.001)

func test_the_button_can_be_pressed_only_with_the_lid_up():
	var lid := _lid()
	lid.bind(QuantumStore.new(1200, 300))
	assert_false(lid.button.can_interact(null), "not under a shut lid")
	lid.set_open(true, false)
	assert_true(lid.button.can_interact(null))
	assert_eq(lid.button.prompt_text(), "Refill QE (dev)")

func test_the_button_fills_the_store():
	var store := QuantumStore.new(1200, 30)
	var lid := _lid()
	lid.bind(store)
	lid.set_open(true, false)
	lid.button.interact(null)
	assert_eq(store.amount, 1200)
	assert_false(store.is_low_power())

func test_an_unbound_button_does_nothing():
	var lid := _lid()
	lid.set_open(true, false)
	assert_false(lid.button.can_interact(null), "no store to fill")
	lid.button.interact(null)
	assert_true(true, "and pressing it anyway is harmless")

func test_in_a_release_build_the_toilet_is_only_a_toilet():
	var lid := _lid(false)
	assert_false(lid.is_in_group("interactable"))
	assert_null(lid.button)
	assert_eq(lid.collision_layer, 0)
	assert_false(lid.has_node("Hit"))
	assert_true(lid.has_node("Lid"), "the lid is still drawn, shut")

## In the starter, from where you would stand: the Interactor's ray finds the
## lid, and once it is lifted, the button in the bowl -- not the toilet's own
## collider.
func test_standing_in_the_starter_s_bathroom_you_reach_the_lid_then_the_button():
	var root: Node = load("res://scenes/flight_test.tscn").instantiate()
	root.save_enabled = false
	add_child_autofree(root)
	var ship: Ship = root.get_node("Ship")
	var lids := ship.interior_builder.toilet_lids()
	assert_eq(lids.size(), 1, "the starter has one bathroom")
	var lid := lids[0]
	assert_eq(lid.dev, OS.is_debug_build())
	await wait_physics_frames(2)
	var eye := lid.global_transform * Vector3(-0.5, 1.6, 1.3)
	var bowl := lid.global_transform * (InteriorProps.toilet_button().origin + Vector3(0, 0.02, 0))
	assert_eq(_looked_at(lid, eye, bowl), lid, "the shut lid")
	lid.set_open(true, false)
	await wait_physics_frames(2)
	assert_eq(_looked_at(lid, eye, bowl), lid.button, "the button, past the lifted lid")

func _looked_at(from: Node3D, eye: Vector3, target: Vector3) -> Object:
	var query := PhysicsRayQueryParameters3D.create(eye, eye + (target - eye).normalized() * 2.5, Interactor.MASK)
	query.collide_with_areas = true
	var hit := from.get_world_3d().direct_space_state.intersect_ray(query)
	return hit.get("collider")

func test_the_starter_s_button_fills_its_own_store_and_a_rebuild_keeps_it_bound():
	var root: Node = load("res://scenes/flight_test.tscn").instantiate()
	root.save_enabled = false
	add_child_autofree(root)
	var ship: Ship = root.get_node("Ship")
	var store := ship.quantum.store
	assert_lt(store.amount, store.capacity, "a new ship starts part full")
	ship._rebuild_everything()
	var lid := ship.interior_builder.toilet_lids()[0]
	lid.set_open(true, false)
	lid.button.interact(null)
	assert_eq(store.amount, store.capacity)
