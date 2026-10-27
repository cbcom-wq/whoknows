extends GutTest

## Damage you can read (docs/superpowers/specs/2026-10-24-hostile-ships-design.md
## §7): a section under half vents gas from its most exposed blocks, more as it
## falls, the puffs riding the hull; and a damaged block spits sparks more
## often the more its section is hurt.

var _cat: BlockCatalog
var _grid: ShipGrid
var _d: ShipDamage

func before_all():
	_cat = BlockCatalog.load_from_dir("res://data/blocks")

func before_each():
	var bootstrap: Node = load("res://scenes/flight_test.gd").new()
	_grid = bootstrap._starter_grid()
	bootstrap.free()
	_d = ShipDamage.build(_grid, _cat, Ship.inner_of(_grid, _cat))

func _at(section: StringName, health: float) -> void:
	_d.section_damage[section] = _d.section_hp[section] * (1.0 - health)

func _in_section(vent: Dictionary, section: StringName) -> bool:
	return (_d.sections_of[vent["coord"]] as Array).has(section)

func _onto_space(vent: Dictionary) -> bool:
	var next: Vector3i = vent["coord"] + vent["normal"]
	return not _grid.has_block(next) or _d.lost().has(next)

func test_no_vents_above_half():
	for id in ShipDamage.SECTIONS:
		_at(id, 0.6)
	assert_eq(GasVents.vents(_d, _grid), [])

func test_vents_grow_as_a_section_falls():
	_at(&"port_mid", 0.45)
	var few := GasVents.vents(_d, _grid)
	assert_eq(few.size(), 1, "just under half: one vent")
	_at(&"port_mid", 0.05)
	var many := GasVents.vents(_d, _grid)
	assert_eq(many.size(), GasVents.MOST_PER_SECTION, "near nothing: the most")
	for vent: Dictionary in many:
		assert_true(_in_section(vent, &"port_mid"), "%s is in the section" % vent["coord"])
		assert_true(_d.present(vent["coord"]), "%s is still there" % vent["coord"])
		assert_true(_onto_space(vent), "%s vents onto space" % vent["coord"])
		assert_gt(vent["strength"], few[0]["strength"], "thicker as it falls")
		assert_between(vent["strength"], 0.0, 1.0)

func test_a_mended_section_stops_venting():
	_at(&"port_mid", 0.2)
	assert_gt(GasVents.vents(_d, _grid).size(), 0)
	_at(&"port_mid", GasVents.VENT_BELOW)
	assert_eq(GasVents.vents(_d, _grid), [], "at half, mended")

func test_a_centre_line_block_vents_once():
	for id in ShipDamage.SECTIONS:
		_at(id, 0.05)
	var seen := {}
	for vent: Dictionary in GasVents.vents(_d, _grid):
		assert_false(seen.has(vent["coord"]), "%s listed once" % vent["coord"])
		seen[vent["coord"]] = true

# --- sparks (spec §7) ------------------------------------------------------------

func test_spit_interval_by_share():
	assert_eq(DamageShow.spit_every(0.0), DamageShow.SPIT_EVERY, "a light scratch: as today")
	assert_eq(DamageShow.spit_every(0.25), DamageShow.SPIT_EVERY)
	assert_almost_eq(DamageShow.spit_every(1.0), DamageShow.SPIT_EVERY_WORST, Vector2.ONE * 0.0001)
	var half := DamageShow.spit_every(0.625)
	assert_almost_eq(half, DamageShow.SPIT_EVERY.lerp(DamageShow.SPIT_EVERY_WORST, 0.5), Vector2.ONE * 0.0001)

func test_sparks_quicken_with_damage():
	var show := DamageShow.new()
	add_child_autofree(show)
	var grid := ShipGrid.new()
	var inst := BlockInstance.new()
	inst.block_id = &"hull"
	var coord := Vector3i(0, 0, 0)
	grid.set_block(coord, inst)
	show.stage(grid, coord, BlockDamage.Stage.DAMAGED)
	show.share(coord, 1.0)
	assert_lte(show._spitting[coord]["next"], DamageShow.SPIT_EVERY_WORST.y, "its next spit comes soon")
	for i in 20:
		show._process(DamageShow.SPIT_EVERY_WORST.y)
		assert_lte(show._spitting[coord]["next"], DamageShow.SPIT_EVERY_WORST.y, "and every one after")

func test_a_share_given_before_the_block_spits_is_kept():
	var show := DamageShow.new()
	add_child_autofree(show)
	var grid := ShipGrid.new()
	var inst := BlockInstance.new()
	inst.block_id = &"hull"
	var coord := Vector3i(0, 0, 0)
	grid.set_block(coord, inst)
	show.share(coord, 1.0)
	show.stage(grid, coord, BlockDamage.Stage.DAMAGED)
	assert_lte(show._spitting[coord]["next"], DamageShow.SPIT_EVERY_WORST.y)

# --- in the real scene ---------------------------------------------------------------

func _scene() -> Node:
	var root: Node = load("res://scenes/flight_test.tscn").instantiate()
	add_child_autofree(root)
	return root

func _vent_all(ship: Ship, health: float) -> void:
	for id in ShipDamage.SECTIONS:
		ship.damage.section_damage[id] = ship.damage.section_hp[id] * (1.0 - health)
	ship._apply_view()

func test_a_hurt_ship_vents_and_a_mended_one_stops():
	var root := _scene()
	var ship: Ship = root.get_node("Ship")
	assert_eq(ship.gas_vents.emitters().size(), 0, "as built")
	_vent_all(ship, 0.1)
	assert_gt(ship.gas_vents.emitters().size(), ShipDamage.SECTIONS.size(), "every section vents")
	for id in ShipDamage.SECTIONS:
		ship.repair_section(id, 1.0)
	assert_eq(ship.gas_vents.emitters().size(), 0, "mended")

func test_vents_ride_the_hull():
	var root := _scene()
	var ship: Ship = root.get_node("Ship")
	var universe: Universe = root.get_node("Universe")
	_vent_all(ship, 0.1)
	var emitters := ship.gas_vents.emitters()
	assert_gt(emitters.size(), 0)
	var at := {}
	for e in emitters:
		assert_true(e.local_coords, "%s puffs in the hull's frame" % e.name)
		assert_true(ship.exterior.is_ancestor_of(e), "%s is on the hull" % e.name)
		at[e] = ship.exterior.to_local(e.global_position)
	universe.shift(Vector3(2500, 0, -700))
	var holding := get_tree().get_nodes_in_group(Universe.HOLDS_SHIFT)
	for e in emitters:
		assert_almost_eq(ship.exterior.to_local(e.global_position), at[e] as Vector3, Vector3.ONE * 0.001,
			"%s stays where it was on the hull" % e.name)
		assert_false(holding.has(e), "%s never holds the shift" % e.name)
