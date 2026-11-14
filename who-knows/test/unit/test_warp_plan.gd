extends GutTest

## Can I warp from here, and what will it cost (the warp spec §4.2, §6)?

var _star: WarpTarget
var _near: WarpTarget
var _far: WarpTarget
var _cluster: WarpTarget
var _distant: WarpTarget
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
	_distant = _target(&"p9", WarpTarget.Kind.PLANET, Vector3(0, 0, -8000000), 150000.0)
	_targets = [_star, _near, _far, _cluster, _distant]
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
	assert_eq(p.cost, 40 + 7, "84 km is 6.72 lots of 12.5 km, rounded up")
	assert_almost_eq(p.duration, 18.0 + 84000.0 / 350000.0, 1e-6)
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
	var nose := UniversePoint.at(0, 0, -8000000).minus(_from()).normalized()
	var p := _check(_from(), nose, _distant)
	assert_eq(p.status, WarpPlan.Status.NO_QE, p.text())
	assert_gt(p.cost, 600, "7,800 km of travel")
	assert_eq(p.cost, WarpPlan.cost_of(p.distance))
	assert_eq(p.text(), "WARP · NEED %d QE" % p.cost)

func test_a_warp_into_low_power_warns_but_goes():
	var nose := UniversePoint.at(0, 0, -8000000).minus(_from()).normalized()
	_store.amount = WarpPlan.cost_of(_check(_from(), nose, _distant).distance) + 20
	var p := _check(_from(), nose, _distant)
	assert_eq(p.status, WarpPlan.Status.READY, p.text())
	assert_true(p.into_low_power)
	assert_eq(p.text(), "WARP READY · J · → LOW POWER")

func test_the_nose_must_be_on_the_line():
	var p := _check(_from(), Vector3.FORWARD, _near)
	assert_eq(p.status, WarpPlan.Status.ALIGN)
	assert_almost_eq(p.off_line, PI / 2.0, 0.001)
	assert_eq(p.text(), "ALIGN · 90°")
	var nearly := Vector3.LEFT.rotated(Vector3.UP, deg_to_rad(4.0))
	assert_eq(_check(_from(), nearly, _near).status, WarpPlan.Status.READY, "4° is lined up")

func test_the_cost_is_one_qe_per_12_5_km_rounded_up_and_exact():
	assert_eq(WarpPlan.cost_of(0.0), 40)
	assert_eq(WarpPlan.cost_of(1.0), 41)
	assert_eq(WarpPlan.cost_of(3000000.0), 280, "exactly 240 lots: 0.08 per km would round to 241")
	assert_eq(WarpPlan.cost_of(12500000.0), 1040)

func test_a_moon_s_limit_blocks_like_a_planet_s():
	var moon := _target(&"p1.m1", WarpTarget.Kind.MOON, Vector3(0, 0, 300000), 30000.0)
	_targets.append(moon)
	var p := _check(UniversePoint.at(0, 0, 500000), Vector3.FORWARD, _far)
	assert_eq(p.status, WarpPlan.Status.BLOCKED)
	assert_eq(p.blocker, moon)

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

## The arrival over a place (desert world spec §8.2; phase 3 plan, Task 5).

func _p3_target() -> WarpTarget:
	return SystemRecipe.from_seed(1337).warp_target(&"p3")

## The old maths, as they were before a target had a side: the line to the centre.
func _old_plan(from: UniversePoint, t: WarpTarget) -> Dictionary:
	var line := t.point.minus(from)
	var to_centre := line.length()
	var direction := line / maxf(to_centre, 0.001)
	var distance := to_centre - t.limit
	return {
		"direction": direction,
		"cost": WarpPlan.cost_of(distance),
		"drop": from.plus(direction * maxf(distance, 0.0)),
		"distance": distance,
		"duration": WarpProfile.new(maxf(distance, 0.0)).duration,
	}

func test_targets_without_a_side_are_unchanged():
	var system := SystemRecipe.from_seed(1337)
	var from := system.entry()
	var seen := 0
	for t in system.warp_targets():
		if t.id == &"p3":
			continue
		assert_eq(t.arrive, Vector3.ZERO, "%s has no side" % t.id)
		var want := _old_plan(from, t)
		var p := WarpPlan.check(from, Vector3.LEFT, t, system.warp_targets(), [], null)
		assert_eq(p.direction, want["direction"], "%s's direction" % t.id)
		assert_eq(p.cost, want["cost"], "%s's cost" % t.id)
		assert_eq(p.distance, want["distance"], "%s's distance" % t.id)
		assert_eq(p.duration, want["duration"], "%s's duration" % t.id)
		assert_eq(p.drop.minus(want["drop"]).length(), 0.0, "%s's drop" % t.id)
		assert_eq(p.to_centre, t.point.minus(from).length(), "%s's centre" % t.id)
		seen += 1
	assert_gt(seen, 10, "every other target of 1337 compared (it has 16)")

func test_arrival_over_the_oasis():
	var system := SystemRecipe.from_seed(1337)
	var t := system.warp_target(&"p3")
	var oasis: PlaceDesign
	for p in system.places():
		if p.id == &"oasis":
			oasis = p
	assert_lt(t.arrive.distance_to(oasis.dir()), 1e-9, "p3's side is the oasis")
	var from := system.entry()
	var u := from.minus(t.point).normalized()
	var reach := from.minus(t.point).length()
	var clamp_at := minf(WarpPlan.ARRIVE_MAX, acos(t.limit / reach) - WarpPlan.ARRIVE_SPARE)
	var plan := WarpPlan.check(from, Vector3.LEFT, t, system.warp_targets(), [], null)
	var drop_dir := plan.drop.minus(t.point).normalized()
	assert_almost_eq(plan.drop.minus(t.point).length(), t.limit, 0.01, "drops at the limit")
	if oasis.dir().angle_to(u) <= clamp_at:
		assert_lt(rad_to_deg(drop_dir.angle_to(oasis.dir())), 1.0, "over the oasis")
	else:
		assert_almost_eq(drop_dir.angle_to(u), clamp_at, 1e-6, "at the clamp")
		assert_almost_eq(drop_dir.angle_to(oasis.dir()), oasis.dir().angle_to(u) - clamp_at, 1e-6, "on the way to the oasis")

func test_arrival_never_crosses_the_world():
	var system := SystemRecipe.from_seed(1337)
	var t := system.warp_target(&"p3")
	var well := system.body(&"p3").well_radius
	var rng := RandomNumberGenerator.new()
	rng.seed = 77
	for i in 50:
		var dir := Vector3(rng.randf_range(-1, 1), rng.randf_range(-1, 1), rng.randf_range(-1, 1)).normalized()
		var from := t.point.plus(dir * t.limit * rng.randf_range(1.2, 20.0))
		var p := WarpPlan.check(from, Vector3.LEFT, t, system.warp_targets(), [], null)
		var length := p.drop.minus(from).length()
		var at := 0.0
		var nearest := INF
		while at <= length:
			nearest = minf(nearest, from.plus(p.direction * at).minus(t.point).length())
			at += 1000.0
		nearest = minf(nearest, p.drop.minus(t.point).length())
		assert_gt(nearest, well, "point %d stays outside the well" % i)

func test_aligning_follows_the_drop():
	var t := _target(&"side", WarpTarget.Kind.PLANET, Vector3.ZERO, 16000.0)
	t.arrive = Vector3.LEFT
	var from := UniversePoint.at(40000, 0, 0)
	var targets: Array[WarpTarget] = [t]
	var on_centre := WarpPlan.check(from, Vector3.LEFT, t, targets, [], _store)
	assert_gt(on_centre.off_line, WarpPlan.ALIGN, "the drop is well off the centre line")
	assert_eq(on_centre.status, WarpPlan.Status.ALIGN)
	assert_almost_eq(on_centre.to_centre, 40000.0, 0.01, "to_centre stays the distance to the centre")
	var on_drop := WarpPlan.check(from, on_centre.direction, t, targets, [], _store)
	assert_eq(on_drop.status, WarpPlan.Status.READY, on_drop.text())
	assert_eq(on_drop.direction, on_centre.direction)
	assert_almost_eq(on_drop.distance, on_drop.drop.minus(from).length(), 0.01)

func test_inside_the_limit_is_close_with_or_without_a_side():
	var system := SystemRecipe.from_seed(1337)
	var sided := system.warp_target(&"p3")
	var plain := system.warp_target(&"p2") if system.warp_target(&"p2") != null else system.warp_targets()[0]
	for t in [sided, plain]:
		var from: UniversePoint = t.point.plus(Vector3(t.limit * 0.5, 0.0, 0.0))
		var p := WarpPlan.check(from, Vector3.LEFT, t, system.warp_targets(), [], null)
		var want := _old_plan(from, t)
		assert_eq(p.status, WarpPlan.Status.CLOSE, "%s: inside its limit" % t.id)
		assert_eq(p.distance, want["distance"], "%s: the old maths" % t.id)
		assert_eq(p.direction, want["direction"], "%s: the old direction" % t.id)
