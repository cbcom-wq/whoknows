extends GutTest

## Every base, sleeping and waking as ships do (habitat modules spec §9.3), in
## the real flight scene with a Bases of its own.

class Ground extends PlantSurface:
	func cast(from: Vector3, dir: Vector3, reach: float) -> Dictionary:
		var to := from + dir * reach
		if from.y >= -30.0 and to.y <= -30.0:
			var t := (from.y + 30.0) / (from.y - to.y)
			return {"position": from.lerp(to, t), "normal": Vector3.UP}
		return {}
	func fixed() -> bool:
		return true
	func site_id() -> StringName:
		return &"rock:test"
	func rock() -> Vector4i:
		return Vector4i(1, 2, 3, 4)

var _root: Node
var _bases: Bases

func before_each():
	_root = load("res://scenes/flight_test.tscn").instantiate()
	add_child_autofree(_root)
	_bases = Bases.new()
	_bases.home = _root
	_bases.outside = _root.get_node("Outside")
	_bases.universe = _root.get_node("Universe")
	_bases.slots = _root.fleet.slots
	_bases.clock = func() -> float: return 0.0
	_root.add_child(_bases)

func _plant_hub(at := Vector3(0, -30, 60)) -> Base:
	var r := Planting.fit(Ground.new(), ModuleCatalog.get_def(ModuleCatalog.HUB), at, Vector3.FORWARD, 0)
	assert_eq(r.fit, Planting.Fit.OK)
	return _bases.plant(ModuleCatalog.HUB, r, Ground.new())

func test_a_hub_on_bare_rock_founds_a_base_unfolding():
	var base := _plant_hub()
	assert_not_null(base)
	assert_eq(String(base.name), "Base1")
	assert_eq(base.unfolding, 0)
	assert_eq(base.interior_slot, 1, "the next slot after the starter's")
	assert_same(_bases.on(&"rock:test"), base.site)
	assert_eq(base.site.rock, Vector4i(1, 2, 3, 4))
	assert_true(_bases.busy() != "", "a save waits while it unfolds")

func test_a_drill_joins_the_rock_s_base():
	var base := _plant_hub()
	base.tick_unfold(HabitatValues.UNFOLD + 0.1)
	var frame := _bases.frame_of(base.site)
	var r := Planting.fit(Ground.new(), ModuleCatalog.get_def(ModuleCatalog.DRILL), frame * Vector3(10, -2, 0),
		Vector3.FORWARD, 0, base.site, frame)
	assert_eq(r.fit, Planting.Fit.OK)
	assert_same(_bases.plant(ModuleCatalog.DRILL, r, Ground.new()), base)
	assert_eq(base.site.modules.size(), 2)
	assert_eq(base.unfolding, 1)

## A drill's fit beside `base`, on its grid (the fit itself knows nothing of
## an unfolding: PackageUse tells it).
func _drill_fit(base: Base) -> Planting.Result:
	var frame := _bases.frame_of(base.site)
	var r := Planting.fit(Ground.new(), ModuleCatalog.get_def(ModuleCatalog.DRILL), frame * Vector3(10, -2, 0),
		Vector3.FORWARD, 0, base.site, frame)
	assert_eq(r.fit, Planting.Fit.OK)
	return r

## Planted beside a sleeping base, a module wakes it first (the final review):
## with no slot to wake into, nothing changes and the package is kept; with
## one, the module joins and unfolds.
func test_a_module_planted_by_a_sleeping_base_wakes_it_first():
	var base := _plant_hub()
	base.tick_unfold(HabitatValues.UNFOLD + 0.1)
	var site := base.site
	var r := _drill_fit(base)
	# Asleep by hand, and kept so: near, its own check would wake it at once.
	_bases.set_physics_process(false)
	_bases.sleep(&"Base1")
	await wait_frames(1)
	var held: Array[int] = []
	while _bases.slots.free_count() > 0:
		held.append(_bases.slots.claim())
	assert_null(_bases.plant(ModuleCatalog.DRILL, r, Ground.new()), "no slot: it cannot wake")
	assert_eq(site.modules.size(), 1, "and nothing was added")
	assert_null(_bases.named(&"Base1"), "still asleep")
	_bases.slots.release(held.pop_back())
	var woke := _bases.plant(ModuleCatalog.DRILL, r, Ground.new())
	assert_not_null(woke, "a slot: awake")
	assert_eq(site.modules.size(), 2, "the drill joined once")
	assert_eq(woke.unfolding, 1, "and unfolds")

## One module unfolds at a time (the final review): a second planted meanwhile
## would take over the unfolding and lose the first's stamp.
func test_nothing_more_is_planted_while_a_module_unfolds():
	var base := _plant_hub()
	assert_eq(base.unfolding, 0)
	var r := _drill_fit(base)
	assert_null(_bases.plant(ModuleCatalog.DRILL, r, Ground.new()), "refused while the hub unfolds")
	assert_eq(base.site.modules.size(), 1)
	assert_eq(base.unfolding, 0, "the hub's unfolding goes on")

func test_a_base_sleeps_far_off_and_wakes_near_with_everything_in_it():
	var base := _plant_hub()
	base.tick_unfold(HabitatValues.UNFOLD + 0.1)
	base.quantum.store.credit(77, &"test")
	var slot := base.interior_slot
	var universe: Universe = _root.get_node("Universe")
	universe.origin = universe.origin.plus(Vector3(25000, 0, 0))
	_bases.check_sleep()
	await wait_frames(1)
	assert_null(_bases.named(&"Base1"), "asleep: no nodes")
	assert_false(_bases.slots.is_held(slot), "its slot is free")
	assert_eq(_bases.site_named(&"Base1").store, 77)
	universe.origin = universe.origin.plus(Vector3(-25000, 0, 0))
	_bases.check_sleep()
	var again := _bases.named(&"Base1")
	assert_not_null(again, "awake again")
	assert_eq(again.quantum.store.amount, 77)

func test_the_base_you_are_in_never_sleeps():
	var base := _plant_hub()
	base.tick_unfold(HabitatValues.UNFOLD + 0.1)
	_bases.inside = func() -> Base: return _bases.named(&"Base1")
	var universe: Universe = _root.get_node("Universe")
	universe.origin = universe.origin.plus(Vector3(25000, 0, 0))
	_bases.check_sleep()
	assert_not_null(_bases.named(&"Base1"))

func test_a_base_that_cannot_get_a_slot_stays_asleep_and_wakes_later():
	var base := _plant_hub()
	base.tick_unfold(HabitatValues.UNFOLD + 0.1)
	var universe: Universe = _root.get_node("Universe")
	universe.origin = universe.origin.plus(Vector3(25000, 0, 0))
	_bases.check_sleep()
	await wait_frames(1)
	var held: Array[int] = []
	while _bases.slots.free_count() > 0:
		held.append(_bases.slots.claim())
	universe.origin = universe.origin.plus(Vector3(-25000, 0, 0))
	_bases.check_sleep()
	assert_null(_bases.named(&"Base1"), "no slot: still asleep")
	assert_not_null(_bases.site_named(&"Base1"), "and not lost")
	_bases.slots.release(held.pop_back())
	_bases.check_sleep()
	assert_not_null(_bases.named(&"Base1"), "a slot freed: awake")

func test_bases_round_trip_through_a_save():
	var base := _plant_hub()
	base.tick_unfold(HabitatValues.UNFOLD + 0.1)
	base.quantum.store.credit(40, &"test")
	var saved := JSON.parse_string(JSON.stringify(_bases.to_dict()))
	var other: Bases = autofree(Bases.new())
	other.from_dict(saved)
	assert_eq(other.next_number, 2)
	assert_eq(other.sites().size(), 1)
	assert_eq(other.site_named(&"Base1").store, 40)
