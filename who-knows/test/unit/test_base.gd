extends GutTest

## A base (habitat modules spec §6.1, §9.1): a hub built from its site,
## standing still, boarded like a ship.

var _root: Node3D

func before_each():
	_root = Node3D.new()
	add_child_autofree(_root)

func _site() -> BaseSite:
	var s := BaseSite.new()
	s.id = &"Base1"
	s.add(ModuleCatalog.HUB, Vector3i.ZERO, 0, PackedFloat32Array([0.7, 0.7, 0.7, 0.7]))
	return s

func _base(site := _site(), slot := 3, unfolding := -1) -> Base:
	var base := Base.make(site, slot, NodePath(".."), unfolding)
	_root.add_child(base)
	base.place(Transform3D(Basis(Vector3.UP, 0.4), Vector3(100, 20, -50)))
	return base

func test_it_is_a_still_grid_home_in_its_slot():
	var base := _base()
	assert_true(base is GridHome)
	assert_true(base.exterior.freeze, "it never moves")
	assert_eq(base.exterior.freeze_mode, RigidBody3D.FREEZE_MODE_STATIC)
	assert_eq(base.exterior.linear_velocity, Vector3.ZERO)
	assert_true(base.exterior.is_in_group(Universe.EXTERIOR_SPACE))
	assert_true(base.exterior.is_in_group(AsteroidStream.SPACE_ANCHOR), "its rock stays in detail under it")
	assert_eq(base.interior.global_position, GridHome.INTERIOR_WORLD_BASE + Vector3(3 * GridHome.SLOT_SPACING, 0, 0))
	assert_almost_eq(base.exterior.global_position, Vector3(100, 20, -50), Vector3.ONE * 0.001)

func test_its_hub_has_an_airlock_that_cycles_and_a_store_that_starts_empty():
	var base := _base()
	assert_eq(base.airlocks.size(), 1)
	for a: Airlock in base.airlocks.values():
		assert_not_null(a.alcove, "an outer hatch on its hull")
		assert_false(a.warping())
	assert_eq(base.quantum.store.capacity, HabitatValues.HUB_STORE)
	assert_eq(base.quantum.store.amount, 0, "never a free half store")

func test_its_terminal_converts_but_never_makes():
	var base := _base()
	var machines := base.interior_builder.quantum_machines()
	assert_eq(machines.size(), 1)
	base.quantum.tick(0.1)
	var cycle: MachineCycle = base.quantum.cycles[machines[0].cell]
	assert_null(cycle.selected_def(), "nothing to make")
	assert_eq(cycle.screen()[0], "NOTHING TO MAKE")

func test_it_has_somewhere_to_wake():
	var base := _base()
	assert_false(base.wake_spots().is_empty())

func test_what_is_in_it_survives_capture_and_restore():
	var base := _base()
	base.quantum.store.credit(150, &"test")
	var mug := Item.new()
	mug.setup(base.item_catalog.get_def(&"mug"))
	base.items.add_child(mug)
	mug.global_position = base.wake_spots()[0].origin + Vector3.UP
	base.capture()
	assert_eq(base.site.store, 150)
	assert_eq(base.site.items.size(), 1)
	assert_eq(base.site.airlocks.size(), 1)
	var again := _base(base.site, 5)
	again.restore_inside()
	assert_eq(again.quantum.store.amount, 150)
	assert_eq(again.items.get_child_count(), 1, "the mug, in the new slot's interior")

func test_unfolding_waits_then_builds_and_stamps():
	var base := _base(_site(), 3, 0)
	assert_eq(base.busy(), "unfolding")
	assert_true(base.airlocks.is_empty(), "the base changes at the end")
	watch_signals(base)
	base.tick_unfold(HabitatValues.UNFOLD + 0.1)
	assert_eq(base.busy(), "")
	assert_signal_emitted(base, "unfolded")
	assert_eq(base.airlocks.size(), 1)

func test_it_stands_on_legs():
	var base := _base()
	assert_eq(base.exterior_look.leg_count(), 4)

## Spec §8.1: a base wears rounded shells, not the ship's box skin, which it
## keeps only for its colliders; the shell leaves the hatch face bare, and
## carries a porthole for each of the hull layout's.
func test_it_wears_a_shell_not_the_box_skin():
	var base := _base()
	assert_false(base.exterior_builder.skin().visible, "the box skin is hidden")
	assert_false(base.exterior_builder.collider_coords().is_empty(), "its colliders stay")
	var shell := base.exterior_look.get_node_or_null(^"Shell")
	assert_not_null(shell)
	var meshes := shell.find_children("*", "MeshInstance3D", true, false)
	assert_false(meshes.is_empty())
	var hatch: AirlockAlcove = base.airlocks.values()[0].alcove
	var face := hatch.outer_frame.origin
	for mi: MeshInstance3D in meshes:
		assert_true(mi.layers == ExteriorBuilder.OWN_HULL_LAYER or mi.layers == 1, "on the hull's layers")
		if mi.name == InteriorKit.BATCH_NAMES[InteriorKit.Batch.HULL]:
			var hits := 0
			var faces := (mi.mesh as ArrayMesh).get_faces()
			for i in range(0, faces.size(), 3):
				var c := (faces[i] + faces[i + 1] + faces[i + 2]) / 3.0
				if c.distance_to(face) < 0.6:
					hits += 1
			assert_eq(hits, 0, "no plating over the hatch")
	var portholes := base.exterior_builder.layout().windows.filter(func(w: Dictionary) -> bool: return w["round"])
	var glass := shell.get_node_or_null(^"DressingGlass") as MeshInstance3D
	if portholes.is_empty():
		assert_null(glass)
	else:
		assert_not_null(glass, "a porthole on the shell")
