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

func test_the_flight_computer_holds_you_to_the_limit_where_you_are():
	_setup_where()
	var p := _system.planets()[0]
	var t := _where.terrain_of(p)
	var hull := RigidBody3D.new()
	hull.mass = 95300.0
	add_child_autofree(hull)
	var fc := FlightComputer.new()
	fc.hull_path = NodePath("../" + hull.name)
	hull.get_parent().add_child(fc)
	autofree(fc)
	fc.whereabouts = _where
	_universe.set_focus(hull)
	_universe.origin = p.point.plus(Vector3.UP * (p.radius + t.height_at(Vector3.UP) + 4000.0))
	hull.global_position = Vector3.ZERO
	hull.linear_velocity = Vector3(0, 0, -500)
	fc._physics_process(1.0 / 60.0)
	assert_almost_eq(fc.current_limit, 220.0, 0.5)
	assert_almost_eq(hull.linear_velocity.length(), 220.0, 0.5)
	var tm := fc.build_telemetry()
	assert_almost_eq(tm.cruise_limit, 220.0, 0.5)
	assert_true(tm.limit_raised)

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
