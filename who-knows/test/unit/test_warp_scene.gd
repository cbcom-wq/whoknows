extends GutTest

## The warp in the real flight scene (the warp spec §5, §10.1): the start is
## inside a cluster's limit; from clear space a charted warp flies you to a
## planet's limit with the rocks there loaded and none on you; a save during
## travel loads at the drop-out point; the hop waits while you warp.

var _root: Node
var _ship: Ship
var _universe: Universe
var _stream: AsteroidStream
var _system: SystemRecipe

func before_each():
	_root = load("res://scenes/flight_test.tscn").instantiate()
	add_child_autofree(_root)
	_ship = _root.get_node("Ship")
	_universe = _root.get_node("Universe")
	_stream = _root.get_node("AsteroidStream")
	_system = _root.system
	await wait_physics_frames(3)
	_ship.warp.set_physics_process(false)

func _focus() -> UniversePoint:
	return _universe.to_universe(_ship.exterior.global_position)

## The hull at rest at `at`, nose on `look`, the world ready, as the hop does.
func _put(at: UniversePoint, look: UniversePoint) -> void:
	var hull := _ship.exterior
	hull.linear_velocity = Vector3.ZERO
	hull.angular_velocity = Vector3.ZERO
	var dir := look.minus(at).normalized()
	var up := Vector3.UP if absf(dir.dot(Vector3.UP)) < 0.99 else Vector3.BACK
	hull.global_transform = Transform3D(Basis.looking_at(dir, up), _universe.to_engine(at))
	_universe.check()
	_root.star_system.place_all()
	_root.star_system.whereabouts.look()
	_stream.update(0.0, true)

## Charts a warp to a target of `kind` reachable from high above it; returns it.
func _ready_above(kind: WarpTarget.Kind) -> WarpTarget:
	_ship.quantum.store.amount = _ship.quantum.store.capacity
	for t in _system.warp_targets():
		if t.kind != kind:
			continue
		_put(t.point.plus(Vector3.UP * (t.limit + 25000.0)), t.point)
		_ship.warp.chart(t.id)
		if _ship.warp.check().status == WarpPlan.Status.READY:
			return t
	fail_test("no target of kind %d reachable from above" % kind)
	return null

func _run(seconds: float) -> void:
	var dt := 1.0 / 60.0
	for i in ceili(seconds / dt):
		_ship.warp.step(dt)
		_root.star_system.streak = _ship.warp.streak()
		_root.star_system.place_all()

func test_the_start_is_inside_a_cluster_s_limit_so_the_warp_waits():
	_ship.warp.chart(_system.planets()[0].id)
	var p: WarpPlan = _ship.warp.check()
	assert_true(p.status == WarpPlan.Status.INSIDE or p.status == WarpPlan.Status.CLOSE, p.text())
	assert_false(_root.star_system.whereabouts.warp_clear())

func test_a_warp_to_a_planet_arrives_with_the_rocks_loaded_and_none_on_you():
	var t := _ready_above(WarpTarget.Kind.PLANET)
	_ship.warp.engage()
	_run(WarpDrive.SPOOL + 1.0)
	assert_true(_stream.suspended, "the rocks stop streaming")
	_run(5.0)
	assert_lt(_ship.exterior.global_position.length(), Universe.FORCE_AT, "the origin keeps up")
	for p: BodyProxy in _root.star_system.proxies:
		assert_lt(p.global_position.distance_to(_ship.exterior.global_position), BodyProxy.PROXY_AT + 100.0,
			"%s placed for where you are" % p.name)
	_run(_ship.warp.time_left() + 0.1)
	await wait_physics_frames(2)
	assert_false(_stream.suspended)
	var here := _focus()
	assert_almost_eq(here.minus(t.point).length(), t.limit, 400.0)
	assert_true(_stream.is_loaded(0, AsteroidRecipe.cell_of(0, here)), "rubble loaded where you arrived")
	assert_false(WarpPlan.rock_near(_stream.recipe, here), "nothing on you")
	assert_eq(_ship.exterior.collision_mask & AsteroidBody.LAYER, AsteroidBody.LAYER, "the hull bumps rocks again")

func test_a_warp_to_a_cluster_arrives_clear_of_rocks():
	var t := _ready_above(WarpTarget.Kind.CLUSTER)
	_ship.warp.engage()
	_run(WarpDrive.SPOOL + 1.0)
	_run(_ship.warp.time_left() + 0.1)
	await wait_physics_frames(2)
	assert_false(WarpPlan.rock_near(_stream.recipe, _focus()), "stepped clear of %s's rocks" % t.id)

func test_a_save_during_travel_loads_at_the_drop_out_point():
	var t := _ready_above(WarpTarget.Kind.PLANET)
	var paid: int = _ship.quantum.store.amount - _ship.warp.plan.cost
	_ship.warp.engage()
	_run(WarpDrive.SPOOL + 4.0)
	var saved: Dictionary = _root.capture()
	var at := SaveCodec.to_upoint(saved["ship"]["hull"]["at"])
	assert_almost_eq(at.minus(t.point).length(), t.limit, 400.0)
	assert_almost_eq(SaveCodec.to_vec3(saved["ship"]["hull"]["v"]).length(), WarpProfile.EDGE_SPEED, 0.5)
	assert_eq(int(saved["ship"]["store"]["amount"]), paid, "the warp is paid for")
	assert_eq(String(saved["ship"]["warp"]["charted"]), String(t.id))

func test_the_hop_is_refused_while_warping():
	_ready_above(WarpTarget.Kind.PLANET)
	_ship.warp.engage()
	assert_false(_root.hop(1), "not while spooling")
	_run(WarpDrive.SPOOL + 1.0)
	assert_false(_root.hop(1), "not while travelling")

func test_j_is_bound_to_the_warp():
	assert_true(InputMap.has_action(&"warp"))
	var keys := InputMap.action_get_events(&"warp").map(func(e: InputEvent) -> int: return (e as InputEventKey).physical_keycode)
	assert_true(keys.has(KEY_J))

func test_the_hud_has_the_warp_panel_and_body_brackets():
	var panel: WarpPanel = _root.warp_panel
	assert_not_null(panel)
	assert_true(_root.get_node("HudRoot/Screen/Band/Row").is_ancestor_of(panel))
	var markers: Array = _root.body_markers
	assert_eq(markers.size(), 3, "one per view")
	for m: CourseMarker in _root.course_markers:
		assert_eq(m.warp, _ship.warp)

func test_crossing_a_limit_toasts():
	var t := _ready_above(WarpTarget.Kind.PLANET)
	var panel: WarpPanel = _root.warp_panel
	_put(t.point.plus(Vector3.UP * (t.limit - 500.0)), t.point)
	assert_eq(panel.toast_label.text, "ENTERING %s" % t.name)
	_put(t.point.plus(Vector3.UP * (t.limit + 20000.0)), t.point)
	assert_true(panel.toast_label.text.begins_with("LEAVING %s" % t.name), panel.toast_label.text)
