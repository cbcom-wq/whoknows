extends GutTest

## The Ship and Suit buses (airlock spec §6): air carries sound.

func test_the_buses_are_made_once():
	AudioBuses.ensure()
	AudioBuses.ensure()
	var ship := 0
	var suit := 0
	for i in AudioServer.bus_count:
		if AudioServer.get_bus_name(i) == AudioBuses.SHIP:
			ship += 1
		elif AudioServer.get_bus_name(i) == AudioBuses.SUIT:
			suit += 1
	assert_eq(ship, 1)
	assert_eq(suit, 1)

func test_the_ship_bus_muffles_as_the_air_goes():
	AudioBuses.ensure()
	var bus := AudioServer.get_bus_index(AudioBuses.SHIP)
	var filter := AudioServer.get_bus_effect(bus, 0) as AudioEffectLowPassFilter
	assert_not_null(filter)
	AudioBuses.set_air(1.0)
	assert_almost_eq(filter.cutoff_hz, AudioBuses.OPEN_CUTOFF, 1.0)
	assert_almost_eq(AudioServer.get_bus_volume_db(bus), 0.0, 0.01)
	AudioBuses.set_air(0.0)
	assert_almost_eq(filter.cutoff_hz, AudioBuses.VACUUM_CUTOFF, 1.0)
	assert_almost_eq(AudioServer.get_bus_volume_db(bus), AudioBuses.VACUUM_DB, 0.01)
	AudioBuses.set_air(0.5)
	assert_between(filter.cutoff_hz, AudioBuses.VACUUM_CUTOFF, AudioBuses.OPEN_CUTOFF)
	AudioBuses.set_air(1.0)
