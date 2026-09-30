extends GutTest

## SaveCodec and every pure part's to_dict/from_dict, through JSON and back
## (docs/superpowers/specs/2026-09-26-saving-design.md §11.1): JSON reads every
## number back as a float, so each part must turn it back into what it was.

static func _json(v: Variant) -> Variant:
	return JSON.parse_string(JSON.stringify(v, "", false, true))

func test_a_vector_round_trips():
	var v := Vector3(1.25, -3.5e6, 0.000123)
	assert_eq(SaveCodec.to_vec3(_json(SaveCodec.vec3(v))), v)

func test_a_cell_round_trips_as_ints():
	var c := Vector3i(-3, 1, 7)
	var back := SaveCodec.to_vec3i(_json(SaveCodec.vec3i(c)))
	assert_eq(back, c)
	assert_eq(SaveCodec.to_cell(SaveCodec.cell_key(c)), c)

func test_a_transform_round_trips():
	var t := Transform3D(Basis.from_euler(Vector3(0.3, -1.2, 2.0)), Vector3(4, -5, 6.5))
	var back := SaveCodec.to_transform(_json(SaveCodec.transform(t)))
	assert_true(back.is_equal_approx(t), "%s == %s" % [back, t])

func test_a_universe_point_a_million_kilometres_out_round_trips_exactly():
	var u := UniversePoint.at(1_000_000_000, -987_654_321, 42).plus(Vector3(0.125, 0.5, 0.75))
	var back := SaveCodec.to_upoint(_json(SaveCodec.upoint(u)))
	assert_eq([back.x, back.y, back.z, back.fx, back.fy, back.fz], [u.x, u.y, u.z, u.fx, u.fy, u.fz])

func test_bad_input_reads_as_defaults():
	assert_eq(SaveCodec.to_vec3(null, Vector3.ONE), Vector3.ONE)
	assert_eq(SaveCodec.to_basis("nonsense"), Basis.IDENTITY)
	assert_eq(SaveCodec.to_transform(7), Transform3D.IDENTITY)

func test_the_store_keeps_its_amount_within_its_capacity():
	var store := QuantumStore.new(1200, 600)
	store.spend(123, &"test")
	var again := QuantumStore.new(1200, 600)
	again.from_dict(_json(store.to_dict()))
	assert_eq(again.amount, 477)
	var small := QuantumStore.new(100, 0)
	small.from_dict(_json(store.to_dict()))
	assert_eq(small.amount, 100, "never more than it holds")

func test_the_suit_cell_keeps_its_charge():
	var cell := SuitCell.new()
	cell.add(42.5)
	var again := SuitCell.new()
	again.from_dict(_json(cell.to_dict()))
	assert_eq(again.charge, 42.5)

func test_the_ledger_keeps_what_was_taken():
	var ledger := SalvageLedger.new()
	ledger.take(&"near", 3)
	ledger.take(&"near", 0)
	ledger.take(&"far", 11)
	var again := SalvageLedger.new()
	again.take(&"near", 5)
	again.from_dict(_json(ledger.to_dict()))
	assert_true(again.is_taken(&"near", 3))
	assert_true(again.is_taken(&"near", 0))
	assert_true(again.is_taken(&"far", 11))
	assert_false(again.is_taken(&"near", 5), "replaced, not merged")
	assert_eq(again.remaining(&"near", 12), 10)

func test_a_blueprint_round_trips_as_plain_data():
	var grid := ShipGrid.new()
	for at in [Vector3i(0, 0, 0), Vector3i(-1, 1, 2), Vector3i(3, 0, -4)]:
		var b := BlockInstance.new()
		b.block_id = &"hull"
		b.orientation = 5
		b.damage = 17.0
		grid.set_block(at, b)
	var bp := ShipBlueprint.from_grid(grid, "Test")
	var back := ShipBlueprint.from_dict(_json(bp.to_dict()))
	assert_eq(back.ship_name, "Test")
	assert_eq(back.coords, bp.coords)
	assert_eq(back.block_ids, bp.block_ids)
	assert_eq(back.orientations, bp.orientations)
	assert_eq(back.damage_values, bp.damage_values)
	assert_eq(back.to_grid().coords().size(), 3)

func test_the_flight_settings_round_trip():
	var fc := FlightComputer.new()
	fc.speed_locked = true
	fc.locked_speed = 31.5
	fc.heading_hold = true
	fc.heading = Vector3(0, 0.6, -0.8)
	fc.set_pilot_input(Vector3(0, 0, -1), Vector3(0.5, 0, 0), true)
	var again := FlightComputer.new()
	again.from_dict(_json(fc.to_dict()))
	assert_true(again.assist_enabled)
	assert_true(again.speed_locked)
	assert_eq(again.locked_speed, 31.5)
	assert_true(again.heading_hold)
	assert_almost_eq(again.heading, Vector3(0, 0.6, -0.8), Vector3.ONE * 1e-6)
	assert_eq(again.to_dict()["burn"], [0.0, 0.0, -1.0], "a latched burn keeps burning")
	assert_true(again.to_dict()["boost"])
	fc.free()
	again.free()

func test_assist_off_drops_the_locks_it_needs():
	var fc := FlightComputer.new()
	var again := FlightComputer.new()
	again.from_dict({"assist": false, "speed_locked": true, "heading_hold": true})
	assert_false(again.assist_enabled)
	assert_false(again.speed_locked)
	assert_false(again.heading_hold)
	fc.free()
	again.free()

func test_an_idle_airlock_comes_back_as_it_stood():
	var cycle := AirlockCycle.new()
	cycle.restore_idle(0.0, AirlockCycle.Door.OUTER)
	assert_eq(cycle.stage, AirlockCycle.Stage.IDLE)
	assert_eq(cycle.outer_open, 1.0)
	assert_eq(cycle.outer_bolts, 1.0)
	assert_eq(cycle.inner_open, 0.0)
	assert_false(cycle.pressurized())

func test_an_airlock_never_comes_back_open_to_the_wrong_side():
	var cycle := AirlockCycle.new()
	cycle.restore_idle(AirlockCycle.ATMOSPHERE, AirlockCycle.Door.OUTER)
	assert_eq(cycle.open_side(), AirlockCycle.Door.NONE, "air behind an open outer hatch")
	cycle.restore_idle(0.0, AirlockCycle.Door.INNER)
	assert_eq(cycle.open_side(), AirlockCycle.Door.NONE, "vacuum behind an open inner hatch")

func test_a_burning_flare_keeps_burning_with_what_it_had_left():
	var flare := Flare.new()
	flare.burn = Flare.Burn.BURNING
	flare.burn_left = 12.5
	var again := Flare.new()
	again.restore(_json(flare.save()))
	assert_eq(again.burn, Flare.Burn.BURNING)
	assert_eq(again.burn_left, 12.5)
	flare.free()
	again.free()

func test_a_lamp_and_a_datapad_stay_switched_on():
	var lamp := HandLamp.new()
	lamp.on = true
	var lamp_again := HandLamp.new()
	lamp_again.restore(_json(lamp.save()))
	assert_true(lamp_again.on)
	var pad := Datapad.new()
	pad.on = true
	var pad_again := Datapad.new()
	pad_again.restore(_json(pad.save()))
	assert_true(pad_again.on)
	for n in [lamp, lamp_again, pad, pad_again]:
		n.free()
