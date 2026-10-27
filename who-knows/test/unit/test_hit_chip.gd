extends GutTest

## Landing a hit, outside (hostile ships spec §6.2): a heavy bolt bursts
## brighter, and a single hit of HitFeel.CHIP_FROM or more knocks a piece off
## its section at any health. The piece counts as one of the section's lost
## pieces, comes back with the torch, and is saved.

var _root: Node
var _ship: Ship

func before_each():
	_root = load("res://scenes/flight_test.tscn").instantiate()
	add_child_autofree(_root)
	_ship = _root.get_node("Ship")

## A bow plate that can break away, off the centre line, open to space on
## +x or -x: [coord, its section, the way out].
func _bow_plate() -> Array:
	for section: StringName in [&"port_bow", &"starboard_bow"]:
		for coord: Vector3i in _ship.damage.pieces[section]:
			var out := Vector3i(signi(coord.x), 0, 0)
			if coord.x != 0 and _ship.damage.sections_of[coord].size() == 1 \
					and not _ship.grid.has_block(coord + out):
				return [coord, section, Vector3(out)]
	fail_test("no bow plate open to the side")
	return [Vector3i.ZERO, &"port_bow", Vector3.RIGHT]

## Delivers a hit of `damage` hp from outside onto `plate`.
func _strike(plate: Array, damage: float) -> void:
	var coord: Vector3i = plate[0]
	var out: Vector3 = plate[2]
	var local := ShipGrid.cell_center(coord) + out * 1.0 + Vector3(0, 0.2, -0.3)
	var hit := Hit.make(_ship.exterior.to_global(local), _ship.exterior.global_basis * out,
		-(_ship.exterior.global_basis * out), Vector3.ZERO, null)
	hit.damage = damage
	Hit.deliver(_ship.exterior, hit)

func test_a_heavy_hit_chips_a_whole_section():
	var plate := _bow_plate()
	var section: StringName = plate[1]
	var before := _ship.grid.size()
	_strike(plate, 120.0)
	var lost := _ship.damage.lost()
	assert_eq(lost.size(), 1, "one piece off")
	assert_true(_ship.damage.pieces[section].has(lost.keys()[0]), "one of that section's pieces")
	assert_gt(_ship.damage.health(section), 0.9, "the section is still nearly whole")
	assert_eq(_ship.grid.size(), before - 1, "the grid shows it")

func test_a_light_hit_never_chips():
	var plate := _bow_plate()
	_strike(plate, 15.0)
	assert_gt(_ship.damage.section_damage[plate[1]], 0.0, "the hit landed")
	assert_true(_ship.damage.lost().is_empty())

## Takes `section` to `health` (0..1), and the grid shows it.
func _set_health(section: StringName, health: float) -> void:
	_ship.damage.section_damage[section] = _ship.damage.section_hp[section] * (1.0 - health)
	_ship._apply_view()

func test_chips_come_back_with_the_torch():
	var plate := _bow_plate()
	var section: StringName = plate[1]
	var before := _ship.grid.size()
	_set_health(section, 0.9)
	assert_true(_ship.damage.chip(plate[0]))
	assert_true(_ship.damage.chip(plate[0]))
	_ship._apply_view()
	assert_eq(_ship.damage.lost().size(), 2, "two off a section nearly whole")
	assert_eq(_ship.grid.size(), before - 2)
	var guard := 0
	_ship.repair_section(section, 0.2)
	while _ship.damage.health(section) < ShipDamage.BREAK_BELOW and guard < 10:
		_ship.repair_section(section, 0.2)
		guard += 1
	assert_true(_ship.damage.lost().is_empty(), "every piece back")
	assert_eq(_ship.grid.size(), before)

func test_under_half_the_chips_stay_until_the_torch_passes_half():
	var plate := _bow_plate()
	var section: StringName = plate[1]
	var before := _ship.grid.size()
	_set_health(section, 0.4)
	var by_health := _ship.damage.lost_count(section)
	assert_true(_ship.damage.chip(plate[0]))
	_ship._apply_view()
	assert_eq(_ship.damage.lost().size(), by_health + 1, "one more than its health says")
	_ship.repair_section(section, 0.05)
	assert_lt(_ship.damage.health(section), ShipDamage.BREAK_BELOW)
	assert_eq(_ship.damage.chipped[section], 1, "under half, the chip stays")
	var guard := 0
	while _ship.damage.health(section) < ShipDamage.BREAK_BELOW and guard < 10:
		_ship.repair_section(section, 0.2)
		guard += 1
	assert_true(_ship.damage.lost().is_empty(), "every piece back")
	assert_eq(_ship.grid.size(), before)

func test_a_chip_stops_at_the_section_s_pieces():
	var plate := _bow_plate()
	var section: StringName = plate[1]
	var count: int = _ship.damage.pieces[section].size()
	for i in count:
		_ship.damage.chip(plate[0])
	assert_eq(_ship.damage.lost_count(section), count)
	assert_false(_ship.damage.chip(plate[0]), "nothing left to knock off")
	assert_eq(_ship.damage.lost_count(section), count)

func test_a_chip_on_a_bare_section_banks_nothing():
	var plate := _bow_plate()
	var section: StringName = plate[1]
	_set_health(section, 0.0)
	assert_false(_ship.damage.chip(plate[0]), "nothing left to knock off")
	assert_eq(_ship.damage.chipped[section], 0, "no chip held over for the torch")

func test_a_component_never_chips():
	for coord: Vector3i in _ship.damage.component_of:
		assert_false(_ship.damage.chip(coord))
		return

func test_chipped_round_trips():
	var plate := _bow_plate()
	_strike(plate, 120.0)
	var saved := _ship.damage.to_dict()
	assert_true(saved.has("chipped"))
	var back := ShipDamage.build(_ship.launch_blueprint.to_grid(), _ship.catalog, _ship.inner_cells)
	back.from_dict(saved)
	assert_eq(back.lost().size(), 1)
	assert_eq(back.lost(), _ship.damage.lost())

func test_the_flash_is_brighter_for_a_heavy():
	var holder := Node3D.new()
	add_child_autofree(holder)
	var flash := ImpactFlash.spawn(holder, Vector3.ZERO, Vector3.UP, ImpactFlash.Kind.IMPACT, false, 3.0, 6.0)
	assert_almost_eq(flash._light.light_energy, ImpactFlash.LIGHT_ENERGY * 6.0, 0.0001)
	assert_almost_eq(flash.life(), ImpactFlash.DURATION[ImpactFlash.Kind.IMPACT] * 2.0, 0.0001, "capped at twice")
	var plain := ImpactFlash.spawn(holder, Vector3.ZERO, Vector3.UP, ImpactFlash.Kind.IMPACT)
	assert_almost_eq(plain._light.light_energy, ImpactFlash.LIGHT_ENERGY, 0.0001)
	assert_almost_eq(plain.life(), ImpactFlash.DURATION[ImpactFlash.Kind.IMPACT], 0.0001)

func test_a_heavy_bolt_carries_its_brightness():
	for kind: StringName in WeaponValues.TURRET_IDS:
		assert_true(WeaponValues.spec(kind).has("flash_bright"), "%s has a flash_bright" % kind)
	assert_gt(WeaponValues.spec(WeaponValues.HEAVY)["flash_bright"],
		WeaponValues.spec(WeaponValues.LIGHT)["flash_bright"])
	assert_gt(WeaponValues.spec(WeaponValues.HEAVY)["damage"], HitFeel.CHIP_FROM, "a heavy bolt chips")
	assert_lt(WeaponValues.spec(WeaponValues.LIGHT)["damage"], HitFeel.CHIP_FROM, "a light one never")
