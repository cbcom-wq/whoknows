extends GutTest

## The speed limit rises with altitude inside a well (the world scale spec
## §6): 120 m/s on the ground, 1 m/s more for every 40 m up, at most 1,500,
## easing back to 120 over the top tenth of the well.

const FC := preload("res://src/flight/flight_computer.gd")

func test_the_limit_climbs_with_altitude():
	assert_almost_eq(FC.speed_limit(0.0, 60000.0), 120.0, 1e-6)
	assert_almost_eq(FC.speed_limit(4000.0, 60000.0), 220.0, 1e-6)
	assert_almost_eq(FC.speed_limit(40000.0, 60000.0), 1120.0, 1e-6)
	assert_almost_eq(FC.speed_limit(54000.0, 60000.0), 1470.0, 1e-6, "the peak, just below the easing")

func test_it_eases_back_over_the_top_tenth_of_the_well():
	assert_almost_eq(FC.speed_limit(57000.0, 60000.0), lerpf(120.0, 1500.0, 0.5), 1e-6, "capped, then half eased")
	assert_almost_eq(FC.speed_limit(60000.0, 60000.0), 120.0, 1e-6)
	assert_almost_eq(FC.speed_limit(14250.0, 15000.0), lerpf(120.0, 120.0 + 14250.0 / 40.0, 0.5), 1e-6)

func test_the_limit_at_or_below_the_ground_is_the_cruise_ceiling():
	assert_almost_eq(FC.speed_limit(-3.0, 60000.0), 120.0, 1e-6)
	assert_almost_eq(FC.speed_limit(INF, 60000.0), 120.0, 1e-6)
	assert_almost_eq(FC.speed_limit(100.0, 0.0), 120.0, 1e-6)

# --- where you are ----------------------------------------------------------------

var _universe: Universe
var _where: Whereabouts
var _focus: Node3D
var _system: SystemRecipe

func _place(u: UniversePoint) -> void:
	_universe.origin = u
	_focus.global_position = Vector3.ZERO

func _setup_where() -> void:
	_system = SystemRecipe.from_seed(1337)
	_universe = Universe.new()
	add_child_autofree(_universe)
	_focus = Node3D.new()
	add_child_autofree(_focus)
	_universe.set_focus(_focus)
	_where = Whereabouts.new()
	add_child_autofree(_where)
	_where.setup(_system, _universe)

func test_the_well_you_are_in_and_your_height_over_its_ground():
	_setup_where()
	var p := _system.planets()[0]
	var t := _where.terrain_of(p)
	_place(p.point.plus(Vector3.UP * (p.radius + t.height_at(Vector3.UP) + 4000.0)))
	assert_eq(_where.well(), p)
	assert_almost_eq(_where.altitude(), 4000.0, 0.1)
	_place(p.point.plus(Vector3.UP * (p.well_radius + 100.0)))
	assert_null(_where.well())
	assert_eq(_where.altitude(), INF)

## A hull and its flight computer 4,000 m over the first planet's ground,
## flying at `speed` m/s down the nose. Fills `_hull` and `_fc`.
var _hull: RigidBody3D
var _fc: FlightComputer

func _fly_over_a_planet(speed: float) -> void:
	_setup_where()
	var p := _system.planets()[0]
	var t := _where.terrain_of(p)
	_hull = RigidBody3D.new()
	_hull.mass = 95300.0
	add_child_autofree(_hull)
	_fc = FlightComputer.new()
	_fc.hull_path = NodePath("../" + _hull.name)
	_hull.get_parent().add_child(_fc)
	autofree(_fc)
	_fc.whereabouts = _where
	_universe.set_focus(_hull)
	_universe.origin = p.point.plus(Vector3.UP * (p.radius + t.height_at(Vector3.UP) + 4000.0))
	_hull.global_position = Vector3.ZERO
	_hull.linear_velocity = Vector3(0, 0, -speed)

## Moves the hull out past the well's edge, where the limit is the cruise ceiling.
func _leave_the_well() -> void:
	var p := _system.planets()[0]
	_place(p.point.plus(Vector3.UP * (p.well_radius + 100.0)))

func test_the_flight_computer_holds_you_to_the_limit_where_you_are():
	_fly_over_a_planet(500.0)
	var hull := _hull
	var fc := _fc
	fc._physics_process(1.0 / 60.0)
	assert_almost_eq(fc.current_limit, 220.0, 0.5)
	assert_almost_eq(hull.linear_velocity.length(), 220.0, 0.5)
	var tm := fc.build_telemetry()
	assert_almost_eq(tm.cruise_limit, 220.0, 0.5)
	assert_true(tm.limit_raised)

func test_no_limit_with_the_assist_off():
	_fly_over_a_planet(500.0)
	_fc.assist_enabled = false
	_fc._physics_process(1.0 / 60.0)
	assert_almost_eq(_hull.linear_velocity.length(), 500.0, 0.5, "the pilot's own risk")

func test_boost_never_raises_the_limit():
	_fly_over_a_planet(500.0)
	_fc.set_pilot_input(Vector3(0, 0, -1), Vector3.ZERO, true)
	_fc._physics_process(1.0 / 60.0)
	assert_true(_fc.boosting, "boost was applying")
	assert_almost_eq(_fc.current_limit, 220.0, 0.5, "the same limit with boost held")
	assert_almost_eq(_hull.linear_velocity.length(), 220.0, 0.5)

func test_a_lock_set_high_in_a_well_is_clamped_after_leaving_it():
	_fly_over_a_planet(1400.0)
	_fc.speed_locked = true
	_fc.locked_speed = 1400.0
	_leave_the_well()
	_fc._physics_process(1.0 / 60.0)
	assert_almost_eq(_fc.current_limit, 120.0, 1e-6)
	assert_almost_eq(_fc.locked_speed, 120.0, 1e-6, "no stale lock")
	assert_almost_eq(_fc.build_telemetry().locked_speed, 120.0, 1e-6, "nor on the readout")

func test_the_panel_shows_the_limit_only_while_it_is_raised():
	var panel := VelocityPanel.new()
	add_child_autofree(panel)
	var tm := VehicleTelemetry.new()
	tm.assist_enabled = true
	tm.cruise_limit = 1470.0
	tm.limit_raised = true
	panel.render(tm)
	assert_true(panel.mode_label.text.ends_with("LIMIT 1470"), panel.mode_label.text)
	tm.cruise_limit = 120.0
	tm.limit_raised = false
	panel.render(tm)
	assert_false(panel.mode_label.text.contains("LIMIT"), panel.mode_label.text)
