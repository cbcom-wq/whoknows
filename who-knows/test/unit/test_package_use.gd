extends GutTest

## The package in hand (habitat modules spec §4, §5.2, §5.3), in the real
## flight scene, against the start's big rock.

var _root: Node
var _rock: AsteroidDetail
var _ship: Ship

func before_each():
	_root = load("res://scenes/flight_test.tscn").instantiate()
	add_child_autofree(_root)
	_ship = _root.get_node("Ship")
	var stream: AsteroidStream = _root.get_node("AsteroidStream")
	_rock = stream.details.nearest(_ship.exterior.global_position)
	await wait_physics_frames(2)

func _package(kind := &"hub_package") -> Item:
	var item := Item.new()
	item.setup(_ship.item_catalog.get_def(kind))
	_root.get_node("Outside").add_child(item)
	return item

## An eye 4 m off the rock's surface, looking straight down onto it, where the
## line from the ship toward the rock lands, `side` m across from it. Null if
## that misses.
func _aim(side := Vector2.ZERO) -> Variant:
	var toward := (_rock.global_position - _ship.exterior.global_position).normalized()
	var across := toward.cross(Vector3.UP).normalized()
	var other := toward.cross(across)
	var from := _ship.exterior.global_position + across * side.x + other * side.y
	var hit := RockSurface.new(_rock).cast(from, toward, 2000.0)
	if hit.is_empty():
		return null
	var up: Vector3 = hit["normal"]
	var eye: Vector3 = hit["position"] + up * 4.0
	var hint := up.cross(Vector3.RIGHT if absf(up.dot(Vector3.RIGHT)) < 0.9 else Vector3.BACK).normalized()
	return Transform3D(Basis.looking_at(-up, hint), eye)

## The first aim, in a ring of tries across the near face, where a hub fits:
## a rock is lumpy, so one spot may be a crater wall.
func _fitting_aim(item: Item) -> Variant:
	var use: PackageUse = item.use_node
	for side in [Vector2.ZERO, Vector2(15, 0), Vector2(-15, 0), Vector2(0, 15), Vector2(0, -15),
			Vector2(30, 30), Vector2(-30, 30), Vector2(30, -30), Vector2(-30, -30), Vector2(50, 0), Vector2(-50, 0)]:
		var aim: Variant = _aim(side)
		if aim == null:
			continue
		var r := use.refit(item, aim, _root.get_node("Outside"))
		if r != null and r.fit == Planting.Fit.OK:
			return aim
	return null

func test_the_packages_are_cargo_with_values_that_fit_the_bay():
	for id in [&"hub_package", &"drill_package", &"store_package"]:
		var def: ItemDefinition = _ship.item_catalog.get_def(id)
		assert_not_null(def, String(id))
		assert_true(def.eva_cargo, "read back from the .tres")
		assert_ne(def.module, &"")
		assert_not_null(ModuleCatalog.get_def(def.module))
		assert_gt(def.quantum_value, 0)
		assert_lte(maxf(def.size.x, maxf(def.size.y, def.size.z)), 0.55, "fits the bay")
		assert_lte(def.mass_kg, Item.LIFT_LIMIT_KG)
	assert_eq(_ship.item_catalog.get_def(&"hub_package").quantum_value, 400)
	assert_eq(QuantumValues.make_cost(_ship.item_catalog.get_def(&"hub_package")), 800)

func test_the_ship_s_machine_offers_them():
	var ids := QuantumValues.makeable(_ship.item_catalog).map(func(d: ItemDefinition) -> StringName: return d.id)
	for id in [&"hub_package", &"drill_package", &"store_package"]:
		assert_true(ids.has(id))

func test_aimed_at_the_rock_a_hub_fits_and_planting_it_founds_a_base():
	var item := _package()
	var use: PackageUse = item.use_node
	var aim: Variant = _fitting_aim(item)
	assert_not_null(aim, "somewhere on the start rock's near face takes a hub")
	assert_true(use.use(item, aim, _root.get_node("Outside"), null))
	await wait_physics_frames(1)
	assert_eq(_root.bases.awake().size(), 1)
	assert_false(is_instance_valid(item), "the package is used up")

func test_use_retests_the_fit_before_planting():
	var item := _package()
	var use: PackageUse = item.use_node
	assert_not_null(_fitting_aim(item))
	var away := Transform3D(Basis.IDENTITY, _rock.global_position + Vector3(0, _rock.rock.radius + 500.0, 0))
	assert_false(use.use(item, away, _root.get_node("Outside"), null), "nothing under the aim now")
	assert_eq(_root.bases.awake().size(), 0)

func test_a_drill_with_no_base_says_so():
	var item := _package(&"drill_package")
	var use: PackageUse = item.use_node
	var r := use.refit(item, _aim(), _root.get_node("Outside"))
	assert_not_null(r)
	assert_eq(Planting.prompt(r, ModuleCatalog.get_def(&"drill")), "Plant a hub first")

func test_r_turns_the_ghost():
	var item := _package()
	var use: PackageUse = item.use_node
	use.turn()
	assert_eq(use.turns, 1)
	assert_true(InputMap.has_action(&"turn_module"))

func _ghost() -> PackageGhost:
	return _root.get_node("Outside").get_node_or_null("PackageGhost") as PackageGhost

## Something that is not the player's avatar to hold the package: aim_text
## reads it as outside, with the Outside space as its parent.
func _holder() -> StaticBody3D:
	var h := StaticBody3D.new()
	_root.get_node("Outside").add_child(h)
	return h

func test_the_ghost_stays_up_every_tick_while_it_is_aimed():
	var item := _package()
	item.state = Item.State.HELD
	var use: PackageUse = item.use_node
	var aim: Variant = _fitting_aim(item)
	assert_not_null(aim)
	var holder := _holder()
	use.aim_text(item, aim, holder)
	assert_true(_ghost().visible, "up at the first fit")
	var gone := 0
	for i in 75:
		await wait_physics_frames(1)
		use.aim_text(item, aim, holder)
		if not _ghost().visible:
			gone += 1
	assert_eq(gone, 0, "the 10 Hz refit does not flicker the ghost")

func test_the_ghost_goes_when_the_package_leaves_the_hand():
	var item := _package()
	item.state = Item.State.HELD
	var use: PackageUse = item.use_node
	var aim: Variant = _fitting_aim(item)
	assert_not_null(aim)
	var holder := _holder()
	use.aim_text(item, aim, holder)
	await wait_physics_frames(1)
	use.aim_text(item, aim, holder)
	assert_true(_ghost().visible, "shown while aimed in the hand")
	item.state = Item.State.LOOSE
	await wait_physics_frames(1)
	assert_false(_ghost().visible, "dropped, thrown or stowed: the ghost is gone")

func test_the_ghost_goes_when_aim_text_stops():
	var item := _package()
	item.state = Item.State.HELD
	var use: PackageUse = item.use_node
	var aim: Variant = _fitting_aim(item)
	assert_not_null(aim)
	use.aim_text(item, aim, _holder())
	assert_true(_ghost().visible)
	await wait_physics_frames(PackageUse.STALE_AFTER + 2)
	assert_false(_ghost().visible, "aimed at a stow point: aim_text is not called, the ghost is gone")
