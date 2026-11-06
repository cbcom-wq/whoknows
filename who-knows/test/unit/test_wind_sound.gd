extends GutTest

## Wind (desert world spec §6.4): heard through the hull when seated, in the
## helmet on foot on a world, and not at all where there is no air.

var _wind: WindSound

func before_each():
	AudioBuses.ensure()
	_wind = WindSound.new()
	add_child_autofree(_wind)

func _warm() -> void:
	Synth.warm_up()
	var deadline := Time.get_ticks_msec() + 20000
	while not Synth.is_warm() and Time.get_ticks_msec() < deadline:
		await get_tree().process_frame

func test_space_is_silent():
	assert_eq(WindSound.level(0.0, 300.0, 1.0), 0.0)

func test_on_the_ground_it_is_the_air_alone():
	assert_almost_eq(WindSound.level(1.0, 0.0, 1.0), WindSound.AMBIENT, 1e-6)
	assert_almost_eq(WindSound.level(0.35, 0.0, 1.0), 0.35 * WindSound.AMBIENT, 1e-6)

func test_in_flight_it_rises_with_speed():
	assert_eq(WindSound.level(1.0, 150.0, 1.0), 1.0)
	assert_almost_eq(WindSound.level(0.5, 75.0, 1.0), 0.5 * (WindSound.AMBIENT + 0.5), 1e-6)

func test_gusts_are_slow_and_bounded():
	var t := 0.0
	while t < 60.0:
		var g := WindSound.gust(t)
		assert_between(g, 0.5, 1.0)
		assert_lt(absf(WindSound.gust(t + 0.05) - g), 0.02)
		t += 0.05

func test_where_you_hear_it():
	assert_eq(WindSound.ear(Avatar.Mode.FIELD, false), WindSound.Ear.HELMET)
	assert_eq(WindSound.ear(Avatar.Mode.PLATING, true), WindSound.Ear.HULL)
	assert_eq(WindSound.ear(Avatar.Mode.SUIT, false), WindSound.Ear.NONE)
	assert_eq(WindSound.ear(Avatar.Mode.PLATING, false), WindSound.Ear.NONE)

func test_stepping_out_hands_the_wind_over():
	await _warm()
	_wind.tick(1.0, 0.0, WindSound.Ear.HULL, 0.016)
	assert_true(_wind.hull_playing())
	assert_false(_wind.helmet_playing())
	_wind.tick(1.0, 0.0, WindSound.Ear.HELMET, 0.016)
	assert_true(_wind.helmet_playing())
	assert_false(_wind.hull_playing())
	_wind.tick(0.0, 0.0, WindSound.Ear.HELMET, 0.016)
	assert_false(_wind.helmet_playing())
	assert_false(_wind.hull_playing())

func test_the_loops_are_eight_seconds():
	assert_almost_eq(Synth.build(&"wind").get_length(), 8.0, 0.01)
	assert_almost_eq(Synth.build(&"wind_hull").get_length(), 8.0, 0.01)
