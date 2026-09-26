extends GutTest

## SuitCell (docs/superpowers/specs/2026-09-24-quantum-energy-design.md §9),
## headless: a charge of 0 to 100 QE, empty at the start, spent at 1 QE per
## m/s of the thrusters' Δv; amber below 25, critical below 10, dry at 0.

const DT := 1.0 / 60.0

func test_it_starts_empty_and_dry():
	var cell := SuitCell.new()
	assert_eq(cell.charge, 0.0)
	assert_eq(cell.level(), &"dry")
	assert_eq(SuitCell.CAPACITY, 100.0)
	assert_eq(SuitCell.GO_OUT_MIN, 10.0)

func test_delta_v_costs_one_qe_per_metre_a_second():
	var cell := SuitCell.new()
	cell.charge = 50.0
	assert_true(cell.spend_dv(2.5))
	assert_almost_eq(cell.charge, 47.5, 0.0001)

func test_the_last_step_empties_it_and_then_it_is_dry():
	var cell := SuitCell.new()
	cell.charge = 0.02
	assert_true(cell.spend_dv(0.5), "the step that empties it still goes ahead")
	assert_eq(cell.charge, 0.0, "never below 0")
	assert_false(cell.spend_dv(0.5), "false when dry")
	assert_eq(cell.charge, 0.0)

func test_adding_fills_to_capacity_and_says_how_much_went_in():
	var cell := SuitCell.new()
	assert_eq(cell.add(30.0), 30.0)
	assert_eq(cell.charge, 30.0)
	assert_almost_eq(cell.add(86.4), 70.0, 0.0001, "only what fits")
	assert_eq(cell.charge, SuitCell.CAPACITY, "exactly full")
	assert_eq(cell.room(), 0.0)
	assert_eq(cell.add(5.0), 0.0)

func test_the_levels():
	var cell := SuitCell.new()
	for case in [[100.0, &"ok"], [25.0, &"ok"], [24.9, &"low"], [10.0, &"low"], [9.9, &"critical"],
			[0.01, &"critical"], [0.0, &"dry"]]:
		cell.charge = case[0]
		assert_eq(cell.level(), case[1], "at %.2f" % case[0])

## Spec §9: 2.5 QE a second at full thrust -- the suit's 2.5 m/s^2 -- assist
## on, as you fly.
func test_full_thrust_for_a_second_costs_2_5():
	var cell := SuitCell.new()
	cell.charge = SuitCell.CAPACITY
	var v := Vector3.ZERO
	for i in 60:
		var next := Suit.step(v, Vector3.ZERO, Vector3(0, 0, -1), Basis.IDENTITY, true, DT)
		cell.spend_dv((next - v).length())
		v = next
	assert_almost_eq(SuitCell.CAPACITY - cell.charge, 2.5, 0.001)

## Spec §9: holding station beside a drifting, slowly turning ship costs
## almost nothing -- only what it takes to follow the ship's turn.
func test_holding_station_beside_a_drifting_ship_costs_almost_nothing():
	var cell := SuitCell.new()
	cell.charge = SuitCell.CAPACITY
	var drift := Vector3(2, 0, 1)
	var spin := Vector3(0, deg_to_rad(2.0), 0)
	var centre := Vector3.ZERO
	var p := Vector3(6, 0, 0)
	var v := drift + spin.cross(p - centre)
	for i in 600:   # 10 s
		var v_ref := drift + spin.cross(p - centre)
		var next := Suit.step(v, v_ref, Vector3.ZERO, Basis.IDENTITY, true, DT)
		cell.spend_dv((next - v).length())
		v = next
		p += v * DT
		centre += drift * DT
	assert_lt((SuitCell.CAPACITY - cell.charge) / 10.0, 0.1, "under 0.1 QE a second")
