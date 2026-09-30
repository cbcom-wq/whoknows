extends GutTest

## Can I warp from here, and what will it cost (the warp spec §4.2, §6)?

var _star: WarpTarget
var _near: WarpTarget
var _far: WarpTarget
var _cluster: WarpTarget
var _targets: Array[WarpTarget] = []
var _store: QuantumStore

func _target(id: StringName, kind: WarpTarget.Kind, at: Vector3, limit: float) -> WarpTarget:
	var t := WarpTarget.new()
	t.id = id
	t.kind = kind
	t.name = String(id).to_upper()
	t.point = UniversePoint.at(int(at.x), int(at.y), int(at.z))
	t.radius = 800.0
	t.edge = limit - 14000.0
	t.limit = limit
	return t

func before_each():
	_star = _target(&"star", WarpTarget.Kind.STAR, Vector3.ZERO, 25000.0)
	_near = _target(&"p1", WarpTarget.Kind.PLANET, Vector3(0, 0, -60000), 16000.0)
	_far = _target(&"p2", WarpTarget.Kind.PLANET, Vector3(0, 0, -200000), 16000.0)
	_cluster = _target(&"belt_0.c1", WarpTarget.Kind.CLUSTER, Vector3(60000, 0, -60000), 18000.0)
	_targets = [_star, _near, _far, _cluster]
	_store = QuantumStore.new(1200, 1200)

## From 100 km east of p1, along the line through the cluster, nose on p1.
func _from() -> UniversePoint:
	return UniversePoint.at(100000, 0, -60000)

func _check(from: UniversePoint, nose: Vector3, target: WarpTarget, inside: Array[StringName] = [],
		busy: StringName = &"") -> WarpPlan:
	return WarpPlan.check(from, nose, target, _targets, inside, _store, busy)

func test_nothing_charted():
	assert_eq(_check(_from(), Vector3.LEFT, null).status, WarpPlan.Status.NONE)
	assert_eq(_check(_from(), Vector3.LEFT, null).text(), "")

func test_ready_with_the_cost_the_time_and_the_drop_out_point():
	var p := _check(_from(), Vector3.LEFT, _near)
	assert_eq(p.status, WarpPlan.Status.READY, p.text())
	assert_almost_eq(p.distance, 84000.0, 0.01)
	assert_eq(p.cost, 40 + 336)
	assert_almost_eq(p.duration, 18.0 + 84000.0 / 5000.0, 1e-6)
	assert_true(p.drop.is_equal_approx(UniversePoint.at(16000, 0, -60000)))
	assert_true(p.direction.is_equal_approx(Vector3.LEFT))
	assert_false(p.into_low_power)
	assert_eq(p.text(), "WARP READY · J")

func test_a_cluster_on_the_line_does_not_block():
	var p := _check(_from(), Vector3.LEFT, _near)
	assert_eq(p.status, WarpPlan.Status.READY, "the cluster at 60 km east lies on the line")

func test_a_planet_or_the_star_on_the_line_blocks():
	var p := _check(UniversePoint.at(0, 0, 40000), Vector3.FORWARD, _far)
	assert_eq(p.status, WarpPlan.Status.BLOCKED)
	assert_eq(p.blocker, _star, "the nearest blocker along the line")
	assert_eq(p.text(), "BLOCKED BY STAR")

func test_inside_a_limit_says_how_far_to_clear():
	var p := _check(UniversePoint.at(0, 0, 20000), Vector3.FORWARD, _near, [&"star"])
	assert_eq(p.status, WarpPlan.Status.INSIDE)
	assert_eq(p.blocker, _star)
	assert_almost_eq(p.clear_in, 5000.0, 0.01)
	assert_eq(p.text(), "CLEAR OF STAR IN 5.0 KM")

func test_near_the_target_you_fly():
	var p := _check(UniversePoint.at(0, 0, -40000), Vector3.FORWARD, _near)
	assert_eq(p.status, WarpPlan.Status.CLOSE, "4 km short of its limit")
	assert_eq(p.text(), "FLY · 18.0 KM TO P1", "measured to the edge, not the limit")
	p = _check(UniversePoint.at(0, 0, -50000), Vector3.FORWARD, _near, [&"p1"])
	assert_eq(p.status, WarpPlan.Status.CLOSE, "inside the target's own limit")

func test_crew_outside_and_an_airlock_cycling_come_first():
	assert_eq(_check(_from(), Vector3.LEFT, _near, [], &"crew").text(), "WARP · CREW OUTSIDE")
	assert_eq(_check(_from(), Vector3.LEFT, _near, [], &"airlock").text(), "WARP · AIRLOCK CYCLING")

func test_low_power_and_too_little_qe_are_refused():
	_store.amount = 100
	assert_eq(_check(_from(), Vector3.LEFT, _near).status, WarpPlan.Status.LOW_POWER)
	_store.amount = 200
	var p := _check(_from(), Vector3.LEFT, _near)
	assert_eq(p.status, WarpPlan.Status.NO_QE)
	assert_eq(p.text(), "WARP · NEED 376 QE")

func test_a_warp_into_low_power_warns_but_goes():
	_store.amount = 450
	var p := _check(_from(), Vector3.LEFT, _near)
	assert_eq(p.status, WarpPlan.Status.READY)
	assert_true(p.into_low_power)
	assert_eq(p.text(), "WARP READY · J · → LOW POWER")

func test_the_nose_must_be_on_the_line():
	var p := _check(_from(), Vector3.FORWARD, _near)
	assert_eq(p.status, WarpPlan.Status.ALIGN)
	assert_almost_eq(p.off_line, PI / 2.0, 0.001)
	assert_eq(p.text(), "ALIGN · 90°")
	var nearly := Vector3.LEFT.rotated(Vector3.UP, deg_to_rad(4.0))
	assert_eq(_check(_from(), nearly, _near).status, WarpPlan.Status.READY, "4° is lined up")

func test_the_cost_rounds_up_per_kilometre():
	assert_eq(WarpPlan.cost_of(0.0), 40)
	assert_eq(WarpPlan.cost_of(1.0), 41)
	assert_eq(WarpPlan.cost_of(60000.0), 280)
	assert_eq(WarpPlan.cost_of(250000.0), 1040)

func test_a_drop_out_inside_a_rock_is_stepped_back_clear():
	var recipe := AsteroidRecipe.new(1337)
	var start := recipe.find_start()
	var region := AsteroidRecipe.cell_of(AsteroidRecipe.Tier.GIANT, start.plus(Vector3(0, 0, -1000)))
	var rock := recipe.cell_rocks(AsteroidRecipe.Tier.GIANT, region)[0]
	var centre := AsteroidRecipe.cell_corner(AsteroidRecipe.Tier.GIANT, region).plus(rock.local)
	assert_true(WarpPlan.rock_near(recipe, centre))
	var clear := WarpPlan.stepped_clear(recipe, centre, Vector3.FORWARD)
	assert_false(WarpPlan.rock_near(recipe, clear))
	assert_almost_eq(clear.minus(centre).normalized().dot(Vector3.BACK), 1.0, 1e-4, "stepped back along the line")
	assert_gt(clear.minus(centre).length(), rock.radius + WarpPlan.ROCK_CLEAR[AsteroidRecipe.Tier.GIANT] - 1.0)

func test_a_clear_drop_out_stays_put():
	var recipe := AsteroidRecipe.new(1337)
	for k in 20:
		var u := UniversePoint.at(k * 7000, 90000, -k * 3000)
		if not WarpPlan.rock_near(recipe, u):
			assert_true(WarpPlan.stepped_clear(recipe, u, Vector3.FORWARD).is_equal_approx(u))
			return
	fail_test("no clear point among twenty")
