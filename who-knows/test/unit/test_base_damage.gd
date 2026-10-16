extends GutTest

## A base under fire (ship weapons spec §6.5): a hit finds its module, a
## wrecked drill earns nothing, a wrecked hub's machine and panel go dark, a
## wrecked store's tanks leave the capacity, and the torch mends a module.

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
		return &"rock:fire"
	func ore() -> Dictionary:
		return {"seed": 5, "veined": false}

var _root: Node
var _clock := 0.0
var _base: Base
var _ground: Ground
var _drill := -1
var _store := -1

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
	_drill = _plant(ModuleCatalog.DRILL, Vector3(10, -2, 0))
	_store = _plant(ModuleCatalog.STORE, Vector3(-6, -2, 0))

func _plant(kind: StringName, local: Vector3) -> int:
	var frame: Transform3D = _root.bases.frame_of(_base.site)
	var r := Planting.fit(_ground, ModuleCatalog.get_def(kind), frame * local, Vector3.FORWARD, 0, _base.site, frame)
	assert_eq(r.fit, Planting.Fit.OK)
	_root.bases.plant(kind, r, _ground)
	_base.tick_unfold(HabitatValues.UNFOLD + 0.1)
	return _base.site.modules.size() - 1

func _wreck(index: int) -> void:
	_base.site.modules[index]["damage"] = ModuleDamage.hp(_base.site, index, _base.catalog)
	_base.rebuild()

func test_a_hit_on_the_drill_hurts_the_drill():
	var cell: Vector3i = _base.site.cells_of(_drill)[0]
	var hit := Hit.make(_base.exterior.to_global(ShipGrid.cell_center(cell)), Vector3.UP, Vector3.DOWN, Vector3.ZERO, null)
	hit.damage = 50.0
	_base._on_hull_hit(hit)
	assert_almost_eq(float(_base.site.modules[_drill]["damage"]), 50.0, 0.001)
	assert_almost_eq(float(_base.site.modules[0]["damage"]), 0.0, 0.001, "the hub took none")

func test_a_wrecked_drill_earns_nothing():
	_wreck(_drill)
	var before := _base.quantum.store.amount
	_clock += 600.0
	assert_eq(_base.credit_drills(), 0)
	assert_eq(_base.quantum.store.amount, before)

func test_mended_it_earns_again():
	_wreck(_drill)
	_base.repair_section(ModuleDamage.part(_drill), 1.0)
	_clock += 600.0
	assert_gt(_base.credit_drills(), 0)

func test_a_wrecked_hub_unbinds_its_machine_and_darkens_its_panel():
	_wreck(0)
	assert_eq(_base.quantum.machines.size(), 0)
	assert_true(_base.link.offline)

func test_a_wrecked_store_leaves_the_capacity():
	var whole := _base.quantum.store.capacity
	_wreck(_store)
	assert_eq(_base.quantum.store.capacity, whole - HabitatValues.STORE_ADDS)

func test_the_torch_finds_the_module():
	var cell: Vector3i = _base.site.cells_of(_drill)[0]
	var on := _base.part_hit(_base.exterior, -1, _base.exterior.to_global(ShipGrid.cell_center(cell)), Vector3.UP)
	assert_eq(on.get("part"), ModuleDamage.part(_drill))
	assert_true(_base.is_section(ModuleDamage.part(_drill)))
	assert_string_starts_with(_base.part_label(ModuleDamage.part(_drill)), "DRILL 1")

func test_the_damage_survives_sleep():
	_base.site.modules[_drill]["damage"] = 40.0
	var again := BaseSite.from_dict(_base.site.to_dict())
	assert_almost_eq(float(again.modules[_drill]["damage"]), 40.0, 0.001)

func test_a_hurt_module_sparks_and_a_whole_one_does_not():
	assert_true(_base.damage_show._spitting.is_empty())
	_base.site.modules[_drill]["damage"] = ModuleDamage.hp(_base.site, _drill, _base.catalog) * 0.7
	_base.rebuild()
	assert_false(_base.damage_show._spitting.is_empty())

func test_a_wrecked_hub_darkens_the_panel_s_lines():
	_wreck(0)
	assert_eq(_base.link.lines()[0], "HUB WRECKED")
