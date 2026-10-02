extends GutTest

## How fast a warp goes (the warp spec §5.3; the world scale spec §3.4): 18 s and 1 s more per 350 km, up to the peak over 4 s and back down over the last 4, 120 m/s at both ends.

func test_the_duration_is_eighteen_seconds_and_one_more_per_350_km():
	assert_almost_eq(WarpProfile.new(350000.0).duration, 19.0, 1e-6)
	assert_almost_eq(WarpProfile.new(3500000.0).duration, 28.0, 1e-6)
	assert_almost_eq(WarpProfile.new(12250000.0).duration, 53.0, 1e-6)

func test_the_distance_comes_out_exact_and_the_ends_are_at_cruise():
	for d in [5000.0, 350000.0, 4600000.0, 12500000.0]:
		var p := WarpProfile.new(d)
		assert_almost_eq(p.travelled_at(0.0), 0.0, 1e-6)
		assert_almost_eq(p.travelled_at(p.duration), d, d * 1e-6)
		assert_almost_eq(p.speed_at(0.0), WarpProfile.EDGE_SPEED, 1e-6)
		assert_almost_eq(p.speed_at(p.duration), WarpProfile.EDGE_SPEED, 1e-6)
		var sum := 0.0
		var dt := 0.001
		var t := 0.0
		while t < p.duration:
			sum += p.speed_at(t + dt * 0.5) * dt
			t += dt
		assert_almost_eq(sum, d, d * 0.001, "the distance is the speed's integral")

func test_the_peak_makes_the_distance():
	var p := WarpProfile.new(3500000.0)
	assert_almost_eq(p.peak, 120.0 + (3500000.0 - 120.0 * 28.0) / 24.0, 0.01)
	assert_almost_eq(p.speed_at(14.0), p.peak, 1e-6)

func test_typical_trips_average_about_thirty_seconds():
	var total := 0.0
	var trips := 0
	for k in 200:
		var s := SystemRecipe.from_seed(k * 7919 + 3)
		var ts := s.warp_targets().filter(func(t: WarpTarget) -> bool:
			return t.kind == WarpTarget.Kind.STAR or t.kind == WarpTarget.Kind.PLANET)
		for i in ts.size():
			for j in range(i + 1, ts.size()):
				var a: WarpTarget = ts[i]
				var b: WarpTarget = ts[j]
				var travel := a.point.minus(b.point).length() - a.limit - b.limit
				if travel >= WarpPlan.MIN_TRAVEL:
					total += WarpProfile.new(travel).duration
					trips += 1
	var mean := total / trips
	gut.p("%d trips between the star and planets: %.1f s of travel on average" % [trips, mean])
	assert_between(mean, 25.0, 35.0)
