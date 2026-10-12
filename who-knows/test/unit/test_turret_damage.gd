extends GutTest

## Every turret is a component of its own (ship weapons spec §3.4): hit on its
## cell, it is the turret that takes it, never a section; numbered bow first.

var _cat: BlockCatalog

func before_all():
	_cat = BlockCatalog.load_from_dir("res://data/blocks")

func _ship() -> ShipGrid:
	var g := ShipGrid.new()
	for z in range(-2, 3):
		for x in range(-1, 2):
			var inst := BlockInstance.new()
			inst.block_id = &"hull"
			g.set_block(Vector3i(x, 0, z), inst)
	for at: Vector3i in [Vector3i(0, 1, 1), Vector3i(0, 1, -2)]:
		var t := BlockInstance.new()
		t.block_id = WeaponValues.LIGHT
		g.set_block(at, t)
	return g

func test_the_blocks_load_as_systems():
	for id in WeaponValues.TURRET_IDS:
		var def := _cat.get_def(id)
		assert_not_null(def, "%s loads" % id)
		if def == null:
			continue
		assert_eq(def.category, BlockDefinition.Category.SYSTEMS)
		assert_eq(def.occupancy, BlockDefinition.Occupancy.SOLID)
	assert_eq(_cat.get_def(WeaponValues.LIGHT).hp, 200)
	assert_almost_eq(_cat.get_def(WeaponValues.LIGHT).power_draw, 0.1, 0.0001)
	assert_eq(_cat.get_def(WeaponValues.HEAVY).hp, 400)
	assert_almost_eq(_cat.get_def(WeaponValues.HEAVY).mass_t, 2.0, 0.0001)

func test_their_tokens():
	assert_eq(ShipPlan.default_token(WeaponValues.LIGHT, 0), "Tl")
	assert_eq(ShipPlan.default_token(WeaponValues.HEAVY, 2), "Th2")
	assert_eq(ShipPlan.default_pair("Tl3"), [WeaponValues.LIGHT, 3])

func test_each_turret_is_its_own_component():
	var d := ShipDamage.build(_ship(), _cat)
	var part := ShipDamage.turret_part(Vector3i(0, 1, 1))
	assert_eq(d.component_of[Vector3i(0, 1, 1)], part)
	assert_true(d.has_component(part))
	var before := d.hull_whole()
	assert_true(d.hit(Vector3i(0, 1, 1), 150.0))
	assert_eq(d.component_stage(part), BlockDamage.Stage.DAMAGED)
	assert_eq(d.hull_whole(), before, "the hull took none of it")
	assert_eq(d.component_stage(ShipDamage.turret_part(Vector3i(0, 1, -2))), BlockDamage.Stage.INTACT, "the other turret neither")

func test_turrets_are_numbered_bow_first():
	var d := ShipDamage.build(_ship(), _cat)
	assert_eq(d.label(ShipDamage.turret_part(Vector3i(0, 1, -2))), "TURRET 1")
	assert_eq(d.label(ShipDamage.turret_part(Vector3i(0, 1, 1))), "TURRET 2")

func test_a_turret_degrades_and_round_trips():
	assert_true(ShipDamage.degrades(WeaponValues.LIGHT))
	var d := ShipDamage.build(_ship(), _cat)
	d.hit(Vector3i(0, 1, 1), 200.0)
	var again := ShipDamage.build(_ship(), _cat)
	again.from_dict(d.to_dict())
	assert_eq(again.component_stage(ShipDamage.turret_part(Vector3i(0, 1, 1))), BlockDamage.Stage.WRECKED)
