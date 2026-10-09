extends GutTest

## A drill and a store on a base (habitat modules spec §6.2, §6.3, §8.4).

class Ground extends PlantSurface:
	var y := 0.0
	func _init(p_y: float) -> void:
		y = p_y
	func cast(from: Vector3, dir: Vector3, reach: float) -> Dictionary:
		var to := from + dir * reach
		if from.y >= y and to.y <= y:
			return {"position": from.lerp(to, (from.y - y) / (from.y - to.y)), "normal": Vector3.UP}
		return {}
	func fixed() -> bool:
		return true
	func site_id() -> StringName:
		return &"rock:drill"
	func ore() -> Dictionary:
		return {"seed": 5, "veined": true}

var _root: Node
var _clock := 0.0
var _base: Base
var _ground: Ground

func before_each():
	_root = load("res://scenes/flight_test.tscn").instantiate()
	add_child_autofree(_root)
	_clock = 1000.0
	_root.bases.clock = func() -> float: return _clock
	var at: Vector3 = _root.get_node("Ship").exterior.global_position + Vector3(0, -40, 60)
	_ground = Ground.new(at.y)
	var r := Planting.fit(_ground, ModuleCatalog.get_def(ModuleCatalog.HUB), at, Vector3.FORWARD, 0)
	_base = _root.bases.plant(ModuleCatalog.HUB, r, _ground)
	_base.tick_unfold(HabitatValues.UNFOLD + 0.1)

## Plants `kind`, then lets the unfold take `unfold_clock` seconds of the clock.
func _plant_slowly(kind: StringName, local: Vector3, unfold_clock: float) -> int:
	var frame: Transform3D = _root.bases.frame_of(_base.site)
	var r := Planting.fit(_ground, ModuleCatalog.get_def(kind), frame * local, Vector3.FORWARD, 0, _base.site, frame)
	assert_eq(r.fit, Planting.Fit.OK)
	_root.bases.plant(kind, r, _ground)
	_clock += unfold_clock
	_base.tick_unfold(HabitatValues.UNFOLD + 0.1)
	return _base.site.modules.size() - 1

func _plant(kind: StringName, local: Vector3) -> int:
	var frame: Transform3D = _root.bases.frame_of(_base.site)
	var r := Planting.fit(_ground, ModuleCatalog.get_def(kind), frame * local, Vector3.FORWARD, 0, _base.site, frame)
	assert_eq(r.fit, Planting.Fit.OK)
	_root.bases.plant(kind, r, _ground)
	_base.tick_unfold(HabitatValues.UNFOLD + 0.1)
	return _base.site.modules.size() - 1

func test_a_planted_drill_knows_its_rock_s_ore():
	var i := _plant(ModuleCatalog.DRILL, Vector3(10, -2, 0))
	var drill: Dictionary = _base.site.modules[i]["drill"]
	assert_true(drill["veined"])
	assert_eq(float(drill["credited_at"]), 1000.0)

func test_it_earns_from_when_it_stands_not_from_when_it_was_planted():
	var i := _plant_slowly(ModuleCatalog.DRILL, Vector3(10, -2, 0), 20.0)
	assert_eq(float(_base.site.modules[i]["drill"]["credited_at"]), 1020.0)
	assert_eq(_base.credit_drills(), 0, "the unfolding earned nothing")

func test_it_fills_the_base_s_store_by_the_clock():
	var i := _plant(ModuleCatalog.DRILL, Vector3(10, -2, 0))
	var rate := DrillYield.rate(_base.site.modules[i]["drill"])
	_clock += 120.0
	var paid := _base.credit_drills()
	assert_eq(paid, floori(rate * 120.0 + 1e-6))
	assert_eq(_base.quantum.store.amount, paid)

func test_a_store_module_raises_the_capacity():
	_plant(ModuleCatalog.STORE, Vector3(-6, -2, 0))
	assert_eq(_base.quantum.store.capacity, HabitatValues.HUB_STORE + HabitatValues.STORE_ADDS)

func test_a_sleeping_base_is_credited_when_it_wakes():
	_plant(ModuleCatalog.DRILL, Vector3(10, -2, 0))
	var universe: Universe = _root.get_node("Universe")
	universe.origin = universe.origin.plus(Vector3(25000, 0, 0))
	_root.bases.check_sleep()
	await wait_frames(1)
	assert_null(_root.bases.named(&"Base1"))
	_clock += 600.0
	universe.origin = universe.origin.plus(Vector3(-25000, 0, 0))
	_root.bases.check_sleep()
	assert_gt(_root.bases.named(&"Base1").quantum.store.amount, 0, "it earned while asleep")

func test_herds_keep_away_from_a_drill_that_has_run_ten_minutes():
	var i := _plant(ModuleCatalog.DRILL, Vector3(10, -2, 0))
	var at: Vector3 = _root.bases.frame_of(_base.site) * _base.site.centre_of(i)
	assert_false(_root.bases.quiet(&"rock:drill", at), "not yet")
	_clock += HabitatValues.QUIET_AFTER + 1.0
	_base.credit_drills()
	assert_true(_root.bases.quiet(&"rock:drill", at + Vector3(30, 0, 0)), "within 80 m of it")
	assert_false(_root.bases.quiet(&"rock:drill", at + Vector3(200, 0, 0)), "but not beyond")
	assert_false(_root.bases.quiet(&"rock:other", at), "and only on its own rock")
